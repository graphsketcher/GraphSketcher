// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/Model/XML/RSGraph-XML.h 200244 2013-12-10 00:11:55Z correia $

#import <GraphSketcherModel/RSGraph.h>
#import "RSGraphElement-XML.h"

extern NSString * const RSGraphFileType;

@interface RSGraph (XML) <XMLArchiving>

// Public helper methods
- (NSString *)idrefsFromArray:(NSArray *)array;
- (OSStyle *)defaultBaseStyle;

// Archiving for pasteboards
+ (NSData *)archivedDataWithRootObject:(RSGraphElement *)GE graphID:(NSString *)graphID error:(NSError **)outError;
- (RSGraphElement *)unarchiveObjectWithData:(NSData *)data getGraphID:(NSString **)graphID error:(NSError **)outError;

@end
