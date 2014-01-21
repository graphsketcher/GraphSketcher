// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/iPad/Classes/CanvasSizeInspectorSlice.h 200244 2013-12-10 00:11:55Z correia $

#import <OmniUI/OUIInspectorSlice.h>

@class OUIInspectorTextWell, OUIInspectorButton;

@interface CanvasSizeInspectorSlice : OUIInspectorSlice
{
@private
    OUIInspectorTextWell *_widthTextWell;
    OUIInspectorTextWell *_heightTextWell;
    
    UILabel *_axesLabel;
    OUIInspectorButton *_axesEnabledToggleButton;
    OUIInspectorButton *_ticksEnabledToggleButton;
    OUIInspectorButton *_labelsEnabledToggleButton;
}

@property(retain) IBOutlet OUIInspectorTextWell *widthTextWell;
@property(retain) IBOutlet OUIInspectorTextWell *heightTextWell;
@property(retain) IBOutlet UILabel *axesLabel;
@property(retain) IBOutlet OUIInspectorButton *axesEnabledToggleButton;
@property(retain) IBOutlet OUIInspectorButton *ticksEnabledToggleButton;
@property(retain) IBOutlet OUIInspectorButton *labelsEnabledToggleButton;

- (IBAction)changeWidth:(id)sender;
- (IBAction)changeHeight:(id)sender;

- (IBAction)changeAxesEnabled:(id)sender;
- (IBAction)changeTicksEnabled:(id)sender;
- (IBAction)changeLabelsEnabled:(id)sender;

@end
