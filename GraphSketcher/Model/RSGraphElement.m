// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/Model/RSGraphElement.m 200244 2013-12-10 00:11:55Z correia $

#import <GraphSketcherModel/RSGraphElement.h>

#import <GraphSketcherModel/RSGraph.h>
#import <GraphSketcherModel/RSGroup.h>
#import <OmniQuartz/OQColor.h>

CGFloat dimensionOfPointInOrientation(CGPoint p, int orientation) {
    if (orientation == RS_ORIENTATION_HORIZONTAL)
        return p.x;
    else
        return p.y;
}

data_p dimensionOfDataPointInOrientation(RSDataPoint p, int orientation) {
    if (orientation == RS_ORIENTATION_HORIZONTAL)
        return p.x;
    else
        return p.y;
}

CGFloat dimensionOfSizeInOrientation(CGSize size, int orientation) {
    if (orientation == RS_ORIENTATION_HORIZONTAL)
        return size.width;
    else
        return size.height;
}


@implementation RSGraphElement

//////////////////////////////////////////////
#pragma mark -
#pragma mark GraphElement ivars
//////////////////////////////////////////////
@synthesize graph = _graph;

- (NSString *)identifier;
{
    return _identifier;
}

//////////////////////////////////////////////
#pragma mark -
#pragma mark OFXMLIdentifierRegistryObject protocol
//////////////////////////////////////////////
- (void)addedToIdentifierRegistry:(OFXMLIdentifierRegistry *)identifierRegistry withIdentifier:(NSString *)identifier;
{
    OBPRECONDITION(_identifier == nil);
    _identifier = [identifier copy];
}
- (void)removedFromIdentifierRegistry:(OFXMLIdentifierRegistry *)identifierRegistry;
{
    OBPRECONDITION(_identifier != nil);
    [_identifier release];
    _identifier = nil;
}


//////////////////////////////////////////////
#pragma mark -
#pragma mark init/dealloc
//////////////////////////////////////////////

- (id)init;
{
    OBRejectUnusedImplementation([self class], _cmd);
    return nil;
}
- (id)initWithGraph:(RSGraph *)graph identifier:(NSString *)identifier;
{
    OBPRECONDITION(graph);
    
    if (!(self = [super init]))
        return nil;

    _graph = [graph retain];
    
    if (identifier) {
	[_graph registerIdentifier:identifier forObject:self];
    }
    else {
	[_graph registerNewIdentiferForObject:self];
	// that should call back [addedToIdentifierRegistry: withIdentifier]
    }
    
    return self;
}
- (id)initWithoutIdentifier;  // Used by RSUnknown
{
    if (!(self = [super init]))
        return nil;
    
    return self;
}

- (void)invalidate;
{
    if (_identifier) {
	[_graph deregisterObjectWithIdentifier:_identifier];
        OBASSERT(_identifier == nil); // should get cleared via -removedFromIdentifierRegistry:
    }
    
    [[_graph undoManager] removeAllActionsWithTarget:self];
    [_graph release];
    _graph = nil;
}

- (void)dealloc;
{
    if (_graph) {
        [self invalidate];
        OBASSERT(_graph == nil);
    }

    [super dealloc];
}


- (void)encodeWithCoder:(NSCoder *)coder
{
    OBRequestConcreteImplementation([self class], _cmd);
    return;
}
- (id)initWithCoder:(NSCoder *)coder
{
    OBRequestConcreteImplementation([self class], _cmd);
    return nil;
}
- (id)copyWithZone:(NSZone *)zone
// does not support zone
{
    OBRequestConcreteImplementation([self class], _cmd);
    return nil;
}



////////////////////////////////////////
#pragma mark -
#pragma mark KVO
////////////////////////////////////////

+ (NSSet *)keyPathsForValuesAffectingHasColor;
// "documentExists" is the key that depends on other key paths
{
    return [NSSet setWithObjects:@"shape", nil];
}

+ (NSSet *)keyPathsForValuesAffectingHasWidth;
// "documentExists" is the key that depends on other key paths
{
    return [NSSet setWithObjects:@"shape", nil];
}

+ (NSSet *)keyPathsForValuesAffectingHasUserCoords;
// "documentExists" is the key that depends on other key paths
{
    return [NSSet setWithObjects:@"owner", @"label", nil];
}

+ (NSSet *)keyPathsForValuesAffectingHasLabel;
// "documentExists" is the key that depends on other key paths
{
    return [NSSet setWithObjects:@"owner", @"label", @"isLabelable", nil];
}

