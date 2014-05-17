// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <ApplicationServices/ApplicationServices.h>
#import <CoreFoundation/CoreFoundation.h>
#import <CoreServices/CoreServices.h> 
#import <dlfcn.h>

#import <OmniUnzip/OUUnzipArchive.h>
#import <OmniUnzip/OUUnzipEntry.h>
#import <libxml/SAX2.h>
#import <libxml/parser.h>

#if 0 && defined(DEBUG)
    #define DEBUG_LOG(format, ...) NSLog((format), ## __VA_ARGS__)
#else
    #define DEBUG_LOG(format, ...)
#endif

#import "XMLHelpers.h"
#import "CFHelpers.h"
#import "GetMetadataForFile.h"

/*
 TODO:
 
 - Maybe only log checked item count if the status column is visible
 
 -- Map document title to kMDItemTitle
 
 */

typedef struct _ParserContext {
    xmlParserCtxtPtr ctxt;

    NSCharacterSet *nonWhitespaceCharacterSet;
    
    Boolean             inStringLiteral;

    CFMutableDictionaryRef attributes;
    CFMutableStringRef     textContent;
    
    CFMutableArrayRef      elementNameStack;
    CFMutableStringRef     currentText;
    CFMutableArrayRef      currentTextArray;
#if 0
    
    CFMutableStringRef     documentTitle;
    CFMutableArrayRef      namedStyleNames;
    unsigned int           columnCount;
    CFMutableArrayRef      columnTitles;
    Boolean                inDocumentElement;
    Boolean                inRootElement;
    unsigned int           itemCount;
    unsigned int           itemDepth, maxItemDepth;
    unsigned int           uncheckedCount, checkedCount, indeterminateCount;
    unsigned int           cellCount;
#endif
} ParserContext;


////////////////////////////////////////////////////////////////////////////
#pragma mark -

static Boolean _stringIsAFloat(NSString *string)
{
    NSScanner *scanner = [NSScanner localizedScannerWithString:string];
    
    float floatVal;
    BOOL scannedFloat = [scanner scanFloat:&floatVal];
    BOOL isAtEnd = [scanner isAtEnd];
    
    if( scannedFloat && isAtEnd ) {
	return TRUE;
    }
    return FALSE;
}

////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark XML parser callback functions

static void _startElementNsSAX2Func(void *userData, const xmlChar *localname, const xmlChar *prefix, const xmlChar *URI, int nb_namespaces, const xmlChar **namespaces, int nb_attributes, int nb_defaulted, const xmlChar **attributes)
{
    DEBUG_LOG(@"Starting element '%s'", localname);
    
    ParserContext *ctx = userData;
    
    const char *lit = "lit";
    if ( strcmp((const char*)localname, lit) == 0 ) {  // "equal strings"
        ctx->inStringLiteral = TRUE;
    } else {
        ctx->inStringLiteral = FALSE;
    }
}

static void _endElementNsSAX2Func(void *userData, const xmlChar *localname, const xmlChar *prefix, const xmlChar *URI)
{
    DEBUG_LOG(@"Ending element '%s'", localname);
}

static void _charactersSAXFunc(void *userData, const xmlChar *ch, int len)
// Callback for when non-element characters are found, i.e. the "stuff" in "<element>stuff</element>".
{
    ParserContext *ctx = userData;
    
    if ( !(ctx->inStringLiteral) ) {
        // For now, ignore all strings that are not inside <lit></lit> tags.
        return;
    }

    NSString *str = [[NSString alloc] initWithBytes:ch length:len encoding:NSUTF8StringEncoding];
    if (!str) {
        DEBUG_LOG(@"Unable to create string from UTF-8 bytes in SAX callback.");
        return;
    }
    
    if ([str rangeOfCharacterFromSet:ctx->nonWhitespaceCharacterSet].length == 0) {
        // Ignore strings that are just whitespace
        ;
    }
    else if (_stringIsAFloat(str)) {
        // For now, ignore all strings that are just numbers (these are most likely tick labels)
        ;
    }
    else {
        // If made it this far, append to keywords
        CFStringAppend(ctx->textContent, (CFStringRef)str);
        CFStringAppend(ctx->textContent, CFSTR(" "));
        DEBUG_LOG(@"  Text: %@", str);
    }
    
    [str release];
}

static void _ignorableWhitespace(void *userData, const xmlChar *ch, int len)
{
    // ignore, duh.
}

