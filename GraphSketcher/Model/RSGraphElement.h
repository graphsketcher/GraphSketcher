// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/Model/RSGraphElement.h 200244 2013-12-10 00:11:55Z correia $

// Almost everything that can be placed on a graph is a subclass of RSGraphElement.

#import <OmniFoundation/OFObject.h>
#import <OmniFoundation/OFXMLIdentifierRegistryObject.h>
#import <GraphSketcherModel/RSNumber.h>

@class NSArray;
@class OQColor;
@class OAFontDescriptor;
@class RSGraph, RSTextLabel, RSGroup;


///////////////////////////////////////////////////////

#define RSGraphElementPboardType @"RSGraphElementPboardType"
#define OmniDataOnlyTabularPboardType @"OmniDataOnlyTabularPboardType"

#define RS_BAR_WIDTH_FACTOR 6

// THE FOLLOWING INT ASSIGNMENTS CANNOT BE CHANGED FOR BACKWARDS COMPATIBILITY REASONS

//
#pragma mark Shapes

#define RS_NONE 0
#define RS_CIRCLE 1
#define RS_TRIANGLE 2
#define RS_SQUARE 3
#define RS_STAR 4
#define RS_DIAMOND 5
#define RS_X 6
#define RS_CROSS 7
#define RS_HOLLOW 8
#define RS_TICKMARK 9

#define RS_LAST_STANDARD_SHAPE 8

#define RS_BAR_VERTICAL 201
#define RS_BAR_HORIZONTAL 202

#define RS_ARROW 100	// new in OGS
#define RS_LEFT_ARROW 101
#define RS_RIGHT_ARROW 102
#define RS_BOTH_ARROW 103

#define RS_SHAPE_MIXED 999

//
#pragma mark Strokes

#define RS_ARROWS_DASH 101
#define RS_REVERSE_ARROWS_DASH 102
#define RS_RAILROAD_DASH 103

#define RS_DASH_MIXED 999

typedef NS_ENUM(NSInteger, RSConnectType) {
    RSConnectNotApplicable = 0,
    RSConnectNone = 1,
    RSConnectStraight = 2,
    RSConnectCurved = 3,
    RSConnectLinearRegression = 4,
    RSConnectMixed = 100,
};

#define RS_FORWARD 1
#define RS_BACKWARD 2

//
#pragma mark Axis-related

#define RSMaximumNumberOfTicks 200
#define RSMaximumNumberOfTicksForAutoSpacingEqualToOne 50
#define RSMinimumNumberOfTicksForAutoSpacingEqualToOne 4
#define RSMagnitudeOfRangeForRegimeBoundaryAutoSpacing 50
#define RSMagnitudeOfRangeForLogarithmicAutoScaling 2.0

#define RS_AXIS_MAX_MAX 1e300  // Approximately 8 orders of magnitude less than DBL_MAX
#define RS_AXIS_MIN_MIN -1e300

#define RS_ORIENTATION_UNASSIGNED -1
#define RS_ORIENTATION_HORIZONTAL 0
#define RS_ORIENTATION_VERTICAL 1

CGFloat dimensionOfPointInOrientation(CGPoint p, int orientation);
data_p dimensionOfDataPointInOrientation(RSDataPoint p, int orientation);
CGFloat dimensionOfSizeInOrientation(CGSize size, int orientation);

typedef NS_ENUM(NSInteger, RSAxisEdge) {
    RSAxisEdgeMin = 1,
    RSAxisEdgeMax = 2,
};

typedef NS_ENUM(NSInteger, RSAxisType) {
    RSAxisTypeLinear = 1,
    RSAxisTypeLogarithmic = 2,
    RSAxisTypeDate = 3,
};

#define RS_DELETED_STRING @"   "


typedef enum _RSGraphElementSubpart {
    RSGraphElementSubpartWhole = 0,
    RSGraphElementSubpartBarEnd = 1,
} RSGraphElementSubpart;



@interface RSGraphElement : OFObject <NSCopying, OFXMLIdentifierRegistryObject>
{
    NSString *_identifier;
    RSGraph *_graph;
}

- (void)invalidate;

