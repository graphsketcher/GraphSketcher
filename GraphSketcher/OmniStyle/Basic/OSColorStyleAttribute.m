// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/OmniStyle/Basic/OSColorStyleAttribute.m 200244 2013-12-10 00:11:55Z correia $

#import "OSColorStyleAttribute.h"

#if !defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE
#import <OmniAppKit/NSColor-OAExtensions.h>
#else
#import <OmniQuartz/OQColor.h>
#import <OmniQuartz/OQColor-Archiving.h>
#import <OmniFoundation/OFXMLElement.h>
#import <OmniFoundation/OFXMLCursor.h>
#endif

#import <OmniBase/OmniBase.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/OmniStyle/Basic/OSColorStyleAttribute.m 200244 2013-12-10 00:11:55Z correia $");

@implementation OSColorStyleAttribute

- initWithKey:(NSString *)key defaultValue:(id)defaultValue;
{
    OBPRECONDITION([defaultValue isKindOfClass:[OS_COLOR_CLASS class]]);
    return [super initWithKey:key defaultValue:defaultValue];
}

//
// OSConcreteStyleAttribute protocol
//
+ (NSString *) xmlClassName;
{
    return @"color";
}

- (Class) valueClass;
{
    return [OS_COLOR_CLASS class];
}

- (void) appendXML:(OFXMLDocument *)doc forValue:(id) value;
{
    [(OS_COLOR_CLASS *)value appendXML:doc];
}

- (id)copyValueFromXML:(OFXMLCursor *)cursor;
{
    // Really need better support on OFXML for this sort of thing
    OFXMLElement *element;
    while ((element = [cursor nextChild])) {
        if (![element isKindOfClass:[OFXMLElement class]])
            continue;
        
        [cursor openElement];
        OS_COLOR_CLASS *result = [[OS_COLOR_CLASS colorFromXML:cursor] retain];
        [cursor closeElement];
        
        if (result)
            return result;
    }
    
    return [[OS_COLOR_CLASS blackColor] retain];
}

@end
