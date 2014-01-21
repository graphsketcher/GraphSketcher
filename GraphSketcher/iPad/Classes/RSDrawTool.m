// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/iPad/Classes/RSDrawTool.m 200244 2013-12-10 00:11:55Z correia $

#import "RSDrawTool.h"

#import <GraphSketcherModel/RSFreehandStroke.h>
#import <GraphSketcherModel/RSStrokePoint.h>
#import <GraphSketcherModel/RSGraphElement.h>
#import <GraphSketcherModel/RSGraphEditor.h>
#import <GraphSketcherModel/RSUndoer.h>
#import <GraphSketcherModel/RSDataMapper.h>
#import <GraphSketcherModel/RSGraphRenderer.h>
#import <GraphSketcherModel/RSHitTester.h>
#import <GraphSketcherModel/RSHitTester-Snapping.h>
#import <GraphSketcherModel/RSVertex.h>
#import <GraphSketcherModel/RSConnectLine.h>
#import <GraphSketcherModel/RSGroup.h>
#import <GraphSketcherModel/RSConnectLine.h>

#import <OmniUI/OUIAppController.h>
#import <OmniUI/OUIDragGestureRecognizer.h>

#import "AppController.h"
#import "Document.h"
#import "RSFreehandDrawingView.h"
#import "GraphView.h"
#import "PulsingPointView.h"
#import "RSGraphElementView.h"

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/iPad/Classes/RSDrawTool.m 200244 2013-12-10 00:11:55Z correia $");

static NSString *DrawToolTapTapModeStartedMessage = nil;
static NSString *DrawToolNormalModeMessage = nil;

@interface RSDrawTool (/*Private*/)
@property (retain) RSGraphElement *touchedElement;
@end

@implementation RSDrawTool

+ (void)initialize;
{
    OBINITIALIZE;
    
    DrawToolNormalModeMessage = [NSLocalizedString(@"Draw a freehand line, or tap to create a point.", @"Explanotext when you enter draw mode.") copy];
    DrawToolTapTapModeStartedMessage = [NSLocalizedString(@"Tap to add more points; tap the last point again to finish.", @"Explanotext when you enter tap-tap sub-mode of draw mode.") copy];
}

#pragma mark -
#pragma mark Private

- (void)_setupDrawingView;
{
    if (!_drawingView) {
        _drawingView = [[RSFreehandDrawingView alloc] initWithFrame:CGRectZero];
        _drawingView.freehandStroke = _freehand;
    }
    
    // size to viewport
    GraphView *graphView = self.view;
    CGRect canvasRect = [graphView bounds];
    CGRect superRect = [graphView.superview bounds];
    _drawingView.frame = CGRectIntersection(superRect, canvasRect);
    
    [graphView addSubview:_drawingView];
}

- (NSArray *)_verticesFromSegmentedStroke:(NSArray *)segments;
{
    NSMutableArray *A = [NSMutableArray array];
    CGPoint endp;

    RSVertex *V;
    BOOL prevEndUsed = YES;
    for (NSArray *segment in segments)
    {
        if (![segment count]) {
            OBASSERT_NOT_REACHED("empty stroke");
            continue;
        }
        
        CGPoint cp = [RSFreehandStroke curvePointForSegment:segment];  // "curve point"
        endp = [(RSStrokePoint *)[segment lastObject] point];  // "end point"
        
        // if straight segment, use mid-point
        if ([RSFreehandStroke segment:segment isStraightWithCurvePoint:cp]) {
            //NSLog(@"straight");
            // Only add the mid-point if there is a previous segment.  This enables drawing simple straight lines.
            if (!prevEndUsed) {
                CGPoint midp = [RSFreehandStroke midPointForSegment:segment];
                V = [[RSVertex alloc] initWithGraph:self.editor.graph];
                [V setPosition:[self.editor.mapper convertToDataCoords:midp]];
                [A addObject:V];
                [V release];
            }
            
            prevEndUsed = NO;
        }
        // if curved segment, use just curve point
        else {
            //NSLog(@"curved");
            V = [[RSVertex alloc] initWithGraph:self.editor.graph];
            [V setPosition:[self.editor.mapper convertToDataCoords:cp]];
            [A addObject:V];
            [V release];
            
            prevEndUsed = NO;
        }
    }
    // make end vertex if necessary
    if (!prevEndUsed) {
        V = [[RSVertex alloc] initWithGraph:self.editor.graph];
        [V setPosition:[self.editor.mapper convertToDataCoords:endp]];
        [A addObject:V];
        [V release];
    }
    
    return A;
}

