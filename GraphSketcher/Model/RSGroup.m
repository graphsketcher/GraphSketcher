// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <GraphSketcherModel/RSGroup.h>

#import <GraphSketcherModel/RSVertex.h>
#import <GraphSketcherModel/RSGraph.h>
#import <GraphSketcherModel/RSNumber.h>
#import <GraphSketcherModel/RSUndoer.h>


@implementation RSGroup


//////////////////////////////////////////////////
#pragma mark -
#pragma mark Convience creator
///////////////////////////////////////////////////
+ (RSGroup *)groupWithGraph:(RSGraph *)graph;
{
    return [[[RSGroup allocWithZone:[self zone]] initWithGraph:graph] autorelease];
}


//////////////////////////////////////////////////
#pragma mark -
#pragma mark init/dealloc
///////////////////////////////////////////////////


- (id)copyWithZone:(NSZone *)zone
// does not support zone
{
    RSGroup *copy = [[RSGroup allocWithZone:zone] initWithGraph:_graph byCopyingArray:_elements];
    
    return copy;
}



- (id)init;
{
    OBRejectInvalidCall(self, _cmd, @"use designated initializer");
    return nil;
}

- (id)initWithGraph:(RSGraph *)graph;
// initializes a new, empty group
{
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:5];
    
    return [self initWithGraph:graph identifier:nil elements:array];
}

// copies the array
- (id)initWithGraph:(RSGraph *)graph byCopyingArray:(NSArray *)array;
{
    return [self initWithGraph:graph identifier:nil elements:[NSMutableArray arrayWithArray:array]];
}

// DESIGNATED INITIALIZER
- (id)initWithGraph:(RSGraph *)graph identifier:(NSString *)identifier elements:(NSMutableArray *)array;
{
    if (!(self = [super initWithGraph:graph identifier:identifier]))
        return nil;
    
    _elements = [array retain];
    
    return self;
}

- (void)invalidate;
{
    [_elements release];
    _elements = nil;
    
    [super invalidate];
}

- (void)dealloc
{
    [self invalidate];
    
    [super dealloc];
}


//////////////////////////////////////////////////
#pragma mark -
#pragma mark Method to compare the RSGroup (NSObject)
///////////////////////////////////////////////////
- (BOOL)isEqual:(id)other
{
    if ( [other isKindOfClass:[RSGroup class]] ) {
	return [_elements isEqualToArray:[other elements]];
    }
    else  return NO;
}


//////////////////////////////////////////////////
#pragma mark -
#pragma mark RSGraphElement subclass
///////////////////////////////////////////////////
- (OQColor *)color;
{
    OQColor *consensus = nil;
    
    for (RSGraphElement *obj in _elements)
    {
        if ([obj isKindOfClass:[RSVertex class]] && [obj shape] == RS_NONE)
            continue;
        
        if (!consensus) {
            consensus = [obj color];
            continue;
        }
        
        if ( ![consensus isEqual:[obj color]] )
            return nil;
    }
    // if got this far, we have a consensus:
    return consensus;
}
- (void)setColor:(OQColor *)color {
    RSGraphElement *obj;
    
    for (obj in _elements)
    {
	[obj setColor:color];
    }
}
- (CGFloat)opacity;
{
    CGFloat consensus = 0;
    for (RSGraphElement *obj in _elements) {
	CGFloat opacity = [obj opacity];
	if (opacity > consensus)
	    consensus = opacity;
    }
    
    OBASSERT(consensus <= 1);
    return consensus;
}
- (void)setOpacity:(CGFloat)opacity;
{
    for (RSGraphElement *obj in _elements) {
	[obj setOpacity:opacity];
    }
}
- (BOOL)hasColor;
{
    for (RSGraphElement *obj in _elements) {
        if ([obj hasColor])
            return YES;
    }
    return NO;
}
- (CGFloat)width {
    RSGraphElement *obj;
    CGFloat consensus = 0;
    
    for (obj in _elements)
    {
	if ( [obj width] != 0 ) {
	    if ( consensus == 0)  consensus = [obj width];
	    else if ( consensus != [obj width] )  return 0;
	}
    }
    return consensus;	// if no valid objects were found, consensus will be 0 anyhow
}
- (void)setWidth:(CGFloat)width {
    RSGraphElement *obj;
    
    for (obj in _elements)
    {
	[obj setWidth:width];
    }
}
- (BOOL)hasWidth;
// if any element has width
{
    for (RSGraphElement *obj in [self elements])
    {
	if ([obj hasWidth])
	    return YES;
    }
    return NO;
}

