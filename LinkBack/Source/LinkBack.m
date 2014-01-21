//
//  LinkBack.m
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

#import "LinkBack.h"
#import "LinkBackServer.h"

NSString* LinkBackPboardType = @"LinkBackData" ;

// LinkBack data keys.  These are used in a LinkBack object, which is currently a dictionary.  Do not depend on these values.  They are public for testing purposes only.
NSString* LinkBackServerActionKey = @"serverActionKey" ;
NSString* LinkBackServerApplicationNameKey = @"serverAppName" ;
NSString* LinkBackServerNameKey = @"serverName" ;
NSString* LinkBackServerBundleIdentifierKey = @"bundleId" ;
NSString* LinkBackVersionKey = @"version" ;
NSString* LinkBackApplicationDataKey = @"appData" ;
NSString* LinkBackSuggestedRefreshKey = @"refresh" ;
NSString* LinkBackApplicationURLKey = @"ApplicationURL" ;

NSString* LinkBackEditActionName = @"_Edit" ;
NSString* LinkBackRefreshActionName = @"_Refresh" ;

// ...........................................................................
// Support Functions
//

id MakeLinkBackData(NSString* serverName, id appData) 
{
	return [NSDictionary linkBackDataWithServerName: serverName appData: appData] ;
}

id LinkBackGetAppData(id LinkBackData) 
{
	return [LinkBackData linkBackAppData] ;
}

NSString* LinkBackUniqueItemKey(void)
{
    static int counter = 0 ;
    
    NSString* base = [[NSBundle mainBundle] bundleIdentifier] ;
    uint64_t secondsSinceReferenceDate = [NSDate timeIntervalSinceReferenceDate];
    return [NSString stringWithFormat: @"%@%qu.%.4x", base, secondsSinceReferenceDate, counter++] ;
}

BOOL LinkBackDataBelongsToActiveApplication(id data) 
{
	return [data linkBackDataBelongsToActiveApplication] ;
}

NSString* LinkBackEditMultipleMenuTitle(void) 
{
	NSBundle* bundle = [NSBundle bundleForClass: [LinkBack class]] ;
	NSString* ret = [bundle localizedStringForKey: @"_EditMultiple" value: @"Edit LinkBack Items" table: @"Localized"] ;
	return ret ;
}

NSString* LinkBackEditNoneMenuTitle(void) 
{
	NSBundle* bundle = [NSBundle bundleForClass: [LinkBack class]] ;
	NSString* ret = [bundle localizedStringForKey: @"_EditNone" value: @"Edit LinkBack Item" table: @"Localized"] ;
	return ret ;
}

// ...........................................................................
// LinkBack Data Category
//

// Use these methods to create and access linkback data objects.  You can also use the helper functions above.

@implementation NSDictionary (LinkBackData)

+ (NSDictionary*)linkBackDataWithServerName:(NSString*)serverName appData:(id)appData 
{
	return [self linkBackDataWithServerName: serverName appData: appData actionName: nil suggestedRefreshRate: 0];
}

+ (NSDictionary*)linkBackDataWithServerName:(NSString*)serverName appData:(id)appData suggestedRefreshRate:(NSTimeInterval)rate 
{
	return [self linkBackDataWithServerName: serverName appData: appData actionName: LinkBackRefreshActionName suggestedRefreshRate: rate] ;
}

