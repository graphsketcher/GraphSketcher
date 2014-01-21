// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/OmniStyle/Basic/OSBoolStyleAttribute.m 200244 2013-12-10 00:11:55Z correia $

#import "OSBoolStyleAttribute.h"

#import <OmniFoundation/OFXMLCursor.h>

#import <OmniBase/OmniBase.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/OmniStyle/Basic/OSBoolStyleAttribute.m 200244 2013-12-10 00:11:55Z correia $");

@implementation OSBoolStyleAttribute

#pragma mark -
#pragma mark OSStyleAttribute subclass

- (id)validValueForValue:(id)value;
{
    if (!value)
        return value; // Nil is always valid
    if ([value isEqual:(id)kCFBooleanTrue] || [value isEqual:(id)kCFBooleanFalse])
        return value;
    return self.defaultValue;
}

#pragma mark -
#pragma mark OSConcreteStyleAttribute protocol

+ (NSString *) xmlClassName;
{
    return @"bool";
}

- (Class) valueClass;
{
    return [NSNumber class];
}

- (void) appendXML:(OFXMLDocument *)doc forValue:(id) value;
{
    if ([value isEqual:(id)kCFBooleanTrue])
        [doc appendString:@"yes"];
    else
        [doc appendString:@"no"];
}

- (id)copyValueFromXML:(OFXMLCursor *)cursor;
{
    id child = [cursor nextChild];
    if (![child isKindOfClass: [NSString class]])
        [NSException raise:NSInvalidArgumentException format:NSLocalizedStringFromTableInBundle(@"-[%@ %@] expected a string in the cursor", @"OmniStyle", OMNI_BUNDLE, "exception reason"), NSStringFromClass([self class]), NSStringFromSelector(_cmd)];

    if ([child isEqualToString:@"no"])
        return [(id)kCFBooleanFalse copy];
    else if ([child isEqualToString:@"yes"])
        return [(id)kCFBooleanTrue copy];
    else {
        [NSException raise:NSInvalidArgumentException format:NSLocalizedStringFromTableInBundle(@"-[%@ %@] expected a 'yes' or 'no' for its value", @"OmniStyle", OMNI_BUNDLE, "exception reason"), NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
        return nil; // GCOV IGNORE;
    }
}

@end
