// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "RSGraph-XML.h"

#import "OFObject-XML.h"
#import "RSGraphElement-XML.h"
#import "RSAxis-XML.h"
#import "RSVertex-XML.h"
#import "RSLine-XML.h"
#import "RSFill-XML.h"
#import "RSTextLabel-XML.h"
#import "RSGroup-XML.h"
#import "BackwardsCompatibility.h"
#import <OmniQuartz/OQColor-Archiving.h>

#import <OmniFoundation/OFXMLDocument.h>
#import <OmniFoundation/OFXMLCursor.h>
#import <OmniFoundation/OFVersionNumber.h>
#import <OmniUnzip/OUUnzipArchive.h>
#import <OmniUnzip/OUUnzipEntry.h>
#import <OmniUnzip/OUZipArchive.h>

#import "OSStyle.h"
#import "OSStringStyleAttribute.h"
#import "OSColorStyleAttribute.h"
#import "OSStyledTextStorage-XML.h"

NSString * const RSGraphFileType = @"com.graphsketcher.graphdocument";
NSString * const XMLNamespaceIdentifier = @"http://www.omnigroup.com/namespace/OmniGraphSketcher/v1";
NSString * const XMLRootElementName = @"document";

#if !defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE
#import <sys/sysctl.h>
static NSString *stringForSysctlName(int name[], int nameCount)
{
    size_t bufSize = 0;
    
    // Passing a null pointer just says we want to get the size out
    if (sysctl(name, nameCount, NULL, &bufSize, NULL, 0) < 0) {
	perror("sysctl");
	return nil;
    }
    
    char *value = calloc(1, bufSize + 1);
    
    if (sysctl(name, nameCount, value, &bufSize, NULL, 0) < 0) {
	// Not expecting any errors now!
	free(value);
	perror("sysctl");
	return nil;
    }
    
    
    NSString *result = [(NSString *)CFStringCreateWithCString(kCFAllocatorDefault, value, kCFStringEncodingUTF8) autorelease];
    free(value);
    return result;
}
#endif

// XML validation code
#define VALIDATE_XML_IN_RELEASE_BUILDS 1

#if VALIDATE_XML_IN_RELEASE_BUILDS
#import <OmniFoundation/OFPreference.h>
#include <libxml/parser.h>
#include <libxml/tree.h>
#include <libxml/relaxng.h>
#include <libxml/xmlreader.h>

static void validityErrorFunc(void *ctx, const char *msg, ...)
{
    va_list argList;
    va_start(argList, msg);
    NSLogv([NSString stringWithCString:msg encoding:NSASCIIStringEncoding], argList);
    va_end(argList);
}

static void validityWarningFunc(void *ctx, const char *msg, ...)
{
    va_list argList;
    va_start(argList, msg);
    NSLogv([NSString stringWithCString:msg encoding:NSASCIIStringEncoding], argList);
    va_end(argList);
}

static void validateXML(NSString *schema, NSData *xmlData, NSString *filename) 
{
    LIBXML_TEST_VERSION
    
    static xmlRelaxNGPtr compiledSchema = NULL;
    if (!compiledSchema) {
        NSString *schemaPath = [OMNI_BUNDLE pathForResource:schema ofType:@"rng"];
        OBASSERT(schemaPath);
        NSData *schemaData = [NSData dataWithContentsOfFile:schemaPath];
        
        NSUInteger schemaDataLength = [schemaData length];
        if (schemaDataLength > INT_MAX)
            OBRejectInvalidCall(nil, NULL, @"Schema data too long");
        
        xmlRelaxNGParserCtxtPtr schemaCtxt = xmlRelaxNGNewMemParserCtxt((const char *)[schemaData bytes], (int)schemaDataLength);
        compiledSchema = xmlRelaxNGParse(schemaCtxt);
        xmlRelaxNGFreeParserCtxt(schemaCtxt);
    }
    
    xmlRelaxNGValidCtxtPtr validationCtxt = xmlRelaxNGNewValidCtxt(compiledSchema);
    xmlRelaxNGSetValidErrors(validationCtxt, validityErrorFunc, validityWarningFunc, NULL);
    // xmlRelaxNGSetValidErrors(validationCtxt, (xmlValidityErrorFunc)fprintf, (xmlValidityWarningFunc)fprintf, stderr);
    
    NSUInteger xmlDataLength = [xmlData length];
    if (xmlDataLength > INT_MAX)
        OBRejectInvalidCall(nil, NULL, @"XML data too long");
    
    xmlTextReaderPtr reader = xmlReaderForMemory((const char *)[xmlData bytes], (int)xmlDataLength, [filename UTF8String], NULL, (XML_PARSE_NONET | XML_PARSE_PEDANTIC));
    if (xmlTextReaderRelaxNGSetSchema(reader, compiledSchema))
	NSLog(@"Ack!");
    
    int ret = xmlTextReaderRead(reader);
    while (ret == 1) {
	ret = xmlTextReaderRead(reader);
    }
    
    if (xmlTextReaderIsValid(reader) != 1) {
	NSLog(@"xml fails to validate");
    } else {
        xmlDocPtr doc = xmlReadMemory((const char *)[xmlData bytes], (int)xmlDataLength, [filename UTF8String], NULL, (XML_PARSE_NONET | XML_PARSE_PEDANTIC));
        if (!doc || (xmlRelaxNGValidateDoc(validationCtxt, doc) != 0))
            NSLog(@"xml fails to validate");
        else {
#ifdef DEBUG
            NSLog(@"xml validates");
#endif
        }
        if (doc)
            xmlFreeDoc(doc);
    }
    xmlFreeTextReader(reader);
    
    // free up the parser context
    xmlRelaxNGFreeValidCtxt(validationCtxt);
}
#endif


