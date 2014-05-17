// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OmniBase/OBObject.h>

#import <GraphSketcherModel/RSGraphElement.h> // lots of enums
#import <GraphSketcherModel/RSAxis.h> // RSAxisPlacement
#import <GraphSketcherModel/RSGraphDelegate.h>

@class OSStyleContext, OSStyle;
@class RSAxis, OQColor, RSUndoer, RSLine, RSVertex, RSTextLabel, RSGraphElement, RSFill, RSConnectLine, RSGroup, RSFitLine, RSEquationLine;

// Percentage of auto-scaled graph allowed to be between origin and first data point.  This MUST be less than 0.5:
#define RS_SCALE_TO_FIT_MAX_SPACE_TO_ZERO_PERCENTAGE (0.38f)

// Minimum percentage of auto-scaled graph between data rect and axis rect:
#define RS_SCALE_TO_FIT_BORDER_PERCENTAGE (0.01f)

// automatically expand axis ranges for imported data when the data takes up less than this percentage of the axis range:
#define RS_SCALE_TO_FIT_EXPAND_CUTOFF (0.05f)

#define RSMinGraphSize CGSizeMake(50, 20)

#define RSAddJitterToDataPercentage 0.01  // Standard deviation for the Jitter command is the y-range times this

#define RS_STRING_DRAWING_OPTIONS NSStringDrawingUsesLineFragmentOrigin

typedef enum _RSAxisEnd {
    RSAxisEndNone = 0,
    RSAxisXMin = 1,
    RSAxisXMax = 2,
    RSAxisYMin = 3,
    RSAxisYMax = 4,
} RSAxisEnd;

typedef struct _RSBorder {
    CGFloat top;
    CGFloat right;
    CGFloat bottom;
    CGFloat left;
} RSBorder;

typedef struct _RSSummaryStatistics {
    data_p min;
    data_p firstQuartile;
    data_p median;
    data_p thirdQuartile;
    data_p max;
} RSSummaryStatistics;

#define RSBORDER_TOP 1
#define RSBORDER_RIGHT 2
#define RSBORDER_BOTTOM 3
#define RSBORDER_LEFT 4

RSBorder RSMakeBorder(CGFloat top, CGFloat right, CGFloat bottom, CGFloat left);
RSBorder RSUnionBorder(RSBorder b1, RSBorder b2);
RSBorder RSSumBorder(RSBorder b1, RSBorder b2);
BOOL RSEqualBorders(RSBorder b1, RSBorder b2);
CGRect RSAddBorderToPoint(RSBorder b, CGPoint p);
NSString *RSStringFromBorder(RSBorder b);
RSBorder RSBorderFromString(NSString *s);

CGPoint frameOriginFromFrameString(NSString *s);
CGSize canvasSizeFromFrameString(NSString *string);
#if !defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE
NSString *messageForCanvasSize(CGSize size);
#endif


@interface RSGraph : OBObject
{
    NSMutableArray *Vertices;
    NSMutableArray *Lines;
    NSMutableArray *Labels;
    NSMutableArray *Fills;
    NSMutableArray *_groups;
    
    RSAxis *_xAxis;
    RSAxis *_yAxis;
    
    OQColor *_bgColor;
    CGFloat _shadowStrength;  // strength of shadow (0 is "off")
    
    CGSize _canvasSize;
    CGPoint _frameOrigin;
    RSBorder _whitespace;  // border (in pixels) on each side of the axis rectangle (space for axis labels)
    
    // Used for auto-whitespace calculations
    BOOL _autoMaintainsWhitespace;
    RSBorder _edgePadding;  // minimal space between edge of canvas and axis labels (for auto-expanding whitespace)
    
    RSUndoer *_u;
    OFXMLIdentifierRegistry *_idRegistry;  // The identifier registry for XML encoding
    NSUInteger _idCounter;
    NSMutableDictionary *_idPasteMap;
    OSStyleContext *_styleContext;
    OSStyle *_baseStyle;
    
    id <RSGraphDelegate> _delegate;  // Object that gets notifications about changes to the model
    
    CGFloat _windowAlpha;  // desired opacity of window
    
