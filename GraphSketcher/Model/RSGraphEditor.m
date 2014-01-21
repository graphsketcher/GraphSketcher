// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/Model/RSGraphEditor.m 200244 2013-12-10 00:11:55Z correia $


#import <GraphSketcherModel/RSGraphEditor.h>

#import <GraphSketcherModel/RSGraph.h>
#import <GraphSketcherModel/RSDataMapper.h>
#import <GraphSketcherModel/RSGraphRenderer.h>
#import <GraphSketcherModel/RSUndoer.h>
#import <GraphSketcherModel/RSUndoerTarget.h>
#import <GraphSketcherModel/RSHitTester.h>
#import <GraphSketcherModel/RSHitTester-Snapping.h>

#import <GraphSketcherModel/RSUnknown.h>
#import <GraphSketcherModel/RSTextLabel.h>
#import <GraphSketcherModel/RSGroup.h>
#import <GraphSketcherModel/RSVertex.h>
#import <GraphSketcherModel/RSLine.h>
#import <GraphSketcherModel/RSConnectLine.h>
#import <GraphSketcherModel/RSEquationLine.h>
#import <GraphSketcherModel/RSNumber.h>
#import <OmniFoundation/OFPreference.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/Model/RSGraphEditor.m 200244 2013-12-10 00:11:55Z correia $")

@interface RSGraphEditor (RSUndoerTarget) <RSUndoerTarget>
@end

@interface RSGraphEditor (/*Private*/)
- (void)updateConstrainedElements;
- (void)modelChangeRequires:(RSModelUpdateRequirement)req;
@end

@implementation RSGraphEditor

- init;
{
    OBRejectUnusedImplementation(self, _cmd);
    return nil;
}

- initWithGraph:(RSGraph *)graph undoer:(RSUndoer *)undoer;
{
    OBPRECONDITION(graph);
    OBPRECONDITION(undoer);
    OBPRECONDITION(undoer.target == nil);
    
    if (!(self = [super init]))
        return nil;
    
    _undoer = [undoer retain];
    _undoer.target = self;
    
    _graph = [graph retain];
    _graph.delegate = self;
    
    [_graph addObserver:self forKeyPath:@"autoMaintainsWhitespace" options:NSKeyValueObservingOptionNew context:NULL];
    [_graph addObserver:self forKeyPath:@"whitespace" options:NSKeyValueObservingOptionNew context:NULL];
    [_graph addObserver:self forKeyPath:@"canvasSize" options:NSKeyValueObservingOptionNew context:NULL];
    [[_graph xAxis] addObserver:self forKeyPath:@"titleDistance" options:NSKeyValueObservingOptionNew context:NULL];
    [[_graph yAxis] addObserver:self forKeyPath:@"titleDistance" options:NSKeyValueObservingOptionNew context:NULL];
    [[_graph xAxis] addObserver:self forKeyPath:@"labelDistance" options:NSKeyValueObservingOptionNew context:NULL];
    [[_graph yAxis] addObserver:self forKeyPath:@"labelDistance" options:NSKeyValueObservingOptionNew context:NULL];
    
    _mapper = [[RSDataMapper alloc] initWithGraph:_graph];
    _renderer = [[RSGraphRenderer alloc] initWithMapper:_mapper];
    _hitTester = [[RSHitTester alloc] initWithEditor:self];

    _needsUpdateDisplay = YES;
    _needsUpdateWhitespace = YES;
    
    return self;
}

- (void)dealloc;
{
    OBPRECONDITION(_nonretained_delegate == nil); // Our owner should call -invalidate
    OBPRECONDITION(_graph == nil);
    OBPRECONDITION(_undoer == nil);
    OBPRECONDITION(_mapper == nil);
    OBPRECONDITION(_renderer == nil);
    OBPRECONDITION(_hitTester == nil);

    [super dealloc];
}

- (void)invalidate;
{    
    _nonretained_delegate = nil;
    
    [_hitTester release];
    _hitTester = nil;
    
    [_mapper release];
    _mapper = nil;
    
    [_renderer release];
    _renderer = nil;
    
    [_graph removeObserver:self forKeyPath:@"autoMaintainsWhitespace"];
    [_graph removeObserver:self forKeyPath:@"whitespace"];
    [_graph removeObserver:self forKeyPath:@"canvasSize"];
    [[_graph xAxis] removeObserver:self forKeyPath:@"titleDistance"];
    [[_graph yAxis] removeObserver:self forKeyPath:@"titleDistance"];
    [[_graph xAxis] removeObserver:self forKeyPath:@"labelDistance"];
    [[_graph yAxis] removeObserver:self forKeyPath:@"labelDistance"];

    // This clears the graph's undo manager so that as its objects are deallocated, they'll get back nil for -undoManager and not keep a stale pointer to it.
    // This means that RSGraphEditor owns any graph given to it.
    [_graph invalidate];
    [_graph release];
    _graph = nil;

    [[_undoer undoManager] removeAllActions];
    [_undoer invalidate];
    [_undoer release];
    _undoer = nil;
}

@synthesize graph = _graph;
@synthesize undoer = _undoer;
@synthesize delegate = _nonretained_delegate;
@synthesize mapper = _mapper;
@synthesize renderer = _renderer;
@synthesize hitTester = _hitTester;

