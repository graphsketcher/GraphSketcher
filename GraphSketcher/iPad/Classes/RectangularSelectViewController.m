// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/iPad/Classes/RectangularSelectViewController.m 200244 2013-12-10 00:11:55Z correia $

#import "RectangularSelectViewController.h"
#import "Parameters.h"
#import <GraphSketcherModel/RSGraphRenderer.h>


@implementation RectangularSelectViewController



// Implement loadView to create a view hierarchy programmatically, without using a nib.
- (void)loadView;
{
    UIGraphicsBeginImageContextWithOptions(RECTANGULAR_SELECT_STARTING_SIZE, NO, 0.0);
    
    // Draw the rectangular selection image
    CGRect rect;
    rect.origin = CGPointZero;
    rect.size = RECTANGULAR_SELECT_STARTING_SIZE;
    rect = CGRectInset(rect, 2.0, 2.0);
    
    drawRectangularSelectRect(rect);
    
    // Turn it into a UIImage
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
    
    self.view = imageView;
    [imageView release];
    
    UIGraphicsEndImageContext();
}

- (BOOL)shouldAutorotate;
{
    return YES;
}

#pragma mark - API

- (void)startBouncing;
{
    //NSLog(@"startBouncing");
    
    CGFloat scale = 0.93;
    CGSize size = self.view.bounds.size;
    CGRect newBounds = CGRectMake(0, 0, size.width*scale, size.height*scale);
    [UIView beginAnimations:@"new selection bouncing" context:NULL];
    {
        [UIView setAnimationRepeatCount:10000];
        [UIView setAnimationRepeatAutoreverses:YES];
        [UIView setAnimationDuration:0.4];
        
        self.view.bounds = newBounds;
    }
    [UIView commitAnimations];
}

- (void)stopBouncing;
{
    //NSLog(@"stopBouncing");
    
    [UIView setAnimationsEnabled:NO];
    [UIView setAnimationsEnabled:YES];
}

- (void)showAtPoint:(CGPoint)touchPoint inView:(UIView *)targetView;
{
    self.view.center = touchPoint;
    self.view.alpha = 0;
    self.view.bounds = CGRectZero;
    
    [targetView addSubview:self.view];
    
    [UIView beginAnimations:@"new selection view fade in" context:NULL];
    {
        // These parameters are set so that the animation is not annoying when you are just tapping the canvas.
        [UIView setAnimationDelay:0.1];
        [UIView setAnimationDuration:0.2];
        
        self.view.alpha = 1;
        CGSize size = RECTANGULAR_SELECT_STARTING_SIZE;
        self.view.bounds = CGRectMake(0, 0, size.width, size.height);
        
        [UIView setAnimationDelegate:self];
        [UIView setAnimationDidStopSelector:@selector(showAnimationDidStop:finished:context:)];
    }
    [UIView commitAnimations];
}

- (void)showAnimationDidStop:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context;
{
    if (self.view.alpha != 0) {
        [self startBouncing];
    }
}

- (void)hideToRect:(CGRect)rect;
{
    if (self.view.alpha == 0)
        return;
    
    [self stopBouncing];
    
    [UIView beginAnimations:@"new selection view hide to rect" context:NULL];
    {
        [UIView setAnimationDelegate:self];
        [UIView setAnimationDidStopSelector:@selector(hideAnimationDidStop:finished:context:)];
        [UIView setAnimationDuration:0.2];
        
        self.view.alpha = 0;
        self.view.frame = rect;
    }
    [UIView commitAnimations];
}

- (void)hide;
// Hide immediately (for situations where it turns out you are not performing rectangular-select).
{
    if (self.view.alpha == 0)
        return;
    
    [self stopBouncing];
    
    self.view.alpha = 0;
    [self.view removeFromSuperview];
}

- (void)hideAnimationDidStop:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context;
{
    if (self.view.alpha == 0) {
        [self.view removeFromSuperview];
    }
}


@end
