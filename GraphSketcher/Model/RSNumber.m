// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/Model/RSNumber.m 200244 2013-12-10 00:11:55Z correia $

#import <GraphSketcherModel/RSNumber.h>

#if !defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE
#import <AppKit/NSPanel.h>
#endif

RSDataPoint RSDataPointMake(data_p x, data_p y) {
    RSDataPoint p;
    p.x = x;
    p.y = y;
    
    return p;
}

NSValue *NSValueFromDataPoint(RSDataPoint p)
{
    return [NSValue valueWithBytes:&p objCType:@encode(RSDataPoint)];
}

RSDataPoint dataPointFromNSValue(NSValue *value)
{
    RSDataPoint p;
    [value getValue:&p];
    return p;
}

NSString *NSStringFromRSDataPoint(RSDataPoint p)
{
    return [NSString stringWithFormat:@"(%g, %g)", p.x, p.y];
}



// functions

BOOL pointIsFinite(CGPoint p) {
    // i.e. x and y values are not nan, infinite, etc.
    return isfinite(p.x) && isfinite(p.y);
}  

BOOL nearlyEqualFloats(CGFloat a, CGFloat b) {
    if( fabs(a - b) > 0.0001 )  return NO;
    return YES;
}

BOOL nearlyEqualDataValues(data_p a, data_p b) {
    // We consider data to be nearly equal if there is not going to be enough precision left over to do a decent amount of math operations.
    // Double-precision values have 15 reliable decimal places. To allow slop for other operations such as log() or cos(), we'll be conservative and call anything that differs only past 12 decimal places to be "nearly equal."
    // Using the 12 decimal place cutoff, these numbers are considered "nearly equal":  3e-41, 3.000000000001e-41
    // whereas these numbers are considered NOT nearly equal:  3e-41, 3.00000000001e-41
    
    if (!isfinite(a) || !isfinite(b))
        return NO;
    
    if (a == 0 && b == 0)
        return YES;
    
    if (a == 0 || b == 0) {
        return (fabs(a - b) < 1e-305);  // 1e-308 is approx the smallest representable double
    }
    
    data_p ratio = a/b;
    data_p wantedPrecision = 1e-12;
    return (fabs(1 - ratio) < wantedPrecision);
}

BOOL nearlyEqualPoints(CGPoint a, CGPoint b) {
    return nearlyEqualFloats(a.x, b.x) && nearlyEqualFloats(a.y, b.y);
}

BOOL nearlyEqualDataPoints(RSDataPoint a, RSDataPoint b) {
    return nearlyEqualDataValues(a.x, b.x) && nearlyEqualDataValues(a.y, b.y);
}

data_p magnitudeOfRangeRelativeToZero(data_p min, data_p max) {
    // Adjust for all-negative case:
    if (min < 0 && max < 0) {
        data_p temp = min;
        min = -max;
        max = -temp;
    }
    
    // Orders of magnitude spanned relative to the distance from zero:
    return (max - min)/(min/* - 0*/);
}


CGPoint CGRectGetMaxes(CGRect r) {
    return CGPointMake(CGRectGetMaxX(r), CGRectGetMaxY(r));
}

CGFloat nearestPixel(CGFloat f) {
    return floor(f) + 0.5f;
}

// Calculates the distance between points p1 and p2
CGFloat distanceBetweenPoints(CGPoint p1, CGPoint p2) {
    return hypot(p2.x - p1.x, p2.y - p1.y);
}

CGPoint v2Normalized(CGPoint v) {
    CGFloat length = hypot(v.x, v.y);
    return CGPointMake(v.x/length, v.y/length);
}

CGFloat v2Angle(CGPoint v)
// (in radians)
{
    if (nearlyEqualFloats(v.x, 0)) {
	if (v.y >= 0)  return (CGFloat)M_PI_2;
	else  return (CGFloat)(3*M_PI_2);
    }
    
    return atan(v.y/v.x);
}


// Finds the angle, in degrees, between the right-pointing vector (1,0) and a line
CGFloat degreesFromHorizontalOfVector(CGPoint p1, CGPoint p2) {
    //! there's probably a faster way to do this with vector math
    CGFloat a = p2.x - p1.x;
    CGFloat b = p2.y - p1.y;
    CGFloat m;
    if (a != 0)
	m = b/a;  // slope
    else {
	if (b < 0)
	    m = -100000;
	else
	    m = 100000;
    }
    
    CGFloat angle = (CGFloat)((atan(m))*180/M_PI);  // calculate angle and convert to degrees

    if ( p2.x < p1.x )  angle += 180;
    return angle;
}


