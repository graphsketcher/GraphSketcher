// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "OSStyleAttribute.h"

#import "OSBoolStyleAttribute.h"
#import "OSColorStyleAttribute.h"
#import "OSEnumStyleAttribute.h"
#import "OSNumberStyleAttribute.h"
#import "OSStringStyleAttribute.h"
#import "OSVectorStyleAttribute.h"
#import "OSStyledTextStorage-XML.h"
#import <OmniFoundation/NSNumber-OFExtensions.h>
#import <OmniFoundation/OFXMLDocument.h>
#import <OmniFoundation/OFXMLElement.h>
#import <OmniFoundation/OFXMLCursor.h>
#import <Foundation/NSException.h>

#import <OmniBase/rcsid.h>

RCS_ID("$Header$");

@interface OSStyleAttribute (Private)
+ (Class) _styleAttributeClassForXMLClassName:(NSString *)xmlClassName;
@end

@implementation OSStyleAttribute
/*"
OSStyleAttribute represents a particular aspect of a style.  Once a style attribute is registered, it cannot be removed or altered as this could involve major rework to all the existing style objects and anything being rendered under them.  Various subclasses of this class provide support for different data types and editing schemes (for integration with the style inspector panel).

There are three names to consider when building an attribute.  First, there is the 'key' which is the developer-defined name for the attribute.  Second, there is the 'group' and finally the 'name'.  The 'group' and 'name' must be taken together to be meaningful to the user.  For example, these might be 'font' and 'foreground color'.  These two names are used in the OSStyleInspector to order and present the style information and should therefore be localized.

Care must be taken with attribute naming practices.  Once an attribute is published, it should never be renamed or changed without extreme care since doing so potentially invalidates all the archived documents using that attribute.

Attributes that are not defined in OmniAppKit should have a suffix that ensures uniqueness.  One obvious choice is to use the application's bundle identifier (assuming that won't change).  We need to make sure that -[NSString hash] behaves nicely and in at least some implementations it only considered some small prefix on the string.  For this reason, an application specific key should be of the format 'key(bundle-id)'.  So, for example, OmniOutliner might define 'item-indentation-level(com.omnigroup.OmniOutliner)'.  Again, OmniAppKit reserves the entire 'unsuffixed' attribute key namespace.

Attribute keys from the Cocoa text system should not be used as attribute names as the OSStyle system intends to be neutral to this usage and the Cocoa text system keys are non-orthogonal.  As an example, the NSUnderlineStyleAttributeName key both holds the zero/one/double underline setting and the the 'by-word' and 'strikethrough' masks.  We want these to be separate keys in OSStyle and then have OSStyledTextStorage (when it is written) perform conversion between the two worlds.  One down side to this rule is that if the text system understands some random attribute, we won't get it for free.
"*/

- initWithKey:(NSString *)key defaultValue:(id)defaultValue;
{
    OBPRECONDITION([self class] != [OSStyleAttribute class]); // Must be subclassed
    OBPRECONDITION([self conformsToProtocol: @protocol(OSConcreteStyleAttribute)]);
    OBPRECONDITION(key);
    OBPRECONDITION(defaultValue); // Yes, you must have a default value.  Otherwise the default isn't worth much, is it?

    // Allow OFNaN to work around Radar bug that is its whole reason for existance.
    OBPRECONDITION([defaultValue isKindOfClass: [self valueClass]] || ([self valueClass] == [NSNumber class] && defaultValue == [OFNaN sharedNaN]));

    if (!(self = [super init]))
        return nil;

    _key = [key copy];
    _defaultValue = [defaultValue copy];

    return self;
}

- (void)dealloc;
{
    [_key release];
    [_defaultValue release];
    [_appendingXMLElement release];
    [super dealloc];
}

//
// API
//


- (NSString *) key;
/*" Returns the programmer defined string that is used for registering the style attribute, looking up values from styles and such. "*/
{
    return _key;
}

- (id)defaultValue;
{
    // Make sure that this got filled out correctly if we were initialized with -initFromXML:
    OBPRECONDITION(_defaultValue);
    OBPRECONDITION([self validValueForValue:_defaultValue] == _defaultValue);
    
    return _defaultValue;
}

- (id)validValueForValue:(id)value;
/*" Returns a valid value for this attribute. By default, if the value is of the right class it is returned. Otherwise the default value is returned. Nil is always a valid value since that eventually maps to the defaultValue. "*/
{
    if (!value)
        return value; // Nil is always valid

    if ([value isKindOfClass:[self valueClass]])
        return value;
    
    return _defaultValue;
}

#define StyleAttributeElementName (@"style-attribute")

+ (NSString *)xmlElementName;
{
    return StyleAttributeElementName;
}

