// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/Model/RSLine.m 200244 2013-12-10 00:11:55Z correia $

#import <GraphSketcherModel/RSLine.h>

#import <GraphSketcherModel/RSVertex.h>
#import <GraphSketcherModel/RSGraph.h>
#import <GraphSketcherModel/RSGroup.h>
#import <GraphSketcherModel/RSUndoer.h>
#import <GraphSketcherModel/RSNumber.h>
#import <GraphSketcherModel/RSTextLabel.h>
#import <OmniFoundation/OFPreference.h>


NSString *nameFromConnectMethod(RSConnectType connect)
{
    switch (connect) {
	case RSConnectNone:
	    return @"none";
	case RSConnectStraight:
	    return @"straight";
	case RSConnectCurved:
	    return @"curved";
	default:
	    OBASSERT_NOT_REACHED("Unknown connect method");
	    break;
    }
    return @"curved";
}

RSConnectType connectMethodFromName(NSString *name)
{
    if ([name isEqualToString:@"none"])
	return RSConnectNone;
    else if ([name isEqualToString:@"straight"])
	return RSConnectStraight;
    else if ([name isEqualToString:@"curved"])
	return RSConnectCurved;
    else {
	OBASSERT_NOT_REACHED("Unknown connect method name");
	return RSConnectCurved;
    }
}

RSConnectType defaultConnectMethod(void)
{
    RSConnectType method = connectMethodFromName([[OFPreferenceWrapper sharedPreferenceWrapper] stringForKey:@"DefaultConnectMethod"]);
    
    // Only return a standard connect method //hack//
    if (method != RSConnectStraight && method != RSConnectCurved) {
        method = RSConnectStraight;
    }
    return method;
}


@implementation RSLine


/////////////////////////////
#pragma mark -
#pragma mark init/dealloc
/////////////////////////////

+ (void)initialize
{
    OBINITIALIZE;
    [self setVersion:5];
}


- (id)copyWithZone:(NSZone *)zone;
{
    OBASSERT_NOT_REACHED("RSLine abstract superclass cannot be copied.");
    return nil;
}


//////////////////////////////////////////////////////
// Initializers
////////////////////////////////

- (id)initWithGraph:(RSGraph *)graph identifier:(NSString *)identifier;
{
    //OBASSERT_NOT_REACHED("You shouldn't directly initialize this abstract superclass (RSLine)");
    return [super initWithGraph:graph identifier:identifier];
}

- (void)_setupVertices;
// Set up vertices, which are here both for backwards compatibility and for RSFitLine.  But RSConnectLine doesn't use them, so we'll only create them when needed.
{
    if (!_v1) {
        _v1 = [[RSVertex alloc] initWithGraph:[self graph]];
        [_v1 addParent:self];
    }
    if (!_v2) {
        _v2 = [[RSVertex alloc] initWithGraph:[self graph]];
        [_v2 addParent:self];
    }
}

// DESIGNATED INITIALIZER
- (id)initWithGraph:(RSGraph *)graph identifier:(NSString *)identifier color:(OQColor *)color width:(CGFloat)width dash:(NSInteger)dash slide:(CGFloat)slide labelDistance:(CGFloat)labelDistance;
{
    if (!(self = [super initWithGraph:graph identifier:identifier]))
	return nil;
    
    _color = [color retain];
    _width = width;
    _slide = slide;
    _labelDistance = labelDistance;
    _dash = dash;
    
    _label = nil;
    
    _group = nil;
    
    _hasChanged = NO;
    
    _v1 = _v2 = nil;
    
    return self;
}


- (void)invalidate;
{
    [_v1 release];
    _v1 = nil;
    [_v2 release];
    _v2 = nil;
    
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
    
    [_graph.delegate modelChangeRequires:RSUpdateDraw];
}
- (BOOL)hasWidth;
{
    return YES;
}
- (NSInteger)dash {
    if( _dash < 1 )  return 1;
    else  return _dash;
}
- (void)setDash:(NSInteger)style;
{
    if (_dash == style)
        return;
    
    if ([[_graph undoer] firstUndoWithObject:self key:@"setDash"]) {
	[[[_graph undoManager] prepareWithInvocationTarget:self] setDash:_dash];
        [[_graph undoer] setActionName:NSLocalizedStringFromTableInBundle(@"Change Line Stroke Style", @"GraphSketcherModel-UndoActions", OMNI_BUNDLE, @"Undo action name")];
    }
    
    _dash = style;
    
    [_graph.delegate modelChangeRequires:RSUpdateDraw];
}
- (BOOL)hasDash;
{
    return YES;
}
- (NSInteger)shape {
    //return [[self groupWithVertices] shape];
    return 0;
}
- (void)setShape:(NSInteger)style {
    // We don't want to set the shape twice on our own vertices; technically, lines do not have a point shape.  line *groups* do.
}
- (BOOL)canHaveArrows;
{
    return YES;
}

