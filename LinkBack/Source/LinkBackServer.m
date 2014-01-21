//
//  LinkBackServer.m
//  LinkBack
//
//  Created by Charles Jolley on Tue Jun 15 2004.
//  Copyright (c) 2004, Nisus Software, Inc.
//  All rights reserved.

//  Redistribution and use in source and binary forms, with or without 
//  modification, are permitted provided that the following conditions are met:
//
//  Redistributions of source code must retain the above copyright notice, 
//  this list of conditions and the following disclaimer.
//
//  Redistributions in binary form must reproduce the above copyright notice, 
//  this list of conditions and the following disclaimer in the documentation 
//  and/or other materials provided with the distribution.
//
//  Neither the name of the Nisus Software, Inc. nor the names of its 
//  contributors may be used to endorse or promote products derived from this 
//  software without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS 
//  IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, 
//  THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
//  PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR 
//  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, 
//  EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, 
//  PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR 
//  PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF 
//  LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING 
//  NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS 
//  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

#import "LinkBackServer.h"
#import "LinkBack.h"

#import <objc/message.h>

NSString* MakeLinkBackServerName(NSString* bundleIdentifier, NSString* name)
{
    return [bundleIdentifier stringByAppendingFormat: @":%@",name] ;
}

NSMutableDictionary* LinkBackServers = nil ;

@implementation LinkBackServer

+ (void)initialize
{
    static BOOL inited = NO ;
    if (inited) return ;

    [super initialize] ; 
    inited = YES ;
    
    if (!LinkBackServers) LinkBackServers = [[NSMutableDictionary alloc] init];
}

+ (LinkBackServer*)LinkBackServerWithName:(NSString*)aName  
{
    return [self LinkBackServerWithName:aName bundleIdentifier:[[NSBundle mainBundle] bundleIdentifier]];
}

+ (LinkBackServer*)LinkBackServerWithName:(NSString*)aName bundleIdentifier:(NSString *)bundleID
{
    return [LinkBackServers objectForKey:MakeLinkBackServerName(bundleID, aName)];
}

+ (BOOL)publishServerWithName:(NSString*)aName delegate:(id<LinkBackServerDelegate>)del 
{
    LinkBackServer* serv = [[LinkBackServer alloc] initWithName:aName bundleIdentifier:[[NSBundle mainBundle] bundleIdentifier] delegate:del] ;
    BOOL ret = [serv publish] ; // retains if successful
    [serv release] ;
    return ret ;
}

+ (BOOL)publishServerWithName:(NSString*)aName bundleIdentifier:(NSString *)bundleID delegate:(id<LinkBackServerDelegate>)del ;
{
    LinkBackServer* serv = [[LinkBackServer alloc] initWithName:aName bundleIdentifier:bundleID delegate:del] ;
    BOOL ret = [serv publish] ; // retains if successful
    [serv release] ;
    return ret ;
}

static BOOL LinkBackServerIsSupported(NSString* name, id supportedServers)
{
	BOOL ret = NO ;
	NSUInteger idx ;
	NSString* curServer = supportedServers ;
	
	// NOTE: supportedServers may be nil, an NSArray, or NSString.
	if (supportedServers) {
		if ([supportedServers isKindOfClass: [NSArray class]]) {
			idx = [supportedServers count] ;
			while((NO==ret) && idx--) {
				curServer = [supportedServers objectAtIndex: idx] ;
				ret = [curServer isEqualToString: name] ;
			}
		} else ret = [curServer isEqualToString: name] ; 
	}
	
	return ret ;
}

