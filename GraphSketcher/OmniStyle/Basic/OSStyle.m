// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "OSStyle.h"

#import <Foundation/Foundation.h>

#import "OSEnumStyleAttribute.h"
#import "OSErrors.h"
#import "OSStyleAttribute.h"
#import "OSStyleAttributeRegistry.h"
#import "OSStyleChange.h"
#import "OSStyleContext.h"
#import "NSAttributedString-OSExtensions.h"
#import "OSStyledTextStorage-XML.h"
#import <OmniFoundation/OFCFCallbacks.h>
#import <OmniFoundation/OFEnumNameTable.h>
#import <OmniFoundation/NSDictionary-OFExtensions.h>
#import <OmniFoundation/NSMutableDictionary-OFExtensions.h>
#import <OmniFoundation/OFMutableKnownKeyDictionary.h>
#import <OmniFoundation/NSUndoManager-OFExtensions.h>
#import <OmniFoundation/NSArray-OFExtensions.h>
#import <OmniFoundation/CFArray-OFExtensions.h>
#import <OmniFoundation/CFDictionary-OFExtensions.h>
#import <OmniFoundation/OFNull.h>
#import <OmniFoundation/OFXMLElement.h>
#import <OmniFoundation/OFXMLDocument.h>
#import <OmniFoundation/OFXMLCursor.h>

#import "OSStyle-Internal.h"
#import "OSStyleAttributeRegistry-Internal.h"

#import <OmniBase/OmniBase.h>

RCS_ID("$Header$");

#if 0 && defined(DEBUG)
    #define DEBUG_STYLE_EDIT_DEFINED 1
    #define DEBUG_STYLE_EDIT(format, ...) NSLog(@"STYLE %p: " format, self, ## __VA_ARGS__)
#else
    #define DEBUG_STYLE_EDIT_DEFINED 0
    #define DEBUG_STYLE_EDIT(format, ...)
#endif

static id _defaultValueForAttributeKey(OSStyleContext *context, NSString *attributeKey)
{
    // This will hit an assertion if you try to look up an attribute that isn't registered.
    // This implies you should only look for attributes that you get from -copyLocallyDefinedAttributeKeys
    // (this is a feature, I think :)
    OSStyleAttribute *attribute = [[context attributeRegistry] attributeWithKey:attributeKey];
    if (!attribute)
        [NSException raise:NSInternalInconsistencyException
                    format:NSLocalizedStringFromTableInBundle(@"Attempted to look up the value for an unregistered style attribute '%@'", @"OmniStyle", OMNI_BUNDLE, "exception reason"), attributeKey];

    id value = [attribute defaultValue];
    OBPOSTCONDITION(value);
    return value;
}

@implementation _OSFlattenedStyle
- (id)valueForAttributeKey:(NSString *)attributeKey;
{
    id value = [self localValueForAttributeKey:attributeKey];
    if (value)
        return value;
    return _defaultValueForAttributeKey(self.context, attributeKey);
}
@end

@interface OSStyle () <OSStyleListenerInternal>
@property (nonatomic, readonly) NSMutableDictionary *values;
@end

@interface NSObject (OSStyleListenerInternal) <OSStyleListenerInternal>
@end

static CFComparisonResult _compareByAddress(const void *val1, const void *val2, void *context)
{
    if (val1 < val2)
        return kCFCompareLessThan;
    if (val1 > val2)
        return kCFCompareGreaterThan;
    return kCFCompareEqualTo;
}

/*"
 OSStyle is an application neutral style container with a simple key/value access pattern.
 
 Styles may inherit from any number of other styles, with lower-index inherited styles having less precedence than higher-indexed ones.  When looking up the value for a given style attribute, if the style itself doesn't define the attribute, the inherited styles are searched in precedence order.
 
 Styles may also cascade from a list of other styles, again with lower-indexed styles having less precedence.  If no value is located during lookup after searching the locally defined attributes and the inherited styles, then the cascaded style list is searched.  The main difference between cascading and inheritance is that inherited styles are considered part of the style while cascading is more transitory.  Consider the case of OmniOutliner.  If a row defines a local level 0 style 'A' while its parent defines a level 1 style 'B' (it's children should get that style), then 'A' cascades from 'B'.  But if you move the 'A'-styled child row to another parent, the cascade on its style 'A' will be reset while its inherited styles will remain unchanged.
 
 One other difference between inherited styles and the cascade style is that inherited styles are something that the user can meaningfully modify from AppleScript while the cascade style should not be modifiable from AppleScript -- it is implicit based on other model properties (in the case of OmniOutliner, on a item's parent item).
 
 The final implication for this is that setting the cascade style is something that doesn't cause an undo event to be registered since it is assumed that some other undo-able event in the document is responsible for this change.
 
 Styles may only contain values for attributes in their attribute registry.  This means that your application should store a OSStyleAttributeRegistry in its file format that should be used when unarchiving styles.  New documents can just use the default OSStyleAttributeRegistry.  This has the benefit of both allowing default values for attributes that are set in code to change w/o hurting existing documents AND it allows documents from newer versions of the framework to have their attributes preserved when opened in older versions.  The older framework version may not know how to display or edit the property, but it shouldn't destroy it.
 
 The current Omni usage of this class is probably pretty typical, and so (as much as possible) it is enforced/supported here.  First off, the document will have a list of named styles that are written early on.  These styles may reference each other via inheritance and may not have cascading.  Second, individual elements of the document (like rows in OmniOutliner) may have styles and these should not be named.  In all cases, inherited styles must have names and cascade styles should not have names.
 "*/
@implementation OSStyle
{
    OSStyleContext *_context;
    
    NSMutableDictionary *_values;
    NSArray *_cascadeStyles;   // OSStyle
    
    // Either nil, a single listener, or a mutable array if _flags.hasListenerArray is YES.
    union {
        id <OSStyleListener> single;
        NSMutableArray *multiple;
    } _listeners;
    
    union {
        // If we have no local attributes, there's no need to maintain our own text attribute cache. _flags.hasLocalTextAttributeCache dictates whether to access cachedTextAttributes directly or whether to go through the styleForTextAttributeCache
        
        OSStyle *styleForTextAttributeCache;
        NSDictionary *cachedTextAttributes;
    } _textAttributeCache;
    
    struct {
        unsigned int undoEnabled : 1;
        unsigned int editable : 1;
        unsigned int allowsRedundantValues : 1;
        unsigned int hasListenerArray : 1;
        unsigned int inChange : 1;
        unsigned int hasLocalCachedTextAttributes : 1;  // reset to 0 whenever our style cascade changes
        unsigned int changeNotificationDisableCount : 26;
    } _flags;
}

#if 0 && defined(DEBUG_bungi)
    #define STYLE_STATS
#endif

BOOL OSStyleInChange(OSStyle *style)
{
    OBASSERT([style isKindOfClass:[OSStyle class]]);
    return style->_flags.inChange;
}

static NSUInteger _listenerCount(OSStyle *style)
{
    if (style->_listeners.single == nil) {
        OBASSERT(style->_flags.hasListenerArray == NO);
        return 0;
    }
    
    if (style->_flags.hasListenerArray) {
        OBASSERT([style->_listeners.multiple isKindOfClass:[NSArray class]]);
        NSUInteger count = [style->_listeners.multiple count];
        OBASSERT(count >= 2); // else, go back to non-array
        return count;
    } else {
        OBASSERT([style->_listeners.single conformsToProtocol:@protocol(OSStyleListener)]);
        return 1;
    }
}

#ifdef STYLE_STATS
static CFMutableArrayRef _allStyles;

static void styleAllocated(OSStyle *style)
{
    CFRange range = (CFRange){0, CFArrayGetCount(_allStyles)};
    CFIndex index = CFArrayBSearchValues(_allStyles, range, style, _compareByAddress, NULL);
    if (index < range.length && (CFArrayGetValueAtIndex(_allStyles, index) == style)) {
        OBASSERT(NO);
    }
    CFArrayInsertValueAtIndex(_allStyles, index, style);
}

static void styleDeallocated(OSStyle *style)
{
    CFRange range = (CFRange){0, CFArrayGetCount(_allStyles)};
    CFIndex index = CFArrayBSearchValues(_allStyles, range, style, _compareByAddress, NULL);
    if (index >= range.length || (CFArrayGetValueAtIndex(_allStyles, index) != style)) {
        OBASSERT(NO);
    }
    CFArrayRemoveValueAtIndex(_allStyles, index);
}

+ (void)printStyleStats;
{
    NSUInteger styleIndex = CFArrayGetCount(_allStyles);
    fprintf(stderr, "%" PRIuPTR " styles\n", styleIndex);

    NSUInteger noValuesCount = 0;
    NSUInteger noCascadeStylesCount = 0;
    
    NSUInteger zeroListeners = 0;
    NSUInteger oneListener = 0;
    NSUInteger manyListeners = 0;
    
    while (styleIndex--) {
        OSStyle *style = CFArrayGetValueAtIndex((CFArrayRef)_allStyles, styleIndex);

        if ([style->_values count] == 0)
            noValuesCount++;
        if ([style->_cascadeStyles count] == 0)
            noCascadeStylesCount++;

        switch (_listenerCount(style)) {
            case 0:
                zeroListeners++;
                break;
            case 1:
                oneListener++;
                break;
            default:
                manyListeners++;
                break;
        }
    }

#define PRINT_STAT(x) fprintf(stderr, "  %s = %" PRIuPTR "\n", #x, x)
    
    PRINT_STAT(noValuesCount);
    PRINT_STAT(noCascadeStylesCount);
    PRINT_STAT(zeroListeners);
    PRINT_STAT(oneListener);
    PRINT_STAT(manyListeners);

#undef PRINT_STAT
}
#else
static void styleAllocated(OSStyle *style)
{
}
static void styleDeallocated(OSStyle *style)
{
}
#endif