CGPoint evaluateStraightLineAtT(CGPoint p0, CGPoint p1, CGFloat t) {
    // The parametric formula for a simple line is:
    // P(t) = P_0*(1-t) + P_1*(t)
    
    CGPoint s;  // the result
    s.x = p0.x*(1-t) + p1.x*t;
    s.y = p0.y*(1-t) + p1.y*t;
    
    return s;
}

// Finds the closest point on an RSLine by "constructing" a perpendicular
// line and taking the distance to the intersection point, or the distance to the
// closest end vertex if the intersection point is outside the bounds of the line segment.
// DONE IN VIEW COORDS!
CGPoint closestPointOnStraightLineToP(CGPoint p0, CGPoint p1, CGPoint p) {
    CGPoint r, min, max;	// intersection, min corner, max corner
    CGFloat m, m2;	// slope of line, slope of perpendicular line
    //CGFloat w;	// allowed perpendicular distance from line
    CGFloat d1, d2;	// actual perpendicular distance of test point from line
    CGFloat a, b; // intermediate variables
    BOOL isVertical = NO;
    BOOL isHorizontal = NO;
    
    // calculate slopes:
    if ( p1.x - p0.x != 0 ) {
	m = (p1.y - p0.y) / (p1.x - p0.x);
    } else {
	isVertical = YES;
	m = 1000;
    }
    if ( p1.y - p0.y != 0 ) {
	m2 = (p0.x - p1.x) / (p1.y - p0.y);   // (perpendicular -1/m)
    } else {
	isHorizontal = YES;
	m2 = 1000;
    }
    // calculate intersection point:
    r.x = (p.y - p0.y + m*p0.x - m2*p.x) / (m - m2);
    r.y = m*(r.x - p0.x) + p0.y;
    
    // determine max and min corners:
    if ( p0.x > p1.x ) {
	min.x = p1.x;
	max.x = p0.x;
    } else {
	min.x = p0.x;
	max.x = p1.x;
    }
    if ( p0.y > p1.y ) {
	min.y = p1.y;
	max.y = p0.y;
    } else {
	min.y = p0.y;
	max.y = p1.y;
    }
    // if the intersection is outside extremal corners, distance is to closest end vertex
    if ( (!isVertical && r.x > max.x) || (!isVertical && r.x < min.x) 
	|| (!isHorizontal && r.y > max.y) || (!isHorizontal && r.y < min.y) ) {
	// calculate distance to each endpoint:
	a = p.x - p0.x;
	b = p.y - p0.y;
	d1 = sqrt(a*a + b*b);
	a = p.x - p1.x;
	b = p.y - p1.y;
	d2 = sqrt(a*a + b*b);
	// closest one is the nearest point on the line
	if ( d1 <= d2 )  r = p0;
	else  r = p1;
    }
    return r;
}

// Finds the perpendicular distance between a point and a straight line with given start and end points.
CGFloat distanceBetweenPointAndStraightLine(CGPoint p, CGPoint start, CGPoint end) {
    return distanceBetweenPoints(p, closestPointOnStraightLineToP(start, end, p));
}


// Returns the intersection point of straight lines with given start and end points.  This intersection point could be beyond the end points!
CGPoint lineIntersection(CGPoint p1, CGPoint p2, CGPoint q1, CGPoint q2) {
    CGPoint i;  // intersection
    CGFloat m, n;  // slopes
    
    if (!pointIsFinite(p1) || !pointIsFinite(p2) || !pointIsFinite(q1) || !pointIsFinite(q2)) {
#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
        // TODO: Create an email message for them? Crash so we get a crash report with a backtrace? Or just return an infinite/invalid point instead of worrying the user about this? See <bug://bugs/58890> (How should we handle unexpected errors such as non-finite points in RSNumber's lineIntersection() function?)
        UIAlertView *alert = [[[UIAlertView alloc] initWithTitle:@"Invalid state reached" message:@"We recommend that you quit and relaunch OmniGraphSketcher, then alert the developers using Send Feedback.\n\nReason: A non-finite point value was detected when calculating a line intersection." delegate:nil cancelButtonTitle:NSLocalizedStringFromTableInBundle(@"Cancel", @"GraphSketcherModel", OMNI_BUNDLE, @"button title") otherButtonTitles:nil] autorelease];
        [alert show];
#else
        NSRunAlertPanel(@"Invalid state reached.", @"We recommend that you quit and relaunch OmniGraphSketcher, then alert the developers using the Help > Send Feedback menu item.\n\nReason: A non-finite point value was detected when calculating a line intersection.", @"Continue", nil, nil);
#endif
    }
    
    // calculate slopes, watching for div by 0 (vertical lines)
    if ( nearlyEqualFloats(p2.x - p1.x, 0) )
        m = 1000;
    else
        m = (p2.y - p1.y)/(p2.x - p1.x);
    
    if ( nearlyEqualFloats(q2.x - q1.x, 0) )
        n = 1000;
    else
        n = (q2.y - q1.y)/(q2.x - q1.x);
    
    // calculate intersection, again watching for div by 0 (parallel lines)
    if ( fabs(m - n) < 0.001 )
        n += 0.001f;  // this will shoot the "intersection" way off the screen
    OBASSERT(!nearlyEqualFloats(m - n, 0));
    i.x = (m*p1.x - p1.y - n*q1.x + q1.y)/(m - n);
    i.y = m*(i.x - p1.x) + p1.y;
    
    //NSLog(@"Intersection: %f, %f", i.x, i.y);
    return i;
}