- (RSConnectLine *)_addSegmentedStroke:(NSArray *)segments toLine:(RSConnectLine *)CL;
{
    NSArray *A = [self _verticesFromSegmentedStroke:segments];
    for (RSVertex *V in A) {
        [CL addVertexAtEnd:V];
    }
    [CL setConnectMethod:RSConnectCurved];
    
    return CL;
}


#pragma mark -
#pragma mark RSTool

- (id)initWithView:(GraphView *)view;
{
    if (!(self = [super initWithView:view]))
        return nil;
    
    _drawingView = nil;
    _freehand = nil;
    
    return self;
}

- (void)dealloc;
{
    [_drawStrokeGR release];
    [_moveGR release];
    
    [_fingerView removeFromSuperview];
    [_fingerView release];
    [_drawingView release];
    self.freehand = nil;
    [_touchedElement release];
    [_leftToolbarItems release];
    [_rightToolbarItems release];
    [_pulsingVertex release];
    [_vertexInProgress release];
    [_lineInProgress release];
    [_vertexCluster release];
    
    [super dealloc];
}

- (void)activate;
{
    [super activate];
    
    [self.view clearSelection];
    
    if (!_drawStrokeGR) {
        _drawStrokeGR = [[OUIDragGestureRecognizer alloc] initWithTarget:self action:@selector(drawStrokeGesture:)];
        _drawStrokeGR.holdDuration = 0;
    }
    [self.view addGestureRecognizer:_drawStrokeGR];
    
//    if (!_tapGR) {
//        _tapGR = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapGesture:)];
//        // use default parameters: 1 tap, 1 touch
//        //[_tapGR requireGestureRecognizerToFail:_doubleTapGR];
//    }
//    [self.view addGestureRecognizer:_tapGR];
    
    if (!_moveGR) {
        _moveGR = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(moveGesture:)];
        _moveGR.maximumNumberOfTouches = 1;
    }
    [self.view addGestureRecognizer:_moveGR];
    
//    // TODO: better way to handle this?
//    UIScrollView *scrollView = (UIScrollView *)self.view.superview;
//    for (UIGestureRecognizer *recognizer in scrollView.gestureRecognizers) {
//        if ([recognizer isKindOfClass:[UIPanGestureRecognizer class]]) {
//            recognizer.enabled = NO;
//        }
//    }
    
    // Set up the right gesture recognizers, etc.
    [self resetState];
}

- (void)deactivate;
{
    [self.view removeGestureRecognizer:_drawStrokeGR];
//    [self.view removeGestureRecognizer:_tapGR];
    [self.view removeGestureRecognizer:_moveGR];
    
//    UIScrollView *scrollView = (UIScrollView *)self.view.superview;
//    for (UIGestureRecognizer *recognizer in scrollView.gestureRecognizers) {
//        if ([recognizer isKindOfClass:[UIPanGestureRecognizer class]]) {
//            if (!recognizer.enabled)
//                recognizer.enabled = YES;
//        }
//    }
    
    
    // End line-in-progress, if any
    if (self.lineInProgress) {
        _shouldEndLine = YES;
        [self tapTouchEnded];
    }
    
    [self resetState];
    
    [_drawingView removeFromSuperview];
    [_drawingView release];
    _drawingView = nil;
    
    [_fingerView release];
    _fingerView = nil;
    
    [super deactivate];
}

- (NSArray *)leftBarButtonItems;
{
    if (_leftToolbarItems == nil) {
        OUIDocumentAppController *controller = [OUIDocumentAppController controller];
        NSArray *items = @[
            [controller undoBarButtonItem]
        ];
        _leftToolbarItems = [items copy];
    }
    
    return _leftToolbarItems;
}