// Designated (superclass) initializer:
- (id)initWithGraph:(RSGraph *)graph identifier:(NSString *)identifier;
- (id)initWithoutIdentifier;  // Used by RSUnknown
@property(readonly) RSGraph *graph;
- (NSString *)identifier;


// Handling sets of RSGraphElements
- (RSGraphElement *)makeDuplicateIfGroup;
- (RSGraphElement *)elementEorElement:(RSGraphElement *)e;
- (RSGraphElement *)elementWithElement:(RSGraphElement *)e;
- (RSGraphElement *)elementWithoutElement:(RSGraphElement *)e;
- (RSGraphElement *)elementIncludingElement:(RSGraphElement *)e;
- (RSGraphElement *)elementWithClass:(Class)c;
- (NSUInteger)numberOfElementsWithClass:(Class)c;
- (NSArray *)elements;
- (NSArray *)connectedElements;
- (NSArray *)elementsBetweenElement:(RSGraphElement *)e1 andElement:(RSGraphElement *)e2;
- (RSGraphElement *)elementWithGroup;
- (BOOL)containsElement:(RSGraphElement *)e;


///////////////
// Default methods that subclasses should generally override:

// Graphical properties
- (OQColor *)color;
- (void)setColor:(OQColor *)color;
- (CGFloat)opacity;
- (void)setOpacity:(CGFloat)opacity;
- (BOOL)hasColor;
- (CGFloat)width;
- (void)setWidth:(CGFloat)width;
- (BOOL)hasWidth;
- (NSInteger)dash;
- (void)setDash:(NSInteger)style;
- (BOOL)hasDash;
- (NSInteger)shape;
- (void)setShape:(NSInteger)style;
- (BOOL)hasShape;
- (BOOL)canHaveArrows;
- (BOOL)hasUserCoords;
- (RSDataPoint)position;
- (void)setPosition:(RSDataPoint)p;
- (void)setPositionx:(data_p)val;
- (void)setPositiony:(data_p)val;
- (void)setPositionWithoutLoggingUndo:(RSDataPoint)p;
- (RSDataPoint)positionUR;
- (void)setCenterPosition:(RSDataPoint)center;
- (CGSize)size;
- (void)setSize:(CGSize)newSize;
- (RSConnectType)connectMethod;
- (void)setConnectMethod:(RSConnectType)val;
- (BOOL)hasConnectMethod;
- (BOOL)canBeConnected;

// Text Label properties:
- (RSTextLabel *)label;
- (void)setLabel:(RSTextLabel *)label;  // DO NOT CALL DIRECTLY IN MOST CASES
- (NSString *)text;
- (void)setText:(NSString *)text;
- (NSAttributedString *)attributedString;
- (void)setAttributedString:(NSAttributedString *)text;
- (BOOL)isLabelable;
- (BOOL)hasLabel;
- (CGFloat)labelDistance;
- (void)setLabelDistance:(CGFloat)value;
- (BOOL)hasLabelDistance;
- (RSGraphElement *)owner;
- (void)setOwner:(RSGraphElement *)owner;
- (BOOL)canBeDetached;

// Manipulation and bookkeeping properties:
- (RSGroup *)group;
- (void)setGroup:(RSGroup *)newGroup;  // don't call this directly -- call RSGraph's [setGroup:forElement:]
- (BOOL)isLockable;
- (BOOL)locked;
- (void)setLocked:(BOOL)val;
- (BOOL)isPartOfAxis;
- (BOOL)isMovable;
- (BOOL)isVisible;
- (BOOL)canBeCopied;

- (void)addParent:(id)parent;
- (void)removeParent:(id)parent;
- (RSGraphElement *)groupWithVertices;
- (id)paramForElement:(RSGraphElement *)GE;  // helps out [RSVertex paramOfSnappedToElement]

- (NSUInteger)count;
- (int)axisOrientation;
- (data_p)tickValue;

// Maintaining snapped-tos
//! These need better names
- (BOOL)hasChanged;
- (void)setHasChanged:(BOOL)flag;

// Maintaining best-fit lines
- (void)setNeedsRecompute;
- (BOOL)recomputeNow;

// Actions
- (RSGraphElement *)shake;

// Describing elements
- (NSString *)infoString;  // the representation that shows up in the status bar
- (NSString *)stringRepresentation;

@end
