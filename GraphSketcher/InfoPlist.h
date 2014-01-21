// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/InfoPlist.h 200364 2013-12-10 22:53:14Z correia $

// Common settings
#define BUNDLE_VERSION 45

// iPad settings
#define IPAD_COPYRIGHT_YEARS 2010–2013
#define IPAD_MARKETING_VERSION_NUMBER 2.0
#define IPAD_SNEAKYPEEK 1

// Mac settings
#define COPYRIGHT_YEARS 2003–2013
#define MARKETING_VERSION_NUMBER 2.0
#define SNEAKYPEEK 1

//
// Should not generally need to edit settings beyond this point
//

#if SNEAKYPEEK
#define SOFTWARE_UPDATE_TRACK test
#define MARKETING_VERSION MARKETING_VERSION_NUMBER test
#else
#define SOFTWARE_UPDATE_TRACK
#define MARKETING_VERSION MARKETING_VERSION_NUMBER
#endif

#if IPAD_RETAIL_DEMO
#define IPAD_MARKETING_VERSION IPAD_MARKETING_VERSION_NUMBER demo
#elif IPAD_SNEAKYPEEK
#define IPAD_MARKETING_VERSION IPAD_MARKETING_VERSION_NUMBER alpha
#else
#define IPAD_MARKETING_VERSION IPAD_MARKETING_VERSION_NUMBER
#endif

// Common settings

#define FULL_BUNDLE_VERSION BUNDLE_VERSION
