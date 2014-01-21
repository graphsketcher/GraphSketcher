//
//  LinkBackServer.h
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

#import <Cocoa/Cocoa.h>

@class LinkBack ;
@protocol LinkBackServerDelegate, LinkBackClientDelegate ;

@protocol LinkBackServer
- (LinkBack*)initiateLinkBackFromClient:(LinkBack*)clientLinkBack ;
@end

// This method is used as the standard way of constructing the actual server name a live link connection is posted under.  It is constructed from the name and identifier.
NSString* MakeLinkBackServerName(NSString* bundleIdentifier, NSString* name) ;

// a LinkBack server is created for each published server.  This simply responds to connection requests to create new live links.
@interface LinkBackServer : NSObject <LinkBackServer> {
    NSString *bundleIdentifier;
    NSConnection* listener ;
    NSString* name ;
    id<LinkBackServerDelegate> delegate ;
}

+ (LinkBackServer*)LinkBackServerWithName:(NSString*)name;
+ (LinkBackServer*)LinkBackServerWithName:(NSString*)aName bundleIdentifier:(NSString *)bundleID;

+ (BOOL)publishServerWithName:(NSString*)name delegate:(id<LinkBackServerDelegate>)del ;
+ (BOOL)publishServerWithName:(NSString*)name bundleIdentifier:(NSString *)bundleID delegate:(id<LinkBackServerDelegate>)del ;

+ (LinkBackServer*)LinkBackServerWithName:(NSString*)name inApplication:(NSString*)bundleIdentifier launchIfNeeded:(BOOL)flag fallbackURL:(NSURL*)url appName:(NSString*)appName ;

// This method is used by clients to connect 

- (id)initWithName:(NSString*)name bundleIdentifier:(NSString *)bundleID delegate:(id<LinkBackServerDelegate>)aDel;

- (BOOL)publish ; // creates the connection and adds to the list.
- (void)retract ;

@end
