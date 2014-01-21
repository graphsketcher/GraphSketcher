// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/Model/RSFill.m 200244 2013-12-10 00:11:55Z correia $

#import <GraphSketcherModel/RSFill.h>

#import <GraphSketcherModel/RSGroup.h>
#import <GraphSketcherModel/RSVertex.h>
#import <GraphSketcherModel/RSLine.h>
#import <GraphSketcherModel/RSGraph.h>
#import <GraphSketcherModel/RSUndoer.h>
#import <GraphSketcherModel/RSNumber.h>
#import <GraphSketcherModel/RSTextLabel.h>
#import <GraphSketcherModel/NSArray-RSExtensions.h>
#import <OmniQuartz/OQColor.h>

#if !defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE
#import <OmniAppKit/NSUserDefaults-OAExtensions.h>
#endif

@implementation RSFill

//////////////////////////////////////////////////
#pragma mark -
#pragma mark init/dealloc
///////////////////////////////////////////////////
+ (void)initialize
{
    OBINITIALIZE;
    [self setVersion:3];
}

- (id)copyWithZone:(NSZone *)zone
// does not support zone
{
    RSFill *copy;
    copy = [[RSFill alloc] initWithGraph:_graph identifier:nil
			     vertexGroup:[[_vertices copy] autorelease]
				   color:[[_color copy] autorelease]
			       placement:_labelPlacement];
    return copy;
}

- (id)init {
    OBRejectInvalidCall(self, _cmd, @"Use initWithGraph:");
    return nil;
}
- (id)initWithGraph:(RSGraph *)graph;
// initializes an EMPTY fill with DEFAULT attributes
{
    RSGroup *vertices;
    
    vertices = [[[RSGroup alloc] initWithGraph:graph] autorelease];  // default empty grouping
    
    // init:
    Log3(@"default empty RSFill initialized");
    return [self initWithGraph:graph vertexGroup:vertices];
}

- (id)initWithGraph:(RSGraph *)graph vertexGroup:(RSGroup *)vertices;
{
    CGPoint placement = CGPointMake(0.5f, 0.5f);
    
    // use defaults:
    OQColor *color = [OQColor colorForPreferenceKey:@"DefaultFillColor"];
    
    return [self initWithGraph:graph identifier:nil vertexGroup:vertices color:color placement:placement];
}

// DESIGNATED INITIALIZER
- (id)initWithGraph:(RSGraph *)graph identifier:(NSString *)identifier
	vertexGroup:(RSGroup *)vertices
	      color:(OQColor *)color
	  placement:(CGPoint)placement;
{
    if (!(self = [super initWithGraph:graph identifier:identifier]))
	return nil;
    
    // set up vertices:
    _vertices = [vertices retain];
    [_vertices addParent:self];
    
    // sort the vertices so they make a polygon:
    //maybe//[self polygonize];
    
    // set up the rest:
    _color = [color retain];
    
    _label = nil;
    _labelPlacement = placement;
    
    _group = nil;
    
    return self;
}

- (void)invalidate;
{
    for (RSVertex *V in [[_vertices elements] reverseObjectEnumerator]) {
	if ([[V parents] containsObjectIdenticalTo:self]) {
	    [V removeParent:self];
	}
	[_vertices removeElement:V];
    }
    
    [_vertices invalidate];
    [_vertices release];
    _vertices = nil;
    
    [_color release];
    _color = nil;
    
    [_label release];
    _label = nil;
    
    [super invalidate];
}

- (void)dealloc
{
    [self invalidate];
    
    [super dealloc];
}

// Return a new fill with the specified graph element included
- (RSFill *)fillWithElement:(RSGraphElement *)GE {
    if( !GE )  return self;
    // else, continue...
    
    RSFill *newFill = [self copy];
    
    if( [GE isKindOfClass:[RSVertex class]] ) {
	// only add it if there does not already exist a fill vertex in the same position
	if( ! [self vertexHasDuplicate:(RSVertex *)GE] ) {
	    [newFill addVertexAtEnd:(RSVertex *)GE];
	}
    }
    else if( [GE isKindOfClass:[RSLine class]] ) {
	[newFill addVerticesAtEnd:[(RSLine *)GE vertices]];
    }
    else if( [GE isKindOfClass:[RSGroup class]] ) {
	// add all vertices in the RSGroup
	for (RSGraphElement *nextGE in [(RSGroup *)GE elements]) {
	    if( [nextGE isKindOfClass:[RSVertex class]] ) {
		[newFill addVertexAtEnd:(RSVertex *)nextGE];
	    }
	}
    }
    
    return [newFill autorelease];  // receiving object should retain the new fill if necessary
}

