// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/OmniStyle/Basic/OSStyleAttributeRegistry.m 200244 2013-12-10 00:11:55Z correia $

#import "OSStyleAttributeRegistry.h"
#import "OSStyleAttributeRegistry-Internal.h"

#import <Foundation/Foundation.h>
#import "OSStyleAttribute.h"
#import "OSStyle.h"
#import <OmniFoundation/OFMutableKnownKeyDictionary.h>
#import <OmniFoundation/OFKnownKeyDictionaryTemplate.h>
#import <OmniFoundation/OFXMLDocument.h>
#import <OmniFoundation/OFXMLElement.h>
#import <OmniFoundation/OFXMLCursor.h>

#import <OmniBase/OmniBase.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/OmniStyle/Basic/OSStyleAttributeRegistry.m 200244 2013-12-10 00:11:55Z correia $");

static NSMutableDictionary *_defaultRegisteredStyleAttributes = nil;
static NSMutableDictionary *_overriddenRegisteredStyleAttributes = nil;
static BOOL                 _defaultStyleAttributeRegistrationFinished = NO;

// OSStyleAttributeRegistry
OBDEPRECATED_METHOD(+registerStyleAttributes); // use OSStyleAttributeBeginRegistration/OSStyleAttributeEndRegistration

static OSStyleAttributeRegistration *Registrations = NULL;
static NSUInteger RegistrationCount = 0;

void _OSStyleAttributeAddRegistration(OSStyleAttributeRegistration registration)
{
    OBPRECONDITION(_defaultStyleAttributeRegistrationFinished == NO); // Too late.
    
    Registrations = realloc(Registrations, sizeof(*Registrations) * (RegistrationCount + 1));
    Registrations[RegistrationCount] = registration;
    RegistrationCount++;
}


@interface OSStyleAttributeRegistry (/*Private*/)
@property (nonatomic, getter = isInitializingFromXML) BOOL initializingFromXML; // redeclare the property from the internal category so we get the backing storage

+ (void)_finalizeStyleDatabase;
- (void)_postInit;
@end

@implementation OSStyleAttributeRegistry

+ (void)initialize;
{
    OBINITIALIZE;

    _defaultRegisteredStyleAttributes = [[NSMutableDictionary alloc] init];
    _overriddenRegisteredStyleAttributes = [[NSMutableDictionary alloc] init];

    if (Registrations) {
        for (NSUInteger registrationIndex = 0; registrationIndex < RegistrationCount; registrationIndex++)
            Registrations[registrationIndex]();
        free(Registrations);
        Registrations = NULL;
    }
    
    [self _finalizeStyleDatabase];
}

+ (void)registerStyleAttribute:(OSStyleAttribute *)styleAttribute;
/*" Registers a new style attribute to be used in default style attribute registries created via -initWithUndoManager:.  It is an error to register two style attributes with the same name.  This implicitly changes every existing style object, but currenlty no notification will be sent.  It is understood that this should be called at startup before any style objects are created and an exception will be raised if this rule is violated. "*/
{
    OBPRECONDITION([[styleAttribute validValueForValue:[styleAttribute defaultValue]] isEqual:[styleAttribute defaultValue]]);
    
    if (_defaultStyleAttributeRegistrationFinished)
        [NSException raise:NSInternalInconsistencyException
                    reason:NSLocalizedStringFromTableInBundle(@"Attempted to register a default style attribute after style registration had finished.", @"OmniStyle", OMNI_BUNDLE, "exception reason")];

    // Make sure this isn't a duplicate
    NSString *key = [styleAttribute key];
    if ([_defaultRegisteredStyleAttributes objectForKey:key])
        [NSException raise:NSInvalidArgumentException
                    format:NSLocalizedStringFromTableInBundle(@"Attempted to register two style attributes with the key '%@'.", @"OmniStyle", OMNI_BUNDLE, "exception reason"), key];

    [_defaultRegisteredStyleAttributes setObject:styleAttribute forKey:key];
}

+ (void)overrideStyleAttribute:(OSStyleAttribute *)styleAttribute;
/*" Overrides a default attribute that has been specified with +registerStyleAttribute:. The immediate need for this is that OmniPlan wants to specify different row gap values than OOViewTypes registers, but we don't want to remove the duplicate check from +registerStyleAttribute:, and even if we did we have no guarantee about which +registerStyleAttributes will be called first (OmniPlan's or OOViewTypes's). So we collect overrides and apply them in +_finalizeStyleDatabase, with the bonus of catching cases in which apps override styles that no bundle defines anymore. "*/
{
    OBPRECONDITION([[styleAttribute validValueForValue:[styleAttribute defaultValue]] isEqual:[styleAttribute defaultValue]]);

    if (_defaultStyleAttributeRegistrationFinished)
        [NSException raise:NSInternalInconsistencyException
                    reason:NSLocalizedStringFromTableInBundle(@"Attempted to override a default style attribute after style registration had finished.", @"OmniStyle", OMNI_BUNDLE, "exception reason")];
    
    // Make sure we haven't overridden this attribute more than once
    NSString *key = [styleAttribute key];
    if ([_overriddenRegisteredStyleAttributes objectForKey:key])
        [NSException raise:NSInvalidArgumentException
                    format:NSLocalizedStringFromTableInBundle(@"Attempted to override the default style attribute key '%@' more than once.", @"OmniStyle", OMNI_BUNDLE, "exception reason"), key];
    
    [_overriddenRegisteredStyleAttributes setObject:styleAttribute forKey:key];
}