static void _xmlStructuredErrorFunc(void *userData, xmlErrorPtr error)
{
    ParserContext *ctx = userData;

    DEBUG_LOG(@"XML parse error domain:%d code:%d message:%s line:%d", error->domain, error->code, error->message, error->line);
    
    if (error->str1) {
        DEBUG_LOG(@"  str1: %s", error->str1);
    }
    if (error->str2) {
        DEBUG_LOG(@"  str1: %s", error->str2);
    }
    if (error->str3) {
        DEBUG_LOG(@"  str1: %s", error->str3);
    }

    if (error->int1) {
        DEBUG_LOG(@"  int1: %d", error->int1);
    }
    if (error->int2) {
        DEBUG_LOG(@"  int1: %d", error->int2);
    }

    if (error->level == XML_ERR_WARNING)
        return;

    OBASSERT(error->level == XML_ERR_ERROR || error->level == XML_ERR_FATAL);
    xmlStopParser(ctx->ctxt);
}


////////////////////////////////////////////////////////////////////////////
#pragma mark -

#if 0
static void ParserContextAppendText(ParserContext *ctx, CFStringRef str)
{
    if (ctx->currentText)
	CFStringAppend(ctx->currentText, str);
}

static void ParserContextAppendSpace(ParserContext *ctx)
{
    CFMutableStringRef txt = ctx->currentText ? ctx->currentText : ctx->textContent;
    if (CFStringGetLength(txt))
	CFStringAppend(txt, CFSTR(" "));
}
#endif

#if 0
static bool ParserContextElementPathHasSuffix(ParserContext *ctx, CFArrayRef suffix)
{
    assert(CFArrayGetCount(suffix));
    
    CFIndex suffixLength = CFArrayGetCount(suffix);
    CFIndex pathLength = CFArrayGetCount(ctx->elementNameStack);
    
    if (suffixLength > pathLength)
	return FALSE;
    
    unsigned int suffixIndex;
    for (suffixIndex = 0; suffixIndex < suffixLength; suffixIndex++) {
	if (!CFEqual(CFArrayGetValueAtIndex(suffix, suffixIndex),
		     CFArrayGetValueAtIndex(ctx->elementNameStack, pathLength - suffixLength + suffixIndex)))
	    return FALSE;
    }
    return TRUE;
}
#endif

#if 0
static bool ParserContextElementOnStack(ParserContext *ctx, CFStringRef elementName)
{
    assert(elementName);
    
    CFIndex pathIndex = CFArrayGetCount(ctx->elementNameStack);
    while (pathIndex--)
	if (CFEqual(CFArrayGetValueAtIndex(ctx->elementNameStack, pathIndex), elementName))
	    return TRUE;
    return FALSE;
}

static void AddIntAttribute(CFMutableDictionaryRef attributes, CFStringRef key, unsigned int value)
{
    CFNumberRef number = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &value);
    CFDictionarySetValue(attributes, key, number);
    CFRelease(number);
}

enum ElementType {
    // First must be non-zero since that means to skip the element
    Element_SKIP = 0,
    Element_outline,
    Element_column,
    Element_root,
    Element_item,
    Element_p,
    Element_text,
    Element_other,
};

