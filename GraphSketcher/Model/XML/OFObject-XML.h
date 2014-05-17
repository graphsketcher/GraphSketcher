// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.


@class OFXMLElement, OFXMLCursor, OFXMLDocument;

extern NSString *stringFromBool(BOOL flag);
BOOL boolFromString(NSString *string);





extern OFXMLElement *SkipToNextChildElement(OFXMLCursor *cursor);

@interface NSObject (XML)

- (NSString *)readStringStoringWithKey:(NSString *)key fromCursor:(OFXMLCursor *)cursor elementName:(NSString *)elementName;

//- (NSString *)readStringStoringWithKey:(NSString *)key fromCursor:(OFXMLCursor *)cursor elementName:(NSString *)elementName importer:(XMLImporter *)importer;
- (NSString *)writeString:(NSString *)key document:(OFXMLDocument *)xmlDoc elementName:(NSString *)elementName;

//- (NSData *)readData:(NSString *)key fromCursor:(OFXMLCursor *)cursor elementName:(NSString *)elementName importer:(XMLImporter *)importer;
- (NSData *)writeData:(NSString *)key document:(OFXMLDocument *)xmlDoc elementName:(NSString *)elementName;

// Stores/returns false if the attribute isn't present
- (BOOL)readBool:(NSString *)key fromCursor:(OFXMLCursor *)cursor attributeName:(NSString *)attributeName;
// Stores/returns true if the element is empty false if the element is absent
- (BOOL)readBool:(NSString *)key fromCursor:(OFXMLCursor *)cursor elementName:(NSString *)elementName;
- (BOOL)writeBool:(NSString *)key document:(OFXMLDocument *)xmlDoc elementName:(NSString *)elementName;


- (NSNumber *)readFloatNumber:(NSString *)key fromCursor:(OFXMLCursor *)cursor elementName:(NSString *)elementName;

- (NSNumber *)readIntegerNumber:(NSString *)key fromCursor:(OFXMLCursor *)cursor elementName:(NSString *)elementName;
- (NSNumber *)writeOptionalIntegerNumber:(NSString *)key document:(OFXMLDocument *)xmlDoc elementName:(NSString *)elementName;
- (NSNumber *)writeRequiredIntegerNumber:(NSString *)key document:(OFXMLDocument *)xmlDoc elementName:(NSString *)elementName;

@end


//#define READ_STRING(key, _elementName) [self readStringStoringWithKey:(key) fromCursor:cursor elementName:(_elementName) importer:importer]
#define WRITE_STRING(key, _elementName) [self writeString:(key) document:xmlDoc elementName:(_elementName)]

//#define READ_DATA(key, _elementName) [self readData:(key) fromCursor:cursor elementName:(_elementName) importer:importer]
#define WRITE_DATA(key, _elementName) [self writeData:(key) document:xmlDoc elementName:(_elementName)]

#define READ_BOOL(_elementName) [self readBool:nil fromCursor:cursor elementName:(_elementName)]
#define WRITE_BOOL(key, _elementName) [self writeBool:(key) document:xmlDoc elementName:(_elementName)]

//#define READ_DATE(key, _elementName) [self readDateStoringWithKey:(key) fromCursor:cursor elementName:(_elementName) importer:importer foundElement:NULL]
#define WRITE_DATE(key, _elementName) [self writeDate:(key) document:xmlDoc elementName:(_elementName)]

//#define READ_INT(key, _elementName) [self readIntegerNumber:(key) fromCursor:cursor elementName:(_elementName) importer:importer]
#define WRITE_OPTIONAL_INT(key, _elementName) [self writeOptionalIntegerNumber:(key) document:xmlDoc elementName:(_elementName)]
#define WRITE_REQUIRED_INT(key, _elementName) [self writeRequiredIntegerNumber:(key) document:xmlDoc elementName:(_elementName)]

