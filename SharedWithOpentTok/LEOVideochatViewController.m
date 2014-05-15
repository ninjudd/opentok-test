//
//  ChatViewController.m
//  Leonardo
//
//  Created by Jean Sini on 12/9/13.
//  Copyright (c) 2013 Jean Sini. All rights reserved.
//

#import "LEOVideochatViewController.h"
#import "LEOOpenTokService.h"


typedef NS_ENUM(NSInteger, LEOVideochatViewControllerAlertViewTag) {
  LEOAlertViewNone,
  LEOAlertViewSessionAndTokenIdRequestError,
  LEOAlertViewConnectionError,
  LEOAlertViewPublishingError,
  LEOAlertViewSubscribingError,
  LEOAlertViewCounterPartUserHungup
};


@interface LEOVideochatViewController ()<LEOOpenTokServiceDelegate> {
  BOOL _videoChatWillEndOnDisconnect;
}

@property LEOVideochatViewControllerAlertViewTag alertViewTag;
@end;

@implementation LEOVideochatViewController

// why not using NSString+Leonardo.h::urlEncode?
NSString* encodeToPercentEscapeString(NSString *string) {
  return (NSString *)
  CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(NULL,
                                                            (CFStringRef) string,
                                                            NULL,
                                                            (CFStringRef) @"!*'();:@&=+$,/?%#[]",
                                                            kCFStringEncodingUTF8));
}


#pragma mark - public methodes

- (void)setVideoChatSessionId:(NSString *)sessionId withToken:(NSString *)token {

  // If the arguments are nil or empty strings they are just initializations
  // values and not real credentials.
  if (sessionId && [sessionId length] && token && [token length]) {
    // set the new credentials.
    [[LEOOpenTokService sharedInstance] setSessionId:sessionId];
    [[LEOOpenTokService sharedInstance] setToken:token];
    
    // Since in this mode we don't query session credential from the server,
    // there is no need to start the activity spinner relative to the server query.
    self.connectionActivityIndicator.hidden = YES;
    [self.connectionActivityIndicator stopAnimating];
  }
}

- (void)endVideoChat {
  [self doHangup];
}

#pragma mark - View lifecycle

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
  self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
  if (self) {
    
    // Initialize the opentok service singleton and link it with this instance
    // of the video chat view controller.
    [[LEOOpenTokService sharedInstance] setSessionId:@""];
    [[LEOOpenTokService sharedInstance] setToken:@""];
    [[LEOOpenTokService sharedInstance] setDelegate:self];
  }
  
  return self;
}

- (void)viewDidLoad {
  [super viewDidLoad];

  self.alertViewTag = LEOAlertViewNone;

  // Show the regular hangup button.
  self.hangupButton.hidden = NO;

  self.subscriberView.layer.masksToBounds = NO;
  self.subscriberView.layer.shadowOffset = CGSizeMake(2, 2);
  self.subscriberView.layer.shadowRadius = 5;
  self.subscriberView.layer.shadowOpacity = 0.5;
  
  self.publisherView.layer.masksToBounds = NO;
  self.publisherView.layer.shadowOffset = CGSizeMake(2, 2);
  self.publisherView.layer.shadowRadius = 5;
  self.publisherView.layer.shadowOpacity = 0.5;
  
  // create session object which will connect automatically in autoconnect mode.
  [[LEOOpenTokService sharedInstance] setAppId:self.apiKey];
  [[LEOOpenTokService sharedInstance] createSession];
}

- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];
  
  // The view just appeared, refresh all the buttons.
  [self updateConnectionPublishStartStopButtons];
}

