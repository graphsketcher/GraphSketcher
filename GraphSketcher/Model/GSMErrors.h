// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OmniBase/NSError-OBUtilities.h>

enum {
    GSMNoError = 0, // Zero often means no error.

    GSMUnrecognizedFileType,
    GSMUnrecognizedURLScheme,
    GSMNoPreviewAvailable,
};

extern NSString * const GSMErrorDomain;

#define GSMErrorWithInfo(error, code, description, suggestion, ...) _OBError(error, GSMErrorDomain, code, __FILE__, __LINE__, NSLocalizedDescriptionKey, description, NSLocalizedRecoverySuggestionErrorKey, (suggestion), ## __VA_ARGS__)
#define GSMError(error, code, description, reason) GSMErrorWithInfo((error), (code), (description), (reason), nil)