- (NSArray *)rightBarButtonItems;
{
    if (_rightToolbarItems == nil) {
        OUIDocumentAppController *controller = [OUIDocumentAppController controller];
        NSArray *items = @[
            [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:controller action:@selector(_handMode:)] autorelease]
        ];
        _rightToolbarItems = [items copy];
    }
    
    return _rightToolbarItems;
}


- (NSString *)toolbarTitle;
{
    return (_pulsing ? DrawToolNormalModeMessage : DrawToolTapTapModeStartedMessage);
}

- (void)graphEditorNeedsDisplay:(RSGraphEditor *)editor;
{
    // Don't redraw the graph while we're drawing a line
    if (self.freehand)
        return;
    
    if (self.vertexInProgress || self.lineInProgress) {
        [self.editor.mapper resetCurveCache];
        [self.editor.renderer invalidateCache];
        [_drawingView setNeedsDisplay];
        
        return;
    }
    
    [super graphEditorNeedsDisplay:editor];
}

- (BOOL)undoLastChange;
{
    if (!self.pulsingVertex)
        return NO;
    
    if ( !self.lineInProgress || [self.lineInProgress vertexCount] <= 1 ) {
        [self resetState];
        return YES;
    }
    
    // If more than one point has been added, remove the last one.
    if ([self.lineInProgress vertexCount] > 1) {
        RSVertex *lastV = (RSVertex *)[[self.lineInProgress vertices] lastElement];
        [self.lineInProgress dropVertex:lastV registeringUndo:NO];
        
        RSVertex *remainingV = (RSVertex *)[[self.lineInProgress vertices] lastElement];
        self.pulsingVertex.position = remainingV.position;
        _pulsingView = [PulsingPointView pulsingPointViewForView:self.view element:self.pulsingVertex];
        
        if ([self.lineInProgress vertexCount] == 1) {
            [self.lineInProgress invalidate];
            self.lineInProgress = nil;
        }
        
        return YES;
    }
    
    return NO;  // nothing changed
}

- (void)completedOperation;
{
    // If an object was added, select it and switch back to hand mode
    if (self.addedElement) {
        [super completeOperationWithElement:self.addedElement];
    }
    
    // If nothing was added, just reset the tool so the user can try again
    else {
        [self resetState];
    }
}


#pragma mark -
#pragma mark Class methods

@synthesize freehand = _freehand;
- (void)setFreehand:(RSFreehandStroke *)newFreehand;
{
    if (_freehand == newFreehand)
        return;
    
    [_freehand release];
    _freehand = [newFreehand retain];
    
    _drawingView.freehandStroke = _freehand;
}

@synthesize touchedElement = _touchedElement;
@synthesize pulsingVertex = _pulsingVertex;
@synthesize vertexInProgress = _vertexInProgress;
@synthesize lineInProgress = _lineInProgress;
@synthesize vertexCluster = _vertexCluster;
@synthesize addedElement = _addedElement;


- (void)resetState;
{
    GestureLog(@"drawTool resetState");
    
    _pulsing = NO;
    _shouldEndLine = NO;
    
    self.pulsingVertex = nil;
    self.vertexInProgress = nil;
    [self.lineInProgress invalidate];
    self.lineInProgress = nil;
    _drawingView.lineInProgress = nil;
    _drawingView.snappedToElement = nil;
    [_drawingView setNeedsDisplay];
    
    self.vertexCluster = nil;
    
    self.touchedElement = nil;
    self.freehand = nil;
    self.addedElement = nil;
    
    if (_pulsingView) {
        [_pulsingView endEffect];
        _pulsingView = nil;
    }
    
    [_drawingView hideGridSnapPoint];
    
    _drawStrokeGR.enabled = YES;
    _moveGR.enabled = NO;
    
    // We've either completed or discarded a line. Close off any undo group for this multi-event operation
    [[[AppController controller] document] finishUndoGroup];
    
    [[[AppController controller] undoBarButtonItem] setEnabled:self.editor.undoer.undoManager.canUndo];
    
    [super graphEditorNeedsDisplay:self.editor];
}

