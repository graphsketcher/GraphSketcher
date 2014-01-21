// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/OmniStyle/Basic/OSStyleListener.h 200244 2013-12-10 00:11:55Z correia $

#import <Foundation/NSObject.h>

@class OSStyle, OSStyleChange;

typedef NSUInteger OSStyleChangeInfo; // A combination of a kind and scope.

typedef enum {
    OSStyleChangeKindAttribute, // An individual attribute
    OSStyleChangeKindCascadeStyle, // Reference to or more cascade styles
    OSStyleChangeKindName, // Name of a named style. This doesn't imply any attribute change, so should be done some other way (KVO on the named style name?)
    
    OSStyleChangeKindMask = 0xff,
} OSStyleChangeKind;

typedef enum {
    OSStyleChangeScopeLocal = (0 << 8),
    OSStyleChangeScopeCascade = (1 << 8),

    OSStyleChangeScopeMask = (0xff << 8),
} OSStyleChangeScope;

@protocol OSStyleListener <NSObject>
/*" The OSStyleListener protocol provides a hardcoded notification mechanism for style changes.  Typically this would be done via NSNotificationCenter, but in at least some of the cases where we are going to use OSStyle (OmniOutliner), this would be a performance problem. "*/
// TJW: One downside to having this protocol is that we need to be careful to manage subscription/unsubscription during notification (which NSNotificationCenter handles for us).
- (void)style:(OSStyle *)style willChange:(OSStyleChangeInfo)changeInfo;
- (void)style:(OSStyle *)style didChange:(OSStyleChange *)change;

@end