static NSArray *emptyArray;
static NSSet *fontDescriptorKeys = nil;

BOOL OAFontDescriptorIsInterestedInStyleAttributeKey(NSString *key)
{
    OBPRECONDITION(fontDescriptorKeys);
    return ([fontDescriptorKeys member:key] != nil);
}

+ (void)initialize;
{
    // Ensure that no subclass of OSStyle overrides -hash/-isEqual:. Styles have identity and should be pointer equal.
    OBPRECONDITION(OBClassImplementingMethod(self, @selector(hash)) == [NSObject class]);
    OBPRECONDITION(OBClassImplementingMethod(self, @selector(isEqual:)) == [NSObject class]);
    
    // Subclasses should not implement these two methods. We use our own back channel and these are just for other style listeners
    OBASSERT(OBClassImplementingMethod(self, @selector(style:willChange:)) == [OSStyle class]);
    OBASSERT(OBClassImplementingMethod(self, @selector(style:didChange:)) == [OSStyle class]);
    
    OBINITIALIZE;

#ifdef STYLE_STATS
    _allStyles = OFCreateNonOwnedPointerArray();
#endif

    // Bizarrely, NSArray doesn't return the same pointer each time this is called.
    emptyArray = [[NSArray alloc] init];
        
    // Make sure style attributes get registered before we are used
    [OSStyleAttributeRegistry class];
    
    // Don't implement this blithely.  We may need to do the same placeholder tricks we do in -init
    OBASSERT(![self conformsToProtocol:@protocol(NSCopying)]);

    NSArray *keys = [NSArray arrayWithObjects:
                     [OSFontFamilyNameStyleAttribute key],
                     [OSFontSizeStyleAttribute key],
                     [OSFontWeightStyleAttribute key],
                     [OSFontItalicStyleAttribute key],
                     [OSFontCondensedStyleAttribute key],
                     [OSFontFixedPitchStyleAttribute key],
                     nil];
    fontDescriptorKeys = [[NSSet alloc] initWithArray:keys];
}

- initWithContext:(OSStyleContext *)context cascadeStyles:(NSArray *)cascadeStyles;
{
    OBPRECONDITION(context);
    OBPRECONDITION(![cascadeStyles anyObjectSatisfiesPredicate:^BOOL(id object) {
        OSStyle *cascadeStyle = object;
        OBASSERT(context.attributeRegistry == cascadeStyle.registry, @"Every cascaded style must have the same registry as the context.");
        return context.attributeRegistry != cascadeStyle.registry;
    }]);

    if (!(self = [super init]))
        return nil;
    
    // These are replaced by -performChange:withAction:
    OBASSERT_NOT_IMPLEMENTED(self, willChange:);
    OBASSERT_NOT_IMPLEMENTED(self, didChange);
    
    _context = [context retain];

    // Actually have an empty array here so that callers can do -arrayByAddingObject:.
    if ([cascadeStyles count]) {
        _cascadeStyles = [cascadeStyles copy];
	[_cascadeStyles makeObjectsPerformSelector:@selector(addListener:) withObject:self];
    } else
        _cascadeStyles = [emptyArray retain];

    _flags.editable = 1;
    
    styleAllocated(self);
    
    OBINVARIANT([self _checkInvariants]);
    return self;
}

- initWithContext:(OSStyleContext *)context;
{
    return [self initWithContext:context cascadeStyles:nil];
}

- (void)dealloc;
{
    // Fixing this is hard since we need to make sure all styles are deallocated before the containing document's OSStyleContext is invalidated.
    OBINVARIANT([_context isInvalidated] || [self _checkInvariants]);
    OBPRECONDITION(!_flags.inChange);
    
    styleDeallocated(self);

    // Typically this doesn't matter since the document will hold onto us until it is gone (along with its undo manager).  But in some cases (like copy-paste support in OO3), we are just a transient object temporarily attached to a longer lived undo manager.  It could be argued that it would be better for us to disable undo registration for transient objects, but this has the benefit of preventing crashes if we screw up.
    // Do NOT do this if the context is invalidated, though, since in that case the undo manager has been released already and this is irrelevant and will cause assertions.
    if (_flags.undoEnabled && ![_context isInvalidated])
        [[_context undoManager] removeAllActionsWithTarget:self];

    // Remove ourselves from any style listening agreements
    [_cascadeStyles makeObjectsPerformSelector:@selector(removeListener:) withObject:self];
    
    [_context release];
    [_values release];
    [_cascadeStyles release];
    
    if (_flags.hasListenerArray)
        [_listeners.multiple release]; // Listeners shouldn't be retained, only the array, so the single-listener case doesn't call -release
    
    // Might be the styleForTextAttributeCache; both need -release
    [_textAttributeCache.cachedTextAttributes release];
    
    [super dealloc];
}


//
// API
//

- (void)enableUndo;
{
    _flags.undoEnabled = YES;
}

- (void)disableUndo;
{
    _flags.undoEnabled = NO;
}

- (BOOL)isUndoEnabled;
{
    return _flags.undoEnabled;
}

- (BOOL)isEditable;
{
    return _flags.editable;
}

- (void)setEditable:(BOOL)flag;
{
    _flags.editable = flag ? 1 : 0;
}

- (void)setAllowsRedundantValues:(BOOL)allowsRedundantValues;
{
    _flags.allowsRedundantValues = allowsRedundantValues;
}

- (BOOL)allowsRedundantValues;
{
    return _flags.allowsRedundantValues;
}

- (OSStyleContext *)context;
{
    return _context;
}

- (OSStyleAttributeRegistry *)registry;
{
    return [_context attributeRegistry];
}

- (NSUndoManager *)undoManagerIfUndoIsEnabled;
/*" Returns the undo manager for the style, if undo is enabled for this style (and nil otherwise). Use this if you want to register undo events for this style, so that the events don't get registered if undo is disabled for this style. "*/
{
    if (_flags.undoEnabled)
        return [self undoManagerEvenIfUndoIsDisabled];
    return nil;
}

- (NSUndoManager *)undoManagerEvenIfUndoIsDisabled;
/*" Returns the undo manager for the style, even if undo is disabled for this style. The common use case would be to get the actual undo manager in order to name any open undo group, for instance, or perhaps to find out if you are in the middle of undoing/redoing. "*/
{
    return [_context undoManager];
}

- (NSUndoManager *)undoManager;
{
    // Deprecated. Use undoManagerIfUndoIsEnabled for undo action registration - it will return nil if undo is disabled for this style, so no actions will be registered. Use undoManagerEvenIfUndoIsDisabled if you really do need the undo manager for this style - for naming undo groups, for instance.
    OBASSERT_NOT_REACHED("Use undoManagerIfUndoIsEnabled or undoManagerEvenIfUndoIsDisabled depending on your needs");
    return [self undoManagerIfUndoIsEnabled];
}

/*
 Note that we disallow inheriting and cascading from the same style indirectly be requiring that inherited styles be named and cascade styles be unnamed.
 */

static BOOL _validateForAssociatingStyles(OSStyle *self, OSStyle *style, NSError **outError)
{
    OBPRECONDITION(style);
    OBPRECONDITION([style isKindOfClass:[OSStyle class]]); // All AppleScript callers should check this.
    
    // Associated styles must have the same context
    if (self->_context != style->_context) {
        OSError(outError, OSStyleContextMismatchError, NSLocalizedStringFromTableInBundle(@"Attempted to connect two styles with different style contexts.", @"OmniStyle", OMNI_BUNDLE, "error reason"), nil);
        return NO;
    }
    
    // It is valid to associate to styles with the same undo enable status.  It is also OK to make a style w/o undo enable depend upon styles with undo enabled.  However, it is not OK to make a style with undo enabled depend upon one w/o undo enabled.
    if (self->_flags.undoEnabled && ![style isUndoEnabled]) {
        OSError(outError, OSStyleUndoEnabledMismatchError, NSLocalizedStringFromTableInBundle(@"Attempted to cause a style with undo enabled to depend on a style without an undo enabled.", @"OmniStyle", OMNI_BUNDLE, "error reason"), nil);
        return NO;
    }
    
    // See if we can find ourselves in the set of styles influenced by the potential new ancestor.  If we are in that list (it depend on us) then we can't be allowed to depend on it!
    OSStyleAssociatedStyleIterationTermination searchTerminationCondition = [style iterateAssociatedStylesIncludingRoot:YES recursively:YES with:^OSStyleAssociatedStyleIterationResult(OSStyle *transitiveStyle) {
        if (transitiveStyle == self)
            return OSStyleAssociatedStyleIterationStop;
        return OSStyleAssociatedStyleIterationContinue;
    }];
    BOOL cycleDetected = searchTerminationCondition == OSStyleAssociatedStyleIterationStopped;
    
    if (cycleDetected) {
        NSString *reason = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"This operation would create a self-referential style graph between %@ and %@", @"OmniStyle", OMNI_BUNDLE, "exception reason"), self, style];
        OSError(outError, OSStyleCycleError, reason, nil);
        return NO;
    }
    
    return YES;
}