@implementation RSGraph (Archiving)

// For uncompressed documents
static OFXMLWhitespaceBehavior *_whitespaceBehavior(void)
{
    static OFXMLWhitespaceBehavior *whitespace = nil;
    
    if (!whitespace) {
        whitespace = [[OFXMLWhitespaceBehavior alloc] init];
        [whitespace setBehavior:OFXMLWhitespaceBehaviorTypeIgnore forElementName:XMLRootElementName];
        [whitespace setBehavior:OFXMLWhitespaceBehaviorTypePreserve forElementName:OSStyledTextStorageLiteralStringXMLElementName];
    }
    return whitespace;
}


static id _badFileType(BOOL writing, NSString *typeName, NSError **outError)
{
    NSString *description;
    if (writing)
        description = NSLocalizedStringFromTableInBundle(@"Unable to write file.", @"GraphSketcherModel", OMNI_BUNDLE, @"error description");
    else
        description = NSLocalizedStringFromTableInBundle(@"Unable to read file.", @"GraphSketcherModel", OMNI_BUNDLE, @"error description");
    NSString *reason = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"The file type \"%@\" is not recognized.", @"GraphSketcherModel", OMNI_BUNDLE, @"error reason format string"), typeName];
    GSMError(outError, GSMUnrecognizedFileType, description, reason);
    return nil;
}

static BOOL _isGraphDocumentType(NSString *typeName)
{
    if (!typeName)
        return NO;
    
    // Do a case-insensitive compare since the UTI seems to come in as all lowercase.
    NSComparisonResult result = [typeName caseInsensitiveCompare:RSGraphFileType];
    return result == NSOrderedSame;
}

+ (RSGraph *)graphFromData:(NSData *)data fileName:(NSString *)fileName type:(NSString *)typeName undoer:(RSUndoer *)undoer error:(NSError **)outError;
{
    if (!_isGraphDocumentType(typeName))
        return _badFileType(NO/*write*/, typeName, outError);
    
    OBPRECONDITION(data);
    BOOL readFailed = NO;
    RSGraph *graph = nil;
    
    // Don't register undos if the model reading code uses its own accessors.
    [[undoer undoManager] disableUndoRegistration];

    @try {
        // Create a new graph object (necessary to do that here in case this is "revert to saved")
        graph = [[[RSGraph alloc] initWithIdentifier:nil undoer:undoer] autorelease];
        
        //NSBundle *appBundle = [NSBundle mainBundle];
        //NSString *bundleIdentifier = [appBundle bundleIdentifier];
        
        OFXMLDocument *doc = [[[OFXMLDocument alloc] initWithData:data whitespaceBehavior:_whitespaceBehavior() error:outError] autorelease];
        if (!doc)
            return nil;
        OFXMLCursor *cursor = [[[OFXMLCursor alloc] initWithDocument:doc] autorelease];
        
        OFXMLElement *rootElement = [doc rootElement];
        OBASSERT([[rootElement name] isEqualToString:XMLRootElementName]);
        
        NSString *namespace = [rootElement attributeNamed: @"xmlns"];
        [RSGraphElement setAppVersionOfImportedFileFromString:[rootElement attributeNamed: @"app-version"]];
        
        BOOL shouldOpen = YES;
        // Warn if the file is from the future
        if (![namespace isEqualToString:XMLNamespaceIdentifier]) {
            // This logic requires that our namespaces have nothing that could be considered a version number before the actual version number.
            
            OFVersionNumber *fileVersion = [[[OFVersionNumber alloc] initWithVersionString:[namespace lastPathComponent]] autorelease];
            OFVersionNumber *appVersion  = [[[OFVersionNumber alloc] initWithVersionString:[XMLNamespaceIdentifier lastPathComponent]] autorelease];
            
            if (fileVersion && appVersion) {
                OBASSERT(![fileVersion isEqual:appVersion]); // Otherwise, the strings should have been equal and our containing 'if' should have failed
                
                if ([appVersion compareToVersionNumber:fileVersion] == NSOrderedAscending) {
                    // The file format is newer than the app.
                    // Ask the user if we should load the file.
                    
                    OBFinishPorting;
                    //shouldOpen = [GraphDocument shouldLoadFile:fileName writtenByNewerVersion:fileVersion appVersion:appVersion];
                    
                    // TODO: Maybe we should not allow the user to try to open major revisions of the file format?  Hard to see into the future, though.
                } else {
                    // The app is newer than the file format.
                    shouldOpen = YES;
                }
            }
        }
        if (!shouldOpen) {
            if (outError != NULL)
                *outError = [[NSError errorWithDomain:NSCocoaErrorDomain code:NSUserCancelledError userInfo:nil] retain];
            
            return NO;
        }
        
        // Read in the xml elements above the main "graph" elements.
        CGRect frame = CGRectMake(200, 200, 620, 520);
        if ([cursor openNextChildElementNamed:@"window"]) {
            if ([cursor openNextChildElementNamed:@"frame"]) {
                OFXMLElement *frameElement = [cursor currentElement];
                frame.origin.x = [frameElement realValueForAttributeNamed:@"x" defaultValue:200];
                frame.origin.y = [frameElement realValueForAttributeNamed:@"y" defaultValue:200];
                frame.size.width = [frameElement realValueForAttributeNamed:@"w" defaultValue:200];
                frame.size.height = [frameElement realValueForAttributeNamed:@"h" defaultValue:200];
                DEBUG_XML(@"Read frame: %@", NSStringFromRect(frame));
                graph.frameOrigin = frame.origin;
                
                [cursor closeElement];
            }
            [cursor closeElement];
        }
        
        // Read in the graph properties and data.
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        if ([cursor openNextChildElementNamed:[RSGraph xmlElementName]]) {
            
            if (![graph readContentsXML:cursor error:outError])
                readFailed = YES;
            
            [cursor closeElement];
        }
        [pool release];
    } @finally {
        [[undoer undoManager] enableUndoRegistration];
    }
    
    return readFailed ? nil : graph;
}

