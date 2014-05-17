// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <Foundation/NSAttributedString.h>
#import <OmniAppKit/OAFontDescriptor.h> // For OAFontDescriptorPlatformFont
#import <OmniBase/macros.h> // For OB_HIDDEN

#import "OSColorStyleAttribute.h"

@class OFXMLCursor, OFXMLDocument;
@class OSStyle, OSStyleContext;

extern NSString * const OSInheritedStylesAttributeName;

@interface NSAttributedString (OSExtensions)
+ (OSStyle *)newStyleOfClass:(Class)styleClass fromTextAttributes:(NSDictionary *)textAttributes cascadeStyle:(OSStyle *)cascadeStyle context:(OSStyleContext *)context;
+ (NSDictionary *)copyTextAttributesFromStyle:(OSStyle *)style;
+ (OSStyle *)newStyleFromTextAttributes:(NSDictionary *)textAttributes cascadeStyle:(OSStyle *)cascadeStyle context:(OSStyleContext *)context;
+ (OSStyle *)newStyleFromTextAttributes:(NSDictionary *)textAttributes context:(OSStyleContext *)context;

- (void)appendXML:(OFXMLDocument *)doc baseStyle:(OSStyle *)baseStyle;
@end

@interface NSMutableAttributedString (OSExtensions)
+ (BOOL)canCreateFromNextChildXML:(OFXMLCursor *)cursor;

// Returns YES, indicating that _OSMutableAttributedStringRemoveStyleTextAttributes() should be called on the instance after unarchiving, to remove the OSStyle-specific text attributes.
+ (BOOL)shouldRemoveStyleTextAttributesAfterUnarchiving;

+ newFromNextChildXML:(OFXMLCursor *)cursor baseStyle:(OSStyle *)baseStyle;
- initFromXML:(OFXMLCursor *)cursor baseStyle:(OSStyle *)baseStyle;

@end

#define OS_DEFINE_ORIGINAL_COLOR_KEY(key) \
NSString * const OSOriginal ## key OB_HIDDEN;

OS_DEFINE_ORIGINAL_COLOR_KEY(NSForegroundColorAttributeName);
OS_DEFINE_ORIGINAL_COLOR_KEY(NSBackgroundColorAttributeName);
OS_DEFINE_ORIGINAL_COLOR_KEY(NSStrokeColorAttributeName);
OS_DEFINE_ORIGINAL_COLOR_KEY(NSUnderlineColorAttributeName);
OS_DEFINE_ORIGINAL_COLOR_KEY(NSStrikethroughColorAttributeName);

#undef OS_DEFINE_ORIGINAL_COLOR_KEY

#define _OSColorKeys(textKey, originalKey) textKey, originalKey
#define OSColorKeys(key) _OSColorKeys(key, OSOriginal ## key)

OS_COLOR_CLASS *OSColorForTextAttribute(NSDictionary *textAttributes, NSString *textKey, NSString *originalKey) OB_HIDDEN;
void OSSetColorForTextAttribute(NSMutableDictionary *textAttributes, NSString *textKey, NSString *originalKey, OS_COLOR_CLASS *color) OB_HIDDEN;

NSDictionary *OSStyledTextStorageCreateTextAttributes(OSStyle *_style) OB_HIDDEN;

void _OSMutableAttributedStringRemoveStyleTextAttributes(NSMutableAttributedString *str) OB_HIDDEN;