+ (NSSet *)keyPathsForValuesAffectingHasLabelDistance;
// "documentExists" is the key that depends on other key paths
{
    return [NSSet setWithObjects:@"owner", @"label", @"isLabelable", nil];
}


//////////////////////////////////////////////
#pragma mark -
#pragma mark Handling sets of RSGraphElements
//////////////////////////////////////////////

// Note that the following four methods operate "in place" on the current element and can thus change it rather than returning a new, separate element.  This should perhaps be changed in the future, but for now some of the tools depend on this in-place behavior.

// In other places, we need to get around this with:
- (RSGraphElement *)makeDuplicateIfGroup;
{
    if ([self isKindOfClass:[RSGroup class]]) {
        return [[self copy] autorelease];
    }
    else
        return self;
}

- (RSGraphElement *)elementEorElement:(RSGraphElement *)e;
{
    if (!e)
        return self;
    
    if ( [self isKindOfClass:[RSGroup class]] ) {
	if ( [(RSGroup *)self containsElement:e] ) {
	    return [self elementWithoutElement:e];
	}
	else return [self elementWithElement:e];
    }
    else {  // self is not already an RSGroup
	if ( self == e ) {  // remove self from self
	    return nil;
	}
	else return [self elementWithElement:e];
    }
}

- (RSGraphElement *)elementWithElement:(RSGraphElement *)e;
{
    if (self == e || !e) {
        //NSLog(@"ERROR: RSGraphElement told to add self to self. Returning self.");
	return self;
    }
    
    // Always create a new group, even if self is already a group.  This makes it clear that the group has changed.
    NSArray *elements = [self elements];
    RSGroup *group = [[RSGroup alloc] initWithGraph:_graph byCopyingArray:elements];
    [group addElement:e];
    return [group autorelease];
}

- (RSGraphElement *)elementWithoutElement:(RSGraphElement *)e;
{
    if (!e) {
        return self;
    }
    if (self == e) {
        return nil;
    }
    
    NSArray *myElements = [self elements];
    NSMutableArray *reducedElements = [NSMutableArray array];
    for (RSGraphElement *GE in myElements) {
        if (![e containsElement:GE]) {
            [reducedElements addObject:GE];
        }
    }
    
    if (![reducedElements count])
        return nil;
    if ([reducedElements count] == 1)
        return [reducedElements objectAtIndex:0];
    
    if ([myElements count] == [reducedElements count]) {  // i.e. no change occurred
        return self;
    }
    
    // Otherwise, return a new group with the surviving elements.
    RSGroup *group = [[RSGroup alloc] initWithGraph:_graph byCopyingArray:reducedElements];
    return [group autorelease];
}

- (RSGraphElement *)elementIncludingElement:(RSGraphElement *)e;
// returns the current element if e is part of it
// returns e otherwise
{
    Log3(@"RSGraphElement elementIncludingElement called");
    
    if ( [self isKindOfClass:[RSGroup class]] ) {
	if ( [(RSGroup *)self containsElement:e] ) {
	    return self;
	}
	else return e;
    }
    else {
	return e;
    }
}


- (RSGraphElement *)elementWithClass:(Class)c {
    RSGraphElement *G;
    if ( [self isKindOfClass:[RSGroup class]] ) {
	G = [[[RSGroup alloc] initWithGraph:_graph identifier:nil elements:[(RSGroup *)self elementsWithClass:c]] autorelease];
	G = [G shake];
	return G;
    }
    else {  // not a group
	if ( [self isKindOfClass:c] ) return self;
	else return nil;
    }
}

- (NSUInteger)numberOfElementsWithClass:(Class)class;
// This is overridden by RSGroup
{
    if ([self isKindOfClass:class])  return 1;
    else return 0;
}

- (NSArray *)elements {
    // RSGroup already overrides this method, so if this code is being called, this is not an RSGroup.
    return [NSArray arrayWithObject:self];
}
- (NSArray *)connectedElements {
    return [NSArray array]; // an empty array, autoreleased
}
- (NSArray *)elementsBetweenElement:(RSGraphElement *)e1 andElement:(RSGraphElement *)e2;
{
    return nil;
}

- (RSGraphElement *)elementWithGroup;
// returns the current graph element along with everything that is part of its group (if any)
{
    if( ![self group] ) {
        return self;
    }
    
    if( [self isKindOfClass:[RSGroup class]] ) {
        RSGroup *expanded = [RSGroup groupWithGraph:[self graph]];
        for (RSGraphElement *GE in [(RSGroup *)self elements])
        {
            [expanded addElement:[GE group]];
        }
        return expanded;
    }
    else {  // a single element, with a group
        return [[[self group] copy] autorelease];  // simply return the group
    }
}