- (void)updateBounds:(CGRect)bounds;
{
    [_mapper setBounds:bounds];
    
    // update whitespace and axis calculations:
    [self setNeedsUpdateWhitespace];
}

- (void)prepareForDisplay;
{
    // update display parameters if necessary
    if( _needsUpdateDisplay ) {
        [self updateDisplayNow];
    }
}

- (void)prepareForSave;
{
    [_undoer endRepetitiveUndo];
    [_graph recomputeNow];
}

- (void)setNeedsDisplay;
{
    [self modelChangeRequires:RSUpdateDraw];
}

- (void)setNeedsUpdateWhitespace;
{
    [self modelChangeRequires:RSUpdateWhitespace];
}

- (void)autoScaleIfWanted;
{
    [_mapper scaleAxesToMakeVisible:[_graph Vertices]];
}

#pragma mark -
#pragma mark Inspector helpers

- (void)setDistanceValue:(CGFloat)distanceValue forElement:(RSGraphElement *)obj snapDistanceToNearestInteger:(BOOL)snapDistanceToNearestInteger;
{
    RSLine *L;
    RSGraphElement *owner;
    
    // Round to integer if using the slider
    if (snapDistanceToNearestInteger) {
        distanceValue = nearbyint(distanceValue);
    }
    
    //[distanceField setDoubleValue:distanceValue];
    
    if ( [obj isKindOfClass:[RSUnknown class]] ) {
        //[obj setWidth:distanceValue];
	//[[OFPreferenceWrapper sharedPreferenceWrapper] setDouble:distanceValue 
	//										 forKey: @"DefaultLineWidth"];
    }
    else if ( [obj isKindOfClass:[RSVertex class]] ) {
        [obj setLabelDistance:distanceValue];
    }
    else if ( (L = [RSGraph isLine:obj]) ) {
        [L setLabelDistance:distanceValue];
    }
    else if ( [obj isKindOfClass:[RSTextLabel class]] ) {
	if ([_graph isAxisTitle:(RSTextLabel *)obj]) {
	    RSAxis *axis = [_graph axisOfElement:obj];
	    [axis setTitleDistance:distanceValue];
	}
	else {
	    owner = [obj owner];
	    if (!owner)
		owner = [_graph axisOfElement:obj];
	    if( owner ) {
		[owner setLabelDistance:distanceValue];
	    }
	}
    }
    else if ( [obj isKindOfClass:[RSAxis class]] ) {
        [obj setLabelDistance:distanceValue];
    }
    else if ( [obj isKindOfClass:[RSGroup class]] ) {
        [obj setLabelDistance:distanceValue];
    }
    else {
	NSLog(@"ERROR: changeSliderValue doesn't support this context: %@", [obj class]);
	return;
    }
}

- (void)setShape:(NSInteger)styleIndex forElement:(RSGraphElement *)obj;
{
    if ( [obj isKindOfClass:[RSUnknown class]] || [obj isKindOfClass:[RSVertex class]] ) {
	// set default:
        if (styleIndex != RS_NONE) {
            [[OFPreferenceWrapper sharedPreferenceWrapper] setInteger:styleIndex forKey: @"DefaultVertexShape"];
        }
    }
    else {
        [_undoer setActionName:NSLocalizedStringFromTableInBundle(@"Change Point Shape", @"GraphSketcherModel-UndoActions", OMNI_BUNDLE, @"Undo action name")];
    }
    
    [obj setShape:styleIndex];
}

- (CGFloat)widthForElement:(RSGraphElement *)obj;
{
    OBPRECONDITION([obj hasWidth]);
    
    RSLine *L;
    if ( (L = [RSGraph isLine:obj]) ) {
	obj = L;
    }
    
    return [obj width];
}

- (void)setWidth:(CGFloat)width forElement:(RSGraphElement *)obj snapDistanceToNearestInteger:(BOOL)snapDistanceToNearestInteger;
{
    // If using slider, round to nearest .2
    if (snapDistanceToNearestInteger) {
        width = nearbyint(width*5)/5;
    }
    
    if ( [obj isKindOfClass:[RSUnknown class]] || [obj isKindOfClass:[RSVertex class]] || [RSGraph isLine:obj]) {
	[[OFPreferenceWrapper sharedPreferenceWrapper] setDouble:width forKey:@"DefaultLineWidth"];
    }
    
    [obj setWidth:width];
    
    
    //    if ( [obj isKindOfClass:[RSAxis class]] ) {
    //	// set user preference:
    //	[[OFPreferenceWrapper sharedPreferenceWrapper] setDouble:[sender floatValue] forKey:@"DefaultAxisWidth"];
    //    }
    
}