static void *_createXMLStructure(CFXMLParserRef parser, CFXMLNodeRef nodeDesc, void *info)
{
    ParserContext *ctx = (ParserContext *)info;
    
    switch (CFXMLNodeGetTypeCode(nodeDesc)) {
	case kCFXMLNodeTypeDocument:
	    return NULL;
	case kCFXMLNodeTypeElement: {
	    CFStringRef elementName = CFXMLNodeGetString(nodeDesc);
	    const CFXMLElementInfo *elementInfo = CFXMLNodeGetInfoPtr(nodeDesc);
	    enum ElementType elementType = Element_SKIP;
	    
	    //DEBUG_LOG(@"start %@", elementName);
	    
	    if (CFEqual(elementName, CFSTR("outline"))) {
		ctx->inDocumentElement = TRUE;
		elementType = Element_outline;
	    } else if (CFEqual(elementName, CFSTR("root")))
		elementType = Element_root;
	    else if (CFEqual(elementName, CFSTR("item"))) {
		if (elementInfo->attributes) {
		    CFStringRef state = CFDictionaryGetValue(elementInfo->attributes, CFSTR("state"));
		    if (!state || CFEqual(state, CFSTR("unchecked")))
			ctx->uncheckedCount++;
		    else if (state && CFEqual(state, CFSTR("checked")))
			ctx->checkedCount++;
		    else if (state && CFEqual(state, CFSTR("indeterminate")))
			ctx->indeterminateCount++;
		}
		ctx->itemCount++;
		ctx->itemDepth++;
		ctx->maxItemDepth = MAX(ctx->maxItemDepth, ctx->itemDepth);
		elementType = Element_item;
	    } else if (CFEqual(elementName, CFSTR("note")))
		elementType = Element_other;
	    else if (CFEqual(elementName, CFSTR("columns")))
		elementType = Element_other;
	    else if (CFEqual(elementName, CFSTR("column"))) {
		ctx->columnCount++;
		elementType = Element_column;
	    } else if (CFEqual(elementName, CFSTR("title")))
		elementType = Element_other;
	    else if (CFEqual(elementName, CFSTR("values")))
		elementType = Element_other;
	    else if (CFEqual(elementName, CFSTR("outline-title")))
		elementType = Element_other;
	    else if (CFEqual(elementName, CFSTR("text"))) {
		elementType = Element_text;
		assert(ctx->currentText == NULL);
		assert(ctx->currentTextArray == NULL);
		if (ParserContextElementOnStack(ctx, CFSTR("column"))) {
		    ctx->currentText = CFStringCreateMutable(kCFAllocatorDefault, 0);
		    ctx->currentTextArray = (CFMutableArrayRef)CFRetain(ctx->columnTitles);
		} else if (ParserContextElementOnStack(ctx, CFSTR("values")) ||
			   ParserContextElementOnStack(ctx, CFSTR("note")))
		    ctx->currentText = (CFMutableStringRef)CFRetain(ctx->textContent);
		else if (ParserContextElementOnStack(ctx, CFSTR("outline-title")))
		    ctx->currentText = (CFMutableStringRef)CFRetain(ctx->documentTitle);
	    } else if (CFEqual(elementName, CFSTR("p"))) {
		ParserContextAppendSpace(ctx);
		elementType = Element_p;
	    } else if (CFEqual(elementName, CFSTR("run")))
		elementType = Element_other;
	    else if (CFEqual(elementName, CFSTR("lit")))
		elementType = Element_other;
	    else if (CFEqual(elementName, CFSTR("cell")))
		ctx->cellCount++;
	    else if (CFEqual(elementName, CFSTR("children")))
		elementType = Element_other;
	    else if (CFEqual(elementName, CFSTR("named-styles")))
		elementType = Element_other;
	    else if (CFEqual(elementName, CFSTR("named-style"))) {
		CFStringRef name = CFDictionaryGetValue(elementInfo->attributes, CFSTR("name"));
		CFArrayAppendValue(ctx->namedStyleNames, name);
	    }
            
	    if (elementType != Element_SKIP)
		CFArrayAppendValue(ctx->elementNameStack, elementName);
	    return (void *)elementType;
	}
	case kCFXMLNodeTypeText:
	    ParserContextAppendText(ctx, CFXMLNodeGetString(nodeDesc));
	    return NULL;
        case kCFXMLNodeTypeEntityReference: {
            const CFXMLEntityReferenceInfo *entityInfo = CFXMLNodeGetInfoPtr(nodeDesc);
	    
	    // Ignore text outside of the root element
	    if (!ctx->inDocumentElement)
		return NULL;
	    
	    CFStringRef str = CFXMLNodeGetString(nodeDesc);
	    if (entityInfo->entityType == kCFXMLEntityTypeParsedInternal) {
		CFStringRef replacement = GetReplacmentForInternalEntityName(str);
		if (replacement)
		    ParserContextAppendText(ctx, replacement); // replacement is 'autoreleased'
            } else if (entityInfo->entityType == kCFXMLEntityTypeCharacter) {
		CFStringRef replacement = CreateEntityReplacementStringForCharacterEntity(parser, str);
		if (replacement) {
		    ParserContextAppendText(ctx, replacement);
		    CFRelease(replacement);
		}
	    } else {
		// We should opt out on this on a case by case basis
		DEBUG_LOG(@"typeCode:%d entityType=%d string:%@", kCFXMLNodeTypeEntityReference, entityInfo->entityType, str);
	    }
	    return NULL;
	}
	case kCFXMLNodeTypeWhitespace:
	    return NULL;
	default:
	    DEBUG_LOG(@"ignoring node of type %d -- %@", CFXMLNodeGetTypeCode(nodeDesc), CFXMLNodeGetString(nodeDesc));
	    return NULL;
    }
}

