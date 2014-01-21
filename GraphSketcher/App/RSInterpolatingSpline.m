// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/App/RSInterpolatingSpline.m 200244 2013-12-10 00:11:55Z correia $

#import "RSInterpolatingSpline.h"









@implementation RSInterpolatingSpline



#pragma mark -
#pragma mark Convenience methods

+ (void)bezierSegmentsFromPoints:(NSPoint[])p length:(int)n putInto:(NSPoint[][3])segs;
{
    //
    // This algorithm is taken from the Graphics Gems I (1990) article: 
    // "Explicit cubic spline interpolation formulas" by Richard Rasala
    //
    
    // create the a_m_k array, which "starts" at [3][1] and thus has size [16+3][7+1]
    float a[19][8] =
    /*a =*/ {
	{  },
	//{  },
	{  },
	//{ 0, 0.333 },  // n=3
	{ 0, 0.25 },  // n=4
	//{ 0, 0.2727, -0.0909 },  // n=5
	{ 0, 0.2677, -0.0667 },  // n=6
	//{ 0, 0.2683, -0.0732, 0.0244 },  // n=7
	{ 0, 0.2679, -0.0714, 0.0179 },  // n=8
	//{ 0, 0.2680, -0.0719, 0.0196, -0.0065 },  // n=9
	{ 0, 0.2679, -0.0718, 0.0191, -0.0048 },  // n=10
	//{ 0, 0.2680, -0.0718, 0.0193, -0.0053, 0.0018 },  // n=11
	{ 0, 0.2679, -0.0718, 0.0192, -0.0051, 0.0013 },  // n=12
	//{ 0, 0.2679, -0.0718, 0.0192, -0.0052, 0.0014, -0.0005 },  // n=13
	{ 0, 0.2679, -0.0718, 0.0192, -0.0052, 0.0014, -0.0003 },  // n=14
	//{ 0, 0.2679, -0.0718, 0.0192, -0.0052, 0.0014, -0.0004, 0.0001 },  // n=15
	{ 0, 0.2679, -0.0718, 0.0192, -0.0052, 0.0014, -0.0004, 0.0001 }  // n=16
    };
    
    NSPoint d[n+1];
    
    // choose initial/final tangent vectors d_0 and d_n
    if( n == 2 )   // (count == 3)
    {
	// make the same shape as we had for "simple curves" in the previous version
	float extra = 1.33333;  // (4/3)
	float reduce = 0.5;
	// first control point
	NSPoint cp, ray, p0, p1, p2;
	p0 = p[0];
	p1 = p[1];
	p2 = p[2];
	ray.x = (p1.x - p2.x)*extra;
	ray.y = (p1.y - p2.y)*extra;
	cp.x = p2.x + ray.x;
	cp.y = p2.y + ray.y;
	// derive vector d_0
	d[0].x = (cp.x - p0.x)*reduce;
	d[0].y = (cp.y - p0.y)*reduce;
	
	//visual debugging//[RSGraphRenderer drawCircleAt:cp];
	
	// second control point
	p0 = p[n];
	p1 = p[n - 1];
	p2 = p[n - 2];
	ray.x = (p1.x - p2.x)*extra;
	ray.y = (p1.y - p2.y)*extra;
	cp.x = p2.x + ray.x;
	cp.y = p2.y + ray.y;
	// derive vector d_n
	d[n].x = (p0.x - cp.x)*reduce;
	d[n].y = (p0.y - cp.y)*reduce;
    }
    else {  // the extra curvature is overkill when there are multiple interior points
	d[0] = NSMakePoint(0,0);
	d[n] = NSMakePoint(0,0);
	
	//visual debugging//[RSGraphRenderer drawCircleAt:cp];
    }
    
    
    // construct the "degenerate closed loop" made up of points t
    NSPoint t[2*n];
    // the initial/final special cases
    t[0].x = p[0].x + d[0].x;
    t[0].y = p[0].y + d[0].y;
    t[n].x = p[n].x - d[n].x;
    t[n].y = p[n].y - d[n].y;
    // the rest
    int i;
    for(i=1; i<n; i++) {
	t[i] = p[i];  // t_i = p_i for 0 < i < n
    }
    for(i=1; i<n; i++) {
	t[2*n - i] = t[i];  // t_2n-i = t_i for 0 < i < n
    }
    
    
    // calculate the array of vectors d_i
    int k, m, row;
    for(i=1; i<n; i++) {
	//if( n%2 == 1 )  m = n/2;  // if odd, n = 2m + 2
	//else  m = n/2 - 1;  // if even, n = 2m + 2
	//NSLog(@"m = %d", m);
	
	m = n - 1;
	row = n;
	if( m > 7 ) {
	    m = 7;  // never have to consider more than 7 steps away from current point
	    row = 7;  // the k_n_m table only extends so far
	}
	
	d[i].x = 0;
	d[i].y = 0;
	for(k=1; k<=m; k++) {
	    //NSLog(@"a[m][k] = %f", a[m][k]);
	    d[i].x += a[row][k]*(t[i+k].x - t[RSReflect(i-k, n)].x);
	    d[i].y += a[row][k]*(t[i+k].y - t[RSReflect(i-k, n)].y);
	}
    }
    
    //NSLog(@"d[1]: (%f, %f)", d[1].x, d[1].y);
    
    // calculate the q's and the r's from the p's and the d's
    NSPoint q[n+1];
    NSPoint r[n+1];
    for(i=0; i<n; i++) {
	q[i].x = p[i].x + d[i].x;
	q[i].y = p[i].y + d[i].y;
	r[i].x = p[i+1].x - d[i+1].x;
	r[i].y = p[i+1].y - d[i+1].y;
    }
    
    // put it into the specified memory location
    for(i=0; i<=n; i++ ) {
	segs[i][0] = p[i];
	segs[i][1] = q[i];
	segs[i][2] = r[i];
    }
    
    // that's all
}









