// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/Model/RSHitTester.m 200244 2013-12-10 00:11:55Z correia $

#import "RSHitTester.h"

#import <GraphSketcherModel/RSGraphEditor.h>
#import <GraphSketcherModel/RSNumber.h>
#import <GraphSketcherModel/NSBezierPath-RSExtensions.h>
#import <GraphSketcherModel/RSVertex.h>
#import <GraphSketcherModel/RSConnectLine.h>
#import <GraphSketcherModel/RSEquationLine.h>
#import <GraphSketcherModel/RSTextLabel.h>
#import <GraphSketcherModel/RSFill.h>
#import <GraphSketcherModel/RSGroup.h>
#import <GraphSketcherModel/RSGraphRenderer.h>
#import <GraphSketcherModel/RSGraphElement-Rendering.h>
#import <GraphSketcherModel/RSDataMapper.h>
#import <GraphSketcherModel/OFPreference-RSExtensions.h>


// Quick way to let us keep these shortcuts
#define _graph _nonretained_editor.graph
#define _mapper _nonretained_editor.mapper
#define _renderer _nonretained_editor.renderer


static RSHitResult RSHitResultMake(RSGraphElement *element, CGFloat distance, BOOL hit) {
    RSHitResult hitResult;
    hitResult.element = element;
    hitResult.distance = distance;
    hitResult.hit = hit;
    
    return hitResult;
}

const RSHitResult RSHitResultNo = {nil, 0, NO};


// Returns the parametric time of the point on the given straight line which is closest to 
// the point p.
// p is any point; start and end define the straight line (all in view coords).
static CGFloat timeOfClosestPointOnStraightLineToP(CGPoint start, CGPoint end, CGPoint p) {
    OBPRECONDITION(!CGPointEqualToPoint(start, end));
    
    if (CGPointEqualToPoint(start, p))
        return 0;
    if (CGPointEqualToPoint(end, p))
        return 1;
    
    CGPoint onLine = closestPointOnStraightLineToP(p, start, end);
    CGFloat full = distanceBetweenPoints(start, end);
    CGFloat partial = distanceBetweenPoints(start, onLine);
    if (full == 0) {
        return 0;
    }
    CGFloat percent = partial/full;
    return percent;
}

static CGFloat timeOfClosestPointOnBezierPathToP(CGPoint p0, CGPoint p1, CGPoint p2, CGPoint p3, CGPoint p) {
    // p is a point that is "near" a bezier path, and p0 thru p3 are the control points of the
    // path (all in view coords).
    // This method iteratively approximates the closest point to p on the bezier path.
    
    // Calculate distance to t= 0, 0.1, 0.2, ... , 1
    CGFloat incr = 0.05f;
    CGFloat t;
    CGPoint loc;  // location of t-value on curve
    CGFloat d;  // distance
    CGFloat t_closest = 0;
    CGFloat d_closest = 1000000;  // big
    
    for( t=0; t < (1 + incr); t+=incr ) {
	loc = evaluateBezierPathAtT(p0, p1, p2, p3, t);  // get location of t-value
	d = distanceBetweenPoints(p, loc);  // calculate distance from given point
	
	// check if this is the closest so far
	if( d < d_closest ) {
	    d_closest = d;
	    t_closest = t;
	}
    }
    
    // Now make a starting interval between two t values
    CGFloat t1, t2;  // ends of the segment
    if( t_closest == 0 ) {
	t1 = 0;
	t2 = 0 + incr;
    }
    else if( t_closest > 1 ) {
	t1 = 1 - incr;
	t2 = 1;
    }
    else {
	// make the interval span the closest t-value
	t1 = t_closest - incr*.7f;
	t2 = t_closest + incr*.7f;
    }
    
    /*
     else {
     CGFloat t_less = t_closest - incr;
     CGFloat t_more = t_closest + incr;
     CGFloat d_less = distanceBetween(p, evaluateBezierPathAtT(p0, p1, p2, p3, t_less));
     CGFloat d_more = distanceBetween(p, evaluateBezierPathAtT(p0, p1, p2, p3, t_more));
     
     if( d_less < d_more )  t_closest_2 = t_less;
     else  t_closest_2 = t_more;
     }
     */
    
    // TESTING
    //[RSGraphRenderer drawCircleAt:evaluateBezierPathAtT(p0, p1, p2, p3, t1)];
    //[RSGraphRenderer drawCircleAt:evaluateBezierPathAtT(p0, p1, p2, p3, t2)];
    
    // Now recursively narrow down
    int recursions = 6;
    // initialize ends
    CGFloat d1 = distanceBetweenPoints(p, evaluateBezierPathAtT(p0, p1, p2, p3, t1));
    CGFloat d2 = distanceBetweenPoints(p, evaluateBezierPathAtT(p0, p1, p2, p3, t2));
    //
    CGFloat t_mid = 0;  // middle of the current segment
    CGFloat d_mid;  // distances to each t location
    int r;
    for(r = 0; r < recursions; r++) {
	t_mid = (t1 + t2)/2;
	d_mid = distanceBetweenPoints(p, evaluateBezierPathAtT(p0, p1, p2, p3, t_mid));
	// assume the middle is the closest; put it at the ends
	if( d1 <= d2 ) {
	    t2 = t_mid;
	    d2 = d_mid;
	} else {
	    t1 = t_mid;
	    d1 = d_mid;
	}
	// recurse...
    }
    
    // our best guess is t_mid:
    return t_mid;
}



#pragma mark -
@implementation RSHitTester

- (id)initWithEditor:(RSGraphEditor *)editor;
{
    if (!(self = [super init]))
        return nil;
    
    _nonretained_editor = editor;
    
    _hitLines = [[NSMutableArray alloc] initWithCapacity:2];
    _scale = 1;
    
    return self;
}

- (void)dealloc;
{
    [_hitLines release];
    
    [super dealloc];
}

@synthesize scale = _scale;


#pragma mark -
#pragma mark Fundamental hit-testing parameters
- (CGFloat)selectionSensitivity;
{
    CGFloat sensitivity = [[OFPreferenceWrapper sharedPreferenceWrapper] floatForKey:@"SelectionSensitivity"];
    return sensitivity/_scale;
}
- (CGFloat)snapToObjectSensitivity;
{
    CGFloat sensitivity = [[OFPreferenceWrapper sharedPreferenceWrapper] floatForKey:@"SnapToObjectSensitivity"];
    return sensitivity/_scale;
}
- (CGFloat)snapToGridSensitivity;
{
    float sensitivity = [[OFPreferenceWrapper sharedPreferenceWrapper] floatForKey:@"SnapToGridSensitivity"];
    return sensitivity/_scale;
}


////////////////////////////
#pragma mark -
#pragma mark Information about the most recent hit detection
////////////////////////////

- (NSArray *)linesThatWereHit;
{
    return _hitLines;
}


////////////////////////////
#pragma mark -
#pragma mark Helpers for expanding the selection beyond what was hit
////////////////////////////

- (RSGraphElement *)_expandVertexGroupToIncludeLine:(RSGraphElement *)GE;
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

- (RSGraphElement *)expand:(RSGraphElement *)GE toIncludeGroupingsAndElementsUnderPoint:(CGPoint)p;
{
    // Always stop if hit a bar end
    if ([GE isKindOfClass:[RSVertex class]] && [self hitTestPoint:p onBarEnd:(RSVertex *)GE]) {
        return GE;
    }
    
    if (GE) {
        GE = [GE elementWithGroup];
        GE = [self _expandVertexGroupToIncludeLine:GE];
        GE = [GE groupWithVertices];
        GE = [GE shake];
    }
    else {
        // if nothing was found to begin with, expand the hit-offset
        GE = [self elementsAlmostUnderPoint:p];
    }
    
    return GE;
}



//////////////////
#pragma mark -
#pragma mark Highest-level methods for object hit detection
//////////////////
#pragma mark p is in view coords

static NSInteger sortHitResultValues(NSValue *value1, NSValue *value2, void *context)
{
    RSHitResult hr1, hr2;
    [value1 getValue:&hr1];
    [value2 getValue:&hr2];
    
    // First check that hits actually happened.
    if (hr1.hit && !hr2.hit) {
        return NSOrderedAscending;
    }
    if (!hr1.hit && hr2.hit) {
        return NSOrderedDescending;
    }
    if (!hr1.hit && !hr2.hit) {
        return NSOrderedSame;
    }
    
    // If both were hit, order by distance
    CGFloat d1 = hr1.distance;
    CGFloat d2 = hr2.distance;
    if (d1 < d2)
        return NSOrderedAscending;
    if (d1 > d2)
        return NSOrderedDescending;
    return NSOrderedSame;
}

