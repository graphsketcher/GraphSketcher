// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/iPad/Classes/GridInspectorSlice.m 200244 2013-12-10 00:11:55Z correia $

#import "GridInspectorSlice.h"

#import <OmniUI/OUIInspectorButton.h>
#import <OmniUI/OUIDrawing.h>
#import <OmniUI/OUIInspectorTextWell.h>
#import <OmniUI/OUIInspectorStepperButton.h>

#import <GraphSketcherModel/RSAxis.h>
#import <GraphSketcherModel/RSGraph.h>

#import "InspectorSupport.h"

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/iPad/Classes/GridInspectorSlice.m 200244 2013-12-10 00:11:55Z correia $");

@interface GridInspectorSlice (/*Private*/)
@end

@implementation GridInspectorSlice

- (void)dealloc;
{
    [_gridLabel release];
    [_verticalGridToggleButton release];
    [_horizontalGridToggleButton release];
    [_widthTextWell release];
    [_increaseWidthStepperButton release];
    [_decreaseWidthStepperButton release];
    [super dealloc];
}

@synthesize gridLabel = _gridLabel;
@synthesize verticalGridToggleButton = _verticalGridToggleButton;
@synthesize horizontalGridToggleButton = _horizontalGridToggleButton;

@synthesize widthTextWell = _widthTextWell;
@synthesize increaseWidthStepperButton = _increaseWidthStepperButton;
@synthesize decreaseWidthStepperButton = _decreaseWidthStepperButton;

- (IBAction)changeDisplayGrid:(id)sender;
{
    RSGraph *graph = self.editor.graph;
    RSAxis *axis = (sender == _horizontalGridToggleButton) ? graph.xAxis : graph.yAxis;
    
    [self.inspector willBeginChangingInspectedObjects];
    {
        [axis setDisplayGrid:![axis displayGrid]];
    }
    [self.inspector didEndChangingInspectedObjects];
}

static void _changeWidth(GridInspectorSlice *self, CGFloat delta)
{
    RSGraph *graph = self.editor.graph;

    CGFloat width = graph.gridWidth + delta;
    if (width < 1)
        width = 0.5;
    else if (width > 10)
        width = 10;
    else
        width = MAX(1, floor(width));

    [self.inspector willBeginChangingInspectedObjects];
    {
        graph.gridWidth = width;
    }
    [self.inspector didEndChangingInspectedObjects];
}

- (IBAction)increaseWidth:(id)sender;
{
    _changeWidth(self, 1);
}

- (IBAction)decreaseWidth:(id)sender;
{
    _changeWidth(self, -1);
}

#pragma mark -
#pragma mark OUIInspectorSlice subclass

- (BOOL)isAppropriateForInspectedObject:(id)object;
{
    return [object isKindOfClass:[RSGraph class]];
}

- (void)updateInterfaceFromInspectedObjects:(OUIInspectorUpdateReason)reason;
{
    RSGraph *graph = self.editor.graph;

    _horizontalGridToggleButton.selected = [[graph xAxis] displayGrid];
    _verticalGridToggleButton.selected = [[graph yAxis] displayGrid];

    _widthTextWell.text = [NSString stringWithFormat:@"%g", graph.gridWidth];
}

#pragma mark -
#pragma mark UIViewController subclass

- (void)viewDidLoad;
{
    [super viewDidLoad];
    
    _gridLabel.text = NSLocalizedStringFromTable(@"Grid", @"Inspectors", @"inspector title label");
    _gridLabel.textColor = [OUIInspector labelTextColor];
    _gridLabel.font = [OUIInspector labelFont];
    OUISetShadowOnLabel(_gridLabel, OUIShadowTypeDarkContentOnLightBackground);

    
    _increaseWidthStepperButton.image = [UIImage imageNamed:@"ThicknessIncrease.png"];
    _decreaseWidthStepperButton.image = [UIImage imageNamed:@"ThicknessDecrease.png"];
    _decreaseWidthStepperButton.flipped = YES;
    
    CGFloat fontSize = [OUIInspectorTextWell fontSize];
    _widthTextWell.font = [UIFont boldSystemFontOfSize:fontSize];
    _widthTextWell.label = NSLocalizedStringFromTableInBundle(@"thickness: %@", @"Inspector", OMNI_BUNDLE, @"line/point size label format for inspector");
    _widthTextWell.labelFont = [UIFont systemFontOfSize:fontSize];
    
    _verticalGridToggleButton.image = [UIImage imageNamed:@"GridVertical.png"];
    _horizontalGridToggleButton.image = [UIImage imageNamed:@"GridHorizontal.png"];
}

@end
