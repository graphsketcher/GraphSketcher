// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/Model/RSNumber.h 200244 2013-12-10 00:11:55Z correia $

#import <OmniFoundation/OFObject.h>

// OS version
#ifndef NSAppKitVersionNumber10_4
#define	NSAppKitVersionNumber10_4 824
#endif


#if 1 && defined(DEBUG_robin)
#define DEBUG_RS(format, ...) NSLog((format), ## __VA_ARGS__)
#else
#define DEBUG_RS(format, ...)
#endif


// ************************
// Useful constants
//
#define PITIMES2	6.283185	/* 2 * pi */
#define PIOVER2		1.570796	/* pi / 2 */
#define PIOVER4		0.785398	/* pi / 4 */
#define ECONST		2.718282	/* the venerable e */
#define SQRT2		1.414214	/* sqrt(2) */
#define SQRT3		1.732051	/* sqrt(3) */
#define GOLDEN		1.618034	/* the golden ratio */
#define DTOR		0.017453	/* convert degrees to radians */
#define RTOD		57.29578	/* convert radians to degrees */

#define BIGGEST_INTEGER NSIntegerMax
// ************************

@class NSBezierPath;

// Data type definitions
typedef double data_p;  // one data value dimension

typedef struct _RSDataPoint {  // a two-dimensional data point
    data_p x;
    data_p y;
} RSDataPoint;

RSDataPoint RSDataPointMake(data_p x, data_p y);
NSValue *NSValueFromDataPoint(RSDataPoint p);
RSDataPoint dataPointFromNSValue(NSValue *value);
NSString *NSStringFromRSDataPoint(RSDataPoint p);

// ************************

// functions
BOOL pointIsFinite(CGPoint p);  // i.e. x and y values are not nan, infinite, etc.
BOOL nearlyEqualFloats(CGFloat a, CGFloat b);
BOOL nearlyEqualDataValues(data_p a, data_p b);
BOOL nearlyEqualPoints(CGPoint a, CGPoint b);
BOOL nearlyEqualDataPoints(RSDataPoint a, RSDataPoint b);
data_p magnitudeOfRangeRelativeToZero(data_p min, data_p max);

CGPoint CGRectGetMaxes(CGRect r);
CGFloat nearestPixel(CGFloat f);
CGFloat distanceBetweenPoints(CGPoint p1, CGPoint p2);
CGPoint v2Normalized(CGPoint v);
CGFloat v2Angle(CGPoint v);  // (in radians)
CGFloat degreesFromHorizontalOfVector(CGPoint p1, CGPoint p2);
CGPoint evaluateStraightLineAtT(CGPoint p0, CGPoint p1, CGFloat t);
CGPoint closestPointOnStraightLineToP(CGPoint p0, CGPoint p1, CGPoint p);
CGFloat distanceBetweenPointAndStraightLine(CGPoint p, CGPoint start, CGPoint end);
CGPoint lineIntersection(CGPoint p1, CGPoint p2, CGPoint q1, CGPoint q2);
BOOL rectClipsLine(CGRect rect, CGPoint p1, CGPoint p2);
BOOL rectIntersectsRotatedRect(CGRect rect, CGRect r, CGFloat degrees);

CGFloat trimToMinMax(CGFloat p, CGFloat min, CGFloat max);
CGSize RSUnionSize(CGSize s1, CGSize s2);
CGFloat RSMinSizeDimension(CGSize size);
CGSize RSSizeRotate(CGSize size, CGFloat degrees);
CGPoint rotatePointInFrameByDegrees(CGPoint p, CGRect r, CGFloat degrees);

data_p inverseNormalProbability(data_p p);
data_p addJitter(data_p val, data_p stddev);


@interface RSNumber : OFObject

+ (NSString *)formatNumberForExport:(data_p)val;

+ (BOOL)getStrictDoubleValue:(double *)doubleVal forString:(NSString *)string;
+ (BOOL)getStricterDoubleValue:(double *)doubleVal forString:(NSString *)string;

@end
