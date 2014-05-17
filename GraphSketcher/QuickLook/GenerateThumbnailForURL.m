// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <tgmath.h>
#include <QuickLook/QuickLook.h>
#include <AppKit/AppKit.h>
#include <OmniUnzip/OUUnzipArchive.h>

#import "GenerateThumbnailForURL.h"

/* -----------------------------------------------------------------------------
    Generate a thumbnail for file

   This function's job is to create thumbnail for designated file as fast as possible
   ----------------------------------------------------------------------------- */

OSStatus GenerateThumbnailForURL(void *thisInterface, QLThumbnailRequestRef thumbnail, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options, CGSize maxSize)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    //NSLog(@"Generating thumbnail with bundle %@", [[NSBundle mainBundle] bundlePath]);
    //NSLog(@"QL max size: %@", NSStringFromSize(QLThumbnailRequestGetMaximumSize(thumbnail)));
    
    NSString *path = [(NSURL *)url path];
    
    OUUnzipArchive *zipArchive = [[[OUUnzipArchive alloc] initWithPath:path error:nil] autorelease];
    if (zipArchive) {
        OUUnzipEntry *zipEntry = [zipArchive entryNamed:@"preview.pdf"];
        
        if (zipEntry) {
            NSData *pdfData = [zipArchive dataForEntry:zipEntry error:nil];
            NSImage *thumbImage = [[[NSImage alloc] initWithData:pdfData] autorelease];
            
            // Scale down image if necessary
            NSSize maxSize = QLThumbnailRequestGetMaximumSize(thumbnail);
            NSSize canvasSize = [thumbImage size];
            NSSize thumbSize = canvasSize;
            if (canvasSize.width > maxSize.width || canvasSize.height > maxSize.height) {
                CGFloat scale = MIN(maxSize.width/canvasSize.width, maxSize.height/canvasSize.height);
                OBASSERT(scale > 0);
                thumbSize = NSMakeSize(nearbyint(canvasSize.width * scale),
                                       nearbyint(canvasSize.height * scale));
            }
            [thumbImage setSize:thumbSize];
            //DEBUG_RS(@"Creating thumbnail with size: %@", NSStringFromSize(thumbSize));
            // Create tiff data
            NSData *tiffData = [thumbImage TIFFRepresentation];//UsingCompression:NSTIFFCompressionLZW factor:0.0];
            
            
            NSDictionary *props = [NSDictionary dictionaryWithObject:@"public.tiff" forKey:(NSString *)kCGImageSourceTypeIdentifierHint];
            QLThumbnailRequestSetImageWithData(thumbnail, (CFDataRef)tiffData, (CFDictionaryRef)props);
        }
        else {
#ifdef DEBUG
            NSLog(@"preview.pdf is not present in %@", (NSURL *)url);
#endif
        }
    }
    else {
#ifdef DEBUG
        NSLog(@"No zip archive found at %@", (NSURL *)url);
#endif
    }
    
    [pool release];
    return noErr;
}

void CancelThumbnailGeneration(void* thisInterface, QLThumbnailRequestRef thumbnail)
{
    // implement only if supported
}
