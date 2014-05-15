//
//  LEOVideoChatViewController.h
//  Leonardo
//
//  Created by Jean Sini on 12/9/13.
//  Copyright (c) 2013 Jean Sini. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "LEOOpenTokService.h"

@protocol LEOVideochatViewControllerDelegate <NSObject>
- (void)videoChatHasEnded;
@end


@interface LEOVideochatViewController : UIViewController<UIAlertViewDelegate, LEOOpenTokServiceDelegate>

@property (strong, nonatomic) IBOutlet UIView *view;
@property (weak, nonatomic) IBOutlet UIButton *connectButton;
@property (weak, nonatomic) IBOutlet UIButton *disconnectButton;
@property (weak, nonatomic) IBOutlet UIButton *publishButton;
@property (weak, nonatomic) IBOutlet UIButton *unpublishButton;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *connectionActivityIndicator;
@property (strong, nonatomic) IBOutlet UIButton *hangupButton;
@property (weak, nonatomic) IBOutlet UIView *subscriberView;
@property (weak, nonatomic) IBOutlet UIView *publisherView;

- (IBAction)connectButtonAction:(id)sender;
- (IBAction)disconnectButtonAction:(id)sender;
- (IBAction)publishButtonAction:(id)sender;
- (IBAction)unpublishButtonAction:(id)sender;
- (IBAction)hangupButtonAction:(id)sender;
- (IBAction)togglePubAudioButton:(id)sender;

@property (strong, nonatomic) NSString *apiKey;
@property (weak, nonatomic) id<LEOVideochatViewControllerDelegate> videoChatViewControllerDelegate;

// These  properties will need to be set to start an opentok session if the
// videoChatViewWController is in production mode, which is the default.
// Turning production mode on/off will be handled in the "Internal Setting" view.
- (void)setVideoChatSessionId:(NSString *)sessionId withToken:(NSString *)token;
- (void)endVideoChat;


@end