- (void)appendXML:(OFXMLDocument *)doc;
/*" Archives the receive to the document.  This is useful if you want to record what the default values were when the document was archived in case they change in the future. "*/
{
    OBPRECONDITION(doc);

    [_appendingXMLElement release];
    _appendingXMLElement = [[doc pushElement: StyleAttributeElementName] retain];
    [_appendingXMLElement setIgnoreUnlessReferenced:YES];
    {
        OBASSERT(_version <= UINT32_MAX);
        [doc setAttribute:@"version" integer:(uint32_t)_version];
        [doc setAttribute:OSStyleAttributeKeyXMLAttributeName value:_key];
        [doc setAttribute:@"class" value:[[self class] xmlClassName]];

        if ([self respondsToSelector:@selector(appendAdditionAttributesToXML:)])
            [self appendAdditionAttributesToXML:doc];

        [self appendXMLForDefaultValue:doc];
    }
    [doc popElement];
}

@synthesize appendingXMLElement = _appendingXMLElement;
- (void)setAppendingXMLElement:(OFXMLElement *)appendingXMLElement;
{
    [_appendingXMLElement release];
    _appendingXMLElement = [appendingXMLElement retain];
}

static id MissingAttribute(id self, NSString *attributeName, OFXMLCursor *cursor)
{
    NSLog(@"Missing required attribute '%@' at '%@'", attributeName, [cursor currentPath]);
    [self release];
    return nil;
}
    
- initFromXML:(OFXMLCursor *)cursor;
/*" Initializes the receiver from the cursor.  Note that there is a chance that the value class will not exist in the current process.  If that occurs, this method will return nil (as you almost certainly can't edit the value meaningfully and OSStyle will just preserve any archived values exactly as is). "*/
{
    OBPRECONDITION(cursor);

    if (![[cursor name] isEqualToString: StyleAttributeElementName]) {
        NSLog(@"Expected a '%@' element in the cursor, but got '%@' (path = '%@')", StyleAttributeElementName, [cursor name], [cursor currentPath]);
        [self release];
        return nil;
    }

    // Allow subclasses to override this method, but also allow this implementation to do some of the work
    if ([self isMemberOfClass:[OSStyleAttribute class]]) {
        NSString *className = [cursor attributeNamed: @"class"];
        if (!className)
            return MissingAttribute(self, @"class", cursor);

        Class attributeClass = [[self class] _styleAttributeClassForXMLClassName: className];

        if (!attributeClass) {
            // Just bail.  OSStyle will preserve the value as is.
            NSLog(@"Unable to create style attribute of class '%@'", className);
            [self release];
            return nil;
        }

        // Destroy ourselves and start over using the right subclass
        [self release];
        return [[attributeClass alloc] initFromXML:cursor];
    }

    // Subclasses must call the super implementation to get this part...
    _version = [[cursor attributeNamed:@"version"] intValue];
    
    if (!(_key = [[cursor attributeNamed: OSStyleAttributeKeyXMLAttributeName] copy]))
        return MissingAttribute(self, OSStyleAttributeKeyXMLAttributeName, cursor);

    // Might return nil if the element is empty.  Subclasses should detect this and put in a reasonable default.
    NS_DURING {
        [self readXMLForDefaultValue:cursor];
    } NS_HANDLER {
        [self release];
        [localException raise];
    } NS_ENDHANDLER;
    
    return self;
}

- (void)appendXMLForDefaultValue:(OFXMLDocument *)doc;
/*" The default implementation appends the default value via -appendXML:forVaule:. */
{
    [self appendXML:doc forValue:_defaultValue];
}

- (void)readXMLForDefaultValue:(OFXMLCursor *)cursor;
/*" The default implementation reads the default value via -copyValueFromXML:. */
{
    _defaultValue = [self copyValueFromXML:cursor];
}

- (void)setInternal:(BOOL)internal;
{
    _internal = internal;
}

- (BOOL)internal;
{
    return _internal;
}

- (void)setNonText:(BOOL)nonText;
/*" Sets whether the attribute is represented in the OSStyledTextStorage conversion of OSStyle to Cocoa text attributes.   Applications like OmniOutliner may add styles in different domains (items, columns, etc). "*/
{
    _nonText = nonText;
}

- (BOOL)nonText;
{
    return _nonText;
}

@synthesize version = _version;
- (void)setVersion:(NSUInteger)version;
{
    OBPRECONDITION(_version == 0); // this should be called right after initialization
    _version = version;
}

//
// NSCopying (so we can be keys in dictionaries)
//
- (id)copyWithZone:(NSZone *)zone;
{
    return [self retain];
}

@end

@implementation OSStyleAttribute (Private)

+ (Class) _styleAttributeClassForXMLClassName:(NSString *)xmlClassName;
{
#define CHECK(c) \
    else if ([xmlClassName isEqualToString: [c xmlClassName]]) \
        return [c class]

    if (0) {}
    CHECK(OSStringStyleAttribute);
    CHECK(OSNumberStyleAttribute);
    CHECK(OSColorStyleAttribute);
    CHECK(OSBoolStyleAttribute);
    CHECK(OSEnumStyleAttribute);
    CHECK(OSVectorStyleAttribute);
#undef CHECK

    // We can't allow this to pass since that would mean we'd not be able to save the file back out w/o changes
    [NSException raise:NSInvalidArgumentException format:NSLocalizedStringFromTableInBundle(@"Unrecognized style attribute class name '%@'", @"OmniStyle", OMNI_BUNDLE, "exception reason"), xmlClassName];
    return Nil; // GCOV IGNORE
}

@end
