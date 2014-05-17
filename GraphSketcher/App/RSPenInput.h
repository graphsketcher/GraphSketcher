// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

//
// This class implements the recognition algorithms for drawn strokes.
//

#import <Cocoa/Cocoa.h>

#import "RSStrokePoint.h"
#import "RSNumber.h"



// this sets up various modes useful for debugging stroke recognition (normal is 0):
#define SKETCH_TEST_MODE 0

// there is also a preference "SegmentStrokesWhileDrawing" which interacts with SKETCH_TEST_MODE


// set this to 1 to prevent the segmenter from pruning any sign-change points
#define END_BEFORE_PRUNING 0


// set this to 0 to turn off logging in RSPenInput:
#define PEN_LOGGING_LEVEL 0

#if PEN_LOGGING_LEVEL >= 1 && defined(DEBUG_robin)
#	define	LogP(format, ...)	NSLog( format, ## __VA_ARGS__ )
#else
#	define LogP(format, ...)
#endif



@interface RSPenInput : NSObject {
    
}

// low-level geometry helpers
+ (float)distanceBetweenPoint:(NSPoint)t andLineFrom:(NSPoint)start to:(NSPoint)end;

// methods that act on a single segment
+ (NSPoint)curvePointForStroke:(NSArray *)stroke;
+ (NSPoint)curvePointForSegmentFrom:(NSInteger)startIndex to:(NSInteger)endIndex onStroke:(NSArray *)stroke;
+ (NSPoint)midPointForStroke:(NSArray *)stroke;
+ (BOOL)stroke:(NSArray *)stroke isStraightWithCurvePoint:(NSPoint)cp;
+ (float)straightnessOfStroke:(NSArray *)stroke withCurvePoint:(NSPoint)cp;
+ (float)straightnessOfSegmentStarting:(NSPoint)start ending:(NSPoint)end withCurvePoint:(NSPoint)cp;

// methods for segmenting a stroke
+ (NSArray *)segmentStroke:(NSArray *)stroke;  // returns an array of stroke arrays
+ (NSArray *)segmentsFromSegmentIndices:(NSArray *)indices forStroke:(NSArray *)stroke;
+ (float)tangentFrom:(NSInteger)start to:(NSInteger)end xValues:(CGFloat *)xvals yValues:(CGFloat *)yvals;


@end
