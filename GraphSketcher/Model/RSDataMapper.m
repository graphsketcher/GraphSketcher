// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <GraphSketcherModel/RSDataMapper.h>

#import <GraphSketcherModel/RSNumber.h>
#import <GraphSketcherModel/RSVertex.h>
#import <GraphSketcherModel/RSTextLabel.h>
#import <GraphSketcherModel/RSConnectLine.h>
#import <GraphSketcherModel/RSLine.h>
#import <GraphSketcherModel/RSGroup.h>
#import <GraphSketcherModel/NSArray-RSExtensions.h>
#import <GraphSketcherModel/NSBezierPath-RSExtensions.h>

#import <OmniFoundation/OFPreference.h>

@implementation RSDataMapper

////////////////////////////////////////
#pragma mark init/dealloc
///////////

- (id)init;
{
    // not allowed
    OBASSERT_NOT_REACHED("RSDataMapper needs to be initialized with a view and graph");
    return nil;
}

- (id)initWithGraph:(RSGraph *)graph;
{
    if (!(self = [super init]))
        return nil;
    
    _graph = [graph retain];
    
    _vertexArrayCache = nil;
    _bezierSegmentsCache = nil;
    
    return self;
}

- (void)dealloc;
{
    [_graph release];
    [_bezierSegmentsCache release];
    
    [super dealloc];
}


- (RSGraph *)graph;
{
    return _graph;
}

@synthesize bounds = _bounds;
- (void)setBounds:(CGRect)bounds;
{
    _bounds = bounds;
    [self mappingParametersDidChange];
}

@synthesize vertexArrayCache = _vertexArrayCache;
@synthesize bezierSegmentsCache = _bezierSegmentsCache;

- (void)resetCurveCache;
{
    [self setVertexArrayCache:nil];
}

- (void)mappingParametersDidChange;
{
    _xAxisType = [[_graph xAxis] axisType];
    _yAxisType = [[_graph yAxis] axisType];
    
    if (_xAxisType == RSAxisTypeLogarithmic) {
        if ([_graph xMin] > 0) {  // Min and max both positive
            _logSpaceRange.x = log2([_graph xMax]/[_graph xMin]);
        }
        else {  // Min and max both negative
            _logSpaceRange.x = log2([_graph xMin]/[_graph xMax]);  // Here the min is "more negative" than the max and we want _logSpaceRange to be positive
        }
    }
    if (_yAxisType == RSAxisTypeLogarithmic) {
        if ([_graph yMin] > 0) {
            _logSpaceRange.y = log2([_graph yMax]/[_graph yMin]);
        }
        else {
            _logSpaceRange.y = log2([_graph yMin]/[_graph yMax]);
        }
    }
    
    //NSLog(@"_logSpaceRange: %@", NSStringFromPoint(_logSpaceRange));
}


///////////////
#pragma mark Methods to convert between the coordinate systems
// data coords (used to be called user coords) <--> view coords
//////////////

- (data_p)convertToDataCoords:(CGFloat)viewVal inDimension:(int)orientation;
{
    data_p val = (data_p)viewVal;  // Use full precision in calculations
    data_p convertedVal;
    RSBorder whitespace = [_graph whitespace];
    
    data_p width, height, viewMin, viewMax, viewRange;
    data_p axisMin, axisMax, logSpaceRange;
    RSAxisType axisType;
    
    // X //
    if (orientation == RS_ORIENTATION_HORIZONTAL) {
        width = CGRectGetWidth(_bounds);
        viewMin = whitespace.left;
        viewMax = width - whitespace.right;
        viewRange = width - whitespace.right - whitespace.left;
        
        axisMin = [_graph xMin];
        axisMax = [_graph xMax];
        
        axisType = _xAxisType;
        logSpaceRange = _logSpaceRange.x;
    }
    // Y //
    else {
        height = CGRectGetHeight(_bounds);
        viewMin = whitespace.bottom;
        viewMax = height - whitespace.top;
        viewRange = height - whitespace.top - whitespace.bottom;
        
        axisMin = [_graph yMin];
        axisMax = [_graph yMax];
        
        axisType = _yAxisType;
        logSpaceRange = _logSpaceRange.y;
    }
    
    if (axisType == RSAxisTypeLogarithmic) {
        
        // All-positive case
        if (axisMin > 0) {
            data_p ratio = (val - viewMin)/viewRange;
            data_p logSpaceRatio = ratio * logSpaceRange;
            convertedVal = axisMin * exp2(logSpaceRatio);
        }
        // All-negative case (min < 0, max < 0)
        else {
            data_p ratio = (viewMax - val)/viewRange;
            data_p logSpaceRatio = ratio * logSpaceRange;
            convertedVal = axisMax * exp2(logSpaceRatio);
        }
    }
    else {  // RSAxisTypeLinear
        convertedVal = axisMin + (val - viewMin) * (axisMax - axisMin) / viewRange;
    }

    
    OBASSERT(isfinite(convertedVal));
    return convertedVal;
}

- (RSDataPoint)convertToDataCoords:(CGPoint)p;
{
    RSDataPoint newCoords;
    newCoords.x = [self convertToDataCoords:p.x inDimension:RS_ORIENTATION_HORIZONTAL];
    newCoords.y = [self convertToDataCoords:p.y inDimension:RS_ORIENTATION_VERTICAL];
    return newCoords;
}


- (CGFloat)convertToViewCoords:(data_p)val inDimension:(int)orientation;
{
    data_p convertedVal;
    RSBorder whitespace = [_graph whitespace];
    
    data_p canvasExtent, viewMin, viewMax, viewRange;
    data_p axisMin, axisMax, logSpaceRange;
    RSAxisType axisType;
    
    // X //
    if (orientation == RS_ORIENTATION_HORIZONTAL) {
        
        canvasExtent = CGRectGetWidth(_bounds);
        viewMin = whitespace.left;
        viewMax = canvasExtent - whitespace.right;
        viewRange = canvasExtent - whitespace.right - whitespace.left;
        
        axisMin = [_graph xMin];
        axisMax = [_graph xMax];
        
        axisType = _xAxisType;
        logSpaceRange = _logSpaceRange.x;
    }
    // Y //
    else {
        canvasExtent = CGRectGetHeight(_bounds);
        viewMin = whitespace.bottom;
        viewMax = canvasExtent - whitespace.top;
        viewRange = canvasExtent - whitespace.top - whitespace.bottom;
        
        axisMin = [_graph yMin];
        axisMax = [_graph yMax];
        
        axisType = _yAxisType;
        logSpaceRange = _logSpaceRange.y;
    }
        
    if (axisType == RSAxisTypeLogarithmic) {
        OBASSERT(isfinite(logSpaceRange) && logSpaceRange);
        
        // All-positive case
        if (axisMin > 0) {
            OBASSERT(axisMax > 0);
            
            if (val <= 0) {
                convertedVal = 0;  // Put on left/bottom edge of canvas
            }
            else {
                data_p logSpaceRatio = log2(val/axisMin) / logSpaceRange;
                convertedVal = viewMin + logSpaceRatio*viewRange;
            }
        }
        
        // All-negative case (min < 0, max < 0)
        else {
            OBASSERT(axisMin < 0 && axisMax < 0);
            if (val >= 0) {
                convertedVal = canvasExtent;  // Put on top/right edge of canvas
            }
            else {
                data_p logSpaceRatio = log2(val/axisMax) / logSpaceRange;
                convertedVal = viewMax - logSpaceRatio*viewRange;
            }
        }
    }
    else {  // RSAxisTypeLinear
        convertedVal = viewMin + (val - axisMin) / (axisMax - axisMin) * viewRange;
    }

    
    // round to integer if one is very nearby
    CGFloat intValue = (CGFloat)nearbyint((CGFloat)convertedVal);
    if (nearlyEqualFloats((CGFloat)convertedVal, intValue))
        convertedVal = intValue;
    
    OBASSERT(isfinite(convertedVal));
    return (CGFloat)convertedVal;
}

