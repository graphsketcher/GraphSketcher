// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/iPad/Classes/WidthInspectorSlice.m 200244 2013-12-10 00:11:55Z correia $

#import "WidthInspectorSlice.h"

#import <OmniUI/OUIInspectorTextWell.h>
#import <OmniUI/OUIInspectorStepperButton.h>
#import <GraphSketcherModel/RSGraphEditor.h>
#import "InspectorSupport.h"

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/iPad/Classes/WidthInspectorSlice.m 200244 2013-12-10 00:11:55Z correia $");

@interface WidthInspectorSlice (/*Private*/)
- (NSNumber *)_singleWidthValue;
@end

@implementation WidthInspectorSlice

- (void)dealloc;
{
    [_widthTextWell release];
    [_increaseWidthStepperButton release];
    [_decreaseWidthStepperButton release];
    [super dealloc];
}

@synthesize widthTextWell = _widthTextWell;
@synthesize increaseWidthStepperButton = _increaseWidthStepperButton;
@synthesize decreaseWidthStepperButton = _decreaseWidthStepperButton;

static void _setWidth(WidthInspectorSlice *self, CGFloat width)
{
    if (width < 1)
        width = 0.5;
    else
        width = MAX(1, floor(width));
    
    RSGraphEditor *editor = self.editor;
    
    [self.inspector willBeginChangingInspectedObjects];
    {
        for (id object in self.appropriateObjectsForInspection)
            [editor setWidth:width forElement:object snapDistanceToNearestInteger:NO]; // we've already snapped
    }
    [self.inspector didEndChangingInspectedObjects];
}

static void _changeWidth(WidthInspectorSlice *self, CGFloat delta)
{
    NSNumber *singleValue = [self _singleWidthValue];
    CGFloat singleFloat = (singleValue ? [singleValue floatValue] : 0);
    _setWidth(self, singleFloat + delta);
}

- (IBAction)increaseWidth:(id)sender;
{
    _changeWidth(self, 1);
}

- (IBAction)decreaseWidth:(id)sender;
{
    _changeWidth(self, -1);
}

- (IBAction)changeWidth:(id)sender;
{
    CGFloat width = [_widthTextWell.text doubleValue];
    _setWidth(self, width);
}

#pragma mark -
#pragma mark OUIInspectorSlice subclassed

- (BOOL)isAppropriateForInspectedObject:(id)object;
{
    if (![object isKindOfClass:[RSGraphElement class]])
        return NO;
    return [(RSGraphElement *)object hasWidth];
}

- (void)updateInterfaceFromInspectedObjects:(OUIInspectorUpdateReason)reason;
{
    NSNumber *singleValue = [self _singleWidthValue];
    _widthTextWell.text = [singleValue description];
}

#pragma mark -
#pragma mark UIViewController subclass

- (void)viewDidLoad;
{
    [super viewDidLoad];
    
    _increaseWidthStepperButton.image = [UIImage imageNamed:@"ThicknessIncrease.png"];
    _decreaseWidthStepperButton.image = [UIImage imageNamed:@"ThicknessDecrease.png"];
    _decreaseWidthStepperButton.flipped = YES;
    
    CGFloat fontSize = [OUIInspectorTextWell fontSize];
    _widthTextWell.font = [UIFont boldSystemFontOfSize:fontSize];
    _widthTextWell.label = NSLocalizedStringFromTableInBundle(@"thickness: %@", @"Inspector", OMNI_BUNDLE, @"line/point size label format for inspector");
    _widthTextWell.labelFont = [UIFont systemFontOfSize:fontSize];
    _widthTextWell.editable = YES;
    _widthTextWell.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
}

#pragma mark -
#pragma mark Private

- (NSNumber *)_singleWidthValue;
{
    RSGraphEditor *editor = self.editor;
    NSMutableSet *values = [NSMutableSet set];
    for (RSGraphElement *element in self.appropriateObjectsForInspection)
        [values addObject:[NSNumber numberWithFloat:[editor widthForElement:element]]];
    
    if ([values count] == 1)
        return [values anyObject];
    return nil;
}

@end
