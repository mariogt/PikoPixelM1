/*
    PPToolsPanelController.m

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

#import "PPToolsPanelController.h"

#import "PPDocument.h"
#import "PPDefines.h"
#import "PPHotkeys.h"
#import "PPToolButtonMatrix.h"
#import "PPHotkeyDisplayUtilities.h"
#import "NSObject_PPUtilities.h"
#import "PPPanelDefaultFramePinnings.h"


#define kToolsPanelNibName  @"ToolsPanel"


static NSString *DisplayKeyForToolType(PPToolType toolType);
static NSString *UpdatedTooltipForTooltipAndDisplayKey(NSString *toolTip, NSString *displayKey);


@interface PPToolsPanelController (PrivateMethods)

- (void) handlePPDocumentNotification_SwitchedActiveTool: (NSNotification *) notification;
- (void) handlePPDocumentNotification_ChangedFillColor: (NSNotification *) notification;

- (void) addAsObserverForPPHotkeysNotifications;
- (void) removeAsObserverForPPHotkeysNotifications;
- (void) handlePPHotkeysNotification_UpdatedHotkeys: (NSNotification *) notification;

- (void) updateDocumentFillColor;
- (void) updateToolButtonMatrix;
- (void) updateFillColorWellColor;
- (void) updateFillColorWellActivation;
- (void) setupToolTipsWithCurrentHotkeys;

@end

@implementation PPToolsPanelController

+ (void) initialize
{
    if ([self class] != [PPToolsPanelController class])
    {
        return;
    }

    [PPHotkeys setupGlobals];
}

+ sharedController
{
    static PPToolsPanelController *sharedController = nil;

    if (!sharedController)
    {
        sharedController = [[super controller] retain];
    }

    return sharedController;
}

- (void) dealloc
{
    [self removeAsObserverForPPHotkeysNotifications];

    [super dealloc];
}

- (bool) fillColorWellIsActive
{
    // method may be called before window's loaded
    if (!_panelDidLoad)
    {
        return NO;
    }

    return [_fillColorWell isActive];
}

- (void) activateFillColorWell
{
    // method may be called before window's loaded
    if (!_panelDidLoad)
    {
        [self window];  // force load
    }

    if (![_fillColorWell isActive])
    {
        [_fillColorWell performClick: self];
    }
}

- (void) toggleFillColorWell
{
    // method may be called before window's loaded
    if (!_panelDidLoad)
    {
        [self window];  // force load
    }

    [_fillColorWell performClick: self];
}

#pragma mark Actions

- (IBAction) toolButtonMatrixClicked: (id) sender
{
    [_ppDocument setSelectedToolType: [_toolButtonMatrix toolTypeOfSelectedCell]];
}

- (IBAction) fillColorWellUpdated: (id) sender
{
    [self ppPerformSelectorAtomicallyFromNewStackFrame: @selector(updateDocumentFillColor)];
}

#pragma mark NSWindowController overrides

- (void) windowDidLoad
{
    [self setupToolTipsWithCurrentHotkeys];

    [self addAsObserverForPPHotkeysNotifications];

    // [super windowDidLoad] may show the panel, so call as late as possible
    [super windowDidLoad];
}

#pragma mark PPPanelController overrides

+ controller
{
    return [self sharedController];
}

+ (NSString *) panelNibName
{
    return kToolsPanelNibName;
}

- (void) setPPDocument: (PPDocument *) ppDocument
{
    bool initialPPDocumentIsValid, currentPPDocumentIsValid;

    initialPPDocumentIsValid = (_ppDocument) ? YES : NO;

    [super setPPDocument: ppDocument];

    currentPPDocumentIsValid = (_ppDocument) ? YES : NO;

    if (initialPPDocumentIsValid != currentPPDocumentIsValid)
    {
        if (_ppDocument)
        {
            [self updateFillColorWellActivation];
        }
        else
        {
            // document may only be invalid temporarily if switching windows, so wait until
            // a new stack frame to update the fill colorwell's activation

            [self ppPerformSelectorAtomicallyFromNewStackFrame:
                                                    @selector(updateFillColorWellActivation)];
        }
    }
}

- (void) setPanelVisibilityAllowed: (bool) allowPanelVisibility
{
    bool initialAllowVisibility = _allowPanelVisibility;

    [super setPanelVisibilityAllowed: allowPanelVisibility];

    if (_allowPanelVisibility != initialAllowVisibility)
    {
        [self updateFillColorWellActivation];
    }
}

- (void) addAsObserverForPPDocumentNotifications
{
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];

    if (!_ppDocument)
        return;

    [notificationCenter addObserver: self
                        selector: @selector(handlePPDocumentNotification_SwitchedActiveTool:)
                        name: PPDocumentNotification_SwitchedActiveTool
                        object: _ppDocument];

    [notificationCenter addObserver: self
                        selector: @selector(handlePPDocumentNotification_ChangedFillColor:)
                        name: PPDocumentNotification_ChangedFillColor
                        object: _ppDocument];
}

- (void) removeAsObserverForPPDocumentNotifications
{
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];

    [notificationCenter removeObserver: self
                        name: PPDocumentNotification_SwitchedActiveTool
                        object: _ppDocument];

    [notificationCenter removeObserver: self
                        name: PPDocumentNotification_ChangedFillColor
                        object: _ppDocument];
}

- (bool) defaultPanelEnabledState
{
    return YES;
}

- (PPFramePinningType) pinningTypeForDefaultWindowFrame
{
    return kPPPanelDefaultFramePinning_Tools;
}

- (void) setupPanelForCurrentPPDocument
{
    [self updateToolButtonMatrix];
    [self updateFillColorWellColor];

    // [super setupPanelForCurrentPPDocument] may show the panel, so call as late as possible
    [super setupPanelForCurrentPPDocument];
}

#pragma mark PPDocument notifications

- (void) handlePPDocumentNotification_SwitchedActiveTool: (NSNotification *) notification
{
    [self updateToolButtonMatrix];
}

- (void) handlePPDocumentNotification_ChangedFillColor: (NSNotification *) notification
{
    [self updateFillColorWellColor];
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
    [self setupToolTipsWithCurrentHotkeys];
}

#pragma mark Private methods

- (void) updateDocumentFillColor
{
    [_ppDocument setFillColor: [_fillColorWell color]];
}

- (void) updateToolButtonMatrix
{
    [_toolButtonMatrix highlightCellWithToolType: [_ppDocument activeToolType]];
}

- (void) updateFillColorWellColor
{
    [_fillColorWell setColor: [_ppDocument fillColor]];
}

- (void) updateFillColorWellActivation
{
    bool canActivateFillColorWell = (_allowPanelVisibility && _ppDocument) ? YES : NO;

    if (canActivateFillColorWell)
    {
        if (_needToReactivateFillColorWell)
        {
            if (![_fillColorWell isActive])
            {
                [_fillColorWell activate: YES];
            }

            _needToReactivateFillColorWell = NO;
        }
    }
    else
    {
        if ([_fillColorWell isActive])
        {
            [_fillColorWell deactivate];

            _needToReactivateFillColorWell = YES;
        }
    }
}

- (void) setupToolTipsWithCurrentHotkeys
{
    NSEnumerator *cellEnumerator;
    NSCell *cell;
    NSString *displayKey, *newToolTip;

    // tools matrix
    cellEnumerator = [[_toolButtonMatrix cells] objectEnumerator];

    while (cell = [cellEnumerator nextObject])
    {
        displayKey = DisplayKeyForToolType([_toolButtonMatrix toolTypeOfCell: cell]);

        newToolTip =
                UpdatedTooltipForTooltipAndDisplayKey([_toolButtonMatrix toolTipForCell: cell],
                                                        displayKey);

        [_toolButtonMatrix setToolTip: newToolTip forCell: cell];
    }

    // color well
    displayKey = PPDisplayKeyForHotkey(gHotkeys[kPPHotkeyType_ToggleColorPickerPanel]);

    newToolTip = UpdatedTooltipForTooltipAndDisplayKey([_fillColorWell toolTip], displayKey);

    [_fillColorWell setToolTip: newToolTip];
}

@end

#pragma mark Private functions

static NSString *DisplayKeyForToolType(PPToolType toolType)
{
    NSString *hotkey;

    switch (toolType)
    {
        case kPPToolType_Pencil:
        {
            hotkey = gHotkeys[kPPHotkeyType_Tool_Pencil];
        }
        break;

        case kPPToolType_Fill:
        {
            hotkey = gHotkeys[kPPHotkeyType_Tool_Fill];
        }
        break;

        case kPPToolType_Line:
        {
            hotkey = gHotkeys[kPPHotkeyType_Tool_Line];
        }
        break;

        case kPPToolType_Rect:
        {
            hotkey = gHotkeys[kPPHotkeyType_Tool_Rect];
        }
        break;

        case kPPToolType_Oval:
        {
            hotkey = gHotkeys[kPPHotkeyType_Tool_Oval];
        }
        break;

        case kPPToolType_Eraser:
        {
            hotkey = gHotkeys[kPPHotkeyType_Tool_Eraser];
        }
        break;

        case kPPToolType_ColorSampler:
        {
            hotkey = gHotkeys[kPPHotkeyType_Tool_ColorSampler];
        }
        break;

        case kPPToolType_Magnifier:
        {
            hotkey = gHotkeys[kPPHotkeyType_Tool_Magnifier];
        }
        break;

        case kPPToolType_RectSelect:
        {
            hotkey = gHotkeys[kPPHotkeyType_Tool_RectSelect];
        }
        break;

        case kPPToolType_MagicWand:
        {
            hotkey = gHotkeys[kPPHotkeyType_Tool_MagicWand];
        }
        break;

        case kPPToolType_FreehandSelect:
        {
            hotkey = gHotkeys[kPPHotkeyType_Tool_FreehandSelect];
        }
        break;

        case kPPToolType_Move:
        {
            hotkey = gHotkeys[kPPHotkeyType_Tool_Move];
        }
        break;

        default:
        {
            hotkey = @"";
        }
        break;
    }

    return PPDisplayKeyForHotkey(hotkey);
}

static NSString *UpdatedTooltipForTooltipAndDisplayKey(NSString *toolTip, NSString *displayKey)
{
    if ([toolTip length])
    {
        NSRange rangeOfParenthesis = [toolTip rangeOfString: @"("];

        if (rangeOfParenthesis.length)
        {
            toolTip = [toolTip substringToIndex: rangeOfParenthesis.location];
        }
    }

    if (!toolTip)
    {
        toolTip = @"";
    }

    if ([displayKey length])
    {
        toolTip =
            [NSString stringWithFormat: @"%@(%C)", toolTip, [displayKey characterAtIndex: 0]];
    }

    return toolTip;
}
