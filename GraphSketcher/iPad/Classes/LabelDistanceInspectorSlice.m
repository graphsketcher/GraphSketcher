// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "LabelDistanceInspectorSlice.h"

#import <OmniUI/OUIInspectorTextWell.h>
#import <OmniUI/OUIInspectorStepperButton.h>
#import <GraphSketcherModel/RSGraphElement.h>
#import <GraphSketcherModel/RSGraphEditor.h>
#import "InspectorSupport.h"

RCS_ID("$Header$");

@implementation LabelDistanceInspectorSlice

- (void)dealloc;
{
    [_distanceTextWell release];
    [_decreaseStepperButton release];
    [_increaseStepperButton release];
    [super dealloc];
}

@synthesize distanceTextWell = _distanceTextWell;
@synthesize decreaseStepperButton = _decreaseStepperButton;
@synthesize increaseStepperButton = _increaseStepperButton;

static void _setDistance(LabelDistanceInspectorSlice *self, CGFloat distance)
{
    RSGraphEditor *editor = self.editor;
    
    [self.inspector willBeginChangingInspectedObjects];
    {
        for (id object in self.appropriateObjectsForInspection)
            [editor setDistanceValue:distance forElement:object snapDistanceToNearestInteger:YES];
    }
    [self.inspector didEndChangingInspectedObjects];
}

static void _changeDistance(LabelDistanceInspectorSlice *self, CGFloat delta)
{
    NSNumber *singleValue = [self singleSelectedValueForCGFloatSelector:@selector(labelDistance)];
    CGFloat distance = singleValue ? [singleValue floatValue] : 0;
    _setDistance(self, distance + delta);
}

- (IBAction)increaseDistance:(id)sender;
{
    _changeDistance(self, 1);
}

- (IBAction)decreaseDistance:(id)sender;
{
    _changeDistance(self, -1);
}

- (IBAction)changeDistance:(id)sender;
{
    CGFloat distance = [_distanceTextWell.text doubleValue];
    _setDistance(self, distance);
}

#pragma mark -
#pragma mark OUIInspectorSlice subclass

- (BOOL)isAppropriateForInspectedObject:(id)object;
{
    if (![object isKindOfClass:[RSGraphElement class]])
        return NO;
    RSGraphElement *element = object;
    return element.hasLabelDistance;
}

- (void)updateInterfaceFromInspectedObjects:(OUIInspectorUpdateReason)reason;
{
    NSNumber *singleValue = [self singleSelectedValueForCGFloatSelector:@selector(labelDistance)];
    _distanceTextWell.text = [singleValue description];
}

#pragma mark -
#pragma mark UIViewController subclass

- (void)viewDidLoad;
{
    [super viewDidLoad];
    
    _decreaseStepperButton.image = [UIImage imageNamed:@"LabelDistanceDecrease.png"];
    _decreaseStepperButton.flipped = YES;
    
    _increaseStepperButton.image = [UIImage imageNamed:@"LabelDistanceIncrease.png"];
    
    CGFloat fontSize = [OUIInspectorTextWell fontSize];
    _distanceTextWell.font = [UIFont boldSystemFontOfSize:fontSize];
    _distanceTextWell.label = NSLocalizedStringFromTableInBundle(@"distance: %@", @"Inspectors", OMNI_BUNDLE, @"label distance format string on inspector");
    _distanceTextWell.labelFont = [UIFont systemFontOfSize:fontSize];
    _distanceTextWell.editable = YES;
}

@end