- (RSGraphElement *)elementUnderPoint:(CGPoint)p;
// Returns the "highest" element in the graph hit by the point p (in view coords)
// where the order of "height" is (from highest to lowest):
// Vertex, TextLabel, Line, Fill, xAxis, yAxis, BarVertex
{
    RSGraphElement *GE = nil;
    
#if !defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE
    // On the Mac, prioritize vertices over all else, including invisible vertices.
    RSHitResult vertexResult = [self vertexUnderPoint:p notIncluding:nil extraElement:nil hitOffset:[self selectionSensitivity] includeInvisible:YES includeBars:NO];
    if (vertexResult.hit) {
        return vertexResult.element;
    }
#else
    // On the iPad, everything is sorted and the closest wins
    RSHitResult vertexResult = [self vertexUnderPoint:p notIncluding:nil extraElement:nil hitOffset:[self selectionSensitivity] includeInvisible:NO includeBars:NO];
#endif
    
    RSHitResult lineResult = [self lineUnderPoint:p];
    RSHitResult labelResult = [self labelUnderPoint:p];
    RSHitResult axisResult = [self axisUnderPoint:p];
    
    NSMutableArray *resultArray = [NSMutableArray arrayWithCapacity:4];
    [resultArray addObject:[NSValue valueWithBytes:&vertexResult objCType:@encode(RSHitResult)]];
    [resultArray addObject:[NSValue valueWithBytes:&lineResult objCType:@encode(RSHitResult)]];
    [resultArray addObject:[NSValue valueWithBytes:&labelResult objCType:@encode(RSHitResult)]];
    [resultArray addObject:[NSValue valueWithBytes:&axisResult objCType:@encode(RSHitResult)]];
    
    [resultArray sortUsingFunction:sortHitResultValues context:NULL];
    
    NSValue *firstHitResultValue = [resultArray objectAtIndex:0];
    RSHitResult bestResult;
    [firstHitResultValue getValue:&bestResult];
    
    // If a best hit was found from the sortable objects...
    if (bestResult.hit) {
        GE = bestResult.element;
        
        if ([GE isKindOfClass:[RSAxis class]]) {
            if ([self originUnderPoint:p]) {
                GE = [[[RSGroup alloc] initWithGraph:_graph byCopyingArray:[NSArray arrayWithObjects:[_graph xAxis], [_graph yAxis], nil]] autorelease];
            }
        }
    }
    
    // If no results were found from the sortable object types...
    else {
        GE = [self fillUnderPoint:p];
        
        if (!GE) {
            GE = [self barVertexUnderPoint:p];
        }
    }
    
    return GE;
}

- (RSGraphElement *)elementUnderPoint:(CGPoint)p extraElement:(RSGraphElement *)extra;
// This is specifically for Fill and Draw modes.
{
    RSGraphElement *GE = nil;
    
    if ((GE = [self vertexUnderPoint:p notIncluding:nil extraElement:extra hitOffset:[self selectionSensitivity] includeInvisible:NO includeBars:NO].element))
	; // nothing
    else if ((GE = [self lineUnderPoint:p].element))
	; // nothing
    //    else if ((GE = [self labelUnderPoint:p]))
    //	; // nothing
    else if ((GE = [self axisUnderPoint:p].element))
	; // nothing
    else  // if nothing was found
	return nil;
    
    // if found something...
    return GE;
}

- (RSGraphElement *)elementUnderPoint:(CGPoint)p fromSelection:(RSGraphElement *)selection;
{
    // Check vertices first
    for (RSGraphElement *GE in [selection elements]) {
        if ([GE isKindOfClass:[RSVertex class]]) {
            if ([self hitTestPoint:p onVertex:(RSVertex *)GE].hit)
                return GE;
        }
    }
    
    // Check the rest of the selection
    for (RSGraphElement *GE in [selection elements]) {
        if ([GE isKindOfClass:[RSLine class]]) {
            if ([self hitTestPoint:p onLine:(RSLine *)GE].hit)
                return GE;
        }
        else if ([GE isKindOfClass:[RSFill class]]) {
            if ([self hitTestPoint:p onFill:(RSFill *)GE])
                return GE;
        }
        else if ([GE isKindOfClass:[RSTextLabel class]]) {
            if ([self hitTestPoint:p onLabel:(RSTextLabel *)GE].hit)
                return GE;
        }
    }
    
    // If hit nothing in the selection, try the rest of the graph.
    return [self elementUnderPoint:p];
}

- (RSGraphElement *)elementsAlmostUnderPoint:(CGPoint)p
{
    RSGraphElement *GE = nil;
    
    if ((GE = [self labelAlmostUnderPoint:p])) {
        GE = [[_graph elementsConnectedTo:GE] elementWithClass:[GE class]];
    }
    //    else if ((GE = [self vertexAlmostUnderPoint:p notIncluding:nil])) {
    //        GE = [GE elementWithGroup];
    //    }
    
    return GE;
}

///////////////////
#pragma mark -
#pragma mark Higher-level methods for object hit detection
///////////////////

- (RSHitResult)vertexUnderPoint:(CGPoint)p
{
    return [self vertexUnderPoint:(CGPoint)p notIncluding:nil];
}
- (RSHitResult)vertexUnderPoint:(CGPoint)p notIncluding:(RSVertex *)vNot
{
    NSArray *clusterNot = nil;
    if (vNot) {
        // get vNot's cluster
        if (vNot) {
            clusterNot = [vNot vertexCluster];
        }
    }
    
    return [self vertexUnderPoint:p notIncluding:clusterNot extraElement:nil hitOffset:[self selectionSensitivity] includeInvisible:NO includeBars:YES];
}
- (RSHitResult)vertexUnderPoint:(CGPoint)p
                   notIncluding:(NSArray *)vNots
                   extraElement:(RSGraphElement *)extra 
                      hitOffset:(CGFloat)hitOffset
               includeInvisible:(BOOL)includeInvisible
                    includeBars:(BOOL)includeBars
{
    // get all the vertices under consideration
    NSArray *A = [_graph Vertices];
    if( extra ) {
	if( [extra isKindOfClass:[RSFill class]] ) {
	    A = [A arrayByAddingObjectsFromArray:[[(RSFill *)extra vertices] elements]];
	}
	else if( [extra isKindOfClass:[RSLine class]] ) {
	    A = [A arrayByAddingObjectsFromArray:[[(RSLine *)extra vertices] elements]];
	}
    }
    
    // make sure there is at least *something* there
    if ( [A count] == 0 )  return RSHitResultNo;
    
    RSHitResult bestHit = {nil, CGFLOAT_MAX, NO};
    RSHitResult barResult = RSHitResultNo;
    
    // enumerate through all the vertices
    for (RSVertex *V in [A reverseObjectEnumerator])
    {
        if ( !includeInvisible && [V shape] == RS_NONE )  continue;
        if ( [V isBar] && (!includeBars || barResult.hit) )  continue;
        if ( vNots && [vNots containsObjectIdenticalTo:V] )  continue;
        
        RSHitResult hitResult = [self hitTestPoint:p onVertex:V hitOffset:hitOffset];
        
        if (hitResult.hit) {
            if ([V isBar]) {
                barResult = hitResult;
                continue;
            }
            
            // else, a regular vertex
            if (hitResult.distance < bestHit.distance) {
                bestHit = hitResult;
            }
        }
    }
    
    if (bestHit.hit) {
        return bestHit;
    }
    return barResult;
}

- (RSVertex *)barVertexUnderPoint:(CGPoint)p;
{
    for (RSVertex *V in [[_graph Vertices] reverseObjectEnumerator]) {
        if (![V isBar])
            continue;
        
        RSHitResult hitResult = [self hitTestPoint:p onVertex:V];
        if (hitResult.hit) {
            return V;
        }
    }
    
    return nil;
}

- (RSVertex *)vertexAlmostUnderPoint:(CGPoint)p notIncluding:(RSVertex *)vNot
// p is in view coords
// vNot can be nil
{
    CGFloat offset = [self selectionSensitivity] * 2;
    
    NSEnumerator *E;
    RSVertex *V;
    
    E = [[_graph Vertices] reverseObjectEnumerator];
    while ((V = [E nextObject]))
    {
	if ( [V group] && [self hitTestPoint:p onVertex:V hitOffset:offset].hit && (V != vNot) )  return V;
    }
    // if got this far...
    return nil;
}


- (RSHitResult)labelUnderPoint:(CGPoint)p;
// p is in view coords
{
    // First check for regular, user-created labels:
    for (RSTextLabel *TL in [[_graph Labels] reverseObjectEnumerator]) {
        if (![_graph shouldDisplayLabel:TL])
            continue;
        
        RSHitResult hitResult = [self hitTestPoint:p onLabel:TL];
        if (hitResult.hit)
            return hitResult;
    }
    
    // Now check for axis labels:
    for (RSTextLabel *TL in [_renderer visibleAxisLabels]) {
        RSHitResult hitResult = [self hitTestPoint:p onLabel:TL];
        if (hitResult.hit)
            return hitResult;
    }
    
    // if got this far...
    return RSHitResultNo;
}

- (RSTextLabel *)labelAlmostUnderPoint:(CGPoint)p;
// This currently only looks at axis tick labels
{
    CGFloat offset = [self selectionSensitivity] * 2;
    
    for (RSTextLabel *TL in [_renderer visibleAxisLabels]) {
        if ([self hitTestPoint:p onLabel:TL offset:offset].hit)
            return TL;
    }
    return nil;
}

- (RSHitResult)lineUnderPoint:(CGPoint)p
// alias for [lineUnderPoint: notIncluding:nil]
{
    return [self lineUnderPoint:(CGPoint)p notIncluding:nil];
}
- (RSHitResult)lineUnderPoint:(CGPoint)p notIncluding:(NSArray *)LNots 
// p is in view coords
// lNot can be nil; that means include all
{
    // make sure the cache exists
    [self linesThatWereHit];
    // clear the cache
    [_hitLines removeAllObjects];
    // record the new hit point
    _hitPoint = p;
    
    RSHitResult bestHit = {nil, CGFLOAT_MAX, NO};
    
    for (RSLine *L in [[_graph userLineElements] reverseObjectEnumerator])
    {
        if (LNots && [LNots indexOfObjectIdenticalTo:L] != NSNotFound)
            continue;
        
        RSHitResult hitResult = [self hitTestPoint:p onLine:L];
        if (hitResult.hit) {
            if (hitResult.distance < bestHit.distance) {
                bestHit = hitResult;
            }
            
            [_hitLines addObject:L];
        }
    }
    
    return bestHit;
}

