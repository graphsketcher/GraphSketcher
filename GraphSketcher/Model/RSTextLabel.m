// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/Model/RSTextLabel.m 200244 2013-12-10 00:11:55Z correia $

#import <GraphSketcherModel/RSTextLabel.h>

#import <GraphSketcherModel/RSGraph.h>
#import <GraphSketcherModel/RSUndoer.h>
#import <GraphSketcherModel/RSNumber.h>
#import <OmniQuartz/OQColor.h>
#import <OmniAppKit/OAFontDescriptor.h>
#import <OmniAppKit/OATextAttributes.h>

#import "RSText.h"

#if !defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE
#import <OmniAppKit/NSUserDefaults-OAExtensions.h>

#import <AppKit/NSAttributedString.h>
#import <AppKit/NSStringDrawing.h>
#import <AppKit/NSFont.h>

#import "NSFont-RSExtensions.h"
#endif



@implementation RSTextLabel

//////////////////////////////////////////////////
#pragma mark -
#pragma mark Internal methods
///////////////////////////////////////////////////

- (BOOL)shouldFormatExponents;
{
    if (![self isPartOfAxis])
        return NO;
    
    RSAxis *axis = [_graph axisWithOrientation:_axisOrientation];
    
    if (![axis usesScientificNotation])
        return NO;
    
    NSString *formattedTickString = [axis formattedDataValue:_tickValue];
    NSString *text = [self text];
    
    if ( ![text isEqualToString:formattedTickString] )
        return NO;
    
    return YES;
}

+ (NSAttributedString *)formatExponentsInString:(NSAttributedString *)original exponentSymbol:(NSString *)exponentSymbol removeLeadingOne:(BOOL)removeLeadingOne;
{
    NSString *text = original.string;
    NSString *expandedSciNotation = NSLocalizedStringFromTableInBundle(@" × 10^", @"GraphSketcherModel", OMNI_BUNDLE, @"Scientific notation replacement");  // using unicode \u2009 "thin space"
    
    NSString *newText = [text stringByReplacingOccurrencesOfString:exponentSymbol withString:expandedSciNotation];
    
    if (removeLeadingOne) {
        NSString *redundantPart = NSLocalizedStringFromTableInBundle(@"1 × ", @"GraphSketcherModel", OMNI_BUNDLE, @"Scientific notation portion that can be removed");  // using unicode \u2009 "thin space"
        NSRange oneRange = [newText rangeOfString:redundantPart];
        if (oneRange.location == 0) {
            newText = [newText substringFromIndex:(oneRange.length)];
        }
    }
    
    NSMutableAttributedString *attString = [[original mutableCopy] autorelease];
    [attString replaceCharactersInRange:NSMakeRange(0,[attString length]) withString:newText];
    
    // Superscripting
    NSRange carrotRange = [newText rangeOfString:@"^"];
    if (carrotRange.location != NSNotFound) {
        [attString deleteCharactersInRange:carrotRange];
        NSRange exponentRange = NSMakeRange(carrotRange.location, [attString length] - carrotRange.location);
        
        /*
         Aki says:
         
         This is the expression we use.
         
         NSInteger superscriptValue = [[attributes objectForKey:NSSuperscriptAttributeName] integerValue];
         CGFloat lineHeight; // the default line height for the run
         
         lineHeight = lineHeight * superscriptValue * 0.4;

         */
        
        // Shrink the font
        OAFontDescriptorPlatformFont font = [attString attribute:NSFontAttributeName atIndex:carrotRange.location effectiveRange:NULL];
        font = [font fontWithSize:font.pointSize * 0.75];
        [attString addAttribute:NSFontAttributeName value:font range:exponentRange];

        // Change the baseline
        [attString addAttribute:NSBaselineOffsetAttributeName value:@([font lineHeight] * 0.4) range:exponentRange];
    }
    
    return attString;
}

- (void)updateFormattedText;
{
    if (![self shouldFormatExponents])
        return;
    
    RSAxis *axis = [_graph axisWithOrientation:_axisOrientation];
    NSAttributedString *attString = [axis formatExponentsInString:[self attributedString]];
    
    if (!_formattedText) {
        _formattedText = [[RSText alloc] initWithAttributedString:attString];
    } else {
        _formattedText.attributedString = attString;
    }
}

- (RSText *)formattedTextObject;
{
    if ([self shouldFormatExponents]) {
        [self updateFormattedText];
        return _formattedText;
    }
    
    // Otherwise
    return _text;
}


