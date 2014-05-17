// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <GraphSketcherModel/RSConnectLine.h>

#import <GraphSketcherModel/RSGroup.h>
#import <GraphSketcherModel/RSVertex.h>
#import <GraphSketcherModel/RSNumber.h>
#import <GraphSketcherModel/RSGraph.h>
#import <GraphSketcherModel/RSUndoer.h>
#import <OmniQuartz/OQColor.h>

#import <OmniFoundation/OFPreference.h>
#if !defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE
#import <OmniAppKit/NSUserDefaults-OAExtensions.h>
#endif

@implementation RSConnectLine


//////////////////////////////////////
#pragma mark -
#pragma mark init/dealloc
////////////////

- (id)copyWithZone:(NSZone *)zone
// does not support zone
{
    RSConnectLine *copy = [[RSConnectLine alloc] initWithGraph:_graph identifier:nil vertices:[[_vertices copy] autorelease] color:[[_color copy] autorelease] width:_width dash:_dash slide:_slide labelDistance:_labelDistance];
    
    return copy;
}


+ (RSConnectLine *)connectLineWithGraph:(RSGraph *)graph vertices:(RSGroup *)vertices;
{
    return [[[RSConnectLine alloc] initWithGraph:graph vertices:vertices] autorelease];
}

- (id)init {
    OBRejectInvalidCall([self class], _cmd, @"Use initWithGraph:");
    return nil;
}
- (id)initWithGraph:(RSGraph *)graph;
// initializes an EMPTY line with DEFAULT attributes
{
    RSGroup *vertices = [[[RSGroup alloc] initWithGraph:graph] autorelease];  // default empty grouping
    
    return [self initWithGraph:graph vertices:vertices];
}
- (id)initWithGraph:(RSGraph *)graph start:(RSVertex *)V1 end:(RSVertex *)V2;
{
    RSGroup *vertices = [[[RSGroup alloc] initWithGraph:graph] autorelease];
    [vertices addElement:V1];
    [vertices addElement:V2];
    
    return [self initWithGraph:graph vertices:vertices];
}

- (id)initWithGraph:(RSGraph *)graph vertices:(RSGroup *)vertices;
{
    // use defaults
    OQColor *color = [OQColor colorForPreferenceKey:@"DefaultLineColor"];
    CGFloat width = [[OFPreferenceWrapper sharedPreferenceWrapper] floatForKey:@"DefaultLineWidth"];
    NSInteger dash = [[OFPreferenceWrapper sharedPreferenceWrapper] integerForKey:@"DefaultDashStyle"];
    CGFloat slide = 0.5f;
    CGFloat labelDistance = 2.0f;
    
    return [self initWithGraph:graph identifier:nil vertices:vertices color:color width:width dash:dash slide:slide labelDistance:labelDistance];
}


// DESIGNATED INITIALIZER
- (id)initWithGraph:(RSGraph *)graph identifier:(NSString *)identifier vertices:(RSGroup *)vertices color:(OQColor *)color width:(CGFloat)width dash:(CGFloat)dash slide:(CGFloat)slide labelDistance:(CGFloat)labelDistance;
{
    if (!(self = [super initWithGraph:graph identifier:identifier color:color width:width dash:dash slide:slide labelDistance:labelDistance]))
	return nil;
    
    _connect = connectMethodFromName([[OFPreferenceWrapper sharedPreferenceWrapper] stringForKey:@"DefaultConnectMethod"]);
    _order = RS_ORDER_CREATION;
    
    OBASSERT([vertices count] == [[vertices elementsWithClass:[RSVertex class]] count]);
    _vertices = [vertices retain];
    [_vertices addParent:self];
    
    _label = nil;
    _group = nil;
    _hasChanged = NO;
    
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
    
    [super invalidate];
}

- (void)dealloc;
{
    [self invalidate];
    
    [super dealloc];
}