- (CGPoint)convertToViewCoords:(RSDataPoint)p;
{
    CGPoint newCoords;
    newCoords.x = [self convertToViewCoords:p.x inDimension:RS_ORIENTATION_HORIZONTAL];
    newCoords.y = [self convertToViewCoords:p.y inDimension:RS_ORIENTATION_VERTICAL];
    return newCoords;
}




////// I've left these here in case they come in handy in the future:
- (CGPoint)convertToFractional:(CGPoint)p
// Converts the coordinates of a point in the RSGraphView 
// into decimals between 0 and 1.
{
    // -bounds needs to have been set up
    OBPRECONDITION(!CGRectEqualToRect(_bounds, CGRectZero));

    CGPoint fractionalCoords;
    CGRect bounds = _bounds;
    
    fractionalCoords.x = p.x / CGRectGetWidth(bounds);
    fractionalCoords.y = p.y / CGRectGetHeight(bounds);
    
    return fractionalCoords;
}
- (CGPoint)convertFromFractional:(CGPoint)p
// Converts fractional coordinates into a point in the RSGraphView.
{
    // -bounds needs to have been set up
    OBPRECONDITION(!CGRectEqualToRect(_bounds, CGRectZero));

    CGPoint viewCoords;
    CGRect bounds = _bounds;
    
    viewCoords.x = p.x * CGRectGetWidth(bounds);
    viewCoords.y = p.y * CGRectGetHeight(bounds);
    
    return viewCoords;
}



///////////////
#pragma mark Maintaining the amount of whitespace around the axes
//////////////

/*
- (void)updateLWidth;
{
    // calculate width of elements to the left of the graph area
    
    _Lwidth = 0;
    
    // consider y-axis tick labels:
    _Lwidth += _tickLabelMaxSize.width;
    
    // space between axis and tick labels:
     _Lwidth += [[_graph yAxis] width];
     _Lwidth += [[_graph yAxis] labelDistance];  // distance to tick labels
    
    // space between axis labels and title:
    _Lwidth += [_graph axisTitleSpace].width;
    
    // space for y-axis title plus buffer to edge of window:
    if( [[[_graph yAxis] title] isVisible] ) {
	
	//_Lwidth += 5.0;  // buffer around tick labels
	_Lwidth += ([[[_graph yAxis] title] size].height);  // size of title
	//_Lwidth += [_graph axisTitleSpace].width;  // buffer to edge of window
	_Lwidth += [_graph edgePadding].left;  // small buffer to edge of window
    }
    
    // just a little extra space.
    _Lwidth += CGRectGetWidth([_view bounds])*0.03;
    
    // possibly increase, depending on window size
    CGFloat other = CGRectGetWidth([_view bounds]) * [_graph xMinWhiteSpace];
    if( other > _Lwidth)
	_Lwidth = other;
}

- (void)updateBWidth;
{
    // calculate height of elements below the graph area
    _Bwidth = 0;
    
    // consider x-axis tick labels:
    _Bwidth += _tickLabelMaxSize.height;
    
    // space between axis labels and title:
    _Bwidth += [_graph axisTitleSpace].height * 1.0;//[[[_graph xAxis] title] size].height * 0.5;
    
    // space for x-axis title and buffer to edge of window:
    if( [[[_graph xAxis] title] isVisible] ) {
	_Bwidth += [[_graph xAxis] labelDistance];  // buffer around tick labels
	_Bwidth += ([[[_graph xAxis] title] size].height);  // size of title
	_Bwidth += [_graph axisTitleSpace].height;  // buffer to edge of window
    }
    
    // just a little extra space.
    _Bwidth += CGRectGetHeight([_view bounds])*0.03;
    
    // possibly increase, depending on window size
    CGFloat other = CGRectGetHeight([_view bounds]) * [_graph yMinWhiteSpace];
    if( other > _Bwidth)
	_Bwidth = other;
}

*/

///////////////
#pragma mark Positioning convenience methods
//////////////

- (CGPoint)viewCenterOfElement:(RSGraphElement *)GE;
{
    CGPoint position = [self convertToViewCoords:[GE position]];
    
    if ([GE isKindOfClass:[RSTextLabel class]]) {
        CGFloat rotation = (float)[(RSTextLabel *)GE rotation];
        if (!rotation) {
            CGSize size = [GE size];
            position.x += size.width/2;
            position.y += size.height/2;
        }
        else {
            CGSize size = [GE size];
            rotation = rotation*(float)M_PI/180.0f;
            CGPoint v1 = CGPointMake(size.width*cos(rotation), size.width*sin(rotation));
            v1.x -= size.height*sin(rotation);
            v1.y += size.height*cos(rotation);
            position.x += v1.x/2.0f;
            position.y += v1.y/2.0f;
        }
    }
    return position;
}

// this is the point, in data coords, where the axes meet.
- (RSDataPoint)originPoint;
{
    return RSDataPointMake([[_graph xAxis] visualOrigin], [[_graph yAxis] visualOrigin]);
}

- (CGPoint)viewOriginPoint;
{
    RSDataPoint o = [self originPoint];
    CGPoint viewO = [self convertToViewCoords:o];
    
    // Special case to reduce jiggliness which can occasionally happen when scales are being resized.
    if (o.x == [_graph xMin]) {
        viewO.x = [_graph whitespace].left;
    }
    if (o.y == [_graph yMin]) {
        viewO.y = [_graph whitespace].bottom;
    }
    
    return viewO;
}

- (CGPoint)viewMins;
// axis mins in view coords
{
    //return [self convertToViewCoords:CGPointMake([_graph xMin], [_graph yMin])];
    
    RSBorder whitespace = [_graph whitespace];
    CGFloat xMinView = whitespace.left;
    CGFloat yMinView = whitespace.bottom;
    return CGPointMake(xMinView, yMinView);
}
- (CGPoint)viewMaxes;
// axis maxes in view coords
{
    //return [self convertToViewCoords:CGPointMake([_graph xMax], [_graph yMax])];
    
    RSBorder whitespace = [_graph whitespace];
    CGFloat xMaxView = CGRectGetWidth(_bounds) - whitespace.right;
    CGFloat yMaxView = CGRectGetHeight(_bounds) - whitespace.top;
    return CGPointMake(xMaxView, yMaxView);
}
- (CGRect)viewAxisRect;
{
    RSBorder whitespace = [_graph whitespace];
    
    CGRect r;
    r.origin.x = whitespace.left;
    r.origin.y = whitespace.bottom;
    r.size.width = CGRectGetWidth(_bounds) - whitespace.left - whitespace.right;
    r.size.height = CGRectGetHeight(_bounds) - whitespace.top - whitespace.bottom;
    
    return r;
}

