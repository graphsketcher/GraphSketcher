// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OmniInspector/OIInspector.h>
#import <GraphSketcherModel/RSNumber.h>

@class RSSelector, RSGraph;

@interface DataInspector : OIInspector <OIConcreteInspector>
{
    RSSelector *_s;
    RSGraph *_graph;
    
    BOOL _selfChanged;  // when the inspector is updating itself, ignore notifications from itself
    
    RSDataPoint _unfinishedPoint;
}

@property (nonatomic, retain) IBOutlet NSView *view;
@property (nonatomic, assign) IBOutlet NSTableView *tableView;
@property (nonatomic, assign) IBOutlet id connectPointsButton;

- (IBAction)connectPoints:(id)sender;

@end
