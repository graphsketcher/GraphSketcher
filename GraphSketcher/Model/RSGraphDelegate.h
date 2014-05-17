// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

@class RSGraph;

// Update requirements are in order of increasing computational complexity.  Some requirements automatically imply additional requirements; for example, updating the whitespace also requires redrawing the display.
typedef enum _RSModelUpdateRequirement {
    RSUpdateNone = 0,
    RSUpdateDraw = 1,		// Redraw the display only
    RSUpdateWhitespace = 2,	// Recompute the automatic whitespace margins
    RSUpdateConstraints = 3,	// Recompute the positions of objects obeying constraints (such as snappedTo vertices and best-fit lines)
} RSModelUpdateRequirement;

@protocol RSGraphDelegate <NSObject>
- (void)modelChangeRequires:(RSModelUpdateRequirement)req;
@end
