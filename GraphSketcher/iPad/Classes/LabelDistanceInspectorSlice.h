// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/iPad/Classes/LabelDistanceInspectorSlice.h 200244 2013-12-10 00:11:55Z correia $

#import <OmniUI/OUIInspectorSlice.h>

@class OUIInspectorTextWell, OUIInspectorStepperButton;

@interface LabelDistanceInspectorSlice : OUIInspectorSlice
{
    OUIInspectorTextWell *_distanceTextWell;
    OUIInspectorStepperButton *_decreaseStepperButton;
    OUIInspectorStepperButton *_increaseStepperButton;
}

@property(retain) IBOutlet OUIInspectorTextWell *distanceTextWell;
@property(retain) IBOutlet OUIInspectorStepperButton *decreaseStepperButton;
@property(retain) IBOutlet OUIInspectorStepperButton *increaseStepperButton;

- (IBAction)increaseDistance:(id)sender;
- (IBAction)decreaseDistance:(id)sender;
- (IBAction)changeDistance:(id)sender;

@end