    // Backwards compatibility
    CGFloat _xMinWhiteSpace;	// white space scaling factor to the left
    CGFloat _xMaxWhiteSpace;	// ditto... to the right
    CGFloat _yMinWhiteSpace;	// ... bottom
    CGFloat _yMaxWhiteSpace;	// top
    CGSize _labelToAxisSpace;	// space between tick labels and axis
    CGSize _axisTitleSpace;     // space between axis titles and tick labels  // now we use [axis titleDistance]
    NSMutableArray *_IPs;	// Intersection Points
    
    // Experimental
    BOOL _displayHistogram;
    BOOL _tufteEasterEgg;
}

// Controller and identifier registry
@property(nonatomic,retain) RSUndoer *undoer; // Only writable for backwards compatiblity NSCoder-based loading.
@property(nonatomic,readonly) NSUndoManager *undoManager;
@property(readonly) OSStyleContext *styleContext;
@property(nonatomic, retain) NSMutableDictionary *idPasteMap;

- (NSString *)generateIdentifier;
- (void)registerNewIdentiferForObject:(id <OFXMLIdentifierRegistryObject>)object;
- (void)registerIdentifier:(NSString *)identifier forObject:(id <OFXMLIdentifierRegistryObject>)object;
- (NSString *)identiferForObject:(id <OFXMLIdentifierRegistryObject>)object;
- (void)deregisterObjectWithIdentifier:(NSString *)identifier;
- (id)objectForIdentifier:(NSString *)identifier;
- (BOOL)containsObjectForIdentifier:(NSString *)identifier;
- (id)createObjectForIdentifier:(NSString *)identifier ofClass:(Class)class;


// Delegate
@property(assign) id <RSGraphDelegate> delegate;


// Designated initializer:
- (id)initWithIdentifier:(NSString *)identifier undoer:(RSUndoer *)undoer;

- (void)invalidate;
- (void)setupDefault;


// Utility methods
+ (RSLine *)firstParentLineOf:(RSVertex *)V;
+ (RSTextLabel *)labelOf:(RSGraphElement *)GE;
+ (RSGraphElement *)labelFromElement:(RSGraphElement *)obj;
+ (RSGraphElement <RSFontAttributes> *)fontAtrributeElementForElement:(RSGraphElement *)obj;
+ (RSLine *)isLine:(RSGraphElement *)GE;
+ (RSFill *)isFill:(RSGraphElement *)GE;
+ (RSVertex *)isVertex:(RSGraphElement *)GE;
+ (RSLine *)commonParentLine:(NSArray *)A;
+ (RSLine *)singleParentLine:(NSArray *)A;
+ (BOOL)hasStraightSegments:(RSGraphElement *)GE;
+ (BOOL)isText:(RSGraphElement *)GE;
+ (BOOL)hasVertices:(RSGraphElement *)GE;
+ (BOOL)hasMultipleVertices:(RSGraphElement *)GE;
+ (BOOL)hasAtLeastThreeVertices:(RSGraphElement *)GE;
+ (BOOL)hasArrow:(RSGraphElement *)GE onEnd:(int)endSpecifier;
+ (NSInteger)vertexHasShape:(RSVertex *)V;
+ (BOOL)isPointAndFill:(RSGraphElement *)GE;
+ (NSString *)tabularStringRepresentationOfPointsIn:(RSGraphElement *)GE;
- (RSDataPoint)dataMinsOfGraphElements:(NSArray *)array;
- (RSDataPoint)dataMaxesOfGraphElements:(NSArray *)array;
+ (RSDataPoint)meanOfGroup:(RSGroup *)G;
+ (RSDataPoint)centerOfGravity:(RSGroup *)G;
+ (RSSummaryStatistics)summaryStatisticsOfGroup:(RSGroup *)G inOrientation:(int)orientation;
+ (RSGraphElement *)prepareForPasteboard:(RSGraphElement *)GE;
+ (RSGraphElement *)prepareToPaste:(RSGraphElement *)GE;
+ (RSGraphElement *)omitVerticesWithSomeParentsNotInGroup:(RSGraphElement *)GE;
+ (RSGraphElement *)elementsToDelete:(RSGraphElement *)GE;
+ (NSArray *)elementsWithPrimaryPosition:(RSGraphElement *)GE;
+ (RSGroup *)elementsToMove:(RSGraphElement *)GE;


