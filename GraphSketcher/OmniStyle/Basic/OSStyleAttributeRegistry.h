// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/OmniStyle/Basic/OSStyleAttributeRegistry.h 200244 2013-12-10 00:11:55Z correia $

#import <OmniFoundation/OFObject.h>

@class OFMutableKnownKeyDictionary, OFKnownKeyDictionaryTemplate, OFXMLElement, OFXMLCursor, OFXMLDocument;
@class OSStyleAttribute;
@class NSArray;

@interface OSStyleAttributeRegistry : NSObject
{
@private
    NSDictionary *_registeredStyleAttributesByKey;
    NSArray *_registeredStyleAttributes;
    NSSet *_registeredStyleAttributeKeys;
    OFKnownKeyDictionaryTemplate *_styleDictionaryTemplate;
    OFMutableKnownKeyDictionary *_defaultValuesDictionary;
    
    // Valid while archiving
    OFXMLElement *_appendingXMLElement;
}

+ (void)registerStyleAttribute:(OSStyleAttribute *)styleAttribute;
+ (void)overrideStyleAttribute:(OSStyleAttribute *)styleAttribute;

// For cases where we've been passed a non-optimized attribute key
- (NSString *)attributeKeyForKey:(NSString *)key;

- (NSArray *)registeredAttributeKeys;
- (NSArray *)registeredAttributes;
- (OSStyleAttribute *)attributeWithKey:(NSString *)attributeKey;

@end

/*
 Register attributes like so at the top level of your file:
 
 OSStyleAttributeBeginRegistration
 {
    ...
 }
 OSStyleAttributeEndRegistration
 
 */

typedef void (*OSStyleAttributeRegistration)(void);
extern void _OSStyleAttributeAddRegistration(OSStyleAttributeRegistration registration);
#define OSStyleAttributeBeginRegistration \
static void _OSStyleAttributeRegistration(void)

#define OSStyleAttributeEndRegistration \
static void OSStyleAttributeAddRegistration(void) __attribute__((constructor)); \
static void OSStyleAttributeAddRegistration(void) { \
    _OSStyleAttributeAddRegistration(_OSStyleAttributeRegistration); \
}






