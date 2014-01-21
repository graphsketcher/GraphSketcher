// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/App/Inspectors/AxisInspector.h 200244 2013-12-10 00:11:55Z correia $

#import <OmniInspector/OIInspector.h>

@class RSSelector, RSGraph, GraphDocument;
@class OATinyPopUpButton;

@interface AxisInspector : OIInspector <OIConcreteInspector>
{
    GraphDocument *_document;
    RSSelector *_s;
    RSGraph *_graph;
}

// Outlets
@property (nonatomic, retain) IBOutlet NSView *view;
@property (nonatomic, assign) IBOutlet id axisTypePopUpX;
@property (nonatomic, assign) IBOutlet id axisTypePopUpY;

@property (nonatomic, assign) IBOutlet NSTextField *rangeXMinField;
@property (nonatomic, assign) IBOutlet NSTextField *rangeXMaxField;
@property (nonatomic, assign) IBOutlet NSTextField *rangeYMinField;
@property (nonatomic, assign) IBOutlet NSTextField *rangeYMaxField;

@property (nonatomic, assign) IBOutlet id axisPlacementXMatrix;
@property (nonatomic, assign) IBOutlet id axisPlacementYMatrix;

@property (nonatomic, assign) IBOutlet id displayAxisTitleX;
@property (nonatomic, assign) IBOutlet id displayAxisTitleY;
@property (nonatomic, assign) IBOutlet id displayAxisTickMarksX;
@property (nonatomic, assign) IBOutlet id displayAxisTickLabelsX;
@property (nonatomic, assign) IBOutlet id displayAxisTickMarksY;
@property (nonatomic, assign) IBOutlet id displayAxisTickLabelsY;
@property (nonatomic, assign) IBOutlet OATinyPopUpButton *tickLabelPopUpX;
@property (nonatomic, assign) IBOutlet OATinyPopUpButton *tickLabelPopUpY;

@property (nonatomic, assign) IBOutlet NSTextField *axisTickSpacingX;
@property (nonatomic, assign) IBOutlet NSTextField *axisTickSpacingY;
@property (nonatomic, assign) IBOutlet NSTextField *axisTickSpacingXLabel;
@property (nonatomic, assign) IBOutlet NSTextField *axisTickSpacingYLabel;

@property (nonatomic, assign) IBOutlet id displayGridX;
@property (nonatomic, assign) IBOutlet id displayGridY;
@property (nonatomic, assign) IBOutlet id gridWidthSlider;
@property (nonatomic, assign) IBOutlet id gridWidthField;
@property (nonatomic, assign) IBOutlet id gridWidthStepper;
@property (nonatomic, assign) IBOutlet id gridColorWell;

// Accessors
@property(assign) GraphDocument *document;
- (BOOL)documentExists;


// IBActions
- (IBAction)changeAxisType:(id)sender;

- (IBAction)changeXMin:(id)sender;
- (IBAction)changeXMax:(id)sender;
- (IBAction)changeYMin:(id)sender;
- (IBAction)changeYMax:(id)sender;

- (IBAction)changeAxisPlacement:(id)sender;

- (IBAction)changeDisplayAxisTitle:(id)sender;
- (IBAction)changeDisplayAxisTickMarks:(id)sender;
- (IBAction)changeDisplayAxisTickLabels:(id)sender;
- (IBAction)changeTickSpacing:(id)sender;

- (IBAction)changeDisplayGrid:(id)sender;
- (IBAction)changeGridWidth:(id)sender;
- (IBAction)changeGridColor:(id)sender;


@end
