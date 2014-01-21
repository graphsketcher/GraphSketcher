//
//  LinkBack.h
//  LinkBack Project
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

#import <Foundation/NSDictionary.h>
#import <Foundation/NSDate.h>

@class NSPasteboard;

// Use this pasteboard type to put LinkBack data to the pasteboard.  Use MakeLinkBackData() to create the data.
extern NSString* LinkBackPboardType ;

// Default Action Names.  These will be localized for you automatically.
extern NSString* LinkBackEditActionName ;
extern NSString* LinkBackRefreshActionName ;

//
// Support Functions
//
extern NSString* LinkBackUniqueItemKey(void);
extern NSString* LinkBackEditMultipleMenuTitle(void);
extern NSString* LinkBackEditNoneMenuTitle(void);

// 
// Deprecated Support Functions -- use LinkBack Data Category instead
//
id MakeLinkBackData(NSString* serverName, id appData) ;
id LinkBackGetAppData(id linkBackData) ;
BOOL LinkBackDataBelongsToActiveApplication(id data) ;

//
// LinkBack Data Category
//

// Use these methods to create and access linkback data objects.  You can also use the helper functions above.

@interface NSDictionary (LinkBackData)

+ (NSDictionary*)linkBackDataWithServerName:(NSString*)serverName appData:(id)appData ;

+ (NSDictionary*)linkBackDataWithServerName:(NSString*)serverName appData:(id)appData suggestedRefreshRate:(NSTimeInterval)rate ;

+ (NSDictionary*)linkBackDataWithServerName:(NSString*)serverName appData:(id)appData actionName:(NSString*)action suggestedRefreshRate:(NSTimeInterval)rate ;

- (BOOL)linkBackDataBelongsToActiveApplication ;

- (id)linkBackAppData ;
- (NSString*)linkBackSourceApplicationName ;
- (NSString*)linkBackActionName ;
- (NSString*)linkBackVersion ;
- (NSURL*)linkBackApplicationURL ;

- (NSTimeInterval)linkBackSuggestedRefreshRate ;

- (NSString*)linkBackEditMenuTitle ;

@end

//
// Delegate Protocols
//

@class LinkBack ;

@protocol LinkBackServerDelegate
- (void)linkBackDidClose:(LinkBack*)link ;
- (void)linkBackClientDidRequestEdit:(LinkBack*)link ;
@end

@protocol LinkBackClientDelegate
- (void)linkBackDidClose:(LinkBack*)link ;
- (void)linkBackServerDidSendEdit:(LinkBack*)link ;
@end

// used for cross app communications
@protocol LinkBack
- (oneway void)remoteCloseLink ;
- (void)requestEditWithPasteboardName:(bycopy NSString*)pboardName ; // from client
- (void)refreshEditWithPasteboardName:(bycopy NSString*)pboardName ; // from server
@end

@interface LinkBack : NSObject <LinkBack> {
    LinkBack* peer ; // the client or server on the other side.
    BOOL isServer ; 
    id delegate ;
    NSPasteboard* pboard ;
    id repobj ; 
    NSString* sourceName ;
	NSString* sourceApplicationName ;
    NSString* key ;
}

+ (LinkBack*)activeLinkBackForItemKey:(id)key ;
// works for both the client and server side.  Valid only while a link is connected.

// ...........................................................................
// General Use methods
//
- (NSPasteboard*)pasteboard ;
- (void)closeLink ;

- (id)representedObject ;
- (void)setRepresentedObject:(id)obj ;
// Applications can use this represented object to attach some meaning to the live link.  For example, a client application may set this to the object to be modified when the edit is refreshed.  This retains its value.

- (NSString*)sourceName ;
- (NSString*)sourceApplicationName ;
- (NSString*)itemKey ; // maybe this matters only on the client side.

// ...........................................................................
// Server-side methods
//
+ (BOOL)publishServerWithName:(NSString*)name delegate:(id<LinkBackServerDelegate>)del;
+ (BOOL)publishServerWithName:(NSString*)name bundleIdentifier:(NSString *)anIdentifier delegate:(id<LinkBackServerDelegate>)del;

+ (void)retractServerWithName:(NSString*)name;
+ (void)retractServerWithName:(NSString*)name bundleIdentifier:(NSString *)anIdentifier;

- (void)sendEdit ;

// ...........................................................................
// Client-Side Methods
//
+ (LinkBack*)editLinkBackData:(id)data sourceName:(NSString*)aName delegate:(id<LinkBackClientDelegate>)del itemKey:(NSString*)aKey ;

@end

@interface LinkBack (InternalUseOnly)

- (id)initServerWithClient: (LinkBack*)aLinkBack delegate: (id<LinkBackServerDelegate>)aDel ;

- (id)initClientWithSourceName:(NSString*)aName delegate:(id<LinkBackClientDelegate>)aDel itemKey:(NSString*)aKey ;

- (BOOL)connectToServerWithName:(NSString*)aName inApplication:(NSString*)bundleIdentifier fallbackURL:(NSURL*)url appName:(NSString*)appName ;

- (void)requestEdit ;

@end
