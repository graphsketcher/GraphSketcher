// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

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