//CGFloat dotProduct(CGPoint v1, CGPoint v2) {
//    return v1.x*v2.x + v1.y*v2.y;
//}
//
//BOOL segmentsIntersect(CGPoint p1, CGPoint p2, CGPoint q1, CGPoint q2) {
//    CGPoint qNormal = CGPointMake(q1.y - q2.y, q2.x - q1.x);
//    CGFloat t1 = dotProduct(qNormal, CGPointMake(q1.x - p1.x, q1.y - p1.y));
//    CGFloat t2 = dotProduct(qNormal, CGPointMake(p2.x - p1.x, p2.y - p1.y));
//    
//    if (t2 == 0) {  // parallel
//        return FALSE;
//    }
//    CGFloat t = t1/t2;
//    CGPoint i = CGPointMake(p1.x + t*(p2.x - p1.x), p1.y + t*(p2.y - p1.y));
//    
//}

BOOL rectClipsLine(CGRect rect, CGPoint p1, CGPoint p2) {
    // If either point is inside the rect, trivially accept
    if (CGRectContainsPoint(rect, p1) || CGRectContainsPoint(rect, p2))
        return YES;
    
    // from NSBezierPath-OAExtensions _straightLineIntersectsRect()
    CGPoint v = CGPointMake(p2.x - p1.x, p2.y - p1.y);  // vector along length of line
    if (v.x != 0) {
        CGFloat t = (CGRectGetMinX(rect) - p1.x)/v.x;
        CGFloat y;
        if (t >= 0 && t <= 1) {
            y = t * v.y + p1.y;
            if (y >= CGRectGetMinY(rect) && y < CGRectGetMaxY(rect)) {
                return YES;
            }
        }
        t = (CGRectGetMaxX(rect) - p1.x)/v.x;
        if (t >= 0 && t <= 1) {
            y = t * v.y + p1.y;
            if (y >= CGRectGetMinY(rect) && y < CGRectGetMaxY(rect)) {
                return YES;
            }
        }
    }
    if (v.y != 0) {
        CGFloat t = (CGRectGetMinY(rect) - p1.y)/v.y;
        CGFloat x;
        if (t >= 0 && t <= 1) {
            x = t * v.x + p1.x;
            if (x >= CGRectGetMinX(rect) && x < CGRectGetMaxX(rect)) {
                return YES;
            }
        }
        t = (CGRectGetMaxY(rect) - p1.y)/v.y;
        if (t >= 0 && t <= 1) {
            x = t * v.x + p1.x;
            if (x >= CGRectGetMinX(rect) && x < CGRectGetMaxX(rect)) {
                return YES;
            }
        }
    }
    
    return NO;
}

BOOL rectIntersectsRotatedRect(CGRect rect, CGRect r, CGFloat degrees) {
    CGPoint mins = CGPointMake(CGRectGetMinX(r), CGRectGetMinY(r));
    CGPoint maxes = CGPointMake(CGRectGetMaxX(r), CGRectGetMaxY(r));
    
    CGPoint p[4] = {
        { .x=mins.x, .y=mins.y },
        { .x=mins.x, .y=maxes.y },
        { .x=maxes.x, .y=maxes.y },
        { .x=maxes.x, .y=mins.y },
    };
    
    CGAffineTransform AT = CGAffineTransformIdentity;
    
    // The following three commands get applied in reverse order
    AT = CGAffineTransformTranslate(AT, r.origin.x, r.origin.y);
    AT = CGAffineTransformRotate(AT, (CGFloat)(degrees * (2*M_PI/360)));
    AT = CGAffineTransformTranslate(AT, -r.origin.x, -r.origin.y);
    
    // Apply the affine transform to each rect corner
    for (NSInteger i = 0; i < 4; i += 1) {
        p[i] = CGPointApplyAffineTransform(p[i], AT);
    }
    
    // See if any of the rotated sides intersect the non-rotated rect.
    for (NSInteger i = 0; i < 4; i += 1) {
        CGPoint p1 = p[i];
        CGPoint p2 = p[(i + 1)%4];
        if (rectClipsLine(rect, p1, p2)) {
            return YES;
        }
    }
    
    // If got this far
    return NO;
}


