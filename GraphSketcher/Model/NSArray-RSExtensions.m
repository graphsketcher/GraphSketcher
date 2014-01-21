// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/Model/NSArray-RSExtensions.m 200244 2013-12-10 00:11:55Z correia $

#import "NSArray-RSExtensions.h"


@implementation NSArray (RSExtensions)


- (NSMutableArray *)objectsWithClass:(Class)c;
{
    id obj;
    NSMutableArray *A = [[NSMutableArray alloc] init];
    
    for (obj in self) {
	if ( [obj isKindOfClass:c] ) [A addObject:obj];
    }
    return [A autorelease];
}

- (NSUInteger)numberOfObjectsWithClass:(Class)c;
{
    int count = 0;
    for (id obj in self) {
        if ([obj isKindOfClass:c])
            count++;
    }
    return count;
}

- (id)firstObjectWithClass:(Class)c;
{
    id obj;
    
    for (obj in self) {
	if ( [obj isKindOfClass:c] ) return obj;
    }
    return nil;
}


@end