- (BOOL)containsElement:(RSGraphElement *)e;
// RSGroup overrides this to be more useful
{
    if (self == e)
	return YES;
    
    return NO;
}



//////////////////////////////////////////////
#pragma mark -
#pragma mark Default methods that subclasses should generally override
//////////////////////////////////////////////

#pragma mark - Graphical properties

- (OQColor *)color {
    Log1(@"WARNING: \"color\" Not implemented for class: %@", [self class]);
    return [OQColor blueColor];
}
- (void)setColor:(OQColor *)color {
    Log1(@"WARNING: \"color\" Not implemented for class: %@", [self class]);
}
- (CGFloat)opacity {
    return [[[self color] colorUsingColorSpace:OQColorSpaceRGB] alphaComponent];
}
- (void)setOpacity:(CGFloat)opacity {
    [self setColor:[[[self color] colorUsingColorSpace:OQColorSpaceRGB] colorWithAlphaComponent:opacity]];
}
- (BOOL)hasColor;
{
    return YES;
}
- (CGFloat)width {
    Log1(@"WARNING: \"width\" Not implemented for class: %@", [self class]);
    return 0.0f;
}
- (void)setWidth:(CGFloat)width {
    Log1(@"WARNING: \"setWidth\" Not implemented for class: %@", [self class]);
}
- (BOOL)hasWidth;
{
    return NO;
}
- (NSInteger)dash {
    Log1(@"WARNING: \"dash\" Not implemented for class: %@", [self class]);
    return 0;
}
- (void)setDash:(NSInteger)style {
    Log1(@"WARNING: \"setDash\" Not implemented for class: %@", [self class]);
}
- (BOOL)hasDash;
{
    return NO;
}
- (NSInteger)shape {
    Log1(@"WARNING: \"shape\" Not implemented for class: %@", [self class]);
    return 0;
}
- (void)setShape:(NSInteger)style {
    Log1(@"WARNING: \"setShape\" Not implemented for class: %@", [self class]);
}
- (BOOL)hasShape;
{
    return NO;
}
- (BOOL)canHaveArrows;
// This is used by the style inspector for enabling/disabling controls
{
    return NO;
}

- (BOOL)hasUserCoords;
{
    return YES;
}
- (RSDataPoint)position {
    Log1(@"WARNING: \"position\" Not implemented for class: %@", [self class]);
    return RSDataPointMake(0.0,0.0);
}
- (void)setPosition:(RSDataPoint)p {
    Log1(@"WARNING: \"setPosition\" Not implemented for class: %@", [self class]);
}
- (void)setPositionx:(data_p)val {
    RSDataPoint pos = [self position];
    pos.x = val;
    [self setPosition:pos];
}
- (void)setPositiony:(data_p)val {
    RSDataPoint pos = [self position];
    pos.y = val;
    [self setPosition:pos];
}
- (void)setPositionWithoutLoggingUndo:(RSDataPoint)p;
{
    // Subclasses override if they wish this to do anything
}
- (RSDataPoint)positionUR;
{
    return [self position];
}
- (void)setCenterPosition:(RSDataPoint)center;
{
    RSDataPoint dl = [self position];  // down-left
    RSDataPoint ur = [self positionUR];  // up-right
    //NSLog(@"dl: %@, ur: %@", NSStringFromPoint(dl), NSStringFromPoint(ur));
    
    RSDataPoint centerOffset = RSDataPointMake((ur.x - dl.x)/2.0f, (ur.y - dl.y)/2.0f);
    RSDataPoint newPosition = RSDataPointMake(center.x - centerOffset.x, center.y - centerOffset.y);
    [self setPosition:newPosition];
}
- (CGSize)size {
    Log1(@"WARNING: \"size\" Not implemented for class: %@", [self class]);
    return CGSizeZero;
}
- (void)setSize:(CGSize)newSize;
{
    NSLog(@"WARNING: \"setSize\" Not implemented for class: %@", [self class]);
}
- (RSConnectType)connectMethod {
    return RSConnectNotApplicable;
}
- (void)setConnectMethod:(RSConnectType)val {
    //Log1(@"WARNING: \"setConnectMethod\" Not implemented for class: %@", [self class]);
}
- (BOOL)hasConnectMethod;
{
    return NO;
}
- (BOOL)canBeConnected;
// Only vertices can be connected
{
    return NO;
}


#pragma mark - Text Label properties