- (NSInteger)dash;
{
    NSInteger consensus = 0;
    for (RSGraphElement *obj in [self elements])
    {
        if ( ![obj dash] )
            continue;

        if ( consensus == 0) consensus = [obj dash];
        else if ( consensus != [obj dash] ) return RS_DASH_MIXED;
    }
    return consensus;	// if no valid objects were found, consensus will be 0 anyhow
}
- (void)setDash:(NSInteger)style;
{
    for (RSGraphElement *obj in [self elements])
    {
	[obj setDash:style];
    }
}
- (BOOL)hasDash;
// if any element can have dash styles
{
    for (RSGraphElement *obj in [self elements])
    {
	if ([obj hasDash])
	    return YES;
    }
    return NO;
}

- (NSInteger)shape;
{
    NSInteger consensus = 0;
    for (RSGraphElement *obj in [self elements])
    {
	if ( [obj shape] != 0 ) {
	    if ( consensus == 0)  consensus = [obj shape];
	    else if ( consensus != [obj shape] )  return RS_SHAPE_MIXED;
	}
    }
    return consensus;	// if no valid objects were found, consensus will be 0
}
- (void)setShape:(NSInteger)style;
{
    for (RSGraphElement *obj in [self elements])
    {
	[obj setShape:style];
    }
}
- (BOOL)hasShape;
// if any element has shape
{
    for (RSGraphElement *obj in [self elements])
    {
	if ([obj hasShape])
	    return YES;
    }
    return NO;
}
- (BOOL)canHaveArrows;
// if any element can have arrows
{
    for (RSGraphElement *obj in [self elements])
    {
	if ([obj canHaveArrows])
	    return YES;
    }
    return NO;
}

- (RSConnectType)connectMethod;
{
    RSConnectType consensus = RSConnectNotApplicable;
    for (RSGraphElement *obj in [self elements])
    {
	if ( [obj connectMethod] != RSConnectNotApplicable ) {
	    if ( consensus == RSConnectNotApplicable)  consensus = [obj connectMethod];
	    else if ( consensus != [obj connectMethod] )  return RSConnectMixed;
	}
    }
    return consensus;	// if no valid objects were found, consensus will be RSConnectNotApplicable anyhow
}
- (void)setConnectMethod:(RSConnectType)style;
{
    for (RSGraphElement *obj in [self elements])
    {
	[obj setConnectMethod:style];
    }
}
- (BOOL)hasConnectMethod;
{
    NSInteger vertexCount = 0;
    for (RSGraphElement *obj in [self elements])
    {
	if ([obj hasConnectMethod])
	    return YES;
	
	if ([obj canBeConnected])
	    vertexCount++;
    }

    // Alternatively, we're connectable if we include more than one vertex.
    return (vertexCount > 1 );
}

