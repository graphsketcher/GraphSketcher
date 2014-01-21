// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/App/RSModifyTool.m 200244 2013-12-10 00:11:55Z correia $

#import "RSModifyTool.h"

#import <GraphSketcherModel/RSVertex.h>
#import <GraphSketcherModel/RSGroup.h>
#import <GraphSketcherModel/RSLine.h>
#import <GraphSketcherModel/RSTextLabel.h>
#import <GraphSketcherModel/RSFill.h>
#import <GraphSketcherModel/RSGraphEditor.h>
#import <GraphSketcherModel/RSGraphRenderer.h>
#import <GraphSketcherModel/RSUndoer.h>
#import <GraphSketcherModel/RSDataMapper.h>
#import <GraphSketcherModel/RSUnknown.h>
#import <GraphSketcherModel/RSConnectLine.h>
#import <GraphSketcherModel/RSHitTester.h>
#import <GraphSketcherModel/RSHitTester-Snapping.h>

#import "RSGraphView.h"
#import "RSSelector.h"
#import "RSMode.h"

@implementation RSModifyTool

////////////////////////////////////////
#pragma mark -
#pragma mark Class methods
///////////

@synthesize originalSelection = _originalSelection;
@synthesize movers = _movers;
@synthesize vertexCluster = _vertexCluster;

- (RSGraphElement *)expandVertexGroupToIncludeLine:(RSGraphElement *)GE;
// If GE is (or is part of) a vertex group (i.e. data series) that is connected by a line, return that line along with GE.
// <bug://bugs/54904> (Make it easier to select a line when it is made up of densly plotted points)
{
    // Look for a vertex in GE
    RSVertex *V = nil;
    if ([GE isKindOfClass:[RSVertex class]]) {
        V = (RSVertex *)GE;
    }
    else if ([GE isKindOfClass:[RSGroup class]]) {
        V = (RSVertex *)[(RSGroup *)GE firstElementWithClass:[RSVertex class]];
    }
    if (!V /*|| [V shape]*/)
        return GE;
    
    // Look for a parent line
    RSLine *L = [V lastParentLine];
    if (!L || [GE containsElement:L])
        return GE;
    
    // If everything works out, return the line along with GE
    if ([[V elementWithGroup] containsElement:[L vertices]]) {
        RSGroup *G = [RSGroup groupWithGraph:_graph];
        [G addElement:GE];
        [G addElement:L];
        GE = G;
    }
    
    return GE;
}

- (RSGraphElement *)expandSelection:(RSGraphElement *)selection withIntermediatesTo:(RSGraphElement *)end;
// This method implements shift key selection behavior.  Currently, it expands the selection to include all objects that are in-between something already in the selection and the element "end".  This currently only works with connect-lines and axis tick marks.
{
    if (!selection || !end)
	return end;
    
//Even if the selection contains the end element, we might still want to add to the selection any objects connected between them.
//    if ([selection containsElement:end])
//	return selection;
    
    RSGroup *result = [RSGroup groupWithGraph:_graph];
    
    for (RSGraphElement *start in [selection elements]) {
	[result addElement:start];
	
	NSMutableArray *connected = [NSMutableArray arrayWithArray:[start connectedElements]];
	if ([start isKindOfClass:[RSTextLabel class]]) {
            RSAxis *axis = [_graph axisOfElement:start];
            if (axis) {
                [connected addObject:axis];
            }
	}
	
	for (RSGraphElement *connector in connected) {
	    NSArray *intermediates = [connector elementsBetweenElement:start andElement:end];
	    for (RSGraphElement *obj in intermediates) {
		[result addElement:obj];
	    }
	}
    }
    [result addElement:end];
    
    return [result shake];
}

- (void)performRectangularSelect;
{
    NSPoint p1, p2;
    p1 = _viewMouseDownPoint;
    p2 = _viewMouseDraggedPoint;
    
    NSRect rect = NSMakeRect( p1.x, p1.y, 
		      (p2.x - p1.x),  // width
		      (p2.y - p1.y) );  // height
    rect = CGRectStandardize(rect);
    
    RSGraphElement *insiders;
    if ( [_m optionKeyIsDown] ) {
        insiders = [_view.editor.hitTester elementsEnclosedByRect:rect];
    }
    else {
        insiders = [_view.editor.hitTester elementsIntersectingRect:rect];
    }
    
    
    // set the selection:
    if ( _originalSelection ) {
        if ([_m commandKeyIsDown]) {
            [_view setSelection:[[[_originalSelection makeDuplicateIfGroup] elementEorElement:insiders] shake]];
        }
        else {
            [_view setSelection:[[[_originalSelection makeDuplicateIfGroup] elementWithElement:insiders] shake]];
        }
    }
    else
	[_view setSelection:[insiders shake]];
    
    // update font panel:
    if ([[_s selection] conformsToProtocol:@protocol(RSFontAttributes)]) {
        [[NSFontManager sharedFontManager] setSelectedFont:[[(id <RSFontAttributes>)[_s selection] fontDescriptor] font]
					    isMultiple:NO];
    }
    
    // update status message:
    //[_s setStatusMessage:[[_s selection] infoString]];
}

