// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OmniFoundation/OFObject.h>
#import <OmniFoundation/OFSaveType.h>

#import "OSStyleListener.h"

@class OSStyle, OSStyleContext, OSStyleAttributeRegistry;
@class OFXMLCursor, OFXMLDocument, OFXMLIdentifierRegistry;
@class NSUndoManager;

@interface OSStyleContext : OFObject
{
@private
    OSStyleAttributeRegistry *_attributeRegistry;
    OFXMLIdentifierRegistry  *_identifierRegistry;
    NSUndoManager *_undoManager;
    BOOL _invalidated;
}

- initWithUndoManager:(NSUndoManager *)undoManager identifierRegistry:(OFXMLIdentifierRegistry *)identifierRegistry;

- (void)invalidate;
- (BOOL)isInvalidated;

@property(readonly,nonatomic) BOOL allowUserEdits; // Just asks the delegate

@property(readonly,nonatomic) OSStyleAttributeRegistry *attributeRegistry;
@property(readonly,nonatomic) NSUndoManager *undoManager;

@property(readonly,nonatomic) OFXMLIdentifierRegistry *identifierRegistry;

@end
