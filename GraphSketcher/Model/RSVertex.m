// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <GraphSketcherModel/RSVertex.h>

#import <GraphSketcherModel/RSUnknown.h>
#import <GraphSketcherModel/RSLine.h>
#import <GraphSketcherModel/RSGraph.h>
#import <GraphSketcherModel/RSUndoer.h>
#import <GraphSketcherModel/RSFill.h>
#import <GraphSketcherModel/RSGroup.h>
#import <GraphSketcherModel/RSNumber.h>
#import <GraphSketcherModel/RSTextLabel.h>
#import <OmniQuartz/OQColor.h>
#import <GraphSketcherModel/NSArray-RSExtensions.h>

#import <OmniFoundation/OFPreference.h>
#import <OmniFoundation/CFArray-OFExtensions.h>
#if !defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE
#import <OmniAppKit/NSUserDefaults-OAExtensions.h>
#endif

@interface RSVertex (PrivateAPI)
- (BOOL)shallowRemoveSnappedTo:(RSGraphElement *)GE;
- (BOOL)shallowAddSnappedTo:(RSGraphElement *)GE withParam:(id)param;
@end


@implementation RSVertex

//////////////////////////////////////////////////
#pragma mark -
#pragma mark init/dealloc
///////////////////////////////////////////////////
+ (void)initialize
{
    OBINITIALIZE;
    [self setVersion:8];
}


- (id)copyWithZone:(NSZone *)zone
// copies parent references as well as graphic properties
// does not support zone
{
    RSVertex *copy;
    copy = [[RSVertex alloc] initWithGraph:_graph identifier:nil point:_p width:_width color:[[_color copy] autorelease] shape:_shape];
    
    for (id obj in [self parents]) {
	[copy addParent:obj];
    }
    
    return copy;
}
- (id)parentlessCopy;
// does not support zone
{
    RSVertex *copy;
    copy = [[RSVertex alloc] initWithGraph:_graph identifier:nil point:_p width:_width color:[[_color copy] autorelease] shape:_shape];
    return copy;
}

- (id)init;
{
    OBRejectInvalidCall(self, _cmd, @"Use initWithGraph:");
    return nil;
}

- (id)initWithGraph:(RSGraph *)graph;
// initializes a vertex with coordinates (0,0)
{
    RSDataPoint p = RSDataPointMake(0, 0);
    int shape = 0;
    
    // use defaults:
    OQColor *color = [OQColor colorForPreferenceKey:@"DefaultLineColor"];
    CGFloat width = [[OFPreferenceWrapper sharedPreferenceWrapper] floatForKey:@"DefaultLineWidth"];
    
    return [self initWithGraph:graph identifier:nil point:p width:width color:color shape:shape];
}

// DESIGNATED INITIALIZER
- (id)initWithGraph:(RSGraph *)graph identifier:(NSString *)identifier point:(RSDataPoint)p width:(CGFloat)width color:(OQColor *)color shape:(NSInteger)shape;
{
    if (!(self = [super initWithGraph:graph identifier:identifier]))
	return nil;
    
    _p = p;
    _width = width;
    _color = [color retain];
    _shape = shape;
    _arrowParent = nil;
    
    _parents = (NSMutableArray *)OFCreateNonOwnedPointerArray();  // Creates an NSMutableArray that doesn't retain its members.
    
    _label = nil;
    _labelPosition = 0;
    _labelDistance = 5;
    _sortValue = 0;
    
    _group = nil;
    _locked = NO;
    _snappedTo = nil;
    _snappedToParams = nil;
    
    Log2(@"RSVertex initialized.");
    
    return self;
}

- (void)invalidate;
{
    // These can contain pointers to other graphics and possibly cycle back to us
    [_snappedTo invalidate];
    [_snappedTo release];
    _snappedTo = nil;
    
    [_snappedToParams release];
    _snappedToParams = nil;
    
    [_parents release];
    _parents = nil;
    
    [_label release];
    _label = nil;
    
    [_color release];
    _color = nil;
    
    [super invalidate];
}

- (void)dealloc
{
    [self invalidate];
    
    [super dealloc];
}


- (void)acceptLatestDefaults;
{
    [self setColor:[OQColor colorForPreferenceKey:@"DefaultLineColor"]];
    [self setWidth:[[OFPreferenceWrapper sharedPreferenceWrapper] floatForKey:@"DefaultLineWidth"]];
}



////////////////////////////////////////
#pragma mark -
#pragma mark RSGraphElement subclass
////////////////////////////////////////

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