- (CGFloat)fontSize;
{
    for (id obj in [self elements]) {
        if (![obj conformsToProtocol:@protocol(RSFontAttributes)])
            continue;
        
        // Just return the first one found
        return [obj fontSize];
    }
    
    // If no suitable objects found
    return 0;
    
#if 0
    CGFloat consensus = 0;
    for (RSTextLabel *obj in [self elements])
    {
        CGFloat size = [obj fontSize];
	if ( [obj fontSize] != 0 ) {
	    if ( consensus == 0)  consensus = size;
	    else if ( consensus != size )  return 0;
	}
    }
    // if got this far, we have a consensus:
    return consensus;
#endif
}
- (void)setFontSize:(CGFloat)size;
{
    for (RSGraphElement *obj in [self elements]) {
	if ([obj conformsToProtocol:@protocol(RSFontAttributes)])
            [(id <RSFontAttributes>)obj setFontSize:size];
    }
}

- (OAFontDescriptor *)fontDescriptor;
{
    OAFontDescriptor *consensus = nil;
    for (id obj in [self elements]) {
        if (![obj conformsToProtocol:@protocol(RSFontAttributes)])
            continue;
        
        OAFontDescriptor *desc = [(id <RSFontAttributes>)obj fontDescriptor];
	if( desc != nil )
            return desc;
	
	//this doesn't seem to work://
	//if( consensus == nil )  consensus = [obj font];
	//else if( [obj font] != nil ) {
	//	if ( [consensus isEqual:[obj font]] ) return nil;
	//}
    }
    // if got this far, we have a consensus (or it remained nil):
    return consensus;
}
- (void)setFontDescriptor:(OAFontDescriptor *)newFontDescriptor;
{
    for (RSGraphElement *obj in [self elements]) {
	if ([obj conformsToProtocol:@protocol(RSFontAttributes)])
            [(id <RSFontAttributes>)obj setFontDescriptor:newFontDescriptor];
    }
}

- (id)attributeForKey:(NSString *)name;
{
    // Just return the first one
    for (RSGraphElement<RSFontAttributes> *obj in [self elements]) {
	if ([obj conformsToProtocol:@protocol(RSFontAttributes)])
            return [obj attributeForKey:name];
    }
    
    return nil;
}

- (void)setAttribute:(id)attribute forKey:(NSString *)name;
{
    for (RSGraphElement *obj in [self elements]) {
	if ([obj conformsToProtocol:@protocol(RSFontAttributes)])
            [(id <RSFontAttributes>)obj setAttribute:attribute forKey:name];
    }
}

- (CGFloat)labelDistance;
{
    RSGroup *G = [[self copy] autorelease];
    // First, get the owners of any text labels
    for (RSGraphElement *obj in [self elements])
    {
	RSGraphElement *owner = [obj owner];
        if (!owner)
            owner = [_graph axisOfElement:obj];
        if( owner ) {
	    [G addElement:owner];
	}
    }
    
    // Now determine consensus
    CGFloat consensus = 0;
    for (RSGraphElement *obj in [G elements])
    {
	if ( [obj labelDistance] != 0 ) {
	    if ( consensus == 0)  consensus = [obj labelDistance];
	    else if ( consensus != [obj labelDistance] )  return 0;
	}
    }
    return consensus;	// if no valid objects were found, consensus will be 0 anyhow
}
- (void)setLabelDistance:(CGFloat)value;
{
    RSGroup *G = [[self copy] autorelease];
    // First, get the owners of any text labels
    for (RSGraphElement *obj in [self elements])
    {
        RSGraphElement *owner = [obj owner];
        if (!owner)
            owner = [_graph axisOfElement:obj];
        if( owner ) {
	    [G addElement:owner];
	}
    }
    
    // Now set the label distances
    for (RSGraphElement *obj in [G elements])
    {
	[obj setLabelDistance:value];
    }
}

- (RSDataPoint)position;
    // returns lowest-left corner point
{
    RSDataPoint record = {0, 0};
    
    BOOL first = YES;
    for (RSGraphElement *obj in _elements) {
        if (first) {
            record = [obj position];
            first = NO;
            continue;
        }
        
        RSDataPoint current = [obj position];
	if ( current.x < record.x )  record.x = current.x;
	if ( current.y < record.y )  record.y = current.y;
    }
    
    return record;
}

