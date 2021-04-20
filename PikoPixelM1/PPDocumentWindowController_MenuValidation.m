/*
    PPDocumentWindowController_MenuValidation.m

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

#import "PPDocumentWindowController.h"

#import "PPDocument.h"
#import "PPCanvasView.h"
#import "PPDocumentLayer.h"
#import "PPPanelsController.h"


static void SetupGlobals(void);
static SEL SelectorFromDictForMenuActionName(NSDictionary *selectorDict, NSString *actionName);
static NSDictionary *MenuItemValidationSelectorDict(void);
static NSDictionary *MenuItemModificationSelectorDict(void);
static bool MenuActionNameIsAllowedDuringMouseTracking(NSString *actionName);
static bool MenuActionNameIsAllowedDuringPopupPanel(NSString *actionName);

static bool gNeedToSetupGlobals = YES;
static NSDictionary *gMenuItemModificationSelectorDict = nil;
static NSDictionary *gMenuItemValidationSelectorDict = nil;
static NSNumber *gNumber_YES = nil, *gNumber_NO = nil;


@interface PPDocumentWindowController (MenuValidationPrivateMethods)

- (NSNumber *) documentIsValid;
- (NSNumber *) documentHasSelection;
- (NSNumber *) documentHasSelectionAndDrawLayerIsEnabled;
- (NSNumber *) documentHasSelectionAndEnabledTargetLayer;
- (NSNumber *) documentHasSelectionOrEnabledTargetLayer;
- (NSNumber *) documentHasMultipleLayers;
- (NSNumber *) documentHasValidLayerAboveDrawingLayer;
- (NSNumber *) documentHasValidLayerBelowDrawingLayer;
- (NSNumber *) documentActiveLayerCanIncreaseOpacity;
- (NSNumber *) documentActiveLayerCanDecreaseOpacity;
- (NSNumber *) documentHasVisibleGrid;
- (NSNumber *) documentHasBackgroundImage;
- (NSNumber *) documentHasVisibleBackgroundImage;
- (NSNumber *) documentHasActiveSamplerImageForPanel;
- (NSNumber *) documentHasMultipleSamplerImagesAndSamplerPanelIsVisible;
- (NSNumber *) documentCanReadFromPasteboard;
- (NSNumber *) canvasViewCanZoomIn;
- (NSNumber *) canvasViewCanZoomOut;

- (void) modifyMenuItemForLayerEnabled: (NSMenuItem *) menuItem;
- (void) modifyMenuItemForCanvasDisplayMode: (NSMenuItem *) menuItem;
- (void) modifyMenuItemForLayerBlendingMode: (NSMenuItem *) menuItem;
- (void) modifyMenuItemForGridVisibilityStatus: (NSMenuItem *) menuItem;
- (void) modifyMenuItemForGridType: (NSMenuItem *) menuItem;
- (void) modifyMenuItemForGridGuidelinesVisibilityStatus: (NSMenuItem *) menuItem;
- (void) modifyMenuItemForBackgroundImageVisibilityStatus: (NSMenuItem *) menuItem;
- (void) modifyMenuItemForBackgroundImageSmoothingStatus: (NSMenuItem *) menuItem;
- (void) modifyMenuItemForLayerOperationTarget: (NSMenuItem *) menuItem;
- (void) modifyMenuItemForToolsPanelVisibilityStatus: (NSMenuItem *) menuItem;
- (void) modifyMenuItemForLayersPanelVisibilityStatus: (NSMenuItem *) menuItem;
- (void) modifyMenuItemForPreviewPanelVisibilityStatus: (NSMenuItem *) menuItem;
- (void) modifyMenuItemForSamplerImagePanelVisibilityStatus: (NSMenuItem *) menuItem;
- (void) modifyMenuItemForToolModifierTipsPanelVisibilityStatus: (NSMenuItem *) menuItem;

@end

@interface NSMenuItem (PPUtilities_MenuValidationPrivateMethods)

- (void) ppSetTitleModeNameSuffix: (NSString *) modeName;

@end

@implementation PPDocumentWindowController (MenuValidation)

- (BOOL) validateMenuItem: (PPSDKNativeType_NSMenuItemPtr) menuItem
{
    SEL menuItemAction, modificationSelector, validationSelector;
    NSString *actionName;

    if (gNeedToSetupGlobals)
    {
        SetupGlobals();
    }

    if (!_documentWindowIsKey)
    {
        return NO;
    }

    menuItemAction = [menuItem action];

    if (!menuItemAction)
        goto ERROR;

    actionName = NSStringFromSelector(menuItemAction);

    if (!actionName)
        goto ERROR;

    modificationSelector =
        SelectorFromDictForMenuActionName(gMenuItemModificationSelectorDict, actionName);

    if (modificationSelector)
    {
        [self performSelector: modificationSelector withObject: menuItem];
    }

    if (_isTrackingMouseInCanvasView
        && !MenuActionNameIsAllowedDuringMouseTracking(actionName))
    {
        return NO;
    }

    if (_pressedHotkeyForActivePopupPanel
        && !MenuActionNameIsAllowedDuringPopupPanel(actionName))
    {
        return NO;
    }

    validationSelector =
        SelectorFromDictForMenuActionName(gMenuItemValidationSelectorDict, actionName);

    if (validationSelector)
    {
        return [[self performSelector: validationSelector] boolValue];
    }

    return NO;

ERROR:
    return NO;
}

- (NSNumber *) documentIsValid
{
    return ([_ppDocument numLayers]) ? gNumber_YES : gNumber_NO;
}

- (NSNumber *) documentHasSelection
{
    return ([_ppDocument hasSelection]) ? gNumber_YES : gNumber_NO;
}

- (NSNumber *) documentHasSelectionAndDrawLayerIsEnabled
{
    return ([_ppDocument hasSelection] && [[_ppDocument drawingLayer] isEnabled]) ?
                gNumber_YES : gNumber_NO;
}

- (NSNumber *) documentHasSelectionAndEnabledTargetLayer
{
    return ([_ppDocument hasSelection] && [_ppDocument layerOperationTargetHasEnabledLayer]) ?
                gNumber_YES : gNumber_NO;
}

- (NSNumber *) documentHasSelectionOrEnabledTargetLayer
{
    return ([_ppDocument hasSelection] || [_ppDocument layerOperationTargetHasEnabledLayer]) ?
                gNumber_YES : gNumber_NO;
}

- (NSNumber *) documentHasMultipleLayers
{
    return ([_ppDocument numLayers] > 1) ? gNumber_YES : gNumber_NO;
}

- (NSNumber *) documentHasValidLayerAboveDrawingLayer
{
    return ([_ppDocument indexOfDrawingLayer] < ([_ppDocument numLayers] - 1)) ?
                gNumber_YES : gNumber_NO;
}

- (NSNumber *) documentHasValidLayerBelowDrawingLayer
{
    return ([_ppDocument indexOfDrawingLayer] > 0) ? gNumber_YES : gNumber_NO;
}

- (NSNumber *) documentActiveLayerCanIncreaseOpacity
{
    return ([[_ppDocument drawingLayer] canIncreaseOpacity]) ? gNumber_YES : gNumber_NO;
}

- (NSNumber *) documentActiveLayerCanDecreaseOpacity
{
    return ([[_ppDocument drawingLayer] canDecreaseOpacity]) ? gNumber_YES : gNumber_NO;
}

- (NSNumber *) documentHasVisibleGrid
{
    return ([_ppDocument shouldDisplayGrid]) ? gNumber_YES : gNumber_NO;
}

- (NSNumber *) documentHasBackgroundImage
{
    return ([_ppDocument backgroundImage]) ? gNumber_YES : gNumber_NO;
}

- (NSNumber *) documentHasVisibleBackgroundImage
{
    return ([_ppDocument backgroundImage] && [_ppDocument shouldDisplayBackgroundImage]) ?
                gNumber_YES : gNumber_NO;
}

- (NSNumber *) documentHasActiveSamplerImageForPanel
{
    return ([_ppDocument hasActiveSamplerImageForPanelType: kPPSamplerImagePanelType_Panel]) ?
                gNumber_YES : gNumber_NO;
}

- (NSNumber *) documentHasMultipleSamplerImagesAndSamplerPanelIsVisible
{
    return (([_ppDocument numSamplerImages] > 1)
                && [_panelsController panelOfTypeIsVisible: kPPPanelType_SamplerImage]) ?
                    gNumber_YES : gNumber_NO;
}

- (NSNumber *) documentCanReadFromPasteboard
{
    return ([_ppDocument canReadFromPasteboard]) ? gNumber_YES : gNumber_NO;
}

- (NSNumber *) canvasViewCanZoomIn
{
    return ([_canvasView canIncreaseZoomFactor]) ? gNumber_YES : gNumber_NO;
}

- (NSNumber *) canvasViewCanZoomOut
{
    return ([_canvasView canDecreaseZoomFactor]) ? gNumber_YES : gNumber_NO;
}

#pragma mark Menu item modifications

- (void) modifyMenuItemForLayerEnabled: (NSMenuItem *) menuItem
{
    [menuItem setState: ([[_ppDocument drawingLayer] isEnabled]) ? NSOnState : NSOffState];
}

- (void) modifyMenuItemForLayerBlendingMode: (NSMenuItem *) menuItem
{
    NSString *modeName = nil;

    if ([self documentIsValid])
    {
        if ([_ppDocument layerBlendingMode] == kPPLayerBlendingMode_Linear)
        {
            modeName = @"LINEAR";
        }
        else
        {
            modeName = @"STANDARD";
        }
    }

    [menuItem ppSetTitleModeNameSuffix: modeName];
}

- (void) modifyMenuItemForCanvasDisplayMode: (NSMenuItem *) menuItem
{
    NSString *modeName = nil;

    if ([self documentIsValid])
    {
        if (_canvasDisplayMode == kPPLayerDisplayMode_DrawingLayerOnly)
        {
            modeName = @"DRAW Layer";
        }
        else
        {
            modeName = @"ENABLED Layers";
        }
    }

    [menuItem ppSetTitleModeNameSuffix: modeName];
}

- (void) modifyMenuItemForGridVisibilityStatus: (NSMenuItem *) menuItem
{
    [menuItem setState: ([_ppDocument shouldDisplayGrid]) ? NSOnState : NSOffState];
}

- (void) modifyMenuItemForGridType: (NSMenuItem *) menuItem
{
    NSString *modeName = nil;

    if ([self documentIsValid])
    {
        switch ([_ppDocument pixelGridPatternType])
        {
            case kPPGridType_Crosshairs:
            {
                modeName = @"Crosshairs";
            }
            break;

            case kPPGridType_LargeDots:
            {
                modeName = @"Large Dots";
            }
            break;

            case kPPGridType_Dots:
            {
                modeName = @"Dots";
            }
            break;

            case kPPGridType_Lines:
            default:
            {
                modeName = @"Lines";
            }
            break;
        }
    }

    [menuItem ppSetTitleModeNameSuffix: modeName];
}

- (void) modifyMenuItemForGridGuidelinesVisibilityStatus: (NSMenuItem *) menuItem
{
    [menuItem setState:
                ([_ppDocument gridPatternShouldDisplayGuidelines]) ? NSOnState : NSOffState];
}

- (void) modifyMenuItemForBackgroundImageVisibilityStatus: (NSMenuItem *) menuItem
{
    [menuItem setState: ([_ppDocument shouldDisplayBackgroundImage]) ? NSOnState : NSOffState];
}

- (void) modifyMenuItemForBackgroundImageSmoothingStatus: (NSMenuItem *) menuItem
{
    [menuItem setState: ([_ppDocument shouldSmoothenBackgroundImage]) ? NSOnState : NSOffState];
}

- (void) modifyMenuItemForLayerOperationTarget: (NSMenuItem *) menuItem
{
    NSString *modeName = nil;

    if ([self documentIsValid])
    {
        if ([_ppDocument layerOperationTarget] == kPPLayerOperationTarget_DrawingLayerOnly)
        {
            modeName = @"DRAW Layer";
        }
        else
        {
            modeName = @"ENABLED Layers";
        }
    }

    [menuItem ppSetTitleModeNameSuffix: modeName];
}

- (void) modifyMenuItemForToolsPanelVisibilityStatus: (NSMenuItem *) menuItem
{
    [menuItem setState:
                ([_panelsController panelOfTypeIsVisible: kPPPanelType_Tools]) ?
                                                                    NSOnState : NSOffState];
}

- (void) modifyMenuItemForLayersPanelVisibilityStatus: (NSMenuItem *) menuItem
{
    [menuItem setState:
                ([_panelsController panelOfTypeIsVisible: kPPPanelType_Layers]) ?
                                                                    NSOnState : NSOffState];
}

- (void) modifyMenuItemForPreviewPanelVisibilityStatus: (NSMenuItem *) menuItem
{
    [menuItem setState:
                ([_panelsController panelOfTypeIsVisible: kPPPanelType_Preview]) ?
                                                                    NSOnState : NSOffState];
}

- (void) modifyMenuItemForSamplerImagePanelVisibilityStatus: (NSMenuItem *) menuItem
{
    [menuItem setState:
                ([_panelsController panelOfTypeIsVisible: kPPPanelType_SamplerImage]) ?
                                                                    NSOnState : NSOffState];
}

- (void) modifyMenuItemForToolModifierTipsPanelVisibilityStatus: (NSMenuItem *) menuItem
{
    [menuItem setState:
                ([_panelsController panelOfTypeIsVisible: kPPPanelType_ToolModifierTips]) ?
                                                                    NSOnState : NSOffState];
}

@end

@implementation NSMenuItem (PPUtilities_MenuValidationPrivateMethods)

- (void) ppSetTitleModeNameSuffix: (NSString *) modeName
{
    NSString *currentTitle, *newTitle;
    NSRange colonRange;

    currentTitle = [self title];

    if (!currentTitle)
    {
        currentTitle = @"";
    }

    colonRange = [currentTitle rangeOfString: @":"];

    if (colonRange.length)
    {
        newTitle = [currentTitle substringToIndex: colonRange.location];
    }
    else
    {
        newTitle = currentTitle;
    }

    if (modeName)
    {
        newTitle = [newTitle stringByAppendingFormat: @": %@", modeName];
    }

    if (![newTitle isEqualToString: currentTitle])
    {
        [self setTitle: newTitle];
    }
}

@end

#pragma mark Private functions

static void SetupGlobals(void)
{
    if (!gNeedToSetupGlobals)
        return;

    gMenuItemModificationSelectorDict = [MenuItemModificationSelectorDict() retain];
    gMenuItemValidationSelectorDict = [MenuItemValidationSelectorDict() retain];

    gNumber_YES = [[NSNumber numberWithBool: YES] retain];
    gNumber_NO = [[NSNumber numberWithBool: NO] retain];

    gNeedToSetupGlobals = NO;
}

static SEL SelectorFromDictForMenuActionName(NSDictionary *selectorDict, NSString *actionName)
{
    NSString *dictSelectorName;

    if (!selectorDict || !actionName)
    {
        return NULL;
    }

    dictSelectorName = [selectorDict objectForKey: actionName];

    if (!dictSelectorName)
    {
        return NULL;
    }

    return NSSelectorFromString(dictSelectorName);
}

static NSDictionary *MenuItemValidationSelectorDict(void)
{
    return [NSDictionary dictionaryWithObjectsAndKeys:

                                                // File menu

                                                    @"documentHasSelectionAndEnabledTargetLayer",
                                                @"newDocumentFromSelection:",

                                                    @"documentIsValid",
                                                @"exportImage:",

                                                // Edit menu

                                                    @"documentHasSelection",
                                                @"cut:",

                                                    @"documentHasSelection",
                                                @"copy:",

                                                    @"documentCanReadFromPasteboard",
                                                @"paste:",

                                                    @"documentCanReadFromPasteboard",
                                                @"pasteIntoActiveLayer:",

                                                    @"documentHasSelection",
                                                @"delete:",

                                                    @"documentIsValid",
                                                @"selectAll:",

                                                    @"documentHasSelection",
                                                @"deselectAll:",

                                                    @"documentIsValid",
                                                @"selectVisibleTargetPixels:",

                                                    @"documentHasSelection",
                                                @"deselectInvisibleTargetPixels:",

                                                    @"documentIsValid",
                                                @"invertSelection:",

                                                    @"documentHasSelection",
                                                @"nudgeSelectionOutlineLeft:",

                                                    @"documentHasSelection",
                                                @"nudgeSelectionOutlineRight:",

                                                    @"documentHasSelection",
                                                @"nudgeSelectionOutlineUp:",

                                                    @"documentHasSelection",
                                                @"nudgeSelectionOutlineDown:",

                                                    @"documentHasSelection",
                                                @"closeHolesInSelection:",

                                                    @"documentHasSelectionAndDrawLayerIsEnabled",
                                                @"fillSelectedPixels:",

                                                    @"documentHasSelectionAndDrawLayerIsEnabled",
                                                @"eraseSelectedPixels:",

                                                    @"documentHasSelectionAndEnabledTargetLayer",
                                                @"tileSelection:",

                                                    @"documentHasSelectionAndEnabledTargetLayer",
                                                @"tileSelectionAsNewLayer:",

                                                // Layer menu

                                                     @"documentIsValid",
                                                @"newLayer:",

                                                    @"documentIsValid",
                                                @"duplicateActiveLayer:",

                                                    @"documentIsValid",
                                                @"deleteActiveLayer:",

                                                   @"documentIsValid",
                                                @"toggleActiveLayerEnabledFlag:",

                                                    @"documentIsValid",
                                                @"enableAllLayers:",

                                                    @"documentIsValid",
                                                @"disableAllLayers:",

                                                    @"documentActiveLayerCanIncreaseOpacity",
                                                @"increaseActiveLayerOpacity:",

                                                    @"documentActiveLayerCanDecreaseOpacity",
                                                @"decreaseActiveLayerOpacity:",

                                                    @"documentHasValidLayerAboveDrawingLayer",
                                                @"makePreviousLayerActive:",

                                                    @"documentHasValidLayerBelowDrawingLayer",
                                                @"makeNextLayerActive:",

                                                    @"documentHasValidLayerAboveDrawingLayer",
                                                @"moveActiveLayerUp:",

                                                    @"documentHasValidLayerBelowDrawingLayer",
                                                @"moveActiveLayerDown:",

                                                    @"documentHasValidLayerAboveDrawingLayer",
                                                @"mergeWithLayerAbove:",

                                                    @"documentHasValidLayerBelowDrawingLayer",
                                                @"mergeWithLayerBelow:",

                                                    @"documentHasMultipleLayers",
                                                @"mergeAllLayers:",

                                                    @"documentIsValid",
                                                @"toggleLayerBlendingMode:",

                                                // Canvas menu

                                                    @"documentHasMultipleLayers",
                                                @"toggleCanvasDisplayMode:",

                                                    @"canvasViewCanZoomIn",
                                                @"increaseZoom:",

                                                    @"canvasViewCanZoomOut",
                                                @"decreaseZoom:",

                                                    @"documentIsValid",
                                                @"zoomToFit:",

                                                    @"documentIsValid",
                                                @"editGridSettings:",

                                                    @"documentIsValid",
                                                @"toggleGridVisibility:",

                                                    @"documentHasVisibleGrid",
                                                @"toggleGridType:",

                                                    @"documentHasVisibleGrid",
                                                @"toggleGridGuidelinesVisibility:",

                                                    @"documentIsValid",
                                                @"editBackgroundSettings:",

                                                    @"documentHasBackgroundImage",
                                                @"toggleBackgroundImageVisibility:",

                                                    @"documentHasVisibleBackgroundImage",
                                                @"toggleBackgroundImageSmoothing:",

                                                    @"documentIsValid",
                                                @"flipCanvasHorizontally:",

                                                    @"documentIsValid",
                                                @"flipCanvasVertically:",

                                                    @"documentIsValid",
                                                @"rotateCanvas90Clockwise:",

                                                    @"documentIsValid",
                                                @"rotateCanvas90Counterclockwise:",

                                                    @"documentIsValid",
                                                @"rotateCanvas180:",

                                                    @"documentIsValid",
                                                @"resize:",

                                                    @"documentIsValid",
                                                @"scale:",

                                                    @"documentHasSelection",
                                                @"cropToSelection:",

                                                // Operation menu

                                                    @"documentHasMultipleLayers",
                                                @"toggleLayerOperationTarget:",

                                                    @"documentHasSelectionOrEnabledTargetLayer",
                                                @"flipHorizontally:",

                                                    @"documentHasSelectionOrEnabledTargetLayer",
                                                @"flipVertically:",

                                                    @"documentHasSelectionOrEnabledTargetLayer",
                                                @"rotate90Clockwise:",

                                                    @"documentHasSelectionOrEnabledTargetLayer",
                                                @"rotate90Counterclockwise:",

                                                    @"documentHasSelectionOrEnabledTargetLayer",
                                                @"rotate180:",

                                                    @"documentHasSelectionOrEnabledTargetLayer",
                                                @"nudgeLeft:",

                                                    @"documentHasSelectionOrEnabledTargetLayer",
                                                @"nudgeRight:",

                                                    @"documentHasSelectionOrEnabledTargetLayer",
                                                @"nudgeUp:",

                                                    @"documentHasSelectionOrEnabledTargetLayer",
                                                @"nudgeDown:",

                                                // Panels menu

                                                    @"documentIsValid",
                                                @"toggleToolsPanelVisibility:",

                                                    @"documentIsValid",
                                                @"toggleLayersPanelVisibility:",

                                                    @"documentIsValid",
                                                @"togglePreviewPanelVisibility:",

                                                    @"documentHasActiveSamplerImageForPanel",
                                                @"toggleSamplerImagePanelVisibility:",

                                                    @"documentIsValid",
                                                @"toggleToolModifierTipsPanelVisibility:",

                                                    @"documentIsValid",
                                                @"toggleActivePanelsVisibility:",

                                                    @"documentIsValid",
                                                @"toggleColorPickerVisibility:",

                                                    @"documentIsValid",
                                                @"editSamplerImagesSettings:",

                                    @"documentHasMultipleSamplerImagesAndSamplerPanelIsVisible",
                                                @"nextSamplerPanelImage:",

                                    @"documentHasMultipleSamplerImagesAndSamplerPanelIsVisible",
                                                @"previousSamplerPanelImage:",

                                                    nil];
}

static NSDictionary *MenuItemModificationSelectorDict(void)
{
    return [NSDictionary dictionaryWithObjectsAndKeys:

                                    @"modifyMenuItemForLayerEnabled:",
                                @"toggleActiveLayerEnabledFlag:",

                                    @"modifyMenuItemForLayerBlendingMode:",
                                @"toggleLayerBlendingMode:",

                                    @"modifyMenuItemForCanvasDisplayMode:",
                                @"toggleCanvasDisplayMode:",

                                    @"modifyMenuItemForGridVisibilityStatus:",
                                @"toggleGridVisibility:",

                                    @"modifyMenuItemForGridType:",
                                @"toggleGridType:",

                                    @"modifyMenuItemForGridGuidelinesVisibilityStatus:",
                                @"toggleGridGuidelinesVisibility:",

                                    @"modifyMenuItemForBackgroundImageVisibilityStatus:",
                                @"toggleBackgroundImageVisibility:",

                                    @"modifyMenuItemForBackgroundImageSmoothingStatus:",
                                @"toggleBackgroundImageSmoothing:",

                                    @"modifyMenuItemForLayerOperationTarget:",
                                @"toggleLayerOperationTarget:",

                                    @"modifyMenuItemForToolsPanelVisibilityStatus:",
                                @"toggleToolsPanelVisibility:",

                                    @"modifyMenuItemForLayersPanelVisibilityStatus:",
                                @"toggleLayersPanelVisibility:",

                                    @"modifyMenuItemForPreviewPanelVisibilityStatus:",
                                @"togglePreviewPanelVisibility:",

                                    @"modifyMenuItemForSamplerImagePanelVisibilityStatus:",
                                @"toggleSamplerImagePanelVisibility:",

                                    @"modifyMenuItemForToolModifierTipsPanelVisibilityStatus:",
                                @"toggleToolModifierTipsPanelVisibility:",

                                    nil];
}

static bool MenuActionNameIsAllowedDuringMouseTracking(NSString *actionName)
{
    static NSSet *allowedMouseTrackingActionNamesSet = nil;

    if (!actionName)
        goto ERROR;

    if (!allowedMouseTrackingActionNamesSet)
    {
        allowedMouseTrackingActionNamesSet =
                                [[NSSet setWithObjects:
                                                    @"toggleGridVisibility:",
                                                    @"toggleGridType:",
                                                    @"toggleGridGuidelinesVisibility:",
                                                    @"toggleBackgroundImageVisibility:",
                                                    @"toggleBackgroundImageSmoothing:",
                                                    @"toggleToolsPanelVisibility:",
                                                    @"toggleLayersPanelVisibility:",
                                                    @"togglePreviewPanelVisibility:",
                                                    @"toggleSamplerImagePanelVisibility:",
                                                    @"toggleToolModifierTipsPanelVisibility:",
                                                    @"toggleActivePanelsVisibility:",
                                                    @"toggleColorPickerVisibility:",
                                                    @"nextSamplerPanelImage:",
                                                    @"previousSamplerPanelImage:",
                                                    nil]
                                            retain];
    }

    return ([allowedMouseTrackingActionNamesSet containsObject: actionName]) ? YES : NO;

ERROR:
    return NO;
}

static bool MenuActionNameIsAllowedDuringPopupPanel(NSString *actionName)
{
    static NSSet *disallowedPopupPanelActionNamesSet = nil;

    if (!actionName)
        goto ERROR;

    if (!disallowedPopupPanelActionNamesSet)
    {
        disallowedPopupPanelActionNamesSet =
                                [[NSSet setWithObjects:
                                                    @"nextSamplerPanelImage:",
                                                    @"previousSamplerPanelImage:",
                                                    nil]
                                            retain];
    }

    return ([disallowedPopupPanelActionNamesSet containsObject: actionName]) ? NO : YES;

ERROR:
    return NO;
}
