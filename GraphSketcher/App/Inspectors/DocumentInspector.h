// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OmniInspector/OIInspector.h>

@class GraphDocument, RSSelector, RSGraph;

@interface DocumentInspector : OIInspector <OIConcreteInspector>
{
    GraphDocument *_document;
    RSSelector *_s;
    RSGraph *_graph;
    NSString *originalShadowLabelString;
    BOOL _canEditWhitespace;
}

// Outlets
@property (nonatomic, retain) IBOutlet NSView *view;
@property (nonatomic, assign) IBOutlet id backgroundColorWell;
@property (nonatomic, assign) IBOutlet id shadowSlider;
@property (nonatomic, assign) IBOutlet id shadowLabel;

@property (nonatomic, assign) IBOutlet id canvasWidth;
@property (nonatomic, assign) IBOutlet id canvasWidthStepper;
@property (nonatomic, assign) IBOutlet id canvasHeight;
@property (nonatomic, assign) IBOutlet id canvasHeightStepper;

@property (nonatomic, assign) IBOutlet id automaticMarginCheckBox;
@property (nonatomic, assign) IBOutlet id marginLeft;
@property (nonatomic, assign) IBOutlet id marginTop;
@property (nonatomic, assign) IBOutlet id marginRight;
@property (nonatomic, assign) IBOutlet id marginBottom;

@property (nonatomic, assign) IBOutlet id windowTranslucencySlider;

// Accessors
@property(assign) GraphDocument *document;
- (BOOL)documentExists;
@property(assign) BOOL canEditWhitespace;


// IBActions
- (IBAction)changeBackgroundColor:(id)sender;
- (IBAction)changeShadowStrength:(id)sender;

- (IBAction)changeCanvasSize:(id)sender;
- (IBAction)changeMarginBorder:(id)sender;

- (IBAction)changeWindowTranslucency:(id)sender;


@end
