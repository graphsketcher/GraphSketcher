// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/iPad/Classes/AxisTypeInspectorSlice.h 200244 2013-12-10 00:11:55Z correia $

#import <OmniUI/OUIInspectorSlice.h>

@class OUISegmentedControl, OUIInspectorButton;

@interface AxisTypeInspectorSlice : OUIInspectorSlice
{
@private
    OUISegmentedControl *_axisTypeSegmentedControl;
    
    UILabel *_nextHeaderLabel;
}

@property(retain) IBOutlet UILabel *nextHeaderLabel;
@property(retain) IBOutlet OUISegmentedControl *axisTypeSegmentedControl;

- (void)changeAxisType:(id)sender;

@end
