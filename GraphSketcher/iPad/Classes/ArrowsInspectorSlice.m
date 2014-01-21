// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/iPad/Classes/ArrowsInspectorSlice.m 200244 2013-12-10 00:11:55Z correia $

#import "ArrowsInspectorSlice.h"

#import "InspectorSupport.h"
#import <OmniUI/OUIInspectorButton.h>
#import <OmniUI/OUIDrawing.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/iPad/Classes/ArrowsInspectorSlice.m 200244 2013-12-10 00:11:55Z correia $");

@implementation ArrowsInspectorSlice

- (void)dealloc;
{
    [_minArrowEnabledButton release];
    [_maxArrowEnabledButton release];
    [super dealloc];
}

@synthesize minArrowEnabledButton = _minArrowEnabledButton;
@synthesize maxArrowEnabledButton = _maxArrowEnabledButton;

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

#pragma mark -
#pragma mark OUIInspectorSlice subclass

- (BOOL)isAppropriateForInspectedObject:(id)object;
{
    if (![object isKindOfClass:[RSGraphElement class]])
        return NO;

    // The axis inspector has its own copy of this.
    if ([object isKindOfClass:[RSAxis class]])
        return NO;

    return [(RSGraphElement *)object canHaveArrows];
}

- (void)updateInterfaceFromInspectedObjects:(OUIInspectorUpdateReason)reason;
{
    RSGraphEditor *editor = self.editor;

    BOOL hasMin = NO, hasMax = NO;

    for (RSGraphElement *element in self.appropriateObjectsForInspection) {
        hasMin |= [editor hasMinArrow:element];
        hasMax |= [editor hasMaxArrow:element];
    }
    
    [_minArrowEnabledButton setSelected:hasMin];
    [_maxArrowEnabledButton setSelected:hasMax];
}

#pragma mark -
#pragma mark UIViewController subclass

- (void)viewDidLoad;
{
    [super viewDidLoad];
    
    UIImage *arrowImage = [UIImage imageNamed:@"Arrow.png"];
    _minArrowEnabledButton.image = arrowImage;
    _maxArrowEnabledButton.image = OUIImageByFlippingHorizontally(arrowImage);
}

@end