- (NSArray/*<OSStyle>*/ *)cascadeStyles;
    /*" Returns the single cascade style for the receiver. "*/
{
    return _cascadeStyles;
}

- (void)setCascadeStyles:(NSArray *)cascadeStyles;
/*" Sets the cascade style list for the receiver. "*/
{
    OBINVARIANT([self _checkInvariants]);

    // We do not want to compare the *contents* here, but the actual pointers
    if ([_cascadeStyles isIdenticalToArray:cascadeStyles])
        return;

    for (OSStyle *cascadeStyle in cascadeStyles) {
        NSError *error = nil;
        if (![self _validateStyleForCascading:cascadeStyle error:&error]) {
            [NSException raise:NSInvalidArgumentException reason:[error localizedDescription]];
        }
    }
    
    // NOTE: This doesn't register an undo event right now since this change should only happen due to another change.  BUT, if an exception is raised sometime during the 'whole' change, we might end up with a bogus state.  If we registered an undo here, we could start a group, do the whole change and if there was an exception, undo anything that did get done.

    [self performChange:OSStyleChangeKindCascadeStyle withAction:^{
        for (OSStyle *cascadeStyle in _cascadeStyles)
            [cascadeStyle removeListener:self];

        [_cascadeStyles release];
        _cascadeStyles = [[NSArray alloc] initWithArray:cascadeStyles];

        for (OSStyle *cascadeStyle in _cascadeStyles)
            [cascadeStyle addListener:self];
    }];
    
    OBINVARIANT([self _checkInvariants]);
}

- (void)setCascadeStyle:(OSStyle *)cascadeStyle;
/*" A convenience method that sets a single (or empty) cascade style list "*/
{
    if (cascadeStyle) {
        NSArray *styles = [[NSArray alloc] initWithObjects:&cascadeStyle count:1];
        @try {
            [self setCascadeStyles:styles];
        } @finally {
            [styles release];
        }
    } else
        [self setCascadeStyles:emptyArray];
}

// Obviously this isn't good for unregistered attributes
- (BOOL) setValue:(id)value forAttribute:(OSStyleAttribute *)attribute;
{
    return [self setValue:value forAttributeKey:[attribute key]];
}

- (BOOL)shouldSetValue:(id)value forAttributeKey:(NSString *)attributeKey;
{
    return self.editable;
}

- (BOOL)setValue:(id)value forAttributeKey:(NSString *)attributeKey;
/*" Sets the specified attribute to the new value, or clears it if value is nil.  You can only 'set' values locally; this method ignore all the cascading and inheritence of the receiver.  An exception will be raised if the attribute key is not registered (unless the operation is to clear a unregistered value).  Also, the attribute is given a chance to validate the value and if that fails and exception will be raised.  Setting the value to nil removed any locally defined style. "*/
{
    OBPRECONDITION(self.editable, "We're not editable; there should be no UI for changing us");
    OBINVARIANT([self _checkInvariants]);
    
    if (!attributeKey) {
#if !defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE
        // If a OSStyleAttributeReference is created w/o a key...
        NSScriptCommand *command = [NSScriptCommand currentCommand];
        OBASSERT(command);
        [command setScriptErrorNumber:NSArgumentsWrongScriptError];
        [command setScriptErrorString:@"Attempt to set a style attribute value using a nil key"];
#endif
        return NO;
    }
    
    // Make sure this attribute is valid.
    OSStyleAttribute *attribute = [[_context attributeRegistry] attributeWithKey:attributeKey];
    if (value && !attribute)
        [NSException raise:NSInternalInconsistencyException format:NSLocalizedStringFromTableInBundle(@"Attempted to set value for an unregistered attribute key of '%@'", @"OmniStyle", OMNI_BUNDLE, "exception reason"), attributeKey];

    // Map the given value to something that is valid
    value = [attribute validValueForValue:value];

    // We do not allow styles to have redundant values (at least we try hard to avoid it).
    // This is important for infinite recursion avoidance in some cases where child styles are getting merged into parents (where we potentially have changes going up and down the style graph).
    id inheritedValue;
    
    OSStyle *associatedStyle;
    if ((associatedStyle = [self associatedStyleDefiningAttributeKey:attributeKey])) {
        inheritedValue = [associatedStyle localValueForAttributeKey:attributeKey];
        OBASSERT(inheritedValue);
    } else {
        inheritedValue = [[[_context attributeRegistry] attributeWithKey:attributeKey] defaultValue];
    }
    
    if (!_flags.allowsRedundantValues && OFISEQUAL(value, inheritedValue))
        value = nil; // i.e., remove the local value
    
    // Must check this after potentially changing the value of 'value'!
    id oldLocalValue = [_values objectForKey:attributeKey];
    if (OFISEQUAL(value, oldLocalValue))
        return NO;
    
    // Ok, we do have a unique value to set; let's make sure it's ok for us to set it.
    if (![self shouldSetValue:value forAttributeKey:attributeKey]) {
        return NO;
    }
    
    [self _setValue:value attributeKey:attributeKey];

    OBINVARIANT([self _checkInvariants]);

    return YES;
}

// Obviously this isn't good for unregistered attributes
- (id) valueForAttribute:(OSStyleAttribute *)attribute;
{
    return [self valueForAttributeKey:[attribute key]];
}

- (id) valueForAttributeKey:(NSString *) attributeKey;
{
    id        value;
    OSStyle  *definingStyle;
    definingStyle = [self styleDefiningAttributeKey:attributeKey];
    if (definingStyle) {
        value = [definingStyle localValueForAttributeKey:attributeKey];
        OBASSERT(value); // cause, you know, that's why we asked!
        return value;
    }

    return _defaultValueForAttributeKey(_context, attributeKey);
}

- (id) localValueForAttributeKey:(NSString *) attributeKey;
/*" This method should typically not be called directly unless you are inspecting styles since it ignores cascading and inheritence.  Returns the locally set value for the specified attribute, ignoring cascading, inheritence and default values. "*/
{
    if (!attributeKey) {
#if !defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE
        // If a OSStyleAttributeReference is created w/o a key...
        NSScriptCommand *command = [NSScriptCommand currentCommand];
        OBASSERT(command);
        [command setScriptErrorNumber:NSArgumentsWrongScriptError];
        [command setScriptErrorString:@"Attempt to get a style attribute value using a nil key"];
#endif
        return nil;
    }
    
    return [_values objectForKey:attributeKey];
}

- (id)valueForAttributeKey:(NSString *)attributeKey stoppingAtStyle:(OSStyle *)stopStyle;
{
    // This variant returns nil if there is no value found instead of the default.
    OSStyle *definingStyle = [self styleDefiningAttributeKey:attributeKey stoppingAtStyle:stopStyle];
    return [definingStyle localValueForAttributeKey:attributeKey];
}

- (OSStyle *)styleDefiningAttributeKey:(NSString *)attributeKey stoppingAtStyle:(OSStyle *)stopStyle;
{
    __block OSStyle *result = nil;
    [self iterateAssociatedStylesIncludingRoot:YES recursively:YES with:^OSStyleAssociatedStyleIterationResult(OSStyle *style) {
        if ([style localValueForAttributeKey:attributeKey]) {
            result = style;
            return OSStyleAssociatedStyleIterationStop;
        }
        if (style == stopStyle)
            return OSStyleAssociatedStyleIterationStop;

        return OSStyleAssociatedStyleIterationContinue;
    }];
    return result;
}

- (OSStyle *)_styleDefiningAttributeKey:(NSString *)attributeKey includeRoot:(BOOL)includeRoot;
{
    __block OSStyle *result = nil;
    [self iterateAssociatedStylesIncludingRoot:includeRoot recursively:YES with:^OSStyleAssociatedStyleIterationResult(OSStyle *style) {
        if ([style localValueForAttributeKey:attributeKey]) {
            result = style;
            return OSStyleAssociatedStyleIterationStop;
        }
        return OSStyleAssociatedStyleIterationContinue;
    }];
    return result;
}

- (OSStyle *)styleDefiningAttributeKey:(NSString *)attributeKey;
/*" Returns the style from which this style will determine the value for the given attribute name.  This could be itself if the value is locally defined, or it could be the cascade or one of the inherited styles.  If no style is found, then nil is returned, meaning that the default value will be used (accessible from the registered OSStyleAttribute). "*/
{
    return [self _styleDefiningAttributeKey:attributeKey includeRoot:YES];
}

- (OSStyle *)associatedStyleDefiningAttributeKey:(NSString *)attributeKey;
/*" The same as -styleDefiningAttributeKey:, except this method ignores the receiver, only returning associated styles. "*/
{
    return [self _styleDefiningAttributeKey:attributeKey includeRoot:NO];
}

- (BOOL)isEmpty;
/*" Returns YES if the style has no locally defined attribute keys (i.e., the style is completely boring). "*/
{
    return ![self hasLocallyDefinedAttributeKeys];
}