static void _addChild(CFXMLParserRef parser, void *parent, void *child, void *info)
{
}

static void _endXMLStructure(CFXMLParserRef parser, void *xmlType, void *info)
{
    ParserContext *ctx = (ParserContext *)info;
    
    switch ((int)xmlType) {
	case Element_outline:
	    ctx->inDocumentElement = FALSE;
	    break;
	case Element_column:
	    if (ctx->currentText) {
		if (CFStringGetLength(ctx->currentText))
		    CFArrayAppendValue(ctx->columnTitles, ctx->currentText);
		CFRelease(ctx->currentText);
		ctx->currentText = NULL;
	    }
	case Element_root:
	    ctx->inRootElement = FALSE;
	    break;
	case Element_item:
	    ParserContextAppendText(ctx, CFSTR("\n"));
	    ctx->itemDepth--;
	    break;
	case Element_text:
	    if (ctx->currentText) {
		if (ctx->currentTextArray) {
		    if (CFStringGetLength(ctx->currentText))
			CFArrayAppendValue(ctx->currentTextArray, ctx->currentText);
		    CFRelease(ctx->currentTextArray);
		    ctx->currentTextArray = NULL;
		}
		CFRelease(ctx->currentText);
		ctx->currentText = NULL;
	    }
	    break;
	case Element_p:
	case Element_other:
	    break;
	default:
	    DEBUG_LOG(@"Ended element with xmlType=%p", xmlType);
	    break;
    }
    
    assert(CFArrayGetCount(ctx->elementNameStack));
    CFArrayRemoveValueAtIndex(ctx->elementNameStack, CFArrayGetCount(ctx->elementNameStack) - 1);
}

static CFDataRef _resolveExternalEntity(CFXMLParserRef parser, CFXMLExternalID *extID, void *info)
{
    return NULL;
}

static Boolean _handleError(CFXMLParserRef parser, CFXMLParserStatusCode error, void *info)
{
    DEBUG_LOG(@"XML parser error: %ld", error);
    return FALSE;
}
#endif

// Might want to have a metadata inspector in OGS and save another zip entry for this.
#if 0
static void _dictionarySetValueApplier(const void *key, const void *value, void *context)
{
    CFDictionarySetValue((CFMutableDictionaryRef)context, key, value);
}

// Presumes we are a wrapped file; check for a metadata.xml file inside the wrapper
static void _addBaseMetadata(CFMutableDictionaryRef attributes, CFStringRef pathToFile)
{
    CFMutableStringRef metadataPath = CFStringCreateMutableCopy(kCFAllocatorDefault, 0, pathToFile);
    CFStringAppend(metadataPath, CFSTR("/metadata.xml"));
    CFURLRef metadataURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, metadataPath, kCFURLPOSIXPathStyle, false);
    CFRelease(metadataPath);
    DEBUG_LOG(@"  Base metadata url is '%@'", metadataURL);
    
    CFDataRef plistData = NULL;
    SInt32 errorCode;
    if (!CFURLCreateDataAndPropertiesFromResource(kCFAllocatorDefault, metadataURL, &plistData, NULL/*properties*/, NULL/*desiredProperties*/, &errorCode)) {
#if 0 // This report kCFURLUnknownError instead of kCFURLResourceNotFoundError when there is no such file.
	DEBUG_LOG(@"CFURLCreateDataAndPropertiesFromResource failed for '%@', errorCode = %d", metadataURL, errorCode);
#endif
	return;
    }
    
    CFStringRef errorString = NULL;
    CFDictionaryRef plist = CFPropertyListCreateFromXMLData(kCFAllocatorDefault, plistData, kCFPropertyListImmutable, &errorString);
    CFRelease(plistData);
    
    if (!plist) {
	DEBUG_LOG(@"CFPropertyListCreateFromXMLData failed for '%@'", metadataURL);
	if (errorString) {
	    DEBUG_LOG(@"   error = %@", errorString);
	    CFRelease(errorString);
	}
	return;
    }
    
    if (CFGetTypeID(plist) != CFDictionaryGetTypeID())
	DEBUG_LOG(@"Expected a dictionary in '%@', but got something with a type id of %d", metadataURL, CFGetTypeID(plist));
    else
	CFDictionaryApplyFunction(plist, _dictionarySetValueApplier, attributes);
    CFRelease(plist);
}
#endif



