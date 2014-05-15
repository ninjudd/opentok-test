//
//  ViewController.m
//  SharedWithOpentTok
//
//  Created by Gilles Dezeustre on 3/19/14.
//  Copyright (c) 2014 Gilles Dezeustre. All rights reserved.
//

#import "ViewController.h"
#import "PageViewController.h"
#import "LEOVideochatViewController.h"
#import "LEOGLKViewController.h"
#import "LEOOpenTokService.h"

static NSString* const kApiKey    = @"";
static NSString* const kSessionId = @"";
static NSString* const kToken1 = @"";
static NSString* const kToken2 = @"";

@interface ViewController () <LEOVideochatViewControllerDelegate>
@property (strong, nonatomic) NSString *token;
@end


@implementation ViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  
  if ([kToken1 length] == 0) {
    self.startChatButton.enabled = NO;
    self.tokenChooser.enabled = NO;
    NSLog(@"Specify Opentok credentials.");
    return;
  }
  
  // By default use token1
  self.token = kToken1;
  [self.tokenChooser setSelectedSegmentIndex:0];
  
  // disable choosing widget and self subscribe if we token2 is empty.
  if ([kToken2 length] == 0) {
    self.tokenChooser.enabled = NO;
    [[LEOOpenTokService sharedInstance] setSubscribeToSelf:YES];
  }
}

- (IBAction)StartChatButtonAction:(UIButton *)sender {
  
  LEOGLKViewController *glkVC = [[LEOGLKViewController alloc] init];
  [self presentViewController:glkVC animated:YES completion:^{
    [glkVC dismissViewControllerAnimated:YES completion:^{
      LEOVideochatViewController *videoChatController = [[LEOVideochatViewController alloc]
                                                         initWithNibName:@"LEOVideochatViewController"
                                                         bundle:nil];
      
      if (self.tokenChooser.selectedSegmentIndex == 0) {
        self.token = kToken1;
      } else {
        self.token = kToken2;
      }
      
      if ([self.token length]) {
        [videoChatController setApiKey:kApiKey];
        [videoChatController setVideoChatSessionId:kSessionId withToken:self.token];
        videoChatController.videoChatViewControllerDelegate = self;
        
        LEOGLKViewController *leoglkViewController = [[LEOGLKViewController alloc] initWithNibName:nil bundle:nil];
        
        PageViewController *pageViewController = [[PageViewController alloc] initWithTransitionStyle:UIPageViewControllerTransitionStyleScroll
                                                                               navigationOrientation:UIPageViewControllerNavigationOrientationHorizontal
                                                                                             options:nil];
        pageViewController.vc1 = videoChatController;
        pageViewController.vc2 = leoglkViewController;
        
        [self presentViewController:pageViewController animated:YES completion:nil];
      }
    }];
  }];
}

- (void)videoChatHasEnded {
  [self dismissViewControllerAnimated:YES completion:nil];
}

@end