- (BOOL)hasColor;
{
    return ([self shape] != RS_NONE);
}
- (CGFloat)width {
    return _width;
}
- (void)setWidth:(CGFloat)width;
{
    if (_width == width)
        return;
    
    if ([[_graph undoer] firstUndoWithObject:self key:@"setWidth"]) {
	[[[_graph undoManager] prepareWithInvocationTarget:self] setWidth:_width];
        [[_graph undoer] setActionName:NSLocalizedStringFromTableInBundle(@"Change Thickness", @"GraphSketcherModel-UndoActions", OMNI_BUNDLE, @"Undo action name")];
    }
    
    _width = width;
    
    if (_shape == RS_ARROW && [self canHaveArrows]) {
        [_graph.delegate modelChangeRequires:RSUpdateConstraints];  // update the line length to match
    } else {
        [_graph.delegate modelChangeRequires:RSUpdateDraw];
    }
}
- (BOOL)hasWidth;
{
    return ([self shape] != RS_NONE);
}
- (CGSize)size;
{
    CGFloat width = _width;
    if (width == 0) {
        width = 1;
    }
    
    if ([RSGraph vertexHasShape:self]) {
        width *= 4;
    }
    
    return CGSizeMake(width, width);
}
- (CGFloat)widthFromSize:(CGSize)size;
{
    CGFloat width = size.width;
    if (size.height < width) {
        width = size.height;
    }
    
    if ([RSGraph vertexHasShape:self]) {
        width /= 4;
    }
    
    return width;
}
- (void)setSize:(CGSize)newSize;
{
    CGFloat width = [self widthFromSize:newSize];
    [self setWidth:width];
}

@synthesize rotation = _rotation;

- (NSInteger)dash {
    return 0;
}
- (void)setDash:(NSInteger)style {
    // do nothing; dash is meaningless for vertex
}
- (NSInteger)shape {
    return _shape;
}
- (void)setShape:(NSInteger)style;
{
    if (_shape == style)
        return;
    
    if ([[_graph undoer] firstUndoWithObject:self key:@"setShape"]) {
	[[[_graph undoManager] prepareWithInvocationTarget:self] setShape:_shape];
    }
    
    RSModelUpdateRequirement req = RSUpdateDraw;
    if (_shape == RS_ARROW || style == RS_ARROW) {
        req = RSUpdateConstraints;
    }
    
    _shape = style;
    if (style == RS_ARROW && [[self parents] count]) {
	_arrowParent = [self lastParentLine];
    }
    
    [_graph.delegate modelChangeRequires:req];
}
- (BOOL)hasShape;
{
    return YES;
}
- (BOOL)canHaveArrows;
{
    return ([_parents count] > 0);
}

- (BOOL)canBeConnected;
{
    return YES;
}

- (RSDataPoint)position {
    return _p;
}
- (void)setPosition:(RSDataPoint)p;
{
    if (_p.x == p.x && _p.y == p.y)
        return;
    
#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
    if ([[_graph undoer] firstUndoWithObject:self key:@"setPosition"]) {
	[(RSGraphElement *)[[_graph undoManager] prepareWithInvocationTarget:self] setPosition:_p];
    }
#endif
    
    [self setPositionWithoutLoggingUndo:p];
    
    [_graph.delegate modelChangeRequires:RSUpdateConstraints];
}
- (void)setPositionx:(data_p)val;
{
    if( _p.x == val )
        return;
    
#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
    if ([[_graph undoer] firstUndoWithObject:self key:@"setPositionx"]) {
	[[[_graph undoManager] prepareWithInvocationTarget:self] setPositionx:_p.x];
    }
#endif
    
    _p.x = val;
    [self setNeedsRecompute];
    
    [_graph.delegate modelChangeRequires:RSUpdateConstraints];
}
- (void)setPositiony:(data_p)val;
{
    if( _p.y == val )
        return;
    
#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
    if ([[_graph undoer] firstUndoWithObject:self key:@"setPositiony"]) {
	[[[_graph undoManager] prepareWithInvocationTarget:self] setPositiony:_p.y];
    }
#endif
    
    _p.y = val;
    [self setNeedsRecompute];
    
    [_graph.delegate modelChangeRequires:RSUpdateConstraints];
}

- (void)setPositionWithoutLoggingUndo:(RSDataPoint)p;
{
    _p = p;
    [self setNeedsRecompute];
}

// Needed by the data points table view in the inspector
- (data_p)positionx;
{
    return _p.x;
}
- (data_p)positiony;
{
    return _p.y;
}


