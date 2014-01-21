// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/Model/RSGroup.h 200244 2013-12-10 00:11:55Z correia $

// An RSGroup is a collection of RSGraphElements — basically just an NSMutableArray with some extra features. The most useful feature is that RSGroup is a subclass of RSGraphElement, and handles the work of summarizing multiple object attributes into a single attribute (like -position, -color, -width).  In other Omni apps this work is normally done in the inspectors.  RSGroups are also used for the "group" operation on a graph.  It may be that RSGroups are really the wrong way of accomplishing what they do (at least in the context of the Omni frameworks), but they're fairly deeply embedded in GraphSketcher's source.

// If an RSGroup is added to an RSGroup, all of the elements of the incoming group are added to the receiver and the incoming RSGroup object itself is released.

#import <GraphSketcherModel/RSGraphElement.h>
#import <GraphSketcherModel/RSFontAttributes.h>

@class RSTextLabel;

@interface RSGroup : RSGraphElement <RSFontAttributes>
{
    NSMutableArray *_elements;
}

// Convenience creator
+ (RSGroup *)groupWithGraph:(RSGraph *)graph;
- (id)initWithGraph:(RSGraph *)graph;
- (id)initWithGraph:(RSGraph *)graph byCopyingArray:(NSArray *)array;
// Designated initializer:
- (id)initWithGraph:(RSGraph *)graph identifier:(NSString *)identifier elements:(NSMutableArray *)array;


// Manage the RSGroup
- (BOOL)addElement:(RSGraphElement *)e;
- (BOOL)addElement:(RSGraphElement *)e after:(RSGraphElement *)e2;
- (BOOL)addElement:(RSGraphElement *)e atIndex:(NSUInteger)index;
- (BOOL)removeElement:(RSGraphElement *)e;
- (BOOL)containsElement:(RSGraphElement *)e;
- (BOOL)replaceElement:(RSGraphElement *)old with:(RSGraphElement *)new;
- (RSGraphElement *)nextElement:(RSGraphElement *)e;
- (RSGraphElement *)prevElement:(RSGraphElement *)e;
- (void)swapElement:(NSInteger)first with:(NSInteger)second;
- (void)sortElementsUsingSelector:(SEL)comparator;
- (NSUInteger)count;
- (BOOL)isEmpty;
- (NSArray *)elements;
- (NSMutableArray *)elementsWithClass:(Class)c;
- (RSGraphElement *)firstElementWithClass:(Class)c;
- (RSGraphElement *)lastElementWithClass:(Class)c;
- (RSGroup *)groupWithClass:(Class)c;
- (NSUInteger)numberOfElementsWithClass:(Class)c;
- (NSArray *)elementsMovable;   // returns an array of all moveable elements
- (NSArray *)elementsLabelled;  // returns an array of all elements that have an attached label
- (RSGraphElement *)firstElement;  // returns the first element in the array
- (RSGraphElement *)lastElement;  // returns the last element in the array
- (RSGroup *)elementsBetween:(RSGraphElement *)e1 and:(RSGraphElement *)e2;
- (RSGraphElement *)shake;


// Describing
- (NSString *)stringRepresentation;

@end