static void ParserContextFree(ParserContext *parseContext)
{
    if (parseContext->ctxt)
        xmlFreeParserCtxt(parseContext->ctxt);
    
#if 0
#define RELEASE(x) if (ctx->x) { CFRelease(ctx->x); ctx->x = NULL; }
    // Don't release attributes -- that is owned by the caller
    
    RELEASE(elementNameStack);
    RELEASE(currentText);
    RELEASE(textContent);
    RELEASE(documentTitle);
    RELEASE(namedStyleNames);
    RELEASE(columnTitles);
#endif    
    [parseContext->nonWhitespaceCharacterSet release];

    free(parseContext);
}

static ParserContext *ParserContextCreate(CFMutableDictionaryRef attributes, NSData *xmlData)
{
    ParserContext *parseContext = calloc(1, sizeof(*parseContext));

    parseContext->attributes = attributes;
    
    xmlSAXHandler sax;
    memset(&sax, 0, sizeof(sax));
    
    sax.initialized = XML_SAX2_MAGIC; // Use the SAX2 callbacks
    
    sax.characters = _charactersSAXFunc;
    sax.ignorableWhitespace = _ignorableWhitespace;
    sax.startElementNs = _startElementNsSAX2Func;
    sax.endElementNs = _endElementNsSAX2Func;
    sax.serror = _xmlStructuredErrorFunc;
    
    // xmlSAXUserParseMemory hides the xmlParserCtxtPtr.  But, this means we can't get the source encoding, so we use the push approach.
    NSUInteger xmlDataLength = [xmlData length];
    if (xmlDataLength > INT_MAX) {
        DEBUG_LOG(@"Data too long.");
        ParserContextFree(parseContext);
        return NULL;
    }
    
    parseContext->ctxt = xmlCreatePushParserCtxt(&sax, parseContext, [xmlData bytes], (int)xmlDataLength, NULL);
    if (!parseContext->ctxt) {
        DEBUG_LOG(@"Unable to create XML parser.");
        ParserContextFree(parseContext);
        return NULL;
    }
    
    int options = XML_PARSE_NOENT; // Turn entities into content
    options |= XML_PARSE_NONET; // don't allow network access
    options |= XML_PARSE_NSCLEAN; // remove redundant namespace declarations
    options |= XML_PARSE_NOCDATA; // merge CDATA as text nodes
    options = xmlCtxtUseOptions(parseContext->ctxt, options);
    if (options != 0)
        NSLog(@"unsupported options %d", options);

    parseContext->textContent = CFStringCreateMutable(kCFAllocatorDefault, 0);
    parseContext->nonWhitespaceCharacterSet = [[[NSCharacterSet whitespaceAndNewlineCharacterSet] invertedSet] copy];

#if 0
    parseContext->elementNameStack = CFArrayCreateMutable(kCFAllocatorDefault, 0, &OFCFTypeArrayCallbacks);
    parseContext->documentTitle = CFStringCreateMutable(kCFAllocatorDefault, 0);
    parseContext->namedStyleNames = CFArrayCreateMutable(kCFAllocatorDefault, 0, &OFCFTypeArrayCallbacks);
    parseContext->columnTitles = CFArrayCreateMutable(kCFAllocatorDefault, 0, &OFCFTypeArrayCallbacks);
#endif
    
    return parseContext;
}

