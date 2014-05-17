// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <GraphSketcherModel/NSBezierPath-RSExtensions.h>


#pragma mark Bezier functions

///////
// The following is taken from the Graphics Gems I (1990) article: "Explicit cubic spline interpolation formulas" by Richard Rasala
//
// "wraps" integer i around a loop of length n
NSInteger RSWrap(NSInteger i, NSInteger n) {
    NSInteger iwrap = i;
    while( iwrap < 0 )  iwrap += n;
    
    if( iwrap%n >= 19 ) {
	NSLog(@"uh-oh");
    }
    
    return iwrap%n;
}
// "reflects" integer i across a range 0...n
NSInteger RSReflect(NSInteger i, NSInteger n) {
    NSInteger ir = i;
    //if( i > n )  ir = 2*n - i;
    if( i < 0 )  ir = -1*i;
    
    if( i < (-n) )  NSLog(@"i is too negative in RSReflect");
    
    return ir;
}


///////
// Evaluate a bezier path with control points p0, p1, p2, p3 at parametric value 0 <= t <= 1
//
CGPoint evaluateBezierPathAtT(CGPoint p0, CGPoint p1, CGPoint p2, CGPoint p3, CGFloat t) {
    // (From the graphics textbook p. 611)
    // The parametric formula for a Bezier curve based on four points is:
    // P(t) = P_0(1 - t)^3 + P_1*3(1 - t)^2*t + P_2*3(1 - t)*t^2 + P_3*t^3
    // 
    // where P_0 and P_3 are endpoints and P_1 and P_2 are control points
    //
    
    CGPoint s;  // the result
    
    // this won't hurt anything
    //if( t < 0 || t > 1 ) {
    //	NSLog(@"t is not in range [0, 1]");
    //	return CGPointMake(0,0); // is there a better way to throw an error?
    //}
    
    s.x =  p0.x*(1 - t)*(1 - t)*(1 - t)
    + p1.x*3*(1 - t)*(1 - t)*t
    + p2.x*3*(1 - t)*t*t
    + p3.x*t*t*t
    ;
    s.y =  p0.y*(1 - t)*(1 - t)*(1 - t)
    + p1.y*3*(1 - t)*(1 - t)*t
    + p2.y*3*(1 - t)*t*t
    + p3.y*t*t*t
    ;
    
    return s;
}

// Takes bezier path p (an array of the 4 control points) and calculates a bezier path 
// with the same curvature as p but with start t1 and end t2.  
// Puts this new bezier path in r.
CGFloat* matrixMultiplyWithBSBInv(CGFloat* p, CGFloat* r, CGFloat t1, CGFloat t2) {
    // There is more documentation (as of Jan '08) at: 
    //   ../Graph Sketcher related/technical/Bezier interval calculation.txt
    //
    // In short, we use Jaakko's matrix formula...
    //
    // P' = P B S B^-1,
    //
    // which means we multiply the original control point matrix (P) with BSB^-1 to get
    // the new control points.  We don't really have to do it for p0 and p3 because we can
    // calculate those directly from the original bezier path.
    // ---------------------------
    //
    // P = 
    // [	p0.x,	p1.x,	p2.x,	p3.x	]
    // [	p0.y,	p1.y,	p2.y,	p3.y	]
    //
    //
    // B*S*inv(B) =
    //	
    // [           1-3*a+3*a^2-a^3,   1-2*a+a^2-b+2*b*a-b*a^2,   1-a-2*b+2*b*a+b^2-b^2*a,           1-3*b+3*b^2-b^3]
    // [           3*a-6*a^2+3*a^3, 2*a-2*a^2+b-4*b*a+3*b*a^2, a+2*b-4*b*a-2*b^2+3*b^2*a,           3*b-6*b^2+3*b^3]
    // [               3*a^2-3*a^3,         a^2+2*b*a-3*b*a^2,         2*b*a+b^2-3*b^2*a,               3*b^2-3*b^3]
    // [                       a^3,                     b*a^2,                     b^2*a,                       b^3]
    //
    
    CGFloat a = t1;
    CGFloat b = t2;
    //CGFloat p[] = {	p0.x,	p1.x,	p2.x,	p3.x	};  // P
    //CGFloat r[4];  // P'
    
    r[0] = p[0] * (1-3*a+3*a*a-a*a*a)
    + p[1] * (3*a-6*a*a+3*a*a*a)
    + p[2] * (3*a*a-3*a*a*a)
    + p[3] * (a*a*a)
    ;
    r[1] = p[0] * (1-2*a+a*a-b+2*b*a-b*a*a)
    + p[1] * (2*a-2*a*a+b-4*b*a+3*b*a*a)
    + p[2] * (a*a+2*b*a-3*b*a*a)
    + p[3] * (b*a*a)
    ;
    r[2] = p[0] * (1-a-2*b+2*b*a+b*b-b*b*a)
    + p[1] * (a+2*b-4*b*a-2*b*b+3*b*b*a)
    + p[2] * (2*b*a+b*b-3*b*b*a)
    + p[3] * (b*b*a)
    ;
    r[3] = p[0] * (1-3*b+3*b*b-b*b*b)
    + p[1] * (3*b-6*b*b+3*b*b*b)
    + p[2] * (3*b*b-3*b*b*b)
    + p[3] * (b*b*b)
    ;
    
    return r;
}


