/*
    PPDocumentWindowController_Actions.m

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
#import "PPDocumentWindowController_Sheets.h"
#import "PPPanelsController.h"
#import "PPToolsPanelController.h"
#import "NSDocumentController_PPUtilities.h"


@implementation PPDocumentWindowController (Actions)

#pragma mark File

- (IBAction) newDocumentFromSelection: (id) sender
{
    if (_isTrackingMouseInCanvasView)
        return;

    if (![_ppDocument hasSelection])
    {
        goto ERROR;
    }

    [[NSDocumentController sharedDocumentController]
                                        ppOpenUntitledDuplicateOfPPDocument:
                                                        [_ppDocument ppDocumentFromSelection]];

    return;

ERROR:
    return;
}

- (IBAction) exportImage: (id) sender
{
    if (_isTrackingMouseInCanvasView)
        return;

    [_ppDocument exportImage];
}

#pragma mark Edit

- (IBAction) cut: (id) sender
{
    if (_isTrackingMouseInCanvasView)
        return;

    [_ppDocument cutSelectionToPasteboardFromTarget: [_ppDocument layerOperationTarget]];
}

- (IBAction) copy: (id) sender
{
    if (_isTrackingMouseInCanvasView)
        return;

    [_ppDocument copySelectionToPasteboardFromTarget: [_ppDocument layerOperationTarget]];
}

- (IBAction) paste: (id) sender
{
    if (_isTrackingMouseInCanvasView)
        return;

    [_ppDocument pasteNewLayerFromPasteboard];
}

- (IBAction) pasteIntoActiveLayer: (id) sender
{
    if (_isTrackingMouseInCanvasView)
        return;

    [_ppDocument pasteIntoDrawingLayerFromPasteboard];
}

- (IBAction) delete: (id) sender
{
    if (_isTrackingMouseInCanvasView)
        return;

    [_ppDocument noninteractiveEraseSelectedAreaInTarget: [_ppDocument layerOperationTarget]
                    andClearSelectionMask: YES];
}

- (IBAction) selectAll: (id) sender
{
    if (_isTrackingMouseInCanvasView)
        return;

    [_ppDocument selectAll];
}

- (IBAction) deselectAll: (id) sender
{
    if (_isTrackingMouseInCanvasView)
        return;

    [_ppDocument deselectAll];
}

- (IBAction) selectVisibleTargetPixels: (id) sender
{
    if (_isTrackingMouseInCanvasView)
        return;

    [_ppDocument selectVisibleTargetPixels];
}

- (IBAction) deselectInvisibleTargetPixels: (id) sender
{
    if (_isTrackingMouseInCanvasView)
        return;

    [_ppDocument deselectInvisibleTargetPixels];
}

- (IBAction) invertSelection: (id) sender
{
    if (_isTrackingMouseInCanvasView)
        return;

    [_ppDocument invertSelection];
}

- (IBAction) nudgeSelectionOutlineLeft: (id) sender
{
    if (_isTrackingMouseInCanvasView)
        return;

    [_ppDocument nudgeInDirection: kPPDirectionType_Left
                    moveType: kPPMoveOperationType_SelectionOutlineOnly
                    target: [_ppDocument layerOperationTarget]];
}

- (IBAction) nudgeSelectionOutlineRight: (id) sender
{
    if (_isTrackingMouseInCanvasView)
        return;

    [_ppDocument nudgeInDirection: kPPDirectionType_Right
                    moveType: kPPMoveOperationType_SelectionOutlineOnly
                    target: [_ppDocument layerOperationTarget]];
}

- (IBAction) nudgeSelectionOutlineUp: (id) sender
{
    if (_isTrackingMouseInCanvasView)
        return;

    [_ppDocument nudgeInDirection: kPPDirectionType_Up
                    moveType: kPPMoveOperationType_SelectionOutlineOnly
                    target: [_ppDocument layerOperationTarget]];
}

- (IBAction) nudgeSelectionOutlineDown: (id) sender
{
    if (_isTrackingMouseInCanvasView)
        return;

    [_ppDocument nudgeInDirection: kPPDirectionType_Down
                    moveType: kPPMoveOperationType_SelectionOutlineOnly
                    target: [_ppDocument layerOperationTarget]];
}

- (IBAction) closeHolesInSelection: (id) sender
{
    if (_isTrackingMouseInCanvasView)
        return;

    [_ppDocument closeHolesInSelection];
}

- (IBAction) fillSelectedPixels: (id) sender
{
    if (_isTrackingMouseInCanvasView)
        return;

    [_ppDocument noninteractiveFillSelectedDrawingArea];
}

- (IBAction) eraseSelectedPixels: (id) sender
{
    if (_isTrackingMouseInCanvasView)
        return;

    [_ppDocument noninteractiveEraseSelectedAreaInTarget:
                                                    kPPLayerOperationTarget_DrawingLayerOnly
                    andClearSelectionMask: NO];
}

- (IBAction) tileSelection: (id) sender
{
    if (_isTrackingMouseInCanvasView)
        return;

    [_ppDocument tileSelection];
}

- (IBAction) tileSelectionAsNewLayer: (id) sender
{
    if (_isTrackingMouseInCanvasView)
        return;

    [_ppDocument tileSelectionAsNewLayer];
}

#pragma mark Layer

- (IBAction) newLayer: (id) sender
{
    if (_isTrackingMouseInCanvasView)
        return;

    [_ppDocument createNewLayer];
}

- (IBAction) duplicateActiveLayer: (id) sender
{
    if (_isTrackingMouseInCanvasView)
        return;

    [_ppDocument duplicateLayerAtIndex: [_ppDocument indexOfDrawingLayer]];
}

- (IBAction) deleteActiveLayer: (id) sender
{
    if (_isTrackingMouseInCanvasView)
        return;

    [_ppDocument removeLayerAtIndex: [_ppDocument indexOfDrawingLayer]];
}

- (IBAction) toggleActiveLayerEnabledFlag: (id) sender
{
    PPDocumentLayer *drawingLayer;

    if (_isTrackingMouseInCanvasView)
        return;

    drawingLayer = [_ppDocument drawingLayer];

    [drawingLayer setEnabled: ![drawingLayer isEnabled]];
}

- (IBAction) enableAllLayers: (id) sender
{
    if (_isTrackingMouseInCanvasView)
        return;

    [_ppDocument setEnabledFlagForAllLayers: YES];
}

- (IBAction) disableAllLayers: (id) sender
{
    if (_isTrackingMouseInCanvasView)
        return;

    [_ppDocument setEnabledFlagForAllLayers: NO];
}

- (IBAction) increaseActiveLayerOpacity: (id) sender
{
    if (_isTrackingMouseInCanvasView)
        return;

    [[_ppDocument drawingLayer] increaseOpacity];
}

- (IBAction) decreaseActiveLayerOpacity: (id) sender
{
    if (_isTrackingMouseInCanvasView)
        return;

    [[_ppDocument drawingLayer] decreaseOpacity];
}

- (IBAction) makePreviousLayerActive: (id) sender
{
    if (_isTrackingMouseInCanvasView)
        return;

    [_ppDocument selectDrawingLayerAtIndex: [_ppDocument indexOfDrawingLayer] + 1];
}

- (IBAction) makeNextLayerActive: (id) sender
{
    if (_isTrackingMouseInCanvasView)
        return;

    [_ppDocument selectDrawingLayerAtIndex: [_ppDocument indexOfDrawingLayer] - 1];
}

- (IBAction) moveActiveLayerUp: (id) sender
{
    if (_isTrackingMouseInCanvasView)
        return;

    [_ppDocument moveDrawingLayerUp];
}

- (IBAction) moveActiveLayerDown: (id) sender
{
    if (_isTrackingMouseInCanvasView)
        return;

    [_ppDocument moveDrawingLayerDown];
}

- (IBAction) mergeWithLayerAbove: (id) sender
{
    if (_isTrackingMouseInCanvasView)
        return;

    [_ppDocument mergeDrawingLayerUp];
}

- (IBAction) mergeWithLayerBelow: (id) sender
{
    if (_isTrackingMouseInCanvasView)
        return;

    [_ppDocument mergeDrawingLayerDown];
}

- (IBAction) mergeAllLayers: (id) sender
{
    if (_isTrackingMouseInCanvasView)
        return;

    [_ppDocument mergeAllLayers];
}

- (IBAction) toggleLayerBlendingMode: (id) sender
{
    if (_isTrackingMouseInCanvasView)
        return;

    [_ppDocument toggleLayerBlendingMode];
}

#pragma mark Canvas

- (IBAction) toggleCanvasDisplayMode: (id) sender
{
    if (_isTrackingMouseInCanvasView)
        return;

    [self toggleCanvasDisplayMode];
}

- (IBAction) increaseZoom: (id) sender
{
    if (_isTrackingMouseInCanvasView)
        return;

    [_canvasView increaseZoomFactor];
}

- (IBAction) decreaseZoom: (id) sender
{
    if (_isTrackingMouseInCanvasView)
        return;

    [_canvasView decreaseZoomFactor];
}

- (IBAction) zoomToFit: (id) sender
{
    if (_isTrackingMouseInCanvasView)
        return;

    [_canvasView setZoomToFitCanvas];
}

- (IBAction) editGridSettings: (id) sender
{
    if (_isTrackingMouseInCanvasView)
        return;

    [self beginGridSettingsSheet];
}

- (IBAction) toggleGridVisibility: (id) sender
{
    [_ppDocument toggleGridVisibility];
}

- (IBAction) toggleGridType: (id) sender
{
    [_ppDocument togglePixelGridPatternType];
}

- (IBAction) toggleGridGuidelinesVisibility: (id) sender
{
    [_ppDocument toggleGridGuidelinesVisibility];
}

- (IBAction) editBackgroundSettings: (id) sender
{
    if (_isTrackingMouseInCanvasView)
        return;

    [self beginBackgroundSettingsSheet];
}

- (IBAction) toggleBackgroundImageVisibility: (id) sender
{
    [_ppDocument toggleBackgroundImageVisibility];
}

- (IBAction) toggleBackgroundImageSmoothing: (id) sender
{
    [_ppDocument toggleBackgroundImageSmoothing];
}

- (IBAction) flipCanvasHorizontally: (id) sender
{
    if (_isTrackingMouseInCanvasView)
        return;

    [_ppDocument mirrorHorizontallyWithTarget: kPPLayerOperationTarget_Canvas];
}

- (IBAction) flipCanvasVertically: (id) sender
{
    if (_isTrackingMouseInCanvasView)
        return;

    [_ppDocument mirrorVerticallyWithTarget: kPPLayerOperationTarget_Canvas];
}

- (IBAction) rotateCanvas90Clockwise: (id) sender
{
    if (_isTrackingMouseInCanvasView)
        return;

    [_ppDocument rotate90ClockwiseWithTarget: kPPLayerOperationTarget_Canvas];
}

- (IBAction) rotateCanvas90Counterclockwise: (id) sender
{
    if (_isTrackingMouseInCanvasView)
        return;

    [_ppDocument rotate90CounterclockwiseWithTarget: kPPLayerOperationTarget_Canvas];
}

- (IBAction) rotateCanvas180: (id) sender
{
    if (_isTrackingMouseInCanvasView)
        return;

    [_ppDocument rotate180WithTarget: kPPLayerOperationTarget_Canvas];
}

- (IBAction) resize: (id) sender
{
    if (_isTrackingMouseInCanvasView)
        return;

    [self beginResizeSheet];
}

- (IBAction) scale: (id) sender
{
    if (_isTrackingMouseInCanvasView)
        return;

    [self beginScaleSheet];
}

- (IBAction) cropToSelection: (id) sender
{
    if (_isTrackingMouseInCanvasView)
        return;

    [_ppDocument cropToSelectionBounds];
}

#pragma mark Operation

- (IBAction) toggleLayerOperationTarget: (id) sender
{
    PPLayerOperationTarget newOperationTarget;

    if (_isTrackingMouseInCanvasView)
        return;

    if ([_ppDocument layerOperationTarget] == kPPLayerOperationTarget_DrawingLayerOnly)
    {
        newOperationTarget = kPPLayerOperationTarget_VisibleLayers;
    }
    else
    {
        newOperationTarget = kPPLayerOperationTarget_DrawingLayerOnly;
    }

    [_ppDocument setLayerOperationTarget: newOperationTarget];
}

- (IBAction) flipHorizontally: (id) sender
{
    if (_isTrackingMouseInCanvasView)
        return;

    [_ppDocument mirrorHorizontallyWithTarget: [_ppDocument layerOperationTarget]];
}

- (IBAction) flipVertically: (id) sender
{
    if (_isTrackingMouseInCanvasView)
        return;

    [_ppDocument mirrorVerticallyWithTarget: [_ppDocument layerOperationTarget]];
}

- (IBAction) rotate90Clockwise: (id) sender
{
    if (_isTrackingMouseInCanvasView)
        return;

    [_ppDocument rotate90ClockwiseWithTarget: [_ppDocument layerOperationTarget]];
}

- (IBAction) rotate90Counterclockwise: (id) sender
{
    if (_isTrackingMouseInCanvasView)
        return;

    [_ppDocument rotate90CounterclockwiseWithTarget: [_ppDocument layerOperationTarget]];
}

- (IBAction) rotate180: (id) sender
{
    if (_isTrackingMouseInCanvasView)
        return;

    [_ppDocument rotate180WithTarget: [_ppDocument layerOperationTarget]];
}

- (IBAction) nudgeLeft: (id) sender
{
    if (_isTrackingMouseInCanvasView)
        return;

    [_ppDocument nudgeInDirection: kPPDirectionType_Left
                    moveType: kPPMoveOperationType_Normal
                    target: [_ppDocument layerOperationTarget]];
}

- (IBAction) nudgeRight: (id) sender
{
    if (_isTrackingMouseInCanvasView)
        return;

    [_ppDocument nudgeInDirection: kPPDirectionType_Right
                    moveType: kPPMoveOperationType_Normal
                    target: [_ppDocument layerOperationTarget]];
}

- (IBAction) nudgeUp: (id) sender
{
    if (_isTrackingMouseInCanvasView)
        return;

    [_ppDocument nudgeInDirection: kPPDirectionType_Up
                    moveType: kPPMoveOperationType_Normal
                    target: [_ppDocument layerOperationTarget]];
}

- (IBAction) nudgeDown: (id) sender
{
    if (_isTrackingMouseInCanvasView)
        return;

    [_ppDocument nudgeInDirection: kPPDirectionType_Down
                    moveType: kPPMoveOperationType_Normal
                    target: [_ppDocument layerOperationTarget]];
}

#pragma mark Panels

- (IBAction) toggleToolsPanelVisibility: (id) sender
{
    [_panelsController toggleEnabledStateForPanelOfType: kPPPanelType_Tools];
}

- (IBAction) toggleLayersPanelVisibility: (id) sender
{
    [_panelsController toggleEnabledStateForPanelOfType: kPPPanelType_Layers];
}

- (IBAction) togglePreviewPanelVisibility: (id) sender
{
    [_panelsController toggleEnabledStateForPanelOfType: kPPPanelType_Preview];
}

- (IBAction) toggleSamplerImagePanelVisibility: (id) sender
{
    [_panelsController toggleEnabledStateForPanelOfType: kPPPanelType_SamplerImage];
}

- (IBAction) toggleToolModifierTipsPanelVisibility: (id) sender
{
    [_panelsController toggleEnabledStateForPanelOfType: kPPPanelType_ToolModifierTips];
}

- (IBAction) toggleActivePanelsVisibility: (id) sender
{
    [_panelsController toggleEnabledStateForActivePanels];
}

- (IBAction) toggleColorPickerVisibility: (id) sender
{
    [[PPToolsPanelController sharedController] toggleFillColorWell];
}

- (IBAction) editSamplerImagesSettings: (id) sender
{
    if (_isTrackingMouseInCanvasView)
        return;

    [self beginSamplerImagesSettingsSheet];
}

- (IBAction) nextSamplerPanelImage: (id) sender
{
    [_ppDocument activateNextSamplerImageForPanelType: kPPSamplerImagePanelType_Panel];
}

- (IBAction) previousSamplerPanelImage: (id) sender
{
    [_ppDocument activatePreviousSamplerImageForPanelType: kPPSamplerImagePanelType_Panel];
}

@end
