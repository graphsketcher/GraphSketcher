// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

// RSGraphElementSelector is the object that keeps track of the selection on OGS-iPad. I also see it as the future of the RSSelector object on the Mac, but the transition has not been done.

#import <OmniFoundation/OFObject.h>

#import "RSGraphElement.h"


@interface RSGraphElementSelector : OFObject {
    RSGraphElement * _selection;
}

@property (retain) RSGraphElement *selection;

- (BOOL)deselect; // returns YES if a deselect was actually necessary
- (BOOL)selected;

@end