+ (NSDictionary*)linkBackDataWithServerName:(NSString*)serverName appData:(id)appData actionName:(NSString*)action suggestedRefreshRate:(NSTimeInterval)rate ;
{
	NSDictionary* appInfo = [[NSBundle mainBundle] infoDictionary] ;

    NSMutableDictionary* ret = [[NSMutableDictionary alloc] init] ;
    NSString* bundleId = [[NSBundle mainBundle] bundleIdentifier] ;
	NSString* url = [appInfo objectForKey: @"LinkBackApplicationURL"] ;
	NSString* appName = [[NSProcessInfo processInfo] processName] ;
	id version = @"A" ;

	if (nil==serverName) [NSException raise: NSInvalidArgumentException format: @"LinkBack Data cannot be created without a server name."] ;
	
	// callback information
	[ret setObject: bundleId forKey: LinkBackServerBundleIdentifierKey]; 
    [ret setObject: serverName forKey: LinkBackServerNameKey] ;
    [ret setObject: version forKey: LinkBackVersionKey] ;
	
	// additional information
	if (appName) [ret setObject: appName forKey: LinkBackServerApplicationNameKey] ;
	if (action) [ret setObject: action forKey: LinkBackServerActionKey] ;
    if (appData) [ret setObject: appData forKey: LinkBackApplicationDataKey] ;
	if (url) [ret setObject: url forKey: LinkBackApplicationURLKey] ;
	[ret setObject: [NSNumber numberWithDouble: rate] forKey: LinkBackSuggestedRefreshKey] ;
	
    return [ret autorelease] ;
}

- (BOOL)linkBackDataBelongsToActiveApplication 
{
    NSString* bundleId = [[NSBundle mainBundle] bundleIdentifier] ;
    NSString* dataId = [self objectForKey: LinkBackServerBundleIdentifierKey] ;
    return (dataId && [dataId isEqualToString: bundleId]) ;
}

- (id)linkBackAppData 
{
	return [self objectForKey: LinkBackApplicationDataKey] ;
}

- (NSString*)linkBackSourceApplicationName 
{
	return [self objectForKey: LinkBackServerApplicationNameKey] ;
}

- (NSString*)linkBackActionName 
{
	NSBundle* bundle = [NSBundle bundleForClass: [LinkBack class]] ;
	NSString* ret = [self objectForKey: LinkBackServerActionKey] ;
	if (nil==ret) ret = LinkBackEditActionName ;
	
	ret = [bundle localizedStringForKey: ret value: ret table: @"Localized"] ;
	return ret ;
}

- (NSString*)linkBackEditMenuTitle
{
	NSBundle* bundle = [NSBundle bundleForClass: [LinkBack class]] ;
	NSString* appName = [self linkBackSourceApplicationName] ;
	NSString* action = [self linkBackActionName] ;
	NSString* ret = [bundle localizedStringForKey: @"_EditPattern" value: @"%@ in %@" table: @"Localized"] ;
	ret = [NSString stringWithFormat: ret, action, appName] ;
	return ret ;
}

- (NSString*)linkBackVersion 
{
	return [self objectForKey: LinkBackVersionKey] ;
}

- (NSTimeInterval)linkBackSuggestedRefreshRate 
{
	id obj = [self objectForKey: LinkBackSuggestedRefreshKey] ;
	return (obj) ? [obj floatValue] : 0 ;
}

- (NSURL*)linkBackApplicationURL 
{
	id obj = [self objectForKey: LinkBackApplicationURLKey] ;
	if (obj) obj = [NSURL URLWithString: obj] ;
	return obj ;
}

@end

// ...........................................................................
// LinkBackServer 
//
// one of these exists for each registered server name.  This is the receiver of server requests.

// ...........................................................................
// LinkBack Class
//

NSMutableDictionary* keyedLinkBacks = nil ;

@implementation LinkBack

+ (void)initialize
{
    static BOOL inited = NO ;
    if (inited) return ;
    inited=YES; [super initialize] ;
    keyedLinkBacks = [[NSMutableDictionary alloc] init] ;
}

+ (LinkBack*)activeLinkBackForItemKey:(id)aKey 
{
    return [keyedLinkBacks objectForKey: aKey] ;
}

