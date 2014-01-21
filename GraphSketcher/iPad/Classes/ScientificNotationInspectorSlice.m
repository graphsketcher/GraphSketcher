// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/iPad/Classes/ScientificNotationInspectorSlice.m 200244 2013-12-10 00:11:55Z correia $

#import "ScientificNotationInspectorSlice.h"

#import "InspectorSupport.h"
#import <OmniUI/OUISegmentedControl.h>
#import <OmniUI/OUISegmentedControlButton.h>
#import <OmniUI/OUIDrawing.h>

#import <GraphSketcherModel/RSTextLabel.h>
#import <OmniUI/OUITextLayout.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/iPad/Classes/ScientificNotationInspectorSlice.m 200244 2013-12-10 00:11:55Z correia $");

@implementation ScientificNotationInspectorSlice

- (void)dealloc;
{
    [segmentedControl release];
    segmentedControl = nil;
    
    [_segmentNumberFormatter release];
    _segmentNumberFormatter = nil;

    [super dealloc];
}

- (IBAction)changeScientificNotationSetting:(OUISegmentedControl *)sender;
{
    OUISegmentedControlButton *segment = [sender selectedSegment];
    RSScientificNotationSetting setting = [segment tag];
    
    [self.inspector willBeginChangingInspectedObjects];
    {
        for (RSAxis *axis in self.appropriateObjectsForInspection) {
            axis.scientificNotationSetting = setting;
        }
    }
    [self.inspector didEndChangingInspectedObjects];
}

- (NSNumberFormatter *)segmentNumberFormatter;
{
    if (!_segmentNumberFormatter) {
        _segmentNumberFormatter = [[NSNumberFormatter alloc] init];
        
        [_segmentNumberFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
    }
    
    return _segmentNumberFormatter;
}

- (NSString *)nonScientificNotationString;
{
    NSNumberFormatter *formatter = [self segmentNumberFormatter];
                                    
    [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
    
    [formatter setLenient:YES];
    [formatter setUsesSignificantDigits:YES];
    [formatter setZeroSymbol:@"0"];
    
    [formatter setUsesGroupingSeparator:YES];
    
    NSString *string = [formatter stringFromNumber:[NSNumber numberWithInteger:10000]];
    return string;
}

- (NSString *)scientificNotationString;
{
    NSNumberFormatter *formatter = [self segmentNumberFormatter];
    
    [formatter setNumberStyle:NSNumberFormatterScientificStyle];
    
    [formatter setLenient:YES];
    [formatter setUsesSignificantDigits:YES];
    [formatter setZeroSymbol:@"0"];
    
    [formatter setUsesGroupingSeparator:NO];
    
    NSString *string = [formatter stringFromNumber:[NSNumber numberWithInteger:10000]];
    return string;
}

- (UIImage *)imageFromString:(NSString *)string;
{
    NSDictionary *attributes = @{NSFontAttributeName:[UIFont fontWithName:@"Helvetica" size:17],
                                 NSForegroundColorAttributeName:[OUIInspector labelTextColor]};
    NSAttributedString *attString = [[[NSAttributedString alloc] initWithString:string attributes:attributes] autorelease];
        
    // Superscript
    NSAttributedString *superscriptString = [RSTextLabel formatExponentsInString:attString exponentSymbol:[[self segmentNumberFormatter] exponentSymbol] removeLeadingOne:YES];
    
    return [OUITextLayout imageFromAttributedString:superscriptString];
}

#pragma mark - OUIInspectorSlice subclass

- (BOOL)isAppropriateForInspectedObject:(id)object;
{
    if (![object isKindOfClass:[RSAxis class]])
        return NO;
    return [(RSGraphElement *)object canHaveArrows];
}

- (void)updateInterfaceFromInspectedObjects:(OUIInspectorUpdateReason)reason;
{
    NSNumber *singleValue = [self singleSelectedValueForIntegerSelector:@selector(scientificNotationSetting)];
    RSScientificNotationSetting setting = [singleValue integerValue];
    
    for (NSUInteger i = 0; i < segmentedControl.segmentCount; i += 1) {
        OUISegmentedControlButton *segment = [segmentedControl segmentAtIndex:i];
        if ([segment tag] == setting) {
            segmentedControl.selectedSegment = segment;
        }
    }
}

#pragma mark -
#pragma mark UIViewController subclass

/* We would only have one view in our .nib and we'd have to do most of the setup by hand anyway, so not bothering with a .nib. */
- (void)loadView;
{
    OBPRECONDITION(segmentedControl == nil);
    
    // We'll be resized by the stack view
    OUISegmentedControl *sciNotationBar = [[OUISegmentedControl alloc] initWithFrame:(CGRect){{0,0}, {OUIInspectorContentWidth, [OUISegmentedControl buttonHeight]}}];
    sciNotationBar.sizesSegmentsToFit = YES;
    sciNotationBar.allowsEmptySelection = YES;
    
    OUISegmentedControlButton *button;
        
    //button = [sciNotationBar addSegmentWithImageNamed:@"ScientificNotationSettingOff.png"];
    button = [sciNotationBar addSegmentWithText:[self nonScientificNotationString]];
    [button setTag:RSScientificNotationSettingOff];
    
    button = [sciNotationBar addSegmentWithText:NSLocalizedStringFromTableInBundle(@"Auto", @"Inspector", OMNI_BUNDLE, @"Text in scientific notation segmented control on the axis inspector.")];
    [button setTag:RSScientificNotationSettingAuto];

    //button = [sciNotationBar addSegmentWithImageNamed:@"ScientificNotationSettingOn.png"];
    UIImage *buttonImage = [self imageFromString:[self scientificNotationString]];
    button = [sciNotationBar addSegmentWithImage:buttonImage representedObject:nil];
    [button setTag:RSScientificNotationSettingOn];

    [sciNotationBar addTarget:self action:@selector(changeScientificNotationSetting:) forControlEvents:UIControlEventValueChanged];
    
    self.view = sciNotationBar;
    segmentedControl = sciNotationBar; // Retain moves from our local var to the ivar
}

@end