- (void)performResizeBar;
{
    _movingVertex = _overBarEnd;
    
    // set up undo:
    if ([_u firstUndoWithObject:_movingVertex key:@"setPosition"]) {
	[_u registerUndoWithObject:_movingVertex
				      action:@"setPosition" 
				       state:NSValueFromDataPoint([_movingVertex position])];
	[_u setActionName:NSLocalizedStringFromTable(@"Adjust Bar", @"UndoActions", @"Undo action name")];
    }
    
    // start by clearing any snapped-to objects
    [_movingVertex clearSnappedTo];
    
    // resize bar, constraining to horizontal/vertical
    RSDataPoint oldPosition = [_movingVertex position];
    CGPoint oView = [_mapper convertToViewCoords:oldPosition];
    if( [_movingVertex shape] == RS_BAR_VERTICAL ) {
        oView.y = _viewMouseDraggedPoint.y - _cursorOffset.y;
    } else {
        oView.x = _viewMouseDraggedPoint.x - _cursorOffset.x;
    }
    
    [_s setHalfSelection:[_view.editor.hitTester snapVertex:_movingVertex fromPoint:oView]];
    //
    // re-constrain after the snap
    if( [_movingVertex shape] == RS_BAR_VERTICAL ) {
	[_movingVertex setPositionx:oldPosition.x];
    } else {
	[_movingVertex setPositiony:oldPosition.y];
    }
    _closestGridPoint = [_movingVertex position]; // for snap-to-grid visualization
    [_s sendChange:nil];
    
    // in case the bar is part of a calculation
    [_view.editor modelChangeRequires:RSUpdateConstraints];
    
    // update status message:
    [_s setStatusMessage:[_movingVertex infoString]];
}

//- (void)performDragCurvePoint;
//{
//    RSLine *L = _overCurvePoint;//(RSLine *)[[_s selection] isLine];
//    
//    // set up undo
//    [_u registerRepetitiveUndoWithObject:L
//				  action:@"setCurvePoint" 
//				   state:NSStringFromPoint([L curvePoint])
//				    name:@"Line Curvature"];
//    // make the change
//    [L setCurvePoint:_mouseDraggedPoint];
//    
//    // snap to straight
//    if( [self curvePoint:_mouseDraggedPoint makesAlmostStraight:L] ) {
//	[L makeStraight];
//    }
//    
//    
//    [_s setHalfSelection:L]; // so we still see the curve marks
//    [_s sendChange:nil];
//}

- (void)dragNormalTextLabel;
{
    RSTextLabel *movingLabel = (RSTextLabel *)[_s selection];
    
    CGPoint newPos;
    newPos.x = _viewMouseDraggedPoint.x - _cursorOffset.x;
    newPos.y = _viewMouseDraggedPoint.y - _cursorOffset.y;
    [movingLabel setPosition:[_mapper convertToDataCoords:newPos]];
    
    RSGraphElement *snappedElement = [_view.editor.hitTester snapLabel:movingLabel toObjectsNear:_viewMouseDraggedPoint];
    [_s setHalfSelection:snappedElement];
    [_s sendChange:nil];
    
    return;
}

- (void)dragAttachedTextLabel;
{
    NSPoint vPoint;
    NSSize s;
    CGFloat distance, angle;
    RSLine *L;
    RSVertex *V;
    
    CGFloat hitOffset = [[OFPreferenceWrapper sharedPreferenceWrapper] floatForKey:@"SelectionSensitivity"];
    CGFloat popoutRatio = [[OFPreferenceWrapper sharedPreferenceWrapper] floatForKey:@"PopoutSensitivity"];
    
    //////
    // Text Label attached to a vertex:
    //
    if ( [[[_s selection] owner] isKindOfClass:[RSVertex class]] ) {
        V = (RSVertex *)[[_s selection] owner];
        [_u registerRepetitiveUndoWithObject:V 
                                      action:@"setLabelPosition" 
                                       state:[NSNumber numberWithFloat:(float)[V labelPosition]]
                                        name:NSLocalizedStringFromTable(@"Label Position", @"UndoActions", @"Undo action name")];
        NSPoint o;
        // TODO: use the position of the center of the label
	// but in practice, this seems to work fine:
	o.x = _viewMouseDraggedPoint.x;
	o.y = _viewMouseDraggedPoint.y;
	vPoint = [_mapper convertToViewCoords:[V position]];
	
	// check for pop-out detachment
	s = NSMakeSize(o.x - vPoint.x, o.y - vPoint.y);
	distance = sqrt(s.width*s.width + s.height*s.height);
	//NSLog(@"DETACH? distance=%f", distance);
	if ( distance > (sqrt(hitOffset)*popoutRatio + [[_s selection] size].width/4.0) + [V width]*3.0 ) {
	    // then detach...
	    [_u setActionName:NSLocalizedStringFromTable(@"Detach Label From Point", @"UndoActions", @"Undo action name")];
	    
	    [[_s selection] setOwner:nil];
	    [_s sendChange:nil];
	}
	else {	// don't detach; drag around the point like usual
	    // find the new angle (all in radians):
	    angle = atan((o.y - vPoint.y) / (o.x - vPoint.x)); // * 180 / 3.14159;
	    if ( (o.x - vPoint.x) < 0 )  angle += (CGFloat)M_PI;
	    // snap to 0, 90, 180, etc.
	    angle = [_view.editor.hitTester snapAngleToCorners:angle];
            if ([V shape] == RS_BAR_VERTICAL) {  // On vertical bars, the label position setting starts at north instead of east.
                angle -= (CGFloat)PIOVER2;
            }
	    // position it:
	    [V setLabelPosition:angle];
	    [_renderer positionLabel:(RSTextLabel *)[_s selection] forOwner:V];
	    // finish up:
	    [_s setHalfSelection:nil];
	    [_s sendChange:nil];
	}
    }
    //////
    // Text Label attached to a line:
    else if ( [[[_s selection] owner] isKindOfClass:[RSLine class]] ) {
	L = (RSLine *)[[_s selection] owner];
	[_u registerRepetitiveUndoWithObject:L 
				      action:@"setSlide" 
				       state:[NSNumber numberWithFloat:
					      (float)[L slide]]
					name:NSLocalizedStringFromTable(@"Label Position", @"UndoActions", @"Undo action name")];
        NSPoint o;
	o.x = _viewMouseDraggedPoint.x;
	o.y = _viewMouseDraggedPoint.y;
	
	// check for pop-out detachment
        distance = distanceBetweenPoints(o, [_view.editor.hitTester closestPointTo:o onCurve:L]);
	if ( distance > ( sqrt(hitOffset) * popoutRatio) ) {
	    // then detach...
	    [_u setActionName:NSLocalizedStringFromTable(@"Detach Label From Line", @"UndoActions", @"Undo action name")];
	    
	    [[_s selection] setOwner:nil];
	    [_s sendChange:nil];
	}
	else {	// don't detach; drag along line like usual
	    
	    CGFloat ratio = [_view.editor.hitTester timeOfClosestPointTo:o onLine:L];
	    ratio = [_view.editor.hitTester snapPercentage:ratio toCenterOfLength:[_mapper viewLengthOfLine:L]];
	    [L setSlide:ratio];
	    [_renderer positionLabel:(RSTextLabel *)[_s selection] forOwner:L];
	    // finish up:
	    [_s setHalfSelection:nil];
	    [_s sendChange:nil];
	}
    }
    //////
    // Text Label attached to a fill:
    else if ( [[[_s selection] owner] isKindOfClass:[RSFill class]] ) {
	RSFill *F = (RSFill *)[[_s selection] owner];
	[_u registerRepetitiveUndoWithObject:[[_s selection] owner] 
				      action:@"setPlacement" 
				       state:NSStringFromPoint([F labelPlacement])
					name:NSLocalizedStringFromTable(@"Label Position", @"UndoActions", @"Undo action name")];
        CGPoint o;
        o.x = _viewMouseDraggedPoint.x - _cursorOffset.x;
        o.y = _viewMouseDraggedPoint.y - _cursorOffset.y;
	s = [[_s selection] size];
	o.x += s.width/2;
	o.y += s.height/2;
        RSDataPoint oData = [_mapper convertToDataCoords:o];
	if ( [_view.editor.hitTester hitTestPoint:o onFill:F] ) {
	    NSPoint percents;
	    percents.x = (CGFloat)((oData.x - [F position].x)/([F positionUR].x - [F position].x));
	    percents.y = (CGFloat)((oData.y - [F position].y)/([F positionUR].y - [F position].y));
	    [F setLabelPlacement:percents];
	    // finish up:
	    [_s setHalfSelection:nil];
	    [_s sendChange:nil];
	}
	else {	// mouse not over the fill
            distance = [_view.editor.hitTester viewDistanceFromFill:F toPoint:o];
	    //NSLog(@"DETACH? distance=%f", distance);
	    if ( distance > ( sqrt(hitOffset) * popoutRatio) ) {
		//NSLog(@"DETACH DETACH DETACH");
		// then detach...
		[_u setActionName:NSLocalizedStringFromTable(@"Detach Label From Fill", @"UndoActions", @"Undo action name")];
		[[_s selection] setOwner:nil];
		[_s sendChange:nil];
	    }
	}
    }
}

