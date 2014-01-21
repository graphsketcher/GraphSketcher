// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/OmniStyle/Basic/OSStyle.h 200244 2013-12-10 00:11:55Z correia $

#import <OmniFoundation/OFObject.h>

#import "OSStyleListener.h"
#import <OmniBase/assertions.h>

#if !defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE
#import <AppKit/NSDragging.h> // For NSDragOperation
#import <OmniFoundation/OFAddScriptCommand.h>
#endif

extern BOOL OAFontDescriptorIsInterestedInStyleAttributeKey(NSString *key);

@class NSArray, NSMutableArray, NSMutableSet, NSPredicate, NSSet, NSUndoManager;
@class NSParagraphStyle, NSMutableParagraphStyle, NSLayoutManager, NSColor;
@class OFMutableKnownKeyDictionary, OFXMLCursor, OFXMLDocument;

@class OAFontDescriptor;
@class OSStyleAttribute, OSStyleAttributeReference, OSStyleAttributeRegistry, OSStyleContext;

@class OSBoolStyleAttribute, OSColorStyleAttribute, OSEnumStyleAttribute, OSNumberStyleAttribute, OSVectorStyleAttribute, OSStringStyleAttribute, OSURLStyleAttribute;

typedef enum _OSStyleAssociatedStyleIterationResult {
    OSStyleAssociatedStyleIterationContinue, // Continue processing as normal
    OSStyleAssociatedStyleIterationPrune,    // Conitnue, but don't decend into associated styles of the passed style
    OSStyleAssociatedStyleIterationStop,     // Stop completely
} OSStyleAssociatedStyleIterationResult;

typedef enum _OSStyleAssociatedStyleIterationTermination {
    OSStyleAssociatedStyleIterationStopped,
    OSStyleAssociatedStyleIterationRanOut,
} OSStyleAssociatedStyleIterationTermination;

typedef OSStyleAssociatedStyleIterationResult (^OSStyleAssociatedStyleIterator)(OSStyle *style);

@interface OSStyle : OFObject <OSStyleListener>

- initWithContext:(OSStyleContext *)context cascadeStyles:(NSArray *)cascadeStyles;
- initWithContext:(OSStyleContext *)context;

- (void)enableUndo;
- (void)disableUndo;
- (BOOL)isUndoEnabled;

@property (nonatomic, getter=isEditable) BOOL editable;

- (void)setAllowsRedundantValues:(BOOL)allowsRedundantValues;
- (BOOL)allowsRedundantValues;

@property(readonly,nonatomic) OSStyleContext *context;
@property(readonly,nonatomic) OSStyleAttributeRegistry *registry;
@property(readonly,nonatomic) NSUndoManager *undoManagerIfUndoIsEnabled;
@property(readonly,nonatomic) NSUndoManager *undoManagerEvenIfUndoIsDisabled;

- (NSArray/*<OSStyle>*/ *)cascadeStyles;
- (void)setCascadeStyles:(NSArray *)cascadeStyles;
- (void)setCascadeStyle:(OSStyle *)cascadeStyle;

- (BOOL)shouldSetValue:(id)value forAttributeKey:(NSString *)attributeKey;

- (BOOL)setValue:(id)value forAttributeKey:(NSString *)attributeKey;
- (BOOL)setValue:(id)value forAttribute:(OSStyleAttribute *)attribute;
- (id)valueForAttributeKey:(NSString *)attributeKey;
- (id)valueForAttribute:(OSStyleAttribute *)attribute;
- (id)localValueForAttributeKey:(NSString *)attributeKey;
- (id)valueForAttributeKey:(NSString *)attributeKey stoppingAtStyle:(OSStyle *)stopStyle; // Returns nil if there is no value found instead of the default
- (OSStyle *)styleDefiningAttributeKey:(NSString *)attributeKey stoppingAtStyle:(OSStyle *)stopStyle;
- (OSStyle *)styleDefiningAttributeKey:(NSString *)attributeKey;
- (OSStyle *)associatedStyleDefiningAttributeKey:(NSString *)attributeKey;

- (BOOL)isEmpty;
- (BOOL)hasLocallyDefinedAttributeKeys;
- (NSArray *)copyLocallyDefinedAttributeKeys;
- (NSArray *)nonDefaultAttributeKeys;
- (OFMutableKnownKeyDictionary *)copyEffectiveAttributeValues;
- (OFMutableKnownKeyDictionary *)copyEffectiveAttributeValuesIncludingDefaultValues:(BOOL)includeDefaultValues;
- (OSStyle *)newFlattenedStyle;

- (OSStyleAssociatedStyleIterationTermination)iterateAssociatedStylesIncludingRoot:(BOOL)includeRoot
                                                                       recursively:(BOOL)recursively
                                                                              with:(OSStyleAssociatedStyleIterator)iterator;
- (OSStyleAssociatedStyleIterationTermination)iterateStyles:(OSStyleAssociatedStyleIterator)iterator; // includeRoot=YES, recursively=YES