- (RSFill *)fillUnderPoint:(CGPoint)p
// p is in view coords
{
    NSEnumerator *E;
    RSFill *F;
    
    E = [[_graph Fills] reverseObjectEnumerator];
    while ((F = [E nextObject]))
    {
	if ( [self hitTestPoint:p onFill:F] ) return F;
    }
    // if got this far...
    return nil;
}

//- (RSLine *)curvePointUnderPoint:(CGPoint)p forElement:(RSGraphElement *)GE {
//    // view coords!
//    RSLine *L;
//    
//    if( (L = [RSGraph isLine:GE]) ) {
//	if( [L hasCurvePoint] ) {
//	    if( [self hitTestPoint:p onCurvePointForLine:L] )  return L;
//	}
//    }
//    else if( [GE isKindOfClass:[RSGroup class]] ) {
//	for (RSLine *next in [(RSGroup *)GE elementsWithClass:[RSLine class]])
//	{
//	    L = [self curvePointUnderPoint:p forElement:next];
//	    if( L )  return L;
//	}
//    }
//    // if got this far
//    return nil;  // meaning "no curve point found"
//}


// This returns an CGRect because we really just want two points
// everything is in view coords
- (RSTwoPoints)psuedoTangentNear:(CGPoint)p onLine:(RSLine *)L {
    RSTwoPoints ends;
    
    if( ![L isCurved] ) {  // straight
	// we can just use the line endpoints for the tangent line
	ends.p1 = [_mapper convertToViewCoords:[L startPoint]];
	ends.p2 = [_mapper convertToViewCoords:[L endPoint]];
    }
    else {  // curved
	// get closest point on the curve
	CGFloat t = [self timeOfClosestPointTo:p onLine:L];
        CGFloat length = [_mapper viewLengthOfLine:L];
        
        CGFloat tOffset = 0.01f;
        if (length > 2.0) {
            tOffset = 2 / length;  // about 2 pixels
        }
	
	// form the psuedo-tangent with t-values around the closest t
	ends = [_mapper lineTangentToLine:L atTime:t useDelta:tOffset];
    }
    
    return ends;
}


// p is in VIEW coords (for perfect comparison with cache), and so is the return value
// uses the current _hitLines cache to get the lines
- (CGPoint)intersectionUnderPoint:(CGPoint)p saveT1:(CGFloat *)tp1 andT2:(CGFloat *)tp2;
{
    // error checking
    if( [_hitLines count] < 2 ) {
	NSLog(@"Error: not enough hitLines");
	return p;
    }
    // otherwise, continue...
    RSLine *L1 = [_hitLines objectAtIndex:0];
    RSLine *L2 = [_hitLines objectAtIndex:1];
    
    return [self intersectionNearPoint:p betweenLine:L1 andLine:L2 saveT1:tp1 andT2:tp2];
}

// p is in VIEW coords (for perfect comparison with cache), and so is the return value
- (CGPoint)intersectionNearPoint:(CGPoint)p betweenLine:(RSLine *)L1 andLine:(RSLine *)L2 saveT1:(CGFloat *)tp1 andT2:(CGFloat *)tp2;
{
    CGPoint i;  // the intersection
    NSUInteger maxIterations = 2;
    
    CGFloat maxDistance = [self selectionSensitivity] * 3;
    
    // if both are straight
    if( ![L1 isCurved] && ![L2 isCurved] ) {
	// just use the standard intersection test
	CGPoint start1 = [_mapper convertToViewCoords:[L1 startPoint]];
	CGPoint end1 = [_mapper convertToViewCoords:[L1 endPoint]];
	CGPoint start2 = [_mapper convertToViewCoords:[L2 startPoint]];
	CGPoint end2 = [_mapper convertToViewCoords:[L2 endPoint]];
	i = lineIntersection(start1, end1, start2, end2);
    }
    
    // if one or more are curved
    else {
        
	i = p;
	
	for (NSUInteger count = 0; count < maxIterations; count++) {
	    // construct psuedo-tangents near p on each line
	    RSTwoPoints tangent1 = [self psuedoTangentNear:i onLine:L1];
	    RSTwoPoints tangent2 = [self psuedoTangentNear:i onLine:L2];
	    
	    // find the intersection of the psuedo-tangents
	    i = lineIntersection(tangent1.p1, tangent1.p2, tangent2.p1, tangent2.p2);
	    
	    if( distanceBetweenPoints(i, p) > maxDistance * 2 ) {
		// the lines probably don't actually intersect
		return p;
	    }
	}
    }
    
    if( distanceBetweenPoints(i, p) > maxDistance ) {
	// the lines probably don't actually intersect
	return p;
    }
    
    // compute the t-value for each line
    if( tp1 && tp2 ) {
	*tp1 = [self timeOfClosestPointTo:i onLine:L1];
	*tp2 = [self timeOfClosestPointTo:i onLine:L2];
    }
    
    // else... return the intersection found
    return i;
}

// p is in VIEW coords (for perfect comparison with cache), and so is the return value
- (CGPoint)intersectionNearPoint:(CGPoint)p withLine:(RSLine *)L andConstraints:(NSDictionary *)constraints saveT:(CGFloat *)tp;
// Currently supports intersections between a line and a vertical or horizontal snap-constraint (e.g. grid lines).  If both a vertical and horizontal constraint are supplied, the vertical (x) takes precedence.
{
    // Choose which constraint should apply
    NSString *constraintKey = nil;
    if ([constraints objectForKey:RSSnapConstraintXKey]) {
        // In the special case of snapping to a vertical line, the horizontal constraint (if any) should take precedence.
        if ([L isVertical] && [constraints objectForKey:RSSnapConstraintYKey]) {
            constraintKey = RSSnapConstraintYKey;
        }
        else {
            constraintKey = RSSnapConstraintXKey;
        }
    }
    else if ([constraints objectForKey:RSSnapConstraintYKey]) {
        constraintKey = RSSnapConstraintYKey;
    }
    else {
        return p;  // no valid constraints found
    }
    
    // Make a line equivalent for the vertical or horizontal constraint
    CGPoint start2, end2;
    CGRect bounds = [_mapper bounds];
    NSNumber *val = [constraints objectForKey:constraintKey];
    OBASSERT(val);
    if ([constraintKey isEqualToString:RSSnapConstraintXKey]) {
        RSDataPoint d = RSDataPointMake([val doubleValue], 0);
        start2.x = end2.x = [_mapper convertToViewCoords:d].x;
        start2.y = CGRectGetMinY(bounds);
        end2.y = CGRectGetMaxY(bounds);
    }
    else if ([constraintKey isEqualToString:RSSnapConstraintYKey]) {
        RSDataPoint d = RSDataPointMake(0, [val doubleValue]);
        start2.y = end2.y = [_mapper convertToViewCoords:d].y;
        start2.x = CGRectGetMinX(bounds);
        end2.x = CGRectGetMaxX(bounds);
    }
    else {
        NSLog(@"This should never happen, in RSHitTester's -intersectionNearPoint:withLine:andConstraints:saveT:");
        return p;
    }

    
    CGFloat maxDistance = [self selectionSensitivity] * 3;
    CGPoint i;  // the intersection
    
    // If the line is straight
    if( ![L isCurved] ) {
	// just use the standard intersection test
	CGPoint start1 = [_mapper convertToViewCoords:[L startPoint]];
	CGPoint end1 = [_mapper convertToViewCoords:[L endPoint]];
	i = lineIntersection(start1, end1, start2, end2);
    }
    
    // If the line is curved (or has multiple segments)
    else {
        
        NSUInteger maxIterations = 2;
        i = p;
        
        for (NSUInteger count = 0; count < maxIterations; count++) {
            // construct psuedo-tangent near p
            RSTwoPoints tangent1 = [self psuedoTangentNear:i onLine:L];
            
            // find the intersection of the psuedo-tangent with the constraint line
            i = lineIntersection(tangent1.p1, tangent1.p2, start2, end2);
            
            if( distanceBetweenPoints(i, p) > maxDistance * 2 ) {
                // the lines probably don't actually intersect
                return p;
            }
        }
    }
    
    if( distanceBetweenPoints(i, p) > maxDistance ) {
	// the lines probably don't actually intersect
	return p;
    }
    
    // else... return the intersection found
    if( tp ) {
        // compute the t-value for the real line
	*tp = [self timeOfClosestPointTo:i onLine:L];
    }
    return i;
}


