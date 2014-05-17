// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

// RSDataMapper performs bi-directional 2D mapping between view coordinates (i.e. pixels on screen) and data coordinates (i.e. position in the model relative to the axes).  It currently supports linear and logarithmic coordinate spaces.  View coords use CGFloat while data coords use "data_p" which is defined as "double".  On iPad and 32-bit Mac, that means we're also mapping between float sizes.  RSDataMapper also has various helper methods that are related only in that they do a lot of coordinate mapping at their core. For example, there are a lot of methods that work with lengths and distances on curved lines — the lines live in data coords but the angles and distances are in view coords.

#import <OmniBase/OBObject.h>
#import <GraphSketcherModel/RSGraph.h> // RSAxisEnd

@class NSBezierPath;
@class RSGraph, RSLine, RSConnectLine, RSVertex, RSFill, RSTextLabel, RSAxis, RSGraphElement;

typedef struct _RSBezierSpec {
    CGPoint p0;
    CGPoint p1;
    CGPoint p2;
    CGPoint p3;
    CGFloat t;
} RSBezierSpec;

typedef struct _RSBezierSegment {
    CGPoint p;
    CGPoint q;
    CGPoint r;
} RSBezierSegment;

typedef struct _RSTwoPoints {
    CGPoint p1;
    CGPoint p2;
} RSTwoPoints;



@interface RSDataMapper : OBObject
{
    CGRect _bounds;
    RSGraph *_graph;
    
    RSDataPoint _logSpaceRange;
    
    RSAxisType _xAxisType;
    RSAxisType _yAxisType;
    
    NSArray *_vertexArrayCache;
    NSArray *_bezierSegmentsCache;
}

// Init
- (id)initWithGraph:(RSGraph *)graph;

- (RSGraph *)graph;
@property(nonatomic) CGRect bounds;
@property(assign) NSArray *vertexArrayCache;
@property(retain) NSArray *bezierSegmentsCache;
- (void)resetCurveCache;
- (void)mappingParametersDidChange;


// Methods to convert between coordinate systems
- (data_p)convertToDataCoords:(CGFloat)val inDimension:(int)orientation;
- (RSDataPoint)convertToDataCoords:(CGPoint)p;
- (CGFloat)convertToViewCoords:(data_p)val inDimension:(int)orientation;
- (CGPoint)convertToViewCoords:(RSDataPoint)d;


// Positioning convenience methods
- (CGPoint)viewCenterOfElement:(RSGraphElement *)GE;
- (RSDataPoint)originPoint;  // point where axes touch, in user coords
- (CGPoint)viewOriginPoint;
- (CGPoint)viewMins; // axis mins in view coords
- (CGPoint)viewMaxes;
- (CGRect)viewAxisRect;
- (void)shiftElement:(RSGraphElement *)GE byDelta:(CGPoint)delta;
- (void)moveElement:(RSGraphElement *)GE toPosition:(RSDataPoint)newPos;


// Grid position convenience methods
- (data_p)closestGridLineTo:(CGFloat)viewP onAxis:(RSAxis *)A;
- (BOOL)isGridLine:(data_p)dataP onAxis:(RSAxis *)A;
- (BOOL)isGridLinePoint:(RSDataPoint)p;
- (RSDataPoint)roundToGrid:(CGPoint)viewP;
- (CGPoint)deltaToSquareGrid;


// Auto-scaling
- (void)scaleAxesToMakeVisible:(NSArray *)elements;
- (void)scaleAxesToShrinkIfNecessary;
- (void)scaleAxesToFitData;
- (void)scaleAxesForNewObjects:(NSArray *)elements importingData:(BOOL)importingData;


// Helper methods for lines and curves:
- (void)convertVertexArray:(NSArray *)VArray toPoints:(CGPoint[])points;
- (CGFloat)viewDistanceBetween:(RSDataPoint)p1 and:(RSDataPoint)p2;
- (CGFloat)viewLengthOfLine:(RSLine *)L;  // This returns an estimate of the line's length in view coords.  The caller should be prepared to handle a return value of 0, which could mean the line is just a point or the estimation failed.
- (CGFloat)viewLengthOfLineSegment:(RSLine *)L fromTime:(CGFloat)t1 toTime:(CGFloat)t2;
- (CGFloat)timeOnLine:(RSLine *)L viewDistance:(CGFloat)spacing fromTime:(CGFloat)tprev direction:(NSUInteger)direction;

- (RSBezierSpec)bezierSpecOfConnectLine:(RSConnectLine *)L atTime:(CGFloat)t;
- (void)bezierSegmentsFromVertexArray:(NSArray *)VArray putInto:(CGPoint[][3])segs;
- (NSArray *)bezierSegmentsFromVertexArray:(NSArray *)VArray;

- (CGFloat)timeOfVertex:(RSVertex *)V onLine:(RSLine *)L;
- (CGPoint)locationOnCurve:(RSLine *)L atTime:(CGFloat)t;
- (RSTwoPoints)lineTangentToLine:(RSLine *)L atTime:(CGFloat)t useDelta:(CGFloat)delta;
- (CGPoint)directionOfLine:(RSLine *)L atTime:(CGFloat)t;
- (CGFloat)degreesFromHorizontalOfLine:(RSLine *)L atTime:(CGFloat)t;
- (CGFloat)degreesFromHorizontalOfLine:(RSLine *)L atTime:(CGFloat)t useDelta:(CGFloat)delta;
- (CGFloat)curvatureOfLine:(RSLine *)L atTime:(CGFloat)t useDelta:(CGFloat)delta;

- (void)curvePath:(NSBezierPath *)P alongConnectLine:(RSConnectLine *)L start:(CGFloat)gt1 finish:(CGFloat)gt2;

- (BOOL)xValue:(CGFloat)px intersectsLine:(RSLine *)testLine saveY:(CGFloat *)saveY;


// Helper methods for arrows:
- (CGFloat)timeOfAdjustedEnd:(RSVertex *)V onLine:(RSLine *)L;
- (CGFloat)degreesFromHorizontalOfAdjustedEnd:(RSVertex *)V onLine:(RSLine *)L;


// Helper methods for fills:
- (NSUInteger)bestIndexInFill:(RSFill *)F forVertex:(RSVertex *)V;
- (CGFloat)viewAreaOfFill:(RSFill *)F;


// Helper methods for text labels
- (CGRect)rectFromLabel:(RSTextLabel *)TL offset:(CGFloat)offset;
- (CGRect)rectFromPosition:(data_p)pos onAxis:(RSAxis *)axis;


// Helper methods for axes
- (CGFloat)viewLengthOfAxis:(RSAxis *)axis;
- (CGPoint)positionOfAxisEnd:(RSAxisEnd)axisEnd;


#ifdef DEBUG

#endif

@end