- (BOOL)hasLocallyDefinedAttributeKeys;
/*" Returns YES if any attribute keys are defined on the receiver. "*/
{
    return [_values count] > 0;
}

- (NSArray *)copyLocallyDefinedAttributeKeys;
/*" Returns a new retained array containing a list of all attribute names defined in this style. "*/
{
    if (!_values)
        return [emptyArray retain];
    return [_values copyKeys];
}

- (NSArray *)nonDefaultAttributeKeys;
/*" Returns a list of all the effective attributes at this style that differ from their default values. "*/
{
    NSMutableSet *nonDefaultKeys;

    nonDefaultKeys = [[NSMutableSet alloc] init];
    [self _buildEffectiveAttributeKeys:nonDefaultKeys];

    NSArray *keys = [nonDefaultKeys allObjects];
    [nonDefaultKeys release];
    return keys;
}

- (OFMutableKnownKeyDictionary *)copyEffectiveAttributeValues;
{
    return [self copyEffectiveAttributeValuesIncludingDefaultValues:YES];
}

- (OFMutableKnownKeyDictionary *)copyEffectiveAttributeValuesIncludingDefaultValues:(BOOL)includeDefaultValues;
/*" Returns a dictionary containing all the attributes effective at this style, taking into account inheritence, cascading and default values. "*/
{
    OSStyleAttributeRegistry *registry = [_context attributeRegistry];
    OFMutableKnownKeyDictionary *values = [registry newRegisteredValueDictionary];

    // Recursively get values from inherited/cascaded values
    [self _buildEffectiveAttributeValues:values];

    // Add in any missing default values
    if (includeDefaultValues)
        [values addLocallyAbsentValuesFromDictionary:[registry defaultValuesDictionary]];
    
    return values;
}

- (OSStyle *)newFlattenedStyle;
{
    // We do NOT use '[self class]' here currently since that would result in an OOCellStyle in OmniOutliner, which would lower performance of lookups (and the whole point of this method is to batch the lookups).  Actually, we'll use a special class that overrides a few methods to make sure lookups only look in _values
    OSStyle *style = [[_OSFlattenedStyle alloc] initWithContext:_context cascadeStyles:nil];

    OBASSERT(style->_values == nil); // Assert this is nil so that we can just replace it
    style->_values = [self copyEffectiveAttributeValuesIncludingDefaultValues:NO];
    return style;
}

- (OSStyleAssociatedStyleIterationTermination)iterateAssociatedStylesIncludingRoot:(BOOL)includeRoot
                                                                       recursively:(BOOL)recursively
                                                                              with:(OSStyleAssociatedStyleIterator)iterator;
/*" Iterates the associated styles in precedence order and calls the callback with each style in turn.  If 'recursively' is set, then the entire graph of associated styles is iterated in precedence order instead of just the locally associated styles (the callback should typically not do the recursion manually since that will prevent subclassers from doing filtering).  If the callback returns 'stop' then the iteration is stopped and the method as a whole returns 'stopped'.  "*/
{
    OSStyleAssociatedStyleIterationResult result;
    
    if (includeRoot) {
        result = iterator(self);
        if (result == OSStyleAssociatedStyleIterationStop)
            return OSStyleAssociatedStyleIterationStopped;
        if (result == OSStyleAssociatedStyleIterationPrune)
            return OSStyleAssociatedStyleIterationRanOut;
    }
    
#define PROCESS_STYLE(style) do { \
    OSStyle *__style = (style); \
    result = iterator(__style); \
    if (result == OSStyleAssociatedStyleIterationStop) \
        return OSStyleAssociatedStyleIterationStopped; \
    if (recursively && result != OSStyleAssociatedStyleIterationPrune) { \
        OSStyleAssociatedStyleIterationTermination recursionResult; \
        recursionResult = [__style iterateAssociatedStylesIncludingRoot:NO/*just did it above*/ \
                                                            recursively:recursively \
                                                                   with:iterator]; \
        if (recursionResult == OSStyleAssociatedStyleIterationStopped) \
            return OSStyleAssociatedStyleIterationStopped; \
    } \
} while(0)
    
    NSUInteger styleIndex;
        
    // Cascades, highest index is highest precedence
    styleIndex = [_cascadeStyles count];
    while (styleIndex--) {
        PROCESS_STYLE([_cascadeStyles objectAtIndex:styleIndex]);
    }
    
    return OSStyleAssociatedStyleIterationRanOut;
#undef PROCESS_STYLE
}

- (OSStyleAssociatedStyleIterationTermination)iterateStyles:(OSStyleAssociatedStyleIterator)iterator;
{
    return [self iterateAssociatedStylesIncludingRoot:YES recursively:YES with:iterator];
}

- (void)removeValuesForKeys:(NSArray *)keys;
{
    NSUInteger keyIndex;
    keyIndex = [keys count];
    while (keyIndex--)
        [self setValue:nil forAttributeKey:[keys objectAtIndex:keyIndex]];
}

- (void)removeRedundantValues;
/*" Removes any locally defined style values that are the same as what would be inherited or cascaded "*/
{
    OBINVARIANT([self _checkInvariants]);

    if (![self hasLocallyDefinedAttributeKeys])
        return;
    
    OFUndoManagerPushCallSite([self undoManagerIfUndoIsEnabled]);
    
    // Remove the values for the keys for which our value is the same as what we get from an associated style. OFMKKD specifically allows modifying the currently processing key while enumerating, but we want to remove them with the OSStyle API anyway, so we still collect them in an array first.
    OSStyleAttributeRegistry *registry = _context.attributeRegistry;
    __block NSMutableArray *keysToRemove = nil;
    
    [_values enumerateKeysAndObjectsUsingBlock:^(NSString *key, id value, BOOL *stop) {
        OSStyle *associatedStyle = [self associatedStyleDefiningAttributeKey:key];
        
        id associatedValue = nil;
        if (associatedStyle)
            associatedValue = [associatedStyle valueForAttributeKey:key];
        else {
            OSStyleAttribute *attribute = [registry attributeWithKey:key];
            if (attribute)
                associatedValue = [attribute defaultValue];
        }
        
        if (associatedValue && [associatedValue isEqual:value]) {
            if (!keysToRemove)
                keysToRemove = [[NSMutableArray alloc] init];
            [keysToRemove addObject:key];
        }
    }];

    if (keysToRemove) {
        [self removeValuesForKeys:keysToRemove];
        [keysToRemove release];
    }

    OFUndoManagerPopCallSite([self undoManagerIfUndoIsEnabled]);

    OBINVARIANT([self _checkInvariants]);
}

#pragma mark -
#pragma mark Caching of text attributes

- (NSDictionary *)textAttributes;
{
    OBPRECONDITION(_flags.inChange == 0); // Not sure if we want/need this
    if (_flags.inChange)
	return nil;
    
    NSDictionary *attributes;
    
    if (_flags.hasLocalCachedTextAttributes) {
        OBASSERT_NOTNULL(_textAttributeCache.cachedTextAttributes);
        attributes = _textAttributeCache.cachedTextAttributes;
    } else {
        OSStyle *styleForCaching = _textAttributeCache.styleForTextAttributeCache;
        if (!styleForCaching)
            styleForCaching = [self _styleForTextAttributeCaching];
        
        if (styleForCaching == self) {
            [self _ensureLocalCachedTextAttributes];
            attributes = _textAttributeCache.cachedTextAttributes;
        } else {
            [_textAttributeCache.styleForTextAttributeCache release];
            _textAttributeCache.styleForTextAttributeCache = [styleForCaching retain];
            attributes = [styleForCaching textAttributes];
        }
    }
    
    OBPOSTCONDITION([attributes isEqual:[OSStyledTextStorageCreateTextAttributes(self) autorelease]], "Text attribute cache should reflect the current state of the style");
    return attributes;
}

- (OSStyle *)_styleForTextAttributeCaching;
{
    // Local values?
    if ([_values count] > 0)
        return self;
    
    // If all the cascade styles lead back to some common style, we can use it.
    OSStyle *commonCacheStyle = nil;
    for (OSStyle *cascadeStyle in _cascadeStyles) {
        OSStyle *cascadeCache = [cascadeStyle _styleForTextAttributeCaching];
        OBASSERT(cascadeCache);
        
        if (!commonCacheStyle)
            commonCacheStyle = cascadeCache;
        else if (commonCacheStyle != cascadeCache)
            return self;
    }

    if (commonCacheStyle)
        return commonCacheStyle; // only one, or they all lead back to the same spot
    
    return self; // no cascades, so we are the bottom of the line.
}

- (void)_ensureLocalCachedTextAttributes;
{
    OBASSERT_NULL(_textAttributeCache.styleForTextAttributeCache, "Asked to cache local attributes for a style that believes itself to use another style's cache");
    
    [_textAttributeCache.cachedTextAttributes release]; // just in case...
    _textAttributeCache.cachedTextAttributes = OSStyledTextStorageCreateTextAttributes(self);
    _flags.hasLocalCachedTextAttributes = 1;
}

- (void)_resetTextAttributeCache;
{
    [_textAttributeCache.cachedTextAttributes release]; // Might be the styleForTextAttributeCache; both need -release when clearing
    _textAttributeCache.cachedTextAttributes = nil;
    _flags.hasLocalCachedTextAttributes = 0;
}