////////////////////////////////////////////////////////////////////////////////////////


#pragma mark -
#pragma mark Class methods




#pragma mark -
#pragma mark init/dealloc


- (id)init {
    return [self initWithPoints:[[NSMutableArray alloc] init]];
}

// DESIGNATED INITIALIZER
- (id)initWithPoints:(NSMutableArray *)points;
{
    if (!(self = [super init]))
        return nil;
    
    _points = [points retain];
    
    return self;
}

- (void)dealloc;
{
    [_points release];
    
    [super dealloc];
}


#pragma mark -
#pragma mark Managing the spline

- (void)addPointsAtEnd:(NSArray *)newPoints;
{
    [_points addObjectsFromArray:newPoints];
}


#pragma mark -
#pragma mark Using the spline

- (NSArray *)points;
{
    return _points;
}

- (void)putBezierSegmentsInto:(NSPoint[][3])segs;
{
    int n = [_points count] - 1;  // number of points p, minus 1
    
    //if( n < 2 )  return;  // the following doesn't make sense for n < 2 (i.e. count < 3)
    
    // populate array of points p
    NSPoint p[n+1];
    int i = 0;
    NSValue *wrapper;
    for (wrapper in _points) {
	p[i++] = [wrapper pointValue];
    }
    
    // create the a_m_k array, which "starts" at [3][1] and thus has size [16+3][7+1]
    float a[19][8] =
    {
	{  },
	//{  },
	{  },
	//{ 0, 0.333 },  // n=3
	{ 0, 0.25 },  // n=4
	//{ 0, 0.2727, -0.0909 },  // n=5
	{ 0, 0.2677, -0.0667 },  // n=6
	//{ 0, 0.2683, -0.0732, 0.0244 },  // n=7
	{ 0, 0.2679, -0.0714, 0.0179 },  // n=8
	//{ 0, 0.2680, -0.0719, 0.0196, -0.0065 },  // n=9
	{ 0, 0.2679, -0.0718, 0.0191, -0.0048 },  // n=10
	//{ 0, 0.2680, -0.0718, 0.0193, -0.0053, 0.0018 },  // n=11
	{ 0, 0.2679, -0.0718, 0.0192, -0.0051, 0.0013 },  // n=12
	//{ 0, 0.2679, -0.0718, 0.0192, -0.0052, 0.0014, -0.0005 },  // n=13
	{ 0, 0.2679, -0.0718, 0.0192, -0.0052, 0.0014, -0.0003 },  // n=14
	//{ 0, 0.2679, -0.0718, 0.0192, -0.0052, 0.0014, -0.0004, 0.0001 },  // n=15
	{ 0, 0.2679, -0.0718, 0.0192, -0.0052, 0.0014, -0.0004, 0.0001 }  // n=16
    };
    
    NSPoint d[n+1];
    
    // choose initial/final tangent vectors d_0 and d_n
    if( n == 2 ) {  // (count == 3)
	// make the same shape as we had for "simple curves" in the previous version
	float extra = 1.33333;  // (4/3)
	float reduce = 0.5;
	// first control point
	NSPoint cp, ray, p0, p1, p2;
	p0 = p[0];
	p1 = p[1];
	p2 = p[2];
	ray.x = (p1.x - p2.x)*extra;
	ray.y = (p1.y - p2.y)*extra;
	cp.x = p2.x + ray.x;
	cp.y = p2.y + ray.y;
	// derive vector d_0
	d[0].x = (cp.x - p0.x)*reduce;
	d[0].y = (cp.y - p0.y)*reduce;
	
	//visual debugging//[RSGraphRenderer drawCircleAt:cp];
	
	// second control point
	p0 = p[n];
	p1 = p[n - 1];
	p2 = p[n - 2];
	ray.x = (p1.x - p2.x)*extra;
	ray.y = (p1.y - p2.y)*extra;
	cp.x = p2.x + ray.x;
	cp.y = p2.y + ray.y;
	// derive vector d_n
	d[n].x = (p0.x - cp.x)*reduce;
	d[n].y = (p0.y - cp.y)*reduce;
    }
    else {  // the extra curvature is overkill when there are multiple interior points
	d[0] = NSMakePoint(0,0);
	d[n] = NSMakePoint(0,0);
	
	//visual debugging//[RSGraphRenderer drawCircleAt:cp];
    }
    
    
    // construct the "degenerate closed loop" made up of points t
    NSPoint t[2*n];
    // the initial/final special cases
    t[0].x = p[0].x + d[0].x;
    t[0].y = p[0].y + d[0].y;
    t[n].x = p[n].x - d[n].x;
    t[n].y = p[n].y - d[n].y;
    // the rest
    for(i=1; i<n; i++) {
	t[i] = p[i];  // t_i = p_i for 0 < i < n
    }
    for(i=1; i<n; i++) {
	t[2*n - i] = t[i];  // t_2n-i = t_i for 0 < i < n
    }
    
    
    // calculate the array of vectors d_i
    int k, m, row;
    for(i=1; i<n; i++) {
	//if( n%2 == 1 )  m = n/2;  // if odd, n = 2m + 2
	//else  m = n/2 - 1;  // if even, n = 2m + 2
	//NSLog(@"m = %d", m);
	
	m = n - 1;
	row = n;
	if( m > 7 ) {
	    m = 7;  // never have to consider more than 7 steps away from current point
	    row = 7;  // the k_n_m table only extends so far
	}
	
	d[i].x = 0;
	d[i].y = 0;
	for(k=1; k<=m; k++) {
	    //NSLog(@"a[m][k] = %f", a[m][k]);
	    d[i].x += a[row][k]*(t[i+k].x - t[RSReflect(i-k, n)].x);
	    d[i].y += a[row][k]*(t[i+k].y - t[RSReflect(i-k, n)].y);
	}
    }
    
    //NSLog(@"d[1]: (%f, %f)", d[1].x, d[1].y);
    
    // calculate the q's and the r's from the p's and the d's
    NSPoint q[n+1];
    NSPoint r[n+1];
    for(i=0; i<n; i++) {
	q[i].x = p[i].x + d[i].x;
	q[i].y = p[i].y + d[i].y;
	r[i].x = p[i+1].x - d[i+1].x;
	r[i].y = p[i+1].y - d[i+1].y;
    }
    
    // put it into the specified memory location
    for(i=0; i<=n; i++ ) {
	segs[i][0] = p[i];
	segs[i][1] = q[i];
	segs[i][2] = r[i];
    }
    
    // that's all
}