- (BOOL)updateIntersection:(CGPoint *)ip betweenLine:(RSLine *)L1 atTime:(CGFloat *)tp1 andLine:(RSLine *)L2 atTime:(CGFloat *)tp2;
{
    NSUInteger maxIterations = 5;
    CGFloat jumpDistance = 400;
    CGFloat hitIncr = jumpDistance/maxIterations;
    
    CGPoint i = *ip;
    CGPoint prevI;
    CGFloat t1 = *tp1;
    CGFloat t2 = *tp2;
    
    for (NSUInteger count = 0; count < maxIterations; count++) {
	CGFloat delta = 0.04f/((CGFloat)count + 1);
	CGFloat currentMaxDistance = jumpDistance/(count + 1);
	
	// construct psuedo-tangents near p on each line
	RSTwoPoints tangent1 = [_mapper lineTangentToLine:L1 atTime:t1 useDelta:delta];
	RSTwoPoints tangent2 = [_mapper lineTangentToLine:L2 atTime:t2 useDelta:delta];
	
	// find the intersection of the psuedo-tangents
	prevI = i;
	i = lineIntersection(tangent1.p1, tangent1.p2, tangent2.p1, tangent2.p2);
	
	// if both lines are straight, we're done
	if ( ![L1 isCurved] && ![L2 isCurved] ) {
	    t1 = [self timeOfClosestPointTo:i onLine:L1];
	    t2 = [self timeOfClosestPointTo:i onLine:L2];
	    break;
	}
	
	if( distanceBetweenPoints(i, *ip) > currentMaxDistance ) {
	    // the lines probably don't actually intersect
	    return NO;
	}
	
	// We don't need to iterate further if the last iteration adjusted the intersection point less than 1/10 pixel.
	if (distanceBetweenPoints(prevI, i) < 0.1) {
	    //DEBUG_RS(@"finished on iteration: %d", count + 1);
	    break;
	}
	
	// Don't re-calculate t-values again if we're not going to repeat the loop.
	if (count >= maxIterations) {
	    DEBUG_RS(@"Reached max # of iterations");
	    break;
	}
	
	
	//
	// update t-values
	//
	NSUInteger hitSegment = 0;
	BOOL wasHit = NO;
	CGFloat hitOffset = 6;
	while (hitOffset <= currentMaxDistance) {
            wasHit = [self hitTestPoint:i onLine:L1 hitSegment:&hitSegment hitOffset:hitOffset].hit;
            if (wasHit) {
                break;
            }
	    hitOffset += hitIncr;
	}
	if (!wasHit) {
	    return NO;
	}
	// else
	t1 = [self timeOfClosestPointTo:i onLine:L1 hitSegment:hitSegment];
	
	wasHit = NO;
	hitOffset = 6;
	while (hitOffset <= currentMaxDistance) {
            wasHit = [self hitTestPoint:i onLine:L2 hitSegment:&hitSegment hitOffset:hitOffset].hit;
            if (wasHit) {
                break;
            }
	    hitOffset += hitIncr;
	}
	if (!wasHit) {
	    return NO;
	}
	// else
	t2 = [self timeOfClosestPointTo:i onLine:L2 hitSegment:hitSegment];
    }
    
    //
    // update parameters
    *ip = i;
    *tp1 = t1;
    *tp2 = t2;
    return YES;
}



- (RSHitResult)axisUnderPoint:(CGPoint)p;
// p is in view coords
{
    RSHitResult hitResult;
    
    hitResult = [self hitTestPoint:p onAxis:[_graph xAxis]];
    if (hitResult.hit) {
        return hitResult;
    }
    hitResult = [self hitTestPoint: p onAxis:[_graph yAxis]];
    return hitResult;
}

- (BOOL)originUnderPoint:(CGPoint)p;
{
    return [self hitTestPoint:p onAxis:[_graph xAxis]].hit && [self hitTestPoint:p onAxis:[_graph yAxis]].hit;
}

- (RSAxisEnd)axisEndUnderPoint:(CGPoint)p;
{
    RSAxisEnd axisEnd = [self hitTestPoint:p onEndsOfAxis:[_graph xAxis]];
    if (axisEnd != RSAxisEndNone)
        return axisEnd;
    
    axisEnd = [self hitTestPoint:p onEndsOfAxis:[_graph yAxis]];
    return axisEnd;
}

- (NSUInteger)marginGuideUnderPoint:(CGPoint)p;
// p is in view coords
{
    CGPoint mins = [_mapper viewMins];
    CGPoint maxes = [_mapper viewMaxes];
    CGFloat hitOffset = [self selectionSensitivity];
    if (p.x > mins.x - hitOffset && p.x < mins.x + hitOffset)
	return RSBORDER_LEFT;
    if (p.x > maxes.x - hitOffset && p.x < maxes.x + hitOffset)
	return RSBORDER_RIGHT;
    if (p.y > mins.y - hitOffset && p.y < mins.y + hitOffset)
	return RSBORDER_BOTTOM;
    if (p.y > maxes.y - hitOffset && p.y < maxes.y + hitOffset)
	return RSBORDER_TOP;
    
    return 0;  // if none were hit
}



///////////////////
#pragma mark -
#pragma mark Low level hitTest methods
///////////////////

//- (BOOL)hitTestPoint:(CGPoint)testPoint onPoint:(CGPoint)fixedPoint
//// testPoint is in view coords
//{
//    CGFloat _hitOffset = [self selectionSensitivity];
//    if( [ViewUtil distanceBetweenPoint:testPoint andPoint:fixedPoint] < (_hitOffset*2) )
//	return YES;
//    else  return NO;
//}


//- (BOOL)hitTestPoint:(CGPoint)testPoint onLine:(RSLine *)testLine 
//// Delegate out depending on whether it is straight or curved
//{
//    if( [testLine isKindOfClass:[RSConnectLine class]] ) {
//	return [self hitTestPoint:testPoint onConnectLine:(RSConnectLine *)testLine];
//    }
//    else {
//	// must be straight
//	return [self hitTestPoint:testPoint onStraightLine:testLine];
//    }
//    
//}


//- (BOOL)hitTestPoint:(CGPoint)testPoint onStraightLine:(RSLine *)testLine
//// I had to write this custom method, because [NSBezierPath containsPoint:]
//// only works for closed shapes, not lines.
//// Another method would be to create a rectangular bezier path in the position of
//// the line.  This seems like a waste of resources, creating a new bezier path
//// all the time.  Besides, I can do math!
//// An example of another custom hit detection method (that I did NOT refer to
//// when designing this method) is in the Sketch project,
//// in SKTLine.m, called hitTest: .
//{
//    // The following algorithm is based on the intersection point between the test line 
//    // and a line that goes through the test point at right angles to the test line.
//    // To pass the test, the intersection point must be within the line's endpoints
//    // and the distance between the test point and the intersection point must be
//    // within the allowed hit width of the line.
//    
//    OBASSERT([[testLine vertices] count] == 2);
//    
//    CGPoint p, q, t;//, r, min, max;	// start, end, test, intersection, min corner, max corner
//    //CGFloat m, m2;	// slope of line, slope of perpendicular line
//    CGFloat w;	// allowed perpendicular distance from line
//    //CGFloat d;	// actual perpendicular distance of test point from line
//    //CGFloat a, b; // intermediate variables
//    //BOOL isVertical = NO;
//    //BOOL isHorizontal = NO;
//    
//    CGFloat _hitOffset = [self selectionSensitivity];
//    
//    // initialize known values:
//    p = [_mapper convertToViewCoords:[testLine startPoint]];
//    q = [_mapper convertToViewCoords:[testLine endPoint]];
//    t = testPoint;
//    w = ([testLine width] / 2) + _hitOffset;
//    
//    return [self hitTestPoint:t onLineFrom:p to:q width:w];
//}


- (RSHitResult)hitTestPoint:(CGPoint)point onLineFrom:(CGPoint)startPoint to:(CGPoint)endPoint width:(CGFloat)tolerance;
// I stole this from OmniAppKit's NSBezierPath-OAExtensions.m -[_straightLineHit: : : : :]
{
    CGPoint delta;
    CGPoint vector;
    CGPoint linePoint;
    CGFloat length;
    CGFloat dotProduct;
    CGFloat distance;
    
    delta.x = endPoint.x - startPoint.x;
    delta.y = endPoint.y - startPoint.y;
    length = sqrt(delta.x * delta.x + delta.y * delta.y);
    delta.x /=length;
    delta.y /=length;
    
    vector.x = point.x - startPoint.x;
    vector.y = point.y - startPoint.y;
    
    dotProduct = vector.x * delta.x + vector.y * delta.y;
    
    linePoint.x = startPoint.x + delta.x * dotProduct;
    linePoint.y = startPoint.y + delta.y * dotProduct;
    
    delta.x = point.x - linePoint.x;
    delta.y = point.y - linePoint.y;
    
    // really the distance squared
    distance = delta.x * delta.x + delta.y * delta.y;
    
    if (distance < (tolerance * tolerance)) {
        CGFloat position = dotProduct/length;
        if (position >= 0 && position <=1) {
            return RSHitResultMake(nil, sqrt(distance), YES);
        }
    }
    
    return RSHitResultNo;
}