- (RSGraphElement *)setConnectMethod:(RSConnectType)connectMethod forElement:(RSGraphElement *)obj;
{
    if ( [obj isKindOfClass:[RSUnknown class]] ) {
	if (connectMethod == RSConnectLinearRegression) {
	    // Create a best-fit line from everything on the graph
	    // No, don't, but also don't let a best-fit line be the default.
            //	    obj = [_graph userVertexElements];
            //	    if (obj)
            //		[_s setSelection:obj];
            //	    else
            //		return;
	    
	    //[self selectSegmentWithConnectMethod:connectMethodFromName([[OFPreferenceWrapper sharedPreferenceWrapper] objectForKey:@"DefaultConnectMethod"])];
	    return obj;
	}
	else {
	    [obj setConnectMethod:connectMethod];
	    // set default:
	    [[OFPreferenceWrapper sharedPreferenceWrapper] setObject:nameFromConnectMethod(connectMethod) forKey: @"DefaultConnectMethod"];
	    return obj;
	}
    }
    // Normally, always set the default
    else if (connectMethod == RSConnectCurved || connectMethod == RSConnectStraight) {
        // set default:
        [[OFPreferenceWrapper sharedPreferenceWrapper] setObject:nameFromConnectMethod(connectMethod) forKey: @"DefaultConnectMethod"];
    }
    
    return [_graph changeLineTypeOf:obj toConnectMethod:connectMethod];
}

- (RSGraphElement *)setDash:(NSInteger)styleIndex forElement:(RSGraphElement *)obj;
{
    if ([obj isKindOfClass:[RSUnknown class]] || [RSGraph isLine:obj]) {
	// set default:
	[[OFPreferenceWrapper sharedPreferenceWrapper] setInteger:styleIndex
							   forKey: @"DefaultDashStyle"];
    }
    
    // Create new line(s) if necessary:
    if ([obj numberOfElementsWithClass:[RSLine class]] == 0) {
        RSGraphElement *newSelection = [self.graph changeLineTypeOf:obj toConnectMethod:RSConnectCurved];
        obj = newSelection;
    }
    
    [obj setDash:styleIndex];
    
    // Need to redraw the lines to display the new dash styles.
    // TODO: make this less heavy-handed
    [_renderer invalidateCache];
    
    return obj;
}

- (void)changeX:(data_p)value forElement:(RSGraphElement *)obj;
{
    [_undoer registerRepetitiveUndoWithObject:obj 
                                       action:@"setPosition" 
                                        state:NSValueFromDataPoint([obj position])
                                         name:NSLocalizedStringFromTableInBundle(@"Update Positions", @"GraphSketcherModel-UndoActions", OMNI_BUNDLE, @"Undo action name")];
    
    [obj setPositionx:value];
    [self autoScaleIfWanted];
}

- (void)changeY:(data_p)value forElement:(RSGraphElement *)obj;
{
    [_undoer registerRepetitiveUndoWithObject:obj 
                                       action:@"setPosition" 
                                        state:NSValueFromDataPoint([obj position])
                                         name:NSLocalizedStringFromTableInBundle(@"Update Positions", @"GraphSketcherModel-UndoActions", OMNI_BUNDLE, @"Undo action name")];
    
    [obj setPositiony:value];
    [self autoScaleIfWanted];
}

static RSGraphElement *_arrowElement(RSGraphElement *obj)
{
    if ([obj isKindOfClass:[RSVertex class]]) {
        obj = [(RSVertex *)obj effectiveArrowParent];
    }
    
    if ([obj isKindOfClass:[RSGroup class]]) {
	obj = [(RSGroup *)obj firstElementWithClass:[RSLine class]];
    }
    
    return obj;
}

- (BOOL)hasMinArrow:(RSGraphElement *)obj;
{
    if (!(obj = _arrowElement(obj)))
        return NO;
    
    // Line
    RSLine *L;
    if ((L = [RSGraph isLine:obj]))
	return ([[L startVertex] shape] == RS_ARROW);
    
    // Axis
    if ([obj isKindOfClass:[RSAxis class]])
	return [(RSAxis *)obj minEndIsArrow];
    
    return NO;
}

- (BOOL)hasMaxArrow:(RSGraphElement *)obj;
{
    if (!(obj = _arrowElement(obj)))
        return NO;
    
    // Line
    RSLine *L;
    if ((L = [RSGraph isLine:obj]))
	return ([[L endVertex] shape] == RS_ARROW);
    
    // Axis
    if ([obj isKindOfClass:[RSAxis class]])
	return [(RSAxis *)obj maxEndIsArrow];
    
    return NO;
}

- (void)_setArrowShape:(NSInteger)style forLine:(RSLine *)L isLeft:(BOOL)isLeft;
{
    NSInteger specificStyle, newStyle;
    RSVertex *V;
    
    if (isLeft) {
	V = [L startVertex];
	specificStyle = RS_LEFT_ARROW;
    }
    else {
	V = [L endVertex];
	specificStyle = RS_RIGHT_ARROW;
    }
    
    if (style == specificStyle || style == RS_BOTH_ARROW || style == RS_ARROW)
	newStyle = RS_ARROW;
    else
	newStyle = RS_NONE;
    
    if ([V shape] != newStyle) {
	[V setShape:newStyle];
	[V setArrowParent:L];
    }
    
    [_undoer setActionName:NSLocalizedStringFromTableInBundle(@"Change Arrow", @"GraphSketcherModel-UndoActions", OMNI_BUNDLE, @"Undo action name")];
}