- init;
{
    if (!_defaultStyleAttributeRegistrationFinished) {
        [self release];
        [NSException raise:NSInternalInconsistencyException
                    reason:NSLocalizedStringFromTableInBundle(@"Attempt to create a OSStyleAttributeRegistry before default attribute registration finished.", @"OmniStyle", OMNI_BUNDLE, "exception reason")];
    }
    if (!(self = [super init]))
        return nil;

    _registeredStyleAttributesByKey = [_defaultRegisteredStyleAttributes copy];
    [self _postInit];
    return self;
}

- (void)dealloc;
{
    [_registeredStyleAttributesByKey release];
    [_registeredStyleAttributeKeys release];
    [_registeredStyleAttributes release];
    [_styleDictionaryTemplate release];
    [_defaultValuesDictionary release];
    [_appendingXMLElement release];
    [super dealloc];
}

- (NSString *)attributeKeyForKey:(NSString *)key;
{
    OBPRECONDITION(_registeredStyleAttributeKeys);
    
    key = [_registeredStyleAttributeKeys member:key];
    OBASSERT(key);
    
    return key;
}

- (NSArray *)registeredAttributeKeys;
/*" Returns the keys of all the registered OSStyleAttributes. "*/
{
    OBPRECONDITION(_styleDictionaryTemplate);
    // This is faster than getting the keys from _registeredStyleAttributesByKey
    return [_styleDictionaryTemplate keys];
}

- (NSArray *)registeredAttributes;
/*" Returns an array of all the registered style attributes in no particular order. "*/
{
    OBPRECONDITION(_registeredStyleAttributes);
    return _registeredStyleAttributes;
}

- (OSStyleAttribute *)attributeWithKey:(NSString *)attributeKey;
/*" Returns the registered attribute with the given key, or nil if no such attribute is registered. "*/
{
    OSStyleAttribute *result = [_registeredStyleAttributesByKey objectForKey: attributeKey];
    OBASSERT_IF(!self.isInitializingFromXML && result != nil, result.key == attributeKey, @"Looking up attribute with an unsanitized key '%@'.", attributeKey); // to reduce memory footprint and improve lookup efficiency, we want the keys used to lookup attributes to have pointer-equality with the attribute keys
    return result;
}

#pragma mark - Internal API
- (OFMutableKnownKeyDictionary *)newRegisteredValueDictionary;
{
    OBPRECONDITION(_styleDictionaryTemplate);
    return [OFMutableKnownKeyDictionary newWithTemplate:_styleDictionaryTemplate];
}

- (OFMutableKnownKeyDictionary *)defaultValuesDictionary;
{
    if (!_defaultValuesDictionary) {
        _defaultValuesDictionary = [self newRegisteredValueDictionary];
        
        // Add in any missing default values
        for (OSStyleAttribute *attr in _registeredStyleAttributes)
            [_defaultValuesDictionary setObject:[attr defaultValue] forKey:[attr key]];
    }

    return _defaultValuesDictionary;
}

#pragma mark - Private API

+ (void)_finalizeStyleDatabase;
{
    _defaultStyleAttributeRegistrationFinished = YES;
    
    // Apply any overrides that were specified, checking to make sure they have something to override first
    for (NSString *key in _overriddenRegisteredStyleAttributes) {
        OSStyleAttribute *override = [_overriddenRegisteredStyleAttributes objectForKey:key];
        OSStyleAttribute *existing = [_defaultRegisteredStyleAttributes objectForKey:key];
        if (!existing)
            [NSException raise:NSInternalInconsistencyException
                        format:NSLocalizedStringFromTableInBundle(@"Attempted to override undefined style attribute with key '%@'.", @"OmniStyle", OMNI_BUNDLE, "exception reason"), key];
        
        [_defaultRegisteredStyleAttributes setObject:override forKey:key];
    }
    
    [_overriddenRegisteredStyleAttributes release];
    _overriddenRegisteredStyleAttributes = nil;
}

- (void)_postInit;
{
    OBPRECONDITION(!_styleDictionaryTemplate);
    OBPRECONDITION(!_registeredStyleAttributeKeys);
    OBPRECONDITION(_registeredStyleAttributesByKey);

    _registeredStyleAttributes = [[_registeredStyleAttributesByKey allValues] retain];
    
    NSArray *allKeys = [_registeredStyleAttributesByKey allKeys];
    _registeredStyleAttributeKeys = [[NSSet alloc] initWithArray:allKeys];
    _styleDictionaryTemplate = [[OFKnownKeyDictionaryTemplate templateWithKeys:allKeys] retain];

    // Now, cleverly, turn the registration dictionary into an OFMKKD.  We'll be doing lots of lookups of attributes by name too.
    NSDictionary *registry = _registeredStyleAttributesByKey;
    _registeredStyleAttributesByKey = [OFMutableKnownKeyDictionary newWithTemplate:_styleDictionaryTemplate];
    [(OFMutableKnownKeyDictionary *)_registeredStyleAttributesByKey addEntriesFromDictionary: registry];
    [registry release];

    OBASSERT([_registeredStyleAttributesByKey count] == [[_styleDictionaryTemplate keys] count]);
}
@end

