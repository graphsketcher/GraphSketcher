// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/Model/XML/RSLine-XML.h 200244 2013-12-10 00:11:55Z correia $

#import <GraphSketcherModel/RSLine.h>
#import <GraphSketcherModel/RSConnectLine.h>
#import <GraphSketcherModel/RSFitLine.h>

#import "RSGraphElement-XML.h"

@interface RSLine (XML) <XMLArchiving>
@end

@interface RSConnectLine (XML)
+ (NSString *)xmlClassName;
- (BOOL)readContentsXML:(OFXMLCursor *)cursor error:(NSError **)outError;
@end

@interface RSFitLine (XML)
+ (NSString *)xmlClassName;
- (BOOL)readContentsXML:(OFXMLCursor *)cursor error:(NSError **)outError;
@end