#pragma mark -
#pragma mark Listeners

- (void)addListener:(id <OSStyleListener>)listener;
/*" Adds the argument as a new listener for the receiving style.  It is an error for the same listener to be added twice.  This does not retain the listener, so the listener must remove itself before being deallocated. "*/
{
    OBPRECONDITION(!listener); // Check for nil will raise below
    OBINVARIANT([self _checkInvariants]);

    //NSLog(@"%@ add listener %@", [self shortDescription], [(id)listener shortDescription]);
    
    if (![listener conformsToProtocol:@protocol(OSStyleListener)])
        [NSException raise:NSInvalidArgumentException reason:NSLocalizedStringFromTableInBundle(@"Attempted to add a listener that doesn't conform to OSStyleListener.", @"OmniStyle", OMNI_BUNDLE, "exception reason")];

    if (!_listeners.single) {
        // This must not retain the listeners to avoid retain cycles.
        _listeners.single = listener;
    } else if (_flags.hasListenerArray == NO) {
        if (_listeners.single == listener)
            [NSException raise:NSInvalidArgumentException reason:NSLocalizedStringFromTableInBundle(@"Attempted to add a listener twice.", @"OmniStyle", OMNI_BUNDLE, "exception reason")];

        // Switch to an array with the existing listener and the new one. Have to add in pointer sorted order here to keep invariants true.
        id <OSStyleListener> listener1 = _listeners.single;
        id <OSStyleListener> listener2 = listener;
        
        // clang-sa can't figure out these both aren't nil. We got in this branch since _listeners.single is set and we got past the exception above if listener is nil (doesn't conform to the protocol), so listener isn't nil
        OBASSERT_NOTNULL(listener1);
        OBASSERT_NOTNULL(listener2);
        
        if (_compareByAddress(listener1, listener2, NULL) != kCFCompareLessThan)
            SWAP(listener1, listener2);
        
        NSMutableArray *listeners = (NSMutableArray *)OFCreateNonOwnedPointerArray();
        [listeners addObject:listener1];
        [listeners addObject:listener2];
        
        _listeners.multiple = listeners;
        _flags.hasListenerArray = YES;
    } else {
        CFMutableArrayRef multiple = (CFMutableArrayRef)_listeners.multiple; // Temporary variable to work around clang-sa crasher with passing union members <http://llvm.org/bugs/show_bug.cgi?id=12004>
        OBASSERT([(id)multiple isKindOfClass:[NSArray class]]);
        
        CFRange range = (CFRange){0, CFArrayGetCount(multiple)};
        CFIndex index = CFArrayBSearchValues(multiple, range, listener, _compareByAddress, NULL);
        if (index < range.length && (CFArrayGetValueAtIndex(multiple, index) == listener))
            [NSException raise:NSInvalidArgumentException reason:NSLocalizedStringFromTableInBundle(@"Attempted to add a listener twice.", @"OmniStyle", OMNI_BUNDLE, "exception reason")];
        CFArrayInsertValueAtIndex(multiple, index, listener);
    }
    
    OBINVARIANT([self _checkInvariants]);
}

- (void)removeListener:(id <OSStyleListener>)listener;
/*" Adds the argument as a new listener for the receiving style.  It is an error to remove a listener that wasn't subscribed. "*/
{
    OBPRECONDITION(!listener); // Use -setOwner:containerKey: instead.  Check for nil will raise below
    
    // Fixing this is hard since we need to make sure all styles are deallocated before the containing document's OSStyleContext is invalidated.
    OBINVARIANT([_context isInvalidated] || [self _checkInvariants]);

    //NSLog(@"%@ remove listener %p", [self shortDescription], listener);

    if (!listener)
        [NSException raise:NSInvalidArgumentException reason:NSLocalizedStringFromTableInBundle(@"Attempted to remove a nil listener.", @"OmniStyle", OMNI_BUNDLE, "exception reason")];

    if (!_listeners.single)
        [NSException raise:NSInvalidArgumentException format:NSLocalizedStringFromTableInBundle(@"Attempted to remove a listener (%@) that hadn't been added to the style (%@).", @"OmniStyle", OMNI_BUNDLE, "exception reason"), OBShortObjectDescription(listener), [self shortDescription]];

    if (_flags.hasListenerArray == NO) {
        // Just one (non-retained) listener
        if (_listeners.single == listener) {
            _listeners.single = nil;
        } else {
            [NSException raise:NSInvalidArgumentException format:NSLocalizedStringFromTableInBundle(@"Attempted to remove a listener (%@) that hadn't been added to the style (%@).", @"OmniStyle", OMNI_BUNDLE, "exception reason"), OBShortObjectDescription(listener), [self shortDescription]];
        }
    } else {
        CFMutableArrayRef multiple = (CFMutableArrayRef)_listeners.multiple; // Temporary variable to work around clang-sa crasher with passing union members <http://llvm.org/bugs/show_bug.cgi?id=12004>
        OBASSERT([(id)multiple isKindOfClass:[NSArray class]]);
        
        CFRange range = (CFRange){0, CFArrayGetCount(multiple)};
        CFIndex index = CFArrayBSearchValues(multiple, range, listener, _compareByAddress, NULL);
        if (index >= range.length || (CFArrayGetValueAtIndex(multiple, index) != listener))
            [NSException raise:NSInvalidArgumentException format:NSLocalizedStringFromTableInBundle(@"Attempted to remove a listener (%@) that hadn't been added to the style (%@).", @"OmniStyle", OMNI_BUNDLE, "exception reason"), OBShortObjectDescription(listener), [self shortDescription]];
        
        CFArrayRemoveValueAtIndex(multiple, index);
        if (CFArrayGetCount(multiple) == 1) {
            // Down to one listener. Drop the array.
            id listener = (id)CFArrayGetValueAtIndex(multiple, 0);
            CFRelease(multiple);
            _listeners.single = listener;
            _flags.hasListenerArray = NO;
        }
    }


    // Fixing this is hard since we need to make sure all styles are deallocated before the containing document's OSStyleContext is invalidated.
    OBINVARIANT([_context isInvalidated] || [self _checkInvariants]);
}

- (BOOL)_isListenerAReferencingListener:(id <OSStyleListener>)listener;
{
    if ([listener isKindOfClass:[OSStyle class]])
        return YES;
    else
        return NO;
}

- (BOOL)isReferenced;
{
    if (_flags.hasListenerArray) {
        for (id  <OSStyleListener> listener in _listeners.multiple) {
            if ([self _isListenerAReferencingListener:listener])
                return YES;
        }
        return NO;
    } else {
        id  <OSStyleListener> listener = _listeners.single;
        return [self _isListenerAReferencingListener:listener];
    }
}

/*" Returns the number of calls to -disableChangeNotifications that would be necessary to cause change notifications to be reenabled.  This method should only be used for debugging purposes. "*/
- (NSUInteger)changeNotificationDisableCount;
{
    return _flags.changeNotificationDisableCount;
}

/*" Disables OSStyleListener change notifications.  Any notifications that would have been generated are lost (not suspended -- completely discarded) until a matching call to -enableChangeNotifications is made "*/
- (void)disableChangeNotifications;
{
#ifdef OMNI_ASSERTIONS_ON
    NSUInteger oldDisableCount = _flags.changeNotificationDisableCount;
#endif
    _flags.changeNotificationDisableCount++;
    OBASSERT(_flags.changeNotificationDisableCount > oldDisableCount); // Somewhat narrow bitfield; watch out for overflow
}

/*" Counteracts the effects of one call to -disableChangeNotifications.  If one or more calls to -disableChangeNotifications are still in effect after this, change notifications are still disabled. "*/
- (void)enableChangeNotifications;
{
    OBPRECONDITION(_flags.changeNotificationDisableCount > 0);
    if (_flags.changeNotificationDisableCount > 0)
        _flags.changeNotificationDisableCount--;
}

#pragma mark -
#pragma mark OSStyleListener

- (void)style:(OSStyle *)style willChange:(OSStyleChangeInfo)changeInfo;
{
    OBASSERT_NOT_REACHED("We should only hit the _style:willChange: internal method");
}

- (void)style:(OSStyle *)style didChange:(OSStyleChange *)change;
{
    OBASSERT_NOT_REACHED("We should only hit the _style:didChange: internal method");
}

#pragma mark - Archiving

+ (NSString *)xmlElementName;
{
    return OSStyleXMLElemementName;
}

- (void)appendXML:(OFXMLDocument *)doc;
{
    OBINVARIANT([self _checkInvariants]);

    [doc pushElement:[[self class] xmlElementName]];
    {
        OSStyleAttributeRegistry *registry = [_context attributeRegistry];
        NSArray *localKeys = [self copyLocallyDefinedAttributeKeys];
        NSUInteger keyIndex, keyCount;
        if ((keyCount = [localKeys count])) {
            NSMutableArray *sortedKeys = [[NSMutableArray alloc] initWithArray:localKeys];
            [sortedKeys sortUsingSelector:@selector(compare:)];

            for (keyIndex = 0; keyIndex < keyCount; keyIndex++) {
                NSString *key = [sortedKeys objectAtIndex:keyIndex];
                OSStyleAttribute *attribute = [registry attributeWithKey:key];
                if ([attribute internal])
                    continue;
                
                id value = [self valueForAttributeKey:key];
                OBASSERT(value);
                
                [doc pushElement:OSStyleAttributeValueXMLElemementName]; {
                    [doc setAttribute:OSStyleAttributeKeyXMLAttributeName value:key];
                    [attribute appendXML:doc forValue:value];
                } [doc popElement];
            }

            [sortedKeys release];
        }
        [localKeys release];
    }
    [doc popElement];

    OBINVARIANT([self _checkInvariants]);
}

