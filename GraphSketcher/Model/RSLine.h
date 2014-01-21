// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/Model/RSLine.h 200244 2013-12-10 00:11:55Z correia $

#import <GraphSketcherModel/RSGraphElement.h>

NSString *nameFromConnectMethod(RSConnectType connect);
RSConnectType connectMethodFromName(NSString *name);
RSConnectType defaultConnectMethod(void);

@class RSVertex;

// NOW AN ABSTRACT SUPERCLASS


@interface RSLine : RSGraphElement
{
    RSVertex *_v1;
    RSVertex *_v2;
    
    OQColor *_color;
    CGFloat _width;
    NSInteger _dash;  // line dash style
    
    RSTextLabel *_label;
    CGFloat _slide;	// position of the label along the line (a fraction between 0 and 1).
    CGFloat _labelDistance;  // in pixels
    
    RSGroup *_group;
    
    BOOL _hasChanged;  // so that vertices can un-snap themselves
    
    
    // BACKWARDS-COMPATIBILITY
    CGFloat _cpa;  // curve point angle
    CGFloat _cpd;  // curve point distance w.r.t. line length
}


// designated initializer:
- (id)initWithGraph:(RSGraph *)graph identifier:(NSString *)identifier color:(OQColor *)color width:(CGFloat)width dash:(NSInteger)dash slide:(CGFloat)slide labelDistance:(CGFloat)labelDistance;


// Public API:

// Subclasses
+ (BOOL)supportsConnectMethod:(RSConnectType)connectMethod;
- (BOOL)supportsConnectMethod:(RSConnectType)connectMethod;


// Vertex-related methods
- (BOOL)isCurved;
- (BOOL)isEmpty;
- (BOOL)isTooSmall;
- (BOOL)hasNoLength;
- (BOOL)isVertex;
- (BOOL)isVertical;
- (BOOL)isHorizontal;

- (RSDataPoint)startPoint;
- (RSDataPoint)endPoint;
- (RSVertex *)otherVertex:(RSVertex *)aVertex;  // returns point of the other vertex
- (RSVertex *)startVertex;
- (RSVertex *)endVertex;
- (RSGroup *)vertices;  // by default, contains the start and end vertices
- (NSArray *)children;  // defined as "every object that should have this line as a parent"
- (NSUInteger)vertexCount;
- (BOOL)containsVertex:(RSVertex *)V;
- (BOOL)containsVertices:(NSArray *)A;
- (void)setStartVertex:(RSVertex *)v;
- (void)setEndVertex:(RSVertex *)v;
- (void)replaceVertex:(RSVertex *)oldV with:(RSVertex *)newV;

- (BOOL)insertVertex:(RSVertex *)V atIndex:(NSUInteger)index;
- (BOOL)dropVertex:(RSVertex *)V;

- (RSGraphElement *)groupWithVertices;


// Label positioning
- (CGFloat)slide;
- (void)setSlide:(CGFloat)value;  // A value between 0 and 1


// helps out [RSVertex paramOfSnappedToElement]
- (id)paramForElement:(RSGraphElement *)GE;


// Change-tracking
- (void)setNeedsRecompute;
- (BOOL)hasChanged;
- (void)setHasChanged:(BOOL)flag;


// Describing the object
- (NSString *)equationString;
- (NSString *)infoString;
- (NSString *)stringRepresentation;

@end
