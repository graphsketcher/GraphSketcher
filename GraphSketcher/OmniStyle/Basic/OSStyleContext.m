// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "OSStyleContext.h"

#import <Foundation/Foundation.h>

#import "OSStyleAttributeRegistry.h"
#import <OmniFoundation/OFXMLIdentifierRegistry.h>
#import <OmniFoundation/OFXMLCursor.h>
#import <OmniFoundation/OFXMLElement.h>

#import <OmniBase/OmniBase.h>

RCS_ID("$Header$");

@implementation OSStyleContext

- init;
{
    OBRejectUnusedImplementation(self, _cmd);
    return nil;
}

- initWithUndoManager:(NSUndoManager *)undoManager identifierRegistry:(OFXMLIdentifierRegistry *)identifierRegistry;
{
    OBPRECONDITION(undoManager);
    
    if (!(self = [super init]))
        return nil;

    _undoManager = [undoManager retain];
    _attributeRegistry = [[OSStyleAttributeRegistry alloc] init];
    _identifierRegistry = identifierRegistry ? [identifierRegistry retain] : [[OFXMLIdentifierRegistry alloc] init];

    return self;
}

- (void)dealloc;
{
    // -invalidate must have been called for us to get deallocated (due to retain cycles)
    OBPRECONDITION(_invalidated);
    OBPRECONDITION(!_attributeRegistry);
    OBPRECONDITION(!_undoManager);
    OBPRECONDITION(!_identifierRegistry);

    [super dealloc];
}

- (void)invalidate;
{
#if 0
    OBExpectDeallocation(self);
#endif
    _invalidated = YES;

    [_attributeRegistry release];
    _attributeRegistry = nil;

    [_undoManager release];
    _undoManager = nil;
   
    [_identifierRegistry clearRegistrations];
    [_identifierRegistry release];
    _identifierRegistry = nil;
}

- (BOOL)isInvalidated;
{
    return _invalidated;
}

- (OSStyleAttributeRegistry *)attributeRegistry;
{
    OBPRECONDITION(!_invalidated);
    return _attributeRegistry;
}

- (NSUndoManager *)undoManager;
{
    OBPRECONDITION(!_invalidated);
    return _undoManager;
}

- (OFXMLIdentifierRegistry *)identifierRegistry;
{
    OBPRECONDITION(_identifierRegistry);
    return _identifierRegistry;
}

@end

