//
//  PageViewController.m
//  SharedWithOpentTok
//
//  Created by Gilles Dezeustre on 4/10/14.
//  Copyright (c) 2014 Gilles Dezeustre. All rights reserved.
//

#import "PageViewController.h"

@interface PageViewController ()  <UIPageViewControllerDataSource>

@end

@implementation PageViewController

- (void)viewDidLoad
{
  [super viewDidLoad];
  self.dataSource = self;
  [self setViewControllers:[NSArray arrayWithObject:_vc1] direction:UIPageViewControllerNavigationDirectionForward
                  animated:NO completion:nil];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerAfterViewController:(UIViewController *)viewController {
  if (viewController == _vc1)
    return _vc2;
  else
    return _vc1;
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerBeforeViewController:(UIViewController *)viewController {
  if (viewController == _vc1)
    return _vc2;
  else
    return _vc1;
}

@end
