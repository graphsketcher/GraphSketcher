// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "RSHitTester-Snapping.h"

#import <GraphSketcherModel/RSDataMapper.h>
#import <GraphSketcherModel/RSVertex.h>
#import <GraphSketcherModel/RSVertexList.h>
#import <GraphSketcherModel/RSLine.h>
#import <GraphSketcherModel/RSConnectLine.h>
#import <GraphSketcherModel/RSFill.h>
#import <GraphSketcherModel/RSNumber.h>
#import <GraphSketcherModel/RSGraphEditor.h>
#import <GraphSketcherModel/RSGraphRenderer.h>
#import <GraphSketcherModel/RSTextLabel.h>
#import <GraphSketcherModel/OFPreference-RSExtensions.h>


// Quick way to let us keep these shortcuts
#define _graph _nonretained_editor.graph
#define _mapper _nonretained_editor.mapper
#define _renderer _nonretained_editor.renderer


// First dictionary has precedence over second.
static NSMutableDictionary *mergedDictionary(NSDictionary *first, NSDictionary *second)
{
    NSMutableDictionary *merged = [first mutableCopy];
    
    for (id key in [second keyEnumerator]) {
        if (![merged objectForKey:key]) {
            [merged setObject:[second objectForKey:key] forKey:key];
        }
    }
    return [merged autorelease];
}


#pragma mark -
@implementation RSHitTester (Snapping)


////////////
#pragma mark -
#pragma mark Snap to grid
////////////

// snaps min and max to tick marks if they are close enough
- (void)snapAxisToGrid:(RSAxis *)A;
{
    [_mapper mappingParametersDidChange];  // Make sure the parameters are up-to-date
    
    CGFloat min, max;
    if( [A orientation] == RS_ORIENTATION_HORIZONTAL ) {
	min = [_mapper viewMins].x;
	max = [_mapper viewMaxes].x;
    }
    else {  // [A orientation] == RS_ORIENTATION_VERTICAL
	min = [_mapper viewMins].y;
	max = [_mapper viewMaxes].y;
    }
    
    [self snapAxisToGrid:A viewMin:min viewMax:max];
}

- (void)snapAxisToGrid:(RSAxis *)A viewMin:(CGFloat)viewMin viewMax:(CGFloat)viewMax;
{
    if( [A orientation] == RS_ORIENTATION_HORIZONTAL ) {
        [self snapAxisEndToGrid:RSAxisXMax viewMin:viewMin viewMax:viewMax];
        [self snapAxisEndToGrid:RSAxisXMin viewMin:viewMin viewMax:viewMax];
    }
    else if( [A orientation] == RS_ORIENTATION_VERTICAL ) {
        [self snapAxisEndToGrid:RSAxisYMax viewMin:viewMin viewMax:viewMax];
        [self snapAxisEndToGrid:RSAxisYMin viewMin:viewMin viewMax:viewMax];
    }
}

- (BOOL)snapAxisEndToGrid:(RSAxisEnd)axisEnd viewMin:(CGFloat)viewMin viewMax:(CGFloat)viewMax;
// Return value is YES if a snap occurred.
{
    float offsetZone = (float)[self snapToGridSensitivity];
    BOOL didSnap = NO;
    RSAxis *axis = [_graph axisWithAxisEnd:axisEnd];
    
    [_mapper mappingParametersDidChange];  // Make sure the parameters are up-to-date
    
    data_p axisMin = [axis min];
    data_p axisMax = [axis max];
    
    // If max end is free
    if (axisEnd == RSAxisXMax || axisEnd == RSAxisYMax) {
        data_p nearestTick = [axis closestTickMarkToMax:axisMax];
        if (nearestTick == axisMax)
            return NO;
        
        data_p distanceFraction;
        if ([axis axisType] == RSAxisTypeLinear) {
            distanceFraction = fabs(nearestTick - axisMax)/(axisMax - axisMin);
        }
        else {  // RSAxisTypeLogarithmic
            distanceFraction = fabs(log2(nearestTick/axisMax) / log2(axisMax/axisMin));
        }
        
        CGFloat distance = (CGFloat)(distanceFraction * (data_p)(viewMax - viewMin));
        //DEBUG_RS(@"distance: %f, viewMax: %f", distance, viewMax);
        if( distance < offsetZone ) {
            data_p n = nearestTick;
            // save the new axis max:
            [[axis maxLabel] setText:@" "];
            [axis setMax:n];
            didSnap = YES;
        } else {
            // do not display unsightly end label
            [[axis maxLabel] setText:RS_DELETED_STRING];
        }
    }
    
    // If min end is free
    else if (axisEnd == RSAxisXMin || axisEnd == RSAxisYMin) {
        data_p nearestTick = [axis closestTickMarkToMin:axisMin];
        if (nearestTick == axisMin)
            return NO;
        
        data_p distanceFraction;
        if ([axis axisType] == RSAxisTypeLinear) {
            distanceFraction = fabs(nearestTick - axisMin)/(axisMax - axisMin);
        }
        else {  // RSAxisTypeLogarithmic
            distanceFraction = fabs(log2(nearestTick/axisMin) / log2(axisMax/axisMin));
        }
        
        CGFloat distance = (CGFloat)(distanceFraction * (data_p)(viewMax - viewMin));
        if( distance < offsetZone ) {
            data_p n = nearestTick;
            // save the new axis max:
            [[axis minLabel] setText:@" "];
            [axis setMin:n];
            didSnap = YES;
        } else {
            [[axis minLabel] setText:RS_DELETED_STRING];
        }
    }
    
    return didSnap;
}