static NSString* FindLinkBackServer(NSString* bundleIdentifier, NSString* serverName, NSString* dir, int level, NSString **altServerPathPtr)
{
	NSString* ret = nil ;

	// resolve any symlinks, expand tildes.
	dir = [dir stringByStandardizingPath] ;
    
	NSFileManager* fm = [NSFileManager defaultManager] ;
    
    NSError *error = nil;
    NSArray *contents = [fm subpathsOfDirectoryAtPath: dir error:&error];
    if (!contents) {
	NSLog(@"Unable to get subpaths of '%@' - %@", dir, error);
	return nil;
    }
    
	NSUInteger idx ;

#ifdef DEBUG_FindLinkBackServer
	NSLog(@"searching for %@ (%@) in folder: %@", serverName, bundleIdentifier, dir) ;
#endif // DEBUG_FindLinkBackServer
        
	// working info
	NSString* cpath ;
	NSBundle* cbundle ;
	NSString* cbundleIdentifier ;
	id supportedServers ;

	// find all .app bundles in the directory and test them.
	idx = (contents) ? [contents count] : 0 ;
	while((nil==ret) && idx--) {
		cpath = [contents objectAtIndex: idx] ;
		
		if ([[cpath pathExtension] isEqualToString: @"app"]) {
			cpath = [dir stringByAppendingPathComponent: cpath] ;
			cbundle = [NSBundle bundleWithPath: cpath] ;
			cbundleIdentifier = [cbundle bundleIdentifier] ;
			
			supportedServers = [[cbundle infoDictionary] objectForKey: @"LinkBackServer"] ;
			NSString* serverPath = (LinkBackServerIsSupported(serverName, supportedServers)) ? cpath : nil ;
			if (nil != serverPath) {
				if ([cbundleIdentifier isEqualToString: bundleIdentifier]) {
					ret = serverPath ;
				} else if ((NULL != altServerPathPtr) && (nil == *altServerPathPtr)) {
					*altServerPathPtr = serverPath ;
				}
			}
		}
	}
	
	// if the app was not found, descend into non-app dirs.  only descend 4 levels to avoid taking forever.
	if ((nil==ret) && (level<4)) {
		idx = (contents) ? [contents count] : 0 ;
		while((nil==ret) && idx--) {
			BOOL isdir ;
			
			cpath = [dir stringByAppendingPathComponent:[contents objectAtIndex: idx]] ;
			[fm fileExistsAtPath: cpath isDirectory: &isdir] ;
			if (isdir && (![[cpath pathExtension] isEqualToString: @"app"])) {
				ret = FindLinkBackServer(bundleIdentifier, serverName, cpath, level+1, altServerPathPtr) ;
			}
		}
	}
	
	return ret ;
}

static void LinkBackRunAppNotFoundPanel(NSString* appName, NSURL* url)
{
	NSInteger result ;
	
	// strings for panel
	NSBundle* b = [NSBundle bundleForClass: [LinkBack class]] ;
	NSString* title ;
	NSString* ok ;
	NSString* urlstr ;
	
	title = NSLocalizedStringFromTableInBundle(@"_AppNotFoundTitle", @"Localized", b, @"app not found title") ;
	ok = NSLocalizedStringFromTableInBundle(@"_OK", @"Localized", b, @"ok") ;

	urlstr = (url) ? NSLocalizedStringFromTableInBundle(@"_GetApplication", @"Localized", b, @"Get application") : nil ;

	title = [NSString stringWithFormat: title, appName] ;
	
	result = NSRunCriticalAlertPanel(title,
                                         (url) ? NSLocalizedStringFromTableInBundle(@"_AppNotFoundMessageWithURL", @"Localized", b, @"app not found msg") : NSLocalizedStringFromTableInBundle(@"_AppNotFoundMessageNoURL", @"Localized", b, @"app not found msg"),
                                         ok, urlstr, nil) ;
	if (NSAlertAlternateReturn == result) {
		[[NSWorkspace sharedWorkspace] openURL: url] ;
	}
}

