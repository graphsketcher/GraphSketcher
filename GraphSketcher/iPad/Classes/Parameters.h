// Copyright 2003-2013 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

// Non-engineers on the UI team should be able to easily tweak parameters for animations, content sizes, etc. without having to ask an engineer to try out every change.  This file is a place to put all parameter #defines that non-engineers can safely adjust.


// These set the delays required before you can move a selection or bring up the contextual menu.
#define SELECTION_DELAY 0.15  // seconds
#define EDIT_MENU_DELAY 0.4

// This roughly sets the size of the "touch effect" that emerges when your finger touches an object on-screen.
#define RS_FINGER_WIDTH 100  // pixels

// Animation parameters for the pulse effect you get when drawing lines with the tap-tap method.
#define PULSE_EFFECT_WIDTH 80  // in pixels
#define PULSE_EFFECT_DELTA 2  // +/- width during pulse (in pixels)
#define PULSE_EFFECT_DELAY 0.2  // seconds
#define PULSE_BEGIN_DELAY 1  // seconds

// These determine the recognition of fill corners when drawing a fill.
#define CORNER_PAUSE_DELAY 0.15  // seconds
#define CORNER_PAUSE_VELOCITY 60 // points per second

// Animation parameters for the expando effect you get when a fill corner is created.
#define RS_POINT_CREATION_EFFECT_EXPANSION 70  // pixels
#define RS_POINT_CREATION_EFFECT_DURATION 0.3  // seconds

// Edit menu
#define CONTEXT_MENU_MAX_SIZE_OF_OBJECT_FOR_EXTERNAL_POSITIONING CGSizeMake(200, 80)

// Rectangular select visual
#define RECTANGULAR_SELECT_STARTING_SIZE CGSizeMake(80, 70)

// Axis manipulation graphics
#define AXIS_TICK_SPACING_KNOB_TIP_INSET CGPointMake(0, 3)  // measured from bottom center
#define AXIS_END_LABEL_HORIZONTAL_RESIZE_PIXEL 16  // measured from extending end
#define AXIS_END_LABEL_HORIZONTAL_MAX_TIP_INSET CGPointMake(3, 0)  // measured from the tip's corner
#define AXIS_END_LABEL_HORIZONTAL_MIN_TIP_INSET CGPointMake(3, 0)  // "
#define AXIS_END_LABEL_HORIZONTAL_TEXT_INSET CGPointMake(16, 4)  // measured from upper extending corner

#define AXIS_END_LABEL_VERTICAL_RESIZE_PIXEL 16  // measured from extending end
#define AXIS_END_LABEL_VERTICAL_MAX_TIP_INSET CGPointMake(0, 0)  // measured from the tip's corner
#define AXIS_END_LABEL_VERTICAL_MIN_TIP_INSET CGPointMake(0, 5)  // "
#define AXIS_END_LABEL_VERTICAL_TEXT_INSET CGPointMake(17, -2)  // measured from upper extending corner

#define INSPECTOR_POPOVER_HEIGHT 330

