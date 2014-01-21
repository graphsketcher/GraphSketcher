// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/Model/RSAxis.h 200244 2013-12-10 00:11:55Z correia $

// RSAxis does a lot of interesting work, storing not only the visual axis settings (like -color and -width) but also the type of scale (linear vs logarithmic) and all the tick marks and tick labels.  It provides methods to format numeric tick labels, but it does not handle the work of actually laying out and choosing tick marks and tick labels (it just stores the results of that work).  There are two instances of RSAxis in an RSGraph.


#import <GraphSketcherModel/RSGraphElement.h>
#import <GraphSketcherModel/RSFontAttributes.h>

typedef enum _RSAxisPlacement {
    RSOriginPlacement = 1,
    RSEdgePlacement = 2,
    RSBothEdgesPlacement = 3,
    RSHiddenPlacement = 10,  // this is used in the inspector to mean _displayAxis = NO
} RSAxisPlacement;

typedef enum _RSAxisTickLayout {
    RSAxisTickLayoutSimple = 1,
    RSAxisTickLayoutAtData = 2,
    RSAxisTickLayoutHidden = 10,  // not currently used
} RSAxisTickLayout;

typedef enum _RSAxisExtent {
    RSAxisExtentFull = 1,
    RSAxisExtentDataRange = 2,
    RSAxisExtentDataQuartiles = 3,
} RSAxisExtent;

typedef enum _RSScientificNotationSetting {
    RSScientificNotationSettingOff = 0,
    RSScientificNotationSettingOn = 1,
    RSScientificNotationSettingAuto = 2,
} RSScientificNotationSetting;

#define DEFAULT_TICK_LABEL_PADDING_HORIZONTAL 10
#define DEFAULT_TICK_LABEL_PADDING_VERTICAL 4

#define RS_DEFAULT_SIGNIFICANT_DIGITS 4  // Minimum number of sig figs to display

#define RSScientificNotationAutoHighStart 1e7  // Scientific notation kicks in when axis range is >= this
#define RSScientificNotationAutoHighStartLogarithmic 1e5
#define RSScientificNotationOffHighStart 1e61
#define RSScientificNotationAutoLowStart 0.001  // Scientific notation kicks in when axis range is <= this
#define RSScientificNotationOffLowStart 1e-41

#define RSLogarithmicMinorLabelsMaxMagnitude 4  // Don't label minor ticks if the axis spans at least this many orders of magnitude
#define RSLogarithmicMinorGridLinesMaxMagnitude 5  // Don't use minor logarithmic grid lines if the axis spans at least this many orders of magnitude
#define RSLogarithmicMinorTickMarksMaxMagnitude 80  // Ditto for minor logarithmic tick marks
#define RSLogarithmicMinorTickMarksMinPixels 16  // Don't use minor logarithmic tick marks if there are fewer than this many pixels per regime.

@class RSGrid, RSTextLabel, RSGroup;

NSString *nameFromOrientation(int orientation);
int orientationFromName(NSString *name);
NSString *labelNameFromOrientation(int orientation);
NSString *nameFromPlacement(RSAxisPlacement placement);
RSAxisPlacement placementFromName(NSString *name);
NSString *nameFromExtent(RSAxisExtent extent);
RSAxisExtent extentFromName(NSString *name);
NSString *nameFromTickLayout(RSAxisTickLayout tickLayout);
RSAxisTickLayout tickLayoutFromName(NSString *name);
NSString *nameFromAxisType(int axisType);
int axisTypeFromName(NSString *name);
NSString *nameFromScientificNotationSetting(RSScientificNotationSetting setting);
RSScientificNotationSetting scientificNotationSettingFromName(NSString *name);


@interface RSAxis : RSGraphElement <RSFontAttributes>
{
    RSAxisType _axisType;  // such as linear, date/time, or log
    
    int _orientation;  // horizontal or vertical
    data_p _min, _max;
    data_p _logMin, _logMax;
    BOOL _userModifiedRange;
    data_p _spacing;  // i.e. tick spacing: the width between ticks
    data_p _userSpacing;  // the spacing manually set by the user; or 0 if not changed by user
    NSUInteger _spacingSigFigs;
    