//- (BOOL)hitTestPoint:(CGPoint)test onLineFrom:(CGPoint)start to:(CGPoint)end width:(CGFloat)w 
//// EVERYTHING IS IN VIEW COORDS
////
//// I had to write this custom method, because [NSBezierPath containsPoint:]
//// only works for closed shapes, not lines.
//// Another method would be to create a rectangular bezier path in the position of
//// the line.  This seems like a waste of resources, creating a new bezier path
//// all the time.  Besides, I can do math!
//// An example of another custom hit detection method (that I did NOT refer to
//// when designing this method) is in the Sketch project,
//// in SKTLine.m, called hitTest: .
//{
//    // The following algorithm is based on the intersection point between the test line 
//    // and a line that goes through the test point at right angles to the test line.
//    // To pass the test, the intersection point must be within the line's endpoints
//    // and the distance between the test point and the intersection point must be
//    // within the allowed hit width of the line.
//    
//    CGPoint p, q, t, r, min, max;	// start, end, test, intersection, min corner, max corner
//    CGFloat m, m2;	// slope of line, slope of perpendicular line
//    //CGFloat w;	// allowed perpendicular distance from line
//    CGFloat d;	// actual perpendicular distance of test point from line
//    CGFloat a, b; // intermediate variables
//    BOOL isVertical = NO;
//    BOOL isHorizontal = NO;
//    
//    // initialize known values:
//    p = start;
//    q = end;
//    t = test;
//    //w = ([testLine width] / 2) + _hitOffset;
//    // calculate slopes:
//    if ( nearlyEqualFloats(q.x, p.x) ) {
//	isVertical = YES;
//	m = 1000;
//    } else {
//	m = (q.y - p.y) / (q.x - p.x);
//	DEBUG_RS(@"m: %f", m);
//    }
//    if ( nearlyEqualFloats(q.y, p.y) ) {
//	isHorizontal = YES;
//	m2 = 1000;
//    } else {
//	m2 = (p.x - q.x) / (q.y - p.y);   // (perpendicular -1/m)
//    }
//    // calculate intersection point:
//    r.x = (t.y - p.y + m*p.x - m2*t.x) / (m - m2);
//    r.y = m*(r.x - p.x) + p.y;
//    
//    // TESTING ONLY:
//    //[_intersectionVertex setPosition:[_mapper convertToDataCoords:r]];
//    //[self setNeedsDisplay:YES];
//    
//    // determine max and min corners:
//    if ( p.x > q.x ) {
//	min.x = q.x;
//	max.x = p.x;
//    } else {
//	min.x = p.x;
//	max.x = q.x;
//    }
//    if ( p.y > q.y ) {
//	min.y = q.y;
//	max.y = p.y;
//    } else {
//	min.y = p.y;
//	max.y = q.y;
//    }
//    // make sure intersection is not outside extremal corners:
//    if ( (!isVertical && r.x > max.x) || (!isVertical && r.x < min.x) 
//	|| (!isHorizontal && r.y > max.y) || (!isHorizontal && r.y < min.y) ) {
//	return NO;
//    }
//    // calculate distance from test point to intersection point:
//    a = t.x - r.x;
//    b = t.y - r.y;
//    d = sqrt(a*a + b*b);
//    // test if close enough to line:
//    if ( d > w ) return NO;
//    else return YES;	// passed all the tests!
//}

//- (BOOL)hitTestPoint:(CGPoint)testPoint onCurvedLine:(RSLine *)testLine {
//    // The parametric formula for a Bezier curve based on four points is (graphics p. 611):
//    // P(t) = P_0(1 - t)^3 + P_1*3(1 - t)^2*t + P_2*3(1 - t)*t^2 + P_3*t^3
//    // 
//    // where P_0 and P_3 are endpoints and P_1 and P_2 are control points
//    //
//    // To hit-test curved lines, I approximate them as a series of straight line segments.
//    
//    CGPoint p1, p2;  // curve control points
//    CGPoint p0, p3;  // start and end of line
//    //CGPoint c;       // curve point
//    //CGPoint r1, r2;  // rays from endpoints through curve point
//    //CGFloat extra;
//    CGPoint s1, s2;  // straight segment endpoints
//    CGFloat width;
//    CGFloat t;
//    CGFloat incr = 0.1;
//    
//    CGFloat _hitOffset = [self selectionSensitivity];
//    
//    // get width from line
//    width = ([testLine width] / 2) + _hitOffset;
//    
//    // calculate control points:
//    p0 = [testLine startPoint];
//    p3 = [testLine endPoint];
//    
//    /*
//     c = [testLine curvePoint];
//     extra = 1.3333;  // (4/3)
//     
//     r1.x = (c.x - p0.x)*extra;
//     r1.y = (c.y - p0.y)*extra;
//     r2.x = (c.x - p3.x)*extra;
//     r2.y = (c.y - p3.y)*extra;
//     
//     p1.x = p3.x + r2.x;
//     p1.y = p3.y + r2.y;
//     p2.x = p0.x + r1.x;
//     p2.y = p0.y + r1.y;
//     */
//    p1 = [testLine controlPoint1];
//    p2 = [testLine controlPoint2];
//    
//    for( t=0; t<1; t+=incr ) {
//	
//	s1 = evaluateBezierPathAtT(p0, p1, p2, p3, t);
//	s2 = evaluateBezierPathAtT(p0, p1, p2, p3, t+incr);
//	
//	// hit-test this straight line segment
//	if( [self hitTestPoint:testPoint 
//		    onLineFrom:[_mapper convertToViewCoords:s1] 
//			    to:[_mapper convertToViewCoords:s2] 
//			 width:width] ) {
//	    return YES;
//	}
//    }
//    
//    // if got this far
//    return NO;
//    
//}


- (RSHitResult)hitTestPoint:(CGPoint)testPoint onLine:(RSLine *)testLine;
{
    return [self hitTestPoint:testPoint onLine:testLine hitSegment:NULL];
}

- (RSHitResult)hitTestPoint:(CGPoint)testPoint onLine:(RSLine *)testLine hitSegment:(NSUInteger *)hitSegment;
{
    CGFloat hitOffset = [self selectionSensitivity];
    
    return [self hitTestPoint:testPoint onLine:testLine hitSegment:hitSegment hitOffset:hitOffset];
}

- (RSHitResult)hitTestPoint:(CGPoint)testPoint onLine:(RSLine *)testLine hitSegment:(NSUInteger *)hitSegment hitOffset:(CGFloat)hitOffset;
{
    NSArray *VArray = [[testLine vertices] elements];
    
    // get width from line and specified offset
    CGFloat width = ([testLine width] / 2) + hitOffset;
    
    // if the line has one or fewer points, it cannot be hit
    if( [testLine vertexCount] < 2 ) {
	return RSHitResultNo;
    }
    
    else if ([testLine isKindOfClass:[RSEquationLine class]]) {
        RSEquationLine *EL = (RSEquationLine *)testLine;
        
        CGFloat start = [_mapper convertToViewCoords:[[testLine startVertex] position].x inDimension:RS_ORIENTATION_HORIZONTAL];
        CGFloat end = [_mapper convertToViewCoords:[[testLine endVertex] position].x inDimension:RS_ORIENTATION_HORIZONTAL];
        CGFloat step = 5.0f;  // pixels
        
        BOOL firstPass = YES;
        CGPoint prev;
        for (CGFloat viewX = start; viewX <= end; viewX += step) {
            data_p dataX = [_mapper convertToDataCoords:viewX inDimension:RS_ORIENTATION_HORIZONTAL];
            data_p dataY = [EL yValueForXValue:dataX];
            CGFloat viewY = [_mapper convertToViewCoords:dataY inDimension:RS_ORIENTATION_VERTICAL];
            
            CGPoint p = CGPointMake(viewX, viewY);
            
            if (firstPass) {
                firstPass = NO;
                prev = p;
                continue;
            }
            
            RSHitResult hitResult = [self hitTestPoint:testPoint onLineFrom:prev to:p width:width];
            if (hitResult.hit) {
                return RSHitResultMake(testLine, hitResult.distance, hitResult.hit);
            }
            
            prev = p;
        }
        
        // if got this far...
        return RSHitResultNo;
    }
    
    // if the line has only two points, it's straight;
    // the curved hit test doesn't work quite right in this case, so I treat it specially here.
    else if( ![testLine isCurved] ) {
	
	// initialize known values:
	CGPoint p = [_mapper convertToViewCoords:[testLine startPoint]];
	CGPoint q = [_mapper convertToViewCoords:[testLine endPoint]];
	CGPoint t = testPoint;
	CGFloat w = ([testLine width] / 2) + hitOffset;
	
	if (hitSegment) {
	    *hitSegment = 0;
	}
	RSHitResult hitResult = [self hitTestPoint:t onLineFrom:p to:q width:w];
        if (hitResult.hit) {
            return RSHitResultMake(testLine, hitResult.distance, hitResult.hit);
        }
        return RSHitResultNo;
    }
    
    // else, the line has more than 2 data points
    
    // if straight connections
    if( [testLine connectMethod] == RSConnectStraight ) {
	NSEnumerator *E = [VArray objectEnumerator];
	RSVertex *V;
	RSVertex *Vprev = [E nextObject];
	while ((V = [E nextObject])) {
            RSHitResult hitResult = [self hitTestPoint:testPoint 
			onLineFrom:[_mapper convertToViewCoords:[Vprev position]] 
				to:[_mapper convertToViewCoords:[V position]] 
                                                 width:width];
            if (hitResult.hit) {
		//return [VArray indexOfObjectIdenticalTo:V];  // a hit!
		if (hitSegment) {
		    *hitSegment = [VArray indexOfObjectIdenticalTo:Vprev];
		}
                return RSHitResultMake(testLine, hitResult.distance, hitResult.hit);
	    }
	    Vprev = V;
	}
	// if got this far...
	return RSHitResultNo;
    }
    
    // if curved connections
    else if( [testLine connectMethod] == RSConnectCurved ) {
	NSInteger n = [VArray count] - 1;
	CGPoint segs[n + 1][3];
	
	// compute the curve segments
	[_mapper bezierSegmentsFromVertexArray:VArray putInto:segs];
	
	//
	// hit-test each curve segment
	CGFloat incr = 0.1f;
	
	// loop through each curve segment
	for( int i=0; i<n; i++ ) {
	    CGPoint p0 = segs[i][0];  // control points making up each segment
	    CGPoint p1 = segs[i][1];
	    CGPoint p2 = segs[i][2];
	    CGPoint p3 = segs[i+1][0];
	    
	    // loop through approximating straight lines
	    for( CGFloat t=0; t<1; t+=incr ) {
                
		// straight line approximation endpoints:
		CGPoint s1 = evaluateBezierPathAtT(p0, p1, p2, p3, t);
		CGPoint s2 = evaluateBezierPathAtT(p0, p1, p2, p3, t+incr);
		
		// hit-test this straight line segment
                RSHitResult hitResult = [self hitTestPoint:testPoint 
			    onLineFrom:s1//[_mapper convertToViewCoords:s1] 
				    to:s2//[_mapper convertToViewCoords:s2] 
                                         width:width];
                if (hitResult.hit) {
		    //return i + 1;  // to make sure it's > 0
		    if (hitSegment) {
			*hitSegment = i;
		    }
		    return RSHitResultMake(testLine, hitResult.distance, hitResult.hit);
		}
	    }
	}
	
	// if got this far
	return RSHitResultNo;
    }
    
    // if the connection type is not specified, we'll have to assume hit testing fails
    else  return RSHitResultNo;
}