//////////////////////////////////////////////////
#pragma mark -
#pragma mark init/dealloc
///////////////////////////////////////////////////
+ (void)initialize
{
    OBINITIALIZE;
    [self setVersion:4];
}


- (id)copyWithZone:(NSZone *)zone
// does not support zone
{
    return [[RSTextLabel alloc] initWithGraph:_graph identifier:nil 
                             attributedString:[self attributedString]
                                     position:_pos
                                     rotation:_rotation];
}


- (id)init;
{
    OBRejectInvalidCall([self class], _cmd, @"Use initWithGraph:");
    return nil;
}
- (id)initWithGraph:(RSGraph *)graph;
// initializes a label with DEFAULT attributes
{    
    return [self initWithGraph:graph fontDescriptor:nil];
}
- (id)initWithGraph:(RSGraph *)graph fontDescriptor:(OAFontDescriptor *)fontDescriptor;
{
    NSDictionary *attributes = RSTextAttributesMake(fontDescriptor, nil/*default color*/);
    
    NSAttributedString *attributedString = [[[NSAttributedString alloc] initWithString:NSLocalizedStringFromTableInBundle(@"Label", @"GraphSketcherModel", OMNI_BUNDLE, @"Default label text") attributes:attributes] autorelease];
        
    RSDataPoint pos = RSDataPointMake(0,0);
    CGFloat angle = 0;
    
    // init:
    Log3(@"default empty RSTextLabel initialized");
    return [self initWithGraph:graph identifier:nil attributedString:attributedString position:pos rotation:angle];
}


// Contains common initialization tasks between init and readFromXML.  Gets called before the second XML unarchiving stage.
- (id)initWithGraph:(RSGraph *)graph identifier:(NSString *)identifier;
{
    if (!(self = [super initWithGraph:graph identifier:identifier]))
	return nil;
    
    _group = nil;
    _axisOrientation = -1; // meaning "unassigned"
    _partOfAxis = NO;
    _rotation = 0;
    _visible = YES;
    
    _formattedText = nil;
    
    return self;
}


// DESIGNATED INITIALIZER
- (id)initWithGraph:(RSGraph *)graph identifier:(NSString *)identifier
   attributedString:(NSAttributedString *)attributedString
	   position:(RSDataPoint)pos
	   rotation:(CGFloat)angle;
{
    if (!(self = [self initWithGraph:graph identifier:identifier]))
	return nil;
    
    _text = [[RSText alloc] initWithAttributedString:attributedString];
    
    _pos = pos;
    _rotation = angle;
    _owner = nil;
    _locked = NO;
    
    return self;
}

- (void)dealloc
{
    [_text release];
    [_formattedText release];
    
    [super dealloc];
}


////////////////////////////////////
#pragma mark -
#pragma mark RSGraphElement subclass
////////////////////////////////////

- (RSDataPoint)position {
    return _pos;
}
- (void)setPosition:(RSDataPoint)pos;
{
    if (_pos.x == pos.x && _pos.y == pos.y)
        return;
    
#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
    if ([[_graph undoer] firstUndoWithObject:self key:@"setPosition"]) {
	[(RSGraphElement *)[[_graph undoManager] prepareWithInvocationTarget:self] setPosition:_pos];
    }
#endif
    
    [self setPositionWithoutLoggingUndo:pos];
    
    if (![self isAxisTickLabel]) {
        [_graph.delegate modelChangeRequires:RSUpdateDraw];
    }
}
- (void)setPositionWithoutLoggingUndo:(RSDataPoint)p;
{
    _pos = p;
}

- (BOOL)hasUserCoords;
{
    return (_owner == nil) && !_partOfAxis;
}

- (OQColor *)color;
{
    return _text.color;
}
- (void)setColor:(OQColor *)color;
{
    if (!color) {
        OBASSERT_NOT_REACHED("How is this hit? Should we assign the default color of black instead?");
        return;
    }
    
    // TODO: This seems incorrect -- it bails if the *first* color is the same, but if the text has mulitple colors, it seems like we should adjust them all.
    OQColor *currentColor = _text.color;
    if ([color isEqual:currentColor])
        return;
    
    if ([[_graph undoer] firstUndoWithObject:self key:@"setColor"]) {
	[(typeof(self))[[_graph undoManager] prepareWithInvocationTarget:self] setColor:currentColor];
        [[_graph undoer] setActionName:NSLocalizedStringFromTableInBundle(@"Change Color", @"GraphSketcherModel-UndoActions", OMNI_BUNDLE, @"Undo action name")];
    }
    
    _text.color = color;
    
    [_graph.delegate modelChangeRequires:RSUpdateDraw];
}
- (CGFloat)width {
    //NSLog(@"\"width\" not implemented for RSTextLabels");
    return 0;
}
- (void)setWidth:(CGFloat)width {
    //NSLog(@"\"setWidth\" not implemented for RSTextLabels");
}