- (RSTextLabel *)label {
    Log3(@"WARNING: \"label\" Not implemented for class: %@", [self class]);
    return nil;
}
- (void)setLabel:(RSTextLabel *)label {
    Log1(@"WARNING: \"setLabel\" Not implemented for class: %@", [self class]);
}
- (NSString *)text {
    Log1(@"WARNING: \"text\" Not implemented for class: %@", [self class]);
    return nil;
}
- (void)setText:(NSString *)text {
    Log1(@"WARNING: \"setText\" Not implemented for class: %@", [self class]);
}
- (NSAttributedString *)attributedString {
    Log1(@"WARNING: \"attributedString\" Not implemented for class: %@", [self class]);
    return nil;
}
- (void)setAttributedString:(NSAttributedString *)text {
    Log1(@"WARNING: \"setAttributedString\" Not implemented for class: %@", [self class]);
}
- (BOOL)isLabelable;
{
    return YES;  // default
}
- (BOOL)hasLabel;
{
    return [self label] != nil;
}
- (CGFloat)labelDistance {
    return 0;
}
- (void)setLabelDistance:(CGFloat)value {
    //Log1(@"WARNING: \"setLabelDistance\" Not implemented for class: %@", [self class]);
}
- (BOOL)hasLabelDistance;
{
    return [self hasLabel];
}
- (RSGraphElement *)owner {
    Log1(@"WARNING: \"owner\" Not implemented for class: %@", [self class]);
    return nil;
}
- (void)setOwner:(RSGraphElement *)owner {
    Log1(@"WARNING: \"setOwner\" Not implemented for class: %@", [self class]);
}
- (BOOL)canBeDetached;
{
    return NO;
}


#pragma mark - Manipulation and bookkeeping properties

- (RSGroup *)group {
    //Log1(@"WARNING: \"group\" Not implemented for class: %@", [self class]);
    return nil;
}
- (void)setGroup:(RSGroup *)newGroup {
    Log1(@"WARNING: \"setGroup\" Not implemented for class: %@", [self class]);
}
- (BOOL)isLockable;
{
    return NO;
}
- (BOOL)locked {
    return NO;
}
- (void)setLocked:(BOOL)val {
    Log1(@"WARNING: \"setLocked\" Not implemented for class: %@", [self class]);
}

- (BOOL)isPartOfAxis {
    return NO;
}
- (BOOL)isMovable {
    // by default, graph elements are not moveable
    return NO;
}
- (BOOL)isVisible {
    // by default, graph elements are visible
    return YES;
}
- (BOOL)canBeCopied {
    return YES;
}



- (void)addParent:(id)parent {
    Log1(@"WARNING: \"addParent\" Not implemented for class: %@", [self class]);
}
- (void)removeParent:(id)parent {
    Log1(@"WARNING: \"removeParent\" Not implemented for class: %@", [self class]);
}
- (RSGraphElement *)groupWithVertices;
// By default, this has no meaning, so we return ourself, unchanged.
{
    return self;
}
- (id)paramForElement:(RSGraphElement *)GE {
    // helps out [RSVertex paramOfSnappedToElement]
    Log1(@"WARNING: \"paramForVertex\" Not implemented for class: %@", [self class]);
    return nil;
}

- (NSUInteger)count {
    return 1;
}

- (int)axisOrientation {
    // by default, graph elements have no orientation:
    return RS_ORIENTATION_UNASSIGNED;
}
- (data_p)tickValue {
    Log1(@"WARNING: \"tickValue\" Not implemented for class: %@", [self class]);
    return 0;
}


#pragma mark - Maintaining snapped-tos

- (BOOL)hasChanged {
    return NO;
}
- (void)setHasChanged:(BOOL)flag {
    //repress//Log1(@"WARNING: \"setHasChanged\" Not implemented for class: %@", [self class]);
}
- (void)setNeedsRecompute {
    //repress//Log1(@"WARNING: \"recompute\" Not implemented for class: %@", [self class]);
}
- (BOOL)recomputeNow {
    return NO;
}


#pragma mark - Actions
//! Consider deprecating?  The main action is in RSGroup's implementation of this method.
- (RSGraphElement *)shake {
    return self;
}



#pragma mark - Describing elements
//! Should be partly replaced with Omni methods?

- (NSString *)infoString;
{
    return nil;  // The status bar won't change if sent this default nil infoString.
}
- (NSString *)stringRepresentation {
    return [NSString stringWithFormat:@"RSGraphElement subclass: %@", [self class]];
}

- (NSDictionary *)attributes {
    return nil;
}

@end