@implementation NSBezierPath (RSExtensions)

////////////////////////////////
#pragma mark Convenience constructors
//////
- (NSBezierPath *)appendArrowheadAtPoint:(CGPoint)p width:(CGFloat)b height:(CGFloat)c;
// construct an arrow head
{
    [self moveToPoint:CGPointMake(p.x, p.y)];
    [self lineToPoint:CGPointMake(p.x + b*2, p.y - c)];
    [self lineToPoint:CGPointMake(p.x + b, p.y)];
    [self lineToPoint:CGPointMake(p.x + b*2, p.y + c)];
    [self closePath];
    
    return self;
}
+ (NSBezierPath *)arrowheadWithBaseAtPoint:(CGPoint)p width:(CGFloat)b height:(CGFloat)c;
{
    // construct an arrow head
    NSBezierPath *P = [NSBezierPath bezierPath];
    
    [P moveToPoint:CGPointMake(p.x - b, p.y)];
    [P lineToPoint:CGPointMake(p.x + b, p.y - c)];
    [P lineToPoint:CGPointMake(p.x, p.y)];
    [P lineToPoint:CGPointMake(p.x + b, p.y + c)];
    //[P moveToPoint:CGPointMake(p.x, p.y)];
    //[P lineToPoint:CGPointMake(p.x + 2*b, p.y - c)];
    //[P lineToPoint:CGPointMake(p.x + b, p.y)];
    //[P lineToPoint:CGPointMake(p.x + 2*b, p.y + c)];
    [P closePath];
    
    return P;
}

// constructs a path to be filled.  p is in view coords.
- (NSBezierPath *)appendTickAtPoint:(CGPoint)p width:(CGFloat)w height:(CGFloat)h;
{
    CGFloat b = h/2;
    CGFloat c = w/2;
    
    // construct path
    [self moveToPoint:CGPointMake(p.x + c, p.y + b)];
    [self lineToPoint:CGPointMake(p.x - c, p.y + b)];
    [self lineToPoint:CGPointMake(p.x - c, p.y - b)];
    [self lineToPoint:CGPointMake(p.x + c, p.y - b)];
    [self closePath];
    
    return self;
}
/* stroke version
 + (NSBezierPath *)tickAtPoint:(CGPoint)p width:(CGFloat)w height:(CGFloat)h {
 NSBezierPath *P = [NSBezierPath bezierPath];
 
 // construct path
 [P moveToPoint:CGPointMake(p.x, p.y + h/2)];
 [P lineToPoint:CGPointMake(p.x, p.y - h/2)];
 
 [P setLineWidth:w];
 return P;
 }
 */