- (RSDataPoint)positionUR;
// returns upper-right corner point
{
    RSDataPoint record;
    
    BOOL first = YES;
    for (RSGraphElement *obj in _elements) {
        if (first) {
            record = [obj position];
            first = NO;
            continue;
        }
        
        RSDataPoint current = [obj position];
	if ( current.x > record.x )  record.x = current.x;
	if ( current.y > record.y )  record.y = current.y;
    }
    
    return record;
}

- (void)setPosition:(RSDataPoint)p;
{
    RSDataPoint oldPosition = [self position];
    
#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
    if ([[_graph undoer] firstUndoWithObject:self key:@"setPosition"]) {
	[(RSGraphElement *)[[_graph undoManager] prepareWithInvocationTarget:self] setPosition:oldPosition];
    }
#endif
    
    RSDataPoint delta = RSDataPointMake(p.x - oldPosition.x, p.y - oldPosition.y);
    
    for (RSGraphElement *obj in [self elementsMovable])
    {
	RSDataPoint old = [obj position];
	RSDataPoint new;
	new.x = old.x + delta.x;
	new.y = old.y + delta.y;
	[obj setPositionWithoutLoggingUndo:new];
    }
    
    [_graph.delegate modelChangeRequires:RSUpdateConstraints];
}

- (void)setPositionx:(data_p)val {
    RSDataPoint p = [self position];
    p.x = val;
    [self setPosition:p];
}
- (void)setPositiony:(data_p)val {
    RSDataPoint p = [self position];
    p.y = val;
    [self setPosition:p];
}

- (BOOL)isPartOfAxis 
// Returns YES if ANY of the elements are part of the axis
{
    RSGraphElement *obj;
    
    for (obj in _elements)
    {
	if ( [obj isPartOfAxis] ) return YES;
    }
    return NO;
}
- (BOOL)isMovable 
// returns true if ANY of the elements are movable
{
    RSGraphElement *obj;
    
    for (obj in _elements)
    {
	if ( [obj isMovable] ) return YES;
    }
    // if got this far, no objects in this group are movable:
    return NO;
}

- (BOOL)isLabelable;
// Only if exactly one of the elements is labelable
{
    if ([RSGraph isLine:self])
	return YES;
    
    NSInteger count = 0;
    for (RSGraphElement *obj in _elements) {
	if ([obj isLabelable])
	    count++;
	if (count > 1)
	    return NO;
    }
    if (count == 1)
	return YES;
    
    return NO;
}
- (BOOL)hasLabel;
// Returns YES if any of the elements has (or is) a label
{
    for (RSGraphElement *obj in _elements) {
	if ([obj hasLabel])
	    return YES;
    }
    return NO;
}
- (RSTextLabel *)label {
    // Returns the first label found in this group
    RSGraphElement *obj;
    RSTextLabel *label = nil;
    
    for (obj in _elements) {
	label = [obj label];
	if( label )  return label;
    }
    // if got this far
    return nil;
}
//- (void)setLabel:(RSTextLabel *)label {
//	if ( [self isLine] ) [(RSGraphElement *)[self isLine] setLabel:label];
//}


- (RSGroup *)group;
{
    RSGraphElement *obj;
    
    for (obj in _elements) {
        RSGroup *G = [obj group];
        if (G)
            return G;
    }
    return nil;
}
- (void)setGroup:(RSGroup *)newGroup {
    RSGraphElement *obj;
    
    //NSLog(@"RSGroup setGroup");
    for (obj in _elements)
    {
	[obj setGroup:newGroup];
    }
}

