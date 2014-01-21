// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/Model/RSGraphRenderer.h 200244 2013-12-10 00:11:55Z correia $

// RSGraphRenderer knows how to do all of the layout and rendering of the graph.  It handles tick mark and tick label layout as well as bezier path creation and drawing.  RSGraphElement-Rendering is an initial attempt to split out some of the rendering code into more manageable categories.  For now it really only works with vertices.

#import <OmniFoundation/OFObject.h>

#import <GraphSketcherModel/RSGraph.h> // RSBorder

@class NSShadow, NSBezierPath;
@class RSDataMapper, RSGraph;

#define RS_MINOR_TICK_LENGTH_MULTIPLIER 0.5f

void drawRectangularSelectRect(CGRect rect);
void RSAppendShapeToBezierPath(NSBezierPath *P, CGPoint p, NSInteger shape, CGFloat width, CGFloat rotation);


@interface RSGraphRenderer : OFObject
{
    RSDataMapper *_mapper;
    RSGraph *_graph;
    
    NSMutableArray *_axisLabels;  // visible, placed axis tick labels
#if !defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE
    NSShadow *_shadow;
#endif
    
    NSMutableDictionary *_pathCache;
}

- (id)initWithMapper:(RSDataMapper *)mapper;


// auto-adjusting whitespace
- (RSBorder)tickLabelWhitespaceBorderForAxis:(RSAxis *)A;
- (RSBorder)tickLabelWhitespaceBorder;
- (RSBorder)totalAutoWhitespaceBorder;


// laying out axis labels
- (void)updateWhitespace;
- (void)positionAllAxisLabels;
- (void)positionAxisTickLabels;
- (void)positionAxisTitles;
- (void)positionAxisEndLabels;
- (RSTextLabel *)nextLabel:(RSGraphElement *)GE;
- (RSTextLabel *)previousLabel:(RSGraphElement *)GE;


// laying out labels attached to objects
- (CGPoint)positionLabel:(RSTextLabel *)TL forOwner:(RSGraphElement *)e;
- (CGPoint)positionLabel:(RSTextLabel *)TL onLine:(RSLine *)L;
- (CGPoint)positionLabel:(RSTextLabel *)TL onVertex:(RSVertex *)V;
- (CGPoint)positionLabel:(RSTextLabel *)TL onFill:(RSFill *)F;
- (void)centerLabelInCanvas:(RSTextLabel *)TL;


// information about layout
- (NSArray *)visibleAxisLabels;


// converting Graph Element --> BezierPath
- (void)invalidateCache;
- (CGRect)rectFromBar:(RSVertex *)V width:(CGFloat)w;
//- (NSBezierPath *)pathFromVertex:(RSVertex *)V;
//- (NSBezierPath *)pathFromVertex:(RSVertex *)V newWidth:(CGFloat)width;
//- (NSBezierPath *)pathFromVertex:(RSVertex *)V newWidth:(CGFloat)width newShape:(NSInteger)shape;
- (NSBezierPath *)pathFromInteriorVertex:(RSVertex *)V newWidth:(CGFloat)width;

- (NSBezierPath *)pathFromLine:(RSLine *)L;
- (void)applyDashStyleForLine:(RSLine *)L toPath:(NSBezierPath *)P;

//- (NSBezierPath *)pathForCurvePointFromLine:(RSLine *)L;
//- (NSBezierPath *)pathForCurvePointFromLine:(RSLine *)L width:(CGFloat)w;
//- (NSBezierPath *)pathForCurvePointFromLine:(RSLine *)L atTime:(CGFloat)t width:(CGFloat)w;

- (NSBezierPath *)pathFromFill:(RSFill *)F;
- (NSBezierPath *)pathFromFill:(RSFill *)F closed:(BOOL)closed;

- (NSBezierPath *)pathFromAxis:(RSAxis *)A width:(CGFloat)width;
- (NSBezierPath *)pathFromAxis:(RSAxis *)A width:(CGFloat)width disableTicks:(BOOL)disableTicks;
- (NSBezierPath *)pathFromAxis:(RSAxis *)A width:(CGFloat)width startPoint:(CGPoint)startp disableTicks:(BOOL)disableTicks bezierPath:(NSBezierPath *)path;
- (NSBezierPath *)pathFromGrid:(RSGrid *)grid width:(CGFloat)width;


// High-level drawing methods:
//- (void)drawVertex:(RSVertex *)V;
- (void)drawLine:(RSLine *)L;
- (void)drawFill:(RSFill *)F;
- (void)drawFill:(RSFill *)F inProgress:(BOOL)inProgress;
- (void)drawLabel:(RSTextLabel *)T;
- (void)drawGridPoint:(RSDataPoint)gridPoint;
- (void)drawPosition:(RSDataPoint)p onAxis:(RSAxis *)A;
- (void)drawGrid;
- (void)drawAxis:(RSAxis *)A;
- (void)drawAxisLabelsExcept:(RSGraphElement *)selection;


// Drawing methods for interactive feedback
- (void)drawHalfSelectedPosition:(data_p)pos onAxis:(RSAxis *)axis;
- (void)drawMarginGuide:(NSUInteger)edge;
#if !defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE
- (void)drawFocusRingAroundRect:(CGRect)r;
#endif
- (void)drawSelected:(RSGraphElement *)selection windowIsKey:(BOOL)windowIsKey;
- (void)drawHalfSelected:(RSGraphElement *)halfSelection;
//- (void)drawCurvePointForHalfSelection:(RSGraphElement *)halfSelection overCurvePoint:(RSLine *)overCurvePoint;


// Highest-level graph drawing methods
- (void)drawBackgroundWithColor:(OQColor *)backgroundColor;
- (void)turnOnShadows;
- (void)turnOffShadows;
#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
- (void)informAllLabelsOfEffectiveScale:(CGFloat)scale;
#endif
- (void)drawAllGraphElementsExcept:(RSGraphElement *)selection;


// Experimental:
- (void)drawHistogram:(int *)bins;  // size of array specified by a -1 in first empty pos


// DEBUGGING:
#ifdef DEBUG
+ (void)drawCircleAt:(CGPoint)p;

#endif

@end