- (void)dragAxisTitle;
{
    CGPoint vo;
    vo.x = _viewMouseDraggedPoint.x - _cursorOffset.x;
    vo.y = _viewMouseDraggedPoint.y - _cursorOffset.y;
    
    // calculate 'f': the percentage (fraction) along the axis
    RSAxis *axis = [_graph axisOfElement:[_s selection]];
    NSSize titleSize = [[axis title] size];
    RSBorder tickLabelBorder = [_renderer tickLabelWhitespaceBorderForAxis:axis];
    CGFloat viewMin, viewMax, axisLength, f;
    
    if ([axis orientation] == RS_ORIENTATION_HORIZONTAL) {
        viewMin = [_mapper viewMins].x - tickLabelBorder.left;
        viewMax = [_mapper viewMaxes].x + tickLabelBorder.right;
        axisLength = viewMax - viewMin;
        
        CGFloat neg = vo.x - viewMin;
        CGFloat pos = viewMax - vo.x - titleSize.width;
        f = neg/(neg + pos);
    }
    else if ([axis orientation] == RS_ORIENTATION_VERTICAL) {
        viewMin = [_mapper viewMins].y - tickLabelBorder.bottom;
        viewMax = [_mapper viewMaxes].y + tickLabelBorder.top;
        axisLength = viewMax - viewMin;
        
        CGFloat neg = vo.y - viewMin;
        CGFloat pos = viewMax - vo.y - titleSize.width;
        f = neg/(neg + pos);
    }
    else {
        OBASSERT_NOT_REACHED("Unsupported dimension");
        return;
    }
    
    if (f < 0)  f = 0;
    if (f > 1)  f = 1;
    f = [_view.editor.hitTester snapPercentage:f toCenterOfLength:axisLength];
    [axis setTitlePlacement:f];
    [_renderer positionAxisTitles];
}


- (void)dragAxis:(RSAxis *)axis;
{
    OBASSERT(axis);
    if (!axis)
        return;
    
    int orientation = [axis orientation];
    CGFloat delta = dimensionOfPointInOrientation(_viewMouseDraggedPoint, orientation) - dimensionOfPointInOrientation(_viewMouseDownPoint, orientation);
    
    CGFloat viewMin = dimensionOfPointInOrientation([_mapper viewMins], orientation);
    CGFloat viewMax = dimensionOfPointInOrientation([_mapper viewMaxes], orientation);
    data_p dataMin = dimensionOfDataPointInOrientation(_dataAxisMins, orientation);
    data_p dataMax = dimensionOfDataPointInOrientation(_dataAxisMaxes, orientation);
    
    CGFloat fraction = delta/(viewMax - viewMin);
    
    data_p dataDelta;
    if ([axis axisType] == RSAxisTypeLinear) {
        dataDelta = fraction * (dataMax - dataMin);
        
        [axis setMin:dataMin - dataDelta];
        [axis setMax:dataMax - dataDelta];
    }
    else {  // RSAxisTypeLogarithmic
        dataDelta = exp2(fraction * log2(dataMax/dataMin));
        //NSLog(@"dataDelta: %.13g", dataDelta);
        [axis setMin:dataMin/dataDelta];
        [axis setMax:dataMax/dataDelta];
    }
    
    // snap ends to ticks, if close enough:
    [_view.editor.hitTester snapAxisToGrid:axis];
    [axis setUserModifiedRange:YES];
}