////////////////////////////////
#pragma mark Appending to the bezier path
//////
- (void)curveAlongBezierP0:(CGPoint)p0 p1:(CGPoint)p1 p2:(CGPoint)p2 p3:(CGPoint)p3 start:(CGFloat)t1 finish:(CGFloat)t2;
{
    //
    // calculate Jaakko's formula P' = P B S B^-1
    // the guts, and some documentation, are in the function matrixMultiplyWithBSBInv()
    //
    
    // convert to control point arrays
    CGFloat px[] = {	p0.x,	p1.x,	p2.x,	p3.x	};  // P [x row]
    CGFloat py[] = {	p0.y,	p1.y,	p2.y,	p3.y	};  // P [y row]
    CGFloat rx[4];
    CGFloat ry[4];
//    CGFloat a, b;
//    if( t1 <= t2 ) {
//	a = t1;
//	b = t2;
//    } else {
//	a = t2;
//	b = t1;
//    }

//    for(NSInteger i = 0; i < 4; i ++) {
//        assert(isfinite(px[i]));
//        assert(isfinite(py[i]));
//    }    
    
    // do the calculations
    matrixMultiplyWithBSBInv(px, rx, t1, t2);
    matrixMultiplyWithBSBInv(py, ry, t1, t2);
    
    
//    for(NSInteger i = 0; i < 4; i ++) {
//        assert(isfinite(rx[i]));
//        assert(isfinite(ry[i]));
//    }
    
    // convert back to CGPoints
    //CGPoint r0 = CGPointMake(rx[0], ry[0]);
    CGPoint r1 = CGPointMake(rx[1], ry[1]);
    CGPoint r2 = CGPointMake(rx[2], ry[2]);
    CGPoint r3 = CGPointMake(rx[3], ry[3]);
    
    // extend the actual path
    [self curveToPoint:r3 controlPoint1:r1 controlPoint2:r2];
}



////////////////////////////////
#pragma mark Manipulating the bezier path
//////

- (void)rotateInFrame:(CGRect)r byDegrees:(CGFloat)degrees;
{
    if (degrees == 0)
        return;
    
    CGAffineTransform AT = CGAffineTransformIdentity;
    
    // The following three commands get applied in reverse order
    AT = CGAffineTransformTranslate(AT, r.origin.x, r.origin.y);
    AT = CGAffineTransformRotate(AT, (CGFloat)(degrees * (2*M_PI/360)));
    AT = CGAffineTransformTranslate(AT, -r.origin.x, -r.origin.y);
    
#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
    [self applyTransform:AT];
#else
    {
        NSAffineTransform *transform = [NSAffineTransform transform];
        [transform setTransformStruct:*(NSAffineTransformStruct *)&AT];
        [self transformUsingAffineTransform:transform];
    }
#endif
}



