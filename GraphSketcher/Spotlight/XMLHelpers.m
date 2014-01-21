// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/Spotlight/XMLHelpers.m 200244 2013-12-10 00:11:55Z correia $

#import "XMLHelpers.h"

#if 0
/* General string utilities for dealing with surrogate pairs (UTF-16 encodings of UCS-4 characters) */
enum OFIsSurrogate {
    OFIsSurrogate_No = 0,
    OFIsSurrogate_HighSurrogate = 1,
    OFIsSurrogate_LowSurrogate = 2
};


/* Determines whether a given 16-bit unichar is part of a surrogate pair */
static inline enum OFIsSurrogate OFCharacterIsSurrogate(UniChar ch)
{
    /* The surrogate ranges are conveniently lined up on power-of-two boundaries.
    ** Since the common case is that a character is not a surrogate at all, we
    ** test for that first.
    */
    if ((ch & 0xF800) == 0xD800) {
        if ((ch & 0x0400) == 0)
            return OFIsSurrogate_HighSurrogate;
        else
            return OFIsSurrogate_LowSurrogate;
    } else
        return OFIsSurrogate_No;
}

static inline void OFCharacterToSurrogatePair(UnicodeScalarValue inCharacter, UniChar *outUTF16)
{
    UnicodeScalarValue supplementaryPlanePoint = inCharacter - 0x10000;
    
    outUTF16[0] = 0xD800 | ( supplementaryPlanePoint & 0xFFC00 ) >> 10; /* high surrogate */
    outUTF16[1] = 0xDC00 | ( supplementaryPlanePoint & 0x003FF );       /* low surrogate */
}

static const void *_retain(CFAllocatorRef allocator, const void *value)
{
    return CFRetain((CFTypeRef)value);
}

static void _release(CFAllocatorRef allocator, const void *value)
{
    CFRelease((CFTypeRef)value);
}
    
static CFStringRef _copyDescription(const void *value)
{
    return CFCopyDescription((CFTypeRef)value);
}

static Boolean _equal(const void *value1, const void *value2)
{
    return CFEqual((CFTypeRef)value1, (CFTypeRef)value2);
}

static CFHashCode _hash(const void *value)
{
    return CFHash((CFTypeRef)value);
}

CFStringRef GetReplacmentForInternalEntityName(CFStringRef entityName)
{
    static CFDictionaryRef entityReplacements = NULL;
    
    if (!entityReplacements) {
	CFStringRef keys[] = {
	    CFSTR("amp"),
	    CFSTR("lt"),
	    CFSTR("gt"),
	    CFSTR("apos"),
	    CFSTR("quot"),
	};
	CFStringRef values[] = {
	    CFSTR("&"),
	    CFSTR("<"),
	    CFSTR(">"),
	    CFSTR("'"),
	    CFSTR("\""),
	};
	
	CFDictionaryKeyCallBacks keyCallbacks;
	memset(&keyCallbacks, 0, sizeof(keyCallbacks));
	keyCallbacks.retain          = _retain;
	keyCallbacks.release         = _release;
	keyCallbacks.copyDescription = _copyDescription;
	keyCallbacks.equal           = _equal;
	keyCallbacks.hash            = _hash;
	
	CFDictionaryValueCallBacks valueCallBacks;
	memset(&valueCallBacks, 0, sizeof(valueCallBacks));
	valueCallBacks.retain          = _retain;
	valueCallBacks.release         = _release;
	valueCallBacks.copyDescription = _copyDescription;
	valueCallBacks.equal           = _equal;
	
	entityReplacements = CFDictionaryCreate(kCFAllocatorDefault, (const void **)keys, (const void **)values, 5, &keyCallbacks, &valueCallBacks);
    }
    
    CFStringRef replacement = (CFStringRef)CFDictionaryGetValue(entityReplacements, entityName);
    //_log(CFSTR("entityReplacements = %@, entityName = %@, replacement = %@\n"), entityReplacements, entityName, replacement);
    
    if (!replacement) {
	replacement = CFSTR("");
#ifdef DEBUG // Really shouldn't happen, but we'll avoid crashing in this case
	_log(CFSTR("Unable to find replacment for internal entity '%@'\n"), entityName);
#endif
    }

    return replacement;
}