- (BOOL)prepareUndoForAttributedString;
{
    if ([[_graph undoer] firstUndoWithObject:self key:@"setAttributedString"]) {
	[[[_graph undoManager] prepareWithInvocationTarget:self] setAttributedString:[[[self attributedString] copy] autorelease]];
	//[[_graph undoer] setActionName:@"Edit Label"];
        return YES;
    }
    return NO;
}

static void _didChange(RSTextLabel *self)
{
    if ([self isPartOfAxis])
        [self->_graph.delegate modelChangeRequires:RSUpdateWhitespace];
    else
        [self->_graph.delegate modelChangeRequires:RSUpdateDraw];
}

- (RSTextLabel *)label;
// This gets called by [super hasLabel] to determine whether to enable inspector items
{
    return self;
}

- (NSString *)text;
{
    return _text.stringValue;
}

- (void)setText:(NSString *)text;
{
    if ([_text.stringValue isEqualToString:text])
	return;
    
    [self prepareUndoForAttributedString];
    _text.stringValue = text;
    _didChange(self);
}

- (NSAttributedString *)attributedString;
{
    return _text.attributedString;
}

- (void)setAttributedString:(NSAttributedString *)newString;
{
    if ([_text.attributedString isEqualToAttributedString:newString])
        return;
    
    [self prepareUndoForAttributedString];
    
//    if (![text length]) {
//	[_astring deleteCharactersInRange:NSMakeRange(0, [_astring length])];
//	return;
//    }

    _text.attributedString = newString;
    _didChange(self);
}

- (id)attributeForKey:(NSString *)name;
{
    return [_text attributeForKey:name];
}

- (void)setAttribute:(id)obj forKey:(NSString *)name;
{
    [self prepareUndoForAttributedString];
    [_text setAttribute:obj forKey:name];
    _didChange(self);
}

- (CGFloat)fontSize;
{
    return _text.fontSize;
}

- (void)setFontSize:(CGFloat)value;
{
    [self prepareUndoForAttributedString];
    _text.fontSize = value;
    _didChange(self);
}

- (OAFontDescriptor *)fontDescriptor;
{
    return _text.fontDescriptor;
}

- (void)setFontDescriptor:(OAFontDescriptor *)newFontDescriptor;
{
#if !defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE
    // set as "user font":
    [NSFont setUserFont:[newFontDescriptor font]]; // what does this accomplish?
#endif
    
    [self prepareUndoForAttributedString];
    _text.fontDescriptor = newFontDescriptor;
    _didChange(self);
}


- (data_p)tickValue {
    return _tickValue;
}


- (RSGraphElement *)owner {
    return _owner;
}
- (void)setOwner:(RSGraphElement *)owner;
{
    if (_owner == owner)
	return;
    
    if ([[_graph undoer] firstUndoWithObject:self key:@"setOwner"]) {
	[[[_graph undoManager] prepareWithInvocationTarget:self] setOwner:_owner];
        if (owner == nil) {
            [[_graph undoer] setActionName:NSLocalizedStringFromTableInBundle(@"Detach Label", @"GraphSketcherModel-UndoActions", OMNI_BUNDLE, @"Undo action name")];
        }
    }
    
    if (_owner) {
	[_owner setLabel:nil];
    }
    _owner = owner;  // Non-retained; owners retain their labels.
    if (_owner) {
	[_owner setLabel:self];
    }
    else {  // we no longer have an owner
	[self setRotation:0];
    }
    
    [_graph.delegate modelChangeRequires:RSUpdateConstraints];  // potentially need to reposition the label
}

- (void)shallowSetOwner:(RSGraphElement *)owner;
// For situations where we don't want to notify the owner, e.g. when updating a duplicate.
{
    if (_owner == owner)
        return;
    
    _owner = owner;
    if (!_owner) {
        [self setRotation:0];
    }
    
    [_graph.delegate modelChangeRequires:RSUpdateConstraints];  // potentially need to reposition the label
}