////////////////////////////////////////
#pragma mark -
#pragma mark Interpolating splines
////////////////////////////////////////
// Writes into segs[0] through segs[n] inclusive (segs must be n+1 long)
+ (void)interpolatingSplineBezierSegmentsFromPoints:(CGPoint[])p length:(NSInteger)n putInto:(CGPoint[][3])segs;
{
    if(n==0)
        return;
    //
    // This algorithm is taken from the Graphics Gems I (1990) article: 
    // "Explicit cubic spline interpolation formulas" by Richard Rasala
    //
    
    // create the a_m_k array, which "starts" at [3][1] and thus has size [16+3][7+1]
    CGFloat a[19][8] =
    /*a =*/ {
	{  },
	//{  },
	{  },
	//{ 0, 0.333 },  // n=3
	{ 0, 0.25f },  // n=4
	//{ 0, 0.2727, -0.0909 },  // n=5
	{ 0, 0.2677f, -0.0667f },  // n=6
	//{ 0, 0.2683, -0.0732, 0.0244 },  // n=7
	{ 0, 0.2679f, -0.0714f, 0.0179f },  // n=8
	//{ 0, 0.2680, -0.0719, 0.0196, -0.0065 },  // n=9
	{ 0, 0.2679f, -0.0718f, 0.0191f, -0.0048f },  // n=10
	//{ 0, 0.2680, -0.0718, 0.0193, -0.0053, 0.0018 },  // n=11
	{ 0, 0.2679f, -0.0718f, 0.0192f, -0.0051f, 0.0013f },  // n=12
	//{ 0, 0.2679, -0.0718, 0.0192, -0.0052, 0.0014, -0.0005 },  // n=13
	{ 0, 0.2679f, -0.0718f, 0.0192f, -0.0052f, 0.0014f, -0.0003f },  // n=14
	//{ 0, 0.2679, -0.0718, 0.0192, -0.0052, 0.0014, -0.0004, 0.0001 },  // n=15
	{ 0, 0.2679f, -0.0718f, 0.0192f, -0.0052f, 0.0014f, -0.0004f, 0.0001f }  // n=16
    };
    
    CGPoint d[n+1];
    
    NSInteger i;
    for(i=0; i<=n; i++)
        d[i] = CGPointMake(0,0);
    
    // choose initial/final tangent vectors d_0 and d_n
    if( n == 2 )   // (count == 3)
    {
	// make the same shape as we had for "simple curves" in legacy Graph Sketcher
	CGFloat extra = 1.33333f;  // (4/3)
	CGFloat reduce = 0.5f;
	// first control point
	CGPoint cp, ray, p0, p1, p2;
	p0 = p[0];
	p1 = p[1];
	p2 = p[2];
	ray.x = (p1.x - p2.x)*extra;
	ray.y = (p1.y - p2.y)*extra;
	cp.x = p2.x + ray.x;
	cp.y = p2.y + ray.y;
	// derive vector d_0
	d[0] = CGPointMake((cp.x - p0.x)*reduce, (cp.y - p0.y)*reduce);
	
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
	d[0] = CGPointMake(0,0);
	d[n] = CGPointMake(0,0);
	
	//visual debugging//[RSGraphRenderer drawCircleAt:cp];
    }
    
    
    // construct the "degenerate closed loop" made up of points t
    CGPoint t[2*n];
    
    for(i=0; i<2*n; i++)
        t[i] = CGPointMake(0, 0);
    
    
    // the initial/final special cases
    t[0] = CGPointMake(p[0].x + d[0].x, p[0].y + d[0].y);
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
    NSInteger m = n - 1;
    NSInteger row = n;
    if( m > 7 ) {
        m = 7;  // never have to consider more than 7 steps away from current point
        row = 7;  // the k_n_m table only extends so far
    }
    for(i=1; i<n; i++) {
	//if( n%2 == 1 )  m = n/2;  // if odd, n = 2m + 2
	//else  m = n/2 - 1;  // if even, n = 2m + 2
	//NSLog(@"m = %d", m);
	
	
	d[i].x = 0;
	d[i].y = 0;
	for(NSInteger k=1; k<=m; k++) {
	    //NSLog(@"a[m][k] = %f", a[m][k]);
	    d[i].x += a[row][k]*(t[i+k].x - t[RSReflect(i-k, n)].x);
	    d[i].y += a[row][k]*(t[i+k].y - t[RSReflect(i-k, n)].y);
	}
    }
    
    //NSLog(@"d[1]: (%f, %f)", d[1].x, d[1].y);
    
    // calculate the q's and the r's from the p's and the d's
    CGPoint q[n+1];
    CGPoint r[n+1];
    for(i=0; i<n; i++) {
	q[i].x = p[i].x + d[i].x;
	q[i].y = p[i].y + d[i].y;
	r[i].x = p[i+1].x - d[i+1].x;
	r[i].y = p[i+1].y - d[i+1].y;
    }
    
    // put it into the specified memory location
    for(i=0; i<n; i++ ) {
        segs[i][0] = p[i];
        segs[i][1] = q[i];
        segs[i][2] = r[i];
    //        for(NSInteger c = 0; c < 3; c ++) {
    //            assert(isfinite(segs[i][c].x));
    //            assert(isfinite(segs[i][c].y));
    //        }
    }
    segs[n][0] = p[n];  // the last segment only has its start point, p

    // that's all
}


@end