CFStringRef CreateEntityReplacementStringForCharacterEntity(CFXMLParserRef parser, CFStringRef str)
{
    // We expect something like '#35' or '#xab'.  Maximum Unicode value is 65535 (5 digits decimal) 
    unsigned int index, length = CFStringGetLength(str);
    
    // CFXML should have already caught these, but it is easy to do ourselves, so...
    if (length <= 1 || CFStringGetCharacterAtIndex(str, 0) != '#') {
	XMLParserAbort(parser, kCFXMLErrorMalformedCharacterReference, CFSTR("Malformed character reference '%@'"), str);
	return NULL;
    }
    
    UnicodeScalarValue sum = 0;  // this is a full 32-bit Unicode value
    if (CFStringGetCharacterAtIndex(str, 1) == 'x') {
	if (length <= 2 || length > 10) { // Max is '#xFFFFFFFF' for 32-bit Unicode characters.
	    XMLParserAbort(parser, kCFXMLErrorMalformedCharacterReference, CFSTR("Malformed character reference '%@'"), str);
	    return nil;
	}
	
	for (index = 2; index < length; index++) {
	    UniChar x = CFStringGetCharacterAtIndex(str, index);
	    if (x >= '0' && x <= '9')
		sum = 16*sum + (x - '0');
	    else if (x >= 'a' && x <= 'f')
		sum = 16*sum + (x - 'a') + 0xa;
	    else if (x >= 'A' && x <= 'F')
		sum = 16*sum + (x - 'A') + 0xA;
	    else {
		XMLParserAbort(parser, kCFXMLErrorMalformedCharacterReference, CFSTR("Malformed character reference '%@'"), str);
		return nil;
	    }
	}
    } else {
	if (length > 11) { // Max is '#4294967295' for 32-bit Unicode characters.
	    XMLParserAbort(parser, kCFXMLErrorMalformedCharacterReference, CFSTR("Malformed character reference '%@'"), str);
	    return nil;
	}
	for (index = 1; index < length; index++) {
	    UniChar x = CFStringGetCharacterAtIndex(str, index);
	    if (x >= '0' && x <= '9')
		sum = 10*sum + (x - '0');
	    else {
		XMLParserAbort(parser, kCFXMLErrorMalformedCharacterReference, CFSTR("Malformed character reference '%@'"), str);
		return nil;
	    }
	}
    }
    
    if (sum <= 65535) {
	UniChar ch = sum;
	return CFStringCreateWithCharacters(kCFAllocatorDefault, &ch, 1);
    } else {
	UniChar utf16[2];
	OFCharacterToSurrogatePair(sum, utf16);
	if (OFCharacterIsSurrogate(utf16[0]) == OFIsSurrogate_HighSurrogate &&
	    OFCharacterIsSurrogate(utf16[1]) == OFIsSurrogate_LowSurrogate)
	    return CFStringCreateWithCharacters(kCFAllocatorDefault, utf16, 2);
	else {
	    XMLParserAbort(parser, kCFXMLErrorMalformedCharacterReference, CFSTR("Malformed character reference '%@'"), str);
	    return NULL;
	}
    }
}

void XMLParserAbort(CFXMLParserRef parser, CFXMLParserStatusCode errorCode, CFStringRef format, ...)
{
    va_list args;
    va_start(args, format);
    CFStringRef str = CFStringCreateWithFormatAndArguments(kCFAllocatorDefault, NULL/*formatOptions*/, format, args);
    va_end(args);
    CFXMLParserAbort(parser, errorCode, str);
    CFRelease(str);
}
#endif