- (RSTextLabel *)label {
    return _label;
}
- (void)setLabel:(RSTextLabel *)label {
    // DO NOT CALL THIS METHOD DIRECTLY!  INSTEAD CALL RSTextLabel's [setOwner:]
    [_label autorelease];
    _label = [label retain];
    
    //if( [self isBar] ) 	[self setLabelPosition:(CGFloat)M_PI_2];  // above
}
- (NSString *)text {
    if (_label) return [_label text];
    else return @"";
}
- (void)setText:(NSString *)text {
    [_label setText:text];
}
- (CGFloat)labelDistance {
    return _labelDistance;
}
- (void)setLabelDistance:(CGFloat)value;
{
    if (_labelDistance == value)
        return;
    
    if ([[_graph undoer] firstUndoWithObject:self key:@"setLabelDistance"]) {
	[[[_graph undoManager] prepareWithInvocationTarget:self] setLabelDistance:_labelDistance];
        [[_graph undoer] setActionName:NSLocalizedStringFromTableInBundle(@"Adjust Label Distance", @"GraphSketcherModel-UndoActions", OMNI_BUNDLE, @"Undo action name")];
    }
    
    _labelDistance = value;
    
    [_graph.delegate modelChangeRequires:RSUpdateDraw];
}

- (RSGroup *)group {
    return _group;
}
- (void)setGroup:(RSGroup *)newGroup {
    _group = newGroup;
}

- (BOOL)isLockable;
{
    return YES;
}
- (BOOL)locked {
    return _locked;
}
- (void)setLocked:(BOOL)val;
{
    if (_locked == val)
        return;
    
    [[[_graph undoManager] prepareWithInvocationTarget:self] setLocked:_locked];
    
    _locked = val;
}

- (BOOL)isMovable {
    return YES;
}



////////////////////////////////////////
#pragma mark -
#pragma mark Accessor methods
////////////////////////////////////////

- (BOOL)isBar {
    if( _shape == RS_BAR_VERTICAL || _shape == RS_BAR_HORIZONTAL )  return YES;
    else  return NO;
}

- (CGFloat)labelPosition {
    return _labelPosition;
}
- (void)setLabelPosition:(CGFloat)value {
    if (_labelPosition == value)
        return;
    
    if ([[_graph undoer] firstUndoWithObject:self key:@"setLabelPosition"]) {
	[[[_graph undoManager] prepareWithInvocationTarget:self] setLabelPosition:_labelPosition];
        [[_graph undoer] setActionName:NSLocalizedStringFromTableInBundle(@"Label Position", @"GraphSketcherModel-UndoActions", OMNI_BUNDLE, @"Undo action name")];
    }
    
    _labelPosition = value;
    
    [_graph.delegate modelChangeRequires:RSUpdateDraw];
}


////////////////////////////////////////
#pragma mark -
#pragma mark Action methods
////////////////////////////////////////

// to update RSFitLine parents and snappedTo
- (void)setNeedsRecompute {
    
    // update RSFitLine parents
    for (RSGraphElement *GE in _parents)
    {
	//if ( [GE isKindOfClass:[RSFitLine class]] )  
	[GE setNeedsRecompute];
	[GE setHasChanged:YES];
    }
    
    [_graph.delegate modelChangeRequires:RSUpdateConstraints];
}



////////////////////////////////////////
#pragma mark -
#pragma mark Parents-related methods:
////////////////////////////////////////
- (void)addParent:(id)e {
    if (![_parents containsObjectIdenticalTo:e]) {
        //OBASSERT([_parents count] == 0);
        [_parents addObject:e];
        if ([_parents count] == 1 && [self shape] == RS_ARROW && [e isKindOfClass:[RSLine class]]) {
            [self setArrowParent:e];
        }
    }
}
- (void)removeParent:(id)e {
    //OBASSERT([_parents containsObjectIdenticalTo:e]);
    if (_arrowParent == e) {
        [self setArrowParent:nil];
    }
    
    // This caused problems by retaining and then releasing the object. Instead, use the CoreFoundation method, since it's really a CFArray that's non-retaining.
    //[_parents removeObjectIdenticalTo:e];
    
    NSUInteger index = [_parents indexOfObjectIdenticalTo:e];
    CFArrayRemoveValueAtIndex((CFMutableArrayRef)_parents, index);
}
- (BOOL)isParent:(RSGraphElement *)e {
    return [_parents containsObjectIdenticalTo:e];
}
- (NSMutableArray *)parents {
    return _parents;
}
- (NSUInteger)parentCount {
    return [_parents count];
}
- (RSLine *)lastParentLine;
{
    if (![_parents count]) {
        return nil;
    }
    
    for (RSGraphElement *GE in [_parents reverseObjectEnumerator]) {
	if ([GE isKindOfClass:[RSLine class]])
	    return (RSLine *)GE;
    }
    
    return nil;
}
- (RSFill *)lastParentFill;
{
    if (![_parents count]) {
        return nil;
    }
    
    for (RSGraphElement *GE in [_parents reverseObjectEnumerator]) {
	if ([GE isKindOfClass:[RSFill class]])
	    return (RSFill *)GE;
    }
    
    return nil;
}

