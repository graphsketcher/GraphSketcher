// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "OSStyleChange.h"

#import <Foundation/NSArray.h>
#import <Foundation/NSNull.h>

#import "OSStyle.h"
#import <OmniFoundation/OFMutableKnownKeyDictionary.h>
#import <OmniFoundation/OFNull.h>
#import "NSAttributedString-OSExtensions.h"

#import <OmniBase/OmniBase.h>

#include <stdlib.h>

RCS_ID("$Header$");

@implementation OSStyleChange

- initWithStyle:(OSStyle *)style;
{
    OBPRECONDITION(style);
    
    if (!(self = [super init]))
        return nil;

    _nonretained_style = style;
    _preChangeAttributeValues = [style copyEffectiveAttributeValues];

    OB_UNUSED_VALUE(_entriesSize); // Avoid static analyzer warning
    
    return self;
}

- (void)dealloc;
{
    [_preChangeAttributeValues release];
    if (_entries)
        free(_entries);
    [super dealloc];
}

- (void)finalizeChange;
{
    OBPRECONDITION(!_entries);
    OBPRECONDITION(_preChangeAttributeValues);
    
    // Compute the attributes that have changed.  Note that we might have unregistered attributes and further, they might be removed or added (can happen in undo).
    OFMutableKnownKeyDictionary *postChangeStyleAttributeValues = [_nonretained_style copyEffectiveAttributeValues];

    OBASSERT(_preChangeAttributeValues);
    OBASSERT(postChangeStyleAttributeValues);

    [_preChangeAttributeValues enumerateKeysAndObjectPairsWithDictionary:postChangeStyleAttributeValues usingBlock:^(NSString *key, id oldValue, id newValue, BOOL *stop) {
        if (OFNOTEQUAL(oldValue, newValue)) {
            if (_entriesCount == _entriesSize) {
                _entriesSize = 2*(_entriesSize + 1);
                _entries = realloc(_entries, sizeof(*_entries) * _entriesSize);
            }
            
            // We assume that the key, oldValue and newValue will be retained until we are done being used.
            OSStyleChangeEntry *entry = &_entries[_entriesCount];
            entry->key      = key;
            entry->oldValue = oldValue;
            entry->newValue = newValue;
            _entriesCount++;
        }
    }];

    [postChangeStyleAttributeValues release];
}

- (NSUInteger)entryCount;
{
    OBPRECONDITION((_entries == NULL) == (_entriesCount == 0));
    return _entriesCount;
}

- (const OSStyleChangeEntry *)entries;
{
    OBPRECONDITION((_entries == NULL) == (_entriesCount == 0));
    return _entries;
}

// This is relatively slow; use it only when really needed.
- (const OSStyleChangeEntry *)entryForKey:(NSString *)key;
{
    OBPRECONDITION((_entries == NULL) == (_entriesCount == 0));

    if (_entries == NULL) // clang
        return NULL;
    
    NSUInteger entryIndex = _entriesCount;
    while (entryIndex--) {
        const OSStyleChangeEntry *entry = &_entries[entryIndex];
        if ([entry->key isEqualToString:key])
            return entry;
    }
    return NULL;
}

- (BOOL)hasEntryForAnyKeyInSet:(NSSet *)keys;
{
    OBPRECONDITION((_entries == NULL) == (_entriesCount == 0));
    
    if (_entries == NULL) // clang
        return NO;
    
    NSUInteger entryIndex = _entriesCount;
    while (entryIndex--) {
        const OSStyleChangeEntry *entry = &_entries[entryIndex];
        if ([keys member:entry->key])
            return YES;
    }
    return NO;
}

#pragma mark -
#pragma mark Debugging

- (NSMutableDictionary *)debugDictionary;
{
    NSMutableDictionary *dict = [super debugDictionary];
    //[dict setObject:OBShortObjectDescription(_nonretained_style) forKey:@"_nonretained_style"];
    if (_entries) {
        NSMutableDictionary *entries = [NSMutableDictionary dictionary];
        NSUInteger entryIndex = _entriesCount;
        while (entryIndex--) {
            OSStyleChangeEntry *entry = &_entries[entryIndex];
            id oldValue = entry->oldValue ? entry->oldValue : [NSNull null];
            id newValue = entry->newValue ? entry->newValue : [NSNull null];
            
            [entries setObject:[NSString stringWithFormat:@"%@ --> %@", [oldValue shortDescription], [newValue shortDescription]] forKey:entry->key];
        }

        [dict setObject:entries forKey:@"entries"];
    } else {
        if (_preChangeAttributeValues)
            [dict setObject:_preChangeAttributeValues forKey:@"preChangeAttributeValues"];
    }
    return dict;
}

@end
