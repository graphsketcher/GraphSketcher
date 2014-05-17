// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OmniUI/OUIInspectorSlice.h>

@class OUISegmentedControl, OUIInspectorOptionWheel;

@interface LineInspectorSlice : OUIInspectorSlice
{
@private
    OUISegmentedControl *_connectionTypeSegmentedControl;
    OUIInspectorOptionWheel *_lineDashOptionWheel;
}

@property(retain) IBOutlet OUISegmentedControl *connectionTypeSegmentedControl;
@property(retain) IBOutlet OUIInspectorOptionWheel *lineDashOptionWheel;

- (IBAction)changeConnectionType:(id)sender;
- (IBAction)changeLineDash:(id)option;

@end