- (NSArray *)connectedElements;
{
    //NSMutableArray *A = [NSMutableArray arrayWithArray:[self extendedNonVertexSnappedTos]];
    NSMutableArray *A = [NSMutableArray arrayWithArray:[self parentsOfVertexCluster]];
    if (_label) {
	[A addObject:_label];
    }
    return A;
}

@synthesize arrowParent = _arrowParent;

- (RSLine *)effectiveArrowParent;
{
    RSLine *arrowParent = [self arrowParent];
    if (!arrowParent)
        arrowParent = [[self parents] firstObjectWithClass:[RSLine class]];
    
    return arrowParent;
}

- (BOOL)arrowParentIsLine:(RSLine *)L;
{
    return ([self shape] == RS_ARROW && [self arrowParent] == L);
}



////////////////////////////////////////
#pragma mark -
#pragma mark Snapped-To methods
////////////////////////////////////////
// returns the elements it was most recently snapped to, or nil if none
- (RSGroup *)snappedTo {
    return _snappedTo;
}
- (NSMutableArray *)snappedToParams {
    return _snappedToParams;
}

- (void)registerUndoForSnappedTos;
{
    if ([[_graph undoer] firstUndoWithObject:self key:@"setSnappedTos"]) {
	NSUndoManager *undoManager = [_graph undoManager];
	[[undoManager prepareWithInvocationTarget:self] setSnappedToWithInfo:[self snappedToInfo]];
    }
}

- (NSDictionary *)snappedToInfo;
{
    return [NSDictionary dictionaryWithObjectsAndKeys:[[_snappedTo copy] autorelease], @"snappedTo",
	    [[_snappedToParams mutableCopy] autorelease], @"params", nil];
}

- (void)setSnappedToWithInfo:(NSDictionary *)info;
// Uses the containers directly from the info dictionary
{
    [self registerUndoForSnappedTos];
    
    [_snappedTo release];
    _snappedTo = [[info objectForKey:@"snappedTo"] retain];
    [_snappedToParams release];
    _snappedToParams = [[info objectForKey:@"params"] retain];
    
    // Make sure either both containers were found or both were not found:
    OBPOSTCONDITION((!_snappedTo && !_snappedToParams) || (_snappedTo && _snappedToParams));
    
    [_graph.delegate modelChangeRequires:RSUpdateConstraints];
}

- (void)setSnappedTo:(RSGroup *)G withParams:(NSMutableArray *)params;
// Rebuilds the snappedTo containters and vertex cluster info
{
    [self clearSnappedTo];
    
    // Add the group members one by one to build up the vertex cluster
    NSUInteger index = 0;
    for (RSGraphElement *GE in [[[G elements] copy] autorelease]) {
	[self addSnappedTo:GE withParam:[params objectAtIndex:index]];
	index++;
    }
}
// removes all elements previously in snappedTo
- (void)clearSnappedTo {
    if ( !_snappedTo ) {
	return;
    }
    
    [self registerUndoForSnappedTos];
    
    // remove self from the vertex clump
    for (RSVertex *V in [self vertexSnappedTos]) {
	[V shallowRemoveSnappedTo:self];
    }
    
    [_snappedTo invalidate];
    [_snappedTo release];
    _snappedTo = nil;
    [_snappedToParams release];
    _snappedToParams = nil;
}

- (void)clearExtendedSnapTos;
// Removes all snappedTos in every vertex in the current cluster
{
    for (RSVertex *V in [self vertexCluster]) {
	[V clearSnappedTo];
    }
}

