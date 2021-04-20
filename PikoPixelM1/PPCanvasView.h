/*
    PPCanvasView.h

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

#import <Cocoa/Cocoa.h>
#import "PPGridType.h"
#import "PPDocumentTypes.h"
#import "PPBitmapPixelTypes.h"


@class PPGridPattern;

@interface PPCanvasView : NSView
{
    NSBitmapImageRep *_canvasBitmap;

    float _zoomFactor;
    float _inverseZoomFactor;

    NSPoint _canvasDrawingOffset;

    NSRect _canvasFrame;
    NSRect _zoomedCanvasFrame;
    NSRect _offsetZoomedCanvasFrame;

    NSRect _clipViewVisibleRect;

    NSRect _visibleCanvasBounds;
    NSRect _zoomedVisibleCanvasBounds;
    NSRect _offsetZoomedVisibleCanvasBounds;

    NSSize _zoomedVisibleImagesSize;

    NSBitmapImageRep *_zoomedVisibleCanvasBitmap;
    NSImage *_zoomedVisibleCanvasImage;

    NSBitmapImageRep *_zoomedVisibleBackgroundBitmap;
    NSImage *_zoomedVisibleBackgroundImage;

    NSImage *_backgroundImage;
    NSColor *_backgroundColor;

#if PP_DEPLOYMENT_TARGET_SUPPORTS_RETINA_DISPLAY

    NSBitmapImageRep *_retinaDisplayBuffer;

#endif  // PP_DEPLOYMENT_TARGET_SUPPORTS_RETINA_DISPLAY

    PPGridType _gridType;
    PPImageBitmapPixel _gridColorPixelValue;
    NSSize _gridGuidelineSpacingSize;
    PPImageBitmapPixel _gridGuidelineColorPixelValue;
    NSPoint _gridGuidelinesTopLeftPhase;

    NSBezierPath *_selectionOutlineTopRightPath;
    NSBezierPath *_selectionOutlineBottomLeftPath;
    NSBezierPath *_selectionOutlineRightEdgePath;
    NSBezierPath *_selectionOutlineBottomEdgePath;

    NSBezierPath *_zoomedSelectionOutlineTopRightPath;
    NSBezierPath *_zoomedSelectionOutlineBottomLeftPath;
    NSRect _zoomedSelectionOutlineDisplayBounds;

    NSTimer *_selectionOutlineAnimationTimer;
    NSPoint _selectionOutlineTopRightAnimationPhase;
    NSPoint _selectionOutlineBottomLeftAnimationPhase;

    NSBezierPath *_selectionToolOverlayPath_Working;
    NSBezierPath *_selectionToolOverlayPath_AddFill;
    NSBezierPath *_selectionToolOverlayPath_SubtractFill;
    NSBezierPath *_selectionToolOverlayPath_ToolPath;
    NSBezierPath *_selectionToolOverlayPath_Outline;
    NSBitmapImageRep *_selectionToolOverlayWorkingMask;
    NSBitmapImageRep *_selectionToolOverlayWorkingPathMask;
    NSTimer *_selectionToolOverlayAnimationTimer;
    NSDate *_selectionToolOverlayAnimationStartDate;
    NSPoint _selectionToolOverlayAnimationPhase;
    NSRect _selectionToolOverlayDisplayBounds;

    NSBezierPath *_eraserToolOverlayPath_Outline;
    NSRect _eraserToolOverlayDisplayBounds;

    NSBezierPath *_fillToolOverlayPath_Fill;
    NSBezierPath *_fillToolOverlayPath_Outline;
    NSRect _fillToolOverlayDisplayBounds;
    NSColor *_fillToolOverlayPatternColor;
    NSPoint _fillToolOverlayPatternPhase;

    NSRect _magnifierToolOverlayRect;
    NSBezierPath *_magnifierToolOverlayRectPath;

    NSBezierPath *_colorRampToolOverlayPath_Outline;
    NSBezierPath *_colorRampToolOverlayPath_XMarks;
    NSRect _colorRampToolOverlayDisplayBounds;

    NSPoint _matchToolToleranceIndicatorOrigin;
    unsigned _matchToolToleranceIndicatorRadius;
    NSBezierPath *_matchToolToleranceIndicatorPath;
    NSRect _matchToolToleranceIndicatorDisplayBounds;

    NSCursor *_toolCursor;

    NSRect _viewBoundsTrackingRect;
    NSTrackingRectTag _viewBoundsTrackingRectTag;

    NSRect _visibleCanvasTrackingRect;
    NSTrackingRectTag _visibleCanvasTrackingRectTag;

    NSTimer *_autoscrollRepeatTimer;
    NSEvent *_autoscrollMouseDraggedEvent;

    int _zoomedImagesDrawMode;

    bool _shouldDisplayDocumentLayers;
    bool _shouldDisplayGrid;
    bool _shouldDisplayGridGuidelines;
    bool _shouldDisplayBackgroundImage;
    bool _shouldSmoothenBackgroundImage;
    bool _disallowBackgroundImageSmoothingForScrolling;
    bool _shouldDisplaySelectionToolOverlay;
    bool _shouldDisplayEraserToolOverlay;
    bool _shouldDisplayFillToolOverlay;
    bool _shouldDisplayMagnifierToolOverlay;
    bool _shouldDisplayColorRampToolOverlay;
    bool _shouldDisplayMatchToolToleranceIndicator;

    bool _backgroundImageIsOpaque;

    bool _isDraggingTool;

    bool _allowSkippingOfMouseDraggedEvents;

    bool _autoscrollingIsEnabled;
    bool _isAutoscrolling;

    bool _isScrolling;

    bool _mouseIsInsideVisibleCanvasTrackingRect;

    bool _disallowMouseTracking;

    bool _hasSelectionOutline;
    bool _shouldHideSelectionOutline;
    bool _shouldAnimateSelectionOutline;

#if PP_DEPLOYMENT_TARGET_SUPPORTS_RETINA_DISPLAY

    bool _currentDisplayIsRetina;

#endif  // PP_DEPLOYMENT_TARGET_SUPPORTS_RETINA_DISPLAY
}

- (void) setCanvasBitmap: (NSBitmapImageRep *) canvasBitmap;

- (void) setBackgroundImage: (NSImage *) backgroundImage
            backgroundImageVisibility: (bool) shouldDisplayBackgroundImage
            backgroundImageSmoothing: (bool) shouldSmoothenBackgroundImage
            backgroundColor: (NSColor *) backgroundColor;

- (void) setBackgroundImage: (NSImage *) backgroundImage;
- (void) setBackgroundImageVisibility: (bool) shouldDisplayBackgroundImage;
- (void) setBackgroundImageSmoothing: (bool) shouldSmoothenBackgroundImage;
- (void) setBackgroundColor: (NSColor *) backgroundColor;

- (void) disableBackgroundImageSmoothingForScrollingBegin;
- (void) updateBackgroundImageSmoothingForScrollingEnd;

- (void) setGridPattern: (PPGridPattern *) gridPattern
            gridVisibility: (bool) shouldDisplayGrid;

- (void) setDocumentLayersVisibility: (bool) shouldDisplayDocumentLayers;
- (bool) documentLayersAreHidden;

- (void) handleUpdateToCanvasBitmapInRect: (NSRect) updateRect;

- (NSRect) normalizedVisibleBounds;

- (NSPoint) imagePointAtCenterOfVisibleCanvas;
- (void) centerEnclosingScrollViewAtImagePoint: (NSPoint) centerPoint;

- (bool) windowPointIsInsideVisibleCanvas: (NSPoint) windowPoint;
- (NSPoint) imagePointFromViewPoint: (NSPoint) viewPoint
                clippedToCanvasBounds: (bool) shouldClipToCanvasBounds;
- (NSPoint) viewPointClippedToCanvasBounds: (NSPoint) viewPoint;

- (float) zoomFactor;
- (void) setZoomFactor: (float) zoomFactor;

- (bool) canIncreaseZoomFactor;
- (void) increaseZoomFactor;

- (bool) canDecreaseZoomFactor;
- (void) decreaseZoomFactor;

- (void) setZoomToFitCanvas;
- (void) setZoomToFitViewRect: (NSRect) rect;

- (void) setIsDraggingTool: (bool) isDraggingTool;

- (void) enableSkippingOfMouseDraggedEvents: (bool) allowSkippingOfMouseDraggedEvents;

@end

@interface PPCanvasView (SelectionOutline)

+ (void) initializeSelectionOutline;

- (bool) initSelectionOutlineMembers;
- (void) deallocSelectionOutlineMembers;

- (void) setSelectionOutlineToMask: (NSBitmapImageRep *) selectionMask
            maskBounds: (NSRect) maskBounds;

- (void) setShouldHideSelectionOutline: (bool) shouldHideSelectionOutline;
- (void) setShouldAnimateSelectionOutline: (bool) shouldAnimateSelectionOutline;

- (void) updateSelectionOutlineForCurrentVisibleCanvas;

- (void) drawSelectionOutline;

@end

@interface PPCanvasView (SelectionToolOverlay)

+ (void) initializeSelectionToolOverlay;

- (bool) initSelectionToolOverlayMembers;
- (void) deallocSelectionToolOverlayMembers;

- (bool) resizeSelectionToolOverlayMasksToSize: (NSSize) size;

- (void) setSelectionToolOverlayToRect: (NSRect) rect
            selectionMode: (PPSelectionMode) selectionMode
            intersectMask: (NSBitmapImageRep *) intersectMask
            toolPathRect: (NSRect) toolPathRect;

- (void) setSelectionToolOverlayToPath: (NSBezierPath *) path
            selectionMode: (PPSelectionMode) selectionMode
            intersectMask: (NSBitmapImageRep *) intersectMask;

- (void) setSelectionToolOverlayToMask: (NSBitmapImageRep *) maskBitmap
            maskBounds: (NSRect) maskBounds
            selectionMode: (PPSelectionMode) selectionMode
            intersectMask: (NSBitmapImageRep *) intersectMask;

- (void) clearSelectionToolOverlay;

- (void) drawSelectionToolOverlay;

@end

@interface PPCanvasView (EraserToolOverlay)

+ (void) initializeEraserToolOverlay;

- (bool) initEraserToolOverlayMembers;
- (void) deallocEraserToolOverlayMembers;

- (void) setEraserToolOverlayToMask: (NSBitmapImageRep *) maskBitmap
            maskBounds: (NSRect) maskBounds;

- (void) clearEraserToolOverlay;

- (void) drawEraserToolOverlay;

@end

@interface PPCanvasView (FillToolOverlay)

+ (void) initializeFillToolOverlay;

- (bool) initFillToolOverlayMembers;
- (void) deallocFillToolOverlayMembers;

- (void) beginFillToolOverlayForOperationTarget: (PPLayerOperationTarget) operationTarget
            fillColor: (NSColor *) flllColor;

- (void) setFillToolOverlayToMask: (NSBitmapImageRep *) maskBitmap
            maskBounds: (NSRect) maskBounds;

- (void) endFillToolOverlay;

- (void) drawFillToolOverlay;

@end

@interface PPCanvasView (MagnifierToolOverlay)

+ (void) initializeMagnifierToolOverlay;

- (bool) initMagnifierToolOverlayMembers;
- (void) deallocMagnifierToolOverlayMembers;

- (void) setMagnifierToolOverlayToViewRect: (NSRect) rect;

- (void) clearMagnifierToolOverlay;

- (void) drawMagnifierToolOverlay;

@end

@interface PPCanvasView (ColorRampToolOverlay)

+ (void) initializeColorRampToolOverlay;

- (bool) initColorRampToolOverlayMembers;
- (void) deallocColorRampToolOverlayMembers;

- (void) setColorRampToolOverlayToMask: (NSBitmapImageRep *) maskBitmap
            maskBounds: (NSRect) maskBounds;

- (void) clearColorRampToolOverlay;

- (void) drawColorRampToolOverlay;

@end

@interface PPCanvasView (MatchToolToleranceIndicator)

+ (void) initializeMatchToolToleranceIndicator;

- (bool) initMatchToolToleranceIndicatorMembers;
- (void) deallocMatchToolToleranceIndicatorMembers;

- (void) showMatchToolToleranceIndicatorAtViewPoint: (NSPoint) viewPoint;

- (void) hideMatchToolToleranceIndicator;

- (void) setMatchToolToleranceIndicatorRadius: (unsigned) radius;

- (void) drawMatchToolToleranceIndicator;

@end

@interface PPCanvasView (MouseCursor)

- (void) setToolCursor: (NSCursor *) toolCursor;

- (void) updateCursor;
- (void) updateCursorForWindowPoint: (NSPoint) windowPoint;
- (void) updateCursorForCurrentMouseLocation;

@end

@interface PPCanvasView (Autoscrolling)

- (void) enableAutoscrolling: (bool) shouldEnableAutoscrolling;

- (bool) isAutoscrolling;

- (void) autoscrollHandleMouseDraggedEvent: (NSEvent *) event;
- (void) autoscrollStop;

@end

#if PP_DEPLOYMENT_TARGET_SUPPORTS_RETINA_DISPLAY

@interface PPCanvasView (RetinaDrawing)

- (void) setupRetinaDrawingForCurrentDisplay;
- (void) setupRetinaDrawingForResizedView;
- (void) destroyRetinaDrawingMembers;

- (void) beginDrawingToRetinaDisplayBufferInRect: (NSRect) rect;
- (void) finishDrawingToRetinaDisplayBufferInRect: (NSRect) rect;

@end

#endif  // PP_DEPLOYMENT_TARGET_SUPPORTS_RETINA_DISPLAY


extern NSString *PPCanvasViewNotification_ChangedZoomFactor;
extern NSString *PPCanvasViewNotification_UpdatedNormalizedVisibleBounds;
