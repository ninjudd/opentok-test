//
//  LEOGLKViewController.h
//  SharedWithOpentTok
//
//  Created by Gilles Dezeustre on 4/10/14.
//  Copyright (c) 2014 Gilles Dezeustre. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <GLKit/GLKit.h>

@interface LEOGLKViewController : GLKViewController <GLKViewDelegate, GLKViewControllerDelegate>
@property (strong, nonatomic) EAGLContext *context;
- (IBAction)doneButtonAction:(id)sender;

@end