static NSString * const PreviewFileName = @"preview.pdf";

+ (RSGraph *)graphFromURL:(NSURL *)url type:(NSString *)typeName undoer:(RSUndoer *)undoer error:(NSError **)outError;
{
    if (!_isGraphDocumentType(typeName))
        return _badFileType(NO/*write*/, typeName, outError);
    
    if (![url isFileURL]) {
        NSString *description = NSLocalizedStringFromTableInBundle(@"Unable to read file.", @"GraphSketcherModel", OMNI_BUNDLE, @"error description");
        NSString *reason = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"\"%@\" is not a file URL.", @"GraphSketcherModel", OMNI_BUNDLE, @"error reason format string"), [url absoluteString]];
        GSMError(outError, GSMUnrecognizedURLScheme, description, reason);
        return nil;
    }
    NSString *path = [[url absoluteURL] path];
    
    NSData *data;
    NSError *unzipError = nil;
    OUUnzipArchive *zipArchive = [[[OUUnzipArchive alloc] initWithPath:path error:&unzipError] autorelease];
    
    if (zipArchive) {
        DEBUG_XML(@"Getting xml file from zip archive");
        OUUnzipEntry *zipEntry = [zipArchive entryNamed:@"contents.xml"];
        data = [zipArchive dataForEntry:zipEntry error:outError];
    } else {
        // If a zip archive was not constructed, this is most likely an autosave.
        data = [NSData dataWithContentsOfURL:url options:0 error:outError];
    }
    
    return [self graphFromData:data fileName:[path lastPathComponent] type:typeName undoer:undoer error:outError];
}

+ (BOOL)getGraphPDFPreviewData:(NSData **)outPDFData modificationDate:(NSDate **)outModificationDate fromURL:(NSURL *)url error:(NSError **)outError;
{
    if (![url isFileURL]) {
        NSString *description = NSLocalizedStringFromTableInBundle(@"Unable to read file.", @"GraphSketcherModel", OMNI_BUNDLE, @"error description");
        NSString *reason = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"\"%@\" is not a file URL.", @"GraphSketcherModel", OMNI_BUNDLE, @"error reason format string"), [url absoluteString]];
        GSMError(outError, GSMUnrecognizedURLScheme, description, reason);
        return NO;
    }
    
    NSString *path = [[url absoluteURL] path];

    OUUnzipArchive *unzip = [[[OUUnzipArchive alloc] initWithPath:path error:outError] autorelease];
    if (!unzip)
        return NO;

    // Don't return a date based on the zip contents. This causes duplicated documents to have the same date as their original instead of consistently moving to the left most edge.
#if 0
    if (outModificationDate) {
        OUUnzipEntry *contentsEntry = [unzip entryNamed:PreviewFileName];
        if (!contentsEntry) {
            NSString *description = NSLocalizedStringFromTableInBundle(@"No preview.pdf found inside the zip wrapper.", @"GraphSketcherModel", OMNI_BUNDLE, @"error description");
            NSString *reason = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"Unable to find preview.", @"GraphSketcherModel", OMNI_BUNDLE, @"error reason format string"), [url absoluteString]];
            GSMError(outError, GSMNoPreviewAvailable, description, reason);
            return NO;
        }
        *outModificationDate = [contentsEntry date];
    }