//- (BOOL)hitTestPoint:(CGPoint)testPoint onCurvePointForLine:(RSLine *)testLine 
//// testPoint is in view coords
//{
//    NSBezierPath *P;
//    CGPoint cp = [_mapper convertToViewCoords:[testLine curvePoint]];
//    CGFloat _hitOffset = [self selectionSensitivity];
//    
//    CGFloat w = [testLine width]*3 + (_hitOffset*2); // width
//    // but width of curve point hit area is smaller if the line is tiny
//    CGFloat len = [_mapper viewLengthOfLine:testLine];
//    CGFloat shrink_factor = 0.25;
//    if( len*shrink_factor < w ) {
//	w = len*shrink_factor;  // leaving most of the line for dragging around
//    }
//    
//    P = [NSBezierPath bezierPathWithOvalInRect:CGRectMake(cp.x - w*0.5, cp.y - w*0.5, w, w)];
//    
//    if ( [P containsPoint:testPoint] )  return YES;
//    else  return NO;
//}

- (RSHitResult)hitTestPoint:(CGPoint)testPoint onVertex:(RSVertex *)V 
// testPoint is in view coords
{
    CGFloat hitOffset = [self selectionSensitivity];
    
    return [self hitTestPoint:testPoint onVertex:V hitOffset:hitOffset];
}
- (RSHitResult)hitTestPoint:(CGPoint)testPoint onVertex:(RSVertex *)V hitOffset:(CGFloat)hitOffset;
// testPoint is in view coords
{
    CGFloat w;
    if( [RSGraph vertexHasShape:V] )
        w = [V width]*2 + hitOffset;
    else
        w = [V width]/2 + hitOffset;
    
    NSBezierPath *P;
    CGPoint p = [_mapper convertToViewCoords:[V position]];
    
    // Special case for bar-chart shape
    if( [V isBar] ) {
	P = [V pathUsingMapper:_mapper newWidth:([V width] + hitOffset*0.1f)];
	
	if( [P containsPoint:testPoint] )
            return RSHitResultMake(V, 0, YES);
	else
            return RSHitResultNo;
    }
    
    // Special adjustment for arrow heads, which are not centered on the point
    if ([V shape] == RS_ARROW && [V arrowParent]) {
	RSLine *L = [V arrowParent];
	CGFloat t = [_mapper timeOfAdjustedEnd:V onLine:L];
	CGPoint adj = [_mapper locationOnCurve:L atTime:t];
	
	p = adj;// CGPointMake((p.x + adj.x)/2, (p.y + adj.y)/2);
    }
    
    //if ( [[_renderer pathFromVertex:V newWidth:width] containsPoint:testPoint] ) return YES;
    
    // I think it's most user-friendly to just use a constant circle hit area
    //CGRect r;
    //r.origin.x = p.x - w;
    //r.origin.y = p.y - w;
    //r.size.width  = w*2;
    //r.size.height = w*2;
    //P = [NSBezierPath bezierPathWithOvalInRect:r];
    
    // And more efficient to do it with math
    //CGFloat dist = distanceBetween(testPoint, p);
    //if( dist <= w )  return YES;
    //else  return NO;
    
    // And even more efficient to do it with tricky math (no square roots or division)
    CGFloat distsquared = (testPoint.x - p.x)*(testPoint.x - p.x) + (testPoint.y - p.y)*(testPoint.y - p.y);
    if( distsquared <= w*w )
        return RSHitResultMake(V, sqrt(distsquared), YES);
    return RSHitResultNo;
}

- (BOOL)hitTestPoint:(CGPoint)testPoint onBarEnd:(RSGraphElement *)GE;
// testPoint is in view coords
{
    if (![GE isKindOfClass:[RSVertex class]])  return NO;
    RSVertex *V = (RSVertex *)GE;
    if( ![V isBar] )  return NO;
    // else
    //NSLog(@"testPoint: %f, %f", testPoint.x, testPoint.y);
    CGFloat width = [V width] * RS_BAR_WIDTH_FACTOR;
    CGFloat offset = [self selectionSensitivity]*2;
    CGPoint p = [_mapper convertToViewCoords:[V position]];
    CGRect r;
    if( [V shape] == RS_BAR_VERTICAL ) {
	r = CGRectMake(p.x - width, p.y - offset, width*2, offset*2);
    }
    else {
	r = CGRectMake(p.x - offset, p.y - width, offset*2, width*2);
    }
    NSBezierPath *P = [NSBezierPath bezierPathWithRect:r];
    if( [P containsPoint:testPoint] )  return YES;
    else  return NO;
}

- (BOOL)hitTestPoint:(CGPoint)testPoint onFill:(RSFill *)testFill;
// testPoint is in view coords
{
    if ( [[_renderer pathFromFill:testFill] containsPoint:testPoint] ) return YES;
    else return NO;
}

- (RSHitResult)hitTestPoint:(CGPoint)testPoint onLabel:(RSTextLabel *)TL;
{
    CGFloat hitOffset = [self selectionSensitivity];
    return [self hitTestPoint:testPoint onLabel:TL offset:hitOffset];
}
- (RSHitResult)hitTestPoint:(CGPoint)testPoint onLabel:(RSTextLabel *)TL offset:(CGFloat)hitOffset;
// testPoint is in view coords
{
    CGRect zeroOffsetRect = [_mapper rectFromLabel:TL offset:0];
    
    // Make sure the tap targets are big enough
    CGRect rect = zeroOffsetRect;
    CGFloat space = hitOffset*2;
    if ([TL isPartOfAxis]) {
        space *= 0.8f;
    }
    
    CGSize delta = CGSizeZero;
    if (rect.size.width < space)
        delta.width = rect.size.width - space;
    if (rect.size.height < space)
        delta.height = rect.size.height - space;
    rect = CGRectInset(rect, delta.width, delta.height);
    
    NSBezierPath *P = [NSBezierPath bezierPathWithRect:rect];
    
    // take care of possible rotation:
    CGRect r = zeroOffsetRect;  // We want to rotate within a 0-offset frame, even though the path is bigger than that frame
    CGFloat degrees = [TL rotation];
    [P rotateInFrame:r byDegrees:degrees];
    if ( [P containsPoint:testPoint] ) {
        
        // Calculate the distance from the text label's midline
        CGPoint end1 = CGPointMake(CGRectGetMinX(rect), CGRectGetMidY(rect));
        CGPoint end2 = CGPointMake(CGRectGetMaxX(rect), CGRectGetMidY(rect));
        end1 = rotatePointInFrameByDegrees(end1, r, degrees);
        end2 = rotatePointInFrameByDegrees(end2, r, degrees);
        CGFloat distance = distanceBetweenPointAndStraightLine(testPoint, end1, end2);
        
        return RSHitResultMake(TL, distance, YES);
    }
    else return RSHitResultNo;
}


- (RSHitResult)hitTestPoint:(CGPoint)p onAxis:(RSAxis *)axis;
// p is in view coords
{
    if ([axis placement] == RSBothEdgesPlacement) {
        RSHitResult hitResult = [self hitTestPoint:p onAxis:axis originPoint:[_mapper convertToViewCoords:[_mapper originPoint]]];
        if (!hitResult.hit) {
            hitResult = [self hitTestPoint:p onAxis:axis originPoint:[_mapper viewMaxes]];
        }
        return hitResult;
    }
    else {
	return [self hitTestPoint:p onAxis:axis originPoint:[_mapper convertToViewCoords:[_mapper originPoint]]];
    }
}

- (RSHitResult)hitTestPoint:(CGPoint)p onAxis:(RSAxis *)axis edge:(RSAxisEdge)edge;
// p is in view coords
{
    if (edge == RSAxisEdgeMax) {
	if ([axis placement] == RSBothEdgesPlacement) {
	    return [self hitTestPoint:p onAxis:axis originPoint:[_mapper viewMaxes]];
	}
	else {
	    return RSHitResultNo;
	}
    }
    else {
	return [self hitTestPoint:p onAxis:axis originPoint:[_mapper convertToViewCoords:[_mapper originPoint]]];
    }
}