- (void)acceptLatestDefaults;
{
    [self setColor:[OQColor colorForPreferenceKey:@"DefaultFillColor"]];
}


/////////////////////////////////////////
#pragma mark -
#pragma mark RSGraphElement subclass
/////////////////////////////////////////

- (OQColor *)color {
    return _color;
}
- (void)setColor:(OQColor *)color;
{
    if ([color isEqual:_color])
        return;
    
    if ([[_graph undoer] firstUndoWithObject:self key:@"setColor"]) {
	[(typeof(self))[[_graph undoManager] prepareWithInvocationTarget:self] setColor:_color];
        [[_graph undoer] setActionName:NSLocalizedStringFromTableInBundle(@"Change Color", @"GraphSketcherModel-UndoActions", OMNI_BUNDLE, @"Undo action name")];
    }
    
    [_color autorelease];
    _color = [color retain];
    
    [_graph.delegate modelChangeRequires:RSUpdateDraw];
}

- (CGFloat)width {
    //NSLog(@"WARNING: \"width\" Not implemented for class: %@", [self class]);
    return 0;
}
- (void)setWidth:(CGFloat)width {
    //NSLog(@"WARNING: \"setWidth\" Not implemented for current RSGraphElement class");
}

- (RSTextLabel *)label {
    return _label;
}
- (void)setLabel:(RSTextLabel *)label {
    // DO NOT CALL THIS METHOD DIRECTLY!  CALL RSTextLabel's setOwner: INSTEAD!
    [_label autorelease];
    _label = [label retain];
    
    if ( !_label ) {	// label was detached
	// restore placement values to default
	[self setLabelPlacement:CGPointMake(0.5f, 0.5f)];
    }
}
- (NSString *)text {
    if (_label) return [_label text];
    else return @"";
}
- (void)setText:(NSString *)text {
    [_label setText:text];
}


- (BOOL)isMovable {
    return NO;
}
- (RSDataPoint)position {
    return [_vertices position];
}
- (RSDataPoint)positionUR {
    return [_vertices positionUR];
}
- (void)setPosition:(RSDataPoint)p {
    [_vertices setPosition:p];
}
- (void)setPositionx:(data_p)val {
    [_vertices setPositionx:val];
}
- (void)setPositiony:(data_p)val {
    [_vertices setPositiony:val];
}


- (NSInteger)shape {
    return 0;  // "no shape"
}
- (void)setShape:(NSInteger)style {
    // do nothing
}

- (RSGroup *)group {
    return _group;
}
- (void)setGroup:(RSGroup *)newGroup {
    _group = newGroup;
}

- (BOOL)locked {
    return [_vertices locked];
}
- (void)setLocked:(BOOL)val {
    [_vertices setLocked:val];
}

- (RSGraphElement *)groupWithVertices {
    RSGroup *group = [[RSGroup alloc] initWithGraph:_graph byCopyingArray:[_vertices elements]];
    [group addElement:self];
    return [group autorelease];
}

- (NSArray *)connectedElements {
    NSMutableArray *A = [NSMutableArray arrayWithArray:[_vertices elements]];
    if (_label) [A addObject:_label];
    return A;
}

- (BOOL)canBeDetached;
{
    return [[self vertices] canBeDetached];
}



//////////////////////////////////////
#pragma mark -
#pragma mark RSVertexList protocol
////////////////

- (RSVertex *)nextVertex:(RSVertex *)V;
{
    if ([_vertices count] < 2) {
        return nil;
    }
    
    NSUInteger index = [[_vertices elements] indexOfObjectIdenticalTo:V];
    if (index == NSNotFound) {
        OBASSERT_NOT_REACHED("Vertex was not found in this fill");
        return nil;
    }
    
    if (index >= [_vertices count] - 1) {
        index = 0;  // wraps to beginning
    } else {
        index += 1;
    }
    return [[_vertices elements] objectAtIndex:index];
}