- (id)initServerWithClient: (LinkBack*)aLinkBack delegate: (id<LinkBackServerDelegate>)aDel 
{
    if (!(self = [super init]))
        return nil;

    peer = [aLinkBack retain] ;
    sourceName = [[peer sourceName] copy] ;
            sourceApplicationName = [[peer sourceApplicationName] copy] ;
    key = [[peer itemKey] copy] ;
    isServer = YES ;
    delegate = aDel ;
    [keyedLinkBacks setObject: self forKey: key] ;
    if ([peer isKindOfClass:[NSDistantObject class]])
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(connectionDidDie:) name:NSConnectionDidDieNotification object:[(NSDistantObject *)peer connectionForProxy]];

    return self ;
}

- (id)initClientWithSourceName:(NSString*)aName delegate:(id<LinkBackClientDelegate>)aDel itemKey:(NSString*)aKey ;
{
    if (!(self = [super init]))
        return nil;

    isServer = NO ;
    delegate = aDel ;
    sourceName = [aName copy] ;
            sourceApplicationName = [[NSProcessInfo processInfo] processName] ;
    pboard = [[NSPasteboard pasteboardWithUniqueName] retain] ;
    key = [aKey copy] ;
    
    return self ;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSConnectionDidDieNotification object:nil];
    
    [repobj release] ;
    [sourceName release] ;
    
    if (peer) [self closeLink] ;
    [peer release] ;
    
    if (!isServer) [pboard releaseGlobally] ; // client owns the pboard.
    [pboard release] ;
    
    [super dealloc] ;
}

// ...........................................................................
// General Use methods

- (NSPasteboard*)pasteboard 
{
    return pboard ;
}

- (id)representedObject 
{
    return repobj ;
}

- (void)setRepresentedObject:(id)obj 
{
    [obj retain] ;
    [repobj release] ;
    repobj = obj ;
}

- (NSString*)sourceName
{
    return sourceName ;
}

- (NSString*)sourceApplicationName 
{
	return sourceApplicationName ;
}

- (NSString*)itemKey
{
    return key ;
}

// this method is called to initial a link closure from this side.
- (void)closeLink 
{
    // inform peer of closure
    if (peer) {
        LinkBack *closingPeer = peer;
        // note we can get an incoming -remoteCloseLink while we're calling the other side's closeLink
        peer = nil ;
        delegate = nil ;
        [keyedLinkBacks removeObjectForKey: [self itemKey]]; 
        [closingPeer remoteCloseLink] ; 
        [closingPeer release] ;
    }
}

// this method is called whenever the link is about to be or has been closed by the other side.
- (oneway void)remoteCloseLink 
{
    if (peer) {
        [peer release] ;
        peer = nil ;
        [keyedLinkBacks removeObjectForKey: [self itemKey]];
    }

    if (delegate) [delegate linkBackDidClose: self] ;
}

// ...........................................................................
// Server-side methods
//
+ (BOOL)publishServerWithName:(NSString*)name delegate:(id<LinkBackServerDelegate>)del 
{
    return [LinkBackServer publishServerWithName: name delegate: del] ;
}

+ (BOOL)publishServerWithName:(NSString*)name bundleIdentifier:(NSString *)anIdentifier delegate:(id<LinkBackServerDelegate>)del;
{
    return [LinkBackServer publishServerWithName:name bundleIdentifier:anIdentifier delegate:del] ;
}

+ (void)retractServerWithName:(NSString*)name 
{
    LinkBackServer* server = [LinkBackServer LinkBackServerWithName: name] ;
    if (server) [server retract] ;
}

+ (void)retractServerWithName:(NSString*)name bundleIdentifier:(NSString *)anIdentifier;
{
    LinkBackServer *server = [LinkBackServer LinkBackServerWithName:name bundleIdentifier:anIdentifier] ;
    [server retract];
}
- (void)sendEdit 
{
    if (!peer) [NSException raise: NSGenericException format: @"tried to request edit from a live link not connect to a server."] ;
    [peer refreshEditWithPasteboardName: [pboard name]] ;
}