- (RSHitResult)hitTestPoint:(CGPoint)p onAxis:(RSAxis *)axis originPoint:(CGPoint)origin;
// p and origin are in view coords
{
    if (![axis displayAxis])  // axis is not visible
	return RSHitResultNo;
    
    CGPoint mins = [_mapper viewMins];
    CGPoint maxes = [_mapper viewMaxes];
    CGFloat hitOffset = [axis width]/2 + [self selectionSensitivity];
    
    CGPoint minEnd, maxEnd;
    CGRect r;
    if ([axis orientation] == RS_ORIENTATION_HORIZONTAL) {  // x-axis
	r = CGRectMake(mins.x - hitOffset, origin.y - hitOffset, maxes.x - mins.x + hitOffset*2, hitOffset*2);
        minEnd = CGPointMake(mins.x, origin.y);
        maxEnd = CGPointMake(maxes.x, origin.y);
    }
    else if ([axis orientation] == RS_ORIENTATION_VERTICAL) {  // y-axis
	r = CGRectMake(origin.x - hitOffset, mins.y - hitOffset, hitOffset*2, maxes.y - mins.y + hitOffset*2);
        minEnd = CGPointMake(origin.x, mins.y);
        maxEnd = CGPointMake(origin.x, maxes.y);
    }
    else {
        OBASSERT_NOT_REACHED("");
        return RSHitResultNo;
    }
    
    if (CGRectContainsPoint(r, p)) {
        CGFloat distance = distanceBetweenPointAndStraightLine(p, minEnd, maxEnd);
        return RSHitResultMake(axis, distance,YES);
    }
    else
	return RSHitResultNo;
}

- (RSAxisEnd)hitTestPoint:(CGPoint)p onEndsOfAxis:(RSAxis *)axis;
{
    if (![axis displayAxis])  // axis is not visible
	return NO;
    
    //    CGPoint mins = [_mapper viewMins];
    //    CGPoint maxes = [_mapper viewMaxes];
    //    CGPoint origin = [_mapper viewOriginPoint];
    //    
    //    CGFloat hitOffset = [axis width]/2.0 + [self selectionSensitivity];
    
    CGRect r;
    if ([axis orientation] == RS_ORIENTATION_HORIZONTAL) {  // x-axis
        //r = CGRectMake(maxes.x - hitOffset, origin.y - hitOffset, hitOffset*2, hitOffset*2);
        r = [_mapper rectFromPosition:[axis max] onAxis:axis];
        if (CGRectContainsPoint(r, p))
            return RSAxisXMax;
        
        //r = CGRectMake(mins.x - hitOffset, origin.y - hitOffset, hitOffset*2, hitOffset*2);
        r = [_mapper rectFromPosition:[axis min] onAxis:axis];
        if (CGRectContainsPoint(r, p))
            return RSAxisXMin;
    }
    else { // vertical
        r = [_mapper rectFromPosition:[axis max] onAxis:axis];
        if (CGRectContainsPoint(r, p))
            return RSAxisYMax;
        
        r = [_mapper rectFromPosition:[axis min] onAxis:axis];
        if (CGRectContainsPoint(r, p))
            return RSAxisYMin;
    }
    
    // If got this far
    return RSAxisEndNone;
}




//////////////////////////
#pragma mark -
#pragma mark Rect clip testing methods (for rectangular select)
//////////////////////////
// rect is in view coords
- (BOOL)rect:(CGRect)viewRect intersectsVertex:(RSVertex *)V;
{
    if (![V isBar]) {
        CGPoint viewPosition = [_mapper convertToViewCoords:[V position]];
        return CGRectContainsPoint(viewRect, viewPosition);
    }
    
    // If this is a bar:
    CGRect barRect = [_renderer rectFromBar:V width:[V width]];
    return CGRectIntersectsRect(viewRect, barRect);
}

- (BOOL)rect:(CGRect)viewRect containsVertex:(RSVertex *)V;
{
    if (![V isBar]) {
        CGPoint viewPosition = [_mapper convertToViewCoords:[V position]];
        return CGRectContainsPoint(viewRect, viewPosition);
    }
    
    // If this is a bar:
    CGRect barRect = [_renderer rectFromBar:V width:[V width]];
    return CGRectIntersectsRect(viewRect, barRect);
}

- (BOOL)rect:(CGRect)viewRect intersectsLine:(RSLine *)L;
{
    if (![L isCurved]) {
        return rectClipsLine(viewRect, [_mapper convertToViewCoords:[L startPoint]], [_mapper convertToViewCoords:[L endPoint]]);
    }
    OBASSERT([[L vertices] count] > 2);
    
    // Trivial accept if any of the interpolation points are inside the rect
    for (RSVertex *V in [[L vertices] elements]) {
        if (CGRectContainsPoint(viewRect, [_mapper convertToViewCoords:[V position]])) {
            return YES;
        }
    }
    
    if ([L connectMethod] == RSConnectStraight) {
        // Check intersection with each straight segment
        RSVertex *prev = nil;
        for (RSVertex *V in [[L vertices] elements]) {
            if (!prev) {
                prev = V;
                continue;
            }
            
            CGPoint prevPos = [_mapper convertToViewCoords:[prev position]];
            CGPoint VPos = [_mapper convertToViewCoords:[V position]];
            if (rectClipsLine(viewRect, prevPos, VPos))
                return YES;
            
            prev = V;
        }
    }
    else if ([L connectMethod] == RSConnectCurved) {
        // Check intersection with 5 straight lines per segment
	CGFloat incr = 0.2f;
        
        NSArray *VArray = [[L vertices] elements];
        NSInteger n = [VArray count] - 1;
	CGPoint segs[n + 1][3];
	
	// compute the curve segments
	[_mapper bezierSegmentsFromVertexArray:VArray putInto:segs];
	
	// loop through each curve segment
	for( int i=0; i<n; i++ ) {
	    CGPoint p0 = segs[i][0];  // control points making up each segment
	    CGPoint p1 = segs[i][1];
	    CGPoint p2 = segs[i][2];
	    CGPoint p3 = segs[i+1][0];
	    
	    // loop through approximating straight lines
	    for( CGFloat t=0; t<1; t+=incr ) {
                
		// straight line approximation endpoints:
		CGPoint s1 = evaluateBezierPathAtT(p0, p1, p2, p3, t);
		CGPoint s2 = evaluateBezierPathAtT(p0, p1, p2, p3, t+incr);
		
		// clip-test this straight line segment
                if (rectClipsLine(viewRect, s1, s2)) {
                    return YES;
                }
	    }
	}
    }
    
    return NO;
}

- (BOOL)rect:(CGRect)viewRect intersectsLabel:(RSTextLabel *)TL;
{
    CGRect labelRect = [_mapper rectFromLabel:TL offset:0];
    
    if (![TL rotation]) {
        return CGRectIntersectsRect(labelRect, viewRect);
    }
    
    // If TL is rotated, more complex calculation is necessary
    return rectIntersectsRotatedRect(viewRect, labelRect, [TL rotation]);
}

- (BOOL)rect:(CGRect)viewRect containsLabel:(RSTextLabel *)TL;
{
    CGRect labelRect = [_mapper rectFromLabel:TL offset:0];
    
    if (![TL rotation]) {
        if (CGRectContainsRect(viewRect, labelRect))
            return YES;
        else
            return NO;
    }
    
    // If TL is rotated, more complex calculation is necessary
    NSBezierPath *P = [NSBezierPath bezierPathWithRect:labelRect];
    CGRect rotationRect = [_mapper rectFromLabel:TL offset:0];  // Be sure to rotate within a 0-offset frame
    [P rotateInFrame:rotationRect byDegrees:[TL rotation]];
    
    if (CGRectContainsRect(viewRect, [P bounds]))
        return YES;
    else
        return NO;
}

- (RSGraphElement *)elementsIntersectingRect:(CGRect)rect;
{
    RSGroup *insiders = [[RSGroup alloc] initWithGraph:_graph];
    
    // Find vertices that are inside the rect
    for (RSVertex *V in [_graph Vertices]) {
        if ([self rect:rect intersectsVertex:V]) {
            [insiders addElement:V];
        }
    }
    // Find lines that intersect with rect
    for (RSLine *L in [_graph Lines]) {
        if ([self rect:rect intersectsLine:L]) {
            [insiders addElement:L atIndex:0];
            [insiders addElement:[L vertices]];
        }
    }
    // Find fills who have any vertex in insiders
    for (RSFill *F in [_graph Fills]) {
        for (RSVertex *V in [[F vertices] elements]) {
            if ([insiders containsElement:V]) {
                [insiders addElement:F atIndex:0];
                break;
            }
        }
    }
    // Find text labels that intersect with the rect
    for (RSTextLabel *TL in [_graph Labels]) {
        if ([self rect:rect intersectsLabel:TL]) {
            [insiders addElement:TL];
        }
    }
    // Now go through axis tick labels
    for (RSTextLabel *TL in [_renderer visibleAxisLabels]) {
        if ([self rect:rect intersectsLabel:TL]) {
            [insiders addElement:TL];
        }
    }
    
    [insiders autorelease];
    return [insiders shake];
}

- (RSGraphElement *)elementsEnclosedByRect:(CGRect)rect;
{
    RSGroup *insiders = [[RSGroup alloc] initWithGraph:_graph];
    
    // Go through vertices, finding those who are inside the rect
    for (RSVertex *V in [_graph Vertices]) {
        if ([self rect:rect containsVertex:V]) {
            [insiders addElement:V];
        }
    }
    // Now go through lines, finding those who have all vertices in insiders
    for (RSLine *L in [_graph Lines]) {
        if ( [insiders containsElement:[L vertices]] ) {
            [insiders addElement:L atIndex:0];
        }
    }
    // now go through fills
    for (RSFill *F in [_graph Fills]) {
        if ( [insiders containsElement:[F vertices]] ) {
            [insiders addElement:F atIndex:0];
        }
    }
    // Now go through text labels, finding those who are inside the rect
    for (RSTextLabel *TL in [_graph Labels]) {
        if ([self rect:rect containsLabel:TL]) {
            [insiders addElement:TL];
        }
    }
    // Now go through axis tick labels
    for (RSTextLabel *TL in [_renderer visibleAxisLabels]) {
        if ([self rect:rect containsLabel:TL]) {
            [insiders addElement:TL];
        }
    }
    
    [insiders autorelease];
    return [insiders shake];
}