// Return a new line with the specified graph element included
- (RSConnectLine *)lineWithElement:(RSGraphElement *)GE {
    if( GE == nil )
	return self;
    
    // Ignore the extra element if it is in the same position as the last vertex
    if ( nearlyEqualDataPoints([GE position], [[_vertices lastElement] position]) )
	return self;
    
    
    if( [GE isKindOfClass:[RSVertex class]] ) {
	
	RSConnectLine *newLine = [self copy];
	
	if( ! [newLine addVertexAtEnd:(RSVertex *)GE] && GE != [_vertices lastElement] ) {
	    // if add failed, it already exists, so create a duplicate instead
	    [newLine addVertexAtEnd:[[(RSVertex *)GE parentlessCopy] autorelease]];
	}
	// only add it if there does not already exist a vertex in the same position
	//if( ! [self vertexHasDuplicate:(RSVertex *)GE] ) {
	//   [newLine addVertexAtEnd:(RSVertex *)GE];
	//}
	
	return [newLine autorelease];  // receiving object should retain the new line if necessary
    }
    else {
	return self;
    }
    
}


- (void)acceptLatestDefaults {
    [self setColor:[OQColor colorForPreferenceKey:@"DefaultLineColor"]];
    [self setWidth:[[OFPreferenceWrapper sharedPreferenceWrapper] floatForKey:@"DefaultLineWidth"]];
    [self setDash:[[OFPreferenceWrapper sharedPreferenceWrapper] integerForKey:@"DefaultDashStyle"]];
    [self setConnectMethod:connectMethodFromName([[OFPreferenceWrapper sharedPreferenceWrapper] stringForKey:@"DefaultConnectMethod"])];
}


//////////////////////////////////////
#pragma mark -
#pragma mark RSGraphElement subclass
////////////////
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

- (RSGraphElement *)groupWithVertices {
    RSGroup *group = [RSGroup groupWithGraph:_graph];
    [group addElement:self];
    [group addElement:_vertices];
    return group;
}


- (NSArray *)connectedElements {
    NSMutableArray *A = [NSMutableArray arrayWithArray:[_vertices elements]];
    if (_label) {
	[A addObject:_label];
    }
    return A;
}

- (NSArray *)elementsBetweenElement:(RSGraphElement *)e1 andElement:(RSGraphElement *)e2;
// If both elements are in this line, return any vertices lying between them.
{
    NSArray *vArray = [_vertices elements];
    NSUInteger index1 = [vArray indexOfObject:e1];
    NSUInteger index2 = [vArray indexOfObject:e2];
    
    if (index1 == NSNotFound || index2 == NSNotFound)
	return nil;
    
    // Ensure index1 <= index2
    if (index1 > index2) {
	// swap
	NSUInteger temp = index1;
	index1 = index2;
	index2 = temp;
    }
    OBASSERT(index1 <= index2);
    if (index2 - index1 <= 1)  // nothing in-between
	return nil;
    
    // If got this far, there is at least one element between index1 and index2.
    NSMutableArray *result = [NSMutableArray array];
    for (NSUInteger i = index1 + 1; i < index2; i++ ) {
	[result addObject:[vArray objectAtIndex:i]];
    }
    return result;
}

// helps out [RSVertex paramOfSnappedToElement]
- (id)paramForElement:(RSGraphElement *)GE {
    NSInteger index = [[_vertices elements] indexOfObjectIdenticalTo:GE];
    if( index == NSNotFound )
	return nil;

    CGFloat n = [_vertices count] - 1;
    CGFloat t = ((CGFloat)index)/n;
    return [NSNumber numberWithDouble:t];
}


//////////////////////////////////////
#pragma mark -
#pragma mark RSLine subclass
////////////////
+ (BOOL)supportsConnectMethod:(RSConnectType)connectMethod;
{
    if (connectMethod == RSConnectStraight || connectMethod == RSConnectCurved)
	return YES;
    
    return NO;
}
- (NSInteger)shape {
    return [[self vertices] shape];
}
- (void)setShape:(NSInteger)style {
    [[self vertices] setShape:style];
}

