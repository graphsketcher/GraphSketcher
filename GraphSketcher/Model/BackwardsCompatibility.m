// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/Model/BackwardsCompatibility.m 200244 2013-12-10 00:11:55Z correia $

#import <GraphSketcherModel/BackwardsCompatibility.h>
#import <GraphSketcherModel/RSVertex.h>


CGPoint CGPointFromRSDataPoint(RSDataPoint p) {
    return CGPointMake((CGFloat)p.x, (CGFloat)p.y);
}


@implementation RSGraph (BackwardsCompatibility)

- (void)updateNonePointTypes;
// RSS GS and OGS betas pre-bundle-version 10 drew "RS_NONE" point types as small circles.  OGS now does not render points at all whose shape is RS_NONE.  So that old graphs look the same in the new OGS, this method converts "RS_NONE" vertices to RS_CIRCLE of the correct size.  However, vertices with parents are left invisible, since that was sometimes the behavior of older versions and anyway in those cases the locations of vertices is implicit in the shape of the parent lines or fills.
{
    for (RSVertex *V in [self Vertices]) {
        if ([V shape] == RS_NONE && [V parentCount] == 0) {
            [V setShape:RS_CIRCLE];
            [V setWidth:( [V width]/4 )];
        }
    }
}

@end
