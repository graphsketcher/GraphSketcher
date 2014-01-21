// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/Model/RSFreehandStroke.m 200244 2013-12-10 00:11:55Z correia $

#import "RSFreehandStroke.h"

#import <GraphSketcherModel/RSStrokePoint.h>
#import <GraphSketcherModel/RSNumber.h>
#import <OmniQuartz/OQColor.h>
#import <OmniFoundation/OFPreference.h>

@interface RSFreehandStroke (/*Private*/)
// low-level geometry helpers
+ (CGFloat)distanceBetweenPoint:(CGPoint)t andLineFrom:(CGPoint)start to:(CGPoint)end;
+ (CGFloat)tangentFrom:(NSInteger)start to:(NSInteger)end xValues:(CGFloat *)xvals yValues:(CGFloat *)yvals;

// methods that act on a single segment
+ (CGPoint)curvePointForSegmentFrom:(NSInteger)startIndex to:(NSInteger)endIndex onSegment:(NSArray *)segment;
+ (CGFloat)straightnessOfSegment:(NSArray *)stroke withCurvePoint:(CGPoint)cp;
+ (CGFloat)straightnessOfSegmentStarting:(CGPoint)start ending:(CGPoint)end withCurvePoint:(CGPoint)cp;

// Methods for segmenting a stroke
- (NSArray *)segmentStroke;  // returns an array of stroke arrays
- (NSArray *)segmentsFromSegmentIndices:(NSArray *)indices;
@end


@implementation RSFreehandStroke

#pragma mark -
#pragma mark Init/dealloc

- (id)init;
{
    if (!(self = [super init]))
        return nil;
    
    _stroke = [[NSMutableArray alloc] initWithCapacity:50];
    _segments = nil;
    
    return self;
}

- (void)dealloc;
{
    [_stroke release];
    [_segments release];
    
    [super dealloc];
}


#pragma mark -
#pragma mark Accessors

- (NSArray *)stroke;
{
    return _stroke;
}

@synthesize strokeEnded = _strokeEnded;
@synthesize segments = _segments;


