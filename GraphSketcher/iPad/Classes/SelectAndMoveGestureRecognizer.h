// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/iPad/Classes/SelectAndMoveGestureRecognizer.h 200244 2013-12-10 00:11:55Z correia $

#import <UIKit/UIGestureRecognizerSubclass.h>

@interface SelectAndMoveGestureRecognizer : UIGestureRecognizer
{
    CFTimeInterval _delay;
    
    NSTimer *_touchTimer;
    BOOL _touchInProgress;
    BOOL _touchTimerFired;
    
    NSTimeInterval _touchBeganTimestamp;
    CGPoint _touchBeganPoint;
    NSTimeInterval _prevTouchTimestamp;
    
    CGPoint _translation;
    CGFloat _velocity;
    CGPoint _direction;
}

@property (assign) CFTimeInterval delay;

@property (assign) CGPoint translation;
@property (assign) CGFloat velocity;
@property (assign) CGPoint direction;

@end
