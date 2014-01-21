// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/Model/RSLog.h 200244 2013-12-10 00:11:55Z correia $


// ***********************
// SET LOGGING LEVEL HERE:
// *****
#define RS_LOGGING_LEVEL 0


#if RS_LOGGING_LEVEL >= 1
#   define	Log1(format, ...)	NSLog( @"File=%s Line=%d " format, strrchr("/" __FILE__,'/')+1, __LINE__, ## __VA_ARGS__ )
#else
#   define Log1(format, ...)
#endif

#if RS_LOGGING_LEVEL >= 2
#   define Log2(format, ...)	NSLog( @"File=%s Line=%d " format, strrchr("/" __FILE__,'/')+1, __LINE__, ## __VA_ARGS__ )
#else
#   define Log2(format, ...)  do {} while(0)
#endif

#if RS_LOGGING_LEVEL >= 3
#   define Log3(format, ...)	NSLog( @"File=%s Line=%d " format, strrchr("/" __FILE__,'/')+1, __LINE__, ## __VA_ARGS__ )
#else
#   define Log3(format, ...)  do {} while(0)
#endif