#endif
    
    if (outPDFData) {
        OUUnzipEntry *previewEntry = [unzip entryNamed:PreviewFileName];
        if (previewEntry)
            *outPDFData = [unzip dataForEntry:previewEntry error:outError];
        else
            *outPDFData = nil;
    }
    
    return YES;
}

+ (OFXMLDocument *)xmlDocumentWrapperWithError:(NSError **)outError;
{
    DEBUG_XML(@"Generating XML data...");
    
    OFXMLDocument *doc = [[[OFXMLDocument alloc] initWithRootElementName:XMLRootElementName
                                                            namespaceURL:[NSURL URLWithString:XMLNamespaceIdentifier]
                                                      whitespaceBehavior:_whitespaceBehavior()
                                                          stringEncoding:kCFStringEncodingUTF8
                                                                   error:outError] autorelease];
    if (!doc)
        return nil;
    
    OFXMLElement *rootElement = [doc rootElement];
    [rootElement setAttribute:@"xmlns" string:XMLNamespaceIdentifier];
    
    // [Copied from OmniFocus] Record information about the client writing this file.  We may be coalescing information written by other clients, so some care in interpreting this is necessary.  We just need to use this for debugging info, if there is any version-specific info read/written, it should be based of the version in the xmlns.
    {
	[rootElement setAttribute:@"app-id" string:[[NSBundle mainBundle] bundleIdentifier]];
	
	NSString *bundleVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:(id)kCFBundleVersionKey];
        OBASSERT(bundleVersion);
	[rootElement setAttribute:@"app-version" string:bundleVersion];
	
	NSString *osName, *model = nil;
#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
	osName = [[UIDevice currentDevice] systemName];
	model = [[UIDevice currentDevice] model];
#else
	osName = [[NSProcessInfo processInfo] operatingSystemName];
	int name[] = {CTL_HW, HW_MODEL};
	model = stringForSysctlName(name, 2);
#endif
	[rootElement setAttribute:@"os-name" string:osName];
	
	NSString *osVersion = [[OFVersionNumber userVisibleOperatingSystemVersionNumber] cleanVersionString];
	[rootElement setAttribute:@"os-version" string:osVersion];
	
	[rootElement setAttribute:@"machine-model" string:model];
    }
    
    return doc;
}