- (BOOL)isEmpty {
    return [_vertices isEmpty];
}
- (BOOL)isTooSmall {
    return [_vertices count] < 2;
}
- (BOOL)isVertex {
    return [_vertices count] == 1;
}

- (BOOL)isCurved {
    if( [_vertices count] > 2 )  return YES;
    else  return NO;
}
- (BOOL)isStraight {
    if( [_vertices count] == 2 )  return YES;
    else  return NO;
}

- (RSGroup *)vertices {
    return _vertices;
}
- (NSUInteger)vertexCount;
{
    return [_vertices count];
}

- (RSVertex *)startVertex {
    return (RSVertex *)[_vertices firstElement];
}
- (RSVertex *)endVertex {
    return (RSVertex *)[_vertices lastElement];
}
- (RSVertex *)otherVertex:(RSVertex *)aVertex {
    if ( ![self isStraight] ) {
        return nil;
    }
    
    if ( aVertex == [self startVertex] )
        return [self endVertex];
    else if ( aVertex == [self endVertex] )
        return [self startVertex];
    
    return nil;
}
- (BOOL)containsVertex:(RSVertex *)V {
    return [_vertices containsElement:V];
}

- (void)replaceVertex:(RSVertex *)oldV with:(RSVertex *)newV;
{
    if (oldV == newV)
	return;
    if (![_vertices containsElement:oldV])
	return;
    
    [[[_graph undoManager] prepareWithInvocationTarget:self] replaceVertex:newV with:oldV];
	
    BOOL result = [_vertices replaceElement:oldV with:newV];
    if( !result ) {
	NSLog(@"ERROR: replaceVertex failed");
    }
    
    [oldV removeParent:self];
    [newV addParent:self];
    
    [_graph.delegate modelChangeRequires:RSUpdateConstraints];
}

- (BOOL)insertVertex:(RSVertex *)V atIndex:(NSUInteger)index;
{
    if ([_vertices containsElement:V])
        return NO;
    
    [[[_graph undoManager] prepareWithInvocationTarget:self] dropVertex:V];
    
    [V addParent:self];
    [_vertices addElement:V atIndex:index];
    
    [_graph.delegate modelChangeRequires:RSUpdateConstraints];
    return YES;
}

- (BOOL)dropVertex:(RSVertex *)V;
{
    return [self dropVertex:V registeringUndo:YES];
}



//////////////////////////////////////
#pragma mark -
#pragma mark RSVertexList protocol
////////////////

- (RSVertex *)nextVertex:(RSVertex *)V;
{
    NSUInteger index = [[_vertices elements] indexOfObjectIdenticalTo:V];
    if (index == NSNotFound) {
        OBASSERT_NOT_REACHED("Vertex was not found in this line");
        return nil;
    }
    
    if (index >= [_vertices count] - 1) {
        return nil;  // there is no next vertex
    }
    
    return [[_vertices elements] objectAtIndex:index + 1];
}

- (RSVertex *)prevVertex:(RSVertex *)V;
{
    NSUInteger index = [[_vertices elements] indexOfObjectIdenticalTo:V];
    if (index == NSNotFound) {
        OBASSERT_NOT_REACHED("Vertex was not found in this line");
        return nil;
    }
    
    if (index == 0) {
        return nil;  // there is no previous vertex
    }
    
    return [[_vertices elements] objectAtIndex:index - 1];
}



//////////////////////////////////////
#pragma mark -
#pragma mark Public API
////////////////

- (RSConnectType)connectMethod {
    return _connect;
}
- (void)setConnectMethod:(RSConnectType)val{
    if( _connect == val )
	return;
    
    NSUndoManager *undoManager = [_graph undoManager];
    [[undoManager prepareWithInvocationTarget:self] setConnectMethod:_connect];
    
    if (![undoManager isUndoing]) {
	[[_graph undoer] setActionName:NSLocalizedStringFromTableInBundle(@"Change Line Segment Type", @"GraphSketcherModel-UndoActions", OMNI_BUNDLE, @"Undo action name")];
    }
    
    _connect = val;
    
    [self setHasChanged:YES];
    [_graph.delegate modelChangeRequires:RSUpdateConstraints];
}
- (NSInteger)order {
    return _order;
}
- (void)setOrder:(NSInteger)val {
    _order = val;
}


