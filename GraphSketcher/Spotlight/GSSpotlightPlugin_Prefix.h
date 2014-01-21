// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/Spotlight/GSSpotlightPlugin_Prefix.h 200244 2013-12-10 00:11:55Z correia $

#ifdef __OBJC__
#import <OmniBase/rcsid.h>
#import <OmniBase/OBUtilities.h>
#import <Foundation/Foundation.h>

// We don't want dependencies on OmniBase and OmniFoundation since we can't refer to the framework at runtime in release builds.
#import <OmniFoundation/OFObject.h> // Import this first to get it defined as OFObject
#define OFObject NSObject // Then make sure "subclasses" just use NSObject in this bundle.

// We import some classes from OmniUnzip, but don't want to risk having collisions if two bundles get loaded.
#define OUUnzipArchive com_omnigroup_omnigraphsketcher_OUUnzipArchive
#define OUUnzipEntry com_omnigroup_omnigraphsketcher_OUUnzipEntry

#endif
