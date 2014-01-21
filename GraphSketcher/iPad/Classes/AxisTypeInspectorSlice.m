// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/iPad/Classes/AxisTypeInspectorSlice.m 200244 2013-12-10 00:11:55Z correia $

#import "AxisTypeInspectorSlice.h"

#import "InspectorSupport.h"
#import <OmniUI/OUISegmentedControl.h>
#import <OmniUI/OUISegmentedControlButton.h>
#import <OmniUI/OUIDrawing.h>

@implementation AxisTypeInspectorSlice

- (void)dealloc;
{
    [_nextHeaderLabel release];
    [_axisTypeSegmentedControl release];
    
    [super dealloc];
}

@synthesize nextHeaderLabel = _nextHeaderLabel;
@synthesize axisTypeSegmentedControl = _axisTypeSegmentedControl;

- (void)changeAxisType:(id)sender;
{
    RSAxisType axisType = [_axisTypeSegmentedControl.selectedSegment.representedObject integerValue];
    
    [self.inspector willBeginChangingInspectedObjects];
    {
        for (RSAxis *axis in self.appropriateObjectsForInspection) {
            [axis setAxisType:axisType];
        }
    }
    [self.inspector didEndChangingInspectedObjects];
}

#pragma mark -
#pragma mark OUIInspectorSlice subclass

- (BOOL)isAppropriateForInspectedObject:(id)object;
{
    if (![object isKindOfClass:[RSAxis class]])
        return NO;
    return [(RSGraphElement *)object canHaveArrows];
}

- (void)updateInterfaceFromInspectedObjects:(OUIInspectorUpdateReason)reason;
{
    NSNumber *singlePlacement = [self singleSelectedValueForIntegerSelector:@selector(axisType)];
    _axisTypeSegmentedControl.selectedSegment = [_axisTypeSegmentedControl segmentWithRepresentedObject:singlePlacement];
}


#pragma mark -
#pragma mark UIViewController subclass

- (void)viewDidLoad;
{
    [super viewDidLoad];
    
    _nextHeaderLabel.text = NSLocalizedStringFromTableInBundle(@"Tick Labels", @"Inspector", OMNI_BUNDLE, @"Header label on single-axis inspector.");
    _nextHeaderLabel.textColor = [OUIInspector labelTextColor];
    _nextHeaderLabel.font = [OUIInspector labelFont];
    OUISetShadowOnLabel(_nextHeaderLabel, OUIShadowTypeDarkContentOnLightBackground);
    
    [_axisTypeSegmentedControl addSegmentWithText:NSLocalizedStringFromTableInBundle(@"Linear", @"Inspector", OMNI_BUNDLE, @"Text in axis-type segment on the axis inspector.") representedObject:[NSNumber numberWithInteger:RSAxisTypeLinear]];
    [_axisTypeSegmentedControl addSegmentWithText:NSLocalizedStringFromTableInBundle(@"Logarithmic", @"Inspector", OMNI_BUNDLE, @"Text in axis-type segment on the axis inspector.") representedObject:[NSNumber numberWithInteger:RSAxisTypeLogarithmic]];
    
    _axisTypeSegmentedControl.sizesSegmentsToFit = YES;
}

@end
