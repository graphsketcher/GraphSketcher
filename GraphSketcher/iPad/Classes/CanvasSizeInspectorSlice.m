// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "CanvasSizeInspectorSlice.h"

#import <OmniUI/OUIInspectorTextWell.h>
#import <OmniUI/OUIInspectorButton.h>
#import <OmniUI/OUIDrawing.h>
#import "InspectorSupport.h"
#import "GraphViewController.h"

RCS_ID("$Header$");

@implementation CanvasSizeInspectorSlice

- (void)dealloc;
{
    [_widthTextWell release];
    [_heightTextWell release];
    [_axesLabel release];
    [_axesEnabledToggleButton release];
    [_ticksEnabledToggleButton release];
    [_labelsEnabledToggleButton release];

    [super dealloc];
}

@synthesize widthTextWell = _widthTextWell;
@synthesize heightTextWell = _heightTextWell;
@synthesize axesLabel = _axesLabel;
@synthesize axesEnabledToggleButton = _axesEnabledToggleButton;
@synthesize ticksEnabledToggleButton = _ticksEnabledToggleButton;
@synthesize labelsEnabledToggleButton = _labelsEnabledToggleButton;

- (IBAction)changeWidth:(id)sender;
{
    RSGraphEditor *editor = self.editor;
    CGSize canvasSize = [editor.graph canvasSize];
    canvasSize.width = MIN(2000, [_widthTextWell.text doubleValue]);
    
    [self.inspector willBeginChangingInspectedObjects];
    {
        [editor setCanvasSize:canvasSize];
    }
    [self.inspector didEndChangingInspectedObjects];
    
    [self.graphViewController sizeInitialViewSizeFromCanvasSize];
}

- (IBAction)changeHeight:(id)sender;
{
    RSGraphEditor *editor = self.editor;
    CGSize canvasSize = [editor.graph canvasSize];
    canvasSize.height = MIN(1500, [_heightTextWell.text doubleValue]);
    
    [self.inspector willBeginChangingInspectedObjects];
    {
        [editor setCanvasSize:canvasSize];
    }
    [self.inspector didEndChangingInspectedObjects];

    [self.graphViewController sizeInitialViewSizeFromCanvasSize];
}

- (IBAction)changeAxesEnabled:(id)sender;
{
    RSGraphEditor *editor = self.editor;
    RSAxis *xAxis = editor.graph.xAxis;
    RSAxis *yAxis = editor.graph.yAxis;

    BOOL enabled = [xAxis displayAxis] && [yAxis displayAxis];
    RSAxisPlacement placement = enabled ? RSHiddenPlacement : RSEdgePlacement;
    
    [self.inspector willBeginChangingInspectedObjects];
    {
        [editor setPlacement:placement forAxis:xAxis];
        [editor setPlacement:placement forAxis:yAxis];
    }
    [self.inspector didEndChangingInspectedObjects];
}

- (IBAction)changeTicksEnabled:(id)sender;
{
    RSGraphEditor *editor = self.editor;
    RSAxis *xAxis = editor.graph.xAxis;
    RSAxis *yAxis = editor.graph.yAxis;
    
    BOOL enabled = [xAxis displayTicks] && [yAxis displayTicks];
    
    [self.inspector willBeginChangingInspectedObjects];
    {
        xAxis.displayTicks = !enabled;
        yAxis.displayTicks = !enabled;
    }
    [self.inspector didEndChangingInspectedObjects];
}

- (IBAction)changeLabelsEnabled:(id)sender;
{
    RSGraphEditor *editor = self.editor;
    RSAxis *xAxis = editor.graph.xAxis;
    RSAxis *yAxis = editor.graph.yAxis;
    
    BOOL enabled = [xAxis displayTickLabels] && [yAxis displayTickLabels];
    
    [self.inspector willBeginChangingInspectedObjects];
    {
        xAxis.displayTickLabels = !enabled;
        yAxis.displayTickLabels = !enabled;
    }
    [self.inspector didEndChangingInspectedObjects];
}

#pragma mark -
#pragma mark OUIInspectorSlice subclasse

- (BOOL)isAppropriateForInspectedObject:(id)object;
{
    return [object isKindOfClass:[RSGraph class]];
}

- (void)updateInterfaceFromInspectedObjects:(OUIInspectorUpdateReason)reason;
{
    RSGraphEditor *editor = self.editor;
    CGSize canvasSize = [editor.graph canvasSize];
        
    _widthTextWell.text = [NSString stringWithFormat:@"%g", canvasSize.width];
    _heightTextWell.text = [NSString stringWithFormat:@"%g", canvasSize.height];
    
    RSAxis *xAxis = editor.graph.xAxis;
    RSAxis *yAxis = editor.graph.yAxis;
    
    _axesEnabledToggleButton.selected = [xAxis displayAxis] && [yAxis displayAxis];
    _ticksEnabledToggleButton.selected = [xAxis displayTicks] && [yAxis displayTicks];
    _labelsEnabledToggleButton.selected = [xAxis displayTickLabels] && [yAxis displayTickLabels];
}

#pragma mark -
#pragma mark UIViewController subclass

- (void)viewDidLoad;
{
    [super viewDidLoad];
    
    _axesLabel.text = NSLocalizedStringFromTableInBundle(@"Axes", @"Inspector", OMNI_BUNDLE, @"Label next to button for controlling axis visibility (note, plural since it controls both).");
    _axesLabel.textColor = [OUIInspector labelTextColor];
    _axesLabel.font = [OUIInspector labelFont];
    OUISetShadowOnLabel(_axesLabel, OUIShadowTypeDarkContentOnLightBackground);

    _axesEnabledToggleButton.image = [UIImage imageNamed:@"AxesEnabled.png"];
    _ticksEnabledToggleButton.image = [UIImage imageNamed:@"AxisTicks.png"];
    _labelsEnabledToggleButton.image = [UIImage imageNamed:@"AxisLabels.png"];
    
    CGFloat fontSize = [OUIInspectorTextWell fontSize];
    _widthTextWell.font = [UIFont boldSystemFontOfSize:fontSize];
    _widthTextWell.label = NSLocalizedStringFromTableInBundle(@"w: %@", @"Inspector", OMNI_BUNDLE, @"canvas width inspector label format string");
    _widthTextWell.labelFont = [OUIInspectorTextWell italicFormatFont];
    _widthTextWell.cornerType = OUIInspectorWellCornerTypeLargeRadius;
    _widthTextWell.editable = YES;
    _widthTextWell.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
    
    _heightTextWell.font = [UIFont boldSystemFontOfSize:fontSize];
    _heightTextWell.label = NSLocalizedStringFromTableInBundle(@"h: %@", @"Inspector", OMNI_BUNDLE, @"canvas height inspector label format string");
    _heightTextWell.labelFont = [OUIInspectorTextWell italicFormatFont];
    _heightTextWell.cornerType = OUIInspectorWellCornerTypeLargeRadius;
    _heightTextWell.editable = YES;
    _heightTextWell.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
}

@end