- initFromXML:(OFXMLCursor *)cursor context:(OSStyleContext *)context cascadeStyles:(NSArray *)cascadeStyles; 
{
    return [self initFromXML:cursor context:context cascadeStyles:cascadeStyles allowRedundantValues:NO referencedAttributes:nil];
}

- initFromXML:(OFXMLCursor *)cursor context:(OSStyleContext *)context cascadeStyles:(NSArray *)cascadeStyles allowRedundantValues:(BOOL)allowRedundantValues referencedAttributes:(NSMutableSet *)referencedAttributes;
{
    if (!(self = [self initWithContext:context cascadeStyles:cascadeStyles]))
        return nil; // GCOV IGNORE

    [self setAllowsRedundantValues:allowRedundantValues];
    
    NSString *xmlElementName = [[self class] xmlElementName]; // since we might get deallocated!
    if (![[cursor name] isEqualToString:xmlElementName]) {
        [self release];
        [NSException raise:NSInvalidArgumentException format:NSLocalizedStringFromTableInBundle(@"Expected a '%@' element in the cursor, but got '%@' (path = '%@')", @"OmniStyle", OMNI_BUNDLE, "exception reason"), xmlElementName, [cursor name], [cursor currentPath]];
    }

    OSStyleAttributeRegistry *registry = [_context attributeRegistry];
    OFXMLElement *child;
    
    [self disableChangeNotifications];
    registry.initializingFromXML = YES;
    
    while ((child = [cursor nextChild])) {
        if (![child isKindOfClass:[OFXMLElement class]])
            continue;

        if ([[child name] isEqualToString:OSStyleAttributeValueXMLElemementName]) {
            NSString         *key;
            OSStyleAttribute *attribute;
            id                value;
            
            key = [child attributeNamed:OSStyleAttributeKeyXMLAttributeName];
            attribute = [registry attributeWithKey:key];
            if (attribute) {
                key = attribute.key; // get uniqued key
                [cursor openElement]; {
                    value = [attribute copyValueFromXML:cursor];
                    OBASSERT(value);
                    if (value) {
                        if (!_values)
                            _values = [[_context attributeRegistry] newRegisteredValueDictionary];
                        [_values setObject:value forKey:key];
                        [value release];

                        [referencedAttributes addObject:attribute]; // We do this even if the value ends up being redundant
                    }
                } [cursor closeElement];
            } else {
                // Unrecognized attribute
                // TODO: Add support on OFXMLDocument for logging reading errors
                NSLog(@"Unrecognized style attribute key '%@'", key);
            }
            continue;
        }

        // Ignore any other crud
    }

    registry.initializingFromXML = NO;
    [self enableChangeNotifications];
    
    OBINVARIANT([self _checkInvariants]);
    
    return self;
}

#pragma mark -
#pragma mark Debugging

- (NSString *)shortDescription;
{
    return [NSString stringWithFormat:@"<%@:%p>", [self class], self];
}

#define addArrayValues(dictionary,array,key) do {\
if ([array count] > 0) \
[dictionary setObject:[array arrayByPerformingSelector:_cmd] forKey:key]; \
} while (0)

- (NSMutableDictionary *)debugDictionary;
{
    NSMutableDictionary *dict = [super debugDictionary];
    
    if (_values)
        [dict setObject:[[_values copy] autorelease] forKey:@"_values"];
    
    addArrayValues(dict, _cascadeStyles, @"_cascadeStyles");
    
    return dict;
}

#ifdef DEBUG

static void _printListeners(OSStyle *style, NSUInteger indent);

static void _printListener(id <NSObject> listener, NSUInteger indent)
{
    if ([listener isKindOfClass:[OSStyle class]])
        _printListeners((OSStyle *)listener, indent);
    else {
        for (NSUInteger indexIndex = 0; indexIndex < indent; indexIndex++)
            fputs("  ", stderr);
        fprintf(stderr, "<%s:%p>\n", class_getName([listener class]), listener);
    }
}

static void _printListeners(OSStyle *style, NSUInteger indent)
{
    NSUInteger indexIndex;
    for (indexIndex = 0; indexIndex < indent; indexIndex++)
        fputs("  ", stderr);
    fprintf(stderr, "<%s:%p", class_getName([style class]), style);
    fputs(">\n", stderr);

    indent++;

    OSStyleForEachListener(style, ^(id <OSStyleListener, OSStyleListenerInternal> listener){
        _printListener(listener, indent);
    });    
}

- (void)printListenerTree;
{
    _printListeners(self, 0);
}
#endif

#ifdef OMNI_ASSERTIONS_ON

- (BOOL) _checkInvariants;
{
    // See the comments in the class header on these invariants.

    // Must have a context
    OBINVARIANT(_context);
    // ... that hasn't been invalidated
    OBINVARIANT(![_context isInvalidated]);
    
    // Check that our listener state is consistent.
    if (_flags.hasListenerArray) {
        OBINVARIANT([_listeners.multiple isKindOfClass:[NSArray class]]);
        
        NSUInteger listenerCount = [_listeners.multiple count];
        OBINVARIANT(listenerCount > 1); // should fall back to single otherwise
        
        // Listeners should be sorted by pointer.
        for (NSUInteger listenerIndex = 0; listenerIndex < listenerCount - 1; listenerIndex++) {
            id <OSStyleListener> listener1 = [_listeners.multiple objectAtIndex:listenerIndex + 0];
            id <OSStyleListener> listener2 = [_listeners.multiple objectAtIndex:listenerIndex + 1];
            OBINVARIANT(_compareByAddress(listener1, listener2, NULL) == kCFCompareLessThan);
        }
    } else {
        if (_listeners.single) {
            OBINVARIANT([_listeners.single conformsToProtocol:@protocol(OSStyleListener)]);
        }
    }
    
    OSStyleAttributeRegistry *registry = [_context attributeRegistry];
    OBINVARIANT(registry);
    
    // Associated styles must have the same registry
    NSUInteger styleIndex = [_cascadeStyles count];
    while (styleIndex--) {
        OBINVARIANT([[_cascadeStyles objectAtIndex:styleIndex] registry] == registry);
    }
        
    // Every entry in the registered attribute dictionary must contain a valid value
    [_values enumerateKeysAndObjectsUsingBlock:^(NSString *key, id value, BOOL *stop) {
        OSStyleAttribute *attr = [registry attributeWithKey:key];
        OBINVARIANT(attr);
        OBINVARIANT(value);
        OBINVARIANT(value == [attr validValueForValue:value]);
    }];
    
    // If undo is enabled for this style, our related styles must also have undo enabled.  It's OK for a style with undo not yet enabled to reference style with undo enabled (see -_validateStyleForAssociation:)
    if (_flags.undoEnabled) {
        styleIndex = [_cascadeStyles count];
        while (styleIndex--) {
            OBINVARIANT([[_cascadeStyles objectAtIndex:styleIndex] isUndoEnabled]);
        }
    }

    return YES;
}
#endif

#pragma mark - Subclasses

// Note that we have to be careful about subscribe/unsubscribe requests while we are notifying.  For now we'll copy the subscription list before notifying.  This means that if you unsubscribe someone else, they may still get notified during this notification.
void OSStyleForEachListener(OSStyle *self, void (^action)(id <OSStyleListener, OSStyleListenerInternal>))
{
    if (self->_listeners.single == nil)
        return;
    
    if (self->_flags.hasListenerArray == NO) {
        // Just one listener. There is no worry here about adding/removing invalidating our array since we only have one slot to look at.
        // This is by far the most common case.
        OBASSERT([self->_listeners.single conformsToProtocol:@protocol(OSStyleListenerInternal)]);
        action((id <OSStyleListener, OSStyleListenerInternal>)self->_listeners.single);
        return;
    }
    
    OBASSERT([self->_listeners.multiple isKindOfClass:[NSArray class]]);
    NSArray *listeners = [[NSArray alloc] initWithArray:self->_listeners.multiple];
    @try {
        for (id <OSStyleListener, OSStyleListenerInternal> listener in listeners)
            action(listener);
    } @finally {
        [listeners release];
    }
}

