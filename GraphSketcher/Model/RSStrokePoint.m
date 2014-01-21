// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/Model/RSStrokePoint.m 200244 2013-12-10 00:11:55Z correia $

#import "RSStrokePoint.h"


@implementation RSStrokePoint

+ (id)strokePointWithPoint:(CGPoint)p time:(double)t {
    return [[[RSStrokePoint alloc] initWithPoint:p time:t] autorelease];
}

// DESIGNATED INITIALIZER
- (id)initWithPoint:(CGPoint)p time:(double)t;
{
    if (!(self = [super init]))
        return nil;
    
    _point = p;
    _time = t;
    
    return self;
}
- (id)init {
    return [self initWithPoint:CGPointMake(0,0) time:0];
}

- (CGPoint)point {
    return _point;
}
- (CGFloat)pointx {
    return _point.x;
}
- (CGFloat)pointy {
    return _point.y;
}
- (double)time {
    return _time;
}


@end