static Boolean _addMetadataFromXML(CFMutableDictionaryRef attributes, NSData *xmlData)
{
    ParserContext *parseContext = ParserContextCreate(attributes, xmlData);
    if (!parseContext)
        return FALSE;
        
    // Encoding isn't set until after the terminate.
    int rc = xmlParseChunk(parseContext->ctxt, NULL, 0, TRUE/*terminate*/);
    if (rc != 0) {
        DEBUG_LOG(@"XML parser returned %d.", rc);
    }
    
    CFDictionarySetValue(attributes, kMDItemTextContent, parseContext->textContent);
#if 0
    CFDictionarySetValue(attributes, kMDItemTitle, parseContext->documentTitle);
    //DEBUG_LOG(@"textContent = %@", parseContext->textContent);
    
    
    CFDictionarySetValue(attributes, CFSTR("com_omnigroup_OmniOutliner_NamedStyles"), parseContext->namedStyleNames);
    AddIntAttribute(attributes, CFSTR("com_omnigroup_OmniOutliner_NamedStyleCount"), CFArrayGetCount(parseContext->namedStyleNames));
    
    CFDictionarySetValue(attributes, CFSTR("com_omnigroup_OmniOutliner_ColumnTitles"), parseContext->columnTitles);
    AddIntAttribute(attributes, CFSTR("com_omnigroup_OmniOutliner_ColumnCount"), parseContext->columnCount); // Not count-of columnTitles since that doesn't include columns with empty titles
    
    AddIntAttribute(attributes, CFSTR("com_omnigroup_OmniOutliner_ItemCount"), parseContext->itemCount);
    AddIntAttribute(attributes, CFSTR("com_omnigroup_OmniOutliner_UncheckedItemCount"), parseContext->uncheckedCount);
    AddIntAttribute(attributes, CFSTR("com_omnigroup_OmniOutliner_CheckedItemCount"), parseContext->checkedCount);
    AddIntAttribute(attributes, CFSTR("com_omnigroup_OmniOutliner_IndeterminateItemCount"), parseContext->indeterminateCount);
    AddIntAttribute(attributes, CFSTR("com_omnigroup_OmniOutliner_MaxItemDepth"), parseContext->maxItemDepth);
    
    AddIntAttribute(attributes, CFSTR("com_omnigroup_OmniOutliner_CellCount"), parseContext->cellCount);
    
#endif
    
    
    ParserContextFree(parseContext);

    return (rc == 0);
}

/* -----------------------------------------------------------------------------
   Step 1
   Set the UTI types the importer supports
  
   Modify the CFBundleDocumentTypes entry in Info.plist to contain
   an array of Uniform Type Identifiers (UTI) for the LSItemContentTypes 
   that your importer can handle
  
   ----------------------------------------------------------------------------- */

/* -----------------------------------------------------------------------------
   Step 2 
   Implement the GetMetadataForFile function
  
   Implement the GetMetadataForFile function below to scrape the relevant
   metadata from your document and return it as a CFDictionary using standard keys
   (defined in MDItem.h) whenever possible.
   ----------------------------------------------------------------------------- */

/* -----------------------------------------------------------------------------
   Step 3 (optional) 
   If you have defined new attributes, update the schema.xml file
  
   Edit the schema.xml file to include the metadata keys that your importer returns.
   Add them to the <allattrs> and <displayattrs> elements.
  
   Add any custom types that your importer requires to the <attributes> element
  
   <attribute name="com_mycompany_metadatakey" type="CFString" multivalued="true"/>
  
   ----------------------------------------------------------------------------- */



/* -----------------------------------------------------------------------------
    Get metadata attributes from file
   
   This function's job is to extract useful information your file format supports
   and return it as a dictionary
   ----------------------------------------------------------------------------- */

Boolean GetMetadataForFile(void* thisInterface, 
			   CFMutableDictionaryRef attributes, 
			   CFStringRef contentTypeUTI,
			   CFStringRef pathToFile)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
#ifdef DEBUG
    Dl_info info;
    memset(&info, 0, sizeof(info));
    if (dladdr(GetMetadataForFile, &info) == 0) {
        DEBUG_LOG(@"Unable to find bundle.");
    }
    
    DEBUG_LOG(@"Generating metadata for \"%@\", contentTypeUTI = %@ using bundle %s", pathToFile, contentTypeUTI, info.dli_fname);
#endif
    
    LIBXML_TEST_VERSION
    
    @try {
        OUUnzipArchive *zipArchive = [[[OUUnzipArchive alloc] initWithPath:(NSString *)pathToFile error:nil] autorelease];
        if (zipArchive) {
            OUUnzipEntry *zipEntry = [zipArchive entryNamed:@"contents.xml"];
            if (!zipEntry) {
                // Terrible news!
                DEBUG_LOG(@"Cannot find XML in \"%@\".", pathToFile);
                return FALSE;
            }
            
            NSError *error = nil;
            NSData *xmlData = [zipArchive dataForEntry:zipEntry error:&error];
            if (!xmlData) {
                DEBUG_LOG(@"Cannot extract XML from \"%@\" -- %@", pathToFile, [error description]);
                return FALSE;
            }
            
            if (!_addMetadataFromXML(attributes, xmlData)) {
                DEBUG_LOG(@"Cannot parse XML from \"%@\"", pathToFile);
                return FALSE;
            }
        }
    } @catch (NSException *exc) {
	NSLog(@"Caught exception while indexing '%@' -- '%@'", pathToFile, exc);
    } @finally {
        [pool release];
    }
    
    return TRUE;
}