static CFArrayRef CreateListenerDependencyOrderedTraversalStartingWithStyle(OSStyle *self, OSStyleChangeContext *ctx)
{
    CFMutableArrayRef orderedListeners = CFArrayCreateMutable(kCFAllocatorDefault, 0, &OFPointerEqualObjectArrayCallbacks);

    // Recursively add listener dependency counts
    [self _style:self prepareForChange:ctx];

    // Clear the bogus count added for the instigator
    OFCFDictionarySetUIntegerValue(ctx->listenerDependencyCount, self, 0);
    
    NSUInteger orderedListenerCount = 0;
    NSUInteger batchStartIndex = 0;

    while (CFDictionaryGetCount(ctx->listenerDependencyCount) > 0) {
#if DEBUG_STYLE_EDIT_DEFINED
        DEBUG_STYLE_EDIT(@"making a pass:");
#endif
        for (OSStyle *style in (NSDictionary *)ctx->listenerDependencyCount) {
            NSUInteger count = 0;
            if (!OFCFDictionaryGetUIntegerValueIfPresent(ctx->listenerDependencyCount, style, &count))
                OBASSERT_NOT_REACHED("Count must be present");
            
            DEBUG_STYLE_EDIT(@"  %lu <-- %@", count, [style shortDescription]);
            
            if (count == 0) {
                CFArrayAppendValue(orderedListeners, style);
            }
        }
        
        orderedListenerCount = CFArrayGetCount(orderedListeners);
        if (orderedListenerCount > batchStartIndex) {
            // Remove all these styles and tell them to decrement their listeners
            while (batchStartIndex < orderedListenerCount) {
                NSObject <OSStyleListenerInternal> *listener = (NSObject <OSStyleListenerInternal> *)CFArrayGetValueAtIndex(orderedListeners, batchStartIndex);
                CFDictionaryRemoveValue(ctx->listenerDependencyCount, listener);
                [listener _addedToOrderedListenerTraversal:ctx];
                batchStartIndex++;
            }
        } else {
            // Die rather than looping forever so we can fix the bug... though maybe we could have a 'minCount' argument we bump each time this happens to get an answer, and then just assert
            [NSException raise:NSInternalInconsistencyException reason:@"No listeners with zero unhandled dependencies"];
        }
    }

    return orderedListeners;
}

- (void)performChange:(OSStyleChangeInfo)changeInfo withAction:(void (^)(void))action;
{
    // We *don't* currently check invariants on entrance to this method since this method is used to restore the invariant of named styles being in precedence sorted order. See -namedStylesPrecedenceChanged.
    //OBINVARIANT([self _checkInvariants]);
    
    if (_flags.changeNotificationDisableCount > 0) {
        // We've been told to be quiet.
        action();
        OBINVARIANT([self _checkInvariants]);
        return;
    }
    
    DEBUG_STYLE_EDIT(@"Perform change %ld on %@ %@", changeInfo, [self shortDescription], [_nonretained_owner shortDescription]);
    
    if (_flags.inChange) // This change is being made in response to some higher level instigating change. The higher level change will deal with sending out notifications.
    {
        DEBUG_STYLE_EDIT(@"  ... already in change, just performing it");
        action();
        OBINVARIANT([self _checkInvariants]);
        return;
    }
        
    /*
     In OmniOutliner, we have a diamond cascade pattern: The Whole Document style is a cascade for column styles and for row styles. Cells cascade from their row and column.
     We want to ensure that no 'did' callbacks are sent to any listeners until every style touched by the change is done dealing with it. Otherwise, asking for the cached text attributes, or whatnot, can yield incorrect results.
     At this point, we are the top level instigator of the change.
     We also want to ensure that we send the 'will' notifications top-down (the instigating style goes first) and the 'did' bottom up (in the exact reverse order of the 'will' methods). This will let clients optimize their response to higher level styles. For example, OmniOutliner for iPad notices that the Whole Document style is changing and ignores changes to row/cell styles until it gets the top-level 'did' and then rebuilds all its rows, rather than doing them one by one.
     We only make the ordering guarantee for non-OSStyle listeners. The OSStyle listeners get notified via an internal mechanism and should not subclass the -style:willChange: and -style:didChange: methods at all.
     */
    
    
    // This should be a top-level change.
    OBASSERT((changeInfo & OSStyleChangeScopeMask) == OSStyleChangeScopeLocal);

    OSStyleChangeContext ctx = {0};
    ctx.instigatingStyle = self;
    ctx.changeInfo = changeInfo;
    ctx.listenerDependencyCount = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &OFNonOwnedPointerDictionaryKeyCallbacks, &OFIntegerDictionaryValueCallbacks);
    ctx.styleToChange = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &OFPointerEqualObjectDictionaryKeyCallbacks, &OFNSObjectDictionaryValueCallbacks);
    ctx.orderedListeners = CreateListenerDependencyOrderedTraversalStartingWithStyle(self, &ctx);
        
    CFRelease(ctx.listenerDependencyCount); // Only used in setup
    ctx.listenerDependencyCount = NULL;
    
    @try {
        // Send -style:willChange: in the proper order. Only non-style listeners will do anything with this.
        for (NSObject <OSStyleListenerInternal> *listener in (NSArray *)ctx.orderedListeners)
            [listener _sendWillToNonStyleListeners:&ctx];

        // Perform the action
        action();
                
        // Finalize the changes across the whole style tree in breadth first traversal order. Only OSStyles will do something in response to this.
        for (NSObject <OSStyleListenerInternal> *listener in (NSArray *)ctx.orderedListeners)
            [listener _finalizeChange:&ctx];
        
        // Now that the entire style graph is done changing, notify all the non-style listeners. Notify them in the reverse order that 'will' was sent, as noted above. Well, the order is reverse enough for our needs -- if two styles B and C cascade from A, then if a listener is observing all three, the 'did' for A will definitely be sent last, but the order of B and C is not defined.
        NSUInteger listenerIndex = CFArrayGetCount(ctx.orderedListeners);
        while (listenerIndex--) {
            NSObject <OSStyleListenerInternal> *listener = (NSObject <OSStyleListenerInternal> *)CFArrayGetValueAtIndex(ctx.orderedListeners, listenerIndex);
            [listener _sendDidToNonStyleListeners:&ctx];
        }
            
#ifdef STYLE_STATS
        // Every single live style should be outside of a change (well, in simple cases)
        {
            NSUInteger styleIndex = CFArrayGetCount(_allStyles);
            while (styleIndex--) {
                OSStyle *style = CFArrayGetValueAtIndex((CFArrayRef)_allStyles, styleIndex);
                OBASSERT(style->_flags.inChange == NO);
            }
        }
#endif
    } @finally {
#ifdef OMNI_ASSERTIONS_ON
        for (NSObject <OSStyleListenerInternal> *listener in (NSArray *)ctx.orderedListeners) {
            if ([listener isKindOfClass:[OSStyle class]]) {
                OSStyle *style = (OSStyle *)listener;
                OBASSERT(style->_flags.inChange == NO);
            }
        }
#endif
        CFRelease(ctx.orderedListeners);
        CFRelease(ctx.styleToChange);
    }
    
    OBINVARIANT([self _checkInvariants]);
}

#pragma mark - OSStyleListenerInternal

static void _incrementCount(OSStyle *self, CFMutableDictionaryRef counts, id listener)
{
    NSUInteger count = 0;
    OFCFDictionaryGetUIntegerValueIfPresent(counts, listener, &count);
    count++;
    OFCFDictionarySetUIntegerValue(counts, listener, count);
    DEBUG_STYLE_EDIT(@"inc to %lu <-- %@", count, [listener shortDescription]);
}

static void _decrementCount(OSStyle *self, CFMutableDictionaryRef counts, id listener)
{
    NSUInteger count = 0;
    if (!OFCFDictionaryGetUIntegerValueIfPresent(counts, listener, &count))
        [NSException raise:NSInternalInconsistencyException format:@"Dependency count is missing for listener %@", [listener shortDescription]];
    if (count == 0)
        [NSException raise:NSInternalInconsistencyException format:@"Dependency count is zero for listener %@", [listener shortDescription]];
    count--;
    OFCFDictionarySetUIntegerValue(counts, listener, count);
    DEBUG_STYLE_EDIT(@"dec to %lu <-- %@", count, [listener shortDescription]);
}

- (void)_style:(OSStyle *)style prepareForChange:(OSStyleChangeContext *)ctx;
{
    DEBUG_STYLE_EDIT(@"_style:prepareForChange:");

    OBPRECONDITION(_flags.changeNotificationDisableCount == 0); // Style with change notifications disabled cascading from one with them enabled?
    
    if (_flags.inChange) {
        // Diamond cascade. We've already been added
        DEBUG_STYLE_EDIT(@"  bail -- already in change");
        return;
    }
    _flags.inChange = YES;
    
    // Only invalidate the cached text attributes if we got a meaningful style attribute change.
    OSStyleChangeKind changeKind = ctx->changeInfo & OSStyleChangeKindMask;
    if (changeKind != OSStyleChangeKindName) {
        [self _resetTextAttributeCache];
    }
    
    // Rest of this is only applicable if we have listeners.
    if (_listenerCount(self) > 0) {
        // Build a place to capture the eventual change for the listeners of this style.
        OSStyleChange *change = [(OSStyleChange *)[OSStyleChange alloc] initWithStyle:self];
        CFDictionarySetValue(ctx->styleToChange, self, change);
        [change release];
        
        // Increment dependency counts on our listeners and recurse
        OSStyleForEachListener(self, ^(id <OSStyleListener, OSStyleListenerInternal> listener){
            _incrementCount(self, ctx->listenerDependencyCount, listener);
            [listener _style:style prepareForChange:ctx];
        });
    }
}