- (void)changeArrowhead:(NSInteger)styleIndex forElement:(RSGraphElement *)obj isLeft:(BOOL)isLeft;
{
    RSLine *L;
    if ( [obj isKindOfClass:[RSAxis class]] ) {
        [obj setShape:styleIndex];
	
	//[[OFPreferenceWrapper sharedPreferenceWrapper] setInteger:[obj shape] forKey:@"DefaultAxisShape"];
	return;
    }
    else if ( [obj isKindOfClass:[RSUnknown class]] ) {
        [obj setShape:styleIndex];
    }
    
    else if ( [obj isKindOfClass:[RSVertex class]] ) {
        [self _setArrowShape:styleIndex forLine:[(RSVertex *)obj effectiveArrowParent] isLeft:isLeft];
    }
    
    else if ( (L = [RSGraph isLine:obj]) ) {
	[self _setArrowShape:styleIndex forLine:L isLeft:isLeft];
    }
    
    // A group (that's not an existing line group)
    else if ( [obj isKindOfClass:[RSGroup class]] ) {
	if ( [RSGraph isText:obj] ) {
	    // do nothing
	    return;
	}
	// Find all the lines in the selection
	RSGroup *G = [(RSGroup *)obj groupWithClass:[RSLine class]];
	
	// Change their arrow properties accordingly
	for (L in [G elements]) {
	    [self _setArrowShape:styleIndex forLine:L isLeft:isLeft];
	}
    }
    else {
	OBASSERT_NOT_REACHED("Arrow control should have been disabled");
    }
}

- (void)setCanvasSize:(CGSize)canvasSize;
{
    CGSize minSize = [_graph minCanvasSize];
    CGSize safeSize = RSUnionSize(canvasSize, minSize);
    [_graph setCanvasSize:safeSize];
}

- (void)setPlacement:(RSAxisPlacement)placement forAxis:(RSAxis *)axis;
{
    if (placement == RSHiddenPlacement) {
	// hide the axis rather than change the placement
	[axis setDisplayAxis:NO];
        
        // but also set the placement to the origin for the purposes of other view calculations
        [axis setPlacement:RSOriginPlacement];
	
	//[_s deselect];
    }
    else {
	// make sure the axis is visible
	[axis setDisplayAxis:YES];
	// change the placement
	[axis setPlacement:placement];
    }
    
    [self setNeedsUpdateWhitespace];
}

- (void)setDisplayTitle:(BOOL)displaysTitle forAxis:(RSAxis *)axis;
{
    [axis setDisplayTitle:displaysTitle];
    [self setNeedsUpdateWhitespace];
}

- (void)setDisplayTickMarks:(BOOL)displaysTickMarks forAxis:(RSAxis *)axis;
{
    [axis setDisplayTicks:displaysTickMarks];
    [self setNeedsUpdateWhitespace];
}

- (void)setDisplayTickLabels:(BOOL)displaysTickLabels forAxis:(RSAxis *)axis;
{
    [axis setDisplayTickLabels:displaysTickLabels];
    [self setNeedsUpdateWhitespace];
}

- (void)setTickSpacing:(data_p)tickSpacing forAxis:(RSAxis *)axis;
{
    [axis setUserSpacing:tickSpacing];
    
    // also make sure tick marks are being displayed
    [_graph displayTicksIfNecessaryOnAxis:axis];
    
    [_undoer setActionName:NSLocalizedStringFromTableInBundle(@"Set Axis Spacing", @"GraphSketcherModel-UndoActions", OMNI_BUNDLE, @"Undo action name")];
    
    [self setNeedsUpdateWhitespace];
}


#pragma mark -
#pragma mark Axis manipulation