    CGFloat _width;   // width of entire path
    OQColor *_color;
    
    RSAxisPlacement _placement;  // origin, edge, both-edges
    RSAxisTickLayout _tickLayout;
    RSAxisExtent _extent;
    
    RSGrid *_grid;
    
    int _tickType;  // in case I implement different styles of ticks
    CGFloat _tickWidthIn; // length of portion of tick on graph side
    CGFloat _tickWidthOut; // length of portion of tick on axis side
    NSInteger _shape;  // such as having arrows at the end
    
    CGFloat _labelDistance;
    CGFloat _tickLabelPadding;  // minimum space (in pixels) between neighboring tick labels
    CGFloat _titleDistance;  // space between the axis title and whatever is inward from it
    CGFloat _titlePlacement;  // percentage of the way along axis at which to anchor the title
    
    RSScientificNotationSetting _scientificNotation;
    
    RSTextLabel *_axisTitle;
    RSTextLabel *_maxLabel;
    RSTextLabel *_minLabel;
    
    BOOL _displayAxis;
    BOOL _displayTickLabels;
    BOOL _displayTicks;
    
    NSMutableDictionary *_userLabels; // stores custom axis labels, with key: a tick value
    
    NSMutableArray *_cachedTickArray;
    data_p _tickLabelSpacing;  // Calculated by the RSGraphRenderer and stored here (not archived to file)
    NSNumberFormatter *_tickLabelNumberFormatter;
    NSNumberFormatter *_inspectorNumberFormatter;
    
    // DEPRECATED
    BOOL _displayTitle;
}



// Initialization
- (id)initWithGraph:(RSGraph *)graph orientation:(int)orientation;
// Designated initializer:
- (id)initWithGraph:(RSGraph *)graph identifier:(NSString *)identifier orientation:(int)orientation min:(data_p)min max:(data_p)max;


// Axis layout/display settings:
- (CGFloat)tickWidthIn;
- (void)setTickWidthIn:(CGFloat)value;
- (CGFloat)tickWidthOut;
- (void)setTickWidthOut:(CGFloat)value;
- (CGFloat)labelDistance;
- (void)setLabelDistance:(CGFloat)value;
- (BOOL)displayAxis;
- (void)setDisplayAxis:(BOOL)flag;
- (BOOL)displayTickLabels;
- (void)setDisplayTickLabels:(BOOL)flag;
- (BOOL)displayTicks;
- (void)setDisplayTicks:(BOOL)flag;
- (BOOL)displayTitle;
- (void)setDisplayTitle:(BOOL)flag;
- (BOOL)displayGrid;
- (void)setDisplayGrid:(BOOL)flag;
@property(nonatomic) RSAxisPlacement placement;
@property(nonatomic) RSAxisTickLayout tickLayout;
- (void)toggleTickLayoutAtData;
@property (nonatomic) RSAxisExtent extent;

- (int)orientation;
- (void)setOrientation:(int)orientation;
- (RSTextLabel *)maxLabel;
- (RSTextLabel *)minLabel;
- (RSTextLabel *)title;
- (void)rotateTitle;
@property(nonatomic) CGFloat titleDistance;
@property(nonatomic) CGFloat titlePlacement;
@property(nonatomic) CGFloat tickLabelPadding;
- (BOOL)hasArrows;
- (BOOL)minEndIsArrow;
- (BOOL)maxEndIsArrow;
- (BOOL)shouldDrawMinArrow;
- (BOOL)shouldDrawMaxArrow;
- (BOOL)shouldDrawMinTick;
- (BOOL)shouldDrawMaxTick;

- (BOOL)noGridComponentsAreDisplayed;


