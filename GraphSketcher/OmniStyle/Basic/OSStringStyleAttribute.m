// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/OmniStyle/Basic/OSStringStyleAttribute.m 200244 2013-12-10 00:11:55Z correia $

#import "OSStringStyleAttribute.h"

#import <OmniFoundation/OFXMLCursor.h>

#import <OmniBase/OmniBase.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/OmniStyle/Basic/OSStringStyleAttribute.m 200244 2013-12-10 00:11:55Z correia $");

@implementation OSStringStyleAttribute

#pragma mark -
#pragma mark OSStyleAttribute subclass

- initFromXML:(OFXMLCursor *)cursor;
{
    if (!(self = [super initFromXML: cursor]))
        return nil;

    if (!_defaultValue)
        // This will happen if there is nothing inside the style-attribute element
        _defaultValue = @"";

    return self;
}

#pragma mark -
#pragma mark OSConcreteStyleAttribute protocol

+ (NSString *) xmlClassName;
{
    return @"string";
}

- (Class) valueClass;
{
    return [NSString class];
}

- (void) appendXML:(OFXMLDocument *)doc forValue:(id) value;
{
    if (![value isKindOfClass: [NSString class]])
        [NSException raise:NSInvalidArgumentException format:NSLocalizedStringFromTableInBundle(@"-[%@ %@] expects NSString inputs but got a '%@'", @"OmniStyle", OMNI_BUNDLE, "exception reason"), NSStringFromClass([self class]), NSStringFromSelector(_cmd), NSStringFromClass([value class])];
    [doc appendString:value];
}

- (id)copyValueFromXML:(OFXMLCursor *)cursor;
{
    id value = [cursor nextChild];
    if (!value)
	value = _defaultValue;
    
    return [[self validValueForValue:value] copy];
}

@end

@implementation OSStringStyleAttribute (Private)
@end