- (void)dragAxisEnd:(RSAxisEnd)axisEnd downTick:(data_p)downPos currentPosition:(CGFloat)viewPos viewMin:(CGFloat)viewMin viewMax:(CGFloat)viewMax;
{
    //NSLog(@"dt: %f, vPos: %f, vMin: %f, vMax: %f", downPos, viewPos, viewMin, viewMax);
    
    RSAxis *axis = [_graph axisWithAxisEnd:axisEnd];
    [axis setUserModifiedRange:YES];
    
    // Define a minimum number of pixels between the fixed end and the moving cursor, and make sure this number is less than the current axis length
    CGFloat smallestBufferToFixedEnd = 20;
    CGFloat axisLength = viewMax - viewMin;
    if (smallestBufferToFixedEnd > axisLength) {
        smallestBufferToFixedEnd = axisLength;
    }
    
    data_p axisMin = [axis min];
    data_p axisMax = [axis max];
    
    if (axisEnd == RSAxisXMax || axisEnd == RSAxisYMax) {
        // Calculate a max such that min stays fixed and downPos appears where the mouse is.
        CGFloat fixedDistance = viewPos - viewMin;
        if (fixedDistance < smallestBufferToFixedEnd) {
            fixedDistance = smallestBufferToFixedEnd;
        }
        
        data_p newMax;
        if ([axis axisType] == RSAxisTypeLinear) {
            newMax = (downPos - axisMin)*(viewMax - viewMin)/fixedDistance + axisMin;
        }
        else {  // RSAxisTypeLogarithmic
            if (axisMin > 0) {
                data_p logOfAnswer = log2(axisMin) + log2(downPos/axisMin) * (viewMax - viewMin)/fixedDistance;
                //NSLog(@"logOfAnswer: %.13g", logOfAnswer);
                newMax = exp2(logOfAnswer);
            }
            else {  // all-negative log axis
                OBASSERT(axisMax < 0);
                data_p logOfAnswer = log2(-axisMin) + log2(downPos/axisMin) * (viewMax - viewMin)/fixedDistance;
                //NSLog(@"logOfAnswer: %.13g", logOfAnswer);
                newMax = -exp2(logOfAnswer);
            }
        }
        
        OBASSERT(newMax > axisMin);
        [axis setMax:newMax];
    }
    else if (axisEnd == RSAxisXMin || axisEnd == RSAxisYMin) {
        // Calculate a min such that max stays fixed and downPos appears where the mouse is.
        CGFloat fixedDistance = viewMax - viewPos;
        if (fixedDistance < smallestBufferToFixedEnd) {
            fixedDistance = smallestBufferToFixedEnd;
        }
        
        data_p newMin;
        if ([axis axisType] == RSAxisTypeLinear) {
            newMin = axisMax - (axisMax - downPos)*(viewMax - viewMin)/fixedDistance;
        }
        else {  // RSAxisTypeLogarithmic
            if (axisMin > 0) {
                data_p logOfAnswer = log2(axisMax) - log2(axisMax/downPos) * (viewMax - viewMin)/fixedDistance;
                newMin = exp2(logOfAnswer);
            }
            else {  // all-negative log axis
                OBASSERT(axisMax < 0);
                data_p logOfAnswer = log2(-axisMax) - log2(axisMax/downPos) * (viewMax - viewMin)/fixedDistance;
                newMin = -exp2(logOfAnswer);
            }
        }
        
        OBASSERT(newMin < axisMax);
        [axis setMin:newMin];
    }
    
    // snap to nearby tick mark, if it's near enough:
    [_hitTester snapAxisEndToGrid:axisEnd viewMin:viewMin viewMax:viewMax];
    
    // check that there are a reasonable number of ticks:
    [axis updateTickMarks];
    
    [self setNeedsUpdateWhitespace];
    [self updateDisplayNow];
}

- (void)dragAxisEnd:(RSAxisEnd)axisEnd downPoint:(RSDataPoint)downPoint currentViewPoint:(CGPoint)viewPoint viewMins:(CGPoint)viewMins viewMaxes:(CGPoint)viewMaxes;
// Convenience version for situations where the caller has the full points
{
    RSAxis *axis = [_graph axisWithAxisEnd:axisEnd];
    data_p downTick;
    CGFloat viewPos, viewMin, viewMax;
    if ([axis orientation] == RS_ORIENTATION_HORIZONTAL) {
        downTick = downPoint.x;
        viewPos = viewPoint.x;
        viewMin = viewMins.x;
        viewMax = viewMaxes.x;
    } else {
        downTick = downPoint.y;
        viewPos = viewPoint.y;
        viewMin = viewMins.y;
        viewMax = viewMaxes.y;
    }
    
    [self dragAxisEnd:axisEnd downTick:downTick currentPosition:viewPos viewMin:viewMin viewMax:viewMax];
}

- (RSAxisEnd)axisEndEquivalentForPoint:(RSDataPoint)startPos onAxisOrientation:(int)orientation;
// When dragging an axis label, need to decide which axis end to behave like.
// startPos is in data coords.
{
    CGFloat viewMin, viewMax;
    CGFloat viewPos;
    CGPoint tickView;
    
    if( orientation == RS_ORIENTATION_HORIZONTAL ) {
        viewMin = [_mapper viewMins].x;
        viewMax = [_mapper viewMaxes].x;
        
        // calculate tick point in view coords:
        tickView = [_mapper convertToViewCoords:RSDataPointMake(startPos.x, [_graph yMin])];
        viewPos = tickView.x;
        
        CGFloat axisLength = viewMax - viewMin;
        if (viewPos > (viewMin + axisLength/2)) {
            return RSAxisXMax;
        } else {
            return RSAxisXMin;
        }
    }
    else {  // VERTICAL
        viewMin = [_mapper viewMins].y;
        viewMax = [_mapper viewMaxes].y;
        
        // calculate tick point in view coords:
        tickView = [_mapper convertToViewCoords:RSDataPointMake([_graph xMin], startPos.y)];
        viewPos = tickView.y;
        
        CGFloat axisLength = viewMax - viewMin;
        if (viewPos > (viewMin + axisLength/2)) {
            return RSAxisYMax;
        } else {
            return RSAxisYMin;
        }
    }
    
    OBASSERT_NOT_REACHED("Should have found an axis end equivalent by now.");
    return RSAxisEndNone;
}


#pragma mark -
#pragma mark Label text editing

