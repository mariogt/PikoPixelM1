/*
    PPPanelController.m

    Copyright 2013-2018,2020 Josh Freeman
    http://www.twilightedge.com

    This file is part of PikoPixel for Mac OS X and GNUstep.
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

#import "PPPanelController.h"

#import "PPUserDefaults.h"
#import "PPDocument.h"
#import "NSDocument_PPUtilities.h"
#import "NSObject_PPUtilities.h"
#import "NSWindow_PPUtilities.h"
#import "PPGeometry.h"
#import "PPSRGBUtilities.h"


#define kScreenBoundsPinningMargin_Left             10.0f
#define kScreenBoundsPinningMargin_Right            20.0f
#define kScreenBoundsPinningMargin_Top              35.0f
#define kScreenBoundsPinningMargin_Bottom           20.0f


static NSRect ScreenBoundsForPinningDefaultWindowFrame(void);


@interface PPPanelController (PrivateMethods)

- (void) updatePanelVisibility;
- (void) showPanel;
- (void) hidePanel;
- (void) hidePanelIfDocumentIsInvalid;

- (void) disablePanel;

- (void) setupPanelStateFromUserDefaults;
- (NSRect) defaultPinnedWindowFrame;

@end

#if PP_SDK_REQUIRES_PROTOCOLS_FOR_DELEGATES_AND_DATASOURCES

@interface PPPanelController (RequiredProtocols) <NSWindowDelegate>
@end

#endif

@implementation PPPanelController

+ controller
{
    NSString *panelNibName = [self panelNibName];

    if (!panelNibName)
    {
        return nil;
    }

    return [[[self alloc] initWithWindowNibName: panelNibName] autorelease];
}

- (id) initWithWindowNibName: (NSString *) windowNibName
{
    self = [super initWithWindowNibName: windowNibName];

    if (!self)
        goto ERROR;

    _shouldStorePanelStateInUserDefaults = [self shouldStorePanelStateInUserDefaults];

    if (_shouldStorePanelStateInUserDefaults)
    {
        [PPUserDefaults registerDefaultEnabledState: [self defaultPanelEnabledState]
                            forPanelWithNibName: windowNibName];

        if ([PPUserDefaults enabledStateForPanelWithNibName: windowNibName])
        {
            // user defaults setting wants the panel enabled - requesting the window will
            // force the controller to load it immediately
            [self window];
        }
    }

    return self;

ERROR:
    [self release];

    return nil;
}

- (void) dealloc
{
    [self setPPDocument: nil];

    [super dealloc];
}

+ (NSString *) panelNibName
{
    return nil;
}

- (void) setPPDocument: (PPDocument *) ppDocument
{
    if (_ppDocument == ppDocument)
    {
        return;
    }

    if (_ppDocument)
    {
        [self removeAsObserverForPPDocumentNotifications];
    }

    [_ppDocument release];
    _ppDocument = [ppDocument retain];

    if (_ppDocument && _panelDidLoad)
    {
        [self addAsObserverForPPDocumentNotifications];

        [self setupPanelForCurrentPPDocument];
    }
    else
    {
        [self updatePanelVisibility];
    }
}

- (void) setPanelVisibilityAllowed: (bool) allowPanelVisibility
{
    allowPanelVisibility = (allowPanelVisibility) ? YES : NO;

    if (_allowPanelVisibility != allowPanelVisibility)
    {
        _allowPanelVisibility = allowPanelVisibility;

        if (_allowPanelVisibility)
        {
            // setPanelVisibilityAllowed: can be called while switching document windows,
            // so _ppDocument may not yet point to the new active document - if the panel
            // becomes visible immediately, it will briefly flicker the old document's state
            // before updating with the new document, so delay showing the panel until
            // _ppDocument is definitely valid (next stack frame)

            [self ppPerformSelectorAtomicallyFromNewStackFrame:
                                                            @selector(updatePanelVisibility)];
        }
        else
        {
            [self updatePanelVisibility];
        }
    }
}

- (void) setPanelEnabled: (bool) enablePanel
{
    enablePanel = (enablePanel) ? YES : NO;

    if (_panelIsEnabled == enablePanel)
    {
        return;
    }

    _panelIsEnabled = enablePanel;

    [self updatePanelVisibility];

    if (_shouldStorePanelStateInUserDefaults)
    {
        [PPUserDefaults setEnabledState: _panelIsEnabled
                            forPanelWithNibName: [self windowNibName]];
    }
}

- (void) togglePanelEnabledState
{
    [self setPanelEnabled: (_panelIsEnabled) ? NO : YES];
}

- (bool) panelIsVisible
{
    if (!_panelDidLoad)
    {
        return NO;
    }

    return [[self window] isVisible] ? YES : NO;
}

- (bool) mouseLocationIsInsideVisiblePanel: (NSPoint) mouseLocation
{
    NSWindow *panel;

    if (!_panelDidLoad || !_ppDocument || !_allowPanelVisibility || !_panelIsEnabled)
    {
        return NO;
    }

    panel = [self window];

    return ([panel isVisible]
                && NSMouseInRect(mouseLocation, [panel frame], NO))
            ? YES : NO;
}

- (void) addAsObserverForPPDocumentNotifications
{
}

- (void) removeAsObserverForPPDocumentNotifications
{
}

- (bool) allowPanelToBecomeKey
{
    return NO;
}

- (bool) shouldStorePanelStateInUserDefaults
{
    return YES;
}

- (bool) defaultPanelEnabledState
{
    return NO;
}

- (PPFramePinningType) pinningTypeForDefaultWindowFrame
{
    return kPPFramePinningType_Invalid;
}

- (void) setupPanelForCurrentPPDocument
{
    [self updatePanelVisibility];
}

- (void) setupPanelBeforeMakingVisible
{
}

- (void) setupPanelAfterVisibilityChange
{
}

#pragma mark NSWindowController overrides

- (void) windowDidLoad
{
    NSPanel *panel;

    [super windowDidLoad];

    panel = (NSPanel *) [self window];
    [panel setDelegate: self];
    [panel setBecomesKeyOnlyIfNeeded: YES];

    [panel ppSetSRGBColorSpace];
    [panel ppDisableWindowAnimation];

    if (_shouldStorePanelStateInUserDefaults)
    {
        [self setupPanelStateFromUserDefaults];
    }

    _panelDidLoad = YES;

    if (_ppDocument)
    {
        [self addAsObserverForPPDocumentNotifications];

        [self setupPanelForCurrentPPDocument];
    }
}

#pragma mark NSWindow delegate methods

- (void) windowDidBecomeKey: (NSNotification *) notification
{
    if (![self allowPanelToBecomeKey])
    {
        [_ppDocument ppMakeWindowKey];
    }
}

- (BOOL) windowShouldClose: (id) sender
{
    [self ppPerformSelectorFromNewStackFrame: @selector(disablePanel)];

    return NO;
}

#pragma mark Private methods

- (void) updatePanelVisibility
{
    bool panelIsVisible, panelShouldBeVisible;

    panelIsVisible = ([self panelIsVisible]) ? YES : NO;

    panelShouldBeVisible = (_allowPanelVisibility && _panelIsEnabled && _ppDocument) ? YES : NO;

    if (panelIsVisible == panelShouldBeVisible)
    {
        return;
    }

    if (panelShouldBeVisible)
    {
        [self showPanel];
    }
    else
    {
        if (_ppDocument)
        {
            [self hidePanel];
        }
        else
        {
            // when _ppDocument is invalid, delay hiding the panel until the next stack
            // frame - this keeps the panel from flickering off/on when switching to a
            // different document window (_ppDocument is nil temporarily, but will be valid
            // by the next frame)

            [self ppPerformSelectorAtomicallyFromNewStackFrame:
                                                @selector(hidePanelIfDocumentIsInvalid)];
        }
    }
}

- (void) showPanel
{
    NSWindow *panel;

    if ([self panelIsVisible])
    {
        return;
    }

    panel = [self window]; // make sure window is loaded before setup

    [self setupPanelBeforeMakingVisible];

    [panel orderFront: self];

    [self setupPanelAfterVisibilityChange];
}

- (void) hidePanel
{
    if (![self panelIsVisible])
    {
        return;
    }

    [[self window] orderOut: self];

    [self setupPanelAfterVisibilityChange];
}

- (void) hidePanelIfDocumentIsInvalid
{
    if (!_ppDocument)
    {
        [self hidePanel];
    }
}

- (void) disablePanel
{
    [self setPanelEnabled: NO];
}

- (void) setupPanelStateFromUserDefaults
{
    NSRect defaultWindowFrame;
    NSString *windowNibName;

    if (!_shouldStorePanelStateInUserDefaults)
        return;

    defaultWindowFrame = [self defaultPinnedWindowFrame];

    if (!NSIsEmptyRect(defaultWindowFrame))
    {
        [[self window] setFrame: defaultWindowFrame display: NO];
    }

    windowNibName = [self windowNibName];

    [[self window] setFrameAutosaveName: windowNibName];

    // Panel won't be visible after nib is loaded (set to remain hidden), so enable if needed

    if ([PPUserDefaults enabledStateForPanelWithNibName: windowNibName])
    {
        [self setPanelEnabled: YES];
    }
}

- (NSRect) defaultPinnedWindowFrame
{
    NSRect screenBoundsForWindowFrame, windowFrame;
    PPFramePinningType framePinningType;

    screenBoundsForWindowFrame = ScreenBoundsForPinningDefaultWindowFrame();

    windowFrame = [[self window] frame];

    framePinningType = [self pinningTypeForDefaultWindowFrame];

    if (!PPFramePinningType_IsValid(framePinningType))
    {
        goto ERROR;
    }

    // horizontal pinning

    switch (framePinningType)
    {
        case kPPFramePinningType_TopLeft:
        case kPPFramePinningType_CenterLeft:
        case kPPFramePinningType_BottomLeft:
        {
            windowFrame.origin.x = screenBoundsForWindowFrame.origin.x;
        }
        break;

        case kPPFramePinningType_TopRight:
        case kPPFramePinningType_CenterRight:
        case kPPFramePinningType_BottomRight:
        {
            windowFrame.origin.x = screenBoundsForWindowFrame.origin.x
                                    + screenBoundsForWindowFrame.size.width
                                    - windowFrame.size.width;
        }
        break;

        default:
        break;
    }

    // vertical pinning

    switch (framePinningType)
    {
        case kPPFramePinningType_TopLeft:
        case kPPFramePinningType_TopRight:
        {
            windowFrame.origin.y = screenBoundsForWindowFrame.origin.y
                                    + screenBoundsForWindowFrame.size.height
                                    - windowFrame.size.height;
        }
        break;

        case kPPFramePinningType_CenterLeft:
        case kPPFramePinningType_CenterRight:
        {
            windowFrame.origin.y =
                roundf(screenBoundsForWindowFrame.origin.y
                        + (screenBoundsForWindowFrame.size.height - windowFrame.size.height)
                            / 2.0f);
        }
        break;

        case kPPFramePinningType_BottomLeft:
        case kPPFramePinningType_BottomRight:
        {
            windowFrame.origin.y = screenBoundsForWindowFrame.origin.y;
        }
        break;

        default:
        break;
    }

    return windowFrame;

ERROR:
    if (!NSIsEmptyRect(screenBoundsForWindowFrame) && !NSIsEmptyRect(windowFrame))
    {
        windowFrame.origin =
            PPGeometry_OriginPointForConfiningRectInsideRect(windowFrame,
                                                                screenBoundsForWindowFrame);
    }

    return windowFrame;
}

@end

#pragma mark Private functions

static NSRect ScreenBoundsForPinningDefaultWindowFrame(void)
{
    NSRect screenBounds = [[NSScreen mainScreen] visibleFrame];

    screenBounds.origin.x += kScreenBoundsPinningMargin_Left;
    screenBounds.origin.y += kScreenBoundsPinningMargin_Bottom;

    screenBounds.size.width -=
                            kScreenBoundsPinningMargin_Left + kScreenBoundsPinningMargin_Right;
    screenBounds.size.height -=
                            kScreenBoundsPinningMargin_Top + kScreenBoundsPinningMargin_Bottom;

    return PPGeometry_PixelBoundsCoveredByRect(screenBounds);
}