- (BOOL)isLockable;
// returns YES if ANY of the objects are lockable
{
    for (RSGraphElement *obj in _elements) {
	if ([obj isLockable])
	    return YES;
    }
    return NO;
}
- (BOOL)locked;
// returns YES if there are lockable objects and ALL of those lockable objects are locked
{
    BOOL lockableObjectFound = NO;
    for (RSGraphElement *obj in _elements) {
	if ( [obj isLockable] ) {
	    lockableObjectFound = YES;
	    if (![obj locked])
		return NO;
	}
    }
    if (lockableObjectFound)
	return YES;
    
    return NO;
}
- (void)setLocked:(BOOL)flag;
{
    for (RSGraphElement *obj in _elements) {
	if ([obj isLockable])
	    [obj setLocked:flag];
    }
}


- (void)addParent:(id)parent {
    RSGraphElement *obj;
    
    for (obj in _elements)
    {
	[obj addParent:parent];
    }
}
- (void)removeParent:(id)parent {
    RSGraphElement *obj;
    
    for (obj in _elements)
    {
	[obj removeParent:parent];
    }
}

- (BOOL)canBeDetached;
// YES if any element can be detached
{
    for (RSGraphElement *obj in _elements) {
	if ([obj canBeDetached])
	    return YES;
    }
    return NO;
}

- (NSString *)infoString;
{
    RSLine *L;
    if( (L = [RSGraph isLine:self]) ) {
        NSString *infoString = [L infoString];
        if (infoString)
            return infoString;
    }
    
    if ([self numberOfElementsWithClass:[RSVertex class]] == 0) {
        return @"";  // blank
    }
    
    RSDataPoint avg = [RSGraph meanOfGroup:self];
    
    NSString *format = NSLocalizedStringFromTableInBundle(@"Average of selected points:  %@", @"GraphSketcherModel", OMNI_BUNDLE, @"Status bar description of a collection of points");
    return [NSString stringWithFormat:format, [_graph infoStringForPoint:avg]];
}


//////////////////////////////////////////////////
#pragma mark -
#pragma mark Manage the RSGroup
///////////////////////////////////////////////////

// returns YES if the element was successfully added
// returns NO if the element is already in the group
- (BOOL)addElement:(RSGraphElement *)e {
    BOOL anythingAdded = NO;
    
    if ( ![self containsElement:e] ) {  // not all elements are in this group
	if( ![e isKindOfClass:[RSGroup class]] ) {   // e is NOT an RSGroup
	    [_elements addObject:e];
	    anythingAdded = YES;
	}
	else {  // adding an RSGroup to this RSGroup
	    for (RSGraphElement *obj in [e elements])
	    {
		if ( [self addElement:obj] )
		    anythingAdded = YES;
	    }
	}
    }
    return anythingAdded;
}
// returns YES if the element was successfully added
// returns NO if the element is already in the group
- (BOOL)addElement:(RSGraphElement *)e after:(RSGraphElement *)e2;
    // if e is a group, all elements are added in sequence after e2.
{
    RSGraphElement *prev = nil;
    BOOL anythingAdded = NO;
    NSUInteger i = 0;
    
    if ( ![self containsElement:e] ) {  // not all elements are in this group
	if( ![e isKindOfClass:[RSGroup class]] ) {   // e is NOT an RSGroup
	    i = [_elements indexOfObjectIdenticalTo:e2];
	    if ( [_elements count] > (i+1) )
		[_elements insertObject:e atIndex:(i+1)];
	    else
		[_elements addObject:e];	// puts it at the end, avoids "index out of bounds"
	    anythingAdded = YES;
	}
	else {  // adding an RSGroup to this RSGroup
	    prev = e2;
	    for (RSGraphElement *obj in [e elements])
	    {
		if ( [self addElement:obj after:prev] )
		    anythingAdded = YES;
		prev = obj;
	    }
	}
    }
    return anythingAdded;
}
- (BOOL)addElement:(RSGraphElement *)e atIndex:(NSUInteger)index;
{
    OBPRECONDITION(index <= [_elements count]);
    OBPRECONDITION(![self containsElement:e]);
    
    if ([e isKindOfClass:[RSGroup class]]) {
	NSIndexSet *indexSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(index, [e count])];
	[_elements insertObjects:[e elements] atIndexes:indexSet];
    }
    else {  // an individual element
	[_elements insertObject:e atIndex:index];
    }
    
    return YES;
}