- (void)processText:(NSString *)text forEditedLabel:(RSTextLabel *)TL;
{
    RSGraph *graph = self.graph;
    if ( [graph isAxisEndLabel:TL] ) {
        
        if ([text isEqualToString:@""]) {
            text = RS_DELETED_STRING;
        }
        
        // Find out if it is text or numeric.  We should not be "lenient" about this -- if the value is not strictly a number, the user probably intends it to be a label.
        double doubleValue;
        BOOL isNumber = [RSNumber getStricterDoubleValue:&doubleValue forString:text];
        
        if ( TL == [[graph xAxis] maxLabel] ) {
            if( isNumber ) {
                [graph setXMax:doubleValue];
            }
            else {
                [[graph xAxis] setUserString:text forTick:[graph xMax]];
            }
        }
        else if ( TL == [[graph xAxis] minLabel] ) {
            if( isNumber ) {
                [graph setXMin:doubleValue];
            }
            else {
                [[graph xAxis] setUserString:text forTick:[graph xMin]];
            }
        }
        else if ( TL == [[graph yAxis] maxLabel] ) {
            if( isNumber ) {
                [graph setYMax:doubleValue];
            }
            else {
                [[graph yAxis] setUserString:text forTick:[graph yMax]];
            }
        }
        else if ( TL == [[graph yAxis] minLabel] ) {
            if( isNumber ) {
                [graph setYMin:doubleValue];
            }
            else {
                [[graph yAxis] setUserString:text forTick:[graph yMin]];
            }
        }
        
        // Update immediately
        [self setNeedsUpdateWhitespace];
        [self updateDisplayNow];
    }
}

- (CGPoint)updatedLocationForEditedTextLabel:(RSTextLabel *)TL withSize:(CGSize)size;
{
    //
    // Calculate frame origin
    RSGraphElement *owner = [TL owner];
    CGPoint p;
    
    if ( !owner ) {  // a standalone text label - just get its position
	p = [_mapper convertToViewCoords:[TL position]];
    }
    else {  // position the label around its owner object
        p = [_renderer positionLabel:TL forOwner:owner];
    }
    
    // Special case for editing labels attached to straight lines, because we don't want to edit labels at arbitrary rotations (note that the label itself will be positioned correctly in the positionLabel:forOwner: call above)
    if ( [owner isKindOfClass:[RSLine class]] && [RSGraph hasStraightSegments:owner] ) {
	RSLine *L = (RSLine *)owner;
        CGFloat t = [L slide];
        RSTwoPoints tangent = [_mapper lineTangentToLine:L atTime:[L slide] useDelta:0.001f];
        CGFloat d = size.width;
        
        // move label f of the way down the line
        p.x = (CGFloat)(tangent.p1.x * (1.0-t) + tangent.p2.x * (t));
        p.y = (CGFloat)(tangent.p1.y * (1.0-t) + tangent.p2.y * (t));
        
        // shift over so that the text field is centered above the line
        p.x -= d / 2;
    }
    
    return p;
}

#pragma mark -
#pragma mark Special actions

- (void)autoRescueTextLabels;
// "Rescues" text labels that were pasted or autoScaled out of the graph window.
{
    NSArray *userLabels = [_graph userLabels];
    CGRect bounds = [_mapper bounds];
    CGFloat margin = 10;
    
    CGRect unionRect = CGRectZero;
    for (RSTextLabel *TL in userLabels) {
        CGRect rect = [_mapper rectFromLabel:TL offset:margin];  // Allow for a 10-pixel whitespace margin
        
        if (CGRectEqualToRect(unionRect, CGRectZero)) {
            unionRect = rect;
        } else {
            unionRect = CGRectUnion(rect, unionRect);
        }
    }
    
    if (CGRectEqualToRect(unionRect, CGRectZero))  // No labels
        return;
    
    if (CGRectContainsRect(bounds, unionRect))  // No labels need to be rescued
        return;
    
    for (RSTextLabel *TL in userLabels) {
        CGRect rect = [_mapper rectFromLabel:TL offset:margin];
        if (CGRectContainsRect(bounds, rect))  // this label is fully visible
            continue;
        
        // Otherwise, label is not fully visible. Reposition it to be back on screen.
        CGRect newRect = rect;
        if (rect.origin.x < CGRectGetMinX(bounds))
            newRect.origin.x = CGRectGetMinX(bounds) + margin;
        if (CGRectGetMaxX(rect) > CGRectGetMaxX(bounds))
            newRect.origin.x = CGRectGetMaxX(bounds) - CGRectGetWidth(rect) + margin;  // (width already has 2 margins)
        if (rect.origin.y < CGRectGetMinY(bounds))
            newRect.origin.y = CGRectGetMinY(bounds) + margin;
        if (CGRectGetMaxY(rect) > CGRectGetMaxY(bounds))
            newRect.origin.y = CGRectGetMaxY(bounds) - CGRectGetHeight(rect) + margin;
        
        CGPoint newViewPos = newRect.origin;
        
        // Set up undo
        [[self undoer] registerUndoWithObject:TL
                                          action:@"setPosition" 
                                           state:NSValueFromDataPoint([TL position])];
        
        [TL setPosition:[_mapper convertToDataCoords:newViewPos]];
    }
}