CGFloat trimToMinMax(CGFloat p, CGFloat min, CGFloat max)
{
    if (p < min) {
	p = min;
    }
    else if (p > max) {
	p = max;
    }
    return p;
}

CGSize RSUnionSize(CGSize s1, CGSize s2)
{
    CGSize unionSize = s1;
    if (s2.width > s1.width)  unionSize.width = s2.width;
    if (s2.height > s1.height)  unionSize.height = s2.height;
    
    return unionSize;
}

CGFloat RSMinSizeDimension(CGSize size)
{
    if (size.width < size.height)
        return size.width;
    return size.height;
}

CGSize RSSizeRotate(CGSize size, CGFloat degrees)
{
    if (!degrees) {
        return size;
    }
    
    float radians = (float)degrees*(float)M_PI/180.0f;
    CGSize rotatedSize;
    rotatedSize.width = fabs(size.width*cosf(radians)) + fabs(size.height*sinf(radians));
    rotatedSize.height = fabs(size.width*sinf(radians)) + fabs(size.height*cosf(radians));
    //NSLog(@"size: %@, rotatedSize: %@", NSStringFromSize(size), NSStringFromSize(rotatedSize));
    return rotatedSize;
}

CGPoint rotatePointInFrameByDegrees(CGPoint p, CGRect r, CGFloat degrees)
{
    if (degrees == 0)
        return p;
    
    CGAffineTransform AT = CGAffineTransformIdentity;
    
    // The following three commands get applied in reverse order
    AT = CGAffineTransformTranslate(AT, r.origin.x, r.origin.y);
    AT = CGAffineTransformRotate(AT, (CGFloat)(degrees * (2*M_PI/360)));
    AT = CGAffineTransformTranslate(AT, -r.origin.x, -r.origin.y);
    
    return CGPointApplyAffineTransform(p, AT);
}

data_p inverseNormalProbability(data_p p)
{
    data_p t = (p > .5) ? (1 - p) : p;
    data_p s = sqrt(-2.0 * log(t));
    data_p a = 2.515517 + (0.802853 * s) + (0.010328 * s * s);
    data_p b = 1 + (1.432788 * s) + (0.189269 * s * s) + (0.001308 * s * s * s);
    OBASSERT(b != 0);
    data_p u = s - (a / b);
    return (p < .5) ? (- u) : u;
}

data_p addJitter(data_p val, data_p stddev) {
    data_p randProb = random()/(data_p)RAND_MAX;
    data_p jitter = inverseNormalProbability(randProb);
    return val + jitter*stddev;
}


@implementation RSNumber


+ (NSString *)formatNumberForExport:(data_p)val;
{
    // Format with "%.15g" like we do when archiving to XML
    return [NSString stringWithFormat:@"%.*g", DBL_DIG, val];
}


static NSNumberFormatter *_strictNumberFormatter;

+ (BOOL)getStrictDoubleValue:(double *)doubleVal forString:(NSString *)string;
// Unfortunately, I was not able to configure a number formatter to reject strings that contain a number followed by other characters, such as "5k". <bug:///72619>
{
    if (!_strictNumberFormatter) {
        _strictNumberFormatter = [[NSNumberFormatter alloc] init];
        [_strictNumberFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
        
        [_strictNumberFormatter setZeroSymbol:@"0"];
        [_strictNumberFormatter setUsesGroupingSeparator:YES];
        [_strictNumberFormatter setLenient:NO];
    }
    
    NSNumber *number = [_strictNumberFormatter numberFromString:string];
    if (number) {
        *doubleVal = [number doubleValue];
        return YES;
    }
    return NO;
}

+ (BOOL)getStricterDoubleValue:(double *)doubleVal forString:(NSString *)string;
{
    NSScanner *scanner = [NSScanner localizedScannerWithString:string];
    
    BOOL scannedDouble = [scanner scanDouble:doubleVal];
    BOOL isAtEnd = [scanner isAtEnd];
    
    if( scannedDouble && isAtEnd ) {
	return YES;
    }
    return NO;
}


@end
