// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/iPad/Classes/WidthInspectorSlice.h 200244 2013-12-10 00:11:55Z correia $

#import <OmniUI/OUIInspectorSlice.h>

@class OUIInspectorTextWell, OUIInspectorStepperButton;

@interface WidthInspectorSlice : OUIInspectorSlice
{
@private
    OUIInspectorTextWell *_widthTextWell;
    OUIInspectorStepperButton *_increaseWidthStepperButton;
    OUIInspectorStepperButton *_decreaseWidthStepperButton;
}

@property(retain) IBOutlet OUIInspectorTextWell *widthTextWell;
@property(retain) IBOutlet OUIInspectorStepperButton *increaseWidthStepperButton;
@property(retain) IBOutlet OUIInspectorStepperButton *decreaseWidthStepperButton;

- (IBAction)increaseWidth:(id)sender;
- (IBAction)decreaseWidth:(id)sender;
- (IBAction)changeWidth:(id)sender;

@end