- (RSVertex *)prevVertex:(RSVertex *)V;
{
    if ([_vertices count] < 2) {
        return nil;
    }
    
    NSUInteger index = [[_vertices elements] indexOfObjectIdenticalTo:V];
    if (index == NSNotFound) {
        OBASSERT_NOT_REACHED("Vertex was not found in this fill");
        return nil;
    }
    
    if (index == 0) {
        index = [_vertices count] - 1;  // wraps to end
    } else {
        index -= 1;
    }
    return [[_vertices elements] objectAtIndex:index];
}


////////////////////////////////////////
#pragma mark -
#pragma mark Accessor methods
////////////////////////////////////////

@synthesize labelPlacement = _labelPlacement;

- (void)setLabelPlacement:(CGPoint)newPlacement;
{
    if (CGPointEqualToPoint(_labelPlacement, newPlacement))
        return;
    
    if ([[_graph undoer] firstUndoWithObject:self key:@"setLabelPlacement"]) {
	[[[_graph undoManager] prepareWithInvocationTarget:self] setLabelPlacement:_labelPlacement];
        [[_graph undoer] setActionName:NSLocalizedStringFromTableInBundle(@"Label Position", @"GraphSketcherModel-UndoActions", OMNI_BUNDLE, @"Undo action name")];
    }
    
    _labelPlacement = newPlacement;
    
    [_graph.delegate modelChangeRequires:RSUpdateDraw];
}

- (BOOL)isEmpty
{
    return ([_vertices count] == 0);
}
- (BOOL)isVertex {
    // all vertices are same object
    if( [_vertices count] == 1 )  return YES;
    //else if( [_vertices count] == 2 && [self recentVertexIsDuplicate] )  return YES;
    else  return NO;
}
- (BOOL)isTwoVertices
{
    // all vertices are 2 objects
    if( [_vertices count] == 2 && ![self isVertex] )  return YES;
    //else if( [_vertices count] == 3 && [self recentVertexIsDuplicate] )  return YES;
    else  return NO;
}
- (BOOL)hasAtLeastThreeVertices {
    return ([_vertices count] >= 3);
}

- (RSLine *)_allVerticesAreSnappedToSameLine;
{
    NSArray *commonSnappedTos = [RSVertex elementsTheseVerticesAreSnappedTo:[[self vertices] elements]];
    return [commonSnappedTos firstObjectWithClass:[RSLine class]];
}

- (RSLine *)allVerticesAreSnappedToExactlyOneLine;
{
    NSArray *vertices = [[self vertices] elements];
    RSLine *commonLine = [self _allVerticesAreSnappedToSameLine];
    if (!commonLine || [vertices count] < 2)
        return commonLine;
    
    // If two neighboring vertices are also snapped to another line in common, then the fill should continue along that line too and thus the fill should not be considered to be one line. <bug://bugs/62256>
    for (NSUInteger i = 0; i < [vertices count]; i++) {
        NSUInteger firstIndex = i;
        NSUInteger secondIndex = i + 1;
        if (secondIndex >= [vertices count])
            secondIndex = 0;
        NSArray *pair = [NSArray arrayWithObjects:[vertices objectAtIndex:firstIndex], [vertices objectAtIndex:secondIndex], nil];
        NSArray *pairCommonLines = [[RSVertex elementsTheseVerticesAreSnappedTo:pair] objectsWithClass:[RSLine class]];
        if ([pairCommonLines count] > 1) {  // If found both the original common line and another
            return nil;
        }
    }
    
    return commonLine;
}

- (BOOL)allVerticesHaveSameXOrYCoord;
{
    NSArray *vertexElements = [[self vertices] elements];
    if ([vertexElements count] <= 1) {
        return YES;
    }
    
    RSDataPoint bottomLeft = [_graph dataMinsOfGraphElements:vertexElements];
    RSDataPoint topRight = [_graph dataMaxesOfGraphElements:vertexElements];
    
    if (nearlyEqualDataValues(bottomLeft.x, topRight.x))
        return YES;
    if (nearlyEqualDataValues(bottomLeft.y, topRight.y))
        return YES;
    
    return NO;
}

