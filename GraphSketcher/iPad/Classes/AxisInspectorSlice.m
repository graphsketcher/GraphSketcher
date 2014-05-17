// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "AxisInspectorSlice.h"

#import "InspectorSupport.h"
#import <OmniUI/OUISegmentedControl.h>
#import <OmniUI/OUISegmentedControlButton.h>
#import <OmniUI/OUIInspectorButton.h>
#import <OmniUI/OUIDrawing.h>

RCS_ID("$Header$");

@implementation AxisInspectorSlice

- (void)dealloc;
{
    [_positionSegmentedControl release];
    [_minArrowEnabledButton release];
    [_maxArrowEnabledButton release];;
    [_tickMarksEnabledButton release];
    [_labelsEnabledButton release];
    
    [super dealloc];
}

@synthesize positionSegmentedControl = _positionSegmentedControl;
@synthesize minArrowEnabledButton = _minArrowEnabledButton;
@synthesize maxArrowEnabledButton = _maxArrowEnabledButton;
@synthesize tickMarksEnabledButton = _tickMarksEnabledButton;
@synthesize labelsEnabledButton = _labelsEnabledButton;

- (void)changePosition:(id)sender;
{
    RSAxisPlacement placement = [_positionSegmentedControl.selectedSegment.representedObject integerValue];
    RSGraphEditor *editor = self.editor;
    
    [self.inspector willBeginChangingInspectedObjects];
    {
        for (RSAxis *axis in self.appropriateObjectsForInspection) {
            [editor setPlacement:placement forAxis:axis];
        }
    }
    [self.inspector didEndChangingInspectedObjects];
}

- (NSInteger)_arrowShapeIndexFromControls:(id)sender;
{
    BOOL min = ((_minArrowEnabledButton.state & UIControlStateSelected) != 0);
    BOOL max = ((_maxArrowEnabledButton.state & UIControlStateSelected) != 0);
    
    if (sender == _minArrowEnabledButton)
        min = !min;
    else
        max = !max;
    
    if (min) {
	if (max)
            return RS_BOTH_ARROW;
        return RS_LEFT_ARROW;
    } else {
        if (max)
            return RS_RIGHT_ARROW;
        return RS_NONE;
    }
}

- (void)changeArrow:(id)sender;
{
    NSInteger styleIndex = [self _arrowShapeIndexFromControls:sender];
    RSGraphEditor *editor = self.editor;
    
    [self.inspector willBeginChangingInspectedObjects];
    {
        for (RSGraphElement *element in self.appropriateObjectsForInspection)
            [editor changeArrowhead:styleIndex forElement:element isLeft:(sender == _minArrowEnabledButton)];
    }
    [self.inspector didEndChangingInspectedObjects];
}

- (void)toggleTickMarks:(id)sender;
{
    RSGraphEditor *editor = self.editor;
    NSArray *appropriateObjects = self.appropriateObjectsForInspection;
    BOOL hasTicks = NO;
    for (RSAxis *axis in appropriateObjects)
        hasTicks |= [axis displayTicks];

    [self.inspector willBeginChangingInspectedObjects];
    {
        for (RSAxis *axis in appropriateObjects)
            [editor setDisplayTickMarks:!hasTicks forAxis:axis];
    }
    [self.inspector didEndChangingInspectedObjects];
}

- (void)toggleLabels:(id)sender;
{
    RSGraphEditor *editor = self.editor;
    NSArray *appropriateObjects = self.appropriateObjectsForInspection;
    BOOL hasLabels = NO;
    for (RSAxis *axis in appropriateObjects)
        hasLabels |= [axis displayTickLabels];
    
    [self.inspector willBeginChangingInspectedObjects];
    {
        for (RSAxis *axis in appropriateObjects)
            [editor setDisplayTickLabels:!hasLabels forAxis:axis];
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
    RSGraphEditor *editor = self.editor;
    NSArray *appropriateObjects = self.appropriateObjectsForInspection;
    
    BOOL useY = [appropriateObjects indexOfObject:editor.graph.yAxis] != NSNotFound;
    [_positionSegmentedControl segmentAtIndex:0].image = [UIImage imageNamed:useY ? @"AxisPositionYMin.png" : @"AxisPositionXMin.png"];
    [_positionSegmentedControl segmentAtIndex:1].image = [UIImage imageNamed:useY ? @"AxisPositionYOrigin.png" : @"AxisPositionXOrigin.png"];
    [_positionSegmentedControl segmentAtIndex:2].image = [UIImage imageNamed:useY ? @"AxisPositionYBoth.png" : @"AxisPositionXBoth.png"];
    
    NSNumber *singlePlacement = [self singleSelectedValueForIntegerSelector:@selector(placement)];
    _positionSegmentedControl.selectedSegment = [_positionSegmentedControl segmentWithRepresentedObject:singlePlacement];
    
    BOOL hasTicks = NO, hasLabels = NO;
    for (RSAxis *axis in appropriateObjects) {
        hasTicks |= [axis displayTicks];
        hasLabels |= [axis displayTickLabels];
    }
    _tickMarksEnabledButton.selected = hasTicks;
    _labelsEnabledButton.selected = hasLabels;
    
    BOOL hasMin = NO, hasMax = NO;
    for (RSAxis *axis in self.appropriateObjectsForInspection) {
        hasMin |= [editor hasMinArrow:axis];
        hasMax |= [editor hasMaxArrow:axis];
    }
    [_minArrowEnabledButton setSelected:hasMin];
    [_maxArrowEnabledButton setSelected:hasMax];
}

#pragma mark -
#pragma mark UIViewController subclass

- (void)viewDidLoad;
{
    [super viewDidLoad];
    
    [_positionSegmentedControl addSegmentWithImageNamed:@"AxisPositionXMin.png" representedObject:[NSNumber numberWithInteger:RSEdgePlacement]];
    [_positionSegmentedControl addSegmentWithImageNamed:@"AxisPositionXOrigin.png" representedObject:[NSNumber numberWithInteger:RSOriginPlacement]];
    [_positionSegmentedControl addSegmentWithImageNamed:@"AxisPositionXBoth.png" representedObject:[NSNumber numberWithInteger:RSBothEdgesPlacement]];
    [_positionSegmentedControl addSegmentWithImageNamed:@"AxisPositionNone.png" representedObject:[NSNumber numberWithInteger:RSHiddenPlacement]];
    
    _positionSegmentedControl.sizesSegmentsToFit = YES;
    
    UIImage *arrowImage = [UIImage imageNamed:@"Arrow.png"];
    _minArrowEnabledButton.image = arrowImage;
    _maxArrowEnabledButton.image = OUIImageByFlippingHorizontally(arrowImage);
    
    _tickMarksEnabledButton.image = [UIImage imageNamed:@"AxisTicks.png"];
    _labelsEnabledButton.image = [UIImage imageNamed:@"AxisLabels.png"];
}

@end