- (NSPoint)locationAtTime:(float)t;
{
    // compute the curve segments
    int n = [_points count] - 1;
    NSPoint segs[n + 1][3];
    [self putBezierSegmentsInto:segs];
    
    // get the control points
    int piece = floor(t*n);
    NSPoint p0 = segs[piece][0];
    NSPoint p1 = segs[piece][1];
    NSPoint p2 = segs[piece][2];
    NSPoint p3 = segs[piece+1][0];
    
    // calculate:
    float pieceT = t*n - piece;
    NSPoint location = evaluateBezierPathAtT(p0, p1, p2, p3, pieceT);
    
    return location;
}


- (void)curvePath:(NSBezierPath *)P alongBezierP0:(NSPoint)p0 p1:(NSPoint)p1 p2:(NSPoint)p2 p3:(NSPoint)p3 start:(float)t1 finish:(float)t2 {
    //
    // calculate Jaakko's formula P' = P B S B^-1
    // the guts, and some documentation, are in the function matrixMultiplyWithBSBInv()
    //
    
    // convert to control point arrays
    float px[] = {	p0.x,	p1.x,	p2.x,	p3.x	};  // P [x row]
    float py[] = {	p0.y,	p1.y,	p2.y,	p3.y	};  // P [y row]
    float rx[4];
    float ry[4];
//    float a, b;
//    if( t1 <= t2 ) {
//	a = t1;
//	b = t2;
//    } else {
//	a = t2;
//	b = t1;
//    }
    
    // do the calculations
    matrixMultiplyWithBSBInv(px, rx, t1, t2);
    matrixMultiplyWithBSBInv(py, ry, t1, t2);
    
    // convert back to NSPoints
    NSPoint r0, r1, r2, r3;
    r0 = NSMakePoint(rx[0], ry[0]);
    r1 = NSMakePoint(rx[1], ry[1]);
    r2 = NSMakePoint(rx[2], ry[2]);
    r3 = NSMakePoint(rx[3], ry[3]);
    
    // extend the actual path
    [P curveToPoint:r3 
      controlPoint1:r1
      controlPoint2:r2];
}


