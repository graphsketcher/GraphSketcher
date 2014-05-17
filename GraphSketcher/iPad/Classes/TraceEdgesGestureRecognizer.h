// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <UIKit/UIGestureRecognizerSubclass.h>


@class NSTimer, RSFillTool;

@interface TraceEdgesGestureRecognizer : UIPanGestureRecognizer
{
@private
    CGPoint _timerBeganPoint;
    NSTimeInterval _timerBeganTimestamp;
    
    NSTimer *_pauseTimer;
    CGPoint _pausePoint;
    CGPoint _lastPoint;
    
    RSFillTool *_tool;
    BOOL _paused;
}

@property (assign) RSFillTool *tool;
@property (readonly) BOOL paused;

@end
