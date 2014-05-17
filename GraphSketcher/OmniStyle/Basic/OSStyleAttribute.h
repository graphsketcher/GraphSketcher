// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OmniFoundation/OFObject.h>
#import <OmniBase/OBUtilities.h>

@class OFXMLCursor, OFXMLDocument, OFXMLElement;
@class OSStyleAttributeCell;
@class NSException;

#define OS_UNINITIALIZED_STYLE_ATTRIBUTE ((id)0xdeadbeef)

@interface OSStyleAttribute : OFObject <NSCopying>
{
@private
    NSString *_key;
    NSUInteger _version;
    BOOL _internal;
    BOOL _nonText;
    
    // Valid while archiving
    OFXMLElement *_appendingXMLElement;
    
@protected
    // Subclasses set this when unarchiving
    id _defaultValue;
}

- initWithKey:(NSString *)key defaultValue:(id)defaultValue;

- (NSString *) key;

@property(readonly,nonatomic) id defaultValue;

- (id)validValueForValue:(id)value;

+ (NSString *)xmlElementName;
- (void)appendXML:(OFXMLDocument *)doc;
@property(nonatomic,retain) OFXMLElement *appendingXMLElement;
- initFromXML:(OFXMLCursor *)cursor;
- (void)appendXMLForDefaultValue:(OFXMLDocument *)doc;
- (void)readXMLForDefaultValue:(OFXMLCursor *)cursor;

- (void)setInternal:(BOOL)internal;
- (BOOL)internal;

- (void)setNonText:(BOOL)nonText;
- (BOOL)nonText;

@property(nonatomic,assign) NSUInteger version;

@end

// Subclasses must implement this protocol
@protocol OSConcreteStyleAttribute
+ (NSString *) xmlClassName;
/*" Must be subclassed.  Returns a name used to distinguish attributes of this class.  This is not the same as the ObjC class name of -valueClass since you may have two different ways to represent NSNumbers (possibly a fixed list of integers and a slider). "*/

- (Class) valueClass;
/*" Returns the class of values for this attribute. "*/

- (void) appendXML:(OFXMLDocument *)doc forValue:(id) value;
/*"  Must be subclassed.  Writes XML to the document for the indicated value. "*/

- (id)copyValueFromXML:(OFXMLCursor *)cursor;
/*"  Must be subclassed.  Creates a value from the current position of the OFXMLCursor. "*/

@optional
- (void)appendAdditionAttributesToXML:(OFXMLDocument *)doc;
/* only needed if subclass wants additional attributes written out */

@end

// We never implement this, this just allows callers to call the methods in the protocol more easily
@interface OSStyleAttribute (OSFakeConcreteInterface) <OSConcreteStyleAttribute>
@end