- (void)removeConstraints;
// Clears only the non-vertex snappedTos.
{
    if (!_snappedTo)
	return;
    OBASSERT(_snappedToParams);  // if _snappedTo exists, so should _snappedToParams
    
    for (RSGraphElement *GE in [[_snappedTo elements] reverseObjectEnumerator]) {
	if (![GE isKindOfClass:[RSVertex class]]) {
	    [self shallowRemoveSnappedTo:GE];
	}
    }
}
- (void)removeExtendedConstraints;
// Clears non-vertex snappedTos from the entire vertex cluster
{
    if (!_snappedTo)
	return;
    
    [self removeConstraints];
    for (RSVertex *V in [self vertexSnappedTos]) {
	[V removeConstraints];
    }
}

- (void)setVertexCluster:(NSArray *)newCluster;
// Updates snapped-to arrays for all vertices in the existing and new vertex clusters such that vertices no longer in the cluster are removed and notified, and vertices newly in the cluster are added and notified.
{
    NSArray *existing = [self vertexCluster];
    
    // Find out which vertices need to be added and removed from the existing cluster
    NSMutableArray *toRemove = [NSMutableArray array];
    for (RSVertex *V in existing) {
        if (![newCluster containsObject:V]) {
            [toRemove addObject:V];
        }
    }
    NSMutableArray *toAdd = [NSMutableArray array];
    for (RSVertex *V in newCluster) {
        if (![existing containsObject:V]) {
            [toAdd addObject:V];
            
            OBASSERT(![toRemove containsObject:V]);
        }
            
    }
    
    // Remove vertices from the cluster
    for (RSVertex *r in toRemove) {
        for (RSVertex *V in newCluster) {
            if (V == r)
                continue;
            
            [V shallowRemoveSnappedTo:r];
            [r shallowRemoveSnappedTo:V];
        }
    }
    
    // Add vertices to the cluster
    for (RSVertex *a in toAdd) {
        for (RSVertex *V in newCluster) {
            if (V == a)
                continue;
            
            [V shallowAddSnappedTo:a withParam:[NSNumber numberWithInt:0]];
            [a shallowAddSnappedTo:V withParam:[NSNumber numberWithInt:0]];
        }
    }
    
//    // Remove any vertices in the cluster
//    if (_snappedTo) {
//	for (RSVertex *V in [self vertexSnappedTos]) {
//	    [self simpleRemoveSnappedTo:V];
//	    [V simpleRemoveSnappedTo:self];
//	}
//    }
//    
//    // Add the vertices from the new cluster:
//    for (RSVertex *V in vertices) {
//	[self addSnappedTo:V withParam:[NSNumber numberWithInt:0]];
//    }
}

// Maintain own references to the vertex cluster, but clear self from the snappedTo records of all other vertices in the cluster.
- (BOOL)removeFromVertexCluster;
{
    if ( !_snappedTo ) {
	return NO;
    }
    
    for (RSVertex *V in [self vertexSnappedTos]) {
	OBASSERT(V != self);
        [V shallowRemoveSnappedTo:self];
    }
    return YES;
}

- (void)addToVertexCluster;
{
    if (!_snappedTo) {
        return;
    }
    
    for (RSVertex *V in [self vertexSnappedTos]) {
	OBASSERT(V != self);
        [V shallowAddSnappedTo:self withParam:[NSNumber numberWithFloat:0]];
    }
}

// Remove an element that the vertex is no longer snapped to.
// Methods calling this with a vertex GE need to also clean up the other vertices (if any) in the vertex cluster.
- (BOOL)shallowRemoveSnappedTo:(RSGraphElement *)GE;
{
    if (!_snappedTo)
	return NO;
    OBASSERT(_snappedToParams);  // if _snappedTo exists, so should _snappedToParams
    
    if (![_snappedTo containsElement:GE])
	return NO;
    
    [self registerUndoForSnappedTos];

    NSUInteger index = [[_snappedTo elements] indexOfObjectIdenticalTo:GE];
    
    [_snappedTo removeElement:GE];
    [_snappedToParams removeObjectAtIndex:index];
    
    [_graph.delegate modelChangeRequires:RSUpdateConstraints];
    
    return YES;
}

- (void)removeSnappedTo:(RSGraphElement *)GE;
{
    BOOL changed = [self shallowRemoveSnappedTo:GE];
    
    if (!changed)
	return;
    if (![GE isKindOfClass:[RSVertex class]]) {
	return;
    }
    
    // GE is a vertex, so we need to clean up the other vertices (if any) in the vertex cluster
    [(RSVertex *)GE shallowRemoveSnappedTo:self];
    for (RSVertex *V in [self vertexSnappedTos]) {
	OBASSERT(V != self);
	if (V != GE) {
	    [V shallowRemoveSnappedTo:GE];
	    [(RSVertex *)GE shallowRemoveSnappedTo:V];
	}
    }
}

