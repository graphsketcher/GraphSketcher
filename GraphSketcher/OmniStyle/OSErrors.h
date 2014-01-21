// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/OmniStyle/OSErrors.h 200244 2013-12-10 00:11:55Z correia $

enum {
    // Generic error
    OSGenericError = 1,                                     // skip zero since it typically means 'no error'
    
    // Should I really bother having all these errors, or just a few? Or just one? Only define separate errors when there's something I identify that I want to treat specially?
    
    // Problems associating styles
    OSStyleContextMismatchError,
    OSStyleUndoEnabledMismatchError,
    OSStyleCycleError,
    OSStyleInheritedStyleIsNotNamedStyleError,
    OSStyleDuplicateInheritanceError,
    OSStyleCascadeStyleIsNamedStyleError,
};

extern NSString * const OSErrorDomain;

#define OSErrorWithInfo(error, code, description, suggestion, ...) _OBError(error, OSErrorDomain, code, __FILE__, __LINE__, NSLocalizedDescriptionKey, description, NSLocalizedRecoverySuggestionErrorKey, (suggestion), ## __VA_ARGS__)
#define OSError(error, code, description, reason) OSErrorWithInfo((error), (code), (description), (reason), nil)
