/*
    PPApplication.m

    Copyright 2013-2018 Josh Freeman
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

#import "PPApplication.h"

#import "PPHotkeys.h"
#import "PPHotkeySettingsWindowController.h"
#import "PPDocument.h"
#import "NSDocumentController_PPUtilities.h"
#import "NSPasteboard_PPUtilities.h"
#import "PPDocumentWindow.h"
#import "NSColorPanel_PPUtilities.h"
#import "NSDocumentController_PPUtilities.h"
#import "PPModifierKeyMasks.h"
#import "PPAppBootUtilities.h"


#define kNonzeroModifierMaskForMenuItemsWithArrowKeyEquivalents         (NSAlternateKeyMask)


@interface PPApplication (PrivateMethods)

- (void) addAsObserverForNSWindowNotifications;
- (void) removeAsObserverForNSWindowNotifications;
- (void) handleNSWindowNotification_DidBecomeKey: (NSNotification *) notification;

- (void) addAsObserverForPPHotkeysNotifications;
- (void) removeAsObserverForPPHotkeysNotifications;
- (void) handlePPHotkeysNotification_UpdatedHotkeys: (NSNotification *) notification;

- (void) updateMainMenuForWindow: (NSWindow *) window;
- (void) updateMainMenuForCurrentKeyWindow;
- (void) updateMenuItemKeyEquivalentsForCurrentHotkeys;
- (void) setupPreviousWindowMenuItemKeyEquivalentFromLocalizedHotkey;
- (void) setupNonzeroModifierMasksForMenuItemsWithArrowKeyEquivalents;

@end


#if PP_SDK_REQUIRES_PROTOCOLS_FOR_DELEGATES_AND_DATASOURCES

@interface PPApplication (RequiredProtocols) <NSApplicationDelegate>
@end

#endif  // PP_SDK_REQUIRES_PROTOCOLS_FOR_DELEGATES_AND_DATASOURCES


@implementation PPApplication

- init
{
    self = [super init];

    if (!self)
        goto ERROR;

    [self setDelegate: self];

    return self;

ERROR:
    [self release];

    return nil;
}

#pragma mark Actions

- (IBAction) editHotkeySettings: (id) sender
{
    [[PPHotkeySettingsWindowController sharedController] showPanel];
}

- (IBAction) newDocumentFromPasteboard: (id) sender
{
    [[NSDocumentController sharedDocumentController]
                                ppOpenUntitledDuplicateOfPPDocument:
                                                        [PPDocument ppDocumentFromPasteboard]];
}

- (IBAction) activateNextDocumentWindow: (id) sender
{
    [[NSDocumentController sharedDocumentController] ppActivateNextDocument];
}

- (IBAction) activatePreviousDocumentWindow: (id) sender
{
    [[NSDocumentController sharedDocumentController] ppActivatePreviousDocument];
}

#pragma mark NSApplication overrides

- (void) finishLaunching
{
    PPAppBootUtils_HandleAppDidFinishLoading();

    [super finishLaunching];
}

- (BOOL) validateMenuItem: (PPSDKNativeType_NSMenuItemPtr) menuItem
{
    SEL menuItemAction = [menuItem action];

    if (menuItemAction == @selector(newDocumentFromPasteboard:))
    {
        return [NSPasteboard ppPasteboardHasBitmap] ? YES : NO;
    }

    // printing is currently disabled, so both printing-related menu items (print & page setup)
    // use runPageLayout: as their action for convenience when invalidating them

    if (menuItemAction == @selector(runPageLayout:))
    {
        return NO;
    }


    if ((menuItemAction == @selector(activateNextDocumentWindow:))
        || (menuItemAction == @selector(activatePreviousDocumentWindow:)))
    {
        return [[NSDocumentController sharedDocumentController] ppHasMultipleDocuments];
    }

    return YES;
}

#pragma mark NSApplication delegate methods

- (void) applicationDidFinishLaunching: (NSNotification *) notification
{
    // Main menu

    [self updateMainMenuForCurrentKeyWindow];

    [self addAsObserverForNSWindowNotifications];

    if (PP_RUNTIME_CHECK__RUNTIME_INTERCEPTS_INACTIVE_MENUITEM_KEY_EQUIVALENTS)
    {
        // if the runtime intercepts keyDown events for menu items that are inactive (10.4),
        // then set nonzero modifier masks for menu items with arrow key equivalents,
        // otherwise the arrow keys won't work on popup panels

        [self setupNonzeroModifierMasksForMenuItemsWithArrowKeyEquivalents];
    }


    // Hotkeys

    [PPHotkeys setupGlobals];

    [self updateMenuItemKeyEquivalentsForCurrentHotkeys];

    [self setupPreviousWindowMenuItemKeyEquivalentFromLocalizedHotkey];

    [self addAsObserverForPPHotkeysNotifications];


    // Alpha-channel support

    [NSColor setIgnoresAlpha: NO];  // enable alpha-channel support & color panel opacity slider


    // Shared Color Panel

    [NSColorPanel ppSetupSharedColorPanel];


    // Autosaving Delay

    [[NSDocumentController sharedDocumentController] setAutosavingDelay: kAutosaveDelay];
}

- (BOOL) applicationShouldHandleReopen: (NSApplication *) sender hasVisibleWindows: (BOOL) flag
{
    return NO;
}

#pragma mark NSWindow notifications

- (void) addAsObserverForNSWindowNotifications
{
    [[NSNotificationCenter defaultCenter]
                                addObserver: self
                                selector:
                                    @selector(handleNSWindowNotification_DidBecomeKey:)
                                name: NSWindowDidBecomeKeyNotification
                                object: nil];
}

- (void) removeAsObserverForNSWindowNotifications
{
    [[NSNotificationCenter defaultCenter] removeObserver: self
                                            name: NSWindowDidBecomeKeyNotification
                                            object: nil];
}

- (void) handleNSWindowNotification_DidBecomeKey: (NSNotification *) notification
{
    [self updateMainMenuForWindow: [notification object]];
}

#pragma mark PPHotkeys notifications

- (void) addAsObserverForPPHotkeysNotifications
{
    [[NSNotificationCenter defaultCenter]
                    addObserver: self
                    selector: @selector(handlePPHotkeysNotification_UpdatedHotkeys:)
                    name: PPHotkeysNotification_UpdatedHotkeys
                    object: nil];
}

- (void) removeAsObserverForPPHotkeysNotifications
{
    [[NSNotificationCenter defaultCenter] removeObserver: self
                                            name: PPHotkeysNotification_UpdatedHotkeys
                                            object: nil];
}

- (void) handlePPHotkeysNotification_UpdatedHotkeys: (NSNotification *) notification
{
    [self updateMenuItemKeyEquivalentsForCurrentHotkeys];
}

#pragma mark Private methods

- (void) updateMainMenuForWindow: (NSWindow *) window
{
    bool windowIsPPDocumentWindow;
    NSString *pasteItemTitle;

    windowIsPPDocumentWindow = [window isKindOfClass: [PPDocumentWindow class]];
    pasteItemTitle = (windowIsPPDocumentWindow) ? @"Paste as New Layer" : @"Paste";

    if (![[_pasteMenuItem title] isEqualToString: pasteItemTitle])
    {
        [_pasteMenuItem setTitle: NSLocalizedString(pasteItemTitle, nil)];
    }
}

- (void) updateMainMenuForCurrentKeyWindow
{
    [self updateMainMenuForWindow: [self keyWindow]];
}

- (void) updateMenuItemKeyEquivalentsForCurrentHotkeys
{
    [_canvasDisplayModeMenuItem setKeyEquivalent:
                                            gHotkeys[kPPHotkeyType_SwitchCanvasViewMode]];

    [_layerOperationTargetMenuItem setKeyEquivalent:
                                        gHotkeys[kPPHotkeyType_SwitchLayerOperationTarget]];

    [_zoomInMenuItem setKeyEquivalent: gHotkeys[kPPHotkeyType_ZoomIn]];

    [_zoomOutMenuItem setKeyEquivalent: gHotkeys[kPPHotkeyType_ZoomOut]];

    [_zoomToFitMenuItem setKeyEquivalent: gHotkeys[kPPHotkeyType_ZoomToFit]];

    [_toggleActivePanelsMenuItem setKeyEquivalent: gHotkeys[kPPHotkeyType_ToggleActivePanels]];

    [_toggleColorPickerMenuItem setKeyEquivalent:
                                            gHotkeys[kPPHotkeyType_ToggleColorPickerPanel]];
}

- (void) setupPreviousWindowMenuItemKeyEquivalentFromLocalizedHotkey
{
    NSString *localizedBacktickKeyEquivalent;

    // The "Previous Window" menu item's key equivalent should be whichever localized key
    // occupies the position above the Tab key (which is used as the key equivalent for
    // "Next Window"); On US keyboards (default), it's the backtick (`) key

    // Verify the menu item's key equivalent is a modified backtick
    if (![[_previousWindowMenuItem keyEquivalent] isEqualToString: @"`"]
        || !([_previousWindowMenuItem keyEquivalentModifierMask]
                & kModifierKeyMask_RecognizedModifierKeys))
    {
        goto ERROR;
    }

    localizedBacktickKeyEquivalent = [PPHotkeys localizedBacktickKeyEquivalent];

    if (!localizedBacktickKeyEquivalent)
        goto ERROR;

    if (![localizedBacktickKeyEquivalent isEqualToString: @"`"])
    {
        [_previousWindowMenuItem setKeyEquivalent: localizedBacktickKeyEquivalent];
    }

    return;

ERROR:
    return;
}

- (void) setupNonzeroModifierMasksForMenuItemsWithArrowKeyEquivalents
{
    [_leftArrowKeyEquivalentMenuItem
        setKeyEquivalentModifierMask: kNonzeroModifierMaskForMenuItemsWithArrowKeyEquivalents];

    [_rightArrowKeyEquivalentMenuItem
        setKeyEquivalentModifierMask: kNonzeroModifierMaskForMenuItemsWithArrowKeyEquivalents];
}

@end