- (void)curvePath:(NSBezierPath *)P alongSplineUsingStart:(float)gt1 finish:(float)gt2;
{
    // calculate the bezier segments
    int n = [_points count] - 1;
    NSPoint segs[n + 1][3];
    [self putBezierSegmentsInto:segs];
    
    // setup vars
    NSPoint p0, p1, p2, p3;
    float t1, t2;  // "local" (piecewise) times, i.e. 0..1 from start to end of bezier segment
    int piece;
    
    if( gt1 < gt2 ) {
	// init
	piece = floor(gt1*n);
	t1 = gt1*n - piece;
	// iterate through the piecewise segments
	while( piece < gt2*n - 0.0001 ) {
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
	    [self curvePath:P alongBezierP0:p0 p1:p1 p2:p2 p3:p3 start:t1 finish:t2];
	    
	    // go to the next piece
	    piece++;
	    t1 = 0;
	}
    }
    else {  // gt2 <= gt1
	// init
	piece = floor(gt1*n);
	t2 = gt1*n - piece;
	// iterate (backwards) through the piecewise segments
	while( piece >= floor(gt2*n) ) {
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
	    [self curvePath:P alongBezierP0:p0 p1:p1 p2:p2 p3:p3 start:t2 finish:t1];
	    
	    // go to the next piece
	    piece-=1;
	    t2 = 1;
	}
    }
}


@end