- (void)dragOrigin;
{
    [self dragAxis:[_graph xAxis]];
    [self dragAxis:[_graph yAxis]];
}



- (void)dragAxisEnd:(RSAxisEnd)axisEnd;
{
    [_view.editor dragAxisEnd:axisEnd downPoint:_mouseDownPoint currentViewPoint:_viewMouseDraggedPoint viewMins:_viewMins viewMaxes:_viewMaxes];
}

- (void)dragAxisTickLabel;
{
    if (_behaveLikeAxisEnd == RSAxisEndNone) {
        RSTextLabel *tickLabel = (RSTextLabel *)[_s selection];
        OBASSERT([tickLabel isKindOfClass:[RSTextLabel class]]);
        OBASSERT([tickLabel isPartOfAxis]);
        
        _behaveLikeAxisEnd = [_view.editor axisEndEquivalentForPoint:_mouseDownPoint onAxisOrientation:[tickLabel axisOrientation]];
        
        [_s setHalfSelection:nil];  // Don't show the hover effect during the drag.  This lessens the impact of the end label being different from the intermediate labels, which otherwise causes a confusing hover effect when dragging the end tick label.
    }
    else {
        OBASSERT([_m mouseDragging]);
    }
    
    [self dragAxisEnd:_behaveLikeAxisEnd];
}

- (void)dragMarginGuide:(NSUInteger)edge;
{
    OBPRECONDITION(edge);
    
    if ([_graph autoMaintainsWhitespace]) {
	[_graph setAutoMaintainsWhitespace:NO];
    }
    
    RSBorder whitespace = [_graph whitespace];
    NSSize canvasSize = [_graph canvasSize];
    CGFloat position, min, max;
    
    switch (edge) {
	case RSBORDER_LEFT:
	    position = _viewMouseDraggedPoint.x;
	    min = 0;
	    max = canvasSize.width - whitespace.right - RSMinGraphSize.width;
	    position = trimToMinMax(position, min, max);
	    whitespace.left = position;
	    break;
	    
	case RSBORDER_RIGHT:
	    position = _viewMouseDraggedPoint.x;
	    min = whitespace.left + RSMinGraphSize.width;
	    max = canvasSize.width;
	    position = trimToMinMax(position, min, max);
	    whitespace.right = canvasSize.width - position;
	    break;
	    
	case RSBORDER_BOTTOM:
	    position = _viewMouseDraggedPoint.y;
	    min = 0;
	    max = canvasSize.height - whitespace.top - RSMinGraphSize.height;
	    position = trimToMinMax(position, min, max);
	    whitespace.bottom = position;
	    break;
	    
	case RSBORDER_TOP:
	    position = _viewMouseDraggedPoint.y;
	    min = whitespace.bottom + RSMinGraphSize.height;
	    max = canvasSize.height;
	    position = trimToMinMax(position, min, max);
	    whitespace.top = canvasSize.height - position;
	    break;
	    
	default:
	    break;
    }
    
    if( !RSEqualBorders(whitespace, [_graph whitespace]) ) {
	[_graph setWhitespace:whitespace];
	[_view.editor setNeedsUpdateWhitespace];
    }
}


////////////////////////////////////////
#pragma mark -
#pragma mark RSTool subclass
///////////

- (void)initState;
{
    _movingVertex = nil;
    _movers = nil;
    _vertexCluster = nil;
    [self setOriginalSelection:nil];
    _newLabelOwner = nil;
    
    _overBarEnd = nil;
    _overOrigin = NO;
    _overAxisEnd = RSAxisEndNone;
    _behaveLikeAxisEnd = RSAxisEndNone;
    _overMarginGuide = 0;
    
    _rectangularSelect = NO;
    _startEditingNextLabel = NO;
    _dragMarginGuide = NO;
    
    _downTick = 0;
}

- (void)dealloc;
{
    [_movers release];
    [_vertexCluster release];
    
    [super dealloc];
}



- (RSDataPoint)closestGridPoint;
{
    return _closestGridPoint;
}

- (BOOL)shouldDrawSelection;
{
    return ( [_s selected] && (![_m mouseDragging] || _rectangularSelect) );
}



- (void)mouseExited:(NSEvent *)event;
{
    [super mouseExited:event];
    
    if (![_m mouseDragging]) {
	_overMarginGuide = NO;
	[_view updateCursor];
    }
}

