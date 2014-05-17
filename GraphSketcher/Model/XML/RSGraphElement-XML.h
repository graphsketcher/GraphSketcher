// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <GraphSketcherModel/RSGraphElement.h>

#if 0 && defined(DEBUG_robin)
    #define DEBUG_XML(format, ...) NSLog((format), ## __VA_ARGS__)
#else
    #define DEBUG_XML(format, ...)
#endif

@class OQColor;
@class OFXMLCursor, OFXMLDocument, OFVersionNumber;

@protocol XMLArchiving
+ (NSString *)xmlElementName;
- (BOOL)readContentsXML:(OFXMLCursor *)cursor error:(NSError **)outError;
- (BOOL)writeContentsXML:(OFXMLDocument *)xmlDoc error:(NSError **)outError;
@optional
- (NSArray *)childObjectsForXML;
@end


NSString *nameFromShape(NSUInteger shape);
NSUInteger shapeFromName(NSString *name);


@interface RSGraphElement (XML)

+ (void)setAppVersionOfImportedFileFromString:(NSString *)versionString;
+ (OFVersionNumber *)appVersionOfImportedFile;

+ (void)appendRect:(CGRect)rect toXML:(OFXMLDocument *)xmlDoc;
+ (void)appendColorIfNotBlack:(OQColor *)color toXML:(OFXMLDocument *)xmlDoc;
+ (void)appendColorIfNotWhite:(OQColor *)color toXML:(OFXMLDocument *)xmlDoc;

@end

#import <OmniFoundation/OFXMLElement.h>
@interface OFXMLElement (RSExtensions)
- (BOOL)boolValueForAttributeNamed:(NSString *)attribute defaultValue:(BOOL)defaultValue;
@end

