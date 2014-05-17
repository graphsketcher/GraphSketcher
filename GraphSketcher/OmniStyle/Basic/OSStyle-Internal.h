// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

@class OSStyle;

typedef struct {
    OSStyle *instigatingStyle;
    OSStyleChangeInfo changeInfo;
    
    CFMutableDictionaryRef listenerDependencyCount;
    CFMutableDictionaryRef styleToChange;
    CFArrayRef orderedListeners;
} OSStyleChangeContext;

// Extra methods we use on OSStyle and non-style listeners while performing edits
@protocol OSStyleListenerInternal
- (void)_style:(OSStyle *)style prepareForChange:(OSStyleChangeContext *)ctx;
- (void)_addedToOrderedListenerTraversal:(OSStyleChangeContext *)ctx;
- (void)_sendWillToNonStyleListeners:(OSStyleChangeContext *)ctx;
- (void)_finalizeChange:(OSStyleChangeContext *)ctx;
- (void)_sendDidToNonStyleListeners:(OSStyleChangeContext *)ctx;
- (void)_style:(OSStyle *)style willChange:(OSStyleChangeContext *)ctx;
- (void)_style:(OSStyle *)style didChange:(OSStyleChangeContext *)ctx;
@end

void OSStyleForEachListener(OSStyle *self, void (^action)(id <OSStyleListener, OSStyleListenerInternal>)) OB_HIDDEN;

extern BOOL OSStyleInChange(OSStyle *style) OB_HIDDEN;
extern id OSStyleOwner(OSStyle *style) OB_HIDDEN;
extern NSString *OSStyleOwnerContainerKey(OSStyle *style) OB_HIDDEN;

@interface _OSFlattenedStyle : OSStyle
@end

