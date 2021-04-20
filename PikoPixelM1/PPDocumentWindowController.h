/*
    PPDocumentWindowController.h

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

#import <Cocoa/Cocoa.h>
#import "PPLayerDisplayMode.h"


@class PPDocument, PPCanvasView, PPPanelsController, PPPopupPanelsController;

@interface PPDocumentWindowController : NSWindowController
{
    PPDocument *_ppDocument;

    IBOutlet PPCanvasView *_canvasView;

    PPLayerDisplayMode _canvasDisplayMode;
    PPLayerDisplayMode _canvasDisplayModeToRestore;

    NSPoint _mouseDownLocation;
    NSPoint _lastMouseLocation;

    PPPanelsController *_panelsController;
    PPPopupPanelsController *_popupPanelsController;

    NSString *_pressedHotkeyForActivePopupPanel;
    NSTimer *_popupPanelHotkeyRepeatTimeoutTimer;

    unsigned _modifierKeyFlags;

    unsigned _lockedActiveToolModifierKeyFlags;

    bool _documentWindowIsKey;
    bool _isTrackingMouseInCanvasView;
    bool _shouldUseImageCoordinatesForMouseLocation;
    bool _shouldClipMouseLocationPointsToCanvasBounds;
    bool _activeToolCursorDependsOnModifierKeys;
    bool _shouldMatchCanvasDisplayModeToOperationTargetWhileTrackingMouse;
    bool _disallowMatchingCanvasDisplayModeToDrawLayerTarget;
    bool _shouldUpdateActiveToolOnMouseUp;
}

+ controller;

- (PPCanvasView *) canvasView;

- (void) setCanvasDisplayMode: (PPLayerDisplayMode) canvasDisplayMode;
- (void) toggleCanvasDisplayMode;
- (PPLayerDisplayMode) canvasDisplayMode;

- (bool) isTrackingMouseInCanvasView;

@end

@interface PPDocumentWindowController (Actions)

// File
- (IBAction) newDocumentFromSelection: (id) sender;

- (IBAction) exportImage: (id) sender;

// Edit
- (IBAction) cut: (id) sender;
- (IBAction) copy: (id) sender;
- (IBAction) paste: (id) sender;
- (IBAction) pasteIntoActiveLayer: (id) sender;

- (IBAction) delete: (id) sender;

- (IBAction) selectAll: (id) sender;
- (IBAction) deselectAll: (id) sender;

- (IBAction) selectVisibleTargetPixels: (id) sender;
- (IBAction) deselectInvisibleTargetPixels: (id) sender;

- (IBAction) invertSelection: (id) sender;

- (IBAction) nudgeSelectionOutlineLeft: (id) sender;
- (IBAction) nudgeSelectionOutlineRight: (id) sender;
- (IBAction) nudgeSelectionOutlineUp: (id) sender;
- (IBAction) nudgeSelectionOutlineDown: (id) sender;

- (IBAction) closeHolesInSelection: (id) sender;

- (IBAction) fillSelectedPixels: (id) sender;
- (IBAction) eraseSelectedPixels: (id) sender;

- (IBAction) tileSelection: (id) sender;
- (IBAction) tileSelectionAsNewLayer: (id) sender;

// Layer
- (IBAction) newLayer: (id) sender;
- (IBAction) duplicateActiveLayer: (id) sender;
- (IBAction) deleteActiveLayer: (id) sender;

- (IBAction) toggleActiveLayerEnabledFlag: (id) sender;

- (IBAction) enableAllLayers: (id) sender;
- (IBAction) disableAllLayers: (id) sender;

- (IBAction) increaseActiveLayerOpacity: (id) sender;
- (IBAction) decreaseActiveLayerOpacity: (id) sender;

- (IBAction) makePreviousLayerActive: (id) sender;
- (IBAction) makeNextLayerActive: (id) sender;

- (IBAction) moveActiveLayerUp: (id) sender;
- (IBAction) moveActiveLayerDown: (id) sender;

- (IBAction) mergeWithLayerAbove: (id) sender;
- (IBAction) mergeWithLayerBelow: (id) sender;
- (IBAction) mergeAllLayers: (id) sender;

- (IBAction) toggleLayerBlendingMode: (id) sender;

// Canvas
- (IBAction) toggleCanvasDisplayMode: (id) sender;

- (IBAction) increaseZoom: (id) sender;
- (IBAction) decreaseZoom: (id) sender;
- (IBAction) zoomToFit: (id) sender;

- (IBAction) editGridSettings: (id) sender;
- (IBAction) toggleGridVisibility: (id) sender;
- (IBAction) toggleGridType: (id) sender;
- (IBAction) toggleGridGuidelinesVisibility: (id) sender;

- (IBAction) editBackgroundSettings: (id) sender;
- (IBAction) toggleBackgroundImageVisibility: (id) sender;
- (IBAction) toggleBackgroundImageSmoothing: (id) sender;

- (IBAction) flipCanvasHorizontally: (id) sender;
- (IBAction) flipCanvasVertically: (id) sender;

- (IBAction) rotateCanvas90Clockwise: (id) sender;
- (IBAction) rotateCanvas90Counterclockwise: (id) sender;
- (IBAction) rotateCanvas180: (id) sender;

- (IBAction) resize: (id) sender;
- (IBAction) scale: (id) sender;
- (IBAction) cropToSelection: (id) sender;

// Operation
- (IBAction) toggleLayerOperationTarget: (id) sender;

- (IBAction) flipHorizontally: (id) sender;
- (IBAction) flipVertically: (id) sender;

- (IBAction) rotate90Clockwise: (id) sender;
- (IBAction) rotate90Counterclockwise: (id) sender;
- (IBAction) rotate180: (id) sender;

- (IBAction) nudgeLeft: (id) sender;
- (IBAction) nudgeRight: (id) sender;
- (IBAction) nudgeUp: (id) sender;
- (IBAction) nudgeDown: (id) sender;

// Panels
- (IBAction) toggleToolsPanelVisibility: (id) sender;
- (IBAction) toggleLayersPanelVisibility: (id) sender;
- (IBAction) togglePreviewPanelVisibility: (id) sender;
- (IBAction) toggleSamplerImagePanelVisibility: (id) sender;
- (IBAction) toggleToolModifierTipsPanelVisibility: (id) sender;
- (IBAction) toggleActivePanelsVisibility: (id) sender;
- (IBAction) toggleColorPickerVisibility: (id) sender;

- (IBAction) editSamplerImagesSettings: (id) sender;
- (IBAction) nextSamplerPanelImage: (id) sender;
- (IBAction) previousSamplerPanelImage: (id) sender;

// Important: Keep IBAction method names in sync with relevant action name strings in
// +setupHotkeyToActionSelectorNameDict class method (PPDocumentWindowController.m)

@end

extern NSString *PPDocumentWindowControllerNotification_ChangedCanvasDisplayMode;