- (BOOL)shallowAddSnappedTo:(RSGraphElement *)GE withParam:(id)param;
// adds GE to this vertex' snappedTo containers only
{
    if (!param) {
	OBASSERT_NOT_REACHED("nil snappedTo parameter");
	return NO;
    }
    
    // Never add self as a snappedTo
    if (GE == self) {
	OBASSERT_NOT_REACHED("trying to add self as a snappedTo");
	return NO;
    }
    
    // Never add a parent as a snappedTo
    if ([[self parents] containsObjectIdenticalTo:GE]) {
        OBASSERT_NOT_REACHED("trying to add a parent as a snappedTo");
        return NO;
    }
    
    if (_snappedTo && [_snappedTo containsElement:GE]) {
	return NO;
    }
    
    [self registerUndoForSnappedTos];
    
    if( !_snappedTo ) {
	_snappedTo = [[RSGroup alloc] initWithGraph:_graph];
	_snappedToParams = [[NSMutableArray alloc] initWithCapacity:3];
    }
    
    [_snappedTo addElement:GE];
    [_snappedToParams addObject:param];
    
    return YES;
}

- (void)addSnappedTo:(RSGraphElement *)GE withParam:(id)param;
// add an element that the vertex is snapped to
{
    if ( ![self shallowAddSnappedTo:GE withParam:param] ) {
	// If nothing was added, we're done
	return;
    }
    
    if (![GE isKindOfClass:[RSVertex class]]) {
	// We're also done if GE is not a vertex
	return;
    }
    
    // GE is a vertex, so we need to update the whole vertex clump.
    // Add self to GE's clump:
    [(RSVertex *)GE addSnappedTo:self withParam:param];
    // Add GE to self's clump:
    for (RSVertex *V in [self vertexSnappedTos]) {
	OBASSERT(V != self);  // Self should not be in vertexSnappedTos
	if (V != GE) {
	    [V shallowAddSnappedTo:GE withParam:param];
	    [(RSVertex *)GE shallowAddSnappedTo:V withParam:param];
	}
    }
    
    [GE setHasChanged:NO];
    [_graph.delegate modelChangeRequires:RSUpdateConstraints];
}


//
#pragma mark -
// Methods for querying snapped-tos
//

- (NSArray *)vertexCluster;
// All vertex snapped-tos, including self
{
    NSMutableArray *cluster = [NSMutableArray arrayWithObject:self];
    [cluster addObjectsFromArray:[self vertexSnappedTos]];
    
    return cluster;
}

- (NSArray *)parentsOfVertexCluster;
{
    NSMutableArray *parents = [NSMutableArray array];
    
    for (RSVertex *V in [self vertexCluster]) {
	[parents addObjectsFromArray:[V parents]];
    }
    
    return parents;
}

- (NSArray *)vertexSnappedTos;
// The other vertices in the vertex cluster (does not include self)
{
    return [[self snappedTo] elementsWithClass:[RSVertex class]];
}

- (NSArray *)nonVertexSnappedTos;
{
    if (![self snappedTo] && [self parentCount] < 1)
	return nil;
    
    if (![self snappedTo])
	return [self parents];
    
    NSMutableArray *all = [NSMutableArray arrayWithArray:[self parents]];
    for (RSGraphElement *GE in [[self snappedTo] elements]) {
	if (![GE isKindOfClass:[RSVertex class]]) {
	    [all addObject:GE];
	}
    }
    
    if (![all count])
	return nil;
    
    return all;
}

- (NSArray *)extendedNonVertexSnappedTos;
// Returns all unique non-vertex objects that this vertex cluster is snapped to.
{
    if (![self snappedTo] && ![self parentCount])
	return nil;
    
    NSMutableArray *all = [NSMutableArray arrayWithArray:[self nonVertexSnappedTos]];
    
    for (RSVertex *V in [self vertexSnappedTos]) {
	NSArray *newSnappers = [V nonVertexSnappedTos];
	for (RSGraphElement *GE in newSnappers) {
	    if (![all containsObjectIdenticalTo:GE]) {
		[all addObject:GE];
	    }
	}
    }
    
    if (![all count])
	return nil;
    
    return all;
}