- (void)mouseMoved:(NSEvent *)event;
{
    [super mouseMoved:event];
    
    // Setup for hit detection:
    RSGraphElement *GE = nil;
    RSGraphElement *selection = nil;
    if ([_s selected])
        selection = [_s selection];

    // Shift key:
    if ( [RSTool shiftKeyIsDown:[event modifierFlags]] ) {
        GE = [_view.editor.hitTester elementUnderPoint:_viewMouseMovedPoint];
        GE = [_view.editor.hitTester expand:GE toIncludeGroupingsAndElementsUnderPoint:_viewMouseMovedPoint];
        GE = [self expandSelection:selection withIntermediatesTo:GE];
        if ([_s selected]) {
            GE = [GE elementWithoutElement:[_s selection]];
        }
    }
    // Command key:
    else if ( [RSTool commandKeyIsDown:[event modifierFlags]] ) {  // (command key)
        GE = [_view.editor.hitTester elementUnderPoint:_viewMouseMovedPoint];
        //GE = [[_graph elementsConnectedTo:GE] elementWithClass:[GE class]];
    }
    // Standard behavior (no modifier keys):
    else {
        // Get true element under point:
        GE = [_view.editor.hitTester elementUnderPoint:_viewMouseMovedPoint];
        
        if ([GE isKindOfClass:[RSVertex class]] && ![GE group]) {
            _movingVertex = (RSVertex *)GE;
        } else {
            _movingVertex = nil;
        }
        
        // If the mouse is over one of the selected elements...
        if ([_s selected] && GE && [[_s selection] containsElement:GE]) {
            // Normally, don't expand the selection (this allows the user to select a special subset and then drag it somewhere).
            ;
        }
        else {
            // If the mouse isn't over a selected element, select any relevant groupings near the mouse.
            GE = [_view.editor.hitTester expand:GE toIncludeGroupingsAndElementsUnderPoint:_viewMouseMovedPoint];
        }
    }
    
    
    // Set up for potential origin dragging
    if (![GE isKindOfClass:[RSVertex class]] && [_view.editor.hitTester originUnderPoint:_viewMouseMovedPoint]) {
        _overOrigin = YES;
    } else {
        _overOrigin = NO;
    }
    
    // Set up for potential margin dragging
    NSUInteger marginEdge = 0;
    if (!GE) {
        marginEdge = [_view.editor.hitTester marginGuideUnderPoint:_viewMouseMovedPoint];
    }
    if (marginEdge != _overMarginGuide) {
	_overMarginGuide = marginEdge;
	[_view setNeedsDisplay:YES];
    }
    
    // Set up for potential axis end dragging
    RSAxisEnd axisEnd = RSAxisEndNone;
    if (!GE || [GE isKindOfClass:[RSAxis class]]) {
        axisEnd = [_view.editor.hitTester axisEndUnderPoint:_viewMouseMovedPoint];
    }
    if (axisEnd != _overAxisEnd) {
        _overAxisEnd = axisEnd;
        _downTick = [_graph tickValueOfAxisEnd:_overAxisEnd];
        [_view setNeedsDisplay:YES];
    }
    if (_overAxisEnd != RSAxisEndNone && ![GE isKindOfClass:[RSAxis class]]) {
        GE = [_graph axisWithAxisEnd:_overAxisEnd];
    }
    
    
    /////////
    // Update half selection:
    if ( [_s halfSelection] != GE ) {
	[_s setHalfSelection:GE];
    }

    _startDrawPoint = _mouseMovedPoint;
    
    //////////////
    // Update inspector about the _startDrawPoint
    if ( [[_s selection] isKindOfClass:[RSUnknown class]] ) {
	[[_s selection] setPosition:_startDrawPoint];
    }
    
    ////////////
    // Update status bar about the _startDrawPoint
    if( (![_s selected]) && NSPointInRect(_viewMouseMovedPoint, [_view bounds]) ) {
	[_s setStatusMessage:[_graph infoStringForPoint:_startDrawPoint]];
    }

    
    /////////
    // Set the cursor
    
    // If over a bar end:
    _overBarEnd = nil;
    if( [GE isKindOfClass:[RSVertex class]] && [_view.editor.hitTester hitTestPoint:_viewMouseMovedPoint onBarEnd:(RSVertex *)GE] ) {
	_overBarEnd = (RSVertex *)GE;
	//no, bad idea//[_s setHalfSelection:nil];
	
	if( [GE shape] == RS_BAR_VERTICAL )
	    [[NSCursor resizeUpDownCursor] set];
	else if( [GE shape] == RS_BAR_HORIZONTAL )
	    [[NSCursor resizeLeftRightCursor] set];
    }
    
    // If over an axis end
    else if ( [GE isKindOfClass:[RSAxis class]] && _overAxisEnd != RSAxisEndNone ) {
        RSAxis *axis = [_graph axisWithAxisEnd:_overAxisEnd];
        if ([axis orientation] == RS_ORIENTATION_HORIZONTAL)
            [[NSCursor resizeLeftRightCursor] set];
        else
            [[NSCursor resizeUpDownCursor] set];
    }
    
    // If over an axis or origin
    else if ( [GE isKindOfClass:[RSAxis class]] || _overOrigin) {
	// Change to hand cursor if over an axis:
	[[NSCursor openHandCursor] set];
    }
    
    // If over a whitespace margin
    else if (marginEdge /*&& ![_graph autoMaintainsWhitespace]*/) {
	if (marginEdge) {
	    if (marginEdge == RSBORDER_LEFT || marginEdge == RSBORDER_RIGHT)
		[[NSCursor resizeLeftRightCursor] set];
	    else if (marginEdge == RSBORDER_TOP || marginEdge == RSBORDER_BOTTOM)
		[[NSCursor resizeUpDownCursor] set];
	}
    }
    else {
        [_view updateCursor];
    }
    
}