// FROM CLIENT LinkBack
- (void)requestEditWithPasteboardName:(bycopy NSString*)pboardName
{
    // get the new pasteboard, if needed
    if ((!pboard) || ![pboardName isEqualToString: [pboard name]]) pboard = [[NSPasteboard pasteboardWithName: pboardName] retain] ;

    // pass onto delegate
	[delegate performSelectorOnMainThread: @selector(linkBackClientDidRequestEdit:) withObject: self waitUntilDone: NO] ;
}

// ...........................................................................
// Client-Side Methods
//
+ (LinkBack*)editLinkBackData:(id)data sourceName:(NSString*)aName delegate:(id<LinkBackClientDelegate>)del itemKey:(NSString*)aKey
{
    // if an active live link already exists, use that.  Otherwise, create a new one.
    LinkBack* ret = [keyedLinkBacks objectForKey: aKey] ;
    
    if(nil==ret) {
        BOOL ok ;
        NSString* serverName = nil ;
        NSString* serverId = nil ;
        NSString* appName = nil ;
        NSURL* url = nil ;
		
        // collect server contact information from data.
        ok = [data isKindOfClass: [NSDictionary class]] ;
        if (ok) {
            serverName = [data objectForKey: LinkBackServerNameKey] ;
            serverId = [data objectForKey: LinkBackServerBundleIdentifierKey];
			appName = [data linkBackSourceApplicationName] ;
			url = [data linkBackApplicationURL] ;
        }
        
        if (!ok || !serverName || !serverId) [NSException raise: NSInvalidArgumentException format: @"LinkBackData is not of the correct format: %@", data] ;
        
        // create the live link object and try to connect to the server.
        ret = [[LinkBack alloc] initClientWithSourceName: aName delegate: del itemKey: aKey];
        
        if (![ret connectToServerWithName: serverName inApplication: serverId fallbackURL: url appName: appName]) {
            // if connection to server failed, return nil.
            [ret release] ;
            ret = nil ;
        } else
            [ret autorelease];
    }
    
    // now with a live link in hand, request an edit
    if (ret) {
        // if connected to server, publish data and inform server.
        NSPasteboard* my_pboard = [ret pasteboard] ;
        [my_pboard declareTypes: [NSArray arrayWithObject: LinkBackPboardType] owner: ret] ;
        [my_pboard setPropertyList: data forType: LinkBackPboardType] ;
        
        [ret requestEdit] ;
    }
    
    return ret;
}

- (BOOL)connectToServerWithName:(NSString*)aName inApplication:(NSString*)bundleIdentifier fallbackURL:(NSURL*)url appName:(NSString*)appName 
{
    // get the LinkBackServer.
    LinkBackServer* server = [LinkBackServer LinkBackServerWithName: aName inApplication: bundleIdentifier launchIfNeeded: YES fallbackURL: url appName: appName] ;
    if (!server) return NO ; // failed to get server
    
    peer = [[server initiateLinkBackFromClient: self] retain] ;
    if (!peer) return NO ; // failed to initiate session
    
    // if we connected, then add to the list of active keys
    [keyedLinkBacks setObject: self forKey: [self itemKey]] ;
    
    return YES ;
}

- (void)requestEdit 
{
    if (!peer) [NSException raise: NSGenericException format: @"tried to request edit from a live link not connect to a server."] ;
    [peer requestEditWithPasteboardName: [pboard name]] ;
}

// RECEIVED FROM SERVER
- (void)refreshEditWithPasteboardName:(bycopy NSString*)pboardName
{
    // if pboard has changes, change to new pboard.
    if (![pboardName isEqualToString: [pboard name]]) {
        [pboard release] ;
        pboard = [[NSPasteboard pasteboardWithName: pboardName] retain] ;
    } 
    
    // inform delegate
	[delegate performSelectorOnMainThread: @selector(linkBackServerDidSendEdit:) withObject: self waitUntilDone: NO] ;
}

- (void)connectionDidDie:(NSNotification *)notification;
{
    [self remoteCloseLink];
}


@end