- (NSArray *)extendedIntersectionSnappedTos;
// Returns a set of lines which at least one vertex in this vertex cluster is snapped to *all* of.  Returns either nil or an array with at least two objects in it.
{
    if (![self snappedTo])
	return nil;
    
//    NSArray *clusterParents = [self parentsOfVertexCluster];
    
    for (RSVertex *V in [self vertexCluster]) {
	NSArray *newSnappers = [[V snappedTo] elementsWithClass:[RSLine class]];
	if ([newSnappers count] < 2)
            continue;
        
//        BOOL valid = YES;
//        for (RSGraphElement *snapper in newSnappers) {
//            if ([clusterParents containsObjectIdenticalTo:snapper])
//                valid = NO;
//        }
//        if (!valid)
//            continue;
        
        // if made it this far...
	return newSnappers;
    }

    // Didn't find any sets of two or more
    return nil;
}


// returns the parameter object associated with a snapped-to element
- (id)paramOfSnappedToElement:(RSGraphElement *)GE;
{
    if( [_snappedTo containsElement:GE] ) {
	NSUInteger index = [[_snappedTo elements] indexOfObjectIdenticalTo:GE];
	return [_snappedToParams objectAtIndex:index];
    }
    else if( /*[GE isKindOfClass:[RSLine class]] &&*/ [[self parents] containsObjectIdenticalTo:GE] ) {
	return [GE paramForElement:self];
    }
    else {
	for (RSVertex *V in [self vertexSnappedTos]) {
	    if ([[V parents] containsObjectIdenticalTo:GE])
		return [GE paramForElement:V];
	    if ([[V snappedTo] containsElement:GE]) {
		NSUInteger index = [[[V snappedTo] elements] indexOfObjectIdenticalTo:GE];
		return [[V snappedToParams] objectAtIndex:index];
	    }
	}
    }
    
    // if made it this far
    //OBASSERT_NOT_REACHED("snappedTo parameter should have been found.");
    return nil;
}

// return YES if this vertex is snapped to or has parent GE
- (BOOL)isSnappedToElement:(RSGraphElement *)GE {
    if( [_snappedTo containsElement:GE] )  return YES;
    if( [_parents containsObjectIdenticalTo:GE] )  return YES;
    
    // if got this far
    return NO;
}

// returns all elements which both this vertex and vertex other are snapped to,
// including parents
- (RSGroup *)snappedToThisAnd:(RSVertex *)other;
{
    NSArray *mine = [self extendedNonVertexSnappedTos];
    NSArray *yours = [other extendedNonVertexSnappedTos];
    
    // return immediately if either vertex is not snapped to anything
    if (!mine || !yours)
	return nil;
    
    // find any elements in common via a nested loop join
    RSGroup *shared = [RSGroup groupWithGraph:_graph];  // elements shared between this and other
    RSGraphElement *GE1;
    RSGraphElement *GE2;
    for (GE1 in mine) {
	for (GE2 in yours) {
	    if( GE1 == GE2 )  [shared addElement:GE1];
	}
    }
    
    return shared;
}
// Returns all elements which all vertices in the array are snapped to, including parents.
+ (NSArray *)elementsTheseVerticesAreSnappedTo:(NSArray *)vertices {
    // return immediately if any of the vertices are not snapped to anything
    RSVertex *V;
    for (V in vertices) {
	if( ![V snappedTo] && [V parentCount] < 1 )  return nil;
    }
    
    // base cases
    NSArray *snapped;
    if( [vertices count] == 0 )  return nil;
    if( [vertices count] == 1 ) {
	V = [vertices objectAtIndex:0];
	snapped = [V extendedNonVertexSnappedTos];
	return snapped;
    }
    
    // if got this far, all vertices have at least one attached element and there are at least two vertices.
    // construct arrays containing parents + snappedTos
    // [parents] is guaranteed to exist; [snappedTo] could be nil
    NSEnumerator *E = [vertices objectEnumerator];
    RSVertex *prev = [E nextObject];
    snapped = [prev extendedNonVertexSnappedTos];
    NSMutableArray *shared = [NSMutableArray arrayWithArray:snapped];  // will be all elements shared between all vertices
    BOOL inCommon;
    while ((V = [E nextObject])) {
	NSArray *snapped2 = [V extendedNonVertexSnappedTos];
	
	// remove any elements not in common via a nested loop join
	// Reverse enumeration is safe for removing the value at the current index
        NSUInteger sharedIndex = [shared count];
        while (sharedIndex--) {
	    RSGraphElement *GE1 = [shared objectAtIndex:sharedIndex];
	    inCommon = NO;
	    for (RSGraphElement *GE2 in snapped2) {
		if( GE1 == GE2 )  inCommon = YES;
	    }
	    if( !inCommon )  [shared removeObjectIdenticalTo:GE1];
	}
    }
    return shared;
}

