// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/iPad/Classes/SelectAndMoveGestureRecognizer.m 200244 2013-12-10 00:11:55Z correia $

#import "SelectAndMoveGestureRecognizer.h"

#import <OmniGraphSketcherModel/RSNumber.h>

#import "GraphView.h"
#import "TextEditor.h"

@implementation SelectAndMoveGestureRecognizer

- (id)initWithTarget:(id)target action:(SEL)action;
{
    if (!(self = [super initWithTarget:target action:action]))
        return nil;
    
    // Defaults
    self.delay = 0.1;
    //self.delaysTouchesBegan = YES;
    
    
    [self reset];
    
    return self;
}

- (void)dealloc;
{
    
    [super dealloc];
}

@synthesize delay = _delay;
@synthesize translation = _translation;
@synthesize velocity = _velocity;
@synthesize direction = _direction;


#pragma mark -
#pragma mark UIGestureRecognizerSubclass

- (void)reset;
// [From the documentation:] The runtime calls this method after the gesture-recognizer state has been set to UIGestureRecognizerStateEnded or UIGestureRecognizerStateRecognized. Subclasses should reset any internal state in preparation for a new attempt at gesture recognition. After this method is called, the runtime ignores all remaining active touches; that is, the gesture recognizer receives no further updates for touches that have begun but haven't ended.
{
    [super reset];
    
    if (_touchTimer) {
        [_touchTimer invalidate];
        _touchTimer = nil;
    }
    
    _touchInProgress = NO;
    _touchTimerFired = NO;
    
    _velocity = 0;
    _translation = CGPointZero;
    _direction = CGPointZero;
}

- (void)_touchBeganTimerFired:(NSTimer *)theTimer;
{
    _touchTimerFired = YES;
    
    if (_touchInProgress && self.state == UIGestureRecognizerStatePossible) {
        self.state = UIGestureRecognizerStateBegan;
    }
    
    // TODO: select touched elements (or send off selector to delegate?)
    // if deselecting, also fail out so that user can then pan
    
    _touchTimer = nil;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event;
{
    [super touchesBegan:touches withEvent:event];
    //NSLog(@"select/move touch began");
    
    if ([touches count] != 1) {
        self.state = UIGestureRecognizerStateFailed;
        return;
    }
    
    // If there this event would match a running text editor, it isn't for us.
    if ([SharedTextEditor() hasTouchesForEvent:event]) {
        self.state = UIGestureRecognizerStateFailed;
        return;
    }
    
    ////////////
//    UIScrollView *scrollView = (UIScrollView *)self.view.superview;
//    for (UIGestureRecognizer *recognizer in scrollView.gestureRecognizers) {
//        if (recognizer.enabled && recognizer.delaysTouchesBegan) {
//            NSLog(@"Delays began: %@", recognizer);
//        }
//    }
    //////////
    
    _touchInProgress = YES;
    _touchTimerFired = NO;
    
    // Schedule a timer to tell us when selection has succeeded
    _touchTimer = [NSTimer scheduledTimerWithTimeInterval:self.delay target:self selector:@selector(_touchBeganTimerFired:) userInfo:nil repeats:NO];
    
    UITouch *touch = [touches anyObject];
    _touchBeganTimestamp = touch.timestamp;
    _touchBeganPoint = [touch locationInView:self.view];
    _prevTouchTimestamp = _touchBeganTimestamp;
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event;
{
    [super touchesMoved:touches withEvent:event];
    if (self.state == UIGestureRecognizerStateCancelled || self.state == UIGestureRecognizerStateFailed)
        return;
    
    // Calculate distance moved from start
    UITouch *touch = [touches anyObject];
    CGPoint newLocation = [touch locationInView:self.view];
    CGFloat distance = distanceBetweenPoints(_touchBeganPoint, newLocation);
    
    // If the touch moved before the timer fired and put us in "Began", we should fail out right away (user probably wants to pan)
    if (self.state == UIGestureRecognizerStatePossible) {
        // Hysteresis - allow for 10 pixel sloppiness (default hysteresis for long-hold gestures)
        if (distance < 10) {
            return;  // pretend no touchMoved event was received
        }
        
        self.state = UIGestureRecognizerStateFailed;
        return;
    }
    
    // Otherwise, we should start or continue an object-move operation
    self.translation = CGPointMake(newLocation.x - _touchBeganPoint.x, newLocation.y - _touchBeganPoint.y);
    
    //CGPoint direction = CGPointMake(newLocation.x - prevLocation.x, newLocation.y - prevLocation.y);
    CGPoint direction = CGPointMake(newLocation.x - _touchBeganPoint.x, newLocation.y - _touchBeganPoint.y);
    if (distance > 0) {
        self.direction = CGPointMake(direction.x/distance, direction.y/distance);
    }
    
    CGPoint prevLocation = [touch previousLocationInView:self.view];
    CGFloat recentDistance = distanceBetweenPoints(prevLocation, newLocation);
    NSTimeInterval timeElapsed = touch.timestamp - _prevTouchTimestamp;
    if (timeElapsed > 0) {
        self.velocity = recentDistance/timeElapsed;
    }
    
    self.state = UIGestureRecognizerStateChanged;
    
    _prevTouchTimestamp = touch.timestamp;
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event;
{
    [super touchesEnded:touches withEvent:event];
    //NSLog(@"select/move touch ended");
    
    if (self.state == UIGestureRecognizerStateCancelled || self.state == UIGestureRecognizerStateFailed)
        return;
    
    _touchInProgress = NO;
    
    if (_touchTimerFired) {
        self.state = UIGestureRecognizerStateEnded;
        return;
    }
    
    // Touch was not down long enough, so fail out and let the tap gesture recognizer "win".
    self.state = UIGestureRecognizerStateFailed;
    [self reset];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event;
{
    [super touchesCancelled:touches withEvent:event];
    //NSLog(@"select/move touch cancelled");
    
    self.state = UIGestureRecognizerStateCancelled;
    [self reset];
}

//- (BOOL)canPreventGestureRecognizer:(UIGestureRecognizer *)preventedGestureRecognizer;
//{
//    NSLog(@"handTool canPreventGestureRecognizer: %@", preventedGestureRecognizer);
//    
////    if (self.state == UIGestureRecognizerStatePossible || self.state == UIGestureRecognizerStateFailed || self.state == UIGestureRecognizerStateCancelled) {
////        return NO;
////    }
//    if (self.state != UIGestureRecognizerStateBegan && self.state != UIGestureRecognizerStateChanged) {
//        return NO;
//    }
//    
//    UIScrollView *scrollView = (UIScrollView *)self.view.superview;
//    for (UIGestureRecognizer *recognizer in scrollView.gestureRecognizers) {
//        if (recognizer == preventedGestureRecognizer) {
//            return YES;
//        }
//    }
//    
//    return NO;
//}

@end