- (void)mouseDown:(NSEvent *)event;
{
    [super mouseDown:event];
    
    //////////////////
    // handle DOUBLE-CLICK
    // which usually creates or edits text in this mode
    if ( [event clickCount] == 2 ) {
        
        RSGraphElement *GE = [_s halfSelection];
        
        if ( [_s selected] ) {
            if( [GE isKindOfClass:[RSAxis class]] ) {
                [(RSAxis *)GE setDisplayTitle:YES];
                [_view.editor setNeedsUpdateWhitespace];
                [_view.editor updateDisplayNow];
                [_view setSelection:[(RSAxis *)GE title]];
            }
            if ( [GE isKindOfClass:[RSTextLabel class]] ) {
                [_view setSelection:GE];
                [_view startEditingLabel];
                return;
            }
            else if ( [GE isKindOfClass:[RSVertex class]] ) {
                [_view.editor.hitTester autoSetLabelPositioningForVertex:(RSVertex *)GE];
                [_renderer positionLabel:nil forOwner:GE];
                [_view setSelection:[GE label]];
                [_view startEditingLabel];
                return;
            }
            else if ( [GE isKindOfClass:[RSLine class]] ) {
                RSLine *L = (RSLine *)GE;
                if ([L isKindOfClass:[RSConnectLine class]]) {
                    // Add a new point to the line
                    NSUInteger segmentIndex = 0;
                    if ([_view.editor.hitTester hitTestPoint:_viewMouseDownPoint onLine:L hitSegment:&segmentIndex].hit) {
                        RSVertex *newVertex = [[RSVertex alloc] initWithGraph:_graph];
                        [newVertex setPosition:[_mapper convertToDataCoords:[_view.editor.hitTester closestPointTo:_viewMouseDownPoint onCurve:L]]];
                        [_graph addVertex:newVertex];
                        [(RSConnectLine *)L insertVertex:newVertex atIndex:(segmentIndex + 1)];
                        [newVertex setWidth:[L width]];
                        [newVertex setColor:[L color]];
                        [newVertex setShape:RS_NONE];
                        [_view setSelection:newVertex];
                        [_s setHalfSelection:newVertex];
                        [newVertex release];
                    }
                }
                else {  // not a connectLine; so, a best-fit line
                    [L setSlide:[_view.editor.hitTester timeOfClosestPointTo:_viewMouseDownPoint onLine:L]];
                    [_renderer positionLabel:nil forOwner:L];
                    [_view setSelection:[L label]];
                    [_view startEditingLabel];
                    return;
                }
            }
            else if ( [GE isKindOfClass:[RSFill class]] ) {
                [_renderer positionLabel:nil forOwner:[_s halfSelection]];
                [_view setSelection:[GE label]];
                [_view startEditingLabel];
                return;
            }
            else {
                // Don't handle the double-click if we don't know what it is
                return;
            }

        }
	else {  // nothing selected
	    // the alternative is that the user double clicked while something
	    //		was selected.  The first click deselected, the second click is now.
	    
	    // make a new text label and start editing:
	    RSTextLabel *TL = [[[RSTextLabel alloc] initWithGraph:_graph] autorelease];
	    [_graph addLabel:TL];
	    [TL setPosition:_mouseDownPoint];
	    [_view setSelection:TL];
	    [_s sendChange:nil];	// spread the news
	    [_view startEditingLabel];
	    
            return;
	}
    }
    
    
    // Record the starting view positions of axes (for smooth axis manipulations)
    _viewMins = [_mapper viewMins];
    _viewMaxes = [_mapper viewMaxes];
    
    _dataAxisMins = RSDataPointMake([_graph xMin], [_graph yMin]);
    _dataAxisMaxes = RSDataPointMake([_graph xMax], [_graph yMax]);
    
    
    ///////////
    // resizing a bar chart bar
    if( _overBarEnd ) {
        CGPoint viewPosition = [_mapper convertToViewCoords:[_overBarEnd position]];
        _cursorOffset = CGPointMake(_viewMouseDownPoint.x - viewPosition.x, _viewMouseDownPoint.y - viewPosition.y);
        return;
    }
    ///////////
    // axis end dragging
    else if (_overAxisEnd) {
        return;
    }
    ///////////
    // margin guide resizing
    else if (_overMarginGuide) {
        _dragMarginGuide = YES;
        return;
    }
    
    ////////////
    // SINGLE CLICK, or finishing up from double-click
    //
    if ( ![_s halfSelection] ) {  // no half-selection (i.e. over white-space)
        
	if ( [RSTool shiftKeyIsDown:[event modifierFlags]] || [RSTool commandKeyIsDown:[event modifierFlags]] ) {
	    // save original selection to potentially modify with a new rectangular select action
	    if ( [_s selected] )
                [self setOriginalSelection:[[_s selection] makeDuplicateIfGroup]];
	}
	else {
	    // deselect if necessary
	    [_view deselect];
	}
	// do rectangular select if mouse is dragged
	_rectangularSelect = YES;
        
        return;
    }
    
    //
    // Calculate what the new selection should be
    //
    RSGraphElement *newSelection = nil;
    if ([_s selected] && [RSTool shiftKeyIsDown:[event modifierFlags]]) {
        newSelection = [[_s selection] elementWithElement:[_s halfSelection]];
    }
    else if ([_s selected] && [RSTool commandKeyIsDown:[event modifierFlags]]) {
        newSelection = [[_s selection] elementEorElement:[_s halfSelection]];
        
        // If the user decides to drag, start a rectangular selection (rather than moving whatever objects are still selected, if any)  <bug://bugs/56261>
        _rectangularSelect = YES;
        // save original selection to potentially modify with a new rectangular select action
        if ( [_s selected] )
            [self setOriginalSelection:[newSelection makeDuplicateIfGroup]];
    }
    else {  // normal select
        if ( [_view isEditingLabel] ) {
            _startEditingNextLabel = YES; // assume user is in a text-editing mindset
        }
        
        if ([[_s halfSelection] isKindOfClass:[RSAxis class]]) {
            newSelection = [_s halfSelection];
        }
        else {
            newSelection = [[_s selection] elementIncludingElement:[_s halfSelection]];
        }
    }
    // Actually select the new selection:
    [_view setSelection:newSelection];
    
    //
    // Set up for potential mouseDragging.
    //
    if ([newSelection isKindOfClass:[RSVertex class]]) {
        _movingVertex = (RSVertex *)newSelection;
    }
    if ([_s selected] || _movingVertex) {
        RSGraphElement *movingObject = (_movingVertex ? _movingVertex : [_s selection]);
        CGPoint viewPosition = [_mapper convertToViewCoords:[movingObject position]];
        _cursorOffset = CGPointMake(_viewMouseDownPoint.x - viewPosition.x, _viewMouseDownPoint.y - viewPosition.y);
        
        _prevMouseDraggedPoint = _viewMouseDownPoint;
    }
    
    if ( _movingVertex ) {
        [self setVertexCluster:[_movingVertex vertexCluster]];
        [self setMovers:[RSGraph elementsToMove:_movingVertex]];
    }
    else {
        [self setMovers:[RSGraph elementsToMove:[_s selection]]];
    }
    
    if ( [[_s selection] isKindOfClass:[RSTextLabel class]] ) {
        // update font panel:
        [[NSFontManager sharedFontManager] setSelectedFont:[[(RSTextLabel *)[_s selection] fontDescriptor] font]
                                                isMultiple:NO];
        // special info for axis tick labels:
        if( [_graph isAxisTickLabel:(RSTextLabel *)[_s selection]] ) {
            _downTick = [[_s selection] tickValue];
        }
    }
    else if ( [[_s selection] isKindOfClass:[RSAxis class]] ) {
        // change to a hand cursor to indicate dragging
        [[NSCursor closedHandCursor] set];
    }
}