//- (BOOL)allVerticesAreColinear;
//{
//    
//}

- (BOOL)shouldBeDrawnAsLine;
{
    if ([self allVerticesHaveSameXOrYCoord] && ![self _allVerticesAreSnappedToSameLine])
        return YES;
    
    return [self allVerticesAreSnappedToExactlyOneLine] != nil;
}

// checks if an existing fill vertex is in the same position as checkV
- (BOOL)vertexHasDuplicate:(RSVertex *)checkV;
{
    for (RSVertex *V in [_vertices elements])
    {
	RSDataPoint checkPoint = [checkV position];
	RSDataPoint thisPoint = [V position];
	if (checkPoint.x == thisPoint.x && checkPoint.y == thisPoint.y)
	    return YES;
    }
    // if got this far
    return NO;
}

- (RSGroup *)vertices {
    return _vertices;
}
- (NSArray *)verticesLabelled {
    return [_vertices elementsLabelled];
}
- (RSVertex *)firstVertex {
    return (RSVertex *)[_vertices firstElement];
}


- (BOOL)containsVertex:(RSVertex *)V {
    NSUInteger result = [[_vertices elements] indexOfObjectIdenticalTo:V];
    if ( result == NSNotFound )  return NO;
    else  return YES;
}


/////////////////////////////////////////
#pragma mark -
#pragma mark Action methods
/////////////////////////////////////////
- (BOOL)removeVertex:(RSVertex *)v {
    [v removeParent:self];
    return [_vertices removeElement:v];
    //default behavior?//[self polygonize];
}
- (void)removeAllVertices;
{
    for (RSVertex *V in [[_vertices elements] reverseObjectEnumerator]) {
	if ([[V parents] containsObjectIdenticalTo:self]) {
	    [V removeParent:self];
	} else {
            OBASSERT_NOT_REACHED("Parent array was not up to date.");
        }
	[_vertices removeElement:V];
    }
}
- (BOOL)addVertexAtEnd:(RSVertex *)v {
    // don't bother if the vertex is already included!
    if ( [self containsVertex:v] )  return NO;
    
    // otherwise, simply add it to the end
    [_vertices addElement:v];
    [v addParent:self];
    return YES;
}
- (BOOL)addVertices:(RSGraphElement *)GE atIndex:(NSUInteger)index;
{
    [GE addParent:self];
    return [_vertices addElement:GE atIndex:index];
}

- (BOOL)addVerticesAtEnd:(RSGraphElement *)element {
    if( [element isKindOfClass:[RSVertex class]] ) {
	return [self addVertexAtEnd:(RSVertex *)element];
    }
    else if( [element isKindOfClass:[RSGroup class]] ) {
	BOOL addedNew = NO;
	for (RSGraphElement *GE in [element elements])
	{
	    if( [GE isKindOfClass:[RSVertex class]] ) {
		if( [self addVertexAtEnd:(RSVertex *)GE] )  addedNew = YES;
	    }
	}
	return addedNew;
    }
    else  return NO;
}

- (void)replaceVertex:(RSVertex *)oldV with:(RSVertex *)newV;
{
    if (oldV == newV)
	return;
    if (![_vertices containsElement:oldV]) {
	OBASSERT_NOT_REACHED("Trying to replace a vertex that isn't part of the fill");
	return;
    }
    
    [[[_graph undoManager] prepareWithInvocationTarget:self] replaceVertex:newV with:oldV];
    
    BOOL result = [_vertices replaceElement:oldV with:newV];
    if( !result ) {
	NSLog(@"ERROR: replaceVertex failed");
    }
    
    [oldV removeParent:self];
    [newV addParent:self];
    
    [_graph.delegate modelChangeRequires:RSUpdateConstraints];
}

