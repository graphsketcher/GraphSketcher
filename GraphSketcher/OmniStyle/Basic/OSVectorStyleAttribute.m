// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/OmniStyle/Basic/OSVectorStyleAttribute.m 200244 2013-12-10 00:11:55Z correia $

#import "OSVectorStyleAttribute.h"

#import <OmniFoundation/OFPoint.h>
#import <OmniFoundation/OFXMLCursor.h>

#import <OmniBase/OmniBase.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/OmniStyle/Basic/OSVectorStyleAttribute.m 200244 2013-12-10 00:11:55Z correia $");

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
