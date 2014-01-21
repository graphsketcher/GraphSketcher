// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/OmniStyle/Basic/OSEnumStyleAttribute.m 200244 2013-12-10 00:11:55Z correia $

#import "OSEnumStyleAttribute.h"

#import <OmniFoundation/OFEnumNameTable-OFXMLArchiving.h>
#import <OmniFoundation/OFXMLCursor.h>
#import <OmniFoundation/OFXMLElement.h>

#import <OmniBase/OmniBase.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/OmniStyle/Basic/OSEnumStyleAttribute.m 200244 2013-12-10 00:11:55Z correia $");

@implementation OSEnumStyleAttribute

- initWithKey:(NSString *)key enumTable:(OFEnumNameTable *)enumTable;
{
    OBPRECONDITION(enumTable);
    OBPRECONDITION([enumTable nameForEnum:[enumTable defaultEnumValue]]);

    if (!(self = [super initWithKey:key defaultValue:[enumTable nameForEnum:[enumTable defaultEnumValue]]]))
        return nil;

    _enumTable = [enumTable retain];
    
    return self;
}

- (void)dealloc;
{
    [_enumTable release];
    [super dealloc];
}

- (OFEnumNameTable *)enumTable;
{
    return _enumTable;
}

#pragma mark -
#pragma mark OSStyleAttribute subclass

- (id)validValueForValue:(id)value;
{
    if (!value)
        return value; // Nil is always valid
    if (![value isKindOfClass:[NSString class]])
        return self.defaultValue;
    
    NSInteger enumValue = [_enumTable enumForName:value];
    return [_enumTable nameForEnum:enumValue];
}

// Instead of writing out the default value, write our our enum table (which contains the default value)
- (void)appendXMLForDefaultValue:(OFXMLDocument *)doc;
{
    [_enumTable appendXML:doc];
}

- (void)readXMLForDefaultValue:(OFXMLCursor *)cursor;
{
    id child;
    while ((child = [cursor nextChild])) {
        if (![child isKindOfClass:[OFXMLElement class]])
            continue;
        if (![[child name] isEqualToString:[OFEnumNameTable xmlElementName]])
            continue;
        [cursor openElement]; {
            _enumTable = [[OFEnumNameTable alloc] initFromXML:cursor];
        } [cursor closeElement];
    }

    if (!_enumTable)
        [NSException raise:NSInvalidArgumentException reason:NSLocalizedStringFromTableInBundle(@"No OFEnumNameTable found for style attribute", @"OmniStyle", OMNI_BUNDLE, "exception reason")];
    
    _defaultValue = [[_enumTable nameForEnum:[_enumTable defaultEnumValue]] retain];
}

#pragma mark -
#pragma mark OSConcreteStyleAttribute protocol

+ (NSString *)xmlClassName;
{
    return @"enum";
}

- (Class)valueClass;
{
    return [NSString class];
}

- (void)appendXML:(OFXMLDocument *)doc forValue:(id) value;
{
    [doc appendString:value];
}

- (id)copyValueFromXML:(OFXMLCursor *)cursor;
{
    NSString *nameValue = [cursor nextChild];

    // Normalize it, in case the input is bogus
    NSInteger enumValue = [_enumTable enumForName:nameValue];
    nameValue = [_enumTable nameForEnum:enumValue];

    return [nameValue copy];
}

@end