- (BOOL)pruneFromEndVertex;
{
    NSArray *vertices = [[self vertices] elements];
    
    if ([vertices count] <= 2)
        return NO;
    
    // Don't prune if the first and last vertices are snapped to two lines in common. Don't prune because that middle vertex is providing valuable information about which edges the fill should cling to.
    NSArray *firstLastPair = [NSArray arrayWithObjects:[vertices objectAtIndex:0], [vertices lastObject], nil];
    NSArray *commonLines = [[RSVertex elementsTheseVerticesAreSnappedTo:firstLastPair] objectsWithClass:[RSLine class]];
    if ([commonLines count] > 1) {
        return NO;
    }
    
    RSVertex *pruneV = nil;
    RSVertex *newV = (RSVertex *)[[self vertices] lastElement];
    
    for (RSVertex *V in [[self vertices] elements]) {
        if (V == newV)
            continue;
        
        RSLine *sharedSnappedTo = (RSLine *)[[V snappedToThisAnd:newV] firstElementWithClass:[RSLine class]];
        if (!sharedSnappedTo)
            continue;
        
        CGFloat middleT = [[V paramOfSnappedToElement:sharedSnappedTo] floatValue];
        CGFloat newVT = [[newV paramOfSnappedToElement:sharedSnappedTo] floatValue];
        
        RSVertex *neighbor = [self nextVertex:V];
        if (neighbor == newV)
            neighbor = [self nextVertex:neighbor];
        id neighborParam = [neighbor paramOfSnappedToElement:sharedSnappedTo];
        if (neighborParam) {
            CGFloat neighborT = [neighborParam floatValue];
            if ( (neighborT > middleT && newVT > neighborT) || (neighborT < middleT && newVT < neighborT) ) {
                pruneV = neighbor;
                break;
            }
            else if ( (middleT > neighborT && newVT > middleT) || (middleT < neighborT && newVT < middleT) ) {
                pruneV = V;
                break;
            }
            
        }
    }
    
    if (pruneV) {
        return [self removeVertex:pruneV];
    }
    
    return NO;
}

- (void)clearSnappedTos;
{
    for (RSVertex *V in [_vertices elements]) {
        [V clearSnappedTo];
    }
}


- (void)sortVerticesBySnappedTo:(RSLine *)L;
// Sort vertices by t-value in their snapped-tos.
{
    for (RSVertex *V in [_vertices elements])
    {
        CGFloat t = [[V paramOfSnappedToElement:L] floatValue];
        [V setSortValue:t];
    }
    [_vertices sortElementsUsingSelector:@selector(valueSort:)];
}

- (void)polygonize;
    // Changes the order of vertices so that it forms a polygon with no crossed lines.
{
    RSLine *L = [self allVerticesAreSnappedToExactlyOneLine];
    if (L) {
        [self sortVerticesBySnappedTo:L];
        
        return;
    }
    
    
    RSDataPoint center = [self centerOfGravity];
    //NSLog(@"center: %f, %f", center.x, center.y);
    
    // use degrees from horizontal right as the sort value
    for (RSVertex *V in [_vertices elements])
    {
	RSDataPoint p = [V position];
	//NSLog(@"p: %f, %f", p.x, p.y);
	double angle = atan((p.y - center.y)/(p.x - center.x));
	// order correctly: (exact numbers don't matter, as long as order is right)
	if ( p.x < center.x )  angle += 5;  // 2nd and 3rd quadrants
	else if ( p.y < center.y )  angle += 10;  // 4th quadrant
	// sort:
	[V setSortValue:angle];
    }
    [_vertices sortElementsUsingSelector:@selector(valueSort:)];
    
}



/////////////////////////////////////////////
#pragma mark -
#pragma mark Utility methods
/////////////////////////////////////////////
- (RSDataPoint)centerOfGravity;
{
    RSDataPoint sum = RSDataPointMake(0, 0);
    for (RSVertex *V in [_vertices elements])
    {
	sum.x += [V position].x;
	sum.y += [V position].y;
    }
    sum.x /= [_vertices count];
    sum.y /= [_vertices count];
    return sum;
}


- (NSString *)stringRepresentation {
    return [NSString stringWithFormat:@"Fill with %lu vertices", [_vertices count]];
}

- (NSString *)infoString;
{
    NSString *format = NSLocalizedStringFromTableInBundle(@"Fill with average:  %@", @"GraphSketcherModel", OMNI_BUNDLE, @"Status bar description of a fill");
    RSDataPoint avg = [RSGraph meanOfGroup:[self vertices]];
    return [NSString stringWithFormat:format, [_graph infoStringForPoint:avg]];
}


@end