- (void)mouseDragged:(NSEvent *)event;
{
    [super mouseDragged:event];
    
    [_view setNeedsDisplay:YES];
    
    if (_rectangularSelect) {
	[self performRectangularSelect];
	return;
    }
    
    // check if the item is locked (and thus can't be dragged)
    if( [[_s selection] locked] || [_movingVertex locked] ) {
	[_s setStatusMessage:NSLocalizedString(@"The selection is locked in place. To move it, first choose \"Unlock\".", @"Status bar warning for locked selection")];
	return;
    }
    
    if (_overBarEnd) {
	[self performResizeBar];
	return;
    }
    
    if (_overAxisEnd) {
        [self dragAxisEnd:_overAxisEnd];
        return;
    }
    
    if (_dragMarginGuide) {
	[self dragMarginGuide:_overMarginGuide];
	return;
    }
    
    
    ///////////
    // If got this far, drag the selected object(s)
    
    // If this is the first drag event since the mouse went down, setup some things
    if ( ![_m mouseDragging] ) {
        
        // If the option key is down, duplicate the selection and setup to manipulate the duplicate
        if ([_m optionKeyIsDown]) {
            
            OBASSERT([_s selected]);
            RSGraphElement *duplicate = [_view duplicateElement:[_s selection]];
            [_s setSelection:duplicate];
            
            [self setMovers:[RSGraph elementsToMove:duplicate]];
            if ([duplicate isKindOfClass:[RSVertex class]]) {
                _movingVertex = (RSVertex *)duplicate;
            } else {
                _movingVertex = nil;
            }
            [self setVertexCluster:[_movingVertex vertexCluster]];
            
            [_u registerUndoWithObjectsIn:[self movers] action:@"setPosition"];
            [_u setActionName:NSLocalizedStringFromTable(@"Duplicate", @"UndoActions", @"Undo action name")];
        }
        
        // Normally, just set up undo
	else if ( !([_graph axisOfElement:[_s selection]] || _overOrigin) )  // NOT an axis component
	{
	    [_u registerDelayedUndoWithObjectsIn:[self movers] action:@"setPosition"];
	    //now in model//[_u registerUndoWithObjectsIn:_movers action:@"setSnappedTos"];
	    [_u setActionName:NSLocalizedStringFromTable(@"Drag", @"UndoActions", @"Undo action name")];
	}
    }
    
    
    //
    // Origin dragging
    //
    if (_overOrigin) {
	[self dragOrigin];
    }
    
    //
    // Vertex dragging
    //
    else if ( [[_s selection] isKindOfClass:[RSVertex class]] || _movingVertex ) {
	if ( !_movingVertex ) {
            OBASSERT_NOT_REACHED("A _movingVertex should be defined");
	    _movingVertex = (RSVertex *)[_s selection];
	}
        
        if (![[self movers] count]) {
            if ([_movingVertex locked])
                [_s setStatusMessage:@"The point is locked in place."];
            else
                [_s setStatusMessage:@"The point is snapped to a locked point.  To move it, first choose \"Detach\"."];
            return;
        }
	
	// start by clearing any snap-constraints, because user dragging overrides those
	[_movingVertex setVertexCluster:_vertexCluster];
	
	RSVertex *topVertex = _movingVertex;
	
        CGPoint oView;
        oView.x = _viewMouseDraggedPoint.x - _cursorOffset.x;
        oView.y = _viewMouseDraggedPoint.y - _cursorOffset.y;
	
        //
        // constrain to vertical, horizontal, diagonal if wanted
	if ( [RSTool shouldStraighten:[event modifierFlags]] ) {  // shift or command key down
            [_s setHalfSelection:[_view.editor.hitTester snapVertex:topVertex fromPoint:oView behavior:RSSnapBehaviorShiftKey]];
	}
	// modifier keys NOT down, or constraints don't apply
	else {
	    [_s setHalfSelection:[_view.editor.hitTester snapVertex:topVertex fromPoint:oView]];
	}

	// copy the snapped position throughout the movable vertex cluster
	RSDataPoint newPoint = [topVertex position];
	for (RSVertex *V in _vertexCluster) {
	    [V setPosition:newPoint];
	}
	
	_closestGridPoint = [topVertex position]; // for snap-to-grid visualization
	[_s sendChange:nil];
    }
    
    //
    // Group dragging
    //
    else if ( [[_s selection] isKindOfClass:[RSGroup class]] || [[_s selection] isKindOfClass:[RSLine class]] || [[_s selection] isKindOfClass:[RSFill class]]) {
        // move all movable elements
        if (![[self movers] count]) {
	    [_s setStatusMessage:NSLocalizedString(@"The selection is locked in place. To move it, first choose \"Unlock\".", @"Status bar warning for locked selection")];
            return;
        }
        
        for (RSGraphElement *obj in [[self movers] elements])
        {
            if( [obj isKindOfClass:[RSVertex class]] ) {
                [(RSVertex *)obj removeExtendedConstraints];  // user drag overrides snapped constraints
            }
            
            CGPoint old = [_mapper convertToViewCoords:[obj position]];
            CGPoint new;
            new.x = old.x + _viewMouseDraggedPoint.x - _prevMouseDraggedPoint.x;
            new.y = old.y + _viewMouseDraggedPoint.y - _prevMouseDraggedPoint.y;
            
            [obj setPosition:[_mapper convertToDataCoords:new]];
        }
        
        // finish up:
        _prevMouseDraggedPoint = _viewMouseDraggedPoint;
        [_s setHalfSelection:nil];
        [_s sendChange:nil];
    }
    
    //
    // Text Label dragging
    //
    else if ( [[_s selection] isKindOfClass:[RSTextLabel class]] ) {
        
        RSTextLabel *movingLabel = (RSTextLabel *)[_s selection];
        
	// axis tick label
	if ( [_graph isAxisTickLabel:movingLabel] ) {
	    [self dragAxisTickLabel];
	}
	
	// axis title -- can move it along the axis
	else if ( [_graph isAxisTitle:movingLabel] ) {
            [self dragAxisTitle];
	}
	
	// text label attached to an object
	else if ( ![[_s selection] isMovable] && !_newLabelOwner ) {
	    [self dragAttachedTextLabel];
	}
	
        // regular text label
        else {
            if ( ![_m mouseDragging] ) {  // first drag event
                [_view.editor.hitTester beginDraggingLabel:movingLabel];
            }
            
            [self dragNormalTextLabel];
        }
    }
    
    //
    // Axis dragging
    //
    else if ( [[_s selection] isKindOfClass:[RSAxis class]] ) {
//	[self dragAxis:(RSAxis *)[_s selection]];
	[self dragOrigin];
    }
    else {
	OBASSERT_NOT_REACHED("RSModifyTool doesn't recognize the object to be dragged.");
    }
    
    
    // Re-compute computationally intensive objects (like fit lines)
    [_view.editor modelChangeRequires:RSUpdateConstraints];
    
    // update status message:
    [_s setStatusMessage:[[_s selection] infoString]];
}