- (NSArray *)_generateTickIntersectionDataFromLine:(RSLine *)L standardDeviation:(data_p)stddev;
{
    // Get a sorted array of tick marks
    RSAxis *A = [_graph xAxis];
    NSMutableArray *tickArray = [[[A allTicks] mutableCopy] autorelease];
    if (![_graph noAxisComponentsAreDisplayed]) {
        [tickArray insertObject:[NSNumber numberWithDouble:[A min]] atIndex:0];
        [tickArray addObject:[NSNumber numberWithDouble:[A max]]];
    }
    // Add the line's start and end points
    [tickArray addObject:[NSNumber numberWithDouble:[L startPoint].x]];
    [tickArray addObject:[NSNumber numberWithDouble:[L endPoint].x]];
    // Sort
    [tickArray sortUsingSelector:@selector(compare:)];
    
    NSMutableArray *newVertices = [NSMutableArray array];
    
    NSUInteger count = 0;
    data_p tick = DBL_MAX;
    for (NSNumber *number in tickArray) {
        data_p oldTick = tick;
        tick = [number doubleValue];
        
        // Skip duplicates (added start/end points could the same as tick values)
        if (nearlyEqualDataValues(oldTick, tick))
            continue;
        
        // Find the intersection of the tick mark x-value with the line
        CGFloat viewTick = [_mapper convertToViewCoords:tick inDimension:RS_ORIENTATION_HORIZONTAL];
        CGFloat viewYIntercept;
        BOOL result = [_mapper xValue:viewTick intersectsLine:L saveY:&viewYIntercept];
        if (!result)
            continue;
        
        data_p dataY = [_mapper convertToDataCoords:viewYIntercept inDimension:RS_ORIENTATION_VERTICAL];
        //NSLog(@"data i: %.13g, %.13g", tick, dataY);
        
        // Make a vertex
        RSVertex *V = [[RSVertex alloc] initWithGraph:_graph];
        [V setPosition:RSDataPointMake(tick, dataY)];
        [V setShape:RS_CIRCLE];
        [newVertices addObject:V];
        [V release];
        
        count += 1;
    }
    DEBUG_RS(@"generated %d data points (out of %d ticks)", (int)count, (int)[tickArray count]);
    
    return newVertices;
}

- (RSGraphElement *)interpolateLine:(RSLine *)L;
{
    NSArray *array = [self _generateTickIntersectionDataFromLine:L standardDeviation:0];
    
    if (![array count])
        return nil;
    
    // Group the new vertices together and make a new line with them
    RSGroup *newVertices = [[[RSGroup alloc] initWithGraph:_graph byCopyingArray:array] autorelease];
    [_graph setGroup:[RSGroup groupWithGraph:_graph] forElement:newVertices];
    
    RSConnectLine *newLine = [[[RSConnectLine alloc] initWithGraph:_graph identifier:nil vertices:newVertices color:[L color] width:[L width] dash:[L dash] slide:[L slide] labelDistance:[L labelDistance]] autorelease];
    [newLine setConnectMethod:RSConnectStraight];
    
    [_graph addElement:newLine];
    [_graph removeElement:[L groupWithVertices]];
    
    return [newLine groupWithVertices];
}

- (RSGroup *)interpolateLines:(NSArray *)lines;
{
    if (![lines count])
        return nil;
    
    RSGroup *newSelection = [RSGroup groupWithGraph:_graph];
    
    for (RSLine *L in lines) {
        OBASSERT([L isKindOfClass:[RSLine class]]);
        
        RSGraphElement *interpolatedGroup = [self interpolateLine:L];
        [newSelection addElement:interpolatedGroup];
    }
    
    return newSelection;
}


#pragma mark -
#pragma mark RSGraphDelegate

- (void)modelChangeRequires:(RSModelUpdateRequirement)req;
{
    if (req == RSUpdateNone)
	return;
    
    if (req == RSUpdateWhitespace) {
	_needsUpdateWhitespace = YES;
    }
    else if (req == RSUpdateConstraints) {
	_needsUpdateConstraints = YES;
    }
    
    // In all cases, the view needs to be redrawn:
    _needsUpdateDisplay = YES;
    
    [_nonretained_delegate graphEditorNeedsDisplay:self];
}

#pragma mark -
#pragma mark KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context;
{
    if (object == _graph) {
	if ([keyPath isEqual:@"autoMaintainsWhitespace"] || 
	    [keyPath isEqual:@"whitespace"] ||
	    [keyPath isEqual:@"canvasSize"] ) {
	    [self setNeedsUpdateWhitespace];
	}
    }
    else if ([object isKindOfClass:[RSAxis class]]) {
	[self setNeedsUpdateWhitespace];
    }
}


#pragma mark -
#pragma mark Private

- (void)updateDisplayNow;
{
    OBPRECONDITION(_mapper);
    OBPRECONDITION(_renderer);
    
    // Don't log undo for these automatic actions
    [[_undoer undoManager] disableUndoRegistration];
    @try {
        [_mapper resetCurveCache];
        
        if (_needsUpdateWhitespace) {
            //DEBUG_RS(@"Updating whitespace");
            
            [_mapper mappingParametersDidChange];
            [_renderer updateWhitespace];
            [_mapper mappingParametersDidChange];
            
            // update the axis labels:
            [_renderer positionAllAxisLabels];
            
            [_renderer invalidateCache];
            
            // Update equation lines
            for (RSLine *L in [_graph Lines]) {
                if ([L isKindOfClass:[RSEquationLine class]]) {
                    [L setNeedsRecompute];
                }
            }
            
            _needsUpdateWhitespace = NO;
        }
        
        if (_needsUpdateConstraints) {
            [self updateConstrainedElements];
            
            [_renderer invalidateCache];
            
            _needsUpdateConstraints = NO;
        }
        
        
        // update positions of attached labels:
        for (RSTextLabel *T in [_graph Labels]) {
            if ([T owner])
                [_renderer positionLabel:nil forOwner:[T owner]];
        }
        
        [_nonretained_delegate graphEditorDidUpdate:self];
        
        _needsUpdateDisplay = NO;
    } @finally {
        [[_undoer undoManager] enableUndoRegistration];
    }
}

