// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "TraceEdgesGestureRecognizer.h"

#import "RSFillTool.h"
#import "Parameters.h"


@implementation TraceEdgesGestureRecognizer

- (id)initWithTarget:(id)target action:(SEL)action;
{
    if (!(self = [super initWithTarget:target action:action]))
        return nil;
    
    //self.delaysTouchesBegan = YES;
    self.maximumNumberOfTouches = 1;
    _tool = nil;
    
    [self reset];
    
    return self;
}

- (void)dealloc;
{
    [_pauseTimer invalidate];
    [_pauseTimer release];
    _pauseTimer = nil;
    
    [super dealloc];
}

- (void)_pauseTimerFired:(NSTimer *)theTimer;
{
    //NSLog(@"timer fired");
    
    [_pauseTimer release];
    _pauseTimer = nil;
    
    _pausePoint = _lastPoint;
    
    [self.tool fillCornerEndedAtPoint:_pausePoint];
}

@synthesize tool = _tool;
@synthesize paused = _paused;


#pragma mark -
#pragma mark UIGestureRecognizerSubclass

- (void)reset;
{
    [_pauseTimer invalidate];
    [_pauseTimer release];
    _pauseTimer = nil;
    
    [super reset];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event;
{
    [super touchesBegan:touches withEvent:event];
    
    if ([touches count] != 1) {
        self.state = UIGestureRecognizerStateFailed;
        return;
    }
    
    UITouch *touch = [touches anyObject];
    _timerBeganPoint = [touch locationInView:self.view];
    _timerBeganTimestamp = touch.timestamp;
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event;
{
    [super touchesMoved:touches withEvent:event];
    if (self.state == UIGestureRecognizerStateCancelled || self.state == UIGestureRecognizerStateFailed)
        return;
    
    if (self.state != UIGestureRecognizerStatePossible) {  // i.e. already in progress
        
        UITouch *touch = [touches anyObject];
        CGPoint newLocation = [touch locationInView:self.view];
        _lastPoint = newLocation;
        
        // If finger is not moving...
        if (!_pauseTimer) {
            CGFloat distance = distanceBetweenPoints(_pausePoint, newLocation);
            // Hysterisis: Ignore little movements of the finger
            if (distance < 30) {
                //NSLog(@"finger still paused");
                _paused = YES;
                return;
            }
            
            //NSLog(@"finger moving again");
        }
        
        // If the finger is moving (a timer is set)
        else {
            _paused = NO;
            
            // Calculate distance moved since timer began
            CGFloat distance = distanceBetweenPoints(_timerBeganPoint, newLocation);
            //NSLog(@"distance: %f", distance);
            //NSTimeInterval timeElapsed = touch.timestamp - _timerBeganTimestamp;
            //CGFloat speed = distance/timeElapsed;
            
//            CGPoint velocity = [self velocityInView:self.view];
//            CGFloat velocityScalar = hypot(velocity.x, velocity.y);
//            NSLog(@"velocity: %f", velocityScalar);
//            if (velocityScalar > CORNER_PAUSE_VELOCITY) {
            
            // Restart the pause timer if the finger is moving fast enough
            if ( distance > 3 ) {
                //NSLog(@"restarting timer");
                [_pauseTimer invalidate];
                [_pauseTimer release];
                _pauseTimer = nil;
                
                _timerBeganPoint = newLocation;
                _timerBeganTimestamp = touch.timestamp;
            }
            else {
                //NSLog(@"distance: %f", distance);
                return;
            }

            
        }
        
        // If made it this far, we need a new pause timer
        _pauseTimer = [[NSTimer scheduledTimerWithTimeInterval:CORNER_PAUSE_DELAY target:self selector:@selector(_pauseTimerFired:) userInfo:nil repeats:NO] retain];
        
    }
    
    
    
    //UITouch *touch = [touches anyObject];
    //_latestTimestamp = touch.timestamp;
    
    //    self.state = UIGestureRecognizerStateChanged;
}

//- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event;
//{
//    [super touchesEnded:touches withEvent:event];
//    if (self.state == UIGestureRecognizerStateCancelled || self.state == UIGestureRecognizerStateFailed)
//        return;
//    
//    if (self.state == UIGestureRecognizerStateBegan)
//        self.state = UIGestureRecognizerStateEnded;
//    
//    self.state = UIGestureRecognizerStateFailed;
//}
//
//- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event;
//{
//    [super touchesCancelled:touches withEvent:event];
//    
//    self.state = UIGestureRecognizerStateCancelled;
//    [self reset];
//}

@end