- (void)mouseUp:(NSEvent *)event;
{
    [super mouseUp:event];
    
    ////////
    // select bar if clicked in bar resize area and didn't drag
    if( _overBarEnd && ![_m mouseDragging] ) {
	[_view setSelection:_overBarEnd];
    }
    
    // update the cursor in case something changed it:
    [_view updateCursor];
    
    // The view needs to be redrawn almost always:
    [_view setNeedsDisplay:YES];
    
    // Reset state variables
    _movingVertex = nil;
    [self setMovers:nil];
    [self setOriginalSelection:nil];
    _rectangularSelect = NO;
    _startEditingNextLabel = NO;
    _dragMarginGuide = NO;
    _behaveLikeAxisEnd = RSAxisEndNone;
    _newLabelOwner = nil;
}

- (void)cancelOperation:(NSEvent *)event;
{
    
}
- (void)delete:(id)sender;
{
    
}
- (void)insertNewline:(id)sender;
{
    if ([_s selected] && [[_s selection] isKindOfClass:[RSTextLabel class]]) {
        [_view startEditingLabel];
    }
}


- (void)drawPhaseAtBeginning;
{
    if ( [[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:@"SnapToGrid"] && _movingVertex && [_m mouseDragging]
	&& [_mapper isGridLinePoint:_closestGridPoint] )
    {
	[_renderer drawGridPoint:_closestGridPoint];
    }
    
    if (_overAxisEnd != RSAxisEndNone) {
        RSAxis *axis = [_graph axisWithAxisEnd:_overAxisEnd];
        [_renderer drawHalfSelectedPosition:_downTick onAxis:axis];
    }
}

- (void)drawPhaseAtEnd;
{
    if ([_m mouseDragging] && _movingVertex) {
        // Show mouse position on axes
        _startDrawPoint = [_movingVertex position];
        [_renderer drawPosition:_startDrawPoint onAxis:[_graph xAxis]];
        [_renderer drawPosition:_startDrawPoint onAxis:[_graph yAxis]];
    }
    
    ///////////////////////////
    // Draw rectangular selection, if any:
    if ( _rectangularSelect && [_m mouseDragging] ) {
	NSRect selectRect = NSMakeRect( _viewMouseDownPoint.x, _viewMouseDownPoint.y, 
				       (_viewMouseDraggedPoint.x - _viewMouseDownPoint.x),  // width
				       (_viewMouseDraggedPoint.y - _viewMouseDownPoint.y) );  // height
	NSBezierPath *P = [NSBezierPath bezierPathWithRect:selectRect];
	[P setLineWidth:1];
	[[NSColor keyboardFocusIndicatorColor] set];
	[P stroke];
    }
    
    if (_overMarginGuide) {
	[_renderer drawMarginGuide:_overMarginGuide];
    }
}


@end
