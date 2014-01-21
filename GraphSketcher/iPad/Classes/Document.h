// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Applications/OmniGraphSketcher/iPad/Classes/Document.h 200244 2013-12-10 00:11:55Z correia $

#import <OmniUIDocument/OUIDocument.h>

@class RSGraph, RSGraphEditor, RSUndoer, GraphView;

#import <GraphSketcherModel/RSUndoerOwner.h>
#import <GraphSketcherModel/RSGraphEditorDelegate.h>

@interface Document : OUIDocument <RSUndoerOwner, RSGraphEditorDelegate>
{
@private
    RSGraphEditor *_editor;
    UIViewController *_viewControllerToPresent;
}

@property(readonly) RSGraphEditor *editor;

+ (GraphView *)temporaryGraphViewForDocument:(OUIDocument *)document;

@end