- (void)addLatestVertex;
{
    if (!self.vertexInProgress) {
        return;
    }
    
    // If previously tapped to start a straight-edged line
    if (_pulsing) {
        if (!self.lineInProgress) {
            self.lineInProgress = [[[RSConnectLine alloc] initWithGraph:self.editor.graph] autorelease];
            //[self.lineInProgress setConnectMethod:RSConnectStraight];
            [self.lineInProgress addVertexAtEnd:self.pulsingVertex];
            _drawingView.lineInProgress = self.lineInProgress;
        }
        [self.lineInProgress addVertexAtEnd:self.vertexInProgress];
    } else {
        [_fingerView.graphView updateNavigationItem];
        [[[AppController controller] undoBarButtonItem] setEnabled:YES];
    }

    self.pulsingVertex = self.vertexInProgress;
    self.vertexInProgress = nil;
    
    _pulsing = YES;
    [_drawingView setNeedsDisplay];
}

- (void)tapTouchEnded;
// i.e. A finger was lifted without having drawn a stroke.
{
    if (!_pulsing) {
        NSLog(@"Does this ever happen?");
        return;
    }
    
    // Ending the tap-tap sequence
    if (_shouldEndLine) {
        if (self.lineInProgress) {
            GestureLog(@"Adding line in progress");
            [self.editor.graph addLine:self.lineInProgress];
            self.addedElement = [self.lineInProgress groupWithVertices];
            self.lineInProgress = nil;
        }
        // If no line in progress, just a point
        else {
            GestureLog(@"Adding vertex at point %@", NSStringFromRSDataPoint(self.pulsingVertex.position));
            [self.pulsingVertex setShape:RS_CIRCLE];
            [self.editor.graph addVertex:self.pulsingVertex];
            self.addedElement = self.pulsingVertex;
        }
        
        [self completedOperation];
        return;
    }
    
    // Starting or continuing a tap-tap sequence
    _drawStrokeGR.enabled = NO;
    _moveGR.enabled = YES;
    
    [_pulsingView updateFrameWithDuration:0];
}


#pragma mark -
#pragma mark Touch handling

