// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/iPad/Classes/RSFreehandDrawingView.m 200244 2013-12-10 00:11:55Z correia $

#import "RSFreehandDrawingView.h"

#import <GraphSketcherModel/RSFreehandStroke.h>
#import <GraphSketcherModel/RSStrokePoint.h>
#import <GraphSketcherModel/RSGraphEditor.h>
#import <GraphSketcherModel/RSGraphRenderer.h>
#import <GraphSketcherModel/RSConnectLine.h>
#import <OmniQuartz/OQColor.h>
#import "GraphView.h"

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/iPad/Classes/RSFreehandDrawingView.m 200244 2013-12-10 00:11:55Z correia $");

@implementation RSFreehandDrawingView

- (id)initWithFrame:(CGRect)aRect;
{
    if (!(self = [super initWithFrame:aRect]))
        return nil;
    
    self.userInteractionEnabled = NO;
    self.opaque = NO;
    self.contentMode = UIViewContentModeRedraw;
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    
    self.color = [OQColor redColor];
    self.thickness = 4;
    
    [self hideGridSnapPoint];
    
    return self;
}

- (void)dealloc;
{
    [_freehand release];
    [_color release];
    [_lineInProgress release];
    [super dealloc];
}

@synthesize freehandStroke = _freehand;
- (void)setFreehandStroke:(RSFreehandStroke *)newStroke;
{
    if (_freehand == newStroke) {
        return;
    }
    
    if (_freehand) {
        [_freehand removeObserver:self forKeyPath:@"stroke"];
        [_freehand release];
    }
    _freehand = [newStroke retain];
    if (_freehand) {
        [_freehand addObserver:self forKeyPath:@"stroke" options:NSKeyValueObservingOptionNew context:NULL];
    }
    
    [self setNeedsDisplay];
}

@synthesize color = _color;
@synthesize thickness = _thickness;

@synthesize lineInProgress = _lineInProgress;
@synthesize snappedToElement = _snappedToElement;

@synthesize gridSnapPoint = _gridSnapPoint;

- (void)hideGridSnapPoint;
{
    if (_gridSnapPoint.x == DBL_MIN)
        return;
    
    _gridSnapPoint = RSDataPointMake(DBL_MIN, DBL_MIN);
    [self setNeedsDisplay];
}


#pragma mark -
#pragma mark KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context;
{
    if (object == _freehand) {
        [self setNeedsDisplay];
    }
}


#pragma mark -
#pragma mark Rendering

- (CGAffineTransform)transformToLayerSpace;
{
    CGRect frame = self.frame;
    
    CGAffineTransform xform = CGAffineTransformIdentity;
    xform = CGAffineTransformTranslate(xform, -frame.origin.x, -frame.origin.y);
    
    return xform;
}

- (void)establishTransformToLayerSpace;
{
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextConcatCTM(ctx, [self transformToLayerSpace]);
}

- (void)drawRawStrokeUsingWidth:(CGFloat)width color:(OQColor *)color;
// Draws raw pen input
{
    // make a new empty path:
    NSBezierPath *P = [NSBezierPath bezierPath];
    
    // construct path:
    NSEnumerator *E = [_freehand.stroke objectEnumerator];
    RSStrokePoint *sp = [E nextObject];
    [P moveToPoint:[sp point]];
    while ((sp = [E nextObject])) {
	[P lineToPoint:[sp point]];
    }
    
    // apply formatting
    [P setLineWidth:width];
    [color set];
    
    // draw
    [P stroke];
    
    // DEBUGGING
    //NSRect strokeBounds = [self boundingRectOfStroke];
    //[[NSColor redColor] set];
    //[NSBezierPath strokeRect:strokeBounds];
}

- (void)drawLineInProgress;
{
    GraphView *graphView = (GraphView *)self.superview;
    [graphView.editor.renderer drawLine:self.lineInProgress];
}

- (void)drawRect:(CGRect)rect;
{
    [self establishTransformToLayerSpace];
    
    GraphView *graphView = (GraphView *)self.superview;
    [graphView establishTransformToRenderingSpace:UIGraphicsGetCurrentContext()];
    
    // snap-to-grid visualization
    if (_gridSnapPoint.x != DBL_MIN) {
        [graphView.editor.renderer drawGridPoint:_gridSnapPoint];
    }
    
    if (self.snappedToElement) {
        [graphView.editor.renderer drawHalfSelected:self.snappedToElement];
    }
    
    if (_lineInProgress) {
        [self drawLineInProgress];
    }
    
    if (_freehand) {
        [self drawRawStrokeUsingWidth:self.thickness color:self.color];
    }
}

@end