- (BOOL)isMovable {
    // THIS IS CORRECT!  (a line's vertices are movable, but the line itself is not)
    return NO;
}
- (RSDataPoint)position {
    return [self endPoint];
}
- (void)setPosition:(RSDataPoint)p {
    [[self endVertex] setPosition:p];
}

- (RSTextLabel *)label {
    return _label;
}
- (void)setLabel:(RSTextLabel *)label {
    // DO NOT CALL THIS METHOD DIRECTLY!  CALL RSTextLabel's setOwner: INSTEAD!
    [_label autorelease];
    _label = [label retain];
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

- (BOOL)locked {
    // "locked" status is simply based on the vertices
    if( [[self startVertex] locked] && [[self endVertex] locked] )  return YES;
    else  return NO;
}
- (void)setLocked:(BOOL)val {
    [[self startVertex] setLocked:val];
    [[self endVertex] setLocked:val];
}

- (NSArray *)connectedElements {
    //NSMutableArray *A = [NSMutableArray arrayWithObjects:_v1, _v2, _label, nil];
    // The above list works because if _label is nil the list will just end there!!
    //if (_label) [A addObject:_label];
    //return A;
    return [NSArray arrayWithObjects:[self startVertex], [self endVertex], _label, nil];
}

- (BOOL)canBeDetached;
{
    return [[self vertices] canBeDetached];
}


- (void)setNeedsRecompute 
// recompute curve point/control points (triggered by vertex movement)
{
    
}

- (BOOL)hasChanged {
    return _hasChanged;
}
- (void)setHasChanged:(BOOL)flag {
    _hasChanged = flag;
}


/////////////////////////////////////////////
#pragma mark -
#pragma mark Subclasses
/////////////////////////////////////////////
+ (BOOL)supportsConnectMethod:(RSConnectType)connectMethod;
{
    OBRequestConcreteImplementation([RSLine class], _cmd);
    return NO;
}
- (BOOL)supportsConnectMethod:(RSConnectType)connectMethod;
{
    return [[self class] supportsConnectMethod:connectMethod];
}

- (BOOL)hasConnectMethod;
// This is just for the style inspector controls
{
    return YES;
}


/////////////////////////////////////////////
#pragma mark -
#pragma mark Public API
/////////////////////////////////////////////

- (BOOL)isCurved;
{
    return NO;
}

- (BOOL)isEmpty
{
    if ([self startVertex] == [self endVertex]) return YES;
    else return NO;
}
- (BOOL)isTooSmall;
{
    OBRequestConcreteImplementation([self class], _cmd);
    return YES;
}
- (BOOL)hasNoLength;
{
    if ([self vertexCount] == 2 && nearlyEqualDataPoints([self startPoint], [self endPoint]))
	return YES;
    
    return NO;
}

- (BOOL)isVertex {
    return ( [self startVertex] == [self endVertex] );  // start and end vertices are same object
}

- (BOOL)isVertical;
{
    if ([self isCurved]) {
        return NO;
    }
    
    return nearlyEqualDataValues([self startPoint].x, [self endPoint].x);
}
- (BOOL)isHorizontal;
{
    if ([self isCurved]) {
        return NO;
    }
    
    return nearlyEqualDataValues([self startPoint].y, [self endPoint].y);
}

- (RSDataPoint)startPoint {
    return [[self startVertex] position];
}
- (RSDataPoint)endPoint {
    return [[self endVertex] position];
}
- (RSVertex *)otherVertex:(RSVertex *)aVertex {
    if ( aVertex == [self startVertex] ) return [self endVertex];
    else return [self startVertex];
}
- (RSVertex *)startVertex {
    [self _setupVertices];
    return _v1;
}
- (RSVertex *)endVertex {
    [self _setupVertices];
    return _v2;
}
- (RSGroup *)vertices {  // by default, contains the start and end vertices
    RSGroup *G = [RSGroup groupWithGraph:_graph];
    [G addElement:[self startVertex]];
    [G addElement:[self endVertex]];
    return G;
}
- (NSArray *)children;
// defined as "every object that should have this line as a parent"
{
    return [[self vertices] elements];
}
- (NSUInteger)vertexCount;
{
    return 2;
}
- (BOOL)containsVertex:(RSVertex *)V {
    [self _setupVertices];
    if ( V == _v1 || V == _v2 )  return YES;
    else  return NO;
}
- (BOOL)containsVertices:(NSArray *)A;
{
    for (RSVertex *V in A) {
        OBASSERT([V isKindOfClass:[RSVertex class]]);
        if (![self containsVertex:V]) {
            return NO;
        }
    }
    return YES;
}
- (void)setStartVertex:(RSVertex *)v {
    if ( [v containsLine:self] ) {	// can only return true if an RSIntersectionPoint
	NSLog(@"Endpoint can't be an intersection with self!");
	return;
    }
    
    [self _setupVertices];
    if ( v == _v1 )
        return;
    
    [[[_graph undoManager] prepareWithInvocationTarget:self] setStartVertex:_v1];
        
    [_v1 removeParent:self];
    [_v1 autorelease];
    _v1 = [v retain];
    [_v1 addParent:self];   // Add this RSLine as a parent of the vertex
}
- (void)setEndVertex:(RSVertex *)v {
    if ( [v containsLine:self] ) {
	NSLog(@"Endpoint can't be an intersection with self!");
	return;
    }
    
    [self _setupVertices];
    if ( v == _v2 )
        return;
    
    [[[_graph undoManager] prepareWithInvocationTarget:self] setEndVertex:_v2];

    [_v2 removeParent:self];
    [_v2 autorelease];
    _v2 = [v retain];
    [_v2 addParent:self];
}
- (void)replaceVertex:(RSVertex *)oldV with:(RSVertex *)newV {
    [self _setupVertices];
    if ( _v1 == oldV ) {
	//NSLog(@"RSLine replaceVertex: setting start vertex");
	[self setStartVertex:newV];
    }
    else if ( _v2 == oldV ) {
	//NSLog(@"RSLine replaceVertex: setting end vertex");
	[self setEndVertex:newV];
    }
    else {
	NSLog(@"RSLine replaceVertex: vertex not found!");
    }
    // else do nothing
}

- (BOOL)insertVertex:(RSVertex *)V atIndex:(NSUInteger)index;
{
    OBRequestConcreteImplementation(self, _cmd);
}

- (BOOL)dropVertex:(RSVertex *)V;
// This is just used for legacy unarchiving.
{
    [V removeParent:self];
    return NO;
}

- (RSGraphElement *)groupWithVertices;
{
    [self _setupVertices];
    RSGroup *group = [RSGroup groupWithGraph:_graph];
    [group addElement:self];
    [group addElement:_v1];
    [group addElement:_v2];
    return group;
}

- (CGFloat)slide;
{
    return _slide;
}
- (void)setSlide:(CGFloat)value;
// A value between 0 and 1
{
    if (_slide == value)
        return;
    
    if ([[_graph undoer] firstUndoWithObject:self key:@"setSlide"]) {
	[[[_graph undoManager] prepareWithInvocationTarget:self] setSlide:_slide];
        [[_graph undoer] setActionName:NSLocalizedStringFromTableInBundle(@"Label Position", @"GraphSketcherModel-UndoActions", OMNI_BUNDLE, @"Undo action name")];
    }
    
    _slide = value;
    
    [_graph.delegate modelChangeRequires:RSUpdateDraw];
}

// helps out [RSVertex paramOfSnappedToElement]
- (id)paramForElement:(RSGraphElement *)GE {
    if( GE == [self startVertex] ) {
	return [NSNumber numberWithFloat:0];	
    }
    else if( GE == [self endVertex] ) {
	return [NSNumber numberWithFloat:1];
    }
    else  return nil;
}


#pragma mark -
#pragma mark Describing the object

- (NSString *)equationString;
{
    data_p m, b;
    
    if ( [self isCurved] ) {
	return @"";
    }
    
    // otherwise, straight:
    RSVertex *V1 = [self startVertex];
    RSVertex *V2 = [self endVertex];
    
    if ( nearlyEqualDataValues([V1 position].x, [V2 position].x) ) {  // vertical line
	return [NSString stringWithFormat:@"x = %@", [_graph stringForDataValue:[V1 position].x inDimension:RS_ORIENTATION_HORIZONTAL]];
    }
    else if ( nearlyEqualDataValues([V1 position].y, [V2 position].y) ) {  // horizontal line
	return [NSString stringWithFormat:@"y = %@", [_graph stringForDataValue:[V1 position].y inDimension:RS_ORIENTATION_VERTICAL]];
    }
    //else
    // Calculate m and b for "mx + b" format
    m = ([V2 position].y - [V1 position].y) / ([V2 position].x - [V1 position].x);
    b = m * ( 0 - [V1 position].x) + [V1 position].y;
    
    if( b >= 0 ) {
        return [NSString stringWithFormat:@"y = %@x + %@", [_graph stringForDataValue:m inDimension:RS_ORIENTATION_VERTICAL], [_graph stringForDataValue:b inDimension:RS_ORIENTATION_VERTICAL]];
    }
    else {  // b is negative
        return [NSString stringWithFormat:@"y = %@x - %@", [_graph stringForDataValue:m inDimension:RS_ORIENTATION_VERTICAL], [_graph stringForDataValue:(-b) inDimension:RS_ORIENTATION_VERTICAL]];
    }
}
- (NSString *)infoString;
{
    NSString *format = NSLocalizedStringFromTableInBundle(@"Line:   %1$@", @"GraphSketcherModel", OMNI_BUNDLE, @"Status bar description of a line");
    return [NSString stringWithFormat:format, [self equationString]];
}
- (NSString *)stringRepresentation {
    return [NSString stringWithFormat:@"Line: (%f,%f) to (%f,%f)",
	    [[self startVertex] position].x,[[self startVertex] position].y,[[self endVertex] position].x,[[self endVertex] position].y];
}



@end