- (BOOL)canBeDetached;
{
    if ([_parents count] > 1)
	return YES;
    
    // Return YES if there are any non-axis snapped-to objects (including vertex clusters)
    if (_snappedTo) {
	for (RSGraphElement *GE in [_snappedTo elements]) {
	    if (![GE isKindOfClass:[RSAxis class]]) {
		return YES;
	    }
	}
    }
    
    return NO;
}

- (BOOL)isConstrained;
{
    return ([[[self snappedTo] elementsWithClass:[RSLine class]] count] > 0);
}


//////////////////////////////////
#pragma mark -
#pragma mark Sorting assistance
//////////////////////////////////

- (NSComparisonResult)xSort:(RSGraphElement *)other {
    if ( [self position].x < [other position].x ) return NSOrderedAscending;
    if ( [self position].x > [other position].x ) return NSOrderedDescending;
    return NSOrderedSame;
}
- (NSComparisonResult)ySort:(RSGraphElement *)other {
    if ( [self position].y < [other position].y ) return NSOrderedAscending;
    if ( [self position].y > [other position].y ) return NSOrderedDescending;
    return NSOrderedSame;
}
- (NSComparisonResult)yAndColorSort:(RSGraphElement *)other;
{
    if ( [self position].y < [other position].y ) return NSOrderedAscending;
    if ( [self position].y > [other position].y ) return NSOrderedDescending;
    
    OQColor *selfColor = [[self color] colorUsingColorSpace:OQColorSpaceRGB];
    OQColor *otherColor = [(OQColor *)[other color] colorUsingColorSpace:OQColorSpaceRGB];
    if ( [selfColor brightnessComponent] < [otherColor brightnessComponent] )
        return NSOrderedAscending;
    if ( [selfColor brightnessComponent] > [otherColor brightnessComponent] )
        return NSOrderedDescending;
    
    return NSOrderedSame;
}
- (NSComparisonResult)labelSort:(id)other {
    return [[self text] caseInsensitiveCompare:[(RSVertex *)other text]];   // sweet
}

- (data_p)sortValue {
    return _sortValue;
}
- (void)setSortValue:(data_p)value {
    _sortValue = value;
}
- (NSComparisonResult)valueSort:(id)other {
    if ( _sortValue < [other sortValue] ) return NSOrderedAscending;
    else if ( _sortValue > [other sortValue] ) return NSOrderedDescending;
    else return NSOrderedSame;
}

// For tableView stuff, in case no value is entered (nil)
- (void)setNilValueForKey:(NSString *)key;
{
    if ([key isEqualToString:@"positionx"]) {
        [self setPositionx:0.0];
    }
    else if ([key isEqualToString:@"positiony"]) {
        [self setPositiony:0.0];
    }
    else {
        [super setNilValueForKey:key];
    }
}


//////////////////////////////////
#pragma mark -
#pragma mark Describing
//////////////////////////////////

- (NSString *)infoString;
{
    NSString *format = NSLocalizedStringFromTableInBundle(@"Point:  %@", @"GraphSketcherModel", OMNI_BUNDLE, @"Status bar description of a point");
    return [NSString stringWithFormat:format, [_graph infoStringForPoint:_p]];
}
- (NSString *)tabularStringRepresentation;
{
    NSString *stringRep = [NSString stringWithFormat:@"%@\t%@", [RSNumber formatNumberForExport:_p.x], [RSNumber formatNumberForExport:_p.y]];
    if ([self label]) {
        stringRep = [stringRep stringByAppendingFormat:@"\t%@", [self text]];
    }
    return stringRep;
}
- (NSString *)stringRepresentation {
    return [NSString stringWithFormat:@"Vertex: (%f,%f)",_p.x,_p.y];
}



//////////////////////////////////
#pragma mark -
#pragma mark DEPRECATED
//////////////////////////////////

// for compatibility with RSIntersectionPoint
- (BOOL)containsLine:(RSLine *)line {
    return NO;	// normal vertices don't depend on any lines
}


#pragma mark -
#pragma mark Debugging

#ifdef DEBUG

- (NSString *)shortDescription;
{
    return [self infoString];
}

- (NSMutableDictionary *)debugDictionary;
/*
 possible objects: self, CGPoint _p, CGFloat _width, OQColor * _color, 
 RSGroup *_parents, RSTextLabel *_label;
 
 */
{
    NSMutableDictionary *dict = [super debugDictionary];
    [dict setObject:[self shortDescription] forKey:@"shortDescription"];
    return dict;
}

#endif


@end