+ (LinkBackServer*)LinkBackServerWithName:(NSString*)aName inApplication:(NSString*)bundleIdentifier launchIfNeeded:(BOOL)flag fallbackURL:(NSURL*)url appName:(NSString*)appName ;
{
	NSString* serverName = MakeLinkBackServerName(bundleIdentifier, aName) ;
    id ret = nil ;

	// Is this our own server?
    ret = [LinkBackServers objectForKey:serverName];
    if (ret != nil)
        return ret;

	// Try to connect
	ret = [NSConnection rootProxyForConnectionWithRegisteredName: serverName host: nil] ;
	BOOL connect = YES ;

    // if launchIfNeeded, and the connection was not available, try to launch.
	if((!ret) && (flag)) {
		NSString* appPath ;
		NSString* altAppPath = nil ;
		id linkBackServers ;
		
		// first, try to find the app with the bundle identifier
		appPath = [[NSWorkspace sharedWorkspace] absolutePathForAppBundleWithIdentifier: bundleIdentifier] ;
		linkBackServers = [[[NSBundle bundleWithPath: appPath] infoDictionary] objectForKey: @"LinkBackServer"] ; 
		appPath = (LinkBackServerIsSupported(aName, linkBackServers)) ? appPath : nil ;
		
		// if the found app is not supported, we will need to search for the app ourselves.
		if (nil==appPath) {
			NSArray *searchPaths = NSSearchPathForDirectoriesInDomains(NSApplicationDirectory, NSAllDomainsMask, NO);   // Don't need to expand tildes as FindLinkBackServer() standardizes the path passed to it
			NSUInteger pathCount = [searchPaths count];
			NSUInteger pathIndex;
			for (pathIndex = 0; pathIndex < pathCount; pathIndex++) {
				NSString *searchPath = [searchPaths objectAtIndex:pathIndex];
				appPath = FindLinkBackServer(bundleIdentifier, aName, searchPath, 0, &altAppPath);
				if (nil!=appPath)
					break;
			}
		}

		if (nil==appPath) appPath = altAppPath;
                
		// if app path has been found, launch the app.
		if (appPath) {
			[[NSWorkspace sharedWorkspace] launchApplication: appPath] ;
		} else if (![[NSWorkspace sharedWorkspace] launchApplication: appName]) {
			LinkBackRunAppNotFoundPanel(appName, url) ;
			connect = NO ;
		}
	}
    
    // if needed, try to connect.  
	// retry connection for a while if we did not succeed at first.  This gives the app time to launch.
	if (connect && (nil==ret)) {
		NSTimeInterval tryMark = [NSDate timeIntervalSinceReferenceDate] ;
		do {
			ret = [NSConnection rootProxyForConnectionWithRegisteredName: serverName host: nil] ;
		} while ((!ret) && (([NSDate timeIntervalSinceReferenceDate]-tryMark)<10)) ;
		
	}

	// setup protocol and return
    if (ret) [ret setProtocolForProxy: @protocol(LinkBackServer)] ;
    return ret ;
}

- (id)initWithName:(NSString*)aName bundleIdentifier:(NSString *)anIdentifier delegate:(id<LinkBackServerDelegate>)aDel
{
    if (!(self = [super init]))
        return nil;

    bundleIdentifier = [anIdentifier copy];
    name = [aName copy] ;
    delegate = aDel ;
    listener = nil ;
    
    return self ;
}

- (void)dealloc
{
    if (listener) 
        [self retract];
    [name release];
    [bundleIdentifier release];
    [super dealloc];
}

- (BOOL)publish
{
    NSString* serverName = MakeLinkBackServerName(bundleIdentifier, name) ;
    BOOL ret = YES ;
    
    // create listener and connect
    NSPort* port = [NSPort port] ;
    listener = [NSConnection connectionWithReceivePort: port sendPort:port] ;
    [listener setRootObject: self] ;
    ret = [listener registerName: serverName] ;
    
    // if successful, retain connection and add self to list of servers.
    if (ret) {
        [listener retain] ;
    } else listener = nil ; // listener will dealloc on its own.
    
    [LinkBackServers setObject: self forKey: serverName] ; // Always keep track of our published servers
    return ret ;
}

- (void)retract 
{
    if (listener) {
        [listener invalidate] ;
        [listener release] ;
        listener = nil ;
    }
    
    [LinkBackServers removeObjectForKey: MakeLinkBackServerName(bundleIdentifier, name)] ;
}

- (LinkBack*)initiateLinkBackFromClient:(LinkBack*)clientLinkBack
{
    LinkBack* ret = [[LinkBack alloc] initServerWithClient: clientLinkBack delegate: delegate] ;
    
    // NOTE: we do not release because LinkBack will release itself when it the link closes. (caj)
    
    // But we need to pretend to release to hack around clang:
    void (*imp)(id, SEL) = (typeof(imp))objc_msgSend;
    imp(ret, @selector(retain));
    [ret autorelease];
    
    return ret ; 
}

@end
