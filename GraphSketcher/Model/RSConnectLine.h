// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <GraphSketcherModel/RSLine.h>

#import <GraphSketcherModel/RSVertexList.h>

#define RS_ORDER_CREATION 0 
#define RS_ORDER_X 1
#define RS_ORDER_Y 2
#define RS_ORDER_CIRCULARLY 3


@interface RSConnectLine : RSLine <RSVertexList>
{
	RSGroup *_vertices;	// a group of vertices
	RSConnectType _connect;
    
	NSInteger _order;  // not used
}

// Initialization
+ (RSConnectLine *)connectLineWithGraph:(RSGraph *)graph vertices:(RSGroup *)data;
- (id)initWithGraph:(RSGraph *)graph;
- (id)initWithGraph:(RSGraph *)graph start:(RSVertex *)V1 end:(RSVertex *)V2;
- (id)initWithGraph:(RSGraph *)graph vertices:(RSGroup *)vertices;
// DESIGNATED INITIALIZER
- (id)initWithGraph:(RSGraph *)graph identifier:(NSString *)identifier vertices:(RSGroup *)vertices color:(OQColor *)color width:(CGFloat)width dash:(CGFloat)dash slide:(CGFloat)slide labelDistance:(CGFloat)labelDistance;

- (RSConnectLine *)lineWithElement:(RSGraphElement *)GE;
- (void)acceptLatestDefaults;


// Public API:
- (BOOL)isStraight;

- (RSConnectType)connectMethod;
- (void)setConnectMethod:(RSConnectType)val;
- (NSInteger)order;
- (void)setOrder:(NSInteger)val;

+ (RSConnectLine *)vertexIsInterior:(RSVertex *)V;
- (BOOL)dropVertex:(RSVertex *)V registeringUndo:(BOOL)undo;
- (void)removeAllVertices;
- (BOOL)addVertexAtEnd:(RSVertex *)V;
- (BOOL)addVerticesAtEnd:(RSGraphElement *)element;
- (BOOL)addVertices:(RSGraphElement *)GE atIndex:(NSUInteger)index;
- (void)clearSnappedTos;

- (BOOL)vertexHasDuplicate:(RSVertex *)checkV;
- (BOOL)vertexIsInterior:(RSVertex *)V;

@end
