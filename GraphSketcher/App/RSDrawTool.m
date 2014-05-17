// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "RSDrawTool.h"

#import <GraphSketcherModel/RSGraphElement.h>
#import <GraphSketcherModel/RSVertex.h>
#import <GraphSketcherModel/RSLine.h>
#import <GraphSketcherModel/RSGroup.h>
#import <GraphSketcherModel/RSDataMapper.h>
#import <GraphSketcherModel/RSConnectLine.h>
#import <GraphSketcherModel/RSGraphRenderer.h>
#import <GraphSketcherModel/RSGraphElement-Rendering.h>
#import <GraphSketcherModel/RSUndoer.h>
#import <GraphSketcherModel/RSUnknown.h>
#import <GraphSketcherModel/RSGraphEditor.h>
#import <GraphSketcherModel/RSHitTester.h>
#import <GraphSketcherModel/RSHitTester-Snapping.h>
#import <GraphSketcherModel/RSFreehandStroke.h>
#import <GraphSketcherModel/RSStrokePoint.h>

#import "RSSelector.h"
#import "RSDrawTool.h"
#import "RSMode.h"
#import "RSGraphView.h"


@interface RSDrawTool (/*Private*/)
- (BOOL)endStroke;
- (void)drawRawStrokeUsingWidth:(CGFloat)width;
- (void)drawRawStrokeUsingWidth:(CGFloat)width color:(NSColor *)color;
- (RSGroup *)verticesFromSegmentedStroke;
- (void)addMostRecentStrokeToLine:(RSConnectLine *)CL;
- (RSGraphElement *)lineSegmentsFromStrokeWithStartVertex:(RSVertex *)startVertex;
- (void)drawSegmentedStrokeUsingStartVertex:(RSVertex *)startVertex;

@property (nonatomic, retain) RSConnectLine *lineInProgress;
@end

@implementation RSDrawTool


///////////////
#pragma mark -
#pragma mark Stroke recognition
///////////////


- (BOOL)endStroke;
// Returns YES if the stroke was big enough to add line segments.
{
    _freehand.strokeEnded = YES;
    LogP(@"%d digitized points", [[_freehand stroke] count]);

    // The big guns: stroke segmentation!
    [_freehand performSegmentation];


    // Create a line, but only if the stroke is big enough (otherwise, just use the original point created on mouseDown)
    CGRect strokeBounds = [_freehand boundingRect];
    CGFloat hitOffset = [[OFPreferenceWrapper sharedPreferenceWrapper] floatForKey:@"SelectionSensitivity"];

    if( CGRectGetWidth(strokeBounds) > hitOffset || CGRectGetHeight(strokeBounds) > hitOffset ) {
        // Add the line segments just created:
        [self addMostRecentStrokeToLine:_lineInProgress];
        // Always make it curved
        [_lineInProgress setConnectMethod:RSConnectCurved];
        
        // Potentially snap to half-selection:
        if( [[_s halfSelection] isKindOfClass:[RSVertex class]] ) {
            [[_lineInProgress endVertex] setPosition:[[_s halfSelection] position]];
        }
        
        // clean up
        [_s setHalfSelection:nil];
        
        return YES;
    }
    return NO;
}