- (NSData *)generateXMLOfType:(NSString *)typeName frame:(CGRect)frame error:(NSError **)outError;
{
    if (!_isGraphDocumentType(typeName))
        return _badFileType(YES/*write*/, typeName, outError);
    
    OFXMLDocument *doc = [RSGraph xmlDocumentWrapperWithError:outError];
    
    if (outError)
        *outError = nil;
    
    // <window>
    if (CGRectGetWidth(frame) > 0 && CGRectGetHeight(frame) > 0) { // CGRectEqualToRect returns NO for NSZeroRect no matter what
	[doc pushElement:@"window"];
	[doc pushElement:@"frame"];
	[RSGraphElement appendRect:frame toXML:doc];
	[doc popElement];
	[doc popElement];
    }
    
    // <graph>
    [doc pushElement:[RSGraph xmlElementName]];
    if (![self writeContentsXML:doc error:outError]) 
        return nil;

    [doc popElement];
    
    NSData *xmlData = [doc xmlData:outError];
    
    // Validate XML always in debug mode
#ifdef DEBUG
    validateXML(@"GraphSketcher", xmlData, @"__TOC.xml");
#elif VALIDATE_XML_IN_RELEASE_BUILDS
    // If a release build, only validate if the hidden preference is turned on
    if ( [[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:@"ValidateXMLOnSave"] ) {
        validateXML(@"GraphSketcher", xmlData, @"__TOC.xml");
    }
#endif
    
    return xmlData;
}

#if !defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE
- (BOOL)writeToURL:(NSURL *)url generatedXMLData:(NSData *)xmlData previewPDFData:(NSData *)previewPDFData error:(NSError **)outError;
{
    // If we just have the XML data (likely an autosave), don't write a full zip file.
    if (!previewPDFData)
        return [xmlData writeToURL:url options:NSAtomicWrite error:outError];
    
    // Add XML file to a zip archive
    OUZipArchive *zipArchive = [[[OUZipArchive alloc] initWithPath:[[url absoluteURL] path] error:outError] autorelease];
    if (!zipArchive) {
        if (outError != NULL)
            OBASSERT(*outError);
        return NO;
    }
    
    NSDate *date = [NSDate date];
    if (![zipArchive appendEntryNamed:@"contents.xml" fileType:NSFileTypeRegular contents:xmlData date:date error:outError])
        return NO;
    if (previewPDFData && ![zipArchive appendEntryNamed:PreviewFileName fileType:NSFileTypeRegular contents:previewPDFData date:date error:outError])
        return NO;
    
    // "Closing" the zip archive saves its contents to disk.
    if (![zipArchive close:outError]) {
        OBFinishPorting;
#if 0
        NSString *path = [absoluteURL path];
        [[NSFileManager defaultManager] removeFileAtPath:path handler:nil];
        if (outError != NULL)
            OBASSERT(*outError);
#endif
        return NO;
    }
    
    return YES;
}
#endif

@end

@implementation RSGraph (XML)

#pragma mark -
#pragma mark Private methods

- (void)writeBorder:(RSBorder)border name:(NSString *)name XML:(OFXMLDocument *)xmlDoc;
{
    [xmlDoc pushElement:name];
    [xmlDoc setAttribute:@"top" real:(float)border.top];
    [xmlDoc setAttribute:@"right" real:(float)border.right];
    [xmlDoc setAttribute:@"bottom" real:(float)border.bottom];
    [xmlDoc setAttribute:@"left" real:(float)border.left];
    [xmlDoc popElement];
}

- (RSBorder)readBorderFromXML:(OFXMLCursor *)cursor;
{
    OFXMLElement *element = [cursor currentElement];
    
    RSBorder border;
    border.top = [element realValueForAttributeNamed:@"top" defaultValue:0];
    border.right = [element realValueForAttributeNamed:@"right" defaultValue:0];
    border.bottom = [element realValueForAttributeNamed:@"bottom" defaultValue:0];
    border.left = [element realValueForAttributeNamed:@"left" defaultValue:0];
    
    return border;
}


- (BOOL)writeCanvasXML:(OFXMLDocument *)xmlDoc error:(NSError **)outError;
{
    [xmlDoc pushElement:@"canvas"];
    
    [xmlDoc setAttribute:@"w" real:(float)[self canvasSize].width];
    [xmlDoc setAttribute:@"h" real:(float)[self canvasSize].height];
    [xmlDoc setAttribute:@"auto-whitespace" string:stringFromBool([self autoMaintainsWhitespace])];
    
    [RSGraphElement appendColorIfNotWhite:[self backgroundColor] toXML:xmlDoc];  // background color
    
    [self writeBorder:[self whitespace] name:@"whitespace" XML:xmlDoc];
    [self writeBorder:[self edgePadding] name:@"edge-padding" XML:xmlDoc];
    
    [xmlDoc pushElement:@"shadow"];
    [xmlDoc setAttribute:@"strength" real:(float)[self shadowStrength]];
    [xmlDoc popElement];
    
    [xmlDoc popElement];
    
    return YES;
}

- (BOOL)readCanvasXML:(OFXMLCursor *)cursor error:(NSError **)outError;
{
    OBPRECONDITION(OFISEQUAL([cursor name], @"canvas"));
    
    OFXMLElement *element = [cursor currentElement];
    
    CGSize canvasSize;
    canvasSize.width = [element realValueForAttributeNamed:@"w" defaultValue:520];
    canvasSize.height = [element realValueForAttributeNamed:@"h" defaultValue:420];
    [self setCanvasSize:canvasSize];
    
    _autoMaintainsWhitespace = [element boolValueForAttributeNamed:@"auto-whitespace" defaultValue:YES];
    
    // background color
    [_bgColor release];
    _bgColor = nil;
    if ([cursor openNextChildElementNamed:@"color"]) {
	_bgColor = [[OQColor colorFromXML:cursor] retain];
	[cursor closeElement];
    } else {
	_bgColor = [[OQColor whiteColor] retain];
    }
    
    if ([cursor openNextChildElementNamed:@"whitespace"]) {
	_whitespace = [self readBorderFromXML:cursor];
	[cursor closeElement];
    } else {
	_whitespace = RSMakeBorder(2, 2, 2, 2);
    }

    if ([cursor openNextChildElementNamed:@"edge-padding"]) {
	_edgePadding = [self readBorderFromXML:cursor];
	[cursor closeElement];
    } else {
	_edgePadding = RSMakeBorder(6, 6, 6, 6);
    }
    
    if ([cursor openNextChildElementNamed:@"shadow"]) {
	_shadowStrength = [[cursor currentElement] realValueForAttributeNamed:@"strength" defaultValue:0];
	[cursor closeElement];
    } else {
	_shadowStrength = 0;
    }
    
    return YES;
}


#pragma mark -
#pragma mark Public helper methods

- (NSString *)idrefsFromArray:(NSArray *)array;
{
    NSMutableString *idrefs = [NSMutableString string];
    for (id element in array) {
	if ([idrefs length])
	    [idrefs appendString:@" "];
	[idrefs appendString:[self identiferForObject:element]];
	
	OBASSERT([self containsElement:element]);  // We don't want to return idrefs of objects that aren't actually going to be archived
    }
    
    return idrefs;
}

- (OSStyle *)defaultBaseStyle;
{
    if (_baseStyle)
	return _baseStyle;
    
    _baseStyle = [[OSStyle alloc] initWithContext:[self styleContext]];

#if !defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE
    [_baseStyle setValue:@"Lucida Grande" forAttribute:OSFontFamilyNameStyleAttribute];
#else
    // No Lucida Grande on the iPad.
    [_baseStyle setValue:@"Verdana" forAttribute:OSFontFamilyNameStyleAttribute];
#endif
    
    id blackColor = [OQColor blackColor];
#if !defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE
    blackColor = ((OQColor *)blackColor).toColor; // Mac wants NSColor, iPad OQColor
#endif
    [_baseStyle setValue:blackColor forAttribute:OSFontFillColorStyleAttribute];
    
    return _baseStyle;
}


#pragma mark -
#pragma mark XMLArchiving protocol

+ (NSString *)xmlElementName;
{
    return @"graph";
}


// Helper functions for intially registering all graph elements
static void allocAndRegisterObjectWithIdentifier(OFXMLElement *element, NSString *identifier, void *context)
{
    RSGraph *graph = context;
    
    if (!identifier)
	return;
    
    NSString *name = [element name];
    OBASSERT(name);
    
    if ([name isEqualToString:[RSAxis xmlElementName]]) {
	[[[RSAxis alloc] initWithGraph:graph identifier:identifier] autorelease];
    }
    else if ([name isEqualToString:[RSVertex xmlElementName]]) {
	[[[RSVertex alloc] initWithGraph:graph identifier:identifier] autorelease];
    }
    else if ([name isEqualToString:[RSLine xmlElementName]]) {
	NSString *className = [element attributeNamed:@"class"];
	
	// default is RSConnectLine
	if (!className || [className isEqualToString:[RSConnectLine xmlClassName]]) {
	    [[[RSConnectLine alloc] initWithGraph:graph identifier:identifier] autorelease];
	}
	else if ([className isEqualToString:[RSFitLine xmlClassName]]) {
	    [[[RSFitLine alloc] initWithGraph:graph identifier:identifier] autorelease];
	}
	else {
	    NSLog(@"Unsupported line class: '%@'", className);
	}
    }
    else if ([name isEqualToString:[RSFill xmlElementName]]) {
	[[[RSFill alloc] initWithGraph:graph identifier:identifier] autorelease];
    }
    else if ([name isEqualToString:[RSTextLabel xmlElementName]]) {
	[[[RSTextLabel alloc] initWithGraph:graph identifier:identifier] autorelease];
    }
    else if ([name isEqualToString:[RSGroup xmlElementName]]) {
	[[[RSGroup alloc] initWithGraph:graph identifier:identifier] autorelease];
    }
}

static void allocAndRegisterObject(OFXMLElement *element, void *context)
{
    RSGraph *graph = context;
    
    // Retrieve the identifier as specified in the XML archive
    NSString *identifier = [element attributeNamed:@"id"];
    
    // If we're in an import-from-pasteboard context, we might have to adjust the identifier to avoid collisions with identifiers in the active graph.
    NSMutableDictionary *idMap = graph.idPasteMap;
    if (idMap) {
        
        OBASSERT(![idMap objectForKey:identifier]);  // Don't register any unarchived object more than once (and all objects in an archive should have unique identifiers)
        
        if ([graph containsObjectForIdentifier:identifier]) {
            // Make a new identifier to avoid a collision
            NSString *newIdentifier = [graph generateIdentifier];
            [idMap setObject:newIdentifier forKey:identifier];
            identifier = newIdentifier;
            DEBUG_XML(@"Made new identifier: %@", identifier);
        }
    }
    
    return allocAndRegisterObjectWithIdentifier(element, identifier, context);
}



- (BOOL)readContentsXML:(OFXMLCursor *)cursor error:(NSError **)outError;
{
    OBPRECONDITION(OFISEQUAL([cursor name], [[self class] xmlElementName]));
    
    //
    // First, read in all elements and allocate/register them.
    OFXMLElement *graphRootElement = [cursor currentElement];
    [graphRootElement applyFunction:allocAndRegisterObject context:self];
    
    
    //
    // Second, traverse the document with the cursor to read all properties.
    
    // canvas
    if ([cursor openNextChildElementNamed:@"canvas"]) {
	[self readCanvasXML:cursor error:outError];
	[cursor closeElement];
    }
    
    // graph elements
    OFXMLElement *element = nil;
    while ( (element = [cursor nextChild]) ) {
	[cursor openElement];
	OFXMLElement *child = [cursor currentElement];
	NSString *name = [child name];
	
	DEBUG_XML(@"Reading element '%@'", name);
	
	NSString *childIdentifier = [child attributeNamed:@"id"];
	
	if ([name isEqualToString:[RSAxis xmlElementName]]) {
	    NSString *dimension = [child attributeNamed:@"dimension"];
	    if (!dimension) {
		NSLog(@"%s: Element %@ at cursor path %@ is missing attribute 'dimension'", __PRETTY_FUNCTION__, element, [cursor currentPath]);
	    }
	    RSAxis *A = [self objectForIdentifier:childIdentifier];
	    [A readContentsXML:cursor error:outError];
	    if ([dimension isEqualToString:@"x"]) {
		[self setAxis:A forOrientation:RS_ORIENTATION_HORIZONTAL];
	    }
	    else if ([dimension isEqualToString:@"y"]) {
		[self setAxis:A forOrientation:RS_ORIENTATION_VERTICAL];
	    }
	    else {
		NSLog(@"%s: Element %@ at cursor path %@ has unknown value %@ for attribute 'dimension'", __PRETTY_FUNCTION__, element, [cursor currentPath], dimension);
	    }
	}
	else if ([name isEqualToString:[RSVertex xmlElementName]]) {
	    RSVertex *V = [self objectForIdentifier:childIdentifier];
	    if ([V readContentsXML:cursor error:outError]) {
		[self addVertex:V];
	    }
	}
	else if([name isEqualToString:[RSLine xmlElementName]]) {
	    RSLine *L = [self objectForIdentifier:childIdentifier];
	    if ([L readContentsXML:cursor error:outError]) {
		[self addLine:L];
	    }
	}
	else if ([name isEqualToString:[RSFill xmlElementName]]) {
	    RSFill *F = [self objectForIdentifier:childIdentifier];
	    if ([F readContentsXML:cursor error:outError]) {
		[self addFill:F];
	    }
	}
	// Text Labels
	else if([name isEqualToString:[RSTextLabel xmlElementName]]) {
	    RSTextLabel *TL = [self objectForIdentifier:childIdentifier];
	    if ([TL readContentsXML:cursor error:outError]) {
		if (![TL isPartOfAxis]) {
		    [self addLabel:TL];
		}
	    }
	}
	// Groups
	else if([name isEqualToString:[RSGroup xmlElementName]]) {
	    RSGroup *G = [self objectForIdentifier:childIdentifier];
	    [G readContentsXML:cursor error:outError];
	}
	else {
	    NSLog(@"%s: Unable to read element %@ at cursor path %@", __PRETTY_FUNCTION__, element, [cursor currentPath]);
	}
	
	
	// groups
	
	[cursor closeElement];
    }
    
    //
    // Potentially make updates if an old version of the app created this file
    //
    OFVersionNumber *versionNumberOfNonePointTypeChange = [[[OFVersionNumber alloc] initWithVersionString:@"10.0.0"] autorelease];
    if ([[RSGraphElement appVersionOfImportedFile] compareToVersionNumber:versionNumberOfNonePointTypeChange] == NSOrderedAscending) {
        [self updateNonePointTypes];
    }
    
    // A bug in XML writing caused no textlabels to ever be labeled visible=NO. We'll just mark all of the tick labels as invisible (the axis layout code will reset the visibility flag for labels that actually should be visible).
    [_xAxis resetUserLabelVisibility];
    [_yAxis resetUserLabelVisibility];
    
    return YES;
}

- (BOOL)writeContentsXML:(OFXMLDocument *)xmlDoc error:(NSError **)outError;
{
    // canvas
    [self writeCanvasXML:xmlDoc error:outError];
    
    // axes & grids
    [[self xAxis] writeContentsXML:xmlDoc error:outError];
    [[self yAxis] writeContentsXML:xmlDoc error:outError];
    
    // graph elements
    for (RSVertex *V in Vertices) {
	[V writeContentsXML:xmlDoc error:outError];
    }
    for (RSLine *L in Lines) {
	[L writeContentsXML:xmlDoc error:outError];
    }
    for (RSFill *F in Fills) {
	[F writeContentsXML:xmlDoc error:outError];
    }
    for (RSTextLabel *TL in [self allLabels]) {
	[TL writeContentsXML:xmlDoc error:outError];
    }
    
    // groups
    for (RSGroup *G in [self groups]) {
	[G writeContentsXML:xmlDoc error:outError];
    }
    
    return YES;
}

- (NSArray *)childObjectsForXML;
{
    return nil;
}


#pragma mark -
#pragma mark Archiving for pasteboards

+ (NSString *)_pasteboardXMLElementName;
{
    return @"model";
}

static NSInteger verticesFirstSort(id obj1, id obj2, void *context)
{
    BOOL isVertex1 = [obj1 isKindOfClass:[RSVertex class]];
    BOOL isVertex2 = [obj2 isKindOfClass:[RSVertex class]];
    
    if (isVertex1 && !isVertex2)
        return NSOrderedAscending;
    else if (!isVertex1 && isVertex2)
        return NSOrderedDescending;
    else
        return NSOrderedSame;
}

+ (void)_appendElementAndChildren:(NSArray *)elements toArray:(NSMutableArray *)result;
{
    for (RSGraphElement *element in elements) {
        // If the element has already been added, don't add it again
        if ([result indexOfObjectIdenticalTo:element] != NSNotFound)
            continue;
        
        [result addObject:element];
        
        // Now process any children elements (objects that 'element' depends on)
        if ([element respondsToSelector:@selector(childObjectsForXML)]) {
            NSArray *children = [(id)element childObjectsForXML];
            if (!children)
                continue;
            
            [RSGraph _appendElementAndChildren:children toArray:result];
        }
    }
    
    // Vertices need to go first (otherwise, vertex parent unarchiving doesn't work right).
    [result sortUsingFunction:verticesFirstSort context:NULL];
}

+ (void)_appendGroupsToArray:(NSMutableArray *)result;
{
    NSMutableSet *groups = [NSMutableSet set];
    for (RSGraphElement *GE in result) {
        RSGroup *group = [GE group];
        if (group && ![groups containsObject:group]) {
            [groups addObject:group];
        }
    }
    
    for (RSGroup *group in groups) {
        [result addObject:group];
    }
}

+ (NSData *)archivedDataWithRootObject:(RSGraphElement *)GE graphID:(NSString *)graphID error:(NSError **)outError;
{
    if (outError)
        *outError = nil;
    
    OFXMLDocument *doc = [RSGraph xmlDocumentWrapperWithError:outError];
    if (!doc)
        return nil;
    
    OFXMLElement *rootElement = [doc rootElement];
    [rootElement setAttribute:@"graph-id" string:graphID];
    
    // Compile array of elements that must be archived
    NSMutableArray *result = [NSMutableArray array];
    [RSGraph _appendElementAndChildren:[GE elements] toArray:result];
    [RSGraph _appendGroupsToArray:result];
    
    // Start creating XML
    [doc pushElement:[RSGraph _pasteboardXMLElementName]];
    
    BOOL success = YES;
    for (RSGraphElement *GE in result) {
        DEBUG_XML(@"archiving [%@]", GE.shortDescription);
        success = [(id)GE writeContentsXML:doc error:outError];
        
        if (!success) {
            return nil;
        }
    }
    
    [doc popElement];  // </model>
    
    return [doc xmlData:outError];
}

- (RSGraphElement *)_unarchiveGraphElementFromXML:(OFXMLCursor *)cursor error:(NSError **)outError;
{
    // Set up a mapping from archived identifiers to new identifiers in the active graph
    self.idPasteMap = [NSMutableDictionary dictionary];
    
    //
    // First, read in all elements and allocate/register them.
    OFXMLElement *graphRootElement = [cursor currentElement];
    [graphRootElement applyFunction:allocAndRegisterObject context:self];
    
    
    //
    // Second, traverse the document with the cursor to read all properties.
    
    // graph elements
    RSGroup *all = [RSGroup groupWithGraph:self];
    OFXMLElement *element = nil;
    while ( (element = [cursor nextChild]) ) {
	[cursor openElement];
	OFXMLElement *child = [cursor currentElement];
	NSString *name = [child name];
	
	DEBUG_XML(@"Reading element '%@'", name);
	
	NSString *childIdentifier = [child attributeNamed:@"id"];
	
	if ([name isEqualToString:[RSVertex xmlElementName]]) {
	    RSVertex *V = [self objectForIdentifier:childIdentifier];
	    if ([V readContentsXML:cursor error:outError]) {
                [all addElement:V];
	    }
	}
	else if([name isEqualToString:[RSLine xmlElementName]]) {
	    RSLine *L = [self objectForIdentifier:childIdentifier];
	    if ([L readContentsXML:cursor error:outError]) {
                [all addElement:L];
	    }
	}
	else if ([name isEqualToString:[RSFill xmlElementName]]) {
	    RSFill *F = [self objectForIdentifier:childIdentifier];
	    if ([F readContentsXML:cursor error:outError]) {
                [all addElement:F];
	    }
	}
	// Text Labels
	else if([name isEqualToString:[RSTextLabel xmlElementName]]) {
	    RSTextLabel *TL = [self objectForIdentifier:childIdentifier];
	    if ([TL readContentsXML:cursor error:outError]) {
		if (![TL isPartOfAxis]) {
                    [all addElement:TL];
		}
	    }
	}
	// Groups
	else if([name isEqualToString:[RSGroup xmlElementName]]) {
	    RSGroup *G = [self objectForIdentifier:childIdentifier];
	    [G readContentsXML:cursor error:outError];
	}
	else {
	    NSLog(@"%s: Unable to read element %@ at cursor path %@", __PRETTY_FUNCTION__, element, [cursor currentPath]);
	}
	
	
	[cursor closeElement];
    }
    
    // Finished with identifier mapping
    self.idPasteMap = nil;
    
    return all;
}

- (RSGraphElement *)unarchiveObjectWithData:(NSData *)data getGraphID:(NSString **)graphID error:(NSError **)outError;
{
    OFXMLDocument *doc = [[[OFXMLDocument alloc] initWithData:data whitespaceBehavior:_whitespaceBehavior() error:outError] autorelease];
    if (!doc)
        return nil;
    OFXMLCursor *cursor = [[[OFXMLCursor alloc] initWithDocument:doc] autorelease];
    
    if (graphID != NULL) {
        *graphID = [[doc rootElement] attributeNamed:@"graph-id"];
    }
    
    OBASSERT([[[doc rootElement] name] isEqualToString:XMLRootElementName]);
    
    if ([cursor openNextChildElementNamed:[RSGraph _pasteboardXMLElementName]]) {
        OBPRECONDITION(OFISEQUAL([cursor name], [RSGraph _pasteboardXMLElementName]));
        
        return [self _unarchiveGraphElementFromXML:cursor error:outError];
    }
    return nil;
}


@end
