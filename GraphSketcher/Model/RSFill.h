// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/Model/RSFill.h 200244 2013-12-10 00:11:55Z correia $

#import <GraphSketcherModel/RSGraphElement.h>
#import <GraphSketcherModel/RSVertexList.h>

@class RSLine;

@interface RSFill : RSGraphElement <RSVertexList>
{
    RSGroup *_vertices;
    OQColor * _color;
    
    RSTextLabel *_label;
    CGPoint _labelPlacement;  // this is not actually a point but an x- and y-percentage
    RSGroup *_group;
}

- (id)initWithGraph:(RSGraph *)graph;

// Initialize an RSFill with a group of vertices
- (id)initWithGraph:(RSGraph *)graph vertexGroup:(RSGroup *)vertices;

// DESIGNATED INITIALIZER
- (id)initWithGraph:(RSGraph *)graph identifier:(NSString *)identifier
	vertexGroup:(RSGroup *)vertices
	      color:(OQColor *)color
	  placement:(CGPoint)placement;

// Return a new fill with GE included
- (RSFill *)fillWithElement:(RSGraphElement *)GE;

- (void)acceptLatestDefaults;

// Accessor methods
@property(nonatomic) CGPoint labelPlacement;

- (BOOL)isEmpty;
- (BOOL)isVertex;
- (BOOL)isTwoVertices;
- (BOOL)hasAtLeastThreeVertices;
- (RSLine *)allVerticesAreSnappedToExactlyOneLine;
- (BOOL)allVerticesHaveSameXOrYCoord;
- (BOOL)shouldBeDrawnAsLine;
- (BOOL)vertexHasDuplicate:(RSVertex *)checkV;  // checks if an existing fill vertex is in the same position as checkV
- (RSGroup *)vertices;
- (NSArray *)verticesLabelled;
- (RSVertex *)firstVertex;

- (BOOL)containsVertex:(RSVertex *)V;


// Action methods
- (BOOL)removeVertex:(RSVertex *)v;
- (void)removeAllVertices;
- (BOOL)addVertexAtEnd:(RSVertex *)v;
- (BOOL)addVertices:(RSGraphElement *)GE atIndex:(NSUInteger)index;
- (BOOL)addVerticesAtEnd:(RSGraphElement *)element;
- (void)replaceVertex:(RSVertex *)oldV with:(RSVertex *)newV;
- (BOOL)pruneFromEndVertex;
- (void)clearSnappedTos;
- (void)polygonize;


// Utility methods
- (RSDataPoint)centerOfGravity;
- (NSString *)stringRepresentation;

@end
