// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OmniUI/OUIInspectorSlice.h>

@class OUISegmentedControl, OUIInspectorButton;

@interface AxisInspectorSlice : OUIInspectorSlice
{
@private
    OUISegmentedControl *_positionSegmentedControl;
    
    OUIInspectorButton *_minArrowEnabledButton;
    OUIInspectorButton *_maxArrowEnabledButton;
    OUIInspectorButton *_tickMarksEnabledButton;
    OUIInspectorButton *_labelsEnabledButton;
}

@property(retain) IBOutlet OUISegmentedControl *positionSegmentedControl;
@property(retain) IBOutlet OUIInspectorButton *minArrowEnabledButton;
@property(retain) IBOutlet OUIInspectorButton *maxArrowEnabledButton;
@property(retain) IBOutlet OUIInspectorButton *tickMarksEnabledButton;
@property(retain) IBOutlet OUIInspectorButton *labelsEnabledButton;

- (void)changePosition:(id)sender;
- (void)changeArrow:(id)sender;
- (void)toggleTickMarks:(id)sender;
- (void)toggleLabels:(id)sender;

@end