- (void)_addedToOrderedListenerTraversal:(OSStyleChangeContext *)ctx;
{
    // Remove the dependency our listeners had on us.
    OSStyleForEachListener(self, ^(id <OSStyleListener, OSStyleListenerInternal> listener){
        _decrementCount(self, ctx->listenerDependencyCount, listener);
    });
}

- (void)_sendWillToNonStyleListeners:(OSStyleChangeContext *)ctx;
{
    OSStyleForEachListener(self, ^(id <OSStyleListener, OSStyleListenerInternal> listener){
        [listener _style:self willChange:ctx];
    });
}

- (void)_sendDidToNonStyleListeners:(OSStyleChangeContext *)ctx;
{
    OSStyleForEachListener(self, ^(id <OSStyleListener, OSStyleListenerInternal> listener){
        [listener _style:self didChange:ctx];
    });
}

- (void)_finalizeChange:(OSStyleChangeContext *)ctx;
{
    DEBUG_STYLE_EDIT(@"  _finalizeChange:%@ %@", [self shortDescription], [_nonretained_owner shortDescription]);
    
    // Clean up now-redundant local attributes. We may have add a new cascade or inherited style added or removed somewhere up the tree that makes our local attributes not relevant.
    if (_flags.allowsRedundantValues == 0) {
        OSStyleAttributeRegistry *registry = _context.attributeRegistry;

        [_values enumerateKeysAndObjectsUsingBlock:^(NSString *key, id value, BOOL *stop) {
            OSStyle *associatedStyle = [self associatedStyleDefiningAttributeKey:key];
            id associatedValue = [associatedStyle valueForAttributeKey:key];
            if (!associatedValue)
                associatedValue = [[registry attributeWithKey:key] defaultValue];

            if (associatedValue && [associatedValue isEqual:value]) {
                // OFMKKD specifically allows key modifications on the current key while enumerating
                [_values removeObjectForKey:key];
            }
        }];
    }
    
    if (_flags.changeNotificationDisableCount > 0) {
        DEBUG_STYLE_EDIT(@"    ... change notifications disabled, bailing");
        OBASSERT_NOT_REACHED("Really, the 'will' path shouldn't have let us get in the tranversal.");
        OBASSERT(_flags.inChange == 0);
        OBASSERT(CFDictionaryGetValue(ctx->styleToChange, self) == NULL);
        return;
    }
    
    if (_flags.inChange == 0) {
        // Some other path in a diamond cascade finished us.
        DEBUG_STYLE_EDIT(@"    ... already hit, bailing");
        return;
    }
    _flags.inChange = NO;
    
    // Our caches should NOT have been repopulated while we were still in a change since only part of the change might have been processed, making the cached half-baked (though our listeners might ask for them to be populated when we alert them below).

    if (_listenerCount(self) > 0) {
        OSStyleChange *change = (OSStyleChange *)CFDictionaryGetValue(ctx->styleToChange, self);
        OBASSERT(change);
        
        // Computes the delta information
        [change finalizeChange];
        DEBUG_STYLE_EDIT(@"  finalize change for style %@: %@", [self shortDescription], [change debugDictionary]);
        
        // The top level tranversal will inform any other styles cascading/inheriting from us and other listeners
    } else {
        OBASSERT(CFDictionaryGetValue(ctx->styleToChange, self) == NULL);
    }
}

- (void)_style:(OSStyle *)style willChange:(OSStyleChangeContext *)ctx;
{
    // Nothing -- this is for non-OSStyle listeners to be notified
}
- (void)_style:(OSStyle *)style didChange:(OSStyleChangeContext *)ctx;
{
    // Nothing for OSStyle -- this is for the non-style listeners
}

#pragma mark - Private

- (BOOL)_validateStyleForAssociation:(OSStyle *)style error:(NSError **)outError;
{
    return _validateForAssociatingStyles(self, style, outError);
}

- (BOOL)_validateStyleForCascading:(OSStyle *)style error:(NSError **)outError;
{
    if (![self _validateStyleForAssociation:style error:outError]) {
        return NO;
    }

    return YES;
}

- (void)_setValue:(id)value attributeKey:(NSString *)attributeKey;
/*" This is called after validation has occurred and is the point of undo management for setting values. "*/
{
    OBINVARIANT([self _checkInvariants]);

    id oldLocalValue = [_values objectForKey:attributeKey];
    OBASSERT(!OFISEQUAL(value, oldLocalValue), "We're not expecting anyone to call us with an unchanged value - it won't actively hurt anything, but will result in a pointless undo event being registered");

    [self performChange:OSStyleChangeKindAttribute withAction:^{
        [oldLocalValue retain]; // The penalty for leak is less then the penalty for too many autoreleases

        if (value) {
            if (!_values)
                _values = [[_context attributeRegistry] newRegisteredValueDictionary];
            DEBUG_STYLE_EDIT(@"Style %p (owner %@) set key %@ to %@", self, [_nonretained_owner shortDescription], attributeKey, [value shortDescription]);
            [_values setObject:value forKey:attributeKey];
        } else {
            // Release _values if it is empty here?  Probably not for now.
            DEBUG_STYLE_EDIT(@"Style %p (owner %@) remove key %@", self, [_nonretained_owner shortDescription], attributeKey);
            [_values removeObjectForKey:attributeKey];
        }

        // We have to log this unto before the did-change notification.  The issue is that the change notification may look at our values, and do something else to us that might log an undo.  If it does, then its undo would get registered first (and executed last).
	// Note that we do NOT discard duplicate values when undoing since we may temporarily be in a 'duplicate-value' state if there are multiple undo events effecting a style graph.
        [[[self undoManagerIfUndoIsEnabled] prepareWithInvocationTarget:self] _setValue:oldLocalValue attributeKey:attributeKey];
        [oldLocalValue release];
    }];

    OBINVARIANT([self _checkInvariants]);
}

- (void)_buildEffectiveAttributeKeys:(NSMutableSet *)keys;
{
    [self iterateAssociatedStylesIncludingRoot:YES recursively:YES with:^OSStyleAssociatedStyleIterationResult(OSStyle *style) {
        [style->_values enumerateKeysAndObjectsUsingBlock:^(NSString *key, id value, BOOL *stop) {
            if (![keys member:key])
                [keys addObject:key];
        }];
        return OSStyleAssociatedStyleIterationContinue;
    }];
}

- (void)_buildEffectiveAttributeValues:(OFMutableKnownKeyDictionary *)values;
{
    [self iterateAssociatedStylesIncludingRoot:YES recursively:YES with:^OSStyleAssociatedStyleIterationResult(OSStyle *style) {
        if (style->_values)
            [values addLocallyAbsentValuesFromDictionary:(OFMutableKnownKeyDictionary *)style->_values];
        return OSStyleAssociatedStyleIterationContinue;
    }];
}

@end


@implementation NSObject (OSStyleListenerInternal)

#pragma mark - OSStyleListenerInternal

- (void)_style:(OSStyle *)style prepareForChange:(OSStyleChangeContext *)ctx;
{
    // We are a non-style listener -- nothing to do.
}

- (void)_addedToOrderedListenerTraversal:(OSStyleChangeContext *)ctx;
{
    // We are a plain OSStyleListener and don't incure a dependency on anything else.
}

- (void)_finalizeChange:(OSStyleChangeContext *)ctx;
{
    // Only for OSStyles.
}

- (void)_sendWillToNonStyleListeners:(OSStyleChangeContext *)ctx;
{
    // We aren't a style -- any styles we are listening to will deal with this
}

- (void)_sendDidToNonStyleListeners:(OSStyleChangeContext *)ctx;
{
    // We aren't a style -- any styles we are listening to will deal with this
}

- (void)_style:(OSStyle *)style willChange:(OSStyleChangeContext *)ctx;
{
    // Bridge from our internal API to the public listener API
    OBPRECONDITION([self conformsToProtocol:@protocol(OSStyleListener)]);
    
    DEBUG_STYLE_EDIT(@"  sending 'will' to %@ for %@", [self shortDescription], [style shortDescription]);

    // The style change should have been registered by the style.
    OBASSERT(CFDictionaryGetValue(ctx->styleToChange, style) != NULL);
    
    // Recorded info should be local; mix in the proper scope
    OBASSERT((ctx->changeInfo & OSStyleChangeScopeMask) == OSStyleChangeScopeLocal);
    
    OSStyleChangeScope scope;
    if (ctx->instigatingStyle == style)
        scope = OSStyleChangeScopeLocal;
    else
        scope = OSStyleChangeScopeCascade;
    
    [(id <OSStyleListener>)self style:style willChange:(ctx->changeInfo|scope)];
}

- (void)_style:(OSStyle *)style didChange:(OSStyleChangeContext *)ctx;
{
    // Bridge from our internal API to the public listener API
    OBPRECONDITION([self conformsToProtocol:@protocol(OSStyleListener)]);

    OSStyleChange *change = (OSStyleChange *)CFDictionaryGetValue(ctx->styleToChange, style);
    OBASSERT(change);
    
    DEBUG_STYLE_EDIT(@"  sending 'did' to %@ for %@", [(id)self shortDescription], [style shortDescription]);
    
    // OSStyle will do nothing with this, so only normal listeners will be informed
    [(id <OSStyleListener>)self style:style didChange:change];
}

@end

