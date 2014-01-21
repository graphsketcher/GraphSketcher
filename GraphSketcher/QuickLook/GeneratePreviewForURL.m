// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/QuickLook/GeneratePreviewForURL.m 200244 2013-12-10 00:11:55Z correia $

#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include <QuickLook/QuickLook.h>
#include <Foundation/Foundation.h>
#include <OmniUnzip/OUUnzipArchive.h>

#import "GeneratePreviewForURL.h"

/* -----------------------------------------------------------------------------
   Generate a preview for file

   This function's job is to create preview for designated file
   ----------------------------------------------------------------------------- */

OSStatus GeneratePreviewForURL(void *thisInterface, QLPreviewRequestRef preview, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    //NSLog(@"Generating preview with bundle %@", [[NSBundle mainBundle] bundlePath]);
    
    NSString *path = [(NSURL *)url path];
    
    OUUnzipArchive *zipArchive = [[[OUUnzipArchive alloc] initWithPath:path error:nil] autorelease];
    if (zipArchive) {
        OUUnzipEntry *zipEntry = [zipArchive entryNamed:@"preview.pdf"];
        
        if (zipEntry) {
            NSData *pdfData = [zipArchive dataForEntry:zipEntry error:nil];
            QLPreviewRequestSetDataRepresentation(preview, (CFDataRef)pdfData, kUTTypePDF, nil);
        }
    }
    
    [pool release];
    return noErr;
}

void CancelPreviewGeneration(void* thisInterface, QLPreviewRequestRef preview)
{
    // implement only if supported
}