// Adding/removing elements from graph:
- (void)addVertex:(RSVertex *)V;
- (void)removeVertex:(RSVertex *)V;
- (void)addLine:(RSLine *)line;
- (void)removeLine:(RSLine *)line;
- (void)addLabel:(RSTextLabel *)label;
- (void)removeLabel:(RSTextLabel *)label;
- (void)addFill:(RSFill *)fill;
- (void)removeFill:(RSFill *)fill;
- (void)removeAxis:(RSAxis *)axis;
- (void)addElement:(RSGraphElement *)e;
- (void)removeElement:(RSGraphElement *)e;


// Special action methods for graph elements
- (RSConnectLine *)connect:(RSGraphElement *)group;
- (void)connectCircular:(RSGroup *)group;
- (RSGraphElement *)changeLineTypeOf:(RSGraphElement *)obj toConnectMethod:(RSConnectType)connectMethod;
- (RSGraphElement *)changeLineTypeOf:(RSGraphElement *)obj toConnectMethod:(RSConnectType)connectMethod sort:(BOOL)shouldSort;
- (void)polygonize:(RSGroup *)group;
- (RSFitLine *)addBestFitLineFromGroup:(RSGroup *)G;
//- (BOOL)addVertex:(RSVertex *)V toLine:(RSLine *)L atIndex:(NSUInteger)index;
//- (BOOL)removeVertex:(RSVertex *)V fromLine:(RSLine *)L;
- (BOOL)addVertex:(RSVertex *)V toFill:(RSFill *)F atIndex:(NSUInteger)index;
- (void)removeVertex:(RSVertex *)V fromFill:(RSFill *)F;
- (void)swapAxes;
- (RSTextLabel *)makeLabelForOwner:(RSGraphElement *)GE;
- (void)setGroup:(RSGroup *)newGroup forElement:(RSGraphElement *)GE;
- (void)recordGroup:(RSGroup *)G;
- (void)unsnapVerticesFromLine:(RSLine *)L;
- (void)detachElements:(RSGraphElement *)GE;
- (BOOL)recomputeNow;
#if !defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE
- (RSGroup *)createErrorBarsWithSelection:(RSGraphElement *)selection;
- (RSGroup *)createConstantErrorBarsWithSelection:(RSGraphElement *)selection posOffset:(data_p)posOffset negOffset:(data_p)negOffset;
#endif
- (NSArray *)importedDataPrototypes;

// Accessor methods for graph properties
@property(nonatomic,copy) OQColor *backgroundColor; // canvas color

- (BOOL)displayAxes;
- (void)setDisplayAxes:(BOOL)flag;
- (BOOL)displayAxisLabels;
- (BOOL)shouldDisplayLabel:(RSGraphElement *)TL;
- (BOOL)displayAxisTicks;
- (void)setDisplayAxisTicks:(BOOL)flag;
- (BOOL)displayAxisTitles;
- (void)setDisplayAxisTitles:(BOOL)flag;
- (BOOL)noAxisComponentsAreDisplayed;
- (BOOL)noGridComponentsAreDisplayed;

- (CGFloat)shadowStrength;
- (void)setShadowStrength:(CGFloat)value;

@property(nonatomic) RSBorder whitespace;
@property(readonly) RSBorder edgePadding;
@property(nonatomic) BOOL autoMaintainsWhitespace;

@property CGPoint frameOrigin;

- (CGSize)canvasSize;
- (void)setCanvasSize:(CGSize)size;
- (CGSize)minCanvasSize;
- (CGSize)sizeOfGraphRect;
- (CGSize)potentialWhitespaceExpansionSize;


// Graph element accessor methods:
- (NSArray *)Lines;
- (NSMutableArray *)Vertices;
- (NSArray *)Labels;
- (NSArray *)userLabels;  // "non-axis labels"
- (NSArray *)allLabels;
- (NSMutableArray *)labelsAsStrings;
- (NSArray *)Fills;
- (NSArray *)groups;
- (RSGroup *)userElements;
- (RSGroup *)userVertexElements;
- (NSArray *)userLineElements;
- (RSGraphElement *)userFillElements;
- (RSGraphElement *)allLabelElements;
- (RSGroup *)fitLineElements;
- (RSGroup *)dataVertices;
- (RSGraphElement *)elementsConnectedTo:(RSGraphElement *)root;
- (RSGraphElement *)graphElementFromArray:(NSArray *)elements;

