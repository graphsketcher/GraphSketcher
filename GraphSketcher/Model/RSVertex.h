// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <GraphSketcherModel/RSGraphElement.h>

@class RSGroup, RSLine, RSFill, RSTextLabel, RSUnknown;

@interface RSVertex : RSGraphElement
{
    RSDataPoint _p;
    CGFloat _width;
    OQColor *_color;
    NSInteger _shape;
    id _arrowParent;
    CGFloat _rotation;  // applies to certain point types (tick marks, arrows)
    
    NSMutableArray *_parents;
    RSTextLabel *_label;
    CGFloat _labelPosition;  // an angle between 0 and 2*M_PI; 0 is to the right.
    CGFloat _labelDistance;  // distance in pixels
    BOOL _locked;
    
    RSGroup *_snappedTo;  // things the vertex was most recently snapped to (e.g. a line)
    NSMutableArray *_snappedToParams;  // associated parameters for _snappedTo elements
    
    RSGroup *_group;  // non-retained
    data_p _sortValue;
}


- (id)initWithGraph:(RSGraph *)graph;

// Special copier:
- (id)parentlessCopy NS_RETURNS_RETAINED;

// Designated initializer:
- (id)initWithGraph:(RSGraph *)graph identifier:(NSString *)identifier point:(RSDataPoint)p width:(CGFloat)width color:(OQColor *)color shape:(NSInteger)shape;

- (void)acceptLatestDefaults;


// Accessor methods:
- (BOOL)isBar;
@property (nonatomic, assign) CGFloat labelPosition;
- (CGFloat)widthFromSize:(CGSize)size;
@property(assign) CGFloat rotation;


// Action methods:
- (void)setNeedsRecompute;


// Parents-related methods:
- (void)addParent:(id)e;
- (void)removeParent:(id)e;
- (BOOL)isParent:(RSGraphElement *)e;
- (NSMutableArray *)parents;
- (NSUInteger)parentCount;
- (RSLine *)lastParentLine;
- (RSFill *)lastParentFill;
- (NSArray *)connectedElements;

@property(assign) id arrowParent;
- (RSLine *)effectiveArrowParent;
- (BOOL)arrowParentIsLine:(RSLine *)L;


// Snapped-To methods
- (RSGroup *)snappedTo;  // returns the elements it was most recently snapped to, or nil if none
- (NSMutableArray *)snappedToParams;

// Snapped-to Changing
- (NSDictionary *)snappedToInfo;
- (void)setSnappedToWithInfo:(NSDictionary *)info;
- (void)setSnappedTo:(RSGroup *)G withParams:(NSMutableArray *)params;  // uses the group G as the set of snapped to elements
- (void)clearSnappedTo;  // removes all elements previously in snappedTo
- (void)clearExtendedSnapTos;
- (void)removeConstraints;
- (void)removeExtendedConstraints;
- (void)setVertexCluster:(NSArray *)newCluster;
- (BOOL)removeFromVertexCluster;
- (void)addToVertexCluster;
- (void)removeSnappedTo:(RSGraphElement *)GE;  // remove an element that the vertex is no longer snapped to
- (BOOL)shallowAddSnappedTo:(RSGraphElement *)GE withParam:(id)param;  // add an element that the vertex is snapped to, without notifying the snapped-to element
- (void)addSnappedTo:(RSGraphElement *)GE withParam:(id)obj;  // add an element that the vertex is snapped to

// Snapped-to Querying
- (NSArray *)vertexCluster;
- (NSArray *)parentsOfVertexCluster;
- (NSArray *)vertexSnappedTos;
- (NSArray *)nonVertexSnappedTos;
- (NSArray *)extendedIntersectionSnappedTos;
- (NSArray *)extendedNonVertexSnappedTos;
- (id)paramOfSnappedToElement:(RSGraphElement *)GE;
- (BOOL)isSnappedToElement:(RSGraphElement *)GE;
- (RSGroup *)snappedToThisAnd:(RSVertex *)other;  // all objects that both this and other are snapped to
+ (NSArray *)elementsTheseVerticesAreSnappedTo:(NSArray *)vertices;
- (BOOL)isConstrained;


// Sorting assistance:
- (NSComparisonResult)xSort:(id)other;
- (NSComparisonResult)ySort:(id)other;
- (NSComparisonResult)yAndColorSort:(id)other;
- (NSComparisonResult)labelSort:(id)other;
- (data_p)sortValue;
- (void)setSortValue:(data_p)value;
- (NSComparisonResult)valueSort:(id)other;


// Describing:
- (NSString *)infoString;
- (NSString *)tabularStringRepresentation;
- (NSString *)stringRepresentation;


// DEPRECATED
- (BOOL)containsLine:(RSLine *)line;	// for compatibility with RSIntersectionPoint


@end