- (void)updateConnectionPublishStartStopButtons {
  
  if ([[LEOOpenTokService sharedInstance] session]) {
    
    OTSessionConnectionStatus sessionStatus = [[[LEOOpenTokService sharedInstance] session] sessionConnectionStatus];
    
    // Show a spinning activity indicator while the session is connecting and
    // when waiting for session credentials from the server.
    BOOL showConnectionActivityIndicator = sessionStatus == OTSessionConnectionStatusConnecting;
    self.connectionActivityIndicator.hidden = !showConnectionActivityIndicator;
    
    BOOL isSessionConnected = sessionStatus == OTSessionConnectionStatusConnected;
    if (isSessionConnected) {
      // The session is connect, hide connect button, show disconnect button.
      self.connectButton.hidden = YES;
      self.disconnectButton.hidden = NO;
      
      // If session is publishing, show unpublish button, otherwise show publish button.
      BOOL isPublishing = [[LEOOpenTokService sharedInstance] publisher] != nil;
      self.publishButton.hidden = isPublishing;
      self.unpublishButton.hidden = !isPublishing;
      
    } else {
      // The session was disconnected or failed to connect.
      // We only show connect button in that case.
      self.connectButton.hidden = !(sessionStatus == OTSessionConnectionStatusNotConnected || sessionStatus == OTSessionConnectionStatusFailed);

      self.disconnectButton.hidden = YES;
      self.publishButton.hidden = YES;
      self.unpublishButton.hidden = YES;
    }
        
  } else {
    
    self.connectionActivityIndicator.hidden = YES;
    
    // No session object present, only the connect button is shown and can possibly be enabled,
    // but only if the session credentials are valid.
    self.connectButton.hidden = NO;
    self.disconnectButton.hidden = YES;
    self.publishButton.hidden = YES;
    self.unpublishButton.hidden = YES;
  }
  

}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
  // For M1 we only support Portrait Up orientation.
  return interfaceOrientation == UIInterfaceOrientationPortrait;
}

- (void)presentPublisherView {
  
  UIView *publisherView = [[LEOOpenTokService sharedInstance] publisher].view;
  // We will want to resize this view so it scale with its super view.
  [publisherView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];

  // Calculate size of publisher view.
  float publisherViewAspectRatio = publisherView.frame.size.width / publisherView.frame.size.height;
  float targetWidth = self.publisherView.frame.size.width;
  float targetHeight = targetWidth / publisherViewAspectRatio;
  CGPoint publisherViewOrigin = (CGPoint) {
    self.publisherView.frame.size.width / 2 - targetWidth / 2,
    self.publisherView.frame.size.height / 2 - targetHeight / 2
  };
  
  // Add it to its intended super view.
  [self.publisherView addSubview:[[LEOOpenTokService sharedInstance] publisher].view];

  // set frame of publisher view.
 publisherView.frame = (CGRect) {.origin = publisherViewOrigin, .size = (CGSize) {targetWidth, targetHeight}};
}



- (void)presentSubscriberView {
  UIView *subscriberView = [[LEOOpenTokService sharedInstance] subscriber].view;
  // We will want to resize this view so it scale with its super view.
  [subscriberView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
  
  // Calculate size of publisher view.
  float subscriberViewAspectRatio = subscriberView.frame.size.width / subscriberView.frame.size.height;
  float targetWidth = self.subscriberView.frame.size.width;
  float targetHeight = targetWidth / subscriberViewAspectRatio;
  CGPoint subscriberViewOrigin = (CGPoint) {
    self.subscriberView.frame.size.width / 2 - targetWidth / 2,
    self.subscriberView.frame.size.height - targetHeight
  };
  
   // Add it to its intended super view.
  [self.subscriberView addSubview:[[LEOOpenTokService sharedInstance] subscriber].view];

  // set frame of publisher view.
  subscriberView.frame = (CGRect) {.origin = subscriberViewOrigin, .size = (CGSize) {targetWidth, targetHeight}};
}

- (void)doHangup {
  [[LEOOpenTokService sharedInstance] hangUp];
}

#pragma mark - UI elements actions
- (IBAction)connectButtonAction:(id)sender {
  [[LEOOpenTokService sharedInstance] manualConnect];
}

- (IBAction)disconnectButtonAction:(id)sender {
    [[LEOOpenTokService sharedInstance] manualDisconnect];
 }

- (IBAction)publishButtonAction:(id)sender {
  [[LEOOpenTokService sharedInstance] manualPublish];
}

- (IBAction)unpublishButtonAction:(id)sender {
  [[LEOOpenTokService sharedInstance] manualUnpublish];
}


- (IBAction)hangupButtonAction:(id)sender {
  [self doHangup];
}

- (IBAction)togglePubAudioButton:(id)sender {
  // toggle pub audio on/off to prevent awful sound echo
  [[[LEOOpenTokService sharedInstance] publisher] setPublishAudio:!
   [[[LEOOpenTokService sharedInstance] publisher] publishAudio]];
}


#pragma mark UIAlertViewDelegate
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
  
  switch (self.alertViewTag) {
      // Alert when connecting to session failed: provide dialog to attemp connection again.
    case LEOAlertViewSessionAndTokenIdRequestError:
      [self updateConnectionPublishStartStopButtons];
      break;
    
      // Alert when connecting to session failed: provide dialog to attemp connection again.
    case LEOAlertViewConnectionError:
      if (buttonIndex == 1) {
        // Retry never seem to work, so just hangup on connection error.
        [self doHangup];
      } else {
        // Pressed Keep trying button, disconnect/reconnect.
        [[LEOOpenTokService sharedInstance] destroySession];
        [[LEOOpenTokService sharedInstance] createSession];
      }
      break;

      // No post alert action for these.
    case LEOAlertViewPublishingError:
      if (buttonIndex == 1) {
        [[LEOOpenTokService sharedInstance] manualPublish];
      }
      break;
      
    case LEOAlertViewSubscribingError:
      if (buttonIndex == 1) {
        // Try subscribing again.
        [[LEOOpenTokService sharedInstance] manualSubscribe];
      }
      break;
      
    case LEOAlertViewCounterPartUserHungup:
      [self doHangup];
      break;
      
    case LEOAlertViewNone:
    default:
      // Should never happen.
      assert(true);
      break;
  }
  
  // reset alertview tag.
  self.alertViewTag = LEOAlertViewNone;
}

