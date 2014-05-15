//
//  ViewController.h
//  SharedWithOpentTok
//
//  Created by Gilles Dezeustre on 3/19/14.
//  Copyright (c) 2014 Gilles Dezeustre. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ViewController : UIViewController

@property (weak, nonatomic) IBOutlet UISegmentedControl *tokenChooser;
@property (weak, nonatomic) IBOutlet UIButton *startChatButton;

- (IBAction)StartChatButtonAction:(UIButton *)sender;

@end
