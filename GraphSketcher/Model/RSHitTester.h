// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

// RSHitTester, as you would expect, handles all of GraphSketcher's hit testing needs.  These range from the very basic (points) to very complex (curving bezier paths, which we hit test by splitting the curve into lots of straight-line approximations).  The highest-level methods -elementUnderPoint: do intelligent sorting of possible hit targets in order to play nicely with fat-finger touch input on the iPad (though it also works nicely on the Mac).

#import <OmniFoundation/OFObject.h>

#import <GraphSketcherModel/RSGraph.h>  // RSAxisEnd

@class RSGraphEditor;

#define RSSnapConstraintXKey @"RSSnapConstraintXKey"
#define RSSnapConstraintYKey @"RSSnapConstraintYKey"

typedef struct _RSHitResult {
    RSGraphElement *element;
    CGFloat distance;
    BOOL hit;
} RSHitResult;


@interface RSHitTester : OFObject {
    RSGraphEditor *_nonretained_editor;
    
    NSMutableArray *_hitLines;  // caches the lines from the last hit-detection
    CGPoint _hitPoint;  // caches the point at which the last hit-detection occurred
    
    RSGraphElement *_currentOwner;
    
    CGFloat _scale;  // zoom scale
}

- (id)initWithEditor:(RSGraphEditor *)editor;

@property (assign) CGFloat scale;

// Fundamental hit-testing parameters
- (CGFloat)selectionSensitivity;
- (CGFloat)snapToObjectSensitivity;
- (CGFloat)snapToGridSensitivity;

// Information about the most recent hit detection
- (NSArray *)linesThatWereHit;

// Helpers for expanding the selection beyond what was hit
- (RSGraphElement *)expand:(RSGraphElement *)GE toIncludeGroupingsAndElementsUnderPoint:(CGPoint)p;

// Highest-level methods for object hit detection
- (RSGraphElement *)elementUnderPoint:(CGPoint)p;
- (RSGraphElement *)elementUnderPoint:(CGPoint)p extraElement:(RSGraphElement *)extra;
- (RSGraphElement *)elementUnderPoint:(CGPoint)p fromSelection:(RSGraphElement *)selection;
- (RSGraphElement *)elementsAlmostUnderPoint:(CGPoint)p;


// Higher-level methods for object hit detection
- (RSHitResult)vertexUnderPoint:(CGPoint)p;
- (RSHitResult)vertexUnderPoint:(CGPoint)p notIncluding:(RSVertex *)vNot;
- (RSHitResult)vertexUnderPoint:(CGPoint)p notIncluding:(NSArray *)vNots extraElement:(RSGraphElement *)extra hitOffset:(CGFloat)hitOffset includeInvisible:(BOOL)includeInvisible includeBars:(BOOL)includeBars;
- (RSVertex *)barVertexUnderPoint:(CGPoint)p;
- (RSVertex *)vertexAlmostUnderPoint:(CGPoint)p notIncluding:(RSVertex *)vNot;
- (RSHitResult)labelUnderPoint:(CGPoint)p;
- (RSTextLabel *)labelAlmostUnderPoint:(CGPoint)p;
- (RSHitResult)lineUnderPoint:(CGPoint)p;
- (RSHitResult)lineUnderPoint:(CGPoint)p notIncluding:(NSArray *)LNots;
//- (RSLine *)lineUnderPoint:(CGPoint)p notIncluding:(RSLine *)lNot;
- (RSFill *)fillUnderPoint:(CGPoint)p;
//- (RSLine *)curvePointUnderPoint:(CGPoint)p forElement:(RSGraphElement *)GE;
- (CGPoint)intersectionUnderPoint:(CGPoint)p saveT1:(CGFloat *)tp1 andT2:(CGFloat *)tp2;
- (CGPoint)intersectionNearPoint:(CGPoint)p betweenLine:(RSLine *)L1 andLine:(RSLine *)L2 saveT1:(CGFloat *)tp1 andT2:(CGFloat *)tp2;
- (CGPoint)intersectionNearPoint:(CGPoint)p withLine:(RSLine *)L andConstraints:(NSDictionary *)constraints saveT:(CGFloat *)tp;
- (BOOL)updateIntersection:(CGPoint *)ip betweenLine:(RSLine *)L1 atTime:(CGFloat *)tp1 andLine:(RSLine *)L2 atTime:(CGFloat *)tp2;
- (RSHitResult)axisUnderPoint:(CGPoint)p;
- (BOOL)originUnderPoint:(CGPoint)p;
- (RSAxisEnd)axisEndUnderPoint:(CGPoint)p;
- (NSUInteger)marginGuideUnderPoint:(CGPoint)p;