- (CGFloat)labelDistance;
{
    if ([_graph isAxisTitle:self]) {
        RSAxis *axis = [_graph axisOfElement:self];
        OBASSERT(axis);
        return [axis titleDistance];
    }
    
    if ([_graph isAxisLabel:self]) {
        RSAxis *axis = [_graph axisOfElement:self];
        OBASSERT(axis);
        return [axis labelDistance];
    }
    
    return [_owner labelDistance];
}
- (void)setLabelDistance:(CGFloat)value;
{
    if ([_graph isAxisTitle:self]) {
        RSAxis *axis = [_graph axisOfElement:self];;
        [axis setTitleDistance:value];
        return;
    }
    
    if ([_graph isAxisLabel:self]) {
        RSAxis *axis = [_graph axisOfElement:self];;
        [axis setLabelDistance:value];
        return;
    }
    
    [_owner setLabelDistance:value];
}
- (BOOL)hasLabelDistance;
{
    return (_owner != nil) || _partOfAxis;
}

- (BOOL)canBeDetached;
{
    return (_owner != nil) && !_partOfAxis;
}

- (RSGroup *)group {
    return _group;
}
- (void)setGroup:(RSGroup *)newGroup {
    _group = newGroup;
}

- (NSArray *)connectedElements {
    if ( _owner )
	return [NSArray arrayWithObject:_owner];
    else
	return [NSArray array]; // empty array
}

- (BOOL)isPartOfAxis {
    return _partOfAxis;
}
- (BOOL)isMovable {
    return ([self owner] == nil && ![self isPartOfAxis]);
}
- (BOOL)isVisible {
    return _visible;
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

- (NSString *)infoString;
{
    NSString *format = NSLocalizedStringFromTableInBundle(@"Label at:  %@", @"GraphSketcherModel", OMNI_BUNDLE, @"Status bar description of a text label");
    RSDataPoint p = [self position];
    return [NSString stringWithFormat:format, [_graph infoStringForPoint:p]];
}

////////////////////////////////////
#pragma mark -
#pragma mark Accessor methods:
////////////////////////////////////

- (BOOL)isDeletedString {
    if( [[self text] isEqualToString:RS_DELETED_STRING] )  return YES;
    else  return NO;
}

- (CGSize)size;
{
    CGSize size = [self formattedTextObject].size;
    
    if( size.width <= 1 )  size.width = 2;
    if( size.height <= 1 )  size.height = 2;
    return size;
}

- (void)resetSizeCache;
{
    [_text resetSizeCache];
    [_formattedText resetSizeCache];
}

- (NSUInteger)length {
    return _text.length;	// "Returns the number of Unicode characters in the receiver."
}


- (void)setPartOfAxis:(BOOL)val {
    _partOfAxis = val;
    if (_partOfAxis == NO) {
	_axisOrientation = RS_ORIENTATION_UNASSIGNED;
    }
}
- (void)setVisible:(BOOL)val {
    _visible = val;
}


- (CGFloat)rotation {
    return _rotation;  // in degrees
}
- (void)setRotation:(CGFloat)angle {  // in degrees
    _rotation = angle;
}


////////////////////////////////////
#pragma mark -
#pragma mark Axis-related accessors
////////////////////////////////////
- (void)setTickValue:(data_p)tickValue axisOrientation:(int)orientation {
    _tickValue = tickValue;
    [self setAxisOrientation:orientation];
}
- (void)setAxisOrientation:(int)orientation {
    _axisOrientation = orientation;
    [self setPartOfAxis:(_axisOrientation != RS_ORIENTATION_UNASSIGNED)];
}
- (int)axisOrientation {
    return _axisOrientation;
}
- (BOOL)isAxisTickLabel {
    if( _axisOrientation == RS_ORIENTATION_HORIZONTAL
       || _axisOrientation == RS_ORIENTATION_VERTICAL ) {
	return YES;
    }
    else  return NO;
}


#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
- (void)useEffectiveScale:(CGFloat)effectiveScale;
{
    [_text useEffectiveScale:effectiveScale];
    [_formattedText useEffectiveScale:effectiveScale];
}
#endif


#pragma mark -
#pragma mark Rendering

- (void)drawAtPoint:(CGPoint)pt baselineRotatedByDegrees:(CGFloat)degrees;
{
    [[self formattedTextObject] drawAtPoint:pt baselineRotatedByDegrees:degrees];
}


@end