// recalculate the computationally expensive objects
- (void)updateConstrainedElements;
{
    //DEBUG_RS(@"Updating constraints");
    
    // recompute positions of vertices that are snapped to lines/intersections
    [_hitTester updateSnappedTos];
    
    // Best-fit lines:
    [_graph recomputeNow];
}


@end

#import <GraphSketcherModel/RSLine.h>
#import <GraphSketcherModel/RSVertex.h>
#import <GraphSketcherModel/RSFill.h>
#import <GraphSketcherModel/RSTextLabel.h>

@implementation RSGraphEditor (RSUndoerTarget)

- (void)setAttributes:(NSDictionary *)D;
// Accepts a dictionary of objects with keys corresponding to selectors, except
// for one of the keys which is equal to @"object" and corresponds to the object
// the selectors should be applied to.
{
    id attrib;
    BOOL modified = NO;
    RSGraphElement *obj = [D objectForKey:@"object"];
    //RSTextLabel *TLobj = [D objectForKey:@"object"];
    RSFill *FillObj = [D objectForKey:@"object"];
    //RSAxis *AxisObj = [D objectForKey:@"object"];
    NSString *actionName = [_undoer.undoManager undoActionName];
    
    Log3(@"GraphDocument setAttributes called (main UNDO method)");
    
    // Notify Logger
    //[[NSNotificationCenter defaultCenter] postNotificationName:@"RSLogUndo" object:nil];
    
    // always start a new undo group after undo-ing
    [_undoer endRepetitiveUndo];
    
    if ((attrib = [D objectForKey:@"setPosition"])) {
	// Set the action of Redo:
	[_undoer registerUndoWithObject:obj
                                 action:@"setPosition" 
                                  state:NSValueFromDataPoint([obj position])];
	/*
	 D = [NSDictionary dictionaryWithObjectsAndKeys:obj, @"object",
	 NSValueFromDataPoint([obj position]), @"position", nil];
	 // This sets the action of *Redo*:
	 [_undoer.undoManager registerUndoWithTarget:self 
	 selector:@selector(setAttributes:) 
	 object:D];
	 */
	[obj setPosition:dataPointFromNSValue(attrib)];
	modified = YES;
    }
    if ((attrib = [D objectForKey:@"addVertexToFill"])) {
        //	// Set the action of Redo:
        //	[_undoer registerUndoWithObject:FillObj
        //			    action:@"removeVertexFromFill" 
        //			     state:attrib];
	OBASSERT([attrib count] == 2);
	[_graph addVertex:[attrib objectAtIndex:0] toFill:FillObj atIndex:[[attrib objectAtIndex:1] integerValue]];
	
	// use original undo menu item name
	[_undoer setActionName:actionName];
	modified = YES;
    }
    if ((attrib = [D objectForKey:@"removeVertexFromFill"])) {
        //	// Set the action of Redo:
        //	[_undoer registerUndoWithObject:FillObj
        //			    action:@"addVertexToFill" 
        //			     state:attrib];
	OBASSERT([attrib count] == 2);
	[_graph removeVertex:[attrib objectAtIndex:0] fromFill:FillObj];
	
	// use original undo menu item name
	[_undoer setActionName:actionName];
	modified = YES;
    }
    //    if ((attrib = [D objectForKey:@"setSnappedTos"])) {
    //	// Set the action of Redo:
    //	//[_undoer registerUndoWithObjectsIn:[VertexObj vertexCluster] action:@"setSnappedTos"];
    //	[_undoer registerUndoWithObject:VertexObj
    //			    action:@"setSnappedTos" 
    //			     state:[VertexObj snappedToInfo]];
    //	
    //	[VertexObj setSnappedToWithInfo:attrib];
    //	modified = YES;
    //    }
    
    
    if ( modified ) {
	[self modelChangeRequires:RSUpdateConstraints];
	//[_s sendChange:nil];
    }
}

- (void)removeElement:(id)obj;
{
    // Notify Logger
    //[[NSNotificationCenter defaultCenter] postNotificationName:@"RSLogUndo" object:nil];
    
    NSString *actionName = [_undoer.undoManager undoActionName];
    
    [_nonretained_delegate graphEditorDeselect:self];

    [_graph removeElement:obj];
    
    [_undoer setActionName:actionName];
    [self modelChangeRequires:RSUpdateConstraints];
}

- (void)addElement:(id)obj;
{
    // Notify Logger
    //[[NSNotificationCenter defaultCenter] postNotificationName:@"RSLogUndo" object:nil];
    
    NSString *actionName = [_undoer.undoManager undoActionName];
    [_graph addElement:obj];
    [_undoer setActionName:actionName];
    
    [_nonretained_delegate graphEditor:self addedElementDuringUndoOrRedo:obj];

    [self modelChangeRequires:RSUpdateConstraints];
}

@end
