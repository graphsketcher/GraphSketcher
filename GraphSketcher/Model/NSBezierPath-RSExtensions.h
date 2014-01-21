// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/Model/NSBezierPath-RSExtensions.h 200244 2013-12-10 00:11:55Z correia $

#if !defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE
#import <AppKit/NSBezierPath.h>
#endif

//
NSInteger RSWrap(NSInteger i, NSInteger n);  // "wraps" integer i around a loop of length n
NSInteger RSReflect(NSInteger i, NSInteger n);  // "reflects" integer i across a range 0...n

// Bezier functions
CGPoint evaluateBezierPathAtT(CGPoint p0, CGPoint p1, CGPoint p2, CGPoint p3, CGFloat t);
CGFloat* matrixMultiplyWithBSBInv(CGFloat* p, CGFloat* r, CGFloat t1, CGFloat t2);


@interface NSBezierPath (RSExtensions)

// Convenience constructors
- (NSBezierPath *)appendArrowheadAtPoint:(CGPoint)p width:(CGFloat)b height:(CGFloat)c;
+ (NSBezierPath *)arrowheadWithBaseAtPoint:(CGPoint)p width:(CGFloat)b height:(CGFloat)c;
- (NSBezierPath *)appendTickAtPoint:(CGPoint)p width:(CGFloat)w height:(CGFloat)h;


// Appending to the bezier path
- (void)curveAlongBezierP0:(CGPoint)p0 p1:(CGPoint)p1 p2:(CGPoint)p2 p3:(CGPoint)p3 start:(CGFloat)t1 finish:(CGFloat)t2;


// Manipulating the bezier path
- (void)rotateInFrame:(CGRect)r byDegrees:(CGFloat)degrees;


// Interpolating splines
+ (void)interpolatingSplineBezierSegmentsFromPoints:(CGPoint[])p length:(NSInteger)n putInto:(CGPoint[][3])segs;


@end