// Low level hitTest methods
//- (BOOL)hitTestPoint:(CGPoint)testPoint onPoint:(CGPoint)fixedPoint;
- (RSHitResult)hitTestPoint:(CGPoint)testPoint onLine:(RSLine *)testLine;  // external classes use this
- (RSHitResult)hitTestPoint:(CGPoint)testPoint onLine:(RSLine *)testLine hitSegment:(NSUInteger *)hitSegment;
- (RSHitResult)hitTestPoint:(CGPoint)testPoint onLine:(RSLine *)testLine hitSegment:(NSUInteger *)hitSegment hitOffset:(CGFloat)hitOffset;
- (RSHitResult)hitTestPoint:(CGPoint)test onLineFrom:(CGPoint)start to:(CGPoint)end width:(CGFloat)w;
- (RSHitResult)hitTestPoint:(CGPoint)testPoint onVertex:(RSVertex *)V;
- (RSHitResult)hitTestPoint:(CGPoint)testPoint onVertex:(RSVertex *)V hitOffset:(CGFloat)hitOffset;
- (BOOL)hitTestPoint:(CGPoint)testPoint onBarEnd:(RSGraphElement *)GE;
- (BOOL)hitTestPoint:(CGPoint)testPoint onFill:(RSFill *)testFill;
- (RSHitResult)hitTestPoint:(CGPoint)testPoint onLabel:(RSTextLabel *)TL;
- (RSHitResult)hitTestPoint:(CGPoint)testPoint onLabel:(RSTextLabel *)TL offset:(CGFloat)hitOffset;
- (RSHitResult)hitTestPoint:(CGPoint)p onAxis:(RSAxis *)axis;
- (RSHitResult)hitTestPoint:(CGPoint)p onAxis:(RSAxis *)axis edge:(RSAxisEdge)edge;
- (RSHitResult)hitTestPoint:(CGPoint)p onAxis:(RSAxis *)axis originPoint:(CGPoint)origin;
- (RSAxisEnd)hitTestPoint:(CGPoint)p onEndsOfAxis:(RSAxis *)axis;


// Rect clip testing methods (for rectangular select)
- (BOOL)rect:(CGRect)viewRect intersectsVertex:(RSVertex *)V;
- (BOOL)rect:(CGRect)viewRect containsVertex:(RSVertex *)V;
- (BOOL)rect:(CGRect)viewRect intersectsLine:(RSLine *)L;
- (BOOL)rect:(CGRect)viewRect intersectsLabel:(RSTextLabel *)TL;
- (BOOL)rect:(CGRect)viewRect containsLabel:(RSTextLabel *)TL;

- (RSGraphElement *)elementsIntersectingRect:(CGRect)rect;
- (RSGraphElement *)elementsEnclosedByRect:(CGRect)rect;


// Curves helper methods
- (CGPoint)closestPointTo:(CGPoint)p onCurve:(RSLine *)L;
- (CGPoint)closestPointTo:(CGPoint)p onCurve:(RSLine *)L saveT:(CGFloat *)tp;
- (CGFloat)timeOfClosestPointTo:(CGPoint)p onLine:(RSLine *)L;
- (CGFloat)timeOfClosestPointTo:(CGPoint)p onLine:(RSLine *)L hitSegment:(NSUInteger)hitSegment;


// Fills helper methods:
- (CGFloat)viewDistanceFromFill:(RSFill *)F toPoint:(CGPoint)p;


@end