#pragma mark LEOOpenTokServiceDelegate

- (void)sessionDidConnect {
  NSLog(@"%s", __PRETTY_FUNCTION__);
  [self updateConnectionPublishStartStopButtons];
}

- (void)sessionDidDisconnect {
  NSLog(@"%s", __PRETTY_FUNCTION__);
  [self updateConnectionPublishStartStopButtons];
}

- (void)sessionDidPublish {
  NSLog(@"%s", __PRETTY_FUNCTION__);
  [self presentPublisherView];
  [self updateConnectionPublishStartStopButtons];
}

- (void)sessionDidUnpublish {
  NSLog(@"%s", __PRETTY_FUNCTION__);
  [self updateConnectionPublishStartStopButtons];
}

- (void)sessionDidSubscribe {
  NSLog(@"%s", __PRETTY_FUNCTION__);
  [self presentSubscriberView];
}

- (void)sessionDidUnsubscribe {
  NSLog(@"%s", __PRETTY_FUNCTION__);
  [self updateConnectionPublishStartStopButtons];
}

- (void)callDidHangUp {
  NSLog(@"%s", __PRETTY_FUNCTION__);
  // The session object is retained by the LEOOpenTokService, so we need to destroy it
  /// when we end a video chat.
  [[LEOOpenTokService sharedInstance] destroySession];
  
  // Break the link between this instance of the video chat viewer and the
  // OpenTok service singleton.
  [[LEOOpenTokService sharedInstance] setDelegate:nil];
  
  if (self.videoChatViewControllerDelegate &&
      [self.videoChatViewControllerDelegate respondsToSelector:@selector(videoChatHasEnded)]) {
    [self.videoChatViewControllerDelegate videoChatHasEnded];
  }
}

- (void)sessionConnectionDidFailWithError:(OTError*)error {
  NSLog(@"%s", __PRETTY_FUNCTION__);
  
  UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Video session failed"
                                                  message:[NSString stringWithFormat:@"%@ \n[session: %@]",
                                                           [error localizedDescription],
                                                           [[LEOOpenTokService sharedInstance] session].sessionId]
                                                 delegate:self
                                        cancelButtonTitle:@"Keep Trying"
                                        otherButtonTitles:@"Hang Up", nil];
  self.alertViewTag = LEOAlertViewConnectionError;
  [alert show];
}

- (void)sessionPublishingDidFailWithError:(OTError*)error {
  NSLog(@"%s", __PRETTY_FUNCTION__);
  [self updateConnectionPublishStartStopButtons];
  
  UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Message from video session"
                                                  message:@"There was an error publishing."
                                                 delegate:self
                                        cancelButtonTitle:@"Cancel"
                                        otherButtonTitles:@"Retry", nil];
  self.alertViewTag = LEOAlertViewPublishingError;
  [alert show];
}

- (void)sessionSubscribingDidFailWithError:(OTError*)error {
  NSLog(@"%s", __PRETTY_FUNCTION__);
  // We'll give the option of subscribing again in the alert.
  NSLog(@"%s [Stream: %@, Error: %@ - %@].", __PRETTY_FUNCTION__,[[LEOOpenTokService sharedInstance] subscriber].stream.streamId,
        error, error.localizedDescription);
  UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Message from video session"
                                                  message:[NSString stringWithFormat:@"%@ \n[stream: %@]",
                                                           [error localizedDescription],
                                                           [[LEOOpenTokService sharedInstance] subscriber].stream.streamId]
                                                 delegate:self
                                        cancelButtonTitle:@"Cancel"
                                        otherButtonTitles:@"Retry", nil];
  self.alertViewTag = LEOAlertViewSubscribingError;
  [alert show];

}

@end
