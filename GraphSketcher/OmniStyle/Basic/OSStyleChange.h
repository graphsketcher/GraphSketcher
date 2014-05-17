// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <Foundation/NSObject.h>

@class NSArray;
@class OSStyle;
@class OFMutableKnownKeyDictionary;

typedef struct _OSStyleChangeEntry {
    NSString *key; // The -key of a OSStyleAttribute
    id oldValue; // The value before the change
    id newValue; // The value after the change
} OSStyleChangeEntry;

@interface OSStyleChange : NSObject
{
@private
    OSStyle *_nonretained_style;
    
    OFMutableKnownKeyDictionary *_preChangeAttributeValues;

    NSUInteger _entriesCount;
    NSUInteger _entriesSize;
    OSStyleChangeEntry *_entries;
}

- initWithStyle:(OSStyle *)style;

- (void)finalizeChange;

- (NSUInteger)entryCount;
- (const OSStyleChangeEntry *)entries;
- (const OSStyleChangeEntry *)entryForKey:(NSString *)key;
- (BOOL)hasEntryForAnyKeyInSet:(NSSet *)keys;

@end