// Axis range settings:
- (data_p)min;
- (data_p)max;
- (void)setMin:(data_p)value;
- (void)setMax:(data_p)value;
- (void)setMin:(data_p)min andMax:(data_p)max;
- (BOOL)valueIsNearlyEqualToZero:(data_p)value;
- (data_p)closestTickMarkToMin:(data_p)min;
- (data_p)closestTickMarkToMax:(data_p)max;
- (void)expandRangeToIncludeValue:(data_p)value;
- (void)expandRangeToIncludePoint:(RSDataPoint)p;
- (void)setRangeAsClosestTickMarksToMin:(data_p)min andMax:(data_p)max;
@property (nonatomic, assign) BOOL userModifiedRange;
@property (nonatomic, assign) RSScientificNotationSetting scientificNotationSetting;
- (data_p)visualOrigin;
- (BOOL)zeroLabelIsHidden;


// Axis Type:
- (RSAxisType)axisType;
- (void)setAxisType:(RSAxisType)type;
- (BOOL)isLinear;
- (BOOL)usesEvenlySpacedTickMarks;
- (BOOL)usesLinearAutoSpacing;


// Tick spacing
- (data_p)spacing;
- (void)setSpacing:(data_p)value;
- (void)updateSpacingSigFigs;
- (data_p)userSpacing;
- (void)setUserSpacing:(data_p)value;
- (void)updateTickMarks;
- (data_p)ordersOfMagnitude;  // returns a log base 10 value
- (data_p)calculateAutoSpacingForMin:(data_p)min max:(data_p)max;
- (data_p)snapTickSpacing:(data_p)spacing;
- (data_p)tickSpacingWithTickLimit:(NSInteger)tickLimit;
@property (nonatomic, assign) data_p tickLabelSpacing;
- (BOOL)usesMinorTicks;
- (BOOL)tickIsMinor:(data_p)tick;
- (data_p)firstTick;
- (data_p)controlTick;


// Computing tick marks
@property (nonatomic, retain) NSMutableArray *cachedTickArray;
- (NSMutableArray *)linearTicksWithSpacing:(data_p)spacing min:(data_p)min max:(data_p)max;
- (NSArray *)linearTicks;
- (NSMutableArray *)logarithmicTicksWithRegimeBoundarySpacing:(data_p)regimeBoundarySpacing min:(data_p)min max:(data_p)max;
- (NSArray *)logarithmicTicks;
- (NSArray *)allTicks;  // In ascending order. Does not include the min and max tick.
- (NSMutableArray *)samplingTicks;
- (NSMutableArray *)dataTicks;


// Grid
@property(nonatomic, retain) RSGrid *grid;


// Number formatting
- (NSUInteger)significantDigits;
- (BOOL)usesDecimalPoint;
- (BOOL)usesScientificNotation;
- (NSNumberFormatter *)tickLabelNumberFormatter;
- (void)resetNumberFormatters;
- (NSString *)formattedDataValue:(data_p)value;
- (NSString *)inspectorFormattedDataValue:(data_p)value;
- (data_p)dataValueFromFormat:(NSString *)format;
- (NSAttributedString *)formatExponentsInString:(NSAttributedString *)original;


// Tick labels
- (NSString *)keyStringForTick:(data_p)value;
- (NSString *)stringForTick:(data_p)value;
- (BOOL)userLabelIsCustomForTick:(data_p)value;
- (RSTextLabel *)userLabelForTick:(data_p)value;
- (void)setUserLabel:(RSTextLabel *)label forTick:(data_p)value;  // set label=nil to remove it
- (void)setUserLabel:(RSTextLabel *)label forTick:(data_p)value andKey:(NSString *)key;
- (void)setUserString:(NSString *)userString forTick:(data_p)value;
- (NSDictionary *)userLabelsDictionary;
- (RSGroup *)allUserLabels;
- (RSGroup *)visibleUserLabels;
- (BOOL)shouldDisplayLabel:(RSGraphElement *)TL;
- (void)updateAxisEndLabels;
- (void)resetUserLabelVisibility;
- (void)purgeUnnecessaryUserLabels;
- (void)resetTickLabelSizeCaches;


// Describing
- (NSString *)prettyName;


@end
