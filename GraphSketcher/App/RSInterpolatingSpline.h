// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <Cocoa/Cocoa.h>

#import "NSBezierPath-RSExtensions.h"




@interface RSInterpolatingSpline : NSObject {
    NSMutableArray *_points;
}



// Convenience methods:
+ (void)bezierSegmentsFromPoints:(NSPoint[])p length:(int)n putInto:(NSPoint[][3])segs;




// Designated initializer
- (id)initWithPoints:(NSMutableArray *)points;


// Managing the spline:
- (void)addPointsAtEnd:(NSArray *)newPoints;


// Using the spline:
- (void)putBezierSegmentsInto:(NSPoint[][3])segs;
- (NSPoint)locationAtTime:(float)t;

- (void)curvePath:(NSBezierPath *)P alongSplineUsingStart:(float)gt1 finish:(float)gt2;


@end
