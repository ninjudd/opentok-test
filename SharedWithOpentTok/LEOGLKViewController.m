//
//  LEOGLKViewController.m
//  SharedWithOpentTok
//
//  Created by Gilles Dezeustre on 4/10/14.
//  Copyright (c) 2014 Gilles Dezeustre. All rights reserved.
//

#import "LEOGLKViewController.h"


@implementation LEOGLKViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  
  self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
  
  if (!self.context) {
    NSLog(@"Failed to create ES context");
  }
  
  GLKView *view = (GLKView *)self.view;
  view.context = self.context;
}

#pragma mark - GLKViewDelegate

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect {
  
  glClearColor(1.0, 0.0, 0.0, 1.0);
  glClear(GL_COLOR_BUFFER_BIT);
  
}

#pragma mark - GLKViewControllerDelegate

- (void)glkViewControllerUpdate:(GLKViewController *)controller {
}

- (IBAction)doneButtonAction:(id)sender {
  [self dismissViewControllerAnimated:YES completion:nil];
}
@end

