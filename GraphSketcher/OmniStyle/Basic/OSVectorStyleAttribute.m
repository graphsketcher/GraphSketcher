// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "OSVectorStyleAttribute.h"

#import <OmniFoundation/OFPoint.h>
#import <OmniFoundation/OFXMLCursor.h>

#import <OmniBase/OmniBase.h>

RCS_ID("$Header$");

@implementation OSVectorStyleAttribute

#pragma mark -
#pragma mark OSConcreteStyleAttribute protocol

+ (NSString *) xmlClassName;
{
    return @"vector";
}

- (Class) valueClass;
{
    return [OFPoint class];
}

- (void) appendXML:(OFXMLDocument *)doc forValue:(id) value;
{
    [doc appendString:[value description]];
}

- (id)copyValueFromXML:(OFXMLCursor *)cursor;
{
    id child = [cursor nextChild];
    if (![child isKindOfClass: [NSString class]])
        [NSException raise:NSInvalidArgumentException format:NSLocalizedStringFromTableInBundle(@"-[%@ %@] expected a string in the cursor", @"OmniStyle", OMNI_BUNDLE, "exception reason"), NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    return [[OFPoint alloc] initWithString: child];
}

@end