- (void)shiftElement:(RSGraphElement *)GE byDelta:(CGPoint)delta;
// Safe for logarithmic axes; delta is in view coords.
{
    for (RSGraphElement *obj in [GE elements]) {
        RSDataPoint pos = [obj position];
        CGPoint viewPos = [self convertToViewCoords:pos];
        CGPoint shiftedViewPos = CGPointMake(viewPos.x + delta.x, viewPos.y + delta.y);
        RSDataPoint shiftedPos = [self convertToDataCoords:shiftedViewPos];
        [obj setPosition:shiftedPos];
    }
}

- (void)moveElement:(RSGraphElement *)GE toPosition:(RSDataPoint)newPos;
{
    if (!GE)
        return;
    
    RSDataPoint oldPos = [GE position];
    
    // Calculate the position change in view coords
    CGPoint viewOld = [self convertToViewCoords:oldPos];
    CGPoint viewNew = [self convertToViewCoords:newPos];
    CGPoint delta = CGPointMake(viewNew.x - viewOld.x, viewNew.y - viewOld.y);
    
    // Shift all elements by that amount in view coords
    [self shiftElement:GE byDelta:delta];
}


///////////////
#pragma mark Grid position convenience methods
//////////////

- (data_p)closestGridLineTo:(CGFloat)viewP onAxis:(RSAxis *)A;
{
    NSMutableArray *tickArray = [[[A allTicks] mutableCopy] autorelease];
    
    if (![_graph noAxisComponentsAreDisplayed]) {
        [tickArray insertObject:[NSNumber numberWithDouble:[A min]] atIndex:0];
        [tickArray addObject:[NSNumber numberWithDouble:[A max]]];
    }
    
    // Do a binary search for the closest one
    NSUInteger min = 0;
    NSUInteger max = [tickArray count] - 1;
    NSUInteger current = max/2;
    
    while ( max - min > 1 ) {
        //NSLog(@"min: %d, max: %d, checking %d", min, max, current);
        
        data_p tick = [[tickArray objectAtIndex:current] doubleValue];
        CGFloat viewTick = [self convertToViewCoords:tick inDimension:[A orientation]];
        
        if (viewP < viewTick) {
            max = current;
            current = current - (max - min)/2;
        }
        else {
            min = current;
            current = current + (max - min)/2;
        }
    }
    //NSLog(@"min: %d, max: %d, current %d", min, max, current);
    OBASSERT(max - min == 1);
    
    CGFloat viewUpper = [self convertToViewCoords:[[tickArray objectAtIndex:max] doubleValue] inDimension:[A orientation]];
    CGFloat viewLower = [self convertToViewCoords:[[tickArray objectAtIndex:min] doubleValue] inDimension:[A orientation]];
    
    NSUInteger winningTick;
    if (viewUpper - viewP < viewP - viewLower)
        winningTick = max;
    else
        winningTick = min;
    
    return [[tickArray objectAtIndex:winningTick] doubleValue];
}

- (BOOL)isGridLine:(data_p)dataP onAxis:(RSAxis *)A;
{
    CGFloat viewP = [self convertToViewCoords:dataP inDimension:[A orientation]];
    data_p closest = [self closestGridLineTo:viewP onAxis:A];
    
    return (closest == dataP);
}

- (BOOL)isGridLinePoint:(RSDataPoint)p;
{
    return ([self isGridLine:p.x onAxis:[_graph xAxis]] || [self isGridLine:p.y onAxis:[_graph yAxis]]);
}

- (data_p)roundToGridLine:(CGFloat)viewP onAxis:(RSAxis *)A;
// This basically converts (3.9989, 4) -> (4,4)
{
    data_p gridLine = [self closestGridLineTo:viewP onAxis:A];
    CGFloat viewGridLine = [self convertToViewCoords:gridLine inDimension:[A orientation]];
    
    // If within rounding error of a grid line, use the grid line
    if ( fabs(1 - viewGridLine/viewP) < 0.001 ) {
        return gridLine;
    }
    else {
        return [self convertToDataCoords:viewP inDimension:[A orientation]];
    }
}