- (void)removeValuesForKeys:(NSArray *)keys;
- (void)removeRedundantValues;

// Caching of text attributes
@property (readonly) NSDictionary *textAttributes;

// Listeners
- (void)addListener:(id <OSStyleListener>)listener;
- (void)removeListener:(id <OSStyleListener>)listener;
- (BOOL)isReferenced;

- (NSUInteger)changeNotificationDisableCount;
- (void)disableChangeNotifications;
- (void)enableChangeNotifications;

// Archiving
+ (NSString *)xmlElementName;
- (void)appendXML:(OFXMLDocument *)doc;
- initFromXML:(OFXMLCursor *)cursor context:(OSStyleContext *)context cascadeStyles:(NSArray *)cascadeStyles;
- initFromXML:(OFXMLCursor *)cursor context:(OSStyleContext *)context cascadeStyles:(NSArray *)cascadeStyles allowRedundantValues:(BOOL)allowRedundantValues referencedAttributes:(NSMutableSet *)referencedAttributes;

#ifdef DEBUG
- (void)printListenerTree;
#endif

#ifdef OMNI_ASSERTIONS_ON
- (BOOL)_checkInvariants;
#endif

@end

// Predefined style attributes.  These become valid after +[OSStyle initialize].

// Character styles
extern OSStringStyleAttribute *OSFontFamilyNameStyleAttribute;
extern OSStringStyleAttribute *OSFontNameStyleAttribute;
extern OSNumberStyleAttribute *OSFontSizeStyleAttribute;
extern OSColorStyleAttribute  *OSFontFillColorStyleAttribute;
extern OSNumberStyleAttribute *OSFontStrokeWidthStyleAttribute;
extern OSColorStyleAttribute  *OSFontStrokeColorStyleAttribute;
extern OSNumberStyleAttribute *OSFontWeightStyleAttribute;
extern OSBoolStyleAttribute   *OSFontItalicStyleAttribute;
extern OSBoolStyleAttribute   *OSFontCondensedStyleAttribute;
extern OSBoolStyleAttribute   *OSFontFixedPitchStyleAttribute;
extern OSColorStyleAttribute  *OSBackgroundColorStyleAttribute;

extern OSColorStyleAttribute  *OSSelectionColorStyleAttribute;

extern OSNumberStyleAttribute *OSBaselineSuperscriptStyleAttribute;  // positive for superscript, negative for subscript
extern OSNumberStyleAttribute *OSBaselineOffsetStyleAttribute;
extern OSNumberStyleAttribute *OSKerningAdjustmentStyleAttribute;
extern OSEnumStyleAttribute   *OSLigatureSelectionStyleAttribute;

extern OSEnumStyleAttribute   *OSUnderlineStyleStyleAttribute;  // kind of a goofy name, yes
extern OSEnumStyleAttribute   *OSUnderlinePatternStyleAttribute;
extern OSEnumStyleAttribute   *OSUnderlineAffinityStyleAttribute;
extern OSColorStyleAttribute  *OSUnderlineColorStyleAttribute;

extern OSEnumStyleAttribute   *OSStrikethroughStyleStyleAttribute;
extern OSEnumStyleAttribute   *OSStrikethroughPatternStyleAttribute;
extern OSEnumStyleAttribute   *OSStrikethroughAffinityStyleAttribute;
extern OSColorStyleAttribute  *OSStrikethroughColorStyleAttribute;

extern OSNumberStyleAttribute *OSObliquenessStyleAttribute;
extern OSNumberStyleAttribute *OSExpansionStyleAttribute;

extern OSVectorStyleAttribute *OSShadowVectorStyleAttribute;
extern OSNumberStyleAttribute *OSShadowBlurRadiusStyleAttribute;
extern OSColorStyleAttribute  *OSShadowColorStyleAttribute;

// Paragraph styles
extern OSEnumStyleAttribute   *OSParagraphAlignmentStyleAttribute;
extern OSNumberStyleAttribute *OSParagraphSpacingStyleAttribute;
extern OSNumberStyleAttribute *OSParagraphLineSpacingStyleAttribute;
extern OSNumberStyleAttribute *OSParagraphFirstLineHeadIndentStyleAttribute;
extern OSNumberStyleAttribute *OSParagraphHeadIndentStyleAttribute;
extern OSNumberStyleAttribute *OSParagraphTailIndentStyleAttribute;
extern OSNumberStyleAttribute *OSParagraphMinimumLineHeightStyleAttribute;
extern OSNumberStyleAttribute *OSParagraphMaximumLineHeightStyleAttribute;
extern OSStringStyleAttribute *OSParagraphTabStopsStyleAttribute;
extern OSNumberStyleAttribute *OSParagraphLineHeightMultipleStyleAttribute;
extern OSNumberStyleAttribute *OSParagraphSpacingBeforeStyleAttribute;
extern OSNumberStyleAttribute *OSParagraphDefaultTabIntervalStyleAttribute;
extern OSEnumStyleAttribute   *OSParagraphBaseWritingDirectionStyleAttribute;