- (void)drawRawStrokeUsingWidth:(CGFloat)width {
    [self drawRawStrokeUsingWidth:width color:[NSColor redColor]];
}
- (void)drawRawStrokeUsingWidth:(CGFloat)width color:(NSColor *)color {
    // Draws raw pen input
    NSBezierPath *P;
    NSEnumerator *E;
    RSStrokePoint *sp;
    
    // make a new empty path:
    P = [NSBezierPath bezierPath];
    
    // construct path:
    E = [_freehand.stroke objectEnumerator];
    sp = [E nextObject];
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

- (RSGroup *)verticesFromSegmentedStroke;
{
    RSGroup *G = [RSGroup groupWithGraph:_graph];
    NSPoint endp;
    
    RSVertex *V;
    BOOL prevEndUsed = YES;
    for (NSArray *segment in _freehand.segments)
    {
	if (![segment count]) {
	    OBASSERT_NOT_REACHED("empty stroke");
	    continue;
	}
	
	NSPoint cp = [RSFreehandStroke curvePointForSegment:segment];  // "curve point"
	endp = [(RSStrokePoint *)[segment lastObject] point];  // "end point"
	
	// if straight segment, use mid-point
	if ([RSFreehandStroke segment:segment isStraightWithCurvePoint:cp]) {
	    //NSLog(@"straight");
	    // Only add the mid-point if there is a previous segment.  This enables drawing simple straight lines.
	    if (!prevEndUsed) {
		NSPoint midp = [RSFreehandStroke midPointForSegment:segment];
		V = [[RSVertex alloc] initWithGraph:_graph];
		[V setPosition:[_mapper convertToDataCoords:midp]];
		[G addElement:V];
		[V release];
	    }
//	    V = [[RSVertex alloc] initWithGraph:_graph];
//	    [V setPosition:[_mapper convertToDataCoords:cp]];
//	    [G addElement:V];
//	    [V release];
//	    
//	    V = [[RSVertex alloc] initWithGraph:_graph];
//	    [V setPosition:[_mapper convertToDataCoords:endp]];
//	    [G addElement:V];
//	    [V release];
	    
	    prevEndUsed = NO;
	}
	// if curved segment, use just curve point
	else {
	    //NSLog(@"curved");
	    V = [[RSVertex alloc] initWithGraph:_graph];
	    [V setPosition:[_mapper convertToDataCoords:cp]];
	    [G addElement:V];
	    [V release];
	    
	    prevEndUsed = NO;
	}
    }
    // make end vertex if necessary
    if (!prevEndUsed) {
	V = [[RSVertex alloc] initWithGraph:_graph];
	[V setPosition:[_mapper convertToDataCoords:endp]];
	[G addElement:V];
	[V release];
    }
    
    return G;
}

- (void)addMostRecentStrokeToLine:(RSConnectLine *)CL;
{
    RSGroup *G = [self verticesFromSegmentedStroke];
    [CL addVerticesAtEnd:G];
}


- (RSGraphElement *)lineSegmentsFromStrokeWithStartVertex:(RSVertex *)startVertex {
    RSGroup *G = [RSGroup groupWithGraph:_graph];
    
    [G addElement:startVertex];
    [G addElement:[self verticesFromSegmentedStroke]];
    
    // make the line
    RSConnectLine *CL = [RSConnectLine connectLineWithGraph:_graph vertices:[[G copy] autorelease]];
    [CL setConnectMethod:RSConnectCurved];
    [G addElement:CL];
    
    return G;
}

- (void)drawSegmentedStrokeUsingStartVertex:(RSVertex *)startVertex {
    // Draws segmented stroke as lines
    NSBezierPath *P;
    RSGroup *G = (RSGroup *)[self lineSegmentsFromStrokeWithStartVertex:startVertex];
    
    for (RSGraphElement *GE in [G elements])
    {
	if( [GE isKindOfClass:[RSVertex class]] ) {
	    if( SKETCH_TEST_MODE == 1 ) {
		P = [(RSVertex *)GE pathUsingMapper:_mapper newWidth:8];
	    }
	    else {
		P = [(RSVertex *)GE pathUsingMapper:_mapper];
	    }
	    
	    // apply formatting
	    [[[startVertex color] colorUsingColorSpaceName:NSCalibratedRGBColorSpace] set];
	    
	    // draw
	    [P fill];
	}
	else if( [GE isKindOfClass:[RSLine class]] ) {
	    P = [_renderer pathFromLine:(RSLine *)GE];
            [_renderer applyDashStyleForLine:(RSLine *)GE toPath:P];
	    
	    // apply formatting
	    if( SKETCH_TEST_MODE == 1 ) {
		[P setLineWidth:2];
		[[[[startVertex color] colorUsingColorSpaceName:NSCalibratedRGBColorSpace] colorWithAlphaComponent:0.8f] set];
	    }
	    else if( [[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:@"SegmentStrokesWhileDrawing"] ) {
		[P setLineWidth:[startVertex width]];
		[[[[startVertex color] colorUsingColorSpaceName:NSCalibratedRGBColorSpace] colorWithAlphaComponent:0.2f] set];
	    }
	    else {
		[P setLineWidth:[startVertex width]];
		[[[startVertex color] colorUsingColorSpaceName:NSCalibratedRGBColorSpace] set];
	    }
	    // draw
	    [P stroke];
	}
	else {
	    // don't know how to draw
	    NSLog(@"Unknown object created by stroke segmenter");
	}
    }
}


///////////////////////
#pragma mark -
#pragma mark Tool logistics
///////////////////////

- (void)resetState;
{
    // create a new line to build:
    self.lineInProgress = [[[RSConnectLine alloc] initWithGraph:_graph] autorelease];
    
    // Clean vertex clusters.  We have to be really careful to always do this before the model is saved to file, because the _newDrawVertex is never itself actually saved to file, but will show up in the snapped-to array of other vertices in a cluster that it is temporarily in.
    [_newDrawVertex clearSnappedTo];
    
    // reset history:
    _prevDrawVertex = nil;
    _newDrawObject = nil;
    _firstClickElement = nil;
    
    [_view setNeedsDisplay:YES];
}

- (void)discardEditing;
{
    // If a line was started, clear out its parent and snapped-to references because it will never be created.
    if( ![_lineInProgress isEmpty] ) {
        [_lineInProgress clearSnappedTos];
        [_lineInProgress removeAllVertices];
    }
    
    // Reset the tool
    [self resetState];
}

- (BOOL)commitEditing;
{
    // Be sure to complete stroke segmentation if, say, the tool mode was changed in the middle of a mouse dragging sequence.
    if (!_freehand.strokeEnded && [_m mouseDragging]) {
        [self endStroke];
    }
    
    // Don't do anything if a new line hasn't even been started
    if( [_lineInProgress isEmpty] ) {
        [self resetState];
        return YES;
    }
    
    // If the new line is a new single vertex, then draw a point there.
    if( [_lineInProgress isVertex] ) {
        // Add the original mouse-down vertex to the graph and select it:
        RSVertex *newVertex = [_lineInProgress startVertex];
        [_graph addElement:newVertex];
        [_s setSelection:newVertex];
        
        // make the point a data point
        [newVertex setShape:[[OFPreferenceWrapper sharedPreferenceWrapper] integerForKey:@"DefaultVertexShape"]];
        
        [_u setActionName:NSLocalizedStringFromTable(@"Draw Point", @"UndoActions", @"Undo action name")];
        
        // Clear out the line components:
        [_lineInProgress removeAllVertices];
        
        [self resetState];
        
        return YES;
    }
    
    // If the line is more than just a single vertex, add the whole line to the graph and select it.
    [_graph addElement:_lineInProgress];
    [_u setActionName:NSLocalizedStringFromTable(@"Draw Line", @"UndoActions", @"Undo action name")];
    [_s setSelection:[_lineInProgress groupWithVertices]];
    
    [self resetState];
    
    return YES;
}




////////////////////////////////////////
#pragma mark -
#pragma mark RSTool subclass
///////////

@synthesize lineInProgress = _lineInProgress;

- (void)initState;
{
    self.lineInProgress = [[[RSConnectLine alloc] initWithGraph:_graph] autorelease];
    _newDrawVertex = [[RSVertex alloc] initWithGraph:_graph];
    [_u addExemptObject:_newDrawVertex];
    
    _prevDrawVertex = nil;
    _newDrawObject = nil;
    _firstClickElement = nil;
    
    _shouldEndDraw = NO;
    
    _timeMouseWentDown = nil;
    _freehand = [[RSFreehandStroke alloc] init];
}

- (void)dealloc;
{
    self.lineInProgress = nil;
    
    [_u removeExemptObject:_newDrawVertex];
    [_newDrawVertex release];
    [_freehand release];
    [_timeMouseWentDown release];
    
    [super dealloc];
}


- (RSDataPoint)closestGridPoint;
{
    return _closestGridPoint;
}



- (void)mouseMoved:(NSEvent *)event;
{
    [super mouseMoved:event];
    
    //[_u setEnabled:NO];  // don't register undo events in mouseMoved, since it shouldn't change anything permanent.
    
    NSUInteger modiferFlags = [event modifierFlags];
    
    
    /////////////
    // Set up _startDrawPoint
    _startDrawPoint.x = _startDrawPoint.y = 0;
    
    
    
    //////////////////
    // Perform hit detection on graph objects
    //
    RSGraphElement *GE = [_view.editor.hitTester elementUnderPoint:_viewMouseMovedPoint extraElement:_lineInProgress];
    
    // freshen the persistent _newDrawVertex object
    [_newDrawVertex clearSnappedTo];
    
    // for safety
    _newDrawObject = nil;
    
    if( [GE isKindOfClass:[RSVertex class]] ) {
	// always:
	_startDrawPoint = [GE position];
	
//	if( [RSTool specialKeysAreDown:modiferFlags] && [GE group] ) {
//	    // add all vertices in the group to the line-in-progress
//	    GE = [GE group];
//	    _newDrawObject = GE;
//	}
//	else {  // normal case
//	    // don't connect in between because that might not be what is wanted
//	    // simply:
//	    _newDrawObject = GE;
//	}
	
	if ([[_lineInProgress vertices] lastElement] == GE)
	    _newDrawObject = GE;
	else {
	    _newDrawObject = _newDrawVertex;
	    [_newDrawVertex setPosition:[GE position]];
	    [_newDrawVertex shallowAddSnappedTo:GE withParam:[NSNumber numberWithFloat:0]];
	}
    }
    else {  // no GE found, or a GE was found of a type we don't have special behavior for
        RSSnapBehavior behavior = RSSnapBehaviorRegular;
        if ([RSTool shouldStraighten:modiferFlags])
            behavior = RSSnapBehaviorShiftKey;
        
	[_view.editor.hitTester snapVertex:_newDrawVertex fromPoint:_viewMouseMovedPoint behavior:behavior prevVertex:_prevDrawVertex nextVertex:nil];
        
	_startDrawPoint = _closestGridPoint = [_newDrawVertex position];
	_newDrawObject = _newDrawVertex;
    }
    
    
    // Update half-selection
    if ( [_s halfSelection] != GE ) {
	[_s setHalfSelection:GE];
    }
    
    // Update inspector about the _startDrawPoint
    if ( [[_s selection] isKindOfClass:[RSUnknown class]] ) {
	[[_s selection] setPosition:_startDrawPoint];
    }
    
    // Update status bar about the _startDrawPoint
    [_s setStatusMessage:[_graph infoStringForPoint:_startDrawPoint]];
    
    
    // always redisplay in draw mode
    [_view setNeedsDisplay:YES];
    
    //[_u setEnabled:YES];
}




- (void)mouseDown:(NSEvent *)event;
{
    [super mouseDown:event];
    
    [_view deselect];
    
    // double-click always ends the draw
    if ( [event clickCount] >= 2 ) {
	_shouldEndDraw = YES;
    }
    // single-click
    else {
	// Start time for stroke recognition
	[_timeMouseWentDown release];
	_timeMouseWentDown = [[NSDate alloc] init];
	
	//[[_u undoManager] beginUndoGrouping];  // ??
	
	// make sure we have the latest changes from the inspector
	[_lineInProgress acceptLatestDefaults];
	
	// Just in case mouseMoved didn't do its job:
	//no, this messes with snapping done in mouseMoved//[_newDrawVertex setPosition:_mouseDownPoint];
	
	if( _newDrawObject == nil ) {
	    OBASSERT_NOT_REACHED("This normally gets done in mouseMoved");
	    _newDrawObject = _newDrawVertex;
	}
	
	if( _newDrawObject == _newDrawVertex ) {  // adding a new point to the line
	    RSVertex *V = [[_newDrawVertex parentlessCopy] autorelease];
	    [V acceptLatestDefaults];
            
	    // copy over the snappedTo info
	    [V setSnappedTo:[_newDrawVertex snappedTo] withParams:[_newDrawVertex snappedToParams]];
            
	    // now we can clean up the persistent _newDrawVertex
	    [_newDrawVertex clearSnappedTo];
	    
	    _newDrawObject = V;
	}
	// else, _newDrawObject is already an existing element
	
	// if the vertex is already in the line, we need to make a duplicate:
	if( [_newDrawObject isKindOfClass:[RSVertex class]] && _newDrawObject != _prevDrawVertex &&
	   [_lineInProgress containsVertex:(RSVertex *)_newDrawObject] ) {
	    _newDrawObject = [(RSVertex *)_newDrawObject parentlessCopy];
	}
	// add the vertex to the line
	if( ![_lineInProgress addVerticesAtEnd:_newDrawObject] ) {
	    _shouldEndDraw = YES;  // the vertex(es) were already in the line, so end it
	}
	else {
	    if( [_newDrawObject isKindOfClass:[RSVertex class]] )
		_prevDrawVertex = (RSVertex *)_newDrawObject;
	    else if ( [_newDrawObject isKindOfClass:[RSGroup class]] ) {
		_prevDrawVertex = (RSVertex *)[(RSGroup *)_newDrawObject 
					       lastElementWithClass:[RSVertex class]];
	    }
	}
	
	// for drawRect
	if( [_newDrawObject isKindOfClass:[RSVertex class]] ) {
	    _firstClickElement = (RSVertex *)_newDrawObject;
	} else {
	    _firstClickElement = (RSVertex *)[(RSGroup *)_newDrawObject firstElement];
	}
	
	// the new object has now been added to the line so we can reset this variable
	_newDrawObject = nil;
	
	// the new line and vertices do not get added to the graph until it is "committed"
	
	// if the default mode is "no connection", then end it right here (usually this
	// will be a single point).
	if( [_lineInProgress connectMethod] == RSConnectNone ) {
	    _shouldEndDraw = YES;
	}
	// if holding the shift key, also end right away (usually this will be 
	// a single straight line)
	//if( [_m shouldStraighten:[event modifierFlags]] ) {
	//_shouldEndDraw = YES;
	//}
	
	
    }
    
    // redraw
    [_view setNeedsDisplay:YES];
}

- (void)mouseDragged:(NSEvent *)event;
{
    [super mouseDragged:event];
    
    // if just started dragging to make a line, do some initialization
    if ( ![_m mouseDragging] && _firstClickElement ) {  
	// Add the original mouse-down point:
	[_freehand addStrokePoint:_viewMouseDownPoint atTime:0];
	// Add the new point:
	[_freehand addStrokePoint:_viewMouseDraggedPoint
		       atTime:-[_timeMouseWentDown timeIntervalSinceNow]];
	
	[_s setSelection:nil];
    }
    
    // In all cases:
    // Add the new stroke point:
    [_freehand addStrokePoint:_viewMouseDraggedPoint
		   atTime:-[_timeMouseWentDown timeIntervalSinceNow]];
    // display snap-to-vertex, if any
    [_s setHalfSelection:[_view.editor.hitTester vertexUnderPoint:_viewMouseDraggedPoint].element];
    // update display:
    [_view setNeedsDisplay:YES];
}

- (void)mouseUp:(NSEvent *)event;
{
    [super mouseUp:event];
    
    
    // if mouse was dragged, then create a line from it
    if( [_m mouseDragging] ) {
	
	// end the stroke and segment it:
	BOOL lineWasDrawn = [self endStroke];
	
	if (lineWasDrawn) {
	    _shouldEndDraw = YES;  // so that we continue below
	}
    }
    
    // potentially add a new line to the graph
    if( _shouldEndDraw ) {
	
	if( [_lineInProgress vertexCount] >= 2 ) {
	    // change back to modify mode in certain circumstances
	    [_m toolWasUsed:RS_draw];
	}
	
	// this takes care of the rest
	[self commitEditing];
	
	_shouldEndDraw = NO;
    }
}


- (void)cancelOperation:(NSEvent *)event;
// "Escape" key pressed
{
    [self discardEditing];  // cancel the current line being constructed
}

- (void)delete:(id)sender;
{
    // delete the previously drawn point in the line in progress
    if (![_lineInProgress isEmpty]) {
        [_lineInProgress dropVertex:_prevDrawVertex registeringUndo:NO];
        _prevDrawVertex = [_lineInProgress endVertex];
        [_view setNeedsDisplay:YES];
    }
}

- (void)insertNewline:(id)sender;
// "Return" key pressed
{
    if ([_m mouseDragging])  // avoid weird interactions with line drawing
        return;
    
    [self commitEditing];
}



- (void)drawPhaseAtBeginning;
{
    if ( [[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:@"SnapToGrid"]
        && [_mapper isGridLinePoint:_closestGridPoint] )
    {
        [_renderer drawGridPoint:_closestGridPoint];
    }
    
    
    if( SKETCH_TEST_MODE ) {
        // draw most recent stroke input:
        [self drawRawStrokeUsingWidth:3];
    }
}

- (void)drawPhaseWithShadows;
{
    ////////////////
    // Draw line-in-progress, if any
    if ( [_lineInProgress vertexCount] >= 1 )
    {
        // first, construct the line
        RSConnectLine *potentialLine = [_lineInProgress lineWithElement:_newDrawObject];
        // then draw it
        [_renderer drawLine:potentialLine];
    }
}
- (void)drawPhaseAtEnd;
{
    // Show mouse position on axes
    [_renderer drawPosition:_startDrawPoint onAxis:[_graph xAxis]];
    [_renderer drawPosition:_startDrawPoint onAxis:[_graph yAxis]];
    
    // Draw pen stroke
    if ( [_m mouseDragging] ) {
	if( SKETCH_TEST_MODE ) {
	    [self drawSegmentedStrokeUsingStartVertex:_firstClickElement];
	}
	else {
	    if ([[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:@"SegmentStrokesWhileDrawing"]) {
		[self drawSegmentedStrokeUsingStartVertex:_firstClickElement];
	    }
            NSColor *lineColor = [[[OFPreferenceWrapper sharedPreferenceWrapper] colorForKey:@"DefaultLineColor"] colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	    [self drawRawStrokeUsingWidth:[[OFPreferenceWrapper sharedPreferenceWrapper] floatForKey:@"DefaultLineWidth"]
                                    color:[lineColor colorWithAlphaComponent:0.618f]];
	}
    }
}


@end