- (RSDataPoint)roundToGrid:(CGPoint)viewP;
{
    // Don't round to grid if preference is disabled:
    if( ![[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:@"SnapToGrid"] ) {
        return [self convertToDataCoords:viewP];
    }
    // Don't round to grid if the relevant visual components are turned off:
    if( [_graph noGridComponentsAreDisplayed] ) {
        return [self convertToDataCoords:viewP];
    }

    // Otherwise, round to grid:
    RSDataPoint roundedPoint;
    roundedPoint.x = [self roundToGridLine:viewP.x onAxis:[_graph xAxis]];
    roundedPoint.y = [self roundToGridLine:viewP.y onAxis:[_graph yAxis]];
    return roundedPoint;
}


- (CGPoint)_individualDeltaToSquareGrid;
{
    RSDataPoint originPoint = [self originPoint];
    CGPoint viewOriginPoint = [self viewOriginPoint];
    RSDataPoint tickOffsetPoint = RSDataPointMake(originPoint.x + [[_graph xAxis] spacing], originPoint.y + [[_graph yAxis] spacing]);
    CGPoint viewTickOffsetPoint = [self convertToViewCoords:tickOffsetPoint];
    CGPoint delta = CGPointMake(viewTickOffsetPoint.x - viewOriginPoint.x, viewTickOffsetPoint.y - viewOriginPoint.y);
    
    CGFloat change = fabs(delta.x - delta.y)/2;
    
    if (delta.x > delta.y) {
        return CGPointMake(-change, change);
    }
    else {
        return CGPointMake(change, -change);
    }
}

- (CGPoint)deltaToSquareGrid;
{
    CGPoint delta = [self _individualDeltaToSquareGrid];
    
    RSAxis *axis;
    axis = [_graph xAxis];
    data_p xTicks = ([axis max] - [axis min])/[axis spacing];
    axis = [_graph yAxis];
    data_p yTicks = ([axis max] - [axis min])/[axis spacing];
    
    return CGPointMake(delta.x*(CGFloat)xTicks, delta.y*(CGFloat)yTicks);
}



/////////////////
#pragma mark -
#pragma mark Auto-scaling
/////////////////

- (CGRect)viewBoundsOfGraphElement:(RSGraphElement *)GE;
{
    if ([GE isKindOfClass:[RSTextLabel class]]) {
        return [self rectFromLabel:(RSTextLabel *)GE offset:0];
    }
    else {
        CGPoint p = [self convertToViewCoords:[GE position]];
        return CGRectMake(p.x, p.y, 0, 0);
    }
}

- (CGRect)viewBoundsOfGraphElements:(NSArray *)array;
{
    if ( !array || [array count] == 0 ) {
	OBASSERT_NOT_REACHED("Non-empty array required");
	return CGRectZero;
    }
    
    CGRect unionRect = [self viewBoundsOfGraphElement:[array objectAtIndex:0]];
    for (RSGraphElement *GE in array) {
        unionRect = CGRectUnion(unionRect, [self viewBoundsOfGraphElement:GE]);
    }
    
    return unionRect;
}

- (BOOL)graphShowsElement:(RSGraphElement *)GE inDirection:(int)dir;
// Returns YES if GE appears within the canvas (could be outside the axis rect), in the dimension specified.
{
    CGRect viewBounds = [self viewBoundsOfGraphElement:GE];
    
    if (dir == RS_ORIENTATION_HORIZONTAL) {
        viewBounds.origin.y = _bounds.origin.y;  // modify rect such that we ignore verticals
        viewBounds.size.height = 0;
    } else {
        viewBounds.origin.x = _bounds.origin.x;  // in other dimension, ditto with horizontals
        viewBounds.size.width = 0;
    }
    
    return CGRectContainsRect(_bounds, viewBounds);
}

- (void)_scaleAxis:(RSAxis *)axis toMakeVisible:(NSArray *)elements;
{
    //NSLog(@"Scaling %@ to make visible", [axis prettyName]);
    if ([elements count] == 0)
	return;
    
    int orientation = [axis orientation];
    
    if ([elements count] == 1) {
	RSGraphElement *element = [elements objectAtIndex:0];
	OBASSERT([element isKindOfClass:[RSGraphElement class]]);
	
	if (![self graphShowsElement:element inDirection:orientation]) {
	    [axis expandRangeToIncludePoint:[element position]];
	}
	return;
    }
    
    // If got this far, array contains at least two elements that need visibility ensured.
    CGRect viewBounds = [self viewBoundsOfGraphElements:elements];
    
    if ( CGRectContainsRect(_bounds, viewBounds) )  // if everything is visible, we're done
	return;
    
    // Otherwise, expand to include all elements
    CGFloat viewMin = dimensionOfPointInOrientation(viewBounds.origin, orientation);
    CGFloat viewMax = dimensionOfPointInOrientation(CGRectGetMaxes(viewBounds), orientation);
    
    data_p dataMin = [self convertToDataCoords:viewMin inDimension:orientation];
    data_p dataMax = [self convertToDataCoords:viewMax inDimension:orientation];
    //NSLog(@"dataMin: %g, dataMax: %g", dataMin, dataMax);
    
    [axis expandRangeToIncludeValue:dataMin];
    [axis expandRangeToIncludeValue:dataMax];
}

- (void)scaleAxesToMakeVisible:(NSArray *)elements;
{
    if ([elements count] == 0)
        return;
    
    [self _scaleAxis:[_graph xAxis] toMakeVisible:elements];
    [self _scaleAxis:[_graph yAxis] toMakeVisible:elements];
}


- (void)_scaleAxis:(RSAxis *)axis toFitData:(NSArray *)vertices;
{
    //NSLog(@"Scaling %@ to fit", [axis prettyName]);
    OBASSERT([vertices numberOfObjectsWithClass:[RSVertex class]] == [vertices count]);  // All objects in the array should be vertices
    
    NSUInteger vCount = [vertices count];
    if (vCount == 0)
	return;
    
    if (vCount == 1) { // Make sure the range includes the one vertex
        [axis expandRangeToIncludePoint:[(RSGraphElement *)[vertices objectAtIndex:0] position]];
	return;
    }
    
    // At least two vertices
    RSDataPoint dataMins = [_graph dataMinsOfGraphElements:vertices];
    RSDataPoint dataMaxes = [_graph dataMaxesOfGraphElements:vertices];
    data_p min = dimensionOfDataPointInOrientation(dataMins, [axis orientation]);
    data_p max = dimensionOfDataPointInOrientation(dataMaxes, [axis orientation]);
    
    [axis setRangeAsClosestTickMarksToMin:min andMax:max];
}

- (void)scaleAxesToFitData;
{
    NSArray *vertices = [_graph Vertices];
    if ([vertices count] == 0)
	return;
    
    [self _scaleAxis:[_graph xAxis] toFitData:vertices];
    [self _scaleAxis:[_graph yAxis] toFitData:vertices];
}

- (void)_scaleAxis:(RSAxis *)axis forPastedObjects:(NSArray *)elements importingData:(BOOL)importingData;
{
    //NSLog(@"Starting axis range: %g to %g", [axis min], [axis max]);
    
    if ([elements count] == 0)
        return;
    
    // If we're importing text data and the user hasn't adjusted the axis range, then scale the axis to fit.
    if (importingData && ![axis userModifiedRange]) {
        [self _scaleAxis:axis toFitData:[_graph Vertices]];
        return;
    }
    
    // Otherwise, scale the axis to make sure the pasted or imported objects are visible.
    [self _scaleAxis:axis toMakeVisible:elements];
}

- (void)scaleAxesForNewObjects:(NSArray *)elements importingData:(BOOL)importingData;
{
    [self _scaleAxis:[_graph xAxis] forPastedObjects:elements importingData:importingData];
    [self _scaleAxis:[_graph yAxis] forPastedObjects:elements importingData:importingData];
}

- (void)scaleAxesToShrinkIfNecessary;
{
    NSArray *elements = [_graph Vertices];

    NSUInteger vCount = [elements count];
    if (vCount <= 1)
        return;

    RSDataPoint dataMins = [_graph dataMinsOfGraphElements:elements];
    RSDataPoint dataMaxes = [_graph dataMaxesOfGraphElements:elements];
    RSDataPoint dataRanges = RSDataPointMake(dataMaxes.x - dataMins.x, dataMaxes.y - dataMins.y);
    RSDataPoint axisRanges = RSDataPointMake([[_graph xAxis] max] - [[_graph xAxis] min], [[_graph yAxis] max] - [[_graph yAxis] min]);

    if ( dataRanges.x > 0 && dataRanges.x < axisRanges.x * RS_SCALE_TO_FIT_EXPAND_CUTOFF ) {
        [[_graph xAxis] setRangeAsClosestTickMarksToMin:dataMins.x andMax:dataMaxes.x];
    }
    if ( dataRanges.y > 0 && dataRanges.y < axisRanges.y * RS_SCALE_TO_FIT_EXPAND_CUTOFF ) {
        [[_graph yAxis] setRangeAsClosestTickMarksToMin:dataMins.y andMax:dataMaxes.y];
    }
}



///////////////
#pragma mark -
#pragma mark Helper methods for lines and curves
//////////////

- (void)convertVertexArray:(NSArray *)VArray toPoints:(CGPoint[])p;
{
    //NSInteger n = [VArray count] - 1;  // number of points p, minus 1
    //CGPoint p[n+1];
    
    // populate array of points p
    RSVertex *V;
    NSInteger i = 0;
    for (V in VArray) {
	p[i++] = [self convertToViewCoords:[V position]];
    }
}

- (CGFloat)viewDistanceBetween:(RSDataPoint)p1 and:(RSDataPoint)p2;
{
    CGPoint vp1 = [self convertToViewCoords:p1];
    CGPoint vp2 = [self convertToViewCoords:p2];
    
    return hypot(vp1.x - vp2.x, vp1.y - vp2.y);
}

- (CGFloat)viewLengthOfLine:(RSLine *)L;
{
    // straight line
    if( ![L isCurved] ) {
        return [self viewDistanceBetween:[L startPoint] and:[L endPoint]];
    }
    // curved line
    else {
	// Approximate with ten straight lines.  5 steps with two approximations each.
        NSInteger steps = 5;
        CGFloat length = 0;
        for (NSInteger i = 0; i < steps; i++) {
            CGFloat start = i/steps;
            CGFloat end = (i + 1)/steps;
            length += [self viewLengthOfLineSegment:L fromTime:start toTime:end];
        }
	
        OBASSERT(isfinite(length));
	return length;
    }
}

- (CGFloat)viewLengthOfLineSegment:(RSLine *)L fromTime:(CGFloat)t1 toTime:(CGFloat)t2;
{
    // approximate with two straight lines
    CGFloat length = 0;
    CGPoint p1, p2;
    
    // first line:
    p1 = [self locationOnCurve:L atTime:t1];
    CGFloat tmid = (t1 + t2)/2;
    p2 = [self locationOnCurve:L atTime:tmid];
    length += hypot(p1.x - p2.x, p1.y - p2.y);
    
    // second line:
    p1 = p2;
    p2 = [self locationOnCurve:L atTime:t2];
    length += hypot(p1.x - p2.x, p1.y - p2.y);
    
    return length;
}

- (CGFloat)timeOnLine:(RSLine *)L viewDistance:(CGFloat)spacing fromTime:(CGFloat)tprev direction:(NSUInteger)direction;
{
    if ([L hasNoLength])
	return 0;
    
    if ([self viewLengthOfLine:L] == 0)  // just to be extra safe.
        return 0;
    
    CGFloat t = tprev;
    CGFloat endT = 1;
    
    CGFloat jump = 0.1f;
    if (direction == RS_BACKWARD) {
	jump *= -1;
        endT = 0;
    }
    
    if (t == endT || [self viewLengthOfLineSegment:L fromTime:tprev toTime:endT] < spacing) {
        // The t-value would be off the end of the line (<0 or >1).
        return endT + jump;
    }
    
    while (t + jump < 0) {
        jump *= 0.5f;
    }
    
    NSUInteger maxIters = 30;
    NSUInteger iters;
    while ( fabs(jump) >= 0.001 ) {
        iters = 0;
	do {
            iters++;
            t += jump;
            if (t < 0)  t = 0;
            if (t > 1)  t = 1;
        }  
	while( iters < maxIters && [self viewLengthOfLineSegment:L fromTime:tprev toTime:t] < spacing );
	
	jump *= 0.5f;
	
        iters = 0;
	do {
            iters++;
            t -= jump;
            if (t < 0)  t = 0;
            if (t > 1)  t = 1;
        }
	while( iters < maxIters && [self viewLengthOfLineSegment:L fromTime:tprev toTime:t] > spacing );
	
	jump *= 0.5f;
    }
    
    return t;
}



// returns a struct containing p0, p1, p2, p3 of the bezier piece that covers time t
- (RSBezierSpec)bezierSpecOfConnectLine:(RSConnectLine *)L atTime:(CGFloat)t;
{
    // compute the curve segments
    NSArray *VArray = [[(RSConnectLine *)L vertices] elements];
    NSInteger n = [VArray count] - 1;
    CGPoint segs[n + 1][3];
    [self bezierSegmentsFromVertexArray:VArray putInto:segs];
    
    // get the control points
    NSInteger piece = (NSInteger)floor(t*n);
    RSBezierSpec spec;
    spec.p0 = segs[piece][0];
    spec.p1 = segs[piece][1];
    spec.p2 = segs[piece][2];
    spec.p3 = segs[piece+1][0];
    
    // calculate the "piecewise" t (the corresponding t on the bezier piece)
    spec.t = t*n - piece;
    
    return spec;
}

// segs[] must have the same number of elements as VArray
- (void)bezierSegmentsFromVertexArray:(NSArray *)VArray putInto:(CGPoint[][3])segs;
{
    RSVertex *V;
    NSInteger n = [VArray count] - 1;  // number of points p, minus 1
    
    //if( n < 2 )  return;  // the following doesn't make sense for n < 2 (i.e. count < 3)
    
    // populate array of points p
    CGPoint p[n+1];
    NSInteger i = 0;
    for (V in VArray) {
	p[i++] = [self convertToViewCoords:[V position]];
    }
    
    [NSBezierPath interpolatingSplineBezierSegmentsFromPoints:p length:n putInto:segs];
}

- (NSArray *)bezierSegmentsFromVertexArray:(NSArray *)VArray;
{
    if (_vertexArrayCache == VArray) {
	return _bezierSegmentsCache;
    }
    
    NSInteger n = [VArray count] - 1;
    CGPoint segs[n + 1][3];
    [self bezierSegmentsFromVertexArray:VArray putInto:segs];
    
    NSMutableArray *segments = [NSMutableArray arrayWithCapacity:(n + 1)];
    for (NSInteger i=0; i<=n; i++) {
	RSBezierSegment seg;
	seg.p = segs[i][0];
	seg.q = segs[i][1];
	seg.r = segs[i][2];
	[segments addObject:[NSValue valueWithBytes:&seg objCType:@encode(RSBezierSegment)]];
    }
    
    // save cache...
    [self setVertexArrayCache:VArray];
    [self setBezierSegmentsCache:segments];
    
    return segments;
}


- (CGFloat)timeOfVertex:(RSVertex *)V onLine:(RSLine *)L;
{
    NSUInteger count = [L vertexCount];
    if (count < 2) {
	OBASSERT_NOT_REACHED("Line does not have enough vertices");
	return 0;
    }
    NSUInteger index = [[[L vertices] elements] indexOfObjectIdenticalTo:V];
    if (index == NSNotFound) {
	OBASSERT_NOT_REACHED("Vertex not found in its line");
	return 0;
    }
    return ((CGFloat)index)/((CGFloat)(count - 1));
}

- (CGPoint)locationOnCurve:(RSLine *)L atTime:(CGFloat)t {
    // in VIEW COORDS
    //
    // The parametric formula for a Bezier curve based on four points is (graphics p. 611):
    // P(t) = P_0(1 - t)^3 + P_1*3(1 - t)^2*t + P_2*3(1 - t)*t^2 + P_3*t^3
    // 
    // where P_0 and P_3 are endpoints and P_1 and P_2 are control points
    OBPRECONDITION(L);
    OBPRECONDITION(isfinite(t) && t >= 0);
    
    OBASSERT(![L isTooSmall]);
    if ([L hasNoLength]) {
	return [self convertToViewCoords:[L startPoint]];
    }
    
    CGPoint s;
    
    if (t == 0)
	return [self convertToViewCoords:[L startPoint]];
    if (t == 1)
	return [self convertToViewCoords:[L endPoint]];
    
    if ([L vertexCount] == 2) {
	CGPoint p0 = [self convertToViewCoords:[L startPoint]];
	CGPoint p1 = [self convertToViewCoords:[L endPoint]];
	
	s = evaluateStraightLineAtT(p0, p1, t);
	return s;
    }
    
    // if got this far...
    OBASSERT([L isKindOfClass:[RSConnectLine class]]);
    
    // get the segments
    NSArray *VArray = [[L vertices] elements];
    NSInteger n = [VArray count] - 1;
    
    // a connectLine with straight connections:
    if ( [L connectMethod] == RSConnectStraight ) {
	
	// get the segment of interest:
	NSInteger piece = floor(t*n);
	if (piece >= n)
	    piece = n - 1;
	if (piece < 0)
	    piece = 0;
	CGPoint p0 = [self convertToViewCoords:[(RSVertex *)[VArray objectAtIndex:piece] position]];
	CGPoint p1 = [self convertToViewCoords:[(RSVertex *)[VArray objectAtIndex:piece + 1] position]];
	
	// calculate location on line:
	CGFloat pieceT = t*n - piece;
	s = evaluateStraightLineAtT(p0, p1, pieceT);
    }
    // a connectLine with curved connections:
    else if ( [L connectMethod] == RSConnectCurved ) {
	// compute the curve segments
	NSArray *segments = [self bezierSegmentsFromVertexArray:VArray];
//	CGPoint segs[n + 1][3];
//	[self bezierSegmentsFromVertexArray:VArray putInto:segs];
	
	// get the control points
	NSInteger piece = floor(t*n);
	if (piece >= n)
	    piece = n - 1;
	if (piece < 0)
	    piece = 0;
        OBASSERT(piece < n && piece >= 0);
        
	RSBezierSegment thisSeg;
	[[segments objectAtIndex:piece] getValue:&thisSeg];
	CGPoint p0 = thisSeg.p;
	CGPoint p1 = thisSeg.q;
	CGPoint p2 = thisSeg.r;
        RSBezierSegment nextSeg;
	[[segments objectAtIndex:piece + 1] getValue:&nextSeg];
	CGPoint p3 = nextSeg.p;
//	CGPoint p0 = segs[piece][0];
//	CGPoint p1 = segs[piece][1];
//	CGPoint p2 = segs[piece][2];
//	CGPoint p3 = segs[piece+1][0];
	
	// calculate:
	CGFloat pieceT = t*n - piece;
	s = evaluateBezierPathAtT(p0, p1, p2, p3, pieceT);
    }
    else {  // no connections?
	OBASSERT_NOT_REACHED("connection type not recognized");
	s = CGPointMake(0, 0);
    }
    
    OBASSERT(pointIsFinite(s));
    return s;
}


- (RSTwoPoints)lineTangentToLine:(RSLine *)L atTime:(CGFloat)t useDelta:(CGFloat)delta;
{
    RSTwoPoints ends;
    
    OBASSERT(isfinite(t));
    
    if (!isfinite(delta)) {
        OBASSERT_NOT_REACHED("!isfinite(delta)");
        NSLog(@"line-tangent delta is not finite!");
        delta = 0.01f;  // default
    }
    
    if ( [L vertexCount] == 2 ) {  // L is straight
	ends.p1 = [self convertToViewCoords:[L startPoint]];
	ends.p2 = [self convertToViewCoords:[L endPoint]];
    }
    else { // L is curved
	CGFloat time = t;
	if ( time <= (0 + delta) )  time = delta;
	if ( time >= (1 - delta) )  time = 1 - delta;
	ends.p1 = [self locationOnCurve:L atTime:(time - delta)];
	ends.p2 = [self locationOnCurve:L atTime:(time + delta)];
    }
    
    OBASSERT(pointIsFinite(ends.p1) && pointIsFinite(ends.p2));
    return ends;
}

- (CGPoint)directionOfLine:(RSLine *)L atTime:(CGFloat)t;
// Returns a vector pointing in the direction of line L.
{
    RSTwoPoints ends = [self lineTangentToLine:L atTime:t useDelta:0.001f];
    return CGPointMake(ends.p2.x - ends.p1.x, ends.p2.y - ends.p1.y);
}

- (CGFloat)degreesFromHorizontalOfLine:(RSLine *)L atTime:(CGFloat)t;
{
    return [self degreesFromHorizontalOfLine:L atTime:t useDelta:0.001f];
}

- (CGFloat)degreesFromHorizontalOfLine:(RSLine *)L atTime:(CGFloat)t useDelta:(CGFloat)delta;
{
    RSTwoPoints ends = [self lineTangentToLine:L atTime:t useDelta:delta];
    return degreesFromHorizontalOfVector(ends.p1, ends.p2);
}

- (CGFloat)curvatureOfLine:(RSLine *)L atTime:(CGFloat)t useDelta:(CGFloat)delta;
// Derived from cross product math; see Hill's Computer Graphics, p. 160.
// Returns the z-component of the cross product of two vectors pointing along the line in opposite directions, using an offset of 'delta' of the given t-value.  According to the right-hand rule, if the z-component is positive, then the line is curving to the left.  If z is negative, it's curving to the right.
{
    if (t < delta) {
        t = delta;
    }
    if (t > 1 - delta) {
        t = 1 - delta;
    }
    OBASSERT(t >= delta && t <= 1 - delta);
    
    CGPoint pa = [self locationOnCurve:L atTime:t - delta];
    CGPoint p = [self locationOnCurve:L atTime:t];
    CGPoint pb = [self locationOnCurve:L atTime:t + delta];
    
    CGPoint va = CGPointMake(pa.x - p.x, pa.y - p.y);  // vector to a
    CGPoint vb = CGPointMake(pb.x - p.x, pb.y - p.y);  // vector to b
    
    // I think there is a special name for this calculation, but I can't remember.  It is: (a_x*b_y - a_y*b_x)
    CGFloat z = va.x*vb.y - va.y*vb.x;
    return z;
}




- (void)curvePath:(NSBezierPath *)P alongConnectLine:(RSConnectLine *)L start:(CGFloat)gt1 finish:(CGFloat)gt2;
// "gt1" means "global time", i.e. 0..1 from start to end of the whole curve
{
    OBPRECONDITION(gt1 >= 0 && gt1 <= 1);
    OBPRECONDITION(gt2 >= 0 && gt2 <= 1);
    OBPRECONDITION([L isKindOfClass:[RSConnectLine class]]);
    OBPRECONDITION(P);
    
    // compute the curve segments
    NSArray *VArray = [[(RSConnectLine *)L vertices] elements];
    NSInteger n = [VArray count] - 1;

    // setup vars
    CGPoint p0, p1, p2, p3;
    CGFloat t1, t2;  // "local" (piecewise) times, i.e. 0..1 from start to end of bezier segment
    NSInteger piece;

    //
    // if straight segments
    //
    if( [L connectMethod] == RSConnectStraight ) {
        
        if( gt1 < gt2 ) {
            // init
            piece = floor(gt1*n);
            if (piece >= n)
                piece = n - 1;
            if (piece < 0)
                piece = 0;
            
            // iterate through the piecewise segments
            while( piece < gt2*n - 0.0001 ) {
                OBASSERT(piece < n && piece >= 0);
                
                // determine local t2 (either corresponds to end of segment or to global t2)
                if( gt2*n - piece > 1 )  t2 = 1;
                else  t2 = gt2*n - piece;
                
                // get the corresponding segment
                p0 = [self convertToViewCoords:[(RSVertex *)[VArray objectAtIndex:piece] position]];
                p1 = [self convertToViewCoords:[(RSVertex *)[VArray objectAtIndex:piece + 1] position]];
                
                // extend the path
                [P lineToPoint:evaluateStraightLineAtT(p0, p1, t2)];
                
                // go to the next piece
                piece++;
            }
        }
        else {  // gt2 <= gt1
            // init
            piece = (CGFloat)floor(gt1*n - 0.0001);  // if gt1 falls right on a vertex, we still want to get the previous piece
            if (piece >= n)
                piece = n - 1;
            if (piece < 0)
                piece = 0;
            
            // iterate (backwards) through the piecewise segments
            while( piece >= floor(gt2*n) ) {
                OBASSERT(piece < n && piece >= 0);
                
                // determine local t1 (either corresponds to end of segment or to global t1)
                if( gt2*n - piece < 0 )  t1 = 0;
                else  t1 = gt2*n - piece;
                
                // get the corresponding segment
                p0 = [self convertToViewCoords:[(RSVertex *)[VArray objectAtIndex:piece] position]];
                p1 = [self convertToViewCoords:[(RSVertex *)[VArray objectAtIndex:piece + 1] position]];
                
                // extend the path
                [P lineToPoint:evaluateStraightLineAtT(p0, p1, t1)];
                
                // go to the next piece
                piece-=1;
            }
        }
        
        // the end
    }

    //
    // if curved segments
    //
    else if( [L connectMethod] == RSConnectCurved ) {
        // calculate the bezier segments
        CGPoint segs[n + 1][3];
        [self bezierSegmentsFromVertexArray:VArray putInto:segs];
        
        if( gt1 < gt2 ) {
            // init
            piece = floor(gt1*n);
            t1 = gt1*n - piece;
            // iterate through the piecewise segments
            while( piece < gt2*n - 0.0001 ) {
                OBASSERT(piece < n && piece >= 0);
                
                // determine local t2 (either corresponds to end of segment or to global t2)
                if( gt2*n - piece > 1 )  t2 = 1;
                else  t2 = gt2*n - piece;
                
                // get the current bezier path
                p0 = segs[piece][0];
                p1 = segs[piece][1];
                p2 = segs[piece][2];
                p3 = segs[piece+1][0];
                
                // apply Jaakko's formula
                //NSLog(@"t1=%f, t2=%f", t1, t2);
                [P curveAlongBezierP0:p0 p1:p1 p2:p2 p3:p3 start:t1 finish:t2];
                
                // go to the next piece
                piece++;
                t1 = 0;
            }
        }
        else {  // gt2 <= gt1
            // init
            piece = (CGFloat)floor(gt1*n - 0.0001);  // if gt1 falls right on a vertex, we still want to get the previous piece
            t2 = gt1*n - piece;
            // iterate (backwards) through the piecewise segments
            while( piece >= floor(gt2*n) ) {
                OBASSERT(piece < n && piece >= 0);
                
                // determine local t1 (either corresponds to end of segment or to global t1)
                if( gt2*n - piece < 0 )  t1 = 0;
                else  t1 = gt2*n - piece;
                
                // get the current bezier path
                p0 = segs[piece][0];
                p1 = segs[piece][1];
                p2 = segs[piece][2];
                p3 = segs[piece+1][0];
                
                // apply Jaakko's formula
                //NSLog(@"t1=%f, t2=%f", t1, t2);
                [P curveAlongBezierP0:p0 p1:p1 p2:p2 p3:p3 start:t2 finish:t1];
                
                // go to the next piece
                piece-=1;
                t2 = 1;
            }
        }
        
        // that's all
    }
}



static BOOL lineIntersectsXValue(CGPoint p1, CGPoint p2, CGFloat x) {
    // Reject all vertical lines
    if (nearlyEqualFloats(p1.x, p2.x)) {
        return NO;
    }
    
    // Accept lines if either endpoint is nearly equal to the x-value
    if (nearlyEqualFloats(p1.x, x) || nearlyEqualFloats(p2.x, x)) {
        return YES;
    }
    
    // Otherwise, only accept lines if the endpoints fall on either side of the x-value
    if (p1.x < x) {
        return (p2.x > x);
    }
    else {
        return (p2.x < x);
    }
}

static CGFloat yValueOfLineAtXValue(CGPoint p1, CGPoint p2, CGFloat x) {
    CGFloat frac = (x - p1.x) / (p2.x - p1.x);
    return frac*(p2.y - p1.y) + p1.y;
}

- (BOOL)xValue:(CGFloat)px intersectsLine:(RSLine *)testLine saveY:(CGFloat *)saveY;
// Let's try this using data coords.
{
    NSArray *VArray = [[testLine vertices] elements];

    // if the line has fewer than two points, it trivially cannot be intersected
    if( [VArray count] < 2 ) {
        return NO;
    }

    // Straight connections (or a line with just two endpoints)
    if( [testLine connectMethod] == RSConnectStraight || [VArray count] == 2 ) {
        for (NSUInteger i = 1; i < [VArray count]; i++) {
            RSVertex *V1 = [VArray objectAtIndex:i - 1];
            RSVertex *V2 = [VArray objectAtIndex:i];
            
            CGPoint s1 = [self convertToViewCoords:[V1 position]];
            CGPoint s2 = [self convertToViewCoords:[V2 position]];
            
            if (!lineIntersectsXValue(s1, s2, px))
                continue;
            
            // If the line does intersect the x-value, calculate the intersection and return YES
            if (saveY) {
                *saveY = yValueOfLineAtXValue(s1, s2, px);
            }
            return YES;
        }
        
        // if got this far...
        return NO;
    }

    // Curved connections
    else if( [testLine connectMethod] == RSConnectCurved ) {
        NSInteger n = [VArray count] - 1;
        CGPoint segs[n + 1][3];
        
        // compute the curve segments
        [self bezierSegmentsFromVertexArray:VArray putInto:segs];
        
        //
        // hit-test each curve segment
        float incr = 0.1f;
        
        // loop through each curve segment
        for( int i=0; i<n; i++ ) {
            CGPoint p0 = segs[i][0];  // control points making up each segment
            CGPoint p1 = segs[i][1];
            CGPoint p2 = segs[i][2];
            CGPoint p3 = segs[i+1][0];
            
            // loop through approximating straight lines
            for( float t=0; t<1; t+=incr ) {
                
                // straight line approximation endpoints:
                CGPoint s1 = evaluateBezierPathAtT(p0, p1, p2, p3, t);
                CGPoint s2 = evaluateBezierPathAtT(p0, p1, p2, p3, t+incr);
                
                if (!lineIntersectsXValue(s1, s2, px))
                    continue;
                
                // If the line does intersect the x-value, calculate the intersection and return YES
                if (saveY) {
                    *saveY = yValueOfLineAtXValue(s1, s2, px);
                }
                return YES;
            }
        }
        
        // if got this far...
        return NO;
    }

    OBASSERT_NOT_REACHED("Unknown line type");
    return NO;
}


///////////////////////////
#pragma mark -
#pragma mark Helper methods for arrows
///////////////////////////


- (CGFloat)timeOfAdjustedEnd:(RSVertex *)V onLine:(RSLine *)L;
// Returns the line endpoint in view coords, adjusted to accommodate an arrow ending.
{
    if ([L hasNoLength]) {
	return 0;
    }
    
    NSUInteger direction;
    CGFloat t;
    if ([L startVertex] == V) {
	direction = RS_FORWARD;
	t = 0;
    }
    else if ([L endVertex] == V) {
	direction = RS_BACKWARD;
	t = 1;
    }
    else {
	// if not a start or end vertex, do nothing
	OBASSERT_NOT_REACHED("not a start or end vertex");
	return 0;
    }
    
    // view distance to adjust the line by:
    CGFloat distance = [V width] * 3;
    
    CGFloat adjustedT = [self timeOnLine:L viewDistance:distance fromTime:t direction:direction];
    return adjustedT;
}

- (CGFloat)degreesFromHorizontalOfAdjustedEnd:(RSVertex *)V onLine:(RSLine *)L;
// Returns the angle between the adjusted line end and the actual line endpoint; i.e., the angle between the base and point of the arrow.
{
    CGFloat t = [self timeOfAdjustedEnd:V onLine:L];
    CGPoint adjustedEnd = [self locationOnCurve:L atTime:t];
    
    CGPoint p = [self convertToViewCoords:[V position]];
    
    return degreesFromHorizontalOfVector(p, adjustedEnd);
}



///////////////////////////
#pragma mark -
#pragma mark Helper methods for fills
///////////////////////////

- (NSUInteger)bestIndexInFill:(RSFill *)F forVertex:(RSVertex *)V;
{
    RSGroup *vertices = [F vertices];
    
    // don't bother if the vertex is already included!
    if ( [F containsVertex:V] )  return 0;
    
    // simplest case...
    if ( [vertices count] <= 2 ) {
	return [vertices count];
    }
    
    
    // first, find the closest vertex to V that is already in the fill
    RSDataPoint pos = [V position];
    NSEnumerator *E = [[vertices elements] objectEnumerator];
    RSVertex *one = [E nextObject];
    RSVertex *obj = nil;
    while ((obj = [E nextObject])) {
        if ( [self viewDistanceBetween:pos and:[obj position]] < [self viewDistanceBetween:pos and:[one position]] )
            one = obj;
    }
    // find the neighbor that is closest to V
    RSVertex *next = (RSVertex *)[vertices nextElement:one];
    RSVertex *prev = (RSVertex *)[vertices prevElement:one];
    if ( [self viewDistanceBetween:pos and:[prev position]] < [self viewDistanceBetween:pos and:[next position]] )
        one = prev;
    
    //! Not sure if this is really the best way.  I think it will break when the x- and y-scales are very different.
    
    // now we want to position the new vertex after vertex one
    NSUInteger index = [[vertices elements] indexOfObjectIdenticalTo:one];
    return index + 1;
}

- (CGFloat)viewAreaOfFill:(RSFill *)F;
{
    if ([[F vertices] count] <= 2)
        return 0;
    
    CGFloat area = 0;
    
    CGPoint p1, p2 = CGPointZero;
    BOOL start = YES;
    for (RSVertex *V in [[F vertices] elements]) {
        if (!start) {
            p1 = p2;
        } else {
            p1 = [self convertToViewCoords:[[[F vertices] lastElement] position]];
            start = NO;
        }
        p2 = [self convertToViewCoords:[V position]];
        
//        area += p1.x*p2.y;
//        area -= p1.y*p2.x;
        area += (p1.x - p2.x)*(p1.y + p2.y);
    }
    area /= 2;
    if (area < 0)  area *= -1;
    
    return area;
}


///////////////////////////
#pragma mark -
#pragma mark Helper methods for text labels
///////////////////////////

- (CGRect)rectFromLabel:(RSTextLabel *)TL offset:(CGFloat)offset;
    // returns a view-coords rect of the bounds of the text label, expanded 'offset' pixels in each direction.
{
    OBASSERT(TL);
    
    CGSize size = [TL size];
    CGPoint p = [self convertToViewCoords:[TL position]];
    CGRect rect = CGRectMake(p.x, p.y, size.width, size.height);
    
    if ( offset ) {
        rect = CGRectInset(rect, -offset, -offset);
    }
    
    // the following ensures that a non-zero-area rectangle is returned always, for math safety:
    if( rect.size.width < 1 )  rect.size.width = 2;
    if( rect.size.height < 1 )  rect.size.height = 2;
    
    return rect;
}


- (CGRect)rectFromPosition:(data_p)pos onAxis:(RSAxis *)axis;
{
    if (![axis displayAxis])  // axis is not visible
        OBASSERT_NOT_REACHED("This method shouldn't be needed when the axis is not visible");
    
    CGFloat hitOffset = [axis width]/2 + [[OFPreferenceWrapper sharedPreferenceWrapper] floatForKey:@"SelectionSensitivity"];
    
    RSBorder border = RSMakeBorder(hitOffset, hitOffset, hitOffset, hitOffset);
    RSDataPoint center;
    
    if ([axis orientation] == RS_ORIENTATION_HORIZONTAL) {
        border.top += [axis tickWidthIn];
        border.bottom += [axis tickWidthOut];
        
        center = RSDataPointMake(pos, [self originPoint].y);
    }
    else {  // vertical
        border.right += [axis tickWidthIn];
        border.left += [axis tickWidthOut];
        
        center = RSDataPointMake([self originPoint].x, pos);
    }
    
    CGPoint viewCenter = [self convertToViewCoords:center];
    CGRect r = RSAddBorderToPoint(border, viewCenter);
    
    return r;
}


///////////////////////////
#pragma mark -
#pragma mark Helper methods for axes
///////////////////////////

- (CGFloat)viewLengthOfAxis:(RSAxis *)axis;
{
    if ([axis orientation] == RS_ORIENTATION_HORIZONTAL) {
        return [self viewMaxes].x - [self viewMins].x;
    }
    else {  // vertical
        return [self viewMaxes].y - [self viewMins].y;
    }
}

- (CGPoint)positionOfAxisEnd:(RSAxisEnd)axisEnd;
// In view coords
{
    CGPoint origin = [self viewOriginPoint];
    CGPoint mins = [self viewMins];
    CGPoint maxes = [self viewMaxes];
    
    CGPoint point = CGPointZero;
    if (axisEnd == RSAxisXMax) {
        point = CGPointMake(maxes.x, origin.y);
    }
    else if (axisEnd == RSAxisXMin) {
        point = CGPointMake(mins.x, origin.y);
    }
    else if (axisEnd == RSAxisYMax) {
        point = CGPointMake(origin.x, maxes.y);
    }
    else if (axisEnd == RSAxisYMin) {
        point = CGPointMake(origin.x, mins.y);
    }
    
    return point;
}


///////////////////////////
#pragma mark -
#pragma mark DEBUGGING
///////////////////////////
#ifdef DEBUG

#endif


@end