// stroke points are in view coords!
- (void)addStrokePoint:(CGPoint)p atTime:(double)t {
    if( self.strokeEnded ) {
	[_stroke removeAllObjects];
	self.strokeEnded = NO;
    }
    
    [self willChangeValueForKey:@"stroke"];
    [_stroke addObject:[RSStrokePoint strokePointWithPoint:p time:t]];
    [self didChangeValueForKey:@"stroke"];
    
    if( SKETCH_TEST_MODE || [[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:@"SegmentStrokesWhileDrawing"] ) {
	// Do segmentation in real time!!
	[self performSegmentation];
    }
}

- (CGRect)boundingRect;
// compute the bounding rectangle of the set of points in the stroke
{
    if( [_stroke count] < 1 ) {
	OBASSERT_NOT_REACHED("Empty stroke");
	return CGRectMake(0,0,0,0);
    }
    
    NSEnumerator *E = [_stroke objectEnumerator];
    RSStrokePoint *sp = [E nextObject];
    CGPoint min = [sp point];
    CGPoint max = [sp point];
    while ((sp = [E nextObject])) {
	CGPoint p = [sp point];
	if( p.x < min.x )  min.x = p.x;
	else if ( p.x > max.x )  max.x = p.x;
	if( p.y < min.y )  min.y = p.y;
	else if( p.y > max.y )  max.y = p.y;
    }
    
    return CGRectMake(min.x, min.y, max.x - min.x, max.y - min.y);
}




/////////////////
#pragma mark -
#pragma mark Parameter constants
/////////////////


// thresholds for individual segments
#define CURVE_PERCENTAGE_CUTOFF (0.08f)  // (percent of straight-line length)

#define NO_CURVATURE_THRESHOLD (30)  // (summed curvature * segment length)

// Set threshold constants for segmenting
#define SPEED_SMOOTHING_WINDOW (2)  //;  % (on each side)
#define TANGENT_WINDOW (4)  //;  % (on each side)
#define DERIVATIVE_WINDOW (4)  //;  % (on each side)
#define MIN_CORNER_DISTANCE (3)  //;  % (input points)
#define MIN_SEG_LENGTH_PERCENTAGE (0.30f)  // (percent of average segment length)

#define SPEED_THRESHOLD_1 (0.2f)  //;  % (percent of average speed)
#define CURVATURE_THRESHOLD (0.75f)  //;  % (degree/pixel)
#define SPEED_THRESHOLD_2 (0.60f)  //;  % (percent of average speed)
#define MIN_ARC_ANGLE (45)  //;  % (degrees)
#define CIRC_FIT_ERROR_MAGNIFICATION (1)  //;  % (multiplied by circle fit average residual)




///////
#pragma mark -
#pragma mark helper functions
////
static CGFloat maxf(CGFloat a, CGFloat b) {  
    // returns the bigger of two floats
    if( a >= b )  return a;
    else  return b;
}
static CGFloat minf(CGFloat a, CGFloat b) {  
    // returns the smaller of two floats
    if( a <= b )  return a;
    else  return b;
}
static CGFloat sumf(NSInteger start, NSInteger stop, CGFloat *array) {  
    // returns the sum of array values from indices start to stop
    CGFloat sum = 0;
    NSInteger j;
    for( j=start; j<=stop; j++ ) {
	sum += array[j];
    }
    return sum;
}
static NSInteger signf(CGFloat a) {
    // returns the sign of a float (1 if pos or 0, -1 if neg)
    if( a >= 0 ) return 1;
    else  return -1;
}
static NSInteger sign3wayf(CGFloat a) {
    // returns the sign of a float (1 if pos or 0, -1 if neg)
    if( a >= NO_CURVATURE_THRESHOLD )  return 1;
    else if ( a <= -NO_CURVATURE_THRESHOLD )  return -1;
    else  return 0;
}
static char * displayf(NSInteger start, NSInteger stop, CGFloat *array) {
    NSInteger j;
    //char *str[(stop-start+1)*15];  // roughly the length of each float in characters
    for( j=start; j<=stop; j++ ) {
	//str = strcat(str, 
	LogP(@"  %f", array[j]);
    }
    return 0;
}


#pragma mark -


/////////////////
#pragma mark Low-level geometry helpers
/////////////////

+ (CGFloat)distanceBetweenPoint:(CGPoint)t andLineFrom:(CGPoint)start to:(CGPoint)end {
    CGPoint p, q, r, min, max;	// start, end, intersection, min corner, max corner
    CGFloat m, m2;	// slope of line, slope of perpendicular line
    //CGFloat w;	// allowed perpendicular distance from line
    CGFloat d, d1, d2;	// actual perpendicular distance of test point from line
    CGFloat a, b; // intermediate variables
    BOOL isVertical = NO;
    BOOL isHorizontal = NO;
    
    // initialize known values:
    p = start;
    q = end;
    // calculate slopes:
    if ( q.x - p.x != 0 ) {
	m = (q.y - p.y) / (q.x - p.x);
    } else {
	isVertical = YES;
	m = 1000;
    }
    if ( q.y - p.y != 0 ) {
	m2 = (p.x - q.x) / (q.y - p.y);   // (perpendicular -1/m)
    } else {
	isHorizontal = YES;
	m2 = 1000;
    }
    // calculate intersection point:
    r.x = (t.y - p.y + m*p.x - m2*t.x) / (m - m2);
    r.y = m*(r.x - p.x) + p.y;
    
    // determine max and min corners:
    if ( p.x > q.x ) {
	min.x = q.x;
	max.x = p.x;
    } else {
	min.x = p.x;
	max.x = q.x;
    }
    if ( p.y > q.y ) {
	min.y = q.y;
	max.y = p.y;
    } else {
	min.y = p.y;
	max.y = q.y;
    }
    // if the intersection is outside extremal corners, distance is to closest end vertex
    if ( (!isVertical && r.x > max.x) || (!isVertical && r.x < min.x) 
	|| (!isHorizontal && r.y > max.y) || (!isHorizontal && r.y < min.y) ) {
	// calculate distance to each endpoint:
	a = t.x - p.x;
	b = t.y - p.y;
	d1 = sqrt(a*a + b*b);
	a = t.x - q.x;
	b = t.y - q.y;
	d2 = sqrt(a*a + b*b);
	// closest one is "distance to line"
	if ( d1 <= d2 )  d = d1;
	else  d = d2;
    }
    else {	// intersection point is within line segment, so calculate distance to it:
	a = t.x - r.x;
	b = t.y - r.y;
	d = sqrt(a*a + b*b);
    }
    return d;
}

+ (CGFloat)tangentFrom:(NSInteger)start to:(NSInteger)end xValues:(CGFloat *)xvals yValues:(CGFloat *)yvals {
    // Adapted from [RSFitLine updateParameters] //
    CGFloat sumx = 0, sumy = 0, sumxy = 0, sumxx = 0;
    CGFloat sumyy = 0;//, sx2 = 0, sy2 = 0;
    CGFloat n;	// converted from an NSInteger
    CGFloat denom;
    CGFloat _m;
    //RSStrokePoint *SP;
    CGPoint p;
    
    n = (CGFloat)(end - start + 1.0);
    //LogP(@"start: %d, stop: %d, n: %f", start, end, n);
    if ( n < 2 ) {	// too small to be meaningful
	//LogP(@"n too small: %d", n);
        // i.e. m=0, b=1
        return 0;
    }
    
    NSInteger i;
    for( i=start; i<=end; i++ ) {
	//SP = [stroke objectAtIndex:i];
	//p = [SP point];
	p = CGPointMake(xvals[i], yvals[i]);
	sumx += p.x;
	sumy += p.y;
	sumxy += p.x*p.y;
	sumxx += p.x*p.x;
	sumyy += p.y*p.y;
    }
    
    // Formula from Kirby's sheet:
    // _m = (n*sumxy - sumx*sumy) / (n*sumxx - sumx*sumx);
    denom = (n*sumxx - sumx*sumx);
    if ( denom != 0 )
	_m = (n*sumxy - sumx*sumy) / denom;
    else 
	_m = 1000;
    
    return _m;
    //_b = sumy/n - _m*(sumx/n);
}



//////////////
#pragma mark -
#pragma mark Methods that act on a single segment
//////////////

+ (CGPoint)curvePointForSegment:(NSArray *)segment {
    return [RSFreehandStroke curvePointForSegmentFrom:0 to:([segment count]-1) onSegment:segment];
}

+ (CGPoint)curvePointForSegmentFrom:(NSInteger)startIndex to:(NSInteger)endIndex onSegment:(NSArray *)segment;
{
    CGPoint farthestPoint;
    CGPoint start = [(RSStrokePoint *)[segment objectAtIndex:startIndex] point];
    CGPoint end = [(RSStrokePoint *)[segment objectAtIndex:endIndex] point];
    CGFloat farthestDistance = 0;
    CGFloat currentDistance;
    RSStrokePoint *sp;
    NSInteger i;
    
    // default starting point will be halfway between the ends:
    farthestPoint = CGPointMake((start.x + end.x)/2, (start.y + end.y)/2);
    
    for( i=startIndex+1; i<endIndex; i++ ) {
	sp = [segment objectAtIndex:i];
	// calculate perpendicular distance from straight line:
	currentDistance = [RSFreehandStroke distanceBetweenPoint:[sp point]
					       andLineFrom:start
							to:end];
	if( currentDistance > farthestDistance ) {
	    farthestDistance = currentDistance;
	    farthestPoint = [sp point];
	}
    }
    //LogP(@"curve thresh: %f", CURVATURE_THRESHOLD);
    return farthestPoint;
}

+ (CGPoint)midPointForSegment:(NSArray *)stroke;
{
    OBPRECONDITION([stroke count] >= 2);
    
    CGPoint p0 = [(RSStrokePoint *)[stroke objectAtIndex:0] point];
    CGPoint p1 = [(RSStrokePoint *)[stroke lastObject] point];
    
    CGPoint mid = CGPointMake((p0.x + p1.x)*0.5f, (p0.y + p1.y)*0.5f);
    return mid;
}

+ (BOOL)segment:(NSArray *)stroke isStraightWithCurvePoint:(CGPoint)cp {
    if( [RSFreehandStroke straightnessOfSegment:stroke withCurvePoint:cp] < CURVE_PERCENTAGE_CUTOFF )
	return YES;
    else  return NO;
}

+ (CGFloat)straightnessOfSegment:(NSArray *)stroke withCurvePoint:(CGPoint)cp {
    CGPoint start = [(RSStrokePoint *)[stroke objectAtIndex:0] point];
    CGPoint end = [(RSStrokePoint *)[stroke lastObject] point];
    
    return [RSFreehandStroke straightnessOfSegmentStarting:start ending:end withCurvePoint:cp];
}

+ (CGFloat)straightnessOfSegmentStarting:(CGPoint)start ending:(CGPoint)end withCurvePoint:(CGPoint)cp {
    CGFloat perpDistance = [RSFreehandStroke distanceBetweenPoint:cp andLineFrom:start to:end];
    CGFloat length = distanceBetweenPoints(start, end);
    
    return perpDistance/length;
}





/////////////////
#pragma mark -
#pragma mark methods for segmenting a stroke
/////////////////

- (void)performSegmentation;
{
    [self willChangeValueForKey:@"segments"];
    [_segments release];
    _segments = [[self segmentStroke] retain];
    [self didChangeValueForKey:@"segments"];
}


// returns an array of stroke arrays
- (NSArray *)segmentStroke;
{
    //LogP(@"start");
    NSArray *stroke = _stroke;
    
    // Calculate some values that will be useful:
    NSInteger len = [stroke count];
    CGFloat pi = (CGFloat)M_PI;
    CGFloat stroke_x[len+1];
    CGFloat stroke_y[len+1];
    CGFloat stroke_t[len+1];
    NSInteger i;
    NSInteger end;
    CGFloat x, y, d;
    
    // Some of the calculations below fail if there are not at least 3 points making up the stroke.
    if (len < 3) {
        return nil;
    }
    
    for( i=1; i<=len; i++ ) {
        RSStrokePoint *strokePoint = [stroke objectAtIndex:(i-1)];
	stroke_x[i] = [strokePoint pointx];
	stroke_y[i] = [strokePoint pointy];
	stroke_t[i] = (CGFloat)[strokePoint time];
    }
    
    LogP(@"************************************");
    
    LogP(@"%d digitized points", len);
    //LogP(@"stroke_t:");
    //displayf(1, 7, stroke_t);
    
    //
    // 1. Construct array of the cumulative arc lengths between each pair of
    // consecutive sampled points.
    d = 0;
    CGFloat arcLength[len];
    arcLength[1] = 0;
    for( i=2; i<=len; i++ ) {
	x = stroke_x[i] - stroke_x[i-1];
	y = stroke_y[i] - stroke_y[i-1];
	d = d + sqrt(x*x + y*y);
	arcLength[i] = d;
    }
    LogP(@"arcLength: %f, %f, %f, %f", arcLength[1], arcLength[2], arcLength[3], arcLength[4]);
    
    //
    // 2. Construct array of smoothed pen speeds at each point.
    // "centered finite difference":
    CGFloat rawPenSpeed[len];
    for( i=2; i<=(len - 1); i++ ) {
	rawPenSpeed[i] = (arcLength[i+1] - arcLength[i-1]) / (stroke_t[i+1] - stroke_t[i-1]);
    }
    // extrapolate end speeds:
    rawPenSpeed[1] = rawPenSpeed[2];
    rawPenSpeed[len] = rawPenSpeed[len-1];
    LogP(@"rawPenSpeed:");
    displayf(1, 5, rawPenSpeed);
    
    // "simple smoothing filter":
    CGFloat penSpeed[len];
    NSInteger win_start, win_end;
    //CGFloat temp;
    for( i=1; i<=len; i++ ) {
	win_start = maxf(1, i - SPEED_SMOOTHING_WINDOW);
	win_end = minf(len, i + SPEED_SMOOTHING_WINDOW);
	// take average of window:
	penSpeed[i] = sumf(win_start, win_end, rawPenSpeed)/(2*SPEED_SMOOTHING_WINDOW + 1);
	//temp = 0;
	//for( j=win_start; j<=win_end; j++ )  temp += rawPenSpeed[j];
	//penSpeed[i] = temp/(2*SPEED_SMOOTHING_WINDOW + 1);
    }
    //penSpeed
    //plot(penSpeed)
    LogP(@"penSpeed:");
    displayf(1, 5, penSpeed);
    
    
    //
    // 3. Construct array of tangents (slopes) at each point
    CGFloat slopes[len];
    for( i=1; i<=len; i++ ) {
	// (tangent function is 0-indexed)
	win_start = maxf(1, i - TANGENT_WINDOW);
	win_end = minf(len, i + TANGENT_WINDOW);
	// compute tangent using points in win_start:win_stop
	slopes[i] = [RSFreehandStroke tangentFrom:win_start to:win_end xValues:stroke_x yValues:stroke_y];
    }
    LogP(@"slopes:");
    displayf(1, 5, slopes);
    
    
    //
    // 4. Compute curvature: change in orientation (angle) over change in
    // position.
    CGFloat arctans[len];
    for( i=1; i<=len; i++ ) {
	arctans[i] = atan(slopes[i]);
    }
    // correct for discontinuity problem:
    CGFloat angles[len];
    CGFloat adjust = 0;
    angles[1] = arctans[1];
    for( i=2; i<=len; i++ ) {
	if( fabs(arctans[i] - arctans[i-1]) > fabs(arctans[i] - pi - arctans[i-1]) )
	    adjust = adjust - pi;
	else if( fabs(arctans[i] - arctans[i-1]) > fabs(arctans[i] + pi - arctans[i-1]) )
	    adjust = adjust + pi;
	angles[i] = arctans[i] + adjust;
    }
    // compute the derivative using another least squares line fit:
    CGFloat curvatures[len];
    for( i=2; i<len; i++ ) {
	win_start = maxf(2, i - DERIVATIVE_WINDOW);
	win_end = minf(len, i + DERIVATIVE_WINDOW);
	curvatures[i] = [RSFreehandStroke tangentFrom:win_start to:win_end xValues:arcLength yValues:angles];
	curvatures[i] = curvatures[i]*180/pi;  // convert from radians/pixel to degrees/pixel:
    }
    curvatures[1] = 0;  // this is arbitrary (but unimportant)
    LogP(@"curvatures:");
    displayf(len-5, len-1, curvatures);
    
    
    //
    // 4.b. Compute the cumulative curvatures
    CGFloat cumcurve[len + 1];
    d = 0;
    for( i=1; i<=len; i++ ) {
	d += curvatures[i];
	cumcurve[i] = d;
    }
    LogP(@"cumcurve:");
    displayf(len-5, len-1, cumcurve);
    
    
    //
    // 5.c. Identify candidate segment points based on curvature sign changes
    // 
    NSMutableArray *signSegs = [NSMutableArray array];
    NSInteger previousSign = signf(curvatures[MIN_CORNER_DISTANCE - 1]);
    NSInteger newSign;
    for( i=MIN_CORNER_DISTANCE; i<=(len - MIN_CORNER_DISTANCE); i++ ) {
	newSign = signf(curvatures[i]);
	if( previousSign != newSign ) {
	    [signSegs addObject:[NSNumber numberWithInteger:i]];
	    i += MIN_CORNER_DISTANCE;
	}
	previousSign = newSign;
    }
    LogP(@"signSegs count: %d", [signSegs count]);
    
    
    if( END_BEFORE_PRUNING ) {
	// Create array of all segment break points:
	NSMutableArray *segs = [NSMutableArray arrayWithArray:signSegs];
	// Add beginning and end points:
	[segs addObject:[NSNumber numberWithInteger:1]];
	[segs addObject:[NSNumber numberWithInteger:len]];
	
	NSArray *sortedSegs = [segs sortedArrayUsingSelector:@selector(compare:)];
	
	return [self segmentsFromSegmentIndices:sortedSegs];
    }
    
    
    //
    // 6. Recursively prune the curve sign seg points if not much curvature between segments
    //E = [signSegs objectEnumerator];
    NSMutableArray *newSignSegs;
    CGFloat segCurvature;
    CGFloat segLength;
    CGFloat timeElapsed;
    end = [signSegs count] + 2;
    //
    NSInteger index[end + 1];
    //
    CGFloat curveRatio[end + 1];
    BOOL recurse = YES;
    while ( recurse ) {
	recurse = NO;  // unless proven guilty
        
        // Set up this iteration
        end = [signSegs count] + 2;
        index[0] = 1;
        for( i=1; i<(end - 1); i++ ) {
            index[i] = [[signSegs objectAtIndex:i-1] intValue];
        }
        index[end - 1] = len;
        newSignSegs = [NSMutableArray array];
        //
        
	for( i=1; i<(end - 1); i++ ) {
	    segCurvature = cumcurve[index[i]] - cumcurve[index[i - 1]];
	    segLength = arcLength[index[i]] - arcLength[index[i - 1]];
	    //timeElapsed = stroke_t[index[i]] - stroke_t[index[i - 1]];
	    timeElapsed = (CGFloat)(index[i] - index[i - 1]);  // just the number of ink points!
	    curveRatio[i] = segCurvature*segLength/timeElapsed;
	    LogP(@"crv: %f, length: %f, curveRatio: %f, bulge: %f, time: %f", segCurvature, segLength, curveRatio[i], bulge[i], timeElapsed);
	}
	LogP(@"curveRatio:");
	displayf(1, end-1, curveRatio);
        
        CGFloat prevBulge, bulge = 0;
	for( i=1; i<(end - 1); i++ ) {
            // Find out whether the simple method thinks it's curved:
            prevBulge = bulge;
            bulge = [RSFreehandStroke 
                         straightnessOfSegmentStarting:[[stroke objectAtIndex:(index[i - 1] - 1)] point]
                         ending:[[stroke objectAtIndex:(index[i] - 1)] point]
                         withCurvePoint:[RSFreehandStroke curvePointForSegmentFrom:(index[i - 1] - 1) to:(index[i] - 1) onSegment:stroke]];
            BOOL bulgeThinksIsCurved = bulge >= CURVE_PERCENTAGE_CUTOFF || prevBulge >= CURVE_PERCENTAGE_CUTOFF;
            if (i == 1)
                continue;  // Just setting up
            
            if( sign3wayf(curveRatio[i]) != sign3wayf(curveRatio[i - 1]) && bulgeThinksIsCurved ) {
                [newSignSegs addObject:[NSNumber numberWithInteger:index[i - 1]]];
            }
            else {  // removing a segmentation point means we must recurse again
                recurse = YES;
            }
	}
	if( recurse ) {  // set up for next iteration
	    signSegs = newSignSegs;
	}
    }
    
    // 
    // 7. Prune segments that are too short relative to the others
    //
    // find average length
    CGFloat avgLength = 0;
    for( i=1; i<(end - 1); i++ ) {
	segLength = arcLength[index[i]] - arcLength[index[i - 1]];
	LogP(@"segLength %d: %f", i, segLength);
	avgLength += segLength;
    }
    avgLength /= ([signSegs count] + 1);
    LogP(@"avgLength: %f, n: %d", avgLength, [signSegs count] + 1);
    
    // prune segments that are much shorter than the average length
    newSignSegs = [NSMutableArray array];
    for( i=1; i<(end - 1); i++ ) {
	segLength = arcLength[index[i]] - arcLength[index[i - 1]];
	if (segLength/avgLength >= MIN_SEG_LENGTH_PERCENTAGE) {
	    [newSignSegs addObject:[NSNumber numberWithInteger:index[i]]];
	    LogP(@"keeping segment %d with length %f", i, segLength);
	}
	else {
	    LogP(@"pruned segment %d with length %f", i, segLength);
	}
    }
    // last segment
    i = end - 1;
    segLength = arcLength[index[i]] - arcLength[index[i - 1]];
    if (segLength/avgLength < MIN_SEG_LENGTH_PERCENTAGE) {
	[newSignSegs removeLastObject];
	LogP(@"pruned segment %d with length %f", i, segLength);
    }
    
    
    /* */
    
    
    // Create array of all segment break points:
    NSMutableArray *segs = [NSMutableArray arrayWithArray:newSignSegs];
    // Add beginning and end points:
    [segs addObject:[NSNumber numberWithInteger:1]];
    [segs addObject:[NSNumber numberWithInteger:len]];
    
    NSArray *sortedSegs = [segs sortedArrayUsingSelector:@selector(compare:)];
    
    //LogP(@"end");
    return [self segmentsFromSegmentIndices:sortedSegs];
}

- (NSArray *)segmentsFromSegmentIndices:(NSArray *)indices;
// We assume that the indices array contains the indexes of the start and end of the stroke.
{
    LogP(@"seg break indices: %@", indices);
    NSMutableArray *segments = [NSMutableArray arrayWithCapacity:[indices count] + 1];
    NSEnumerator *E = [indices objectEnumerator];
    NSInteger prev = [[E nextObject] integerValue];
    NSInteger i;
    NSInteger span_size;
    while ((i = [[E nextObject] intValue])) {
	// remember, we need to adjust to the 0-index array, stroke
	span_size = i - prev;
	LogP(@"handling index: %d; from %d to %d", i, prev - 1, span_size + prev - 1);
	[segments addObject:[_stroke objectsAtIndexes:
			     [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(prev - 1,span_size)]]];
	prev = i;
    }
    //LogP(@"segments: %@", segments);
    return segments;
}





@end
