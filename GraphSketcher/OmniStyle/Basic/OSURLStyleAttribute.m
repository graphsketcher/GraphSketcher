// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/OmniStyle/Basic/OSURLStyleAttribute.m 200244 2013-12-10 00:11:55Z correia $

#import "OSURLStyleAttribute.h"

#import <OmniFoundation/OFXMLString.h>
#import <OmniFoundation/OFXMLCursor.h>
#import <OmniFoundation/NSString-OFSimpleMatching.h>

#import <Foundation/Foundation.h>

#import <OmniBase/OmniBase.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/OmniStyle/Basic/OSURLStyleAttribute.m 200244 2013-12-10 00:11:55Z correia $");

@implementation OSURLStyleAttribute

- initWithKey:(NSString *)key;
{
    return [super initWithKey:key defaultValue:[NSURL URLWithString:@""]];
}

#pragma mark -
#pragma mark OSConcreteStyleAttribute protocol

+ (NSString *)xmlClassName;
{
    return @"url";
}

- (Class)valueClass;
{
    return [NSURL class];
}

- (void)appendXML:(OFXMLDocument *)doc forValue:(id)value;
{
    [doc appendString:[(NSURL *)value absoluteString]];
}

- (id)copyValueFromXML:(OFXMLCursor *)cursor;
{
    NSString *string = OFCharacterDataFromElement([cursor currentElement]);
    if ([NSString isEmptyString:string])
        return [_defaultValue copy];
    
    // NSURL is really unforgiving; other attributes raise on invalid values.  Not sure if that is a good choice going forward.  Instead it would be good to have a 'OFWarningBuffer' class that we could add warnings to.
    NSURL *url = nil;
    @try {
        url = [[NSURL alloc] initWithString:string];
    } @catch (NSException *exc) {
        NSLog(@"Exception raised while converting '%@' to a URL: %@", string, exc);
    }
    
    if (!url)
        NSLog(@"Unable to convert '%@' to a URL", string);
    return url;
}

- (id)copyPropertyListRepresentationForValue:(id)value;
{
    return [[(NSURL *)value absoluteString] copy];
}

- (id)copyValueFromPropertyList:(id)plist;
{
    if (plist && ![plist isKindOfClass:[NSString class]]) {
        NSLog(@"'%@' is a %@, but expected a string to create URL", plist, [plist class]);
        return [_defaultValue copy];
    }
    
    if ([NSString isEmptyString:plist])
        return [_defaultValue copy];

    // NSURL is really unforgiving; other attributes raise on invalid values.  Not sure if that is a good choice going forward.  Instead it would be good to have a 'OFWarningBuffer' class that we could add warnings to.
    @try {
        return [[NSURL alloc] initWithString:plist];
    } @catch (NSException *exc) {
        NSLog(@"Exception raised while converting '%@' to a URL: %@", plist, exc);
    }
    return [_defaultValue copy];
}

- (Class) inspectorCellClass;
{
    return nil;
}

@end
