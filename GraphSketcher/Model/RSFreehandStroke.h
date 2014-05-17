// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

// RSFreehandStroke encapsulates the data and methods needed to turn a freehand line drawing into a smoothed bezier curve passing through a small set of control points. Strokes are made up of RSStrokePoints, which are points in space and time (along the drawn line) that are analyzed together to choose a nicely fitting curve.

#import <OmniBase/OBObject.h>

// set this to 0 to turn off logging in RSFreehandStroke:
#define PEN_LOGGING_LEVEL 0
#if PEN_LOGGING_LEVEL >= 1 && defined(DEBUG)
#define LogP(format, ...) NSLog( format, ## __VA_ARGS__ )
#else
#define LogP(format, ...)
#endif

// this sets up various modes useful for debugging stroke recognition (normal is 0):
#define SKETCH_TEST_MODE 0
// there is also a preference "SegmentStrokesWhileDrawing" which interacts with SKETCH_TEST_MODE

// set this to 1 to prevent the segmenter from pruning any sign-change points
#define END_BEFORE_PRUNING 0


@class RSStrokePoint;

@interface RSFreehandStroke : OBObject
{
@private
    NSMutableArray *_stroke;
    BOOL _strokeEnded;
    NSArray *_segments;
}

// Accessors
- (NSArray *)stroke;
@property (assign) BOOL strokeEnded;
@property (readonly) NSArray *segments;  // Call -performSegmentation first
- (void)addStrokePoint:(CGPoint)p atTime:(double)t;
- (CGRect)boundingRect;

// Methods that act on a single segment
+ (CGPoint)curvePointForSegment:(NSArray *)stroke;
+ (CGPoint)midPointForSegment:(NSArray *)stroke;
+ (BOOL)segment:(NSArray *)stroke isStraightWithCurvePoint:(CGPoint)cp;

// Methods for segmenting a stroke
- (void)performSegmentation;

@end