// finds out if vertex V is an interior vertex (not end vertex) of any of its parents
+ (RSConnectLine *)vertexIsInterior:(RSVertex *)V {
    for (RSGraphElement *GE in [V parents]) {
	if( [GE isKindOfClass:[RSConnectLine class]] ) {
	    if( [(RSConnectLine *)GE vertexIsInterior:V] ) {
		return (RSConnectLine *)GE;
	    }
	}
    }
    // if got this far
    return nil;
}

- (BOOL)dropVertex:(RSVertex *)V registeringUndo:(BOOL)undo;
{
    NSUInteger index = [[_vertices elements] indexOfObjectIdenticalTo:V];
    if (index == NSNotFound) {
        OBASSERT_NOT_REACHED("Vertex could not be removed from this line because the vertex was not found");
        return NO;
    }
    
    if (![_vertices containsElement:V]) {
        return NO;
    }
    
    if (undo) {
        [[[_graph undoManager] prepareWithInvocationTarget:self] insertVertex:V atIndex:index];
    }
    
    [V removeParent:self];
    
    [_vertices removeElement:V];
    
    [_graph.delegate modelChangeRequires:RSUpdateConstraints];
    return YES;
}
- (void)removeAllVertices;
{
    for (RSVertex *V in [[_vertices elements] reverseObjectEnumerator]) {
	[V removeParent:self];
	[_vertices removeElement:V];
    }
}

- (BOOL)addVertexAtEnd:(RSVertex *)V;
{
    [V addParent:self];
    return [_vertices addElement:V];
}
- (BOOL)addVerticesAtEnd:(RSGraphElement *)element;
{
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
- (BOOL)addVertices:(RSGraphElement *)GE atIndex:(NSUInteger)index;
{
    [GE addParent:self];
    return [_vertices addElement:GE atIndex:index];
}

- (void)clearSnappedTos;
{
    for (RSVertex *V in [_vertices elements]) {
        [V clearSnappedTo];
    }
}

// checks if an existing child vertex is in the same position as checkV
- (BOOL)vertexHasDuplicate:(RSVertex *)checkV {
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
- (BOOL)vertexIsInterior:(RSVertex *)V {
    NSUInteger index = [[_vertices elements] indexOfObjectIdenticalTo:V];
    if( index == NSNotFound )  return NO;
    else {
	if( index > 0 && index < ([_vertices count] - 1) ) {
	    return YES;
	}
	else  return NO;
    }
}



/////////////////////////////////////////
#pragma mark -
#pragma mark Describing the object
/////////////////////////////////////////

- (NSString *)equationString;
{
    if ( [self isCurved] ) {
	return @"(complex)";
    }
    
    return [super equationString];
    
}
- (NSString *)infoString {
    if( [self isStraight] )
	return [super infoString];
    else
	return nil;//@"Curved line";
}
- (NSString *)stringRepresentation {
    NSMutableString *str = [NSMutableString stringWithString:@"Line through:"];

    for (RSVertex *V in [_vertices elements]) {
	[str appendFormat:@" (%f,%f)", [V position].x, [V position].y];
    }
    return str;
}


#pragma mark -
#pragma mark Debugging

#ifdef DEBUG

- (NSString *)shortDescription;
{
    NSMutableString *str = [NSMutableString stringWithString:@"RSConnectLine through points:"];
    for (RSVertex *V in [_vertices elements]) {
	[str appendFormat:@" (%f,%f)", [V position].x, [V position].y];
    }
    return str;
}

- (NSMutableDictionary *)debugDictionary;
{
    NSMutableDictionary *dict = [super debugDictionary];
    [dict setObject:[self shortDescription] forKey:@"shortDescription"];
    return dict;
}

#endif

@end
