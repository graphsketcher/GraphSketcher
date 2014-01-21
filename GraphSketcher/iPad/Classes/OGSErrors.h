// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/iPad/Classes/OGSErrors.h 200244 2013-12-10 00:11:55Z correia $

#import <OmniBase/NSError-OBUtilities.h>

enum {
    OGSNoError = 0, // Zero often means no error.
};

extern NSString * const OGSErrorDomain;

#define OGSErrorWithInfo(error, code, description, suggestion, ...) _OBError(error, OGSErrorDomain, code, __FILE__, __LINE__, NSLocalizedDescriptionKey, description, NSLocalizedRecoverySuggestionErrorKey, (suggestion), ## __VA_ARGS__)
#define OGSError(error, code, description, reason) OGSErrorWithInfo((error), (code), (description), (reason), nil)