//////////////////////////
#pragma mark -
#pragma mark Curves helper methods
//////////////////////////

- (CGPoint)closestPointTo:(CGPoint)p onCurve:(RSLine *)L {
    return [self closestPointTo:p onCurve:L saveT:nil];
}
- (CGPoint)closestPointTo:(CGPoint)p onCurve:(RSLine *)L saveT:(CGFloat *)tp {
    // Returns a point on curve L which is closest to the given point p.
    // Pass a float pointer as tp to remember the time value of the closest point.
    // All in VIEW COORDS.
    
    CGFloat t;
    CGPoint loc;
    
    // if the line is straight
    if( ![L isCurved] ) { 
	CGPoint start, end;
	start = [_mapper convertToViewCoords:[L startPoint]];
	end = [_mapper convertToViewCoords:[L endPoint]];
	t = timeOfClosestPointOnStraightLineToP(start, end, p);
	
	loc = evaluateStraightLineAtT(start, end, t);
    }
    //    // the line is curved
    //    // if a simple curve
    //    else if( ![L isKindOfClass:[RSConnectLine class]] ) {
    //	CGPoint p0, p1, p2, p3;
    //	p0 = [_mapper convertToViewCoords:[L startPoint]];
    //	p3 = [_mapper convertToViewCoords:[L endPoint]];
    //	p1 = [_mapper convertToViewCoords:[L controlPoint1]];
    //	p2 = [_mapper convertToViewCoords:[L controlPoint2]];
    //	
    //	t = timeOfClosestPointOnBezierPathToP(p0, p1, p2, p3, p);
    //	
    //	loc = evaluateBezierPathAtT(p0, p1, p2, p3, t);
    //    }
    // else, a connectLine curve
    else {
	t = [self timeOfClosestPointTo:p onLine:(RSConnectLine *)L];
	
	loc = [_mapper locationOnCurve:L atTime:t];
    }
    
    // save the t value if a pointer was provided
    if( tp ) {
	*tp = t;
    }
    
    //calculated earlier//CGPoint loc = evaluateBezierPathAtT(p0, p1, p2, p3, t);
    return loc;
}

//! There is code duplication going on between this method and the preceding method -- but non-obvious how to fix.  Probably, should use Wim's code in OmniAppKit instead.
- (CGFloat)timeOfClosestPointTo:(CGPoint)p onLine:(RSLine *)L {
    // Returns the time value of the point on curve L which is closest to the given point p.
    // p is in VIEW COORDS.
    
    // if the line is straight
    if( ![L isCurved] ) { 
	CGPoint start = [_mapper convertToViewCoords:[L startPoint]];
	CGPoint end = [_mapper convertToViewCoords:[L endPoint]];
	return timeOfClosestPointOnStraightLineToP(start, end, p);
    }
    
    // otherwise, curved...
    
    // first, run the hit test again to find which particular curve segment was hit
    //
    NSUInteger hitSegment = 0;
    RSHitResult hitResult = [self hitTestPoint:p onLine:L hitSegment:&hitSegment];
    if (!hitResult.hit) {
	//OBASSERT_NOT_REACHED("We expected this line to be hit but it wasn't");
	return 0;  // nothing was hit
	
        //	// if not found, expand the range to search in
        //	if (![self hitTestPoint:p onLine:L hitSegment:&hitSegment hitOffset:25.0]) {
        //	    
        //	    // if still not found, return the t-value of the closest endpoint instead
        //	    CGFloat d1 = distanceBetweenPoints(p, [L startPoint]);
        //	    CGFloat d2 = distanceBetweenPoints(p, [L endPoint]);
        //	    if (d1 < d2)
        //		return 0;  // t-value of start vertex
        //	    else
        //		return 1;  // t-value of end vertex
        //	}
    }
    // otherwise, hitSegment should contain the index of the line segment that was hit
    
    CGFloat t = [self timeOfClosestPointTo:p onLine:L hitSegment:hitSegment];
    OBASSERT(isfinite(t) && t >= 0);
    return t;
}



- (CGFloat)timeOfClosestPointTo:(CGPoint)p onLine:(RSLine *)L hitSegment:(NSUInteger)hitSegment;
// hitSegment is the index of the line segment that was hit
{
    if( ![L isCurved] ) { 
	CGPoint start = [_mapper convertToViewCoords:[L startPoint]];
	CGPoint end = [_mapper convertToViewCoords:[L endPoint]];
	return timeOfClosestPointOnStraightLineToP(start, end, p);
    }
    
    
    NSArray *VArray = [[L vertices] elements];
    NSInteger n = [VArray count] - 1;
    CGFloat t = 0;
    
    OBASSERT(hitSegment < [VArray count] - 1);
    
    //
    // find the "local" time of the closest point on the hit segment
    //
    // if straight connections
    if( [L connectMethod] == RSConnectStraight ) {
	CGPoint p0 = [_mapper convertToViewCoords:[(RSVertex *)[VArray objectAtIndex:hitSegment] position]];
	CGPoint p1 = [_mapper convertToViewCoords:[(RSVertex *)[VArray objectAtIndex:hitSegment + 1] position]];
	t = timeOfClosestPointOnStraightLineToP(p0, p1, p);
    }
    // if curved connections
    else if( [L connectMethod] == RSConnectCurved ) {
	// compute the curve segments
	NSArray *segments = [_mapper bezierSegmentsFromVertexArray:VArray];
        //	CGPoint segs[n + 1][3];
        //	[_mapper bezierSegmentsFromVertexArray:VArray putInto:segs];
	
	// get the control points
	RSBezierSegment seg;
	[[segments objectAtIndex:hitSegment] getValue:&seg];
	CGPoint p0 = seg.p;
	CGPoint p1 = seg.q;
	CGPoint p2 = seg.r;
	[[segments objectAtIndex:hitSegment + 1] getValue:&seg];
	CGPoint p3 = seg.p;
	
	
        //	CGPoint p0, p1, p2, p3;  // control points making up a segment
        //	p0 = segs[hitSegment][0];
        //	p1 = segs[hitSegment][1];
        //	p2 = segs[hitSegment][2];
        //	p3 = segs[hitSegment+1][0];
	
	// convert to t on the hit segment
	t = timeOfClosestPointOnBezierPathToP(p0, p1, p2, p3, p);
    }
    
    //
    // last, convert to "global" t for the whole spline object
    //
    CGFloat gt = (CGFloat)hitSegment/(CGFloat)n + t/(CGFloat)n;
    OBASSERT(isfinite(gt) && gt >= 0);
    return gt;
    
    
    /*Attempting to actually calculate distance from each curve segment
     int hitSegment;  // the segment of this curve that got hit
     CGPoint p0, p1, p2, p3;  // control points making up a segment
     CGPoint s1, s2;  // straight line approximation endpoints
     CGFloat t;
     CGFloat incr = 0.1;
     
     // get width from line and user prefs
     CGFloat _hitOffset = [self selectionSensitivity];
     CGFloat width = ([L width] / 2) + _hitOffset;
     
     // loop through each curve segment
     int i;
     for( i=0; i<n; i++ ) {
     p0 = segs[i][0];
     p1 = segs[i][1];
     p2 = segs[i][2];
     p3 = segs[i+1][0];
     
     // loop through approximating straight lines
     for( t=0; t<1; t+=incr ) {
     
     s1 = evaluateBezierPathAtT(p0, p1, p2, p3, t);
     s2 = evaluateBezierPathAtT(p0, p1, p2, p3, t+incr);
     
     // hit-test this straight line segment
     if( [self hitTestPoint:testPoint 
     onLineFrom:s1//[_mapper convertToViewCoords:s1] 
     to:s2//[_mapper convertToViewCoords:s2] 
     width:width] ) {
     return YES;
     }
     }
     }
     
     // if got this far
     return NO;
     */
}




////////////////////
#pragma mark -
#pragma mark Fills helper methods
///////////////////////////////

- (CGFloat)viewDistanceFromFill:(RSFill *)F toPoint:(CGPoint)p;
{
    // Find the closest vertex to the point
    CGFloat closest = CGFLOAT_MAX;
    for (RSVertex *V in [[F vertices] elements]) {
        CGPoint vp = [_mapper convertToViewCoords:[V position]];
        CGFloat current = distanceBetweenPoints(p, vp);
        if ( current < closest ) {
            closest = current;
        }
    }
    
    // See if an edge is closer:
    RSVertex *V1 = [[[F vertices] elements] lastObject];	// loop all the way around
    RSVertex *V2 = nil;
    for (RSVertex *V in [[F vertices] elements]) {
        V2 = V1;
        V1 = V;
        CGPoint edgePoint = closestPointOnStraightLineToP([_mapper convertToViewCoords:[V1 position]],
                                                          [_mapper convertToViewCoords:[V2 position]],
                                                          p);
        CGFloat current = distanceBetweenPoints(edgePoint, p);
        if ( current < closest ) {
            closest = current;
        }
    }
    
    return closest;
}


@end
