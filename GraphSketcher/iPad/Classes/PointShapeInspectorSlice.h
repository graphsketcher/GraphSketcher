// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/iPad/Classes/PointShapeInspectorSlice.h 200244 2013-12-10 00:11:55Z correia $

#import <OmniUI/OUIInspectorSlice.h>

@class OUISegmentedControl, OUIInspectorOptionWheel;

@interface PointShapeInspectorSlice : OUIInspectorSlice
{
@private
    OUISegmentedControl *_pointTypeSegmentedControl;
    OUIInspectorOptionWheel *_shapeTypeOptionWheel;
    CGFloat _shapeTypeSpace;
}

@property(retain) IBOutlet OUISegmentedControl *pointTypeSegmentedControl;
@property(retain) IBOutlet OUIInspectorOptionWheel *shapeTypeOptionWheel;

- (IBAction)changePointType:(id)sender;
- (IBAction)changeShape:(id)sender;

@end
