// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/OmniStyle/Basic/OSNumberStyleAttribute.m 200244 2013-12-10 00:11:55Z correia $

#import "OSNumberStyleAttribute.h"

#import <Foundation/Foundation.h>

#import <OmniFoundation/NSNumber-OFExtensions-CGTypes.h>
#import <OmniFoundation/NSNumber-OFExtensions.h>
#import <OmniFoundation/OFXMLDocument.h>
#import <OmniFoundation/OFXMLElement.h>
#import <OmniFoundation/OFXMLCursor.h>

#import <OmniBase/OmniBase.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/OmniStyle/Basic/OSNumberStyleAttribute.m 200244 2013-12-10 00:11:55Z correia $");

@implementation OSNumberStyleAttribute

- initWithKey:(NSString *)key defaultValue:(NSNumber *)defaultValue valueExtent:(OFExtent)valueExtent integral:(BOOL)integral;
{
    if (!(self = [super initWithKey:key defaultValue:defaultValue]))
        return nil;

    _valueExtent = valueExtent;
    _integral = integral;

    return self;
}

@synthesize valueExtent = _valueExtent;
@synthesize integral = _integral;

#pragma mark -
#pragma mark OSStyleAttribute subclass

- (id)validValueForValue:(id)value;
{
    if (!value)
        return value; // Nil is always valid

    // TODO: Should we map values to an integral value if _integral is set?
    
    // Write the range test so that NaN will fail
    CGFloat fValue = [value cgFloatValue];
    if (fValue >= _valueExtent.location && fValue <= _valueExtent.location + _valueExtent.length)
        return value;

    // NaN *is* valid if it is the default value
    if (value == _defaultValue)
        return value;

    return _defaultValue;
}

#pragma mark -
#pragma mark OSConcreteStyleAttribute protocol

+ (NSString *)xmlClassName;
{
    return @"number";
}

- (Class)valueClass;
{
    return [NSNumber class];
}

- (void)appendXML:(OFXMLDocument *)doc forValue:(id)value;
{
    [doc appendString:[value stringValue]];
}

- (id)copyValueFromXML:(OFXMLCursor *)cursor;
{
    id child = [cursor nextChild];
    if (![child isKindOfClass: [NSString class]])
        [NSException raise:NSInvalidArgumentException format:NSLocalizedStringFromTableInBundle(@"-[%@ %@] expected a string in the cursor", @"OmniStyle", OMNI_BUNDLE, "exception reason"), NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    if ([child isEqualToString:@"NaN"])
        return (id)[[OFNaN sharedNaN] retain];
    return [[NSDecimalNumber alloc] initWithString: child];
}

#pragma mark -
#pragma mark OSStyleAttribute xml

- initFromXML:(OFXMLCursor *)cursor;
{
    self = [super initFromXML:cursor];
    
    if (self) {
        if ([cursor attributeNamed:@"integral"])
            _integral = [[cursor attributeNamed:@"integral"] boolValue];
        if ([cursor attributeNamed:@"min"] && [cursor attributeNamed:@"max"]) {
            _valueExtent = OFExtentFromLocations([[cursor attributeNamed:@"min"] floatValue], [[cursor attributeNamed:@"max"] floatValue]);
        }
        
    }

    return self;
}

- (void)appendAdditionAttributesToXML:(OFXMLDocument *)doc;
{
    OBPRECONDITION(doc);
    
    {
        [doc setAttribute:@"integral" integer:(uint32_t)_integral];
        [doc setAttribute:@"min" double:OFExtentMin(_valueExtent)];
        [doc setAttribute:@"max" double:OFExtentMax(_valueExtent)];
    }
}

@end