- (BOOL)removeElement:(RSGraphElement *)e;
{
    BOOL anythingRemoved = NO;
    
    if( ![e isKindOfClass:[RSGroup class]] ) {   // e is NOT an RSGroup
	NSUInteger count = [_elements count];
	[_elements removeObjectIdenticalTo:e];
	if ([_elements count] < count) {
	    anythingRemoved = YES;
	}
    }
    else {  // removing an RSGroup from this RSGroup
	for (RSGraphElement *obj in [[e elements] reverseObjectEnumerator])
	{
	    if ( [self removeElement:obj] ) {
		anythingRemoved = YES;
	    }
	}
    }
    return anythingRemoved;
}
- (BOOL)containsElement:(RSGraphElement *)e;
// returns YES if contains ALL of element e
{
    OBPRECONDITION(e);
    
    if (![_elements count])
	return NO;
    
    for (RSGraphElement *obj in [e elements])
    {
	if ([_elements indexOfObjectIdenticalTo:obj] == NSNotFound)
	    return NO;
    }
    // if got this far...
    return YES;
}
- (BOOL)replaceElement:(RSGraphElement *)old with:(RSGraphElement *)new;
// returns YES if old was found and successfully replaced
{
    BOOL success = NO;
    
    if( [old isKindOfClass:[RSGroup class]] ) { // replacing a whole group of things
	for (RSGraphElement *obj in [old elements])
	{
	    if ( [self removeElement:obj] )  success = YES;
	}
	if( success ) {
	    [self addElement:new];
	}
	return success;
    }
    else { // old object is not a group
	NSUInteger index = [_elements indexOfObjectIdenticalTo:old];
	if( index != NSNotFound ) {
	    [_elements replaceObjectAtIndex:index withObject:new];
	    return YES;
	}
	else  return NO;
    }
    
}
- (RSGraphElement *)nextElement:(RSGraphElement *)e {
    // returns the next element in the array, or nil if not found
    NSInteger i, c;
    
    i = [_elements indexOfObjectIdenticalTo:e];
    if ( i == NSNotFound ) return nil;
    // otherwise...
    c = [_elements count];
    if ( c == ++i ) i = 0;  // increment i, and wrap if went too far
    return [_elements objectAtIndex:i];
}
- (RSGraphElement *)prevElement:(RSGraphElement *)e {
    // returns the previous element in the array, or nil if not found
    NSInteger i, c;
    
    i = [_elements indexOfObjectIdenticalTo:e];
    if ( i == NSNotFound ) return nil;
    // otherwise...
    c = [_elements count];
    if ( -1 == --i ) i = c-1;  // decrement i, and wrap if went too far
    return [_elements objectAtIndex:i];
}

- (void)swapElement:(NSInteger)first with:(NSInteger)second {
    // swaps the position in the array of elements first and second
    [_elements exchangeObjectAtIndex:first withObjectAtIndex:second];
}
- (void)sortElementsUsingSelector:(SEL)comparator {
    [_elements sortUsingSelector:comparator];
}

