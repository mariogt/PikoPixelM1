/*
    PPDocumentWindowController.m

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

#import "PPDocumentWindowController.h"

#import "PPDocumentWindowController_Notifications.h"
#import "PPModifierKeyMasks.h"
#import "PPDocument.h"
#import "PPCanvasView.h"
#import "PPDocumentWindowController_Sheets.h"
#import "PPPanelsController.h"
#import "PPPopupPanelsController.h"
#import "PPToolbox.h"
#import "PPTool.h"
#import "PPModifiablePPToolTypesMasks.h"
#import "NSColor_PPUtilities.h"
#import "PPHotkeys.h"
#import "PPGeometry.h"
#import "PPDirectionType.h"
#import "NSObject_PPUtilities.h"
#import "PPCursorManager.h"
#import "PPLayerControlButtonImagesManager.h"


#define kWindowNibName  @"DocumentWindow"

#define kNewWindowScreenMargin_Sides            330
#define kNewWindowScreenMargin_Top              5
#define kNewWindowScreenMargin_Bottom           120

#define kHotkeyRepeatTimeoutInterval            0.7f


static NSSize gNewWindowContentSize = {0,0};
static NSPoint gNewWindowCascadePoint = {0,0};
static NSDictionary *gHotkeyToActionSelectorNameDict = nil;


@interface PPDocumentWindowController (PrivateMethods)

- (void) addAsObserverForPPDocumentNotifications;
- (void) removeAsObserverForPPDocumentNotifications;
- (void) handlePPDocumentNotification_UpdatedMergedVisibleArea: (NSNotification *) notification;
- (void) handlePPDocumentNotification_UpdatedDrawingLayerArea: (NSNotification *) notification;
- (void) handlePPDocumentNotification_UpdatedSelection: (NSNotification *) notification;
- (void) handlePPDocumentNotification_SwitchedSelectedTool: (NSNotification *) notification;
- (void) handlePPDocumentNotification_UpdatedBackgroundSettings:
                                                            (NSNotification *) notification;
- (void) handlePPDocumentNotification_UpdatedGridSettings: (NSNotification *) notification;
- (void) handlePPDocumentNotification_ReloadedDocument: (NSNotification *) notification;
- (void) handlePPDocumentNotification_SwitchedActiveSamplerImage:
                                                            (NSNotification *) notification;

- (void) addAsObserverForPPCanvasViewNotifications;
- (void) removeAsObserverForPPCanvasViewNotifications;
- (void) handlePPCanvasViewNotification_ChangedZoomFactor: (NSNotification *) notification;

- (void) addAsObserverForNSWindowWillMoveNotifications;
- (void) removeAsObserverForNSWindowWillMoveNotifications;
- (void) handleNSWindowNotification_WillMove: (NSNotification *) notification;

- (void) addAsObserverForNSMenuDidEndTrackingNotifications;
- (void) removeAsObserverForNSMenuDidEndTrackingNotifications;
- (void) handleNSMenuNotification_DidEndTracking: (NSNotification *) notification;

+ (void) addAsObserverForPPHotkeysNotifications;
+ (void) removeAsObserverForPPHotkeysNotifications;
+ (void) handlePPHotkeysNotification_UpdatedHotkeys: (NSNotification *) notification;

- (void) startPopupPanelHotkeyRepeatTimeoutTimer;
- (void) stopPopupPanelHotkeyRepeatTimeoutTimer;
- (void) popupPanelHotkeyRepeatTimeoutTimerDidFire: (NSTimer *) timer;

+ (void) setupNewWindowGlobals;
+ (void) setupHotkeyToActionSelectorNameDict;

- (void) positionNewWindow;

- (void) setupWindowForCurrentPPDocument;
- (void) setupCanvasViewForCurrentPPDocument;
- (void) setupCanvasViewBitmap;
- (void) matchCanvasDisplayModeToOperationTarget;
- (void) restoreCanvasDisplayModeFromOperationTarget;
- (void) setupPanelsWithPPDocument: (PPDocument *) ppDocument;

- (void) setActivePopupPanelType: (PPPopupPanelType) popupPanelType
            withPressedHotkey: (NSString *) pressedHotkey;
- (void) hideActivePopupPanel;

- (bool) getDirectionType: (PPDirectionType *) returnedDirectionType
            forArrowKey: (NSString *) key;

- (bool) handleActionKey: (NSString *) key;
- (void) updateKeyboardStateForResumedKeyboardEvents;
- (NSPoint) mouseLocationFromEvent: (NSEvent *) event
            clippedToCanvasBounds: (bool) shouldClipToCanvasBounds;
- (void) updateModifierKeyFlags: (unsigned) modifierKeyFlags;
- (void) updateModifierKeyFlagsFromCurrentKeyboardState;
- (void) updateActiveTool;
- (void) updateCanvasViewToolCursorForActiveTool;
- (PPToolType) modifiedToolTypeForSelectedToolType: (PPToolType) selectedToolType;

@end

@implementation PPDocumentWindowController

+ (void) initialize
{
    if ([self class] != [PPDocumentWindowController class])
    {
        return;
    }

    [self setupNewWindowGlobals];

    [PPHotkeys setupGlobals];

    [self setupHotkeyToActionSelectorNameDict];

    [self addAsObserverForPPHotkeysNotifications];
}

+ controller
{
    return [[[self alloc] init] autorelease];
}

- init
{
    self = [super initWithWindowNibName: kWindowNibName];

    if (!self)
        goto ERROR;

    _panelsController = [[PPPanelsController sharedController] retain];
    _popupPanelsController = [[PPPopupPanelsController sharedController] retain];

    if (!_panelsController || !_popupPanelsController)
    {
        goto ERROR;
    }

    return self;

ERROR:
    [self release];

    return nil;
}

- (void) dealloc
{
    [self removeAsObserverForPPCanvasViewNotifications];
    [self removeAsObserverForNSWindowWillMoveNotifications];
    [self removeAsObserverForNSMenuDidEndTrackingNotifications];

    [self hideActivePopupPanel];

    [_panelsController release];
    [_popupPanelsController release];

    [super dealloc];
}

- (PPCanvasView *) canvasView
{
    return _canvasView;
}

- (void) setCanvasDisplayMode: (PPLayerDisplayMode) canvasDisplayMode
{
    if (_isTrackingMouseInCanvasView)
        return;

    if (canvasDisplayMode != kPPLayerDisplayMode_DrawingLayerOnly)
    {
        canvasDisplayMode = kPPLayerDisplayMode_VisibleLayers;
    }

    if (_canvasDisplayMode == canvasDisplayMode)
    {
        return;
    }

    _canvasDisplayMode = canvasDisplayMode;

    [self setupCanvasViewBitmap];

    [self postNotification_ChangedCanvasDisplayMode];
}

- (void) toggleCanvasDisplayMode
{
    PPLayerDisplayMode newDisplayMode;

    if (_canvasDisplayMode == kPPLayerDisplayMode_DrawingLayerOnly)
    {
        newDisplayMode = kPPLayerDisplayMode_VisibleLayers;
    }
    else
    {
        newDisplayMode = kPPLayerDisplayMode_DrawingLayerOnly;
    }

    [self setCanvasDisplayMode: newDisplayMode];
}

- (PPLayerDisplayMode) canvasDisplayMode
{
    return _canvasDisplayMode;
}

- (bool) isTrackingMouseInCanvasView
{
    return _isTrackingMouseInCanvasView;
}

#pragma mark NSWindowController overrides

- (void) mouseDown: (NSEvent *) theEvent
{
    if (![_canvasView windowPointIsInsideVisibleCanvas: [theEvent locationInWindow]])
    {
        return;
    }

    [_ppDocument disableAutosaving: YES];

    [self updateModifierKeyFlags: [theEvent modifierFlags]];

    if (_shouldMatchCanvasDisplayModeToOperationTargetWhileTrackingMouse)
    {
        [self matchCanvasDisplayModeToOperationTarget];
    }

    [_canvasView setIsDraggingTool: YES];

    _isTrackingMouseInCanvasView = YES;

    _mouseDownLocation = _lastMouseLocation = [self mouseLocationFromEvent: theEvent
                                                    clippedToCanvasBounds: YES];

    [[_ppDocument activeTool] mouseDownForDocument: _ppDocument
                                withCanvasView: _canvasView
                                currentPoint: _mouseDownLocation
                                modifierKeyFlags: _modifierKeyFlags];

    [_canvasView setShouldAnimateSelectionOutline: NO];
}

- (void) mouseDragged: (NSEvent *) theEvent
{
    NSPoint mouseLocation;

    if (!_isTrackingMouseInCanvasView)
        return;

    mouseLocation = [self mouseLocationFromEvent: theEvent
                            clippedToCanvasBounds: _shouldClipMouseLocationPointsToCanvasBounds];

    if (NSEqualPoints(mouseLocation, _lastMouseLocation)
        && ![_canvasView isAutoscrolling])
    {
        return;
    }

    [[_ppDocument activeTool] mouseDraggedOrModifierKeysChangedForDocument: _ppDocument
                                withCanvasView: _canvasView
                                currentPoint: mouseLocation
                                lastPoint: _lastMouseLocation
                                mouseDownPoint: _mouseDownLocation
                                modifierKeyFlags: _modifierKeyFlags];

    _lastMouseLocation = mouseLocation;
}

- (void) mouseUp: (NSEvent *) theEvent
{
    NSPoint mouseLocation;

    [_canvasView setShouldAnimateSelectionOutline: [[self window] isKeyWindow]];

    if (!_isTrackingMouseInCanvasView)
        return;

    [_canvasView setIsDraggingTool: NO];

    _isTrackingMouseInCanvasView = NO;

    mouseLocation = [self mouseLocationFromEvent: theEvent
                            clippedToCanvasBounds: _shouldClipMouseLocationPointsToCanvasBounds];

    [[_ppDocument activeTool] mouseUpForDocument: _ppDocument
                                withCanvasView: _canvasView
                                currentPoint: mouseLocation
                                mouseDownPoint: _mouseDownLocation
                                modifierKeyFlags: _modifierKeyFlags];

    if (_shouldMatchCanvasDisplayModeToOperationTargetWhileTrackingMouse)
    {
        [self restoreCanvasDisplayModeFromOperationTarget];
    }

    _lockedActiveToolModifierKeyFlags = _modifierKeyFlags;

    if (_shouldUpdateActiveToolOnMouseUp)
    {
        [self updateActiveTool];

        _shouldUpdateActiveToolOnMouseUp = NO;
    }

    [_ppDocument disableAutosaving: NO];
}

- (void) keyDown: (NSEvent *) theEvent
{
    NSString *key;
    unsigned modifierFlags;
    PPPopupPanelType popupPanelType;
    PPToolType toolType;
    PPDirectionType directionType;

    key = [theEvent charactersIgnoringModifiers];
    modifierFlags = [theEvent modifierFlags];

    [self updateModifierKeyFlags: modifierFlags];

    if (_popupPanelHotkeyRepeatTimeoutTimer
        && [key rangeOfString: _pressedHotkeyForActivePopupPanel].length)
    {
        [self stopPopupPanelHotkeyRepeatTimeoutTimer];
    }

    if (modifierFlags & kModifierKeyMask_RecognizedModifierKeys)
    {
        return;
    }

    // key commands that are permitted while tracking mouse

    if ([key isEqualToString: gHotkeys[kPPHotkeyType_BlinkDocumentLayers]])
    {
        [_canvasView setDocumentLayersVisibility: NO];

        return;
    }

    if (_isTrackingMouseInCanvasView)
        return;

    // key commands that are NOT permitted while tracking mouse

    if ([_popupPanelsController hasActivePopupPanel])
    {
        if ([key isEqualToString: _pressedHotkeyForActivePopupPanel])
        {
            return;
        }

        if ([_popupPanelsController handleActionKey: key])
        {
            return;
        }
    }
    else if ([_popupPanelsController getPopupPanelType: &popupPanelType forKey: key])
    {
        [self setActivePopupPanelType: popupPanelType withPressedHotkey: key];

        return;
    }

    if ([PPToolbox getToolType: &toolType forKey: key])
    {
        [_ppDocument setSelectedToolType: toolType];

        return;
    }

    if ([self getDirectionType: &directionType forArrowKey: key])
    {
        if ([_popupPanelsController hasActivePopupPanel])
        {
            [_popupPanelsController handleDirectionCommand: directionType];
        }

        return;
    }

    [self handleActionKey: key];
}

- (void) keyUp: (NSEvent *) theEvent
{
    NSString *eventChars = [theEvent charactersIgnoringModifiers];

    if (_pressedHotkeyForActivePopupPanel
        && [eventChars rangeOfString: _pressedHotkeyForActivePopupPanel].length)
    {
        [self hideActivePopupPanel];
    }

    if ([eventChars rangeOfString: gHotkeys[kPPHotkeyType_BlinkDocumentLayers]].length)
    {
        [_canvasView setDocumentLayersVisibility: YES];
    }
}

- (void) flagsChanged: (NSEvent *) theEvent
{
    [self updateModifierKeyFlags: [theEvent modifierFlags]];
}

- (void) windowDidLoad
{
    [super windowDidLoad];

    [self positionNewWindow];

    [self showWindow: self];

    // window positioning may not take effect until the next stack frame, so delay any sheets
    // until a new stack frame as well, otherwise the window may temporarily remain in its
    // original position while the sheet's pulldown animation (which begins immediately)
    // displays

    if ([_ppDocument needToSetCanvasSize])
    {
        [self ppPerformSelectorFromNewStackFrame: @selector(beginSizeSheet)];
    }
    else
    {
        [self setupWindowForCurrentPPDocument];

        if ([_ppDocument sourceBitmapHasAnimationFrames])
        {
            [self ppPerformSelectorFromNewStackFrame: @selector(beginAnimationFileNoticeSheet)];
        }
    }

    [self addAsObserverForPPCanvasViewNotifications];
}

- (void) setDocument: (NSDocument *) document
{
    if (_ppDocument)
    {
        [self removeAsObserverForPPDocumentNotifications];
    }

    [super setDocument: document];

    if ([document isKindOfClass: [PPDocument class]])
    {
        _ppDocument = (PPDocument *) document;

        [self addAsObserverForPPDocumentNotifications];

        [self updateActiveTool];
    }
    else
    {
        _ppDocument = nil;
    }
}

- (NSString *) windowTitleForDocumentDisplayName: (NSString *) displayName
{
    NSSize canvasSize = [_ppDocument canvasSize];

    if (!PPGeometry_IsZeroSize(canvasSize))
    {
        NSString *zoomSuffix = [NSString stringWithFormat: @" (%dx%d) (%dx)",
                                                            (int) canvasSize.width,
                                                            (int) canvasSize.height,
                                                            (int) [_canvasView zoomFactor]];

        displayName = [displayName stringByAppendingString: zoomSuffix];
    }

    return displayName;
}

#pragma mark PPDocumentWindow delegate methods

- (void) windowDidBecomeMain: (NSNotification *) notification
{
    // need to know when any window is about to move, in order to disable any active popups
    // (no keyUp events are received while a window's being moved, so an active popup can get
    // stuck visible if the user releases the key while moving)
    [self addAsObserverForNSWindowWillMoveNotifications];

    [self addAsObserverForNSMenuDidEndTrackingNotifications];

    if (_ppDocument && ![_ppDocument needToSetCanvasSize])
    {
        [self setupPanelsWithPPDocument: _ppDocument];
    }
}

- (void) windowDidResignMain: (NSNotification *) notification
{
    [self removeAsObserverForNSWindowWillMoveNotifications];

    [self removeAsObserverForNSMenuDidEndTrackingNotifications];

    [self setupPanelsWithPPDocument: nil];
}

- (void) windowDidBecomeKey: (NSNotification *) notification
{
    _documentWindowIsKey = YES;

    [[PPCursorManager sharedManager] setCurrentDocumentWindow: [self window]];
    [_canvasView setShouldAnimateSelectionOutline: YES];

    // clear _modifierKeyFlags so that _lockedActiveToolModifierKeyFlags is also cleared (don't
    // use locked-key flags held over from last time the window was key), and the active tool
    // is reset to the (unmodified) selected tool (ignore the modifier-key state until the
    // first state-change after becoming key)
    [self updateModifierKeyFlags: 0];
}

- (void) windowDidResignKey: (NSNotification *) notification
{
    _documentWindowIsKey = NO;

    [[PPCursorManager sharedManager] clearCurrentDocumentWindow: [self window]];
    [_canvasView setShouldAnimateSelectionOutline: NO];
    [_canvasView setDocumentLayersVisibility: YES];

    // hide active popup from new stack frame - ColorPicker's ColorPanel can become
    // unresponsive if it becomes key and gets hidden in the same stack frame
    [self ppPerformSelectorFromNewStackFrame: @selector(hideActivePopupPanel)];
}

- (void) windowWillClose: (NSNotification *) notification
{
    if ([[self window] isMainWindow])
    {
        [self setupPanelsWithPPDocument: nil];
    }
}

#if PP_DEPLOYMENT_TARGET_SUPPORTS_RETINA_DISPLAY

- (void) windowDidChangeBackingProperties: (NSNotification *) notification
{
    [_canvasView setupRetinaDrawingForCurrentDisplay];
}

#endif  // PP_DEPLOYMENT_TARGET_SUPPORTS_RETINA_DISPLAY


#pragma mark PPDocument notifications

- (void) addAsObserverForPPDocumentNotifications
{
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];

    if (!_ppDocument)
        return;

    [notificationCenter addObserver: self
                        selector:
                            @selector(handlePPDocumentNotification_UpdatedMergedVisibleArea:)
                        name: PPDocumentNotification_UpdatedMergedVisibleArea
                        object: _ppDocument];

    [notificationCenter addObserver: self
                        selector:
                            @selector(handlePPDocumentNotification_UpdatedDrawingLayerArea:)
                        name: PPDocumentNotification_UpdatedDrawingLayerArea
                        object: _ppDocument];

    [notificationCenter addObserver: self
                        selector: @selector(handlePPDocumentNotification_UpdatedSelection:)
                        name: PPDocumentNotification_UpdatedSelection
                        object: _ppDocument];

    [notificationCenter addObserver: self
                        selector: @selector(handlePPDocumentNotification_SwitchedSelectedTool:)
                        name: PPDocumentNotification_SwitchedSelectedTool
                        object: _ppDocument];

    [notificationCenter addObserver: self
                        selector:
                            @selector(handlePPDocumentNotification_UpdatedBackgroundSettings:)
                        name: PPDocumentNotification_UpdatedBackgroundSettings
                        object: _ppDocument];

    [notificationCenter addObserver: self
                        selector: @selector(handlePPDocumentNotification_UpdatedGridSettings:)
                        name: PPDocumentNotification_UpdatedGridSettings
                        object: _ppDocument];

    [notificationCenter addObserver: self
                        selector: @selector(handlePPDocumentNotification_ReloadedDocument:)
                        name: PPDocumentNotification_ReloadedDocument
                        object: _ppDocument];

    [notificationCenter addObserver: self
                        selector:
                            @selector(handlePPDocumentNotification_SwitchedActiveSamplerImage:)
                        name: PPDocumentNotification_SwitchedActiveSamplerImage
                        object: _ppDocument];
}

- (void) removeAsObserverForPPDocumentNotifications
{
    [[NSNotificationCenter defaultCenter] removeObserver: self
                                            name: nil
                                            object: _ppDocument];
}

- (void) handlePPDocumentNotification_UpdatedMergedVisibleArea: (NSNotification *) notification
{
    NSDictionary *userInfo;
    NSValue *updateRectValue;

    if (_canvasDisplayMode == kPPLayerDisplayMode_DrawingLayerOnly)
    {
        return;
    }

    userInfo = [notification userInfo];

    updateRectValue =
                [userInfo objectForKey: PPDocumentNotification_UserInfoKey_UpdateAreaRect];

    if (!updateRectValue)
        return;

    [_canvasView handleUpdateToCanvasBitmapInRect: [updateRectValue rectValue]];
}

- (void) handlePPDocumentNotification_UpdatedDrawingLayerArea: (NSNotification *) notification
{
    NSDictionary *userInfo;
    NSValue *updateRectValue;

    if (_canvasDisplayMode != kPPLayerDisplayMode_DrawingLayerOnly)
    {
        return;
    }

    userInfo = [notification userInfo];

    updateRectValue =
                [userInfo objectForKey: PPDocumentNotification_UserInfoKey_UpdateAreaRect];

    if (!updateRectValue)
        return;

    [_canvasView handleUpdateToCanvasBitmapInRect: [updateRectValue rectValue]];
}

- (void) handlePPDocumentNotification_UpdatedSelection: (NSNotification *) notification
{
    [_canvasView setSelectionOutlineToMask: [_ppDocument selectionMask]
                    maskBounds: [_ppDocument selectionBounds]];
}

- (void) handlePPDocumentNotification_SwitchedSelectedTool: (NSNotification *) notification
{
    [self updateActiveTool];
}

- (void) handlePPDocumentNotification_UpdatedBackgroundSettings:
                                                            (NSNotification *) notification
{
    [_canvasView setBackgroundImage: [_ppDocument backgroundImage]
                    backgroundImageVisibility: [_ppDocument shouldDisplayBackgroundImage]
                    backgroundImageSmoothing: [_ppDocument shouldSmoothenBackgroundImage]
                    backgroundColor: [_ppDocument backgroundPatternAsColor]];
}

- (void) handlePPDocumentNotification_UpdatedGridSettings: (NSNotification *) notification
{
    [_canvasView setGridPattern: [_ppDocument gridPattern]
                    gridVisibility: [_ppDocument shouldDisplayGrid]];
}

- (void) handlePPDocumentNotification_ReloadedDocument: (NSNotification *) notification
{
    [self setupWindowForCurrentPPDocument];
}

- (void) handlePPDocumentNotification_SwitchedActiveSamplerImage:
                                                            (NSNotification *) notification
{
    PPPopupPanelType popupPanelTypeForPressedKey;
    NSNumber *samplerImagePanelTypeNumber;

    if (![_popupPanelsController hasActivePopupPanel]
        || ![_popupPanelsController getPopupPanelType: &popupPanelTypeForPressedKey
                                    forKey: _pressedHotkeyForActivePopupPanel]
        || (popupPanelTypeForPressedKey != kPPPopupPanelType_ColorPicker))
    {
        return;
    }

    samplerImagePanelTypeNumber =
        [[notification userInfo]
                        objectForKey: PPDocumentNotification_UserInfoKey_SamplerImagePanelType];

    if (samplerImagePanelTypeNumber
        && ([samplerImagePanelTypeNumber intValue] != kPPSamplerImagePanelType_PopupPanel))
    {
        return;
    }

    [_popupPanelsController setActivePopupPanel: kPPPopupPanelType_None];

    // setActivePopupPanelType:... will switch the popup panel type from color picker to
    // sampler image if there's an active sampler image
    [self setActivePopupPanelType: kPPPopupPanelType_ColorPicker
            withPressedHotkey: _pressedHotkeyForActivePopupPanel];
}

#pragma mark PPCanvasView notifications

- (void) addAsObserverForPPCanvasViewNotifications
{
    if (!_canvasView)
        return;

    [[NSNotificationCenter defaultCenter]
                            addObserver: self
                            selector:
                                @selector(handlePPCanvasViewNotification_ChangedZoomFactor:)
                            name: PPCanvasViewNotification_ChangedZoomFactor
                            object: _canvasView];
}

- (void) removeAsObserverForPPCanvasViewNotifications
{
    [[NSNotificationCenter defaultCenter] removeObserver: self
                                            name: PPCanvasViewNotification_ChangedZoomFactor
                                            object: _canvasView];
}

- (void) handlePPCanvasViewNotification_ChangedZoomFactor: (NSNotification *) notification
{
    [self synchronizeWindowTitleWithDocumentName];
}

#pragma mark NSWindow WillMove notifications

- (void) addAsObserverForNSWindowWillMoveNotifications
{
    [[NSNotificationCenter defaultCenter]
                                    addObserver: self
                                    selector: @selector(handleNSWindowNotification_WillMove:)
                                    name: NSWindowWillMoveNotification
                                    object: nil];
}

- (void) removeAsObserverForNSWindowWillMoveNotifications
{
    [[NSNotificationCenter defaultCenter] removeObserver: self
                                            name: NSWindowWillMoveNotification
                                            object: nil];
}

- (void) handleNSWindowNotification_WillMove: (NSNotification *) notification
{
    // hide active popup from new stack frame to allow popup to cleanup first (ColorPicker)
    [self ppPerformSelectorFromNewStackFrame: @selector(hideActivePopupPanel)];
}

#pragma mark NSMenu DidEndTracking notifications

- (void) addAsObserverForNSMenuDidEndTrackingNotifications
{
    [[NSNotificationCenter defaultCenter]
                                addObserver: self
                                selector: @selector(handleNSMenuNotification_DidEndTracking:)
                                name: NSMenuDidEndTrackingNotification
                                object: nil];
}

- (void) removeAsObserverForNSMenuDidEndTrackingNotifications
{
    [[NSNotificationCenter defaultCenter] removeObserver: self
                                            name: NSMenuDidEndTrackingNotification
                                            object: nil];
}

- (void) handleNSMenuNotification_DidEndTracking: (NSNotification *) notification
{
    [self updateKeyboardStateForResumedKeyboardEvents];
}

#pragma mark PPHotkeys notifications (Class object)

+ (void) addAsObserverForPPHotkeysNotifications
{
    [[NSNotificationCenter defaultCenter]
                    addObserver: self
                    selector: @selector(handlePPHotkeysNotification_UpdatedHotkeys:)
                    name: PPHotkeysNotification_UpdatedHotkeys
                    object: nil];
}

+ (void) removeAsObserverForPPHotkeysNotifications
{
    [[NSNotificationCenter defaultCenter] removeObserver: self
                                            name: PPHotkeysNotification_UpdatedHotkeys
                                            object: nil];
}

+ (void) handlePPHotkeysNotification_UpdatedHotkeys: (NSNotification *) notification
{
    [self setupHotkeyToActionSelectorNameDict];
}

#pragma mark Popup panel hotkey-repeat timeout timer

- (void) startPopupPanelHotkeyRepeatTimeoutTimer
{
    if (_popupPanelHotkeyRepeatTimeoutTimer)
    {
        [self stopPopupPanelHotkeyRepeatTimeoutTimer];
    }

    if (!_pressedHotkeyForActivePopupPanel)
        return;

    _popupPanelHotkeyRepeatTimeoutTimer =
        [[NSTimer scheduledTimerWithTimeInterval: kHotkeyRepeatTimeoutInterval
                    target: self
                    selector: @selector(popupPanelHotkeyRepeatTimeoutTimerDidFire:)
                    userInfo: nil
                    repeats: NO]
                retain];
}

- (void) stopPopupPanelHotkeyRepeatTimeoutTimer
{
    if (!_popupPanelHotkeyRepeatTimeoutTimer)
        return;

    [_popupPanelHotkeyRepeatTimeoutTimer invalidate];
    [_popupPanelHotkeyRepeatTimeoutTimer release];
    _popupPanelHotkeyRepeatTimeoutTimer = nil;
}

- (void) popupPanelHotkeyRepeatTimeoutTimerDidFire: (NSTimer *) timer
{
    [self hideActivePopupPanel];
}

#pragma mark Private methods

+ (void) setupNewWindowGlobals
{
    NSScreen *mainScreen;
    NSRect mainScreenFrame, mainScreenVisibleFrame, windowBounds;
    float distanceFromScreenEdge_Left, distanceFromScreenEdge_Right;

    mainScreen = [NSScreen mainScreen];
    mainScreenFrame = [mainScreen frame];
    mainScreenVisibleFrame = [mainScreen visibleFrame];

    windowBounds =
        NSMakeRect(mainScreenVisibleFrame.origin.x + kNewWindowScreenMargin_Sides,
                    mainScreenVisibleFrame.origin.y + kNewWindowScreenMargin_Bottom,
                    mainScreenVisibleFrame.size.width - 2.0 * kNewWindowScreenMargin_Sides,
                    mainScreenVisibleFrame.size.height
                        - (kNewWindowScreenMargin_Top + kNewWindowScreenMargin_Bottom));

    // crop width so (first, uncascaded) window is centered horizontally on the screen
    distanceFromScreenEdge_Left = NSMinX(windowBounds) - NSMinX(mainScreenFrame);
    distanceFromScreenEdge_Right = NSMaxX(mainScreenFrame) - NSMaxX(windowBounds);

    if (distanceFromScreenEdge_Left > distanceFromScreenEdge_Right)
    {
        windowBounds.size.width -= (distanceFromScreenEdge_Left - distanceFromScreenEdge_Right);
    }
    else if (distanceFromScreenEdge_Right > distanceFromScreenEdge_Left)
    {
        float widthAdjustment = distanceFromScreenEdge_Right - distanceFromScreenEdge_Left;

        windowBounds.size.width -= widthAdjustment;
        windowBounds.origin.x += widthAdjustment;
    }

    // don't allow initial window size to be taller than wide
    if (windowBounds.size.height > windowBounds.size.width)
    {
        windowBounds.origin.y += (windowBounds.size.height - windowBounds.size.width);
        windowBounds.size.height = windowBounds.size.width;
    }

    windowBounds = PPGeometry_PixelBoundsCoveredByRect(windowBounds);

    gNewWindowContentSize = windowBounds.size;
    gNewWindowCascadePoint = NSMakePoint(windowBounds.origin.x, NSMaxY(windowBounds));
}

+ (void) setupHotkeyToActionSelectorNameDict
{
    [gHotkeyToActionSelectorNameDict release];

    gHotkeyToActionSelectorNameDict =
                [[NSDictionary dictionaryWithObjectsAndKeys:

                                            // names must match IBAction methods

                                                @"toggleCanvasDisplayMode:",
                                            gHotkeys[kPPHotkeyType_SwitchCanvasViewMode],

                                                @"toggleLayerOperationTarget:",
                                            gHotkeys[kPPHotkeyType_SwitchLayerOperationTarget],

                                                @"toggleColorPickerVisibility:",
                                            gHotkeys[kPPHotkeyType_ToggleColorPickerPanel],

                                                @"toggleActivePanelsVisibility:",
                                            gHotkeys[kPPHotkeyType_ToggleActivePanels],

                                                @"increaseZoom:",
                                            gHotkeys[kPPHotkeyType_ZoomIn],

                                                @"decreaseZoom:",
                                            gHotkeys[kPPHotkeyType_ZoomOut],

                                                @"zoomToFit:",
                                            gHotkeys[kPPHotkeyType_ZoomToFit],

                                                nil]
                                    retain];
}

- (void) positionNewWindow
{
    NSWindow *window = [self window];

    if (!PPGeometry_IsZeroSize(gNewWindowContentSize))
    {
        [window setContentSize: gNewWindowContentSize];
    }

    if (!NSEqualPoints(gNewWindowCascadePoint, NSZeroPoint))
    {
        gNewWindowCascadePoint = [window cascadeTopLeftFromPoint: gNewWindowCascadePoint];
    }
}

- (void) setupWindowForCurrentPPDocument
{
    [self setupCanvasViewForCurrentPPDocument];

    [self synchronizeWindowTitleWithDocumentName];

    if ([[self window] isMainWindow])
    {
        [self setupPanelsWithPPDocument: _ppDocument];
    }
}

- (void) setupCanvasViewForCurrentPPDocument
{
    [_canvasView setGridPattern: [_ppDocument gridPattern]
                    gridVisibility: [_ppDocument shouldDisplayGrid]];

    [self setupCanvasViewBitmap];

    [_canvasView setBackgroundImage: [_ppDocument backgroundImage]
                    backgroundImageVisibility: [_ppDocument shouldDisplayBackgroundImage]
                    backgroundImageSmoothing: [_ppDocument shouldSmoothenBackgroundImage]
                    backgroundColor: [_ppDocument backgroundPatternAsColor]];

    [_canvasView setSelectionOutlineToMask: [_ppDocument selectionMask]
                    maskBounds: [_ppDocument selectionBounds]];

    [self updateCanvasViewToolCursorForActiveTool];
}

- (void) setupCanvasViewBitmap
{
    NSBitmapImageRep *displayBitmap;

    if (_canvasDisplayMode == kPPLayerDisplayMode_DrawingLayerOnly)
    {
        displayBitmap = [_ppDocument dissolvedDrawingLayerBitmap];
    }
    else
    {
        displayBitmap = [_ppDocument mergedVisibleLayersBitmap];
    }

    [_canvasView setCanvasBitmap: displayBitmap];
}

- (void) matchCanvasDisplayModeToOperationTarget
{
    PPLayerDisplayMode newDisplayMode;

    _canvasDisplayModeToRestore = _canvasDisplayMode;

    if ([_ppDocument layerOperationTarget] == kPPLayerOperationTarget_DrawingLayerOnly)
    {
        if (_disallowMatchingCanvasDisplayModeToDrawLayerTarget)
            return;

        newDisplayMode = kPPLayerDisplayMode_DrawingLayerOnly;
    }
    else
    {
        newDisplayMode = kPPLayerDisplayMode_VisibleLayers;
    }

    if (_canvasDisplayMode == newDisplayMode)
    {
        return;
    }

    [self setCanvasDisplayMode: newDisplayMode];
}

- (void) restoreCanvasDisplayModeFromOperationTarget
{
    if (_canvasDisplayMode == _canvasDisplayModeToRestore)
    {
        return;
    }

    [self setCanvasDisplayMode: _canvasDisplayModeToRestore];
}

- (void) setupPanelsWithPPDocument: (PPDocument *) ppDocument
{
    [[PPLayerControlButtonImagesManager sharedManager] setPPDocument: ppDocument];

    [_panelsController setPPDocument: ppDocument];

    [self hideActivePopupPanel];
    [_popupPanelsController setPPDocument: ppDocument];
}

- (void) setActivePopupPanelType: (PPPopupPanelType) popupPanelType
            withPressedHotkey: (NSString *) pressedHotkey
{
    if (_pressedHotkeyForActivePopupPanel != pressedHotkey)
    {
        [_pressedHotkeyForActivePopupPanel release];
        _pressedHotkeyForActivePopupPanel = [pressedHotkey retain];
    }

    if ((popupPanelType == kPPPopupPanelType_ColorPicker)
            && [_ppDocument hasActiveSamplerImageForPanelType:
                                                        kPPSamplerImagePanelType_PopupPanel])
    {
        popupPanelType = kPPPopupPanelType_SamplerImage;
    }

    [_popupPanelsController setActivePopupPanel: popupPanelType];
}

- (void) hideActivePopupPanel
{
    [self stopPopupPanelHotkeyRepeatTimeoutTimer];

    [_pressedHotkeyForActivePopupPanel release];
    _pressedHotkeyForActivePopupPanel = nil;

    [_popupPanelsController setActivePopupPanel: kPPPopupPanelType_None];
}

- (bool) getDirectionType: (PPDirectionType *) returnedDirectionType
            forArrowKey: (NSString *) key
{
    unichar keyChar;

    if (!returnedDirectionType || ![key length])
    {
        return NO;
    }

    keyChar = [key characterAtIndex: 0];

    switch (keyChar)
    {
        case NSLeftArrowFunctionKey:
            *returnedDirectionType = kPPDirectionType_Left;
        break;

        case NSRightArrowFunctionKey:
            *returnedDirectionType = kPPDirectionType_Right;
        break;

        case NSUpArrowFunctionKey:
            *returnedDirectionType = kPPDirectionType_Up;
        break;

        case NSDownArrowFunctionKey:
            *returnedDirectionType = kPPDirectionType_Down;
        break;

        default:
            *returnedDirectionType = kPPDirectionType_None;
        break;
    }

    return PPDirectionType_IsValid(*returnedDirectionType) ? YES : NO;
}

- (bool) handleActionKey: (NSString *) key
{
    NSString *actionSelectorName;
    SEL actionSelector;

    actionSelectorName = [gHotkeyToActionSelectorNameDict objectForKey: key];

    if (!actionSelectorName)
        goto ERROR;

    actionSelector = NSSelectorFromString(actionSelectorName);

    if (!actionSelector)
        goto ERROR;

    [self performSelector: actionSelector withObject: self];

    return YES;

ERROR:
    return NO;
}

- (void) updateKeyboardStateForResumedKeyboardEvents
{
    if (_pressedHotkeyForActivePopupPanel)
    {
        [self startPopupPanelHotkeyRepeatTimeoutTimer];
    }

    [self updateModifierKeyFlagsFromCurrentKeyboardState];
}

- (NSPoint) mouseLocationFromEvent: (NSEvent *) event
            clippedToCanvasBounds: (bool) shouldClipToCanvasBounds
{
    NSPoint mouseLocation;

    if (!event)
        goto ERROR;

    mouseLocation = [_canvasView convertPoint: [event locationInWindow] fromView: nil];

    if (_shouldUseImageCoordinatesForMouseLocation)
    {
        mouseLocation = [_canvasView imagePointFromViewPoint: mouseLocation
                                        clippedToCanvasBounds: shouldClipToCanvasBounds];
    }
    else if (shouldClipToCanvasBounds)
    {
        mouseLocation = [_canvasView viewPointClippedToCanvasBounds: mouseLocation];
    }

    return mouseLocation;

ERROR:
    return _lastMouseLocation;
}

- (void) updateModifierKeyFlags: (unsigned) modifierKeyFlags
{
    modifierKeyFlags &= kModifierKeyMask_RecognizedModifierKeys;

    if (_modifierKeyFlags == modifierKeyFlags)
    {
        return;
    }

    _modifierKeyFlags = modifierKeyFlags;

    if (!_isTrackingMouseInCanvasView)
    {
        if (_lockedActiveToolModifierKeyFlags)
        {
            // clear locked-active-tool modifier flags of any modifier keys no longer held down
            _lockedActiveToolModifierKeyFlags &= _modifierKeyFlags;
        }

        [self updateActiveTool];
    }
    else
    {
        [[_ppDocument activeTool] mouseDraggedOrModifierKeysChangedForDocument: _ppDocument
                                    withCanvasView: _canvasView
                                    currentPoint: _lastMouseLocation
                                    lastPoint: _lastMouseLocation
                                    mouseDownPoint: _mouseDownLocation
                                    modifierKeyFlags: _modifierKeyFlags];

        if (_activeToolCursorDependsOnModifierKeys)
        {
            [self updateCanvasViewToolCursorForActiveTool];
        }

        _shouldUpdateActiveToolOnMouseUp = YES;
    }

    // when the command or shift modifier keys are pressed, the system will swallow the
    // keyUp events for all other keys currently held down, even if the modifier keys are
    // released first - this can cause the popup panels to get stuck visible & the
    // hidden document layers to get stuck hidden, since the app won't be notified when the
    // hotkey is released; to prevent the popups & document layers from getting stuck,
    // preemptively hide the active popup & unhide the document layers when the command
    // & shift keys are pressed

    if (_modifierKeyFlags & (NSCommandKeyMask | NSShiftKeyMask))
    {
        if (_pressedHotkeyForActivePopupPanel)
        {
            [self hideActivePopupPanel];
        }

        if ([_canvasView documentLayersAreHidden])
        {
            [_canvasView setDocumentLayersVisibility: YES];
        }
    }
}

- (void) updateModifierKeyFlagsFromCurrentKeyboardState
{
    [self updateModifierKeyFlags: [[NSApp currentEvent] modifierFlags]];
}

- (void) updateActiveTool
{
    unsigned toolAttributeFlags;

    if (_lockedActiveToolModifierKeyFlags)
        return;

    [_ppDocument setActiveToolType:
                    [self modifiedToolTypeForSelectedToolType: [_ppDocument selectedToolType]]];

    toolAttributeFlags = [[_ppDocument activeTool] toolAttributeFlags];

    _shouldUseImageCoordinatesForMouseLocation =
        (toolAttributeFlags & kPPToolAttributeMask_RequiresPointsInViewCoordinates) ? NO : YES;

    _shouldClipMouseLocationPointsToCanvasBounds =
        (toolAttributeFlags & kPPToolAttributeMask_RequiresPointsCroppedToCanvasBounds) ?
            YES : NO;

    _activeToolCursorDependsOnModifierKeys =
        (toolAttributeFlags & kPPToolAttributeMask_CursorDependsOnModifierKeys) ? YES : NO;

    _shouldMatchCanvasDisplayModeToOperationTargetWhileTrackingMouse =
        (toolAttributeFlags & kPPToolAttributeMask_MatchCanvasDisplayModeToOperationTarget) ?
            YES : NO;

    _disallowMatchingCanvasDisplayModeToDrawLayerTarget =
        (toolAttributeFlags
            & kPPToolAttributeMask_DisallowMatchingCanvasDisplayModeToDrawLayerTarget) ?
                YES : NO;

    [self updateCanvasViewToolCursorForActiveTool];

    [_canvasView enableSkippingOfMouseDraggedEvents:
                (toolAttributeFlags & kPPToolAttributeMask_DisableSkippingOfMouseDraggedEvents)
                                ? NO : YES];

    [_canvasView enableAutoscrolling:
                            (toolAttributeFlags & kPPToolAttributeMask_DisableAutoscrolling)
                                ? NO : YES];
}

- (void) updateCanvasViewToolCursorForActiveTool
{
    NSCursor *toolCursor;

    if (_activeToolCursorDependsOnModifierKeys)
    {
        toolCursor = [[_ppDocument activeTool] cursorForModifierKeyFlags: _modifierKeyFlags];
    }
    else
    {
        toolCursor = [[_ppDocument activeTool] cursor];
    }

    [_canvasView setToolCursor: toolCursor];
}

- (PPToolType) modifiedToolTypeForSelectedToolType: (PPToolType) selectedToolType
{
    PPToolType modifiedToolType;
    unsigned modifiableToolTypesMask, selectedToolTypeMask;

    if (!_modifierKeyFlags)
    {
        return selectedToolType;
    }

    switch (_modifierKeyFlags)
    {
        case kModifierKeyMask_SelectEraserTool:
        case kModifierKeyMask_SelectEraserToolWithFillShape:
        {
            modifiedToolType = kPPToolType_Eraser;
            modifiableToolTypesMask = kModifiablePPToolTypesMask_Eraser;
        }
        break;

        case kModifierKeyMask_SelectFillTool:
        {
            modifiedToolType = kPPToolType_Fill;
            modifiableToolTypesMask = kModifiablePPToolTypesMask_Fill;
        }
        break;

        case kModifierKeyMask_SelectColorSamplerTool:
        {
            modifiedToolType = kPPToolType_ColorSampler;
            modifiableToolTypesMask = kModifiablePPToolTypesMask_ColorSampler;
        }
        break;

        case kModifierKeyMask_SelectMoveTool:
        case kModifierKeyMask_SelectMoveToolWithSelectionOutlineOnly:
        case kModifierKeyMask_SelectMoveToolAndLeaveCopyInPlace:
        {
            modifiedToolType = kPPToolType_Move;
            modifiableToolTypesMask = kModifiablePPToolTypesMask_Move;
        }
        break;

        case kModifierKeyMask_SelectMagnifierTool:
        case kModifierKeyMask_SelectMagnifierToolWithZoomOut:
        case kModifierKeyMask_SelectMagnifierToolWithCenterShape:
        {
            modifiedToolType = kPPToolType_Magnifier;
            modifiableToolTypesMask = kModifiablePPToolTypesMask_Magnifier;
        }
        break;

        case kModifierKeyMask_SelectColorRampTool:
        {
            modifiedToolType = kPPToolType_ColorRamp;
            modifiableToolTypesMask = kModifiablePPToolTypesMask_ColorRamp;
        }
        break;

        default:
            modifiedToolType = selectedToolType;
            modifiableToolTypesMask = 0;
        break;
    }

    selectedToolTypeMask = PPToolTypeMaskForPPToolType(selectedToolType);

    if (!(selectedToolTypeMask & modifiableToolTypesMask))
    {
        return selectedToolType;
    }

    return modifiedToolType;
}

@end