#pragma mark -

////////////////////////
#pragma mark -
#pragma mark Low-level methods for finding constraints for points
////

- (RSDataPoint)snapToGridNearPoint:(CGPoint)pView saveConstraints:(NSMutableDictionary *)constraints;
// p is in view coords. Returns the point in data coords after potentially being snapped to one or both grid dimensions.
// "constraints" can be nil
{
    RSDataPoint pData = [_mapper convertToDataCoords:pView];
    
    // Don't snap to grid if preference is disabled:
    if( ![[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:@"SnapToGrid"] ) {
	return pData;
    }
    // Don't snap to grid if the relevant visual components are turned off:
    if( [_graph noGridComponentsAreDisplayed] ) {
	return pData;
    }
    
    // Otherwise, snap to grid:
    float sensitivity = (float)[self snapToGridSensitivity];
    RSDataPoint reduced;
    reduced.x = [_mapper closestGridLineTo:pView.x onAxis:[_graph xAxis]];
    reduced.y = [_mapper closestGridLineTo:pView.y onAxis:[_graph yAxis]];
    
    RSDataPoint final = pData;
    CGPoint reducedView = [_mapper convertToViewCoords:reduced];
    if( fabs(reducedView.x - pView.x) < sensitivity ) {
	final.x = reduced.x;
        [constraints setValue:[NSNumber numberWithDouble:final.x] forKey:RSSnapConstraintXKey];
    }
    if( fabs(reducedView.y - pView.y) < sensitivity ) {
	final.y = reduced.y;
        [constraints setValue:[NSNumber numberWithDouble:final.y] forKey:RSSnapConstraintYKey];
    }
    return final;
}

- (RSAxis *)snapToAxesNearPoint:(CGPoint)p saveConstraints:(NSMutableDictionary *)constraints;
// If an axis is nearby, adds appropriate snap-constraint and returns the axis object.
// view coords
{
    RSAxis *axis = [_graph xAxis];  // horizontal
    if ( [self hitTestPoint:p onAxis:axis edge:RSAxisEdgeMin].hit ) {
        [constraints setValue:[NSNumber numberWithDouble:[_mapper originPoint].y] forKey:RSSnapConstraintYKey];
        return axis;
    }
    else if ( [self hitTestPoint:p onAxis:axis edge:RSAxisEdgeMax].hit ) {
        [constraints setValue:[NSNumber numberWithDouble:[_graph yMax]] forKey:RSSnapConstraintYKey];
        return axis;
    }
    
    axis = [_graph yAxis]; // vertical
    if ( [self hitTestPoint:p onAxis:axis edge:RSAxisEdgeMin].hit ) {
        [constraints setValue:[NSNumber numberWithDouble:[_mapper originPoint].x] forKey:RSSnapConstraintXKey];
        return axis;
    }
    else if ( [self hitTestPoint:p onAxis:axis edge:RSAxisEdgeMax].hit ) {
        [constraints setValue:[NSNumber numberWithDouble:[_graph xMax]] forKey:RSSnapConstraintXKey];
        return axis;
    }
    
    return nil;
}

- (RSDataPoint)snapTo90DegreesNearPoint:(RSDataPoint)dragged aroundPoint:(RSDataPoint)neighbor saveConstraints:(NSMutableDictionary *)constraints;
// Points in data coords.
{
    float sensitivity = (float)[self snapToObjectSensitivity];
    CGPoint pView = [_mapper convertToViewCoords:dragged];
    CGPoint nView = [_mapper convertToViewCoords:neighbor];
    RSDataPoint final = dragged;
    
    if ( fabs(nView.x - pView.x) < sensitivity ) {
        final.x = neighbor.x;
        [constraints setValue:[NSNumber numberWithDouble:final.x] forKey:RSSnapConstraintXKey];
    }
    if ( fabs(nView.y - pView.y) < sensitivity ) {
        final.y = neighbor.y;
        [constraints setValue:[NSNumber numberWithDouble:final.y] forKey:RSSnapConstraintYKey];
    }
    
    return final;
}

- (RSDataPoint)snapTo90DegreesNearPoint:(RSDataPoint)dragged prevVertex:(RSVertex *)prevVertex nextVertex:(RSVertex *)nextVertex saveConstraints:(NSMutableDictionary *)constraints;
// Points in data coords.
{
    if (!prevVertex && !nextVertex) {
        return dragged;
    }
    
    RSDataPoint final = dragged;
    
    if (prevVertex) {
        final = [self snapTo90DegreesNearPoint:dragged aroundPoint:[prevVertex position] saveConstraints:constraints];
    }
    
    if (nextVertex) {
        final = [self snapTo90DegreesNearPoint:dragged aroundPoint:[nextVertex position] saveConstraints:constraints];
    }
    
    return final;
}

- (RSDataPoint)constrainTo90DegreesNearPoint:(RSDataPoint)dragged aroundPoint:(RSDataPoint)neighbor saveConstraints:(NSMutableDictionary *)constraints;
// i.e. Shift key behavior
// Points in data coords.
{
    CGPoint pView = [_mapper convertToViewCoords:dragged];
    CGPoint nView = [_mapper convertToViewCoords:neighbor];
    RSDataPoint final = dragged;
    
    CGFloat xdist = fabs(nView.x - pView.x);
    CGFloat ydist = fabs(nView.y - pView.y);
    
    if (xdist <= ydist) {
        final.x = neighbor.x;
        [constraints setValue:[NSNumber numberWithDouble:final.x] forKey:RSSnapConstraintXKey];
    }
    else {  // ydist < xdist
        final.y = neighbor.y;
        [constraints setValue:[NSNumber numberWithDouble:final.y] forKey:RSSnapConstraintYKey];
    }
    
    return final;
}

- (RSDataPoint)constrainTo90DegreesNearPoint:(RSDataPoint)dragged prevVertex:(RSVertex *)prevVertex nextVertex:(RSVertex *)nextVertex saveConstraints:(NSMutableDictionary *)constraints;
// Points in data coords.
{
    if (!prevVertex && !nextVertex) {
        return dragged;
    }
    
    // If two neighbors, constrain to whichever dimension of either neighbor is closest, and if applicable snap to the other dimension.  This behavior seemed to produce more understandable results than trying to rigidly snap both dimensions (and other variations I tried).
    if (nextVertex && prevVertex) {
        
        // First, try snapping
        [self snapTo90DegreesNearPoint:dragged prevVertex:prevVertex nextVertex:nextVertex saveConstraints:constraints];
        
        // Next, constrain to whichever dimension of whichever point is nearest
        CGPoint pView = [_mapper convertToViewCoords:dragged];
        CGPoint p1 = [_mapper convertToViewCoords:[prevVertex position]];
        CGPoint p2 = [_mapper convertToViewCoords:[nextVertex position]];
        RSDataPoint final = dragged;
        
        CGFloat x1dist = fabs(p1.x - pView.x);
        CGFloat y1dist = fabs(p1.y - pView.y);
        CGFloat x2dist = fabs(p2.x - pView.x);
        CGFloat y2dist = fabs(p2.y - pView.y);
        
        if (x1dist <= y1dist && x1dist <= x2dist && x1dist <= y2dist) {
            final.x = [prevVertex position].x;
            [constraints setValue:[NSNumber numberWithDouble:final.x] forKey:RSSnapConstraintXKey];
        }
        else if (x2dist <= y1dist && x2dist <= x1dist && x2dist <= y2dist) {
            final.x = [nextVertex position].x;
            [constraints setValue:[NSNumber numberWithDouble:final.x] forKey:RSSnapConstraintXKey];
        }
        else if (y1dist <= x2dist && y1dist <= x1dist && y1dist <= y2dist) {
            final.y = [prevVertex position].y;
            [constraints setValue:[NSNumber numberWithDouble:final.y] forKey:RSSnapConstraintYKey];
        }
        else {
            final.y = [nextVertex position].y;
            [constraints setValue:[NSNumber numberWithDouble:final.y] forKey:RSSnapConstraintYKey];
        }
        
        return final;
    }
    
    // If just one neighbor, constrain to the closest 90 degree angle from it.
    if (nextVertex) {
        return [self constrainTo90DegreesNearPoint:dragged aroundPoint:[nextVertex position] saveConstraints:constraints];
    }
    if (prevVertex) {
        return [self constrainTo90DegreesNearPoint:dragged aroundPoint:[prevVertex position] saveConstraints:constraints];
    }
    
    OBASSERT_NOT_REACHED("All cases should have been covered already.");
    return dragged;
}




- (RSDataPoint)applyConstraints:(NSDictionary *)constraints toPoint:(RSDataPoint)p;
{
    RSDataPoint final = p;
    NSNumber *val;
    if ( (val = [constraints valueForKey:RSSnapConstraintXKey]) ) {
        final.x = [val doubleValue];
    }
    if ( (val = [constraints valueForKey:RSSnapConstraintYKey]) ) {
        final.y = [val doubleValue];
    }
    
    return final;
}



////////////////////////
#pragma mark -
#pragma mark Mid-level methods for snapping vertices to objects
////

- (RSAxis *)snapVertex:(RSVertex *)movingVertex toAxesNearPoint:(CGPoint)p saveConstraints:(NSMutableDictionary *)constraints;
{
    RSAxis *axis = [self snapToAxesNearPoint:p saveConstraints:constraints];
    
    if (axis) {
        // Tell the vertex about it
        [movingVertex addSnappedTo:axis withParam:[NSNumber numberWithDouble:0]];
    }
    
    return axis;  // could be nil
}

- (RSVertex *)snapVertex:(RSVertex *)movingVertex toVerticesNear:(CGPoint)p;
{
    NSArray *vertices = [_graph Vertices];
    
    // make sure there is at least *something* there
    if ( ![vertices count] )
        return nil;
    
    // don't include movingVertex and its cluster
    NSArray *clusterNot = nil;
    if (movingVertex) {
	clusterNot = [movingVertex vertexCluster];
        
        // also don't include vertices sharing the same parent
        NSArray *parents = [movingVertex parentsOfVertexCluster];
        for (RSGraphElement *parent in parents) {
            for (RSVertex *V in vertices) {
                if ([[V parents] containsObjectIdenticalTo:parent]) {
                    clusterNot = [clusterNot arrayByAddingObject:V];
                }
            }
        }
    }
    
    RSHitResult hitResult = [self vertexUnderPoint:p notIncluding:clusterNot extraElement:nil hitOffset:[self snapToObjectSensitivity] includeInvisible:YES includeBars:NO];
    if (!hitResult.hit) {
        return nil;
    }
    
    // if found a hit
    RSVertex *snapV = (RSVertex *)hitResult.element;
    
    [movingVertex addSnappedTo:snapV withParam:[NSNumber numberWithDouble:0]];
    [movingVertex setPosition:[snapV position]];
    return snapV;
}


// Snaps a vertex to any line or line intersection near p, AND updates the vertex's "snappedTo" list which is necessary for fills to curve along curved edges.
// Input p is in VIEW coords (for matching against the cache)
- (RSGraphElement *)snapVertex:(RSVertex *)V toLineOrIntersectionNear:(CGPoint)p useConstraints:(NSDictionary *)constraints;
{
    //Log2(@"snapping to line or intersection");
    
    // make sure p corresponds to the current cache; update cache if necessary
    //if( !nearlyEqualPoints(p, _hitPoint) ) {
    //	[self lineUnderPoint:p];
    //}
    
    NSArray *hitLines = [self linesThatWereHit];
    
    // empty the vertex's snappedTo list (before potentially re-populating it)
    //done in [snapVertex:fromPoint:]//[V clearSnappedTo];
    
    //////
    // if at least two lines were hit, snap to the intersection of the first two
    if( [hitLines count] >= 2 ) {
	//Log1(@"two lines");
	CGFloat t1, t2; // snap t-value for both lines
	CGPoint ip = [self intersectionUnderPoint:p saveT1:&t1 andT2:&t2];
	
	// if an intersection was found, use it
	if( !CGPointEqualToPoint(ip, p) ) {
	    // update vertex position - this must come before the snap information
	    RSDataPoint np = [_mapper roundToGrid:ip];
	    [V setPosition:np];
	    
	    // tell vertex about the snap
	    RSLine *L1 = [hitLines objectAtIndex:0];
	    RSLine *L2 = [hitLines objectAtIndex:1];
	    [V addSnappedTo:L1 withParam:[NSNumber numberWithDouble:t1]];
	    [V addSnappedTo:L2 withParam:[NSNumber numberWithDouble:t2]];
	    
            // This was problematic for snapping to places where a point was already at the intersection
            //            RSGroup *G = [RSGroup groupWithGraph:_graph];
            //            [G addElement:L1];
            //            [G addElement:L2];
            //            return G;
            return nil;
	}
	// if no intersection was actually found, then treat this as a one-line case
	// by simply continuing on...
    }
    
    //////
    // if only one line was found, snap to intersection with constraints if possible
    if( [hitLines count] >= 1 ) {
	//Log1(@"one line");
	// get the first line hit
	RSLine *L = [hitLines objectAtIndex:0];
	CGFloat t = 0;  // t-value snap occurred at
        CGPoint cp = p;
        BOOL constraintsApplied = NO;
        
        // If there are constraint(s), then try to intersect with them
        if ([constraints count]) {
            cp = [self intersectionNearPoint:p withLine:L andConstraints:constraints saveT:&t];
            if (!CGPointEqualToPoint(cp, p)) {
                constraintsApplied = YES;
            }
        }
        
        // If no constraints applied, just snap to the closest point on the line
        if (!constraintsApplied) {
            cp = [self closestPointTo:p onCurve:L saveT:&t];
        }
        
        // set vertex position
        if (!pointIsFinite(cp)) {
            OBASSERT_NOT_REACHED("trying to snap to non-finite point value");
            cp = p;
        }
        RSDataPoint np = [_mapper roundToGrid:cp];
        [V setPosition:np];
        // tell vertex about the snap
        OBASSERT(isfinite(t) && t >= 0);
        [V addSnappedTo:L withParam:[NSNumber numberWithDouble:t]];
        //Log1(@"param: %f", t);
        
        return L;
    }
    
    
    
    //////
    // if no lines were hit, do nothing
    if( [hitLines count] <= 0 ) {
	// except update vertex position
	RSDataPoint np = [_mapper convertToDataCoords:p];
	[V setPosition:np];
    }
    
    return nil;
}

- (RSGraphElement *)snapVertex:(RSVertex *)V toLineNear:(CGPoint)p useConstraints:(NSDictionary *)constraints;
// If a snap was made between a line and a constraint, this sets up the vertex and returns the line.
{
    if (![constraints count]) {
        return nil;
    }
    
    NSArray *hitLines = [self linesThatWereHit];
    RSLine *L = [hitLines objectAtIndex:0];  // first line that was hit
    CGFloat t;  // t-value snap occurred at
    
    CGPoint cp = [self intersectionNearPoint:p withLine:L andConstraints:constraints saveT:&t];
    if (CGPointEqualToPoint(cp, p))
        return nil;
    
    // set vertex position
    RSDataPoint np = [_mapper roundToGrid:cp];
    [V setPosition:np];
    // tell vertex about the snap
    [V addSnappedTo:L withParam:[NSNumber numberWithDouble:t]];
    
    return L;
}




////////////////////////
#pragma mark -
#pragma mark Highest-level methods for vertex snapping
////

// Priority order for snapping
// 1. objects
// 2. grid
// 3. nearby vert/horiz/45-degree

// Snaps the movingVertex to vertices, axes, lines, intersections, and grid points.
// Returns the object the vertex got snapped to, if any (so it can be half-selected).
// p is in VIEW COORDS
- (RSGraphElement *)snapVertex:(RSVertex *)movingVertex fromPoint:(CGPoint)p;
{
    return [self snapVertex:movingVertex fromPoint:p behavior:RSSnapBehaviorRegular];
}

- (RSGraphElement *)snapVertex:(RSVertex *)movingVertex fromPoint:(CGPoint)p behavior:(RSSnapBehavior)behavior;
{
    // If movingVertex already has a line or fill assigned as its parent, then use the neighboring points (if any) for potential snapping.
    RSGraphElement<RSVertexList> *parent = nil;
    RSVertex *prevVertex = nil;
    RSVertex *nextVertex = nil;
    
    RSLine *L = [movingVertex lastParentLine];
    RSFill *F = [movingVertex lastParentFill];
    if (L && [L isKindOfClass:[RSConnectLine class]] && 
        ([(RSConnectLine *)L connectMethod] == RSConnectStraight || [(RSConnectLine *)L isStraight]) ) {
        parent = (RSConnectLine *)L;
    }
    else if (F && [[F vertices] count] > 1) {
        parent = F;
    }
    
    if (parent) {
        prevVertex = [parent prevVertex:movingVertex];
        nextVertex = [parent nextVertex:movingVertex];
    }
    
    return [self snapVertex:movingVertex fromPoint:p behavior:behavior prevVertex:prevVertex nextVertex:nextVertex];
}

- (RSGraphElement *)snapVertex:(RSVertex *)movingVertex fromPoint:(CGPoint)p behavior:(RSSnapBehavior)behavior prevVertex:(RSVertex *)prevVertex nextVertex:(RSVertex *)nextVertex;
// If prevVertex and nextVertex are nil, then 45/90-degree snapping is not attempted.
{
    RSGraphElement *snappedTo = nil;  // by default, no snap found
    
    // Clear snapped-to objects right away (they will be re-generated later if necessary)
    [movingVertex removeExtendedConstraints];
    
    //////
    // Get geometric constraints according to the snap behavior specified
    NSMutableDictionary *coordConstraints = nil;
    RSDataPoint pData = [_mapper convertToDataCoords:p];
    
    // Regular behavior priorities: 1. objects; 2. grid; 3. nearby 90-degree
    if (behavior == RSSnapBehaviorRegular) {
        
        // Snap to other vertices.  Do this first because if there's a hit, we're done.
        RSVertex *V = [self snapVertex:movingVertex toVerticesNear:p];
        if (V)
            return V;
        
        // Get snap-constraints for nearby grid lines and axes, to potentially be used later.
        NSMutableDictionary *gridConstraints = [NSMutableDictionary dictionaryWithCapacity:2];
        [self snapToGridNearPoint:p saveConstraints:gridConstraints];
        snappedTo = [self snapVertex:movingVertex toAxesNearPoint:p saveConstraints:gridConstraints];
        
        // If prev/next neighbor points were specified, add constraints for them
        NSMutableDictionary *neighborConstraints = [NSMutableDictionary dictionaryWithCapacity:2];
        [self snapTo90DegreesNearPoint:pData prevVertex:prevVertex nextVertex:nextVertex saveConstraints:neighborConstraints];
        
        coordConstraints = mergedDictionary(gridConstraints, neighborConstraints);
        
        // snap to lines and intersections
        if ( [self lineUnderPoint:p notIncluding:[movingVertex parentsOfVertexCluster]].hit ) {
            snappedTo = [self snapVertex:movingVertex toLineOrIntersectionNear:p useConstraints:coordConstraints];
            if (snappedTo) {
                return snappedTo;
            }
        }
    }
    
    // Shift key behavior priorities: 1. nearest 90-degree; 2. objects; 3. grid
    else if (behavior == RSSnapBehaviorShiftKey) {
        // 90-degree hard constraints
        NSMutableDictionary *angleConstraints = [NSMutableDictionary dictionaryWithCapacity:2];
        [self constrainTo90DegreesNearPoint:pData prevVertex:prevVertex nextVertex:nextVertex saveConstraints:angleConstraints];
        
        // Snap-constraints for nearby grid lines and axes
        NSMutableDictionary *gridConstraints = [NSMutableDictionary dictionaryWithCapacity:2];
        [self snapToGridNearPoint:p saveConstraints:gridConstraints];
        snappedTo = [self snapVertex:movingVertex toAxesNearPoint:p saveConstraints:gridConstraints];
        
        // Merge the sets of constraints together (with the 90-degree angle constraints taking precedence to snaps)
        coordConstraints = mergedDictionary(angleConstraints, gridConstraints);
        
        // snap to lines and intersections
        if ( [self lineUnderPoint:p notIncluding:[movingVertex parentsOfVertexCluster]].hit ) {
            snappedTo = [self snapVertex:movingVertex toLineNear:p useConstraints:angleConstraints];
            if (snappedTo) {
                return snappedTo;
            }
        }
    }
    
    // If didn't snap to any object, apply the non-object constraints that were generated (if any).
    [movingVertex setPosition:[self applyConstraints:coordConstraints toPoint:pData]];
    
    // Return the object that was snapped to, if any (nil otherwise):
    return snappedTo;
}




- (void)updateSnappedTos;
{
    [self updateSnappedTosForVertices:[_graph Vertices]];
}

- (void)updateSnappedTosForVertices:(NSArray *)vertices;
// Updates snap parameters and vertex positions to maintain snap constraints when objects are moved.
{
    
    for (RSVertex *V in vertices)
    {
	if (![V snappedTo])
	    continue;
	
	//
	// if snapped to two lines, move to the intersection between those lines
	NSArray *intersectionSnappers = [V extendedIntersectionSnappedTos];
	
	if ( [intersectionSnappers count] >= 2 ) {
	    RSLine *L1 = [intersectionSnappers objectAtIndex:0];
	    RSLine *L2 = [intersectionSnappers objectAtIndex:1];
	    
	    CGFloat t1 = [[V paramOfSnappedToElement:L1] floatValue];
	    CGFloat t2 = [[V paramOfSnappedToElement:L2] floatValue];
	    CGPoint ip = [_mapper convertToViewCoords:[V position]];
            
            if ([L1 isTooSmall] || [L2 isTooSmall]) {
                OBASSERT_NOT_REACHED("We shouldn't be snapped to undefined lines.");
                continue;
            }
	    
	    if ([self updateIntersection:&ip betweenLine:L1 atTime:&t1 andLine:L2 atTime:&t2]) {
		// if the intersection update was successful, update the position and parameters:
		[V setPosition:[_mapper convertToDataCoords:ip]];
		
		[V removeSnappedTo:L1];
		[V addSnappedTo:L1 withParam:[NSNumber numberWithDouble:t1]];
		[V removeSnappedTo:L2];
		[V addSnappedTo:L2 withParam:[NSNumber numberWithDouble:t2]];
	    }
	    
	    // Whether or not the intersection update worked, don't try the snap-to-one-line, because that just causes issues when you try to get the intersection back to where it was.
	    continue;
	}
	
	//
	// if just snapped to one line, move to maintain the t-value on that line
	NSMutableArray *lineSnappers = [NSMutableArray array];
	for (RSGraphElement *GE in [V extendedNonVertexSnappedTos]) {
	    if (![GE isKindOfClass:[RSLine class]])
		continue;
	    if ([[V parents] containsObjectIdenticalTo:GE])
		continue;
	    if ([(RSLine *)GE isTooSmall])  // This would be the case if it's a line-in-progress
		continue;
	    
	    // otherwise:
	    [lineSnappers addObject:GE];
	}
	
	if ( [lineSnappers count] >= 1 ) {
	    RSLine *L = [lineSnappers objectAtIndex:0];
	    [V setPosition:[_mapper convertToDataCoords:
			 [_mapper locationOnCurve:L 
					   atTime:[[V paramOfSnappedToElement:L] floatValue]]]];
	}
    }
}





////////////
#pragma mark -
#pragma mark Snapping lines to 45-degree increments (not currently used)
////////////

//- (CGPoint)closest45DegreeOfPoint:(CGPoint)dragged aroundPoint:(CGPoint)other;
//// All in user coords
//{
//    CGPoint new;
//    CGPoint viewDragged, viewOther;
//    CGFloat w, h;  // initial vector
//    CGFloat dc, dc2; // diagonal components along (1,1) and (1,-1)
//    CGFloat length; // length of best diagonal
//    
//    viewDragged = [_mapper convertToViewCoords:dragged];
//    viewOther = [_mapper convertToViewCoords:other];
//    w = viewDragged.x - viewOther.x;
//    h = viewDragged.y - viewOther.y;
//    
//    dc = w/2 + h/2; // component of line in direction (1,1)
//    dc2 = w/2 - h/2;  // component of line in direction (1, -1)
//    //NSLog(@"%.3f, %.3f, %.3f", dp, det, dc);
//    
//    // first, determine the best diagonal axis:
//    if( fabs(dc) > fabs(dc2) ) {
//	new.x = new.y = dc;
//    } else {
//	new.x = dc2;
//	new.y = -dc2;
//    }
//    // diagonal length:
//    length = 2*new.x*new.x;
//    // second, change to horiz/vertical if doing so results in a longer vector:
//    if( w*w > length ) { // then horiz is best
//	new.x = w;
//	new.y = 0;
//    } else if( h*h > length ) { // then vertical is best
//	new.x = 0;
//	new.y = h;
//    } // else, stick with diagonal
//    
//    // finally, add vector to its local origin:
//    new.x += viewOther.x;
//    new.y += viewOther.y;
//    
//    // Convert back to data coords
//    new = [_mapper convertToDataCoords:new];
//    
//    // Make sure that horizontal and vertical lines are exactly so.  This may avoid a bug in quartz rendering.
//    if (nearlyEqualFloats(new.x, other.x)) {
//        new.x = other.x;
//    }
//    if (nearlyEqualFloats(new.y, other.y)) {
//        new.y = other.y;
//    }
//    
//    // Don't change the other coordinate for vertical/horizontal lines (to maintain snap-to-grid).
//    if (nearlyEqualFloats(new.x, dragged.x)) {
//        new.x = dragged.x;
//    }
//    if (nearlyEqualFloats(new.y, dragged.y)) {
//        new.y = dragged.y;
//    }
//    
//    return new;
//}
//
//// this version only snaps if there is no grid point AND the closest 45-degree pt is nearby.
//// inputs in user coords.
//- (CGPoint)snapToNearby45DegreePoint:(CGPoint)dragged aroundPoint:(CGPoint)other {
//    // this hack works if [snapToGrid] is called on "dragged" before this method
//    if( [_mapper isGridPoint:dragged] ) {
//	return dragged;
//    }
//    
//    CGPoint closest = [self closest45DegreeOfPoint:dragged aroundPoint:other];
//    CGFloat viewDistance = distanceBetweenPoints([_mapper convertToViewCoords:dragged], [_mapper convertToViewCoords:closest]);
//    
//    if ( viewDistance < [self snapToObjectSensitivity] ) {
//	return closest;
//    }
//    else {
//	return dragged;
//    }
//}
//
//- (CGPoint)snapVertex:(RSVertex *)V toNearby45DegreePoint:(CGPoint)dragged;
//// This method works if vertex V already has a line or fill assigned as its parent.
//// Points in user coords.
//{
//    RSGraphElement<RSVertexList> *parent = nil;
//    
//    RSLine *L = [V lastParentLine];
//    RSFill *F = [V lastParentFill];
//    if (L && [L isKindOfClass:[RSConnectLine class]] && [(RSConnectLine *)L connectMethod] == RSConnectStraight) {
//        parent = (RSConnectLine *)L;
//    }
//    else if (F) {
//        parent = F;
//    }
//    else {
//        return dragged;
//    }
//    
//    RSVertex *prevVertex = [parent prevVertex:V];
//    if (prevVertex) {
//        dragged = [self snapToNearby45DegreePoint:dragged aroundPoint:[prevVertex position]];
//    }
//    
//    RSVertex *nextVertex = [parent nextVertex:V];
//    if (nextVertex) {
//        dragged = [self snapToNearby45DegreePoint:dragged aroundPoint:[nextVertex position]];
//    }
//    
//    [V setPosition:dragged];
//    return dragged;
//}
//
//- (CGPoint)constrainToClosest45DegreePoint:(CGPoint)dragged aroundPoint:(CGPoint)other;
//{
//    CGPoint closest = [self closest45DegreeOfPoint:dragged aroundPoint:other];
//    
//    BOOL enableX = NO, enableY = NO;
//    if (closest.x == other.x)
//        enableY = YES;
//    else if (closest.y == other.y)
//        enableX = YES;
//    
//    closest = [self snapToGrid:closest enableX:enableX enableY:enableY]; 
//    
//    CGPoint closestView = [_mapper convertToViewCoords:dragged];
//    if (enableX && [self hitTestPoint:closestView onAxis:[_graph yAxis]]) {
//        [_s setHalfSelection:[_graph yAxis]];
//        closest.x = [_mapper originPoint].x;
//    }
//    else if (enableY && [self hitTestPoint:closestView onAxis:[_graph xAxis]]) {
//        [_s setHalfSelection:[_graph xAxis]];
//        closest.y = [_mapper originPoint].y;
//    }
//    else {
//        [_s setHalfSelection:nil];
//    }
//    
//    return closest;
//}






/////////////////////
#pragma mark -
#pragma mark Snapping Labels to objects
////

- (void)autoSetLabelPositioningForVertex:(RSVertex *)V {
    // Set vertex-label positioning intelligently with respect to axes
    if( [V isSnappedToElement:[_graph xAxis]] ) {
	[V setLabelPosition:(CGFloat)(M_PI_2*3)];
	[V setLabelDistance:[[_graph xAxis] labelDistance]];
    }
    else if( [V isSnappedToElement:[_graph yAxis]] ) {
	[V setLabelPosition:(CGFloat)M_PI];
	[V setLabelDistance:[[_graph yAxis] labelDistance]];
    }
    else if ([V shape] == RS_BAR_VERTICAL)
    {
        [V setLabelPosition:M_PI_2];
    }
    else if ([V shape] == RS_BAR_HORIZONTAL)
    {
        [V setLabelPosition:0];
    }
}

// all in radians
- (CGFloat)snapAngleToCorners:(CGFloat)rad {
    CGFloat offset = 0.26180f; // 15 degrees
    CGFloat angle = rad;
    // get an angle between 0 and 2pi
    while( angle < 0 ) { angle += (CGFloat)PITIMES2; }
    while( angle > PITIMES2 ) { angle -= (CGFloat)PITIMES2; }
    
    // snap to 0, 90, 180, 270 degrees
    if( fabs(angle - M_PI_2) < offset )  angle = (CGFloat)M_PI_2;  // 90
    else if( fabs(angle - M_PI) < offset )  angle = (CGFloat)M_PI;  // 180
    else if( fabs(angle - (M_PI_2 + M_PI)) < offset )  angle = (CGFloat)(M_PI_2 + M_PI); // 270
    else if( fabs(angle - PITIMES2) < offset )  angle = (CGFloat)PITIMES2;  // 360
    else if( fabs(angle - 0) < offset )  angle = 0;  // 0
    
    return angle;
}

- (CGFloat)snapPercentage:(CGFloat)val toCenterOfLength:(CGFloat)length;
// val should be between 0 and 1
// length is in view coords
{
    if (nearlyEqualFloats(length, 0)) {
        return val;
    }
    
    float sensitivity = 1.5f * (float)[self snapToObjectSensitivity];
    CGFloat offset = sensitivity/length;
    
    if( fabs(val - 0.5f) < offset )  return 0.5f;
    else  return val;
}

- (RSGraphElement *)dragFreeLabel:(RSTextLabel *)label toPoint:(CGPoint)draggedPoint;
// Returns element the label snapped to, or nil. draggedPoint is in view coords.
{
    RSGraphElement *currentOwner = [label owner];
    
    //
    // if over a vertex:
    RSVertex *V = (RSVertex *)[self vertexUnderPoint:draggedPoint].element;
    if (V && (![V label] || V == currentOwner)) {
        if (![V label]) {
            [label setOwner:V];
            
            // Initial positioning setup
            [label setRotation:0];
            [self autoSetLabelPositioningForVertex:V];
        }
        
        // set the label position based on the angle to the point?
        [_renderer positionLabel:label forOwner:V];
        
        return V;
    }
    
    //
    // if over a line:
    RSLine *L = (RSLine *)[self lineUnderPoint:draggedPoint].element;
    if (L && (![L label] || L == currentOwner)) {
        // if the line doesn't already have a label...
        if ( ![L label] ) {
            [label setOwner:L];
        }
        
        // set the slide based on location along the line
        //[L setSlide:[self timeOfClosestPointTo:draggedPoint onCurve:L]];
        [L setSlide:[self snapPercentage:[self timeOfClosestPointTo:draggedPoint onLine:L]
                                          toCenterOfLength:[_mapper viewLengthOfLine:L]]];
        [_renderer positionLabel:label forOwner:L];
        
        return L;
    }
    
    //
    // if not over a vertex or line:
    if (currentOwner) {
        [label setOwner:nil];  // detach the label
    }
    
    return nil;
}

- (void)_detachLabel:(RSTextLabel *)label;
{
    [label setOwner:nil];
    _currentOwner = nil;
}

- (RSGraphElement *)dragAttachedLabel:(RSTextLabel *)label toPoint:(CGPoint)draggedPoint;
// draggedPoint is in view coords.
{
    CGFloat distance, angle;

    CGFloat hitOffset = [[OFPreferenceWrapper sharedPreferenceWrapper] floatForKey:@"SelectionSensitivity"];
    CGFloat popoutOffset = [[OFPreferenceWrapper sharedPreferenceWrapper] floatForKey:@"PopoutSensitivity"];

    RSGraphElement *owner = [label owner];
     
    //
    // Text Label attached to a vertex:
    //
    if ( [owner isKindOfClass:[RSVertex class]] ) {
        CGPoint vPoint = [_mapper convertToViewCoords:[(RSVertex *)owner position]];
        
        // check for pop-out detachment
        distance = hypot(draggedPoint.x - vPoint.x, draggedPoint.y - vPoint.y);
        CGFloat popoutDistance = hitOffset + popoutOffset + [label size].width/4.0f + [owner width]*3.0f;
        //NSLog(@"DETACH? distance=%f", distance);
        
        if ( distance > popoutDistance ) {
            // then detach...
            [self _detachLabel:label];
        }
        else {	// don't detach; drag around the point like usual
            // find the new angle (all in radians):
            angle = atan((draggedPoint.y - vPoint.y) / (draggedPoint.x - vPoint.x));
            if ( (draggedPoint.x - vPoint.x) < 0 )
                angle += (CGFloat)M_PI;
            
            angle = [self snapAngleToCorners:angle];  // snap to 0, 90, 180, etc.
            
            // position it:
            [(RSVertex *)owner setLabelPosition:angle];
            [_renderer positionLabel:label forOwner:owner];
        }
    }

    //////
    // Text Label attached to a line:
    else if ( [owner isKindOfClass:[RSLine class]] ) {
        RSLine *L = (RSLine *)owner;
        
        // check for pop-out detachment
        distance = distanceBetweenPoints(draggedPoint, [self closestPointTo:draggedPoint onCurve:L]);
        CGFloat popoutDistance = hitOffset + popoutOffset;
        if ( distance > popoutDistance ) {
            // then detach...
            [self _detachLabel:label];
        }
        else {	// don't detach; drag along line like usual
            
            CGFloat ratio = [self timeOfClosestPointTo:draggedPoint onLine:L];
            ratio = [self snapPercentage:ratio toCenterOfLength:[_mapper viewLengthOfLine:L]];
            [L setSlide:ratio];
            [_renderer positionLabel:label forOwner:L];
        }
    }

    // TODO: support for Fills
    /*
     
    //////
    // Text Label attached to a fill:
    else if ( [owner isKindOfClass:[RSFill class]] ) {
        RSFill *F = (RSFill *)owner;
        
        o.x = _v1Point.x + (_mouseDraggedPoint.x - _mouseDownPoint.x);
        o.y = _v1Point.y + (_mouseDraggedPoint.y - _mouseDownPoint.y);
        s = [_mapper convertSizeToDataCoords:[label size]];
        o.x += s.width/2;
        o.y += s.height/2;
        
        if ( [_view.editor.hitTester hitTestPoint:[_mapper convertToViewCoords:o] onFill:F] ) {
            CGPoint percents;
            percents.x = (o.x - [F position].x)/([F positionUR].x - [F position].x);
            percents.y = (o.y - [F position].y)/([F positionUR].y - [F position].y);
            [F setLabelPlacement:percents];
            // finish up:
            [_s setHalfSelection:nil];
        }
        else {	// mouse not over the fill
            s = [_mapper convertSizeToViewCoords:[F distanceSizeToPoint:o]];
            distance = sqrt(s.width*s.width + s.height*s.height);
            //NSLog(@"DETACH? distance=%f", distance);
            if ( distance > ( sqrt(hitOffset) * popoutRatio) ) {
                //NSLog(@"DETACH DETACH DETACH");
                // then detach...
                [label setOwner:nil];
            }
        }
    }
     
    */
    
    return [label owner];
}

- (void)beginDraggingLabel:(RSTextLabel *)label;
{
    _currentOwner = [label owner];
}

- (RSGraphElement *)snapLabel:(RSTextLabel *)label toObjectsNear:(CGPoint)draggedPoint;
{
    OBPRECONDITION(label);
    
    if (_currentOwner) {
        return [self dragAttachedLabel:label toPoint:draggedPoint];
    }
    else {
        return [self dragFreeLabel:label toPoint:draggedPoint];
    }
    
}


@end
