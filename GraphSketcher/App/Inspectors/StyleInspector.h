// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OmniInspector/OIInspector.h>

@class RSSelector, RSGraphElement, RSGraph, RSGraphEditor, RSVertex, RSLine;

@interface StyleInspector : OIInspector <OIConcreteInspector> {
    RSGraphEditor *_editor;
    RSSelector *_s;
    
    BOOL _textDidChange;
}

// Outlets
@property (nonatomic, assign) IBOutlet id widthSlider;
@property (nonatomic, assign) IBOutlet id widthText;
@property (nonatomic, assign) IBOutlet id widthField;
@property (nonatomic, assign) IBOutlet id colorWell;
@property (nonatomic, assign) IBOutlet id colorText;
@property (nonatomic, assign) IBOutlet id opacitySlider;
@property (nonatomic, assign) IBOutlet id opacityButtonLeft;
@property (nonatomic, assign) IBOutlet id opacityButtonRight;

@property (nonatomic, assign) IBOutlet id pointTypeControl;
@property (nonatomic, assign) IBOutlet id shapePopUp;
@property (nonatomic, assign) IBOutlet id shapeText;

@property (nonatomic, assign) IBOutlet id dashPopUp;
@property (nonatomic, assign) IBOutlet id dashText;
@property (nonatomic, assign) IBOutlet NSSegmentedControl *lineTypeControl;
@property (nonatomic, assign) IBOutlet id lineTypeText;
@property (nonatomic, assign) IBOutlet id leftArrowCheckBox;
@property (nonatomic, assign) IBOutlet id rightArrowCheckBox;
@property (nonatomic, assign) IBOutlet id arrowGraphic;
@property (nonatomic, assign) IBOutlet id arrowText;

@property (nonatomic, assign) IBOutlet id labelField;
@property (nonatomic, assign) IBOutlet id labelText;
@property (nonatomic, assign) IBOutlet id fontSizeSlider;
@property (nonatomic, assign) IBOutlet id fontSizeField;
@property (nonatomic, assign) IBOutlet id fontSizeText;
@property (nonatomic, assign) IBOutlet id distanceSlider;
@property (nonatomic, assign) IBOutlet id distanceField;
@property (nonatomic, assign) IBOutlet id distanceText;
@property (nonatomic, assign) IBOutlet id distanceSuffix;
@property (nonatomic, assign) IBOutlet id fontButton;
@property (nonatomic, assign) IBOutlet id fontText;

@property (nonatomic, assign) IBOutlet NSTextField *x1;
@property (nonatomic, assign) IBOutlet NSTextField *y1;

@property (nonatomic, assign) IBOutlet id pointsText;
@property (nonatomic, assign) IBOutlet id point1Text;
@property (nonatomic, assign) IBOutlet id point2Text;

// Accessors
@property(nonatomic,readonly) RSGraph *graph;
- (BOOL)graphExists;
@property(assign) RSGraphEditor *editor;
@property(nonatomic,assign) RSGraphElement *selection;
- (void)updateSelection;
- (BOOL)isSelected;
- (BOOL)hasDash;
- (BOOL)canHaveArrows;


// IBActions
- (IBAction)changeThickness:(id)sender;
- (IBAction)changeColor:(id)sender;
- (IBAction)changeOpacity:(id)sender;

- (IBAction)changePointType:(id)sender;
- (IBAction)changeShapePopUp:(id)sender;
- (IBAction)changeLineType:(id)sender;
- (IBAction)changeDashPopUp:(id)sender;
- (IBAction)changeArrowhead:(id)sender;

- (IBAction)changeAssociatedLabel:(id)sender;
- (IBAction)showFontPicker:(id)sender;
- (IBAction)changeFontSize:(id)sender;
- (IBAction)changeDistanceSliderValue:(id)sender;

- (IBAction)changeX1:(id)sender;
- (IBAction)changeY1:(id)sender;


@end