- (BOOL)is:(RSGraphElement *)one above:(RSGraphElement *)two;
- (RSLine *)lineConnectingVertex:(RSVertex *)V1 andVertex:(RSVertex *)V2;


// Axis accessor methods
- (RSAxis *)xAxis;
- (RSAxis *)yAxis;
- (RSAxis *)axisWithOrientation:(int)orientation;
- (RSAxis *)axisWithAxisEnd:(RSAxisEnd)axisEnd;
- (RSAxis *)otherAxis:(RSAxis *)A;
- (RSAxis *)axisOfElement:(RSGraphElement *)GE;
- (void)setAxis:(RSAxis *)axis forOrientation:(int)orientation;
- (data_p)xMin;
- (data_p)xMax;
- (data_p)yMin;
- (data_p)yMax;
- (void)setXMin:(data_p)value;
- (void)setXMax:(data_p)value;
- (void)setYMin:(data_p)value;
- (void)setYMax:(data_p)value;
- (void)setMin:(data_p)value forAxis:(RSAxis *)axis;
- (void)setMax:(data_p)value forAxis:(RSAxis *)axis;
- (void)setAxisRangesXMin:(data_p)xmin xMax:(data_p)xmax yMin:(data_p)ymin yMax:(data_p)ymax;
- (BOOL)prepareUndoForAxisRanges;
- (BOOL)hasLogarithmicAxis;

- (RSAxisPlacement)axisPlacement;
- (void)setAxisPlacement:(RSAxisPlacement)placement;
- (BOOL)isAxisTitle:(RSTextLabel *)TL;
- (BOOL)isAxisTickLabel:(RSGraphElement *)TL;
- (BOOL)isAxisEndLabel:(RSGraphElement *)TL;
- (BOOL)isDragResizer:(RSGraphElement *)GE forAxis:(RSAxis *)A;
- (BOOL)isAxisLabel:(RSGraphElement *)TL;
- (data_p)tickValueOfAxisEnd:(RSAxisEnd)axisEnd;
- (void)hideEndLabelsForAxis:(RSAxis *)A;
- (void)displayTicksIfNecessaryOnAxis:(RSAxis *)axis;


// Grid accessor methods
- (RSGrid *)xGrid;
- (RSGrid *)yGrid;
- (BOOL)displayGrid;
- (BOOL)displayBothGrids;
- (BOOL)bothGridsAreEvenlySpaced;
- (void)setDisplayGrid:(BOOL)flag;
- (void)displayGridIfNotAlready;
- (CGFloat)gridWidth;
- (void)setGridWidth:(CGFloat)width;
- (OQColor *)gridColor;
- (void)setGridColor:(OQColor *)newColor;


// Number formatting
- (NSString *)stringForDataValue:(data_p)val inDimension:(int)orientation;
- (NSString *)infoStringForPoint:(RSDataPoint)p;


// For debugging and legacy unarchiving
- (BOOL)containsElement:(RSGraphElement *)GE;


// Experimental features
- (BOOL)displayHistogram;
- (void)setDisplayHistogram:(BOOL)flag;


// Other app properties
@property(assign) CGFloat windowAlpha;
@property BOOL tufteEasterEgg;

@end

extern NSString * const RSGraphFileType;

@interface RSGraph (Archiving)

+ (RSGraph *)graphFromData:(NSData *)data fileName:(NSString *)fileName type:(NSString *)typeName undoer:(RSUndoer *)undoer error:(NSError **)outError;
+ (RSGraph *)graphFromURL:(NSURL *)url type:(NSString *)typeName undoer:(RSUndoer *)undoer error:(NSError **)outError;
+ (BOOL)getGraphPDFPreviewData:(NSData **)outPDFData modificationDate:(NSDate **)outModificationDate fromURL:(NSURL *)url error:(NSError **)outError;

- (NSData *)generateXMLOfType:(NSString *)typeName frame:(CGRect)frame error:(NSError **)outError;

#if !defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE
- (BOOL)writeToURL:(NSURL *)url generatedXMLData:(NSData *)xmlData previewPDFData:(NSData *)previewPDFData error:(NSError **)outError;
#endif

@end

