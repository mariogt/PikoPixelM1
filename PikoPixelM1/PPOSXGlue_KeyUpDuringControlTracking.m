/*
    PPOSXGlue_KeyUpDuringControlTracking.m

    Copyright 2013-2018 Josh Freeman
    http://www.twilightedge.com

    This file is part of PikoPixel for Mac OS X.
    PikoPixel is a graphical application for drawing & editing pixel-art images.

    PikoPixel is free software: you can redistribute it and/or modify it under
    the terms of the GNU Affero General Public License as published by the
    Free Software Foundation, either version 3 of the License, or (at your
    option) any later version approved for PikoPixel by its copyright holder (or
    an authorized proxy).

    PikoPixel is distributed in the hope that it will be useful, but WITHOUT ANY
    WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
    FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
    details.

    You should have received a copy of the GNU Affero General Public License
    along with this program. If not, see <http://www.gnu.org/licenses/>.
*/

//  On Sierra 10.12+ & Yosemite 10.10-10.10.2, keyboard events are intercepted by the system
// while a control is tracking the mouse; If a key's held down before the user clicks on a
// control, and the key's released while the mouse button is still down, the application won't
// receive a keyUp event.
//  This can cause popup panels to remain visible after the user has released the popup's
// hotkey, and can also cause the screencast popup to continue displaying a key that's no
// longer pressed.
//  The workaround is to catch when mouse tracking begins, and manually post a delayed
// notification (NSMenuDidEndTrackingNotification) that's received as soon as tracking
// finishes - this allows classes that depend on the current keyboard state
// (PPDocumentWindowController, PPScreencastController) to know to recheck the keyboard.
//  Patching -[NSActionCell startTrackingAt:inView:] catches mouse tracking for most controls,
// however there's a few that don't call through to that method, requiring separate patches:
// NSSliderCell, NSSegmentedControl, NSToolbarItemViewer.

#ifdef __APPLE__

#import <Cocoa/Cocoa.h>
#import "NSObject_PPUtilities.h"
#import "PPAppBootUtilities.h"
#import "PPLayerEnabledButtonCell.h"
#import "PPLayerOpacitySliderCell.h"


#define PP_RUNTIME_CHECK__RUNTIME_INTERCEPTS_KEYBOARD_EVENTS_WHEN_TRACKING_CONTROLS     \
            (_PP_RUNTIME_CHECK__MAC_OS_X_VERSION_IS_AT_LEAST_10_(12)                    \
            || (_PP_RUNTIME_CHECK__MAC_OS_X_VERSION_IS_AT_LEAST_10_(10)                 \
                && _PP_RUNTIME_CHECK__MAC_OS_X_VERSION_IS_EARLIER_THAN_10_(10_3)))


@interface NSNotificationCenter (PPOSXGlue_KeyUpDuringControlTrackingUtilities)

+ (void) ppOSXGlue_PostNotification_ControlDidEndTracking;

+ (void) ppOSXGlue_PostNotificationFromNewStackFrame_ControlDidEndTracking;

@end

@implementation NSObject (PPOSXGlue_KeyUpDuringControlTracking)

+ (void) ppOSXGlue_KeyUpDuringControlTracking_InstallPatches
{
    // NSSliderCell doesn't call through to its superclass' implementation of
    // -[NSActionCell startTrackingAt:inView:], so need to patch NSSliderCell's implementation
    // directly in order to catch mouse tracking in sliders; Install NSSliderCell's patch
    // before installing its parent's patch, otherwise NSSliderCell will inherit a method table
    // where the patch method's implementation pointer points to the original implementation of
    // -[NSActionCell startTrackingAt:inView:].
    macroSwizzleInstanceMethod(NSSliderCell, startTrackingAt:inView:,
                                ppOSXPatch_StartTrackingAt:inView:);


    macroSwizzleInstanceMethod(NSActionCell, startTrackingAt:inView:,
                                ppOSXPatch_StartTrackingAt:inView:);


    // NSSegmentedControl & NSToolbarItemViewer (a private class on OS X that handles mouse
    // interaction on NSToolbars) apparently don't use NSActionCells, so in order to catch when
    // the mouse tracks on them, patch their implementations of -[NSView mouseDown:].
    macroSwizzleInstanceMethod(NSSegmentedControl, mouseDown:, ppOSXPatch_MouseDown:);

    macroSwizzleInstanceMethod(NSClassFromString(@"NSToolbarItemViewer"), mouseDown:,
                                ppOSXPatch_MouseDown:);
}

+ (void) load
{
    if (PP_RUNTIME_CHECK__RUNTIME_INTERCEPTS_KEYBOARD_EVENTS_WHEN_TRACKING_CONTROLS)
    {
        macroPerformNSObjectSelectorAfterAppLoads(
                                        ppOSXGlue_KeyUpDuringControlTracking_InstallPatches);
    }
}

@end

@implementation NSActionCell (PPOSXGlue_KeyUpDuringControlTracking)

- (BOOL)  ppOSXPatch_StartTrackingAt: (NSPoint) startPoint inView: (NSView *) controlView
{
    [NSNotificationCenter ppOSXGlue_PostNotificationFromNewStackFrame_ControlDidEndTracking];

    return [self ppOSXPatch_StartTrackingAt: startPoint inView: controlView];
}

@end

@implementation NSView (PPOSXGlue_KeyUpDuringControlTracking)

- (void) ppOSXPatch_MouseDown: (NSEvent *) theEvent
{
    [self ppOSXPatch_MouseDown: theEvent];

    [NSNotificationCenter ppOSXGlue_PostNotificationFromNewStackFrame_ControlDidEndTracking];
}

@end

@implementation NSNotificationCenter (PPOSXGlue_KeyUpDuringControlTrackingUtilities)

+ (void) ppOSXGlue_PostNotification_ControlDidEndTracking
{
    [[self defaultCenter] postNotificationName: NSMenuDidEndTrackingNotification
                            object: nil];
}

+ (void) ppOSXGlue_PostNotificationFromNewStackFrame_ControlDidEndTracking
{
    [self ppPerformSelectorFromNewStackFrame:
                                @selector(ppOSXGlue_PostNotification_ControlDidEndTracking)];
}

@end

#endif  // __APPLE__
