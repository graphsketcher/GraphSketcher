// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <GraphSketcherModel/RSGraph.h>

#if 0 && defined(DEBUG_robin)
#define DEBUG_BACKWARDS_COMPATIBILITY(format, ...) NSLog((format), ## __VA_ARGS__)
#else
#define DEBUG_BACKWARDS_COMPATIBILITY(format, ...)
#endif

CGPoint CGPointFromRSDataPoint(RSDataPoint p);

@interface RSGraph (BackwardsCompatibility)
- (void)updateNonePointTypes;
@end