- (BOOL)gestureRecognizerInProgress;
{
    if (_drawStrokeGR.state == UIGestureRecognizerStateBegan || _drawStrokeGR.state == UIGestureRecognizerStateChanged || _moveGR.state == UIGestureRecognizerStateBegan || _moveGR.state == UIGestureRecognizerStateChanged ) {
        return YES;
    }
    
    return NO;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event;
{
    [super touchesBegan:touches withEvent:event];
    
    if ([touches count] != 1) {
        return;
    }
    
    if ([self gestureRecognizerInProgress]) {
        return;
    }
    
    GraphView *view = (GraphView *)self.view;
    UITouch *touch = [touches anyObject];
    _touchBeganTimestamp = touch.timestamp;
    CGPoint touchPoint = [touch locationInView:view];
    CGPoint p = [view viewPointForTouchPoint:touchPoint];
    GestureLog(@"drawTool touches began at %@", NSStringFromCGPoint(p));
    
    // If previously tapped to start a straight-edged line
    if (_pulsing) {
        // If hit the pulsing vertex
        if ([view.editor.hitTester hitTestPoint:p onVertex:self.pulsingVertex].hit) {
            //[self.view displayTemporaryOverlayWithString:@"Hit pulsing vertex" avoidingTouchPoint:[touch locationInView:self.view]];
            _shouldEndLine = YES;            
            return;
        }
    }
    
    if (!self.vertexInProgress) {
        self.vertexInProgress = [[[RSVertex alloc] initWithGraph:self.editor.graph] autorelease];
    }
    
    [self _setupDrawingView];
    
    [self.vertexInProgress setPosition:[view.editor.mapper convertToDataCoords:p]];
    self.touchedElement = [view.editor.hitTester snapVertex:self.vertexInProgress fromPoint:p];
    
    if (self.touchedElement) {
        CGPoint elementPoint = [view.editor.mapper convertToViewCoords:self.vertexInProgress.position];
        //elementPoint = [view convertPointToRenderingSpace:elementPoint];
        _fingerOffset = CGPointMake(p.x - elementPoint.x, p.y - elementPoint.y);
        
        // TODO: Snap animation?
        _drawingView.snappedToElement = self.touchedElement;
        [_drawingView setNeedsDisplay];
    }
    else {  // Nothing was hit
        _fingerOffset = CGPointMake(0, 0);
    }
    
    // snap-to-grid visualization
    _drawingView.gridSnapPoint = self.vertexInProgress.position;
    
    [_pulsingView endEffect];
    
    if (!_fingerView) {
        _fingerView = [[RSGraphElementView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
        [self.view addSubview:_fingerView];
    }
    _fingerView.graphElement = self.vertexInProgress;
    [_fingerView makeFingerSize];
    
    if (_pulsing) {
        [self addLatestVertex];
        [self.view displayTextOverlayForVertex:self.pulsingVertex];
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event;
{
    [super touchesMoved:touches withEvent:event];
    
    if ([self gestureRecognizerInProgress]) {
        return;
    }
    
    [_fingerView updateFrame];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event;
// If we get this, no gesture recognizers were activated
{
    GestureLog(@"drawTool touches ended");
    [super touchesEnded:touches withEvent:event];
    
    if ([self gestureRecognizerInProgress]) {
        return;
    }
    
    [self addLatestVertex];
    _pulsingView = [PulsingPointView pulsingPointViewForView:self.view element:self.pulsingVertex];
    [self tapTouchEnded];
    
    [_fingerView makeNormalSizeAndHide:YES];
    
    [_drawingView hideGridSnapPoint];
    [self.view hideTextOverlay];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event;
// This simply means that a gesture recognizer took over handling the touch events
{
    GestureLog(@"drawTool touches cancelled");
    [super touchesCancelled:touches withEvent:event];
    
    [_fingerView hideAnimated:NO];
    //[self reset];
}


#pragma mark -
#pragma mark Gesture handling

- (void)drawStrokeGesture:(OUIDragGestureRecognizer *)gestureRecognizer;
{
    if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {
        GestureLog(@"drawStroke gesture began");
        
        return;
    }
    
    if (gestureRecognizer.state == UIGestureRecognizerStateChanged) {
        //NSLog(@"drawStroke gesture changed");
        //NSLog(@"velocity: %f", gestureRecognizer.velocity);
        
        // Don't do anything until overcoming hysteresis
        if (!gestureRecognizer.overcameHysteresis) {
            return;
        }
        
        if (!self.freehand) {
            // Set up beginning of stroke
            self.freehand = [[[RSFreehandStroke alloc] init] autorelease];

            CGPoint newPoint = [self.editor.mapper convertToViewCoords:self.vertexInProgress.position];
            [self.freehand addStrokePoint:newPoint atTime:_touchBeganTimestamp];
            
            _drawingView.color = [[self vertexInProgress] color];
            _drawingView.thickness = [[self vertexInProgress] width];
            
            _drawingView.gridSnapPoint = self.vertexInProgress.position;
        
            // Don't want the pulsing view anymore
            if (_pulsingView) {
                [_pulsingView endEffect];
                _pulsingView = nil;
            }
            
            [self.editor.undoer.undoManager disableUndoRegistration];
        }
        
        CGPoint p = [self.view viewPointForTouchPoint:[gestureRecognizer locationInView:self.view]];
        CGPoint newPoint = CGPointMake(p.x - _fingerOffset.x,
                                       p.y - _fingerOffset.y);
        
        [self.freehand addStrokePoint:newPoint atTime:gestureRecognizer.latestTimestamp - _touchBeganTimestamp];
        
        if (!self.pulsingVertex) {
            self.pulsingVertex = [[[RSVertex alloc] initWithGraph:self.editor.graph] autorelease];
        }
        [self.pulsingVertex clearSnappedTo];
        _drawingView.snappedToElement = [self.editor.hitTester snapVertex:self.pulsingVertex fromPoint:newPoint];
        _drawingView.gridSnapPoint = self.pulsingVertex.position;
        
        return;
    }
    
    if (gestureRecognizer.state == UIGestureRecognizerStateEnded) {
        GestureLog(@"drawStroke gesture ended with %ld stroke points", [[self.freehand stroke] count]);
        
        // If never overcame hysteresis, treat it as a tap.
        if (!gestureRecognizer.overcameHysteresis) {
            [self addLatestVertex];
            _pulsingView = [PulsingPointView pulsingPointViewForView:self.view element:self.pulsingVertex];
            [self tapTouchEnded];
            
            [_fingerView makeNormalSizeAndHide:YES];
            [_drawingView hideGridSnapPoint];
            
            return;
        }
        
        
        // Clean up from drawing freehand stroke
        [self.pulsingVertex clearSnappedTo];
        [self.pulsingVertex invalidate];
        [self.editor.undoer.undoManager enableUndoRegistration];
        
        if ([[self.freehand stroke] count] > 2) {
            
            // Segment the stroke and add to graph
            [self.freehand performSegmentation];
            RSConnectLine *CL = [[RSConnectLine alloc] initWithGraph:self.editor.graph];
            
            [CL addVertexAtEnd:self.vertexInProgress];
            
            [self _addSegmentedStroke:self.freehand.segments toLine:CL];
            
            // snap the end of the line
            RSVertex *endV = [CL endVertex];
            CGPoint endPoint = [(RSStrokePoint *)[[self.freehand stroke] lastObject] point];
            [self.editor.hitTester snapVertex:endV fromPoint:endPoint];
            
            [self.editor.graph addElement:CL];
            self.addedElement = [CL groupWithVertices];
            [CL release];
        }
        
        [self completedOperation];
        
        return;
    }
    
    if (gestureRecognizer.state == UIGestureRecognizerStateCancelled) {
        GestureLog(@"drawStroke gesture cancelled");
        [self resetState];
        
        [self.editor.undoer.undoManager enableUndoRegistration];
        return;
    }
}

//- (void)tapGesture:(UITapGestureRecognizer *)gestureRecognizer;
//{
//    if (gestureRecognizer.state == UIGestureRecognizerStateRecognized) {
//        GestureLog(@"tap gesture recognized");
//        //_activeRecognizer = gestureRecognizer;
//        
//        [self addLatestVertex];
//        _pulsingView = [PulsingPointView pulsingPointViewForView:self.view element:self.pulsingVertex];
//        [self tapTouchEnded];
//        
//        [_fingerView makeNormalSizeAndHide:YES];
//        
//        return;
//    }
//}

- (void)moveGesture:(UIPanGestureRecognizer *)gestureRecognizer;
{
    if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {
        [self.editor.undoer.undoManager disableUndoRegistration];
        
        _drawingView.gridSnapPoint = self.pulsingVertex.position;
        
        [self addLatestVertex];
        _pulsingView = [PulsingPointView pulsingPointViewForView:self.view element:self.pulsingVertex];
        
        self.vertexCluster = [self.pulsingVertex vertexCluster];
        
        [self.view displayTextOverlayForVertex:self.pulsingVertex];
        
        return;
    }
    
    if (gestureRecognizer.state == UIGestureRecognizerStateChanged) {
        GestureLog(@"move gesture changed");
        CGPoint p = [self.view viewPointForTouchPoint:[gestureRecognizer locationInView:self.view]];
        
        // Snap
        // start by clearing any snap-constraints, because user dragging overrides those
        [self.pulsingVertex setVertexCluster:self.vertexCluster];
        
        self.touchedElement = [self.editor.hitTester snapVertex:self.pulsingVertex fromPoint:p];
        _drawingView.snappedToElement = self.touchedElement;
        [self.editor.hitTester updateSnappedTosForVertices:[NSArray arrayWithObject:self.pulsingVertex]];
        
        _drawingView.gridSnapPoint = self.pulsingVertex.position;
        
        [_drawingView setNeedsDisplay];
        [_pulsingView updateFrameWithDuration:0];
        
        // Don't end the line if the user was dragging the point
        CGPoint translation = [gestureRecognizer translationInView:nil];
        if (hypotf(translation.x, translation.y) > 10) {
            _shouldEndLine = NO;
        }
        
        [self.view displayTextOverlayForVertex:self.pulsingVertex];
        
        return;
    }
    
    if (gestureRecognizer.state == UIGestureRecognizerStateEnded || gestureRecognizer.state == UIGestureRecognizerStateCancelled) {
        [self.editor.undoer.undoManager enableUndoRegistration];
        [self tapTouchEnded];
        
        [_drawingView hideGridSnapPoint];
        [self.view hideTextOverlay];
        
        return;
    }
}


@end
