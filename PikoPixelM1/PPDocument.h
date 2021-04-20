/*
    PPDocument.h

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
#import "PPDocumentTypes.h"
#import "PPDefines.h"
#import "PPToolType.h"
#import "PPGridType.h"
#import "PPDirectionType.h"
#import "PPLayerDisplayMode.h"
#import "PPSamplerImagePanelType.h"
#import "NSDocument_PPUtilities.h"
#import "PPBitmapPixelTypes.h"


@class PPDocumentLayer, PPTool, PPBackgroundPattern, PPGridPattern, PPDocumentSamplerImage,
        PPExportPanelAccessoryViewController, PPDocumentWindowController;

@interface PPDocument : NSDocument <NSCoding>
{
    NSRect _canvasFrame;

    NSMutableArray *_layers;
    int _numLayers;

    PPDocumentLayer *_drawingLayer;
    NSBitmapImageRep *_drawingLayerBitmap;
    NSImage *_drawingLayerImage;
    int _indexOfDrawingLayer;

    NSBitmapImageRep *_dissolvedDrawingLayerBitmap;
    NSImage *_dissolvedDrawingLayerThumbnailImage;

    NSBitmapImageRep *_mergedVisibleLayersBitmap;
    NSImage *_mergedVisibleLayersThumbnailImage;

    NSBitmapImageRep *_mergedVisibleLayersLinearBitmap;

    NSObject *_cachedOverlayersImageObjects[kMaxLayersPerDocument];
    NSObject *_cachedUnderlayersImageObjects[kMaxLayersPerDocument];

    NSBitmapImageRep *_drawingMask;

    NSBitmapImageRep *_drawingUndoBitmap;
    NSRect _drawingUndoBounds;

    NSBitmapImageRep *_selectionMask;
    NSRect _selectionBounds;

    NSBitmapImageRep *_interactiveEraseMask;
    NSRect _interactiveEraseBounds;

    PPToolType _selectedToolType;
    PPToolType _lastSelectedToolType;
    PPToolType _activeToolType;
    PPTool *_activeTool;

    PPPenMode _penMode;

    NSColor *_fillColor;        // original colorspace preserved, returned by -fillColor method
    NSColor *_fillColor_sRGB;   // _fillColor in sRGB colorspace, used when drawing & saving

    PPImageBitmapPixel _fillColorPixelValue_sRGB;   // _fillColor_sRGB as bitmapData pixel-value

    PPLayerOperationTarget _layerOperationTarget;
    int _targetLayerIndexes[kMaxLayersPerDocument];
    int _numTargetLayerIndexes;

    PPLayerBlendingMode _layerBlendingMode;

    PPBackgroundPattern *_backgroundPattern;
    NSImage *_backgroundImage;
    NSData *_compressedBackgroundImageData;

    PPGridPattern *_gridPattern;

    NSMutableArray *_samplerImages;
    int _numSamplerImages;
    int _activeSamplerImageIndexes[kNumPPSamplerImagePanelTypes];
    int _samplerImageMinIndexValues[kNumPPSamplerImagePanelTypes];

    PPLayerOperationTarget _interactiveMoveOperationTarget;
    PPLayerDisplayMode _interactiveMoveDisplayMode;
    NSBitmapImageRep *_interactiveMoveTargetBitmap;
    NSBitmapImageRep *_interactiveMoveFloatingBitmap;
    NSBitmapImageRep *_interactiveMoveFloatingMask;
    NSBitmapImageRep *_interactiveMoveUnderlyingBitmap;
    NSBitmapImageRep *_interactiveMoveInitialSelectionMask;
    NSRect _interactiveMoveInitialSelectionBounds;
    PPMoveOperationType _lastInteractiveMoveType;
    NSPoint _lastInteractiveMoveOffset;
    NSRect _lastInteractiveMoveBounds;

    PPExportPanelAccessoryViewController *_exportPanelViewController;

    PPDocumentSaveFormat _saveFormat;

    bool _hasSelection;
    bool _isDrawing;
    bool _shouldUndoCurrentDrawing;
    bool _isPerformingInteractiveMove;
    bool _shouldDisplayBackgroundImage;
    bool _shouldSmoothenBackgroundImage;
    bool _shouldDisplayGrid;
    bool _shouldEnableSamplerImagePanel;
    bool _mergedVisibleBitmapHasEnabledLayer;
    bool _disallowUpdatesToMergedBitmap;
    bool _disallowThumbnailImageUpdateNotifications;
    bool _disallowAutosaving;
    bool _shouldAutosaveWhenAllowed;
    bool _savePanelShouldAttachExportAccessoryView;
    bool _saveToOperationShouldUseExportSettings;
    bool _sourceBitmapHasAnimationFrames;
}

- (bool) setupNewPPDocumentWithCanvasSize: (NSSize) canvasSize;

- (bool) loadFromPPDocument: (PPDocument *) ppDocument;

- (bool) loadFromImageBitmap: (NSBitmapImageRep *) bitmap
            withFileType: (NSString *) fileType;

- (bool) needToSetCanvasSize;
- (NSSize) canvasSize;

- (bool) resizeCanvasForCurrentLayers;

- (NSBitmapImageRep *) mergedVisibleLayersBitmap;
- (NSImage *) mergedVisibleLayersThumbnailImage;

- (NSBitmapImageRep *) drawingLayerBitmap;
- (NSImage *) drawingLayerThumbnailImage;

- (NSBitmapImageRep *) dissolvedDrawingLayerBitmap;
- (NSImage *) dissolvedDrawingLayerThumbnailImage;

- (NSBitmapImageRep *) mergedVisibleLayersBitmapUsingExportPanelSettings;

- (PPDocumentWindowController *) ppDocumentWindowController;

- (void) setupCompressedBackgroundImageData;
- (void) destroyCompressedBackgroundImageData;

- (bool) sourceBitmapHasAnimationFrames;

@end

@interface PPDocument (Saving)

- (void) disableAutosaving: (bool) disallowAutosaving;

- (void) exportImage;

@end

@interface PPDocument (LayerOperationTarget)

- (void) setLayerOperationTarget: (PPLayerOperationTarget) operationTarget;
- (PPLayerOperationTarget) layerOperationTarget;

- (bool) layerOperationTargetHasEnabledLayer;

- (NSBitmapImageRep *) sourceBitmapForLayerOperationTarget:
                                                    (PPLayerOperationTarget) operationTarget;

- (void) setupTargetLayerIndexesForOperationTarget: (PPLayerOperationTarget) operationTarget;

- (NSString *) nameOfLayerOperationTarget: (PPLayerOperationTarget) operationTarget;
- (NSString *) nameWithSelectionStateForLayerOperationTarget:
                                                    (PPLayerOperationTarget) operationTarget;

@end

@interface PPDocument (Layers)

- (int) numLayers;
- (PPDocumentLayer *) layerAtIndex: (int) index;

- (void) createNewLayer;
- (void) insertLayer: (PPDocumentLayer *) layer
            atIndex: (int) index
            andSetAsDrawingLayer: (bool) shouldSetAsDrawingLayer;
- (void) removeLayerAtIndex: (int) index;
- (void) moveLayerAtIndex: (int) oldIndex
            toIndex: (int) newIndex;
- (void) duplicateLayerAtIndex: (int) index;

- (void) removeAllLayers;
- (void) removeNontargetLayers;

- (bool) setLayers: (NSArray *) newLayers;

- (void) selectDrawingLayerAtIndex: (int) newDrawingLayerIndex;
- (int) indexOfDrawingLayer;
- (PPDocumentLayer *) drawingLayer;

- (void) beginMultilayerOperation;
- (void) finishMultilayerOperation;

- (void) moveDrawingLayerUp;
- (void) moveDrawingLayerDown;

- (void) mergeDrawingLayerUp;
- (void) mergeDrawingLayerDown;

- (void) mergeAllLayers;

- (void) setEnabledFlagForAllLayers: (bool) isEnabled;

- (PPLayerBlendingMode) layerBlendingMode;
- (void) setLayerBlendingMode: (PPLayerBlendingMode) layerBlendingMode;
- (void) toggleLayerBlendingMode;

- (bool) setupLayerBlendingBitmapOfSize: (NSSize) bitmapSize;

- (void) copyImageBitmap: (NSBitmapImageRep *) bitmap
            toLayerAtIndex: (int) index
            atPoint: (NSPoint) origin;

- (void) handleUpdateToLayerAtIndex: (int) index
            inRect: (NSRect) updateRect;

@end

@interface PPDocument (ActiveTool)

// The Selected tool is the tool selected by the user in the tool palette; The Active tool is
// the tool used on the canvas - it can be different from the Selected tool if a modifier key's
// pressed.

- (void) setSelectedToolType: (PPToolType) toolType;
- (void) setSelectedToolTypeToLastSelectedType;
- (PPToolType) selectedToolType;

- (void) setActiveToolType: (PPToolType) toolType;
- (PPToolType) activeToolType;
- (PPTool *) activeTool;

@end

@interface PPDocument (Drawing)

- (NSColor *) fillColor;
- (void) setFillColor: (NSColor *) fillColor;
- (void) setFillColorWithoutUndoRegistration: (NSColor *) fillColor;

- (void) beginDrawingWithPenMode: (PPPenMode) penMode;
- (void) finishDrawing;

- (void) undoCurrentDrawingAtNextDraw;

- (void) drawPixelAtPoint: (NSPoint) point;
- (void) drawLineFromPoint: (NSPoint) startPoint toPoint: (NSPoint) endPoint;
- (void) drawRect: (NSRect) rect andFill: (bool) shouldFill;
- (void) drawOvalInRect: (NSRect) rect andFill: (bool) shouldFill;
- (void) drawBezierPath: (NSBezierPath *) path andFill: (bool) shouldFill;

- (void) drawColorRampWithStartingColor: (NSColor *) startColor
            fromPoint: (NSPoint) startPoint
            toPoint: (NSPoint) endPoint
            returnedRampBounds: (NSRect *) returnedRampBounds
            returnedDrawMask: (NSBitmapImageRep **) returnedDrawMask;

- (NSColor *) colorAtPoint: (NSPoint) point
                inTarget: (PPLayerOperationTarget) target;

- (void) fillPixelsMatchingColorAtPoint: (NSPoint) point
            colorMatchTolerance: (unsigned) colorMatchTolerance
            pixelMatchingMode: (PPPixelMatchingMode) pixelMatchingMode
            returnedMatchMask: (NSBitmapImageRep **) returnedMatchMask
            returnedMatchMaskBounds: (NSRect *) returnedMatchMaskBounds;

- (void) noninteractiveFillSelectedDrawingArea;

- (void) noninteractiveEraseSelectedAreaInTarget: (PPLayerOperationTarget) operationTarget
            andClearSelectionMask: (bool) shouldClearSelectionMask;

- (bool) getInteractiveEraseMask: (NSBitmapImageRep **) returnedEraseMask
            andBounds: (NSRect *) returnedEraseBounds;

- (void) copyImageBitmapToDrawingLayer: (NSBitmapImageRep *) bitmap atPoint: (NSPoint) origin;

@end

@interface PPDocument (Selection)

- (bool) setupSelectionMaskBitmapOfSize: (NSSize) maskSize;

- (bool) hasSelection;
- (NSRect) selectionBounds;

- (NSBitmapImageRep *) selectionMask;
- (void) setSelectionMask: (NSBitmapImageRep *) selectionMask;

- (void) setSelectionMaskAreaWithBitmap: (NSBitmapImageRep *) selectionMask
                                atPoint: (NSPoint) origin;

- (void) selectRect: (NSRect) rect
            selectionMode: (PPSelectionMode) selectionMode;

- (void) selectPath: (NSBezierPath *) path
            selectionMode: (PPSelectionMode) selectionMode;

- (void) selectPixelsMatchingColorAtPoint: (NSPoint) point
            colorMatchTolerance: (unsigned) colorMatchTolerance
            pixelMatchingMode: (PPPixelMatchingMode) pixelMatchingMode
            selectionMode: (PPSelectionMode) selectionMode;

- (void) selectAll;
- (void) selectVisibleTargetPixels;
- (void) deselectAll;
- (void) deselectInvisibleTargetPixels;

- (void) invertSelection;
- (void) closeHolesInSelection;

- (PPDocument *) ppDocumentFromSelection;

@end

@interface PPDocument (PixelMatching)

// maskForPixelsMatchingColorAtPoint::: can be called repeatedly (when dragging the fill or
// wand tools), so rather than construct a new bitmap each time, it just returns a pointer to
// the _drawingMask member (the returned bitmap should only be used temporarily)

- (NSBitmapImageRep *) maskForPixelsMatchingColorAtPoint: (NSPoint) point
                        colorMatchTolerance: (unsigned) colorMatchTolerance
                        pixelMatchingMode: (PPPixelMatchingMode) pixelMatchingMode
                        shouldIntersectSelectionMask: (bool) shouldIntersectSelectionMask;

@end

@interface PPDocument (Moving)

- (void) nudgeInDirection: (PPDirectionType) directionType
            moveType: (PPMoveOperationType) moveType
            target: (PPLayerOperationTarget) operationTarget;

- (void) beginInteractiveMoveWithTarget: (PPLayerOperationTarget) operationTarget
            canvasDisplayMode: (PPLayerDisplayMode) canvasDisplayMode
            moveType: (PPMoveOperationType) moveType;

- (void) setInteractiveMoveOffset: (NSPoint) offset
            andMoveType: (PPMoveOperationType) moveType;

- (void) finishInteractiveMove;

@end

@interface PPDocument (MirroringRotating)

- (void) mirrorHorizontallyWithTarget: (PPLayerOperationTarget) operationTarget;
- (void) mirrorVerticallyWithTarget: (PPLayerOperationTarget) operationTarget;

- (void) rotate180WithTarget: (PPLayerOperationTarget) operationTarget;
- (void) rotate90ClockwiseWithTarget: (PPLayerOperationTarget) operationTarget;
- (void) rotate90CounterclockwiseWithTarget: (PPLayerOperationTarget) operationTarget;

@end

@interface PPDocument (Pasteboard)

- (bool) canReadFromPasteboard;
- (bool) canWriteToPasteboard;

- (void) copySelectionToPasteboardFromTarget: (PPLayerOperationTarget) operationTarget;

- (void) cutSelectionToPasteboardFromTarget: (PPLayerOperationTarget) operationTarget;

- (void) pasteNewLayerFromPasteboard;
- (void) pasteIntoDrawingLayerFromPasteboard;

+ (PPDocument *) ppDocumentFromPasteboard;

@end

@interface PPDocument (CanvasSettings)

- (void) setBackgroundPattern: (PPBackgroundPattern *) backgroundPattern
            backgroundImage: (NSImage *) backgroundImage
            shouldDisplayBackgroundImage: (bool) shouldDisplayBackgroundImage
            shouldSmoothenBackgroundImage: (bool) shouldSmoothenBackgroundImage;

- (PPBackgroundPattern *) backgroundPattern;
- (NSColor *) backgroundPatternAsColor;
- (NSImage *) backgroundImage;
- (bool) shouldDisplayBackgroundImage;
- (bool) shouldSmoothenBackgroundImage;

- (void) toggleBackgroundImageVisibility;
- (void) toggleBackgroundImageSmoothing;

- (void) setGridPattern: (PPGridPattern *) gridPattern
            shouldDisplayGrid: (bool) shouldDisplayGrid;

- (PPGridPattern *) gridPattern;

- (bool) shouldDisplayGrid;
- (void) toggleGridVisibility;

- (PPGridType) pixelGridPatternType;
- (void) togglePixelGridPatternType;

- (bool) gridPatternShouldDisplayGuidelines;
- (void) toggleGridGuidelinesVisibility;

- (bool) shouldDisplayGridAndGridGuidelines;

- (NSRect) gridGuidelineBoundsCoveredByRect: (NSRect) rect;

- (bool) hasCustomCanvasSettings;

@end

@interface PPDocument (Resizing)

- (void) resizeToSize: (NSSize) newSize shouldScale: (bool) shouldScale;

- (void) cropToSelectionBounds;

@end

@interface PPDocument (Tiling)

- (void) tileSelection;

- (void) tileSelectionAsNewLayer;

@end

@interface PPDocument (SamplerImages)

- (void) setupSamplerImageIndexes;

- (int) numSamplerImages;

- (NSArray *) samplerImages;
- (void) setSamplerImages: (NSArray *) newSamplerImages;

- (PPDocumentSamplerImage *) activeSamplerImageForPanelType:
                                                    (PPSamplerImagePanelType) samplerPanelType;

- (void) activateNextSamplerImageForPanelType: (PPSamplerImagePanelType) samplerPanelType;
- (void) activatePreviousSamplerImageForPanelType: (PPSamplerImagePanelType) samplerPanelType;

- (bool) hasActiveSamplerImageForPanelType: (PPSamplerImagePanelType) samplerPanelType;

- (bool) shouldEnableSamplerImagePanel;
- (void) setShouldEnableSamplerImagePanel: (bool) shouldEnableSamplerImagePanel;

@end

@interface PPDocument (NotificationOverrides)

// for better performance, operations that perform multiple quick updates to the document
// bitmaps (interactive drawing, interactive moving, opacity sliders) should disable thumbnail
// image update notifications to prevent the various thumbnail views from redrawing (each
// different size forces a resample of the entire image: SLOW) until the end of the operation
- (void) disableThumbnailImageUpdateNotifications:
                                        (bool) shouldDisableThumbnailImageUpdateNotifications;

- (void) sendThumbnailImageUpdateNotifications;

@end

extern NSString *PPDocumentNotification_UpdatedMergedVisibleArea;
extern NSString *PPDocumentNotification_UpdatedDrawingLayerArea;
extern NSString *PPDocumentNotification_UpdatedMergedVisibleThumbnailImage;
extern NSString *PPDocumentNotification_UpdatedDrawingLayerThumbnailImage;
extern NSString *PPDocumentNotification_UpdatedSelection;
extern NSString *PPDocumentNotification_SwitchedDrawingLayer;
extern NSString *PPDocumentNotification_ReorderedLayers;
extern NSString *PPDocumentNotification_PerformedMultilayerOperation;
extern NSString *PPDocumentNotification_ChangedLayerAttribute;
extern NSString *PPDocumentNotification_SwitchedLayerOperationTarget;
extern NSString *PPDocumentNotification_SwitchedLayerBlendingMode;
extern NSString *PPDocumentNotification_SwitchedSelectedTool;
extern NSString *PPDocumentNotification_SwitchedActiveTool;
extern NSString *PPDocumentNotification_ChangedFillColor;
extern NSString *PPDocumentNotification_UpdatedBackgroundSettings;
extern NSString *PPDocumentNotification_UpdatedGridSettings;
extern NSString *PPDocumentNotification_ReloadedDocument;
extern NSString *PPDocumentNotification_UpdatedSamplerImages;
extern NSString *PPDocumentNotification_SwitchedActiveSamplerImage;

extern NSString *PPDocumentNotification_UserInfoKey_UpdateAreaRect;
extern NSString *PPDocumentNotification_UserInfoKey_IndexOfChangedLayer;
extern NSString *PPDocumentNotification_UserInfoKey_SamplerImagePanelType;