- (NSUInteger)count {
    return [_elements count];
}
- (BOOL)isEmpty {
    return ( [self count] == 0 );
}
- (NSArray *)elements {
    return _elements;
}
- (NSMutableArray *)elementsWithClass:(Class)c {
    RSGraphElement *obj;
    NSMutableArray *A = [[NSMutableArray alloc] init];
    
    for (obj in _elements) {
	//if ( [obj class] == c ) [A addObject:obj];
	if ( [obj isKindOfClass:c] ) [A addObject:obj];
    }
    return [A autorelease];
}
- (RSGraphElement *)firstElementWithClass:(Class)c {
    RSGraphElement *obj;
    
    for (obj in _elements) {
	//if ( [obj class] == c ) return obj;
	if ( [obj isKindOfClass:c] ) return obj;
    }
    // if got this far...
    return nil;
}
- (RSGraphElement *)lastElementWithClass:(Class)c {
    NSEnumerator *E = [_elements reverseObjectEnumerator];
    RSGraphElement *obj;
    
    while ((obj = [E nextObject])) {
	//if ( [obj class] == c ) return obj;
	if ( [obj isKindOfClass:c] ) return obj;
    }
    // if got this far...
    return nil;
}
- (RSGroup *)groupWithClass:(Class)c {
    return [[[RSGroup alloc] initWithGraph:_graph identifier:nil elements:[self elementsWithClass:c]] autorelease];
}
- (NSUInteger)numberOfElementsWithClass:(Class)c {
    NSInteger count = 0;
    RSGraphElement *obj;
    
    for (obj in _elements) {
	//if ( [obj class] == c ) count++;
	if ( [obj isKindOfClass:c] ) count++;
    }
    return count;
}
- (NSArray *)elementsMovable {
    RSGraphElement *obj;
    NSMutableArray *A = [[NSMutableArray alloc] init];
    
    for (obj in _elements) {
	if ( [obj isMovable] && ![obj locked] )
            [A addObject:obj];
    }
    return [A autorelease];
}
- (NSArray *)elementsLabelled {
    RSGraphElement *obj;
    NSMutableArray *A = [[NSMutableArray alloc] init];
    
    for (obj in _elements) {
	if ( [obj label] ) [A addObject:obj];
    }
    return [A autorelease];
}
- (RSGraphElement *)firstElement 
// returns the first element in the array
{
    if ( [_elements count] > 0 )  return [_elements objectAtIndex:0];
    else  return nil;
}
- (RSGraphElement *)lastElement 
// returns the last element in the array
{
    if ( [_elements count] > 0 )  return [_elements lastObject];
    else  return nil;
}

// returns an RSGroup of elements that are strictly between e1 and e2 in the _elements array
- (RSGroup *)elementsBetween:(RSGraphElement *)e1 and:(RSGraphElement *)e2 {
    NSInteger index1 = [_elements indexOfObjectIdenticalTo:e1];
    NSInteger index2 = [_elements indexOfObjectIdenticalTo:e2];
    // bad cases
    if( index1 == NSNotFound || index2 == NSNotFound )  return nil;
    if( labs(index1 - index2) <= (NSInteger)1 )  return nil;
    // otherwise...
    RSGroup *G = [RSGroup groupWithGraph:_graph];
    NSInteger i;
    if( index1 < index2 ) {
	for( i = index1 + 1; i < index2; i++ ) {
	    [G addElement:[_elements objectAtIndex:i]];
	}
    }
    else {
	for( i = index1 - 1; i > index2; i-- ) {
	    [G addElement:[_elements objectAtIndex:i]];
	}
    }
    // just to be safe
    if( [G count] > 0 )  return G;
    else  return nil;
}

//! look carefully at memory issues -- but I think all is as it should be
- (RSGraphElement *)shake;
// "Shakes off" any excess RSGroup wrappers.  If there are no elements, returns nil; if one element, returns the element, and if more than one element, returns self.
{
    if ( [_elements count] > 1 ) return self;
    else if ( [_elements count] == 1 ) return [_elements objectAtIndex:0];
    else return nil;
}




/////////////////////////////////////////////
#pragma mark -
#pragma mark Describing
/////////////////////////////////////////////

// mostly for debugging?
- (NSString *)stringRepresentation {
    RSGraphElement *GE;
    NSMutableString *s = [NSMutableString string];
    
    for (GE in _elements) {
	[s appendString:[GE stringRepresentation]];
	[s appendString:@"\n"];
    }
    return s;
}



@end
