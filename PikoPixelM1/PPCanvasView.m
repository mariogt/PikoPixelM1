/*
    PPCanvasView.m

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

#import "PPCanvasView.h"

#import "PPCanvasView_Notifications.h"
#import "PPGridPattern.h"
#import "PPGeometry.h"
#import "NSImage_PPUtilities.h"
#import "NSBitmapImageRep_PPUtilities.h"
#import "NSColor_PPUtilities.h"
#import "PPUserDefaults.h"
#import "PPDefines.h"
#import "NSObject_PPUtilities.h"
#import "PPCursorManager.h"
#import "PPPanelsController.h"
#import "PPPopupPanelsController.h"
#import "NSWindow_PPUtilities.h"
#import "NSEvent_PPUtilities.h"
#import "PPSRGBUtilities.h"


typedef enum
{
    kPPZoomedImagesDrawMode_Normal,
    kPPZoomedImagesDrawMode_DisallowDrawing,
    kPPZoomedImagesDrawMode_ForceRedraw

} PPZoomedImagesDrawMode;


#define kTimeDelayForImageSmoothingRefreshAfterScrollingEnds        (0.25f)


static bool gRuntimeRoundsOffSubpixelMouseCoordinates = NO,
            gShouldDrawDirectlyToZoomedVisibleBackgroundImage = NO;


@interface PPCanvasView (PrivateMethods)

- (void) addAsObserverForNSWindowNotifications;
- (void) removeAsObserverForNSWindowNotifications;
- (void) handleNSWindowNotifications_DidBecomeOrResignKey: (NSNotification *) notification;

- (void) addAsObserverForNotificationsFromNSClipView: (NSClipView *) clipView;
- (void) removeAsObserverForNotificationsFromNSClipView: (NSClipView *) clipView;
- (void) handleNSClipViewNotifications_FrameOrBoundsDidChange: (NSNotification *) notification;

- (NSClipView *) enclosingClipView;
- (void) updateFrameForEnclosingClipView: (NSClipView *) clipView;

- (void) setCanvasSize: (NSSize) canvasSize;

- (void) setZoomFactor: (float) zoomFactor
            forceRedrawIfZoomFactorUnchanged: (bool) forceRedraw
            centerRedrawnImagesAtPoint: (NSPoint) centerPoint;

- (float) zoomFactorToFitCanvasSize: (NSSize) canvasSize;

- (void) repositionVisibleImages;
- (void) repositionVisibleBoundingRects;
- (void) resizeVisibleImages;

- (void) setupGridGuidelinesPhaseForVisibleCanvas;

- (void) updateVisibleCanvasInRect: (NSRect) canvasUpdateRect;
- (void) recacheZoomedVisibleCanvasImageInBounds: (NSRect) bounds;
- (void) updateVisibleBackground;

- (void) setupMouseTracking;

- (void) handleScrollingBegin;
- (void) handleScrollingEnd;

- (void) performDelayedUpdateOfBackgroundImageSmoothingForScrollingEnd;

- (void) makeWindowKeyIfMain;

@end

@implementation PPCanvasView

+ (void) load
{
    gRuntimeRoundsOffSubpixelMouseCoordinates =
        (PP_RUNTIME_CHECK__RUNTIME_ROUNDS_OFF_SUBPIXEL_MOUSE_COORDINATES) ? YES : NO;

    gShouldDrawDirectlyToZoomedVisibleBackgroundImage =
        (PP_RUNTIME_CHECK__DRAWING_TO_IMAGES_IS_FASTER_THAN_DRAWING_TO_BITMAPS) ? YES : NO;
}

+ (void) initialize
{
    if ([self class] != [PPCanvasView class])
    {
        return;
    }

    [self initializeSelectionOutline];
    [self initializeSelectionToolOverlay];
    [self initializeEraserToolOverlay];
    [self initializeFillToolOverlay];
    [self initializeMagnifierToolOverlay];
    [self initializeColorRampToolOverlay];
    [self initializeMatchToolToleranceIndicator];
}

- (id) initWithFrame: (NSRect) frame
{
    self = [super initWithFrame: frame];

    if (!self)
        goto ERROR;

    if (![self initSelectionOutlineMembers]
        || ![self initSelectionToolOverlayMembers]
        || ![self initEraserToolOverlayMembers]
        || ![self initFillToolOverlayMembers]
        || ![self initMagnifierToolOverlayMembers]
        || ![self initColorRampToolOverlayMembers]
        || ![self initMatchToolToleranceIndicatorMembers])
    {
        goto ERROR;
    }

    [self setZoomFactor: kMinCanvasZoomFactor];

    _shouldDisplayDocumentLayers = YES;

    return self;

ERROR:
    return nil;
}

- (void) dealloc
{
    [self removeAsObserverForNSWindowNotifications];
    [self removeAsObserverForNotificationsFromNSClipView: nil];

    [_canvasBitmap release];

    [_zoomedVisibleCanvasBitmap release];
    [_zoomedVisibleCanvasImage release];

    [_zoomedVisibleBackgroundBitmap release];
    [_zoomedVisibleBackgroundImage release];

    [_backgroundImage release];
    [_backgroundColor release];

#if PP_DEPLOYMENT_TARGET_SUPPORTS_RETINA_DISPLAY

    [self destroyRetinaDrawingMembers];

#endif  // PP_DEPLOYMENT_TARGET_SUPPORTS_RETINA_DISPLAY

    [self deallocSelectionOutlineMembers];
    [self deallocSelectionToolOverlayMembers];
    [self deallocEraserToolOverlayMembers];
    [self deallocFillToolOverlayMembers];
    [self deallocMagnifierToolOverlayMembers];
    [self deallocColorRampToolOverlayMembers];
    [self deallocMatchToolToleranceIndicatorMembers];

    [_toolCursor release];

    // _autoscrollRepeatTimer must be nil, otherwise this canvasView would not be deallocating,
    // because it would be retained as the timer's target

    [_autoscrollMouseDraggedEvent release];

    [super dealloc];
}

- (void) setCanvasBitmap: (NSBitmapImageRep *) canvasBitmap
{
    NSSize canvasBitmapSize;

    if (!canvasBitmap || (_canvasBitmap == canvasBitmap))
    {
        return;
    }

    [_canvasBitmap release];
    _canvasBitmap = [canvasBitmap retain];

    canvasBitmapSize = [canvasBitmap ppSizeInPixels];

    if (!NSEqualSizes(_canvasFrame.size, canvasBitmapSize))
    {
        [self setCanvasSize: canvasBitmapSize];
    }
    else
    {
        [self handleUpdateToCanvasBitmapInRect: _canvasFrame];
    }
}

- (void) setBackgroundImage: (NSImage *) backgroundImage
            backgroundImageVisibility: (bool) shouldDisplayBackgroundImage
            backgroundImageSmoothing: (bool) shouldSmoothenBackgroundImage
            backgroundColor: (NSColor *) backgroundColor
{
    bool shouldUpdateVisibleBackground = NO;

    // background image

    if (_backgroundImage != backgroundImage)
    {
        [_backgroundImage release];
        _backgroundImage = [backgroundImage retain];

        _backgroundImageIsOpaque = [_backgroundImage ppIsOpaque];

        shouldUpdateVisibleBackground = YES;
    }

    // background image visibility

    shouldDisplayBackgroundImage = (shouldDisplayBackgroundImage) ? YES : NO;

    if (_shouldDisplayBackgroundImage != shouldDisplayBackgroundImage)
    {
        _shouldDisplayBackgroundImage = shouldDisplayBackgroundImage;

        if (_backgroundImage)
        {
            shouldUpdateVisibleBackground = YES;
        }
    }

    // background image smoothing

    shouldSmoothenBackgroundImage = (shouldSmoothenBackgroundImage) ? YES : NO;

    if (_shouldSmoothenBackgroundImage != shouldSmoothenBackgroundImage)
    {
        _shouldSmoothenBackgroundImage = shouldSmoothenBackgroundImage;

        if (_backgroundImage)
        {
            shouldUpdateVisibleBackground = YES;
        }
    }

    // background color

    if (!backgroundColor)
    {
        backgroundColor = [NSColor whiteColor];
    }

    if (_backgroundColor != backgroundColor)
    {
        [_backgroundColor release];
        _backgroundColor = [backgroundColor retain];

        shouldUpdateVisibleBackground = YES;
    }

    // update visible background

    if (shouldUpdateVisibleBackground)
    {
        [self updateVisibleBackground];
    }
}

- (void) setBackgroundImage: (NSImage *) backgroundImage
{
    if (_backgroundImage == backgroundImage)
    {
        return;
    }

    [_backgroundImage release];
    _backgroundImage = [backgroundImage retain];

    _backgroundImageIsOpaque = [_backgroundImage ppIsOpaque];

    [self updateVisibleBackground];
}

- (void) setBackgroundImageVisibility: (bool) shouldDisplayBackgroundImage
{
    shouldDisplayBackgroundImage = (shouldDisplayBackgroundImage) ? YES : NO;

    if (_shouldDisplayBackgroundImage == shouldDisplayBackgroundImage)
    {
        return;
    }

    _shouldDisplayBackgroundImage = shouldDisplayBackgroundImage;

    if (_backgroundImage)
    {
        [self updateVisibleBackground];
    }
}

- (void) setBackgroundImageSmoothing: (bool) shouldSmoothenBackgroundImage
{
    shouldSmoothenBackgroundImage = (shouldSmoothenBackgroundImage) ? YES : NO;

    if (_shouldSmoothenBackgroundImage == shouldSmoothenBackgroundImage)
    {
        return;
    }

    _shouldSmoothenBackgroundImage = shouldSmoothenBackgroundImage;

    if (_backgroundImage)
    {
        [self updateVisibleBackground];
    }
}

- (void) setBackgroundColor: (NSColor *) backgroundColor
{
    if (!backgroundColor)
    {
        backgroundColor = [NSColor whiteColor];
    }

    if (_backgroundColor == backgroundColor)
    {
        return;
    }

    [_backgroundColor release];
    _backgroundColor = [backgroundColor retain];

    [self updateVisibleBackground];
}

- (void) disableBackgroundImageSmoothingForScrollingBegin
{
    _disallowBackgroundImageSmoothingForScrolling = YES;
}

- (void) updateBackgroundImageSmoothingForScrollingEnd
{
    if (_isScrolling || _isAutoscrolling || !_disallowBackgroundImageSmoothingForScrolling)
    {
        return;
    }

    _disallowBackgroundImageSmoothingForScrolling = NO;

    if (_backgroundImage && _shouldDisplayBackgroundImage && _shouldSmoothenBackgroundImage)
    {
        [self updateVisibleBackground];
    }
}

- (void) setGridPattern: (PPGridPattern *) gridPattern
            gridVisibility: (bool) shouldDisplayGrid
{
    if (!gridPattern)
    {
        gridPattern = [PPUserDefaults gridPattern];
    }

    _gridType = [gridPattern pixelGridType];
    _gridColorPixelValue = [[gridPattern pixelGridColor] ppImageBitmapPixelValue];
    _gridGuidelineSpacingSize = [gridPattern guidelineSpacingSize];
    _gridGuidelineColorPixelValue = [[gridPattern guidelineColor] ppImageBitmapPixelValue];

    _shouldDisplayGrid = (shouldDisplayGrid) ? YES : NO;
    _shouldDisplayGridGuidelines = ([gridPattern shouldDisplayGuidelines]) ? YES : NO;

    [self updateVisibleCanvasInRect: _visibleCanvasBounds];
}

- (void) setDocumentLayersVisibility: (bool) shouldDisplayDocumentLayers
{
    shouldDisplayDocumentLayers = (shouldDisplayDocumentLayers) ? YES : NO;

    if (shouldDisplayDocumentLayers == _shouldDisplayDocumentLayers)
    {
        return;
    }

    _shouldDisplayDocumentLayers = shouldDisplayDocumentLayers;

    [self updateVisibleCanvasInRect: _visibleCanvasBounds];
}

- (bool) documentLayersAreHidden
{
    return (_shouldDisplayDocumentLayers) ? NO : YES;
}

- (void) handleUpdateToCanvasBitmapInRect: (NSRect) updateRect
{
    [self updateVisibleCanvasInRect: updateRect];
}

- (NSRect) normalizedVisibleBounds
{
    NSRect visibleBounds;

    if (NSIsEmptyRect(_zoomedCanvasFrame))
    {
        goto ERROR;
    }

    visibleBounds = [[[self enclosingScrollView] contentView] bounds];
    visibleBounds = NSIntersectionRect(visibleBounds, _zoomedCanvasFrame);

    return NSMakeRect(visibleBounds.origin.x / _zoomedCanvasFrame.size.width,
                        visibleBounds.origin.y / _zoomedCanvasFrame.size.height,
                        visibleBounds.size.width / _zoomedCanvasFrame.size.width,
                        visibleBounds.size.height / _zoomedCanvasFrame.size.height);

ERROR:
    return NSZeroRect;
}

- (NSPoint) imagePointAtCenterOfVisibleCanvas
{
    NSPoint centerPoint;

    centerPoint.x = (_clipViewVisibleRect.origin.x + _clipViewVisibleRect.size.width / 2.0f
                            - _canvasDrawingOffset.x)
                        * _inverseZoomFactor;
    centerPoint.y = (_clipViewVisibleRect.origin.y + _clipViewVisibleRect.size.height / 2.0f
                            - _canvasDrawingOffset.y)
                        * _inverseZoomFactor;

    return centerPoint;
}

- (void) centerEnclosingScrollViewAtImagePoint: (NSPoint) centerPoint
{
    NSClipView *clipView;
    NSSize clipViewSize;
    NSPoint originPoint;

    clipView = [self enclosingClipView];

    if (!clipView)
        return;

    clipViewSize = [clipView bounds].size;

    originPoint.x =
        roundf(centerPoint.x * _zoomFactor + _canvasDrawingOffset.x
                - clipViewSize.width / 2.0f);

    originPoint.y =
        roundf(centerPoint.y * _zoomFactor + _canvasDrawingOffset.y
                - clipViewSize.height / 2.0f);

    [self scrollPoint: originPoint];

    // NSView's scrollPoint: method can set the cursor to an arrow, so restore it if necessary
    [[PPCursorManager sharedManager] refreshCursorIfNeeded];
}

- (bool) windowPointIsInsideVisibleCanvas: (NSPoint) windowPoint
{
    NSPoint viewPoint = [self convertPoint: windowPoint fromView: nil];
    bool viewPointIsInsideVisibleCanvasRect =
                (NSPointInRect(viewPoint, _visibleCanvasTrackingRect)) ? YES : NO;

    // On OS X versions that round off mouse coordinates (10.7 & earlier), points touching the
    // edge of the tracking rect can end up on the wrong side after rounding, causing the
    // wrong cursor to be set, so if the point touches the tracking rect's edge, use the latest
    // tracking state (_mouseIsInsideVisibleCanvasTrackingRect) instead of the coordinate
    // check (NSPointInRect())

    if (gRuntimeRoundsOffSubpixelMouseCoordinates
        && (viewPointIsInsideVisibleCanvasRect != _mouseIsInsideVisibleCanvasTrackingRect)
        && PPGeometry_PointTouchesEdgePixelOfRect(viewPoint, _visibleCanvasTrackingRect))
    {
        viewPointIsInsideVisibleCanvasRect = _mouseIsInsideVisibleCanvasTrackingRect;
    }

    return viewPointIsInsideVisibleCanvasRect;
}

- (NSPoint) imagePointFromViewPoint: (NSPoint) viewPoint
                clippedToCanvasBounds: (bool) shouldClipToCanvasBounds;
{
    NSPoint imagePoint;

    imagePoint.x = floorf((viewPoint.x - _canvasDrawingOffset.x) * _inverseZoomFactor);
    imagePoint.y = floorf((viewPoint.y - _canvasDrawingOffset.y) * _inverseZoomFactor);

    if (shouldClipToCanvasBounds)
    {
        imagePoint = PPGeometry_PointClippedToRect(imagePoint, _canvasFrame);
    }

    return imagePoint;
}

- (NSPoint) viewPointClippedToCanvasBounds: (NSPoint) viewPoint
{
    return PPGeometry_PointClippedToRect(viewPoint, _offsetZoomedCanvasFrame);
}

- (float) zoomFactor
{
    return _zoomFactor;
}

- (void) setZoomFactor: (float) zoomFactor
{
    if (_isDraggingTool)
        return;

    [self setZoomFactor: zoomFactor
            forceRedrawIfZoomFactorUnchanged: NO
            centerRedrawnImagesAtPoint: [self imagePointAtCenterOfVisibleCanvas]];
}

- (bool) canIncreaseZoomFactor
{
    return (_zoomFactor < kMaxCanvasZoomFactor) ? YES : NO;
}

- (void) increaseZoomFactor
{
    [self setZoomFactor: _zoomFactor + 1.0f];
}

- (bool) canDecreaseZoomFactor
{
    return (_zoomFactor > kMinCanvasZoomFactor) ? YES : NO;
}

- (void) decreaseZoomFactor
{
    [self setZoomFactor: _zoomFactor - 1.0f];
}

- (void) setZoomToFitCanvas
{
    [self setZoomFactor: [self zoomFactorToFitCanvasSize: _canvasFrame.size]];
}

- (void) setZoomToFitViewRect: (NSRect) rect
{
    NSSize viewSize;
    NSPoint imageCenterPoint;
    float zoomFactor;

    rect = NSIntersectionRect(rect, _offsetZoomedCanvasFrame);

    if (NSIsEmptyRect(rect))
    {
        return;
    }

    viewSize = _clipViewVisibleRect.size;

    if (PPGeometry_IsZeroSize(viewSize))
    {
        return;
    }

    imageCenterPoint = [self imagePointFromViewPoint:
                                        NSMakePoint(rect.origin.x + rect.size.width / 2.0f,
                                                    rect.origin.y + rect.size.height / 2.0f)
                                clippedToCanvasBounds: YES];

    zoomFactor =
            floorf(MIN(viewSize.width / rect.size.width, viewSize.height / rect.size.height)
                    * _zoomFactor);

    [self setZoomFactor: zoomFactor
            forceRedrawIfZoomFactorUnchanged: YES
            centerRedrawnImagesAtPoint: imageCenterPoint];
}

- (void) setIsDraggingTool: (bool) isDraggingTool
{
    _isDraggingTool = (isDraggingTool) ? YES : NO;

    [self updateCursor];
}

- (void) enableSkippingOfMouseDraggedEvents: (bool) allowSkippingOfMouseDraggedEvents
{
    _allowSkippingOfMouseDraggedEvents = (allowSkippingOfMouseDraggedEvents) ? YES : NO;
}

#pragma mark NSView overrides

- (void) viewDidMoveToWindow
{
    [super viewDidMoveToWindow];

    [[self window] ppSetSRGBColorSpace];

    [self addAsObserverForNSWindowNotifications];
}

- (void) viewDidMoveToSuperview
{
    NSClipView *enclosingClipView;

    [super viewDidMoveToSuperview];

    enclosingClipView = [self enclosingClipView];

    [self updateFrameForEnclosingClipView: enclosingClipView];

    [self addAsObserverForNotificationsFromNSClipView: enclosingClipView];

#if PP_DEPLOYMENT_TARGET_SUPPORTS_RETINA_DISPLAY

    [self ppPerformSelectorAtomicallyFromNewStackFrame:
                                            @selector(setupRetinaDrawingForCurrentDisplay)];

#endif  // PP_DEPLOYMENT_TARGET_SUPPORTS_RETINA_DISPLAY
}

- (void) removeFromSuperview
{
    [self removeAsObserverForNotificationsFromNSClipView: nil];

    [super removeFromSuperview];
}

- (void) drawRect: (NSRect) rect
{
    NSRect sourceRect;

    if (_zoomedImagesDrawMode == kPPZoomedImagesDrawMode_DisallowDrawing)
    {
        return;
    }

    rect = NSIntersectionRect(rect, _offsetZoomedVisibleCanvasBounds);

    if (NSIsEmptyRect(rect))
    {
        return;
    }

#if PP_DEPLOYMENT_TARGET_SUPPORTS_RETINA_DISPLAY

    if (_retinaDisplayBuffer)
    {
        [self beginDrawingToRetinaDisplayBufferInRect: rect];
    }

#endif  // PP_DEPLOYMENT_TARGET_SUPPORTS_RETINA_DISPLAY

    [[NSGraphicsContext currentContext] setImageInterpolation: NSImageInterpolationNone];

    sourceRect.origin = NSMakePoint(rect.origin.x - _offsetZoomedVisibleCanvasBounds.origin.x,
                                    rect.origin.y - _offsetZoomedVisibleCanvasBounds.origin.y);
    sourceRect.size = rect.size;

    [_zoomedVisibleBackgroundImage drawInRect: rect
                                    fromRect: sourceRect
                                    operation: NSCompositeCopy
                                    fraction: 1.0f];

    if (_shouldDisplayDocumentLayers)
    {
        [_zoomedVisibleCanvasImage drawInRect: rect
                                    fromRect: sourceRect
                                    operation: NSCompositeSourceOver
                                    fraction: 1.0f];
    }

    // Tool overlays drawn underneath selection outline

    if (_shouldDisplaySelectionToolOverlay)
    {
        [self drawSelectionToolOverlay];
    }

    if (_shouldDisplayEraserToolOverlay)
    {
        [self drawEraserToolOverlay];
    }

    // Selection outline

    if (_hasSelectionOutline && !_shouldHideSelectionOutline)
    {
        [self drawSelectionOutline];
    }

    // Tool overlays drawn over selection outline

    if (_shouldDisplayFillToolOverlay)
    {
        [self drawFillToolOverlay];
    }

    if (_shouldDisplayMagnifierToolOverlay)
    {
        [self drawMagnifierToolOverlay];
    }

    if (_shouldDisplayColorRampToolOverlay)
    {
        [self drawColorRampToolOverlay];
    }

#if PP_DEPLOYMENT_TARGET_SUPPORTS_RETINA_DISPLAY

    if (_retinaDisplayBuffer)
    {
        [self finishDrawingToRetinaDisplayBufferInRect: rect];
    }

    // the retina display buffer clips drawing to rect, so don't draw the match tool tolerance
    // indicator (which can draw outside rect bounds) until after retina display buffer drawing
    // is finished

#endif  // PP_DEPLOYMENT_TARGET_SUPPORTS_RETINA_DISPLAY

    if (_shouldDisplayMatchToolToleranceIndicator)
    {
        [self drawMatchToolToleranceIndicator];
    }
}

- (void) mouseDragged: (NSEvent *) theEvent
{
    if (_allowSkippingOfMouseDraggedEvents && !_isAutoscrolling)
    {
        // skipping to the latest mouseDragged event can save unnecessary redrawing during drag
        theEvent = [theEvent ppLatestMouseDraggedEventFromEventQueue];
    }

    if (_autoscrollingIsEnabled)
    {
        [self autoscrollHandleMouseDraggedEvent: theEvent];
    }

    [super mouseDragged: theEvent];
}

- (void) mouseUp: (NSEvent *) theEvent
{
    _isDraggingTool = NO;

    if (_autoscrollingIsEnabled)
    {
        [self autoscrollStop];
    }

    [self updateCursorForWindowPoint: [theEvent locationInWindow]];

    [super mouseUp: theEvent];
}

- (void) mouseEntered: (NSEvent *) theEvent
{
    NSTrackingRectTag trackingRectTag = [theEvent trackingNumber];

    if (trackingRectTag == _viewBoundsTrackingRectTag)
    {
        [self makeWindowKeyIfMain];
    }
    else if (trackingRectTag == _visibleCanvasTrackingRectTag)
    {
        if (!_mouseIsInsideVisibleCanvasTrackingRect)
        {
            _mouseIsInsideVisibleCanvasTrackingRect = YES;
            [self updateCursor];
        }
    }
    else
    {
        [super mouseEntered: theEvent];
    }
}

- (void) mouseExited: (NSEvent *) theEvent
{
    NSTrackingRectTag trackingRectTag = [theEvent trackingNumber];

    if (trackingRectTag == _visibleCanvasTrackingRectTag)
    {
        if (_mouseIsInsideVisibleCanvasTrackingRect)
        {
            _mouseIsInsideVisibleCanvasTrackingRect = NO;
            [self updateCursor];
        }
    }
    else
    {
        [super mouseExited: theEvent];
    }
}

- (void) scrollWheel: (NSEvent *) theEvent
{
    if (_isDraggingTool)
        return;

    [super scrollWheel: theEvent];
}

- (void) cursorUpdate: (NSEvent *) event
{
    [[PPCursorManager sharedManager] refreshCursorIfNeeded];
}

#pragma mark NSWindow notifications

- (void) addAsObserverForNSWindowNotifications
{
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    NSWindow *parentWindow = [self window];

    [self removeAsObserverForNSWindowNotifications];

    if (!parentWindow)
        return;

    [notificationCenter addObserver: self
                        selector: @selector(handleNSWindowNotifications_DidBecomeOrResignKey:)
                        name: NSWindowDidBecomeKeyNotification
                        object: parentWindow];

    [notificationCenter addObserver: self
                        selector: @selector(handleNSWindowNotifications_DidBecomeOrResignKey:)
                        name: NSWindowDidResignKeyNotification
                        object: parentWindow];
}

- (void) removeAsObserverForNSWindowNotifications
{
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];

    [notificationCenter removeObserver: self
                        name: NSWindowDidBecomeKeyNotification
                        object: nil];

    [notificationCenter removeObserver: self
                        name: NSWindowDidResignKeyNotification
                        object: nil];
}

- (void) handleNSWindowNotifications_DidBecomeOrResignKey: (NSNotification *) notification
{
    [self setupMouseTracking];
}

#pragma mark NSClipView notifications

- (void) addAsObserverForNotificationsFromNSClipView: (NSClipView *) clipView
{
    NSNotificationCenter *notificationCenter;

    [self removeAsObserverForNotificationsFromNSClipView: nil];

    if (!clipView)
        return;

    notificationCenter = [NSNotificationCenter defaultCenter];

    [notificationCenter addObserver: self
                        selector:
                            @selector(handleNSClipViewNotifications_FrameOrBoundsDidChange:)
                        name: NSViewFrameDidChangeNotification
                        object: clipView];

    [notificationCenter addObserver: self
                        selector:
                            @selector(handleNSClipViewNotifications_FrameOrBoundsDidChange:)
                        name: NSViewBoundsDidChangeNotification
                        object: clipView];

    [clipView setPostsBoundsChangedNotifications: YES];
}

- (void) removeAsObserverForNotificationsFromNSClipView: (NSClipView *) clipView
{
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];

    [notificationCenter removeObserver: self
                        name: NSViewFrameDidChangeNotification
                        object: clipView];

    [notificationCenter removeObserver: self
                        name: NSViewBoundsDidChangeNotification
                        object: clipView];
}

- (void) handleNSClipViewNotifications_FrameOrBoundsDidChange: (NSNotification *) notification
{
    NSClipView *enclosingClipView = [self enclosingClipView];

    _clipViewVisibleRect =
                (enclosingClipView) ? [enclosingClipView documentVisibleRect] : NSZeroRect;

    [self handleScrollingBegin];

    [self updateFrameForEnclosingClipView: enclosingClipView];

    [self repositionVisibleImages];

    [self setupMouseTracking];

    [self ppPerformSelectorAtomicallyFromNewStackFrame: @selector(handleScrollingEnd)];

    [self postNotification_UpdatedNormalizedVisibleBounds];
}

#pragma mark Private methods

- (NSClipView *) enclosingClipView
{
    NSClipView *enclosingClipView = (NSClipView *) [self superview];

    if (![enclosingClipView isKindOfClass: [NSClipView class]])
    {
        return nil;
    }

    return enclosingClipView;
}

- (void) updateFrameForEnclosingClipView: (NSClipView *) clipView
{
    NSSize clipViewSize;
    NSRect newFrame;

    clipViewSize = (clipView) ? [clipView bounds].size : NSZeroSize;

    newFrame.origin = NSZeroPoint;

    if (clipViewSize.width > _zoomedCanvasFrame.size.width)
    {
        _canvasDrawingOffset.x =
            roundf((clipViewSize.width - _zoomedCanvasFrame.size.width) / 2.0f);

        newFrame.size.width = clipViewSize.width;
    }
    else
    {
        _canvasDrawingOffset.x = 0.0f;
        newFrame.size.width = _zoomedCanvasFrame.size.width;
    }

    if (clipViewSize.height > _zoomedCanvasFrame.size.height)
    {
        _canvasDrawingOffset.y =
            roundf((clipViewSize.height - _zoomedCanvasFrame.size.height) / 2.0f);

        newFrame.size.height = clipViewSize.height;
    }
    else
    {
        _canvasDrawingOffset.y = 0.0f;
        newFrame.size.height = _zoomedCanvasFrame.size.height;
    }

    _offsetZoomedCanvasFrame.origin = _canvasDrawingOffset;

    if (!NSEqualRects([self frame], newFrame))
    {
        [self setFrame: newFrame];

        _clipViewVisibleRect = (clipView) ? [clipView documentVisibleRect] : NSZeroRect;
    }

    [self setNeedsDisplay: YES];
}

- (void) setCanvasSize: (NSSize) canvasSize
{
    canvasSize = PPGeometry_SizeClippedToIntegerValues(canvasSize);

    if (NSEqualSizes(_canvasFrame.size, canvasSize)
        || PPGeometry_IsZeroSize(canvasSize))
    {
        goto ERROR;
    }

    if (![self resizeSelectionToolOverlayMasksToSize: canvasSize])
    {
        goto ERROR;
    }

    _canvasFrame.size = canvasSize;

    [self setZoomFactor: [self zoomFactorToFitCanvasSize: canvasSize]
            forceRedrawIfZoomFactorUnchanged: YES
            centerRedrawnImagesAtPoint: PPGeometry_CenterOfRect(_canvasFrame)];

    return;

ERROR:
    return;
}

- (void) setZoomFactor: (float) zoomFactor
            forceRedrawIfZoomFactorUnchanged: (bool) forceRedraw
            centerRedrawnImagesAtPoint: (NSPoint) centerPoint
{
    if (_isDraggingTool)
        return;

    zoomFactor = roundf(zoomFactor);

    if (zoomFactor < kMinCanvasZoomFactor)
    {
        zoomFactor = kMinCanvasZoomFactor;
    }
    else if (zoomFactor > kMaxCanvasZoomFactor)
    {
        zoomFactor = kMaxCanvasZoomFactor;
    }

    if ((zoomFactor == _zoomFactor)
        && !forceRedraw)
    {
        return;
    }

    _zoomFactor = zoomFactor;
    _inverseZoomFactor = 1.0f / zoomFactor;

    _zoomedCanvasFrame.size =
        PPGeometry_SizeScaledByFactorAndRoundedToIntegerValues(_canvasFrame.size, _zoomFactor);

    _offsetZoomedCanvasFrame = _zoomedCanvasFrame;  // offset origin set in updateFrame...

    // changing the frame & scroll position can cause the zoomed images to unnecessarily redraw
    // several times due to setFrame: & scrollPoint: sending clipview frame/bounds-change
    // notifications & scrollPoint: sometimes calling drawRect: directly), so disallow drawing
    // zoomed images (the bitmaps themselves, as well as to the screen while the bitmaps are
    // out-of-date) until after both changes are made, then force a single redraw

    _zoomedImagesDrawMode = kPPZoomedImagesDrawMode_DisallowDrawing;

    [self updateFrameForEnclosingClipView: [self enclosingClipView]];

    [self centerEnclosingScrollViewAtImagePoint: centerPoint];

    _zoomedImagesDrawMode = kPPZoomedImagesDrawMode_ForceRedraw;

    [self repositionVisibleImages];

    _zoomedImagesDrawMode = kPPZoomedImagesDrawMode_Normal;

    [self setupMouseTracking];

    [self postNotification_ChangedZoomFactor];
}

- (float) zoomFactorToFitCanvasSize: (NSSize) canvasSize
{
    NSRect viewFrame;
    float horizontalFactor, verticalFactor, zoomFactor;

    viewFrame = [[self enclosingScrollView] frame];

    horizontalFactor = viewFrame.size.width / canvasSize.width;
    verticalFactor = viewFrame.size.height / canvasSize.height;

    zoomFactor = (horizontalFactor < verticalFactor) ? horizontalFactor : verticalFactor;
    zoomFactor = floorf(zoomFactor);

    if (zoomFactor < kMinCanvasZoomFactor)
    {
        zoomFactor = kMinCanvasZoomFactor;
    }
    else if (zoomFactor > kMaxCanvasZoomFactor)
    {
        zoomFactor = kMaxCanvasZoomFactor;
    }

    return zoomFactor;
}

- (void) repositionVisibleImages
{
    NSRect oldZoomedVisibleCanvasBounds, oldOffsetZoomedVisibleCanvasBounds;
    bool didChangeVisibleCanvasBounds, didChangeCanvasDrawingOffset, needToUpdateVisibleImages,
            needToResizeVisibleImages, needToRepositionSelectionOutline;

    oldZoomedVisibleCanvasBounds = _zoomedVisibleCanvasBounds;
    oldOffsetZoomedVisibleCanvasBounds = _offsetZoomedVisibleCanvasBounds;

    [self repositionVisibleBoundingRects];

    if (_zoomedImagesDrawMode == kPPZoomedImagesDrawMode_DisallowDrawing)
    {
        return;
    }

    needToUpdateVisibleImages = needToResizeVisibleImages = NO;
    needToRepositionSelectionOutline = NO;

    didChangeVisibleCanvasBounds = !NSEqualRects(_zoomedVisibleCanvasBounds,
                                                    oldZoomedVisibleCanvasBounds);

    didChangeCanvasDrawingOffset = !NSEqualPoints(_offsetZoomedVisibleCanvasBounds.origin,
                                                    oldOffsetZoomedVisibleCanvasBounds.origin);

    if (didChangeVisibleCanvasBounds
        || (_zoomedImagesDrawMode == kPPZoomedImagesDrawMode_ForceRedraw))
    {
        needToUpdateVisibleImages = YES;
        needToRepositionSelectionOutline = YES;

        if ((_zoomedVisibleCanvasBounds.size.width > _zoomedVisibleImagesSize.width)
            || (_zoomedVisibleCanvasBounds.size.height > _zoomedVisibleImagesSize.height))
        {
            needToResizeVisibleImages = YES;
        }
    }
    else if (didChangeCanvasDrawingOffset)
    {
        needToRepositionSelectionOutline = YES;
    }

    if (needToResizeVisibleImages)
    {
        [self resizeVisibleImages];
    }

    if (needToUpdateVisibleImages)
    {
        [self setupGridGuidelinesPhaseForVisibleCanvas];

        [self updateVisibleBackground];

        [self updateVisibleCanvasInRect: _visibleCanvasBounds];
    }

    if (needToRepositionSelectionOutline && _hasSelectionOutline)
    {
        [self updateSelectionOutlineForCurrentVisibleCanvas];
    }
}

- (void) repositionVisibleBoundingRects
{
    _visibleCanvasBounds.origin =
                        NSMakePoint(floorf(NSMinX(_clipViewVisibleRect) * _inverseZoomFactor),
                                    floorf(NSMinY(_clipViewVisibleRect) * _inverseZoomFactor));

    _visibleCanvasBounds.size =
                        NSMakeSize(ceilf(NSMaxX(_clipViewVisibleRect) * _inverseZoomFactor)
                                                - _visibleCanvasBounds.origin.x,
                                    ceilf(NSMaxY(_clipViewVisibleRect) * _inverseZoomFactor)
                                                - _visibleCanvasBounds.origin.y);

    _visibleCanvasBounds = NSIntersectionRect(_visibleCanvasBounds, _canvasFrame);

    _zoomedVisibleCanvasBounds =
                            PPGeometry_RectScaledByFactor(_visibleCanvasBounds, _zoomFactor);

    _offsetZoomedVisibleCanvasBounds.size = _zoomedVisibleCanvasBounds.size;
    _offsetZoomedVisibleCanvasBounds.origin =
                PPGeometry_PointSum(_zoomedVisibleCanvasBounds.origin, _canvasDrawingOffset);
}

- (void) resizeVisibleImages
{
    _zoomedVisibleImagesSize = _zoomedVisibleCanvasBounds.size;

    [_zoomedVisibleCanvasBitmap release];
    _zoomedVisibleCanvasBitmap =
                [[NSBitmapImageRep ppImageBitmapOfSize: _zoomedVisibleImagesSize] retain];

    [_zoomedVisibleCanvasImage release];
    _zoomedVisibleCanvasImage =
                [[NSImage ppImageWithBitmap: _zoomedVisibleCanvasBitmap] retain];

    if (gShouldDrawDirectlyToZoomedVisibleBackgroundImage)
    {
        [_zoomedVisibleBackgroundImage release];
        _zoomedVisibleBackgroundImage = [[NSImage alloc] initWithSize: _zoomedVisibleImagesSize];
    }
    else
    {
        [_zoomedVisibleBackgroundBitmap release];
        _zoomedVisibleBackgroundBitmap =
                    [[NSBitmapImageRep ppImageBitmapOfSize: _zoomedVisibleImagesSize] retain];

        [_zoomedVisibleBackgroundImage release];
        _zoomedVisibleBackgroundImage =
                    [[NSImage ppImageWithBitmap: _zoomedVisibleBackgroundBitmap] retain];
    }


#if PP_DEPLOYMENT_TARGET_SUPPORTS_RETINA_DISPLAY

    if (_currentDisplayIsRetina)
    {
        [self setupRetinaDrawingForResizedView];
    }

#endif  // PP_DEPLOYMENT_TARGET_SUPPORTS_RETINA_DISPLAY
}

- (void) setupGridGuidelinesPhaseForVisibleCanvas
{
    // _zoomedVisibleImagesSize is the bitmap's actual size, not _zoomedVisibleCanvasBounds.size

    _gridGuidelinesTopLeftPhase = NSMakePoint(_zoomedVisibleCanvasBounds.origin.x,
                                                _zoomedCanvasFrame.size.height
                                                    - (_zoomedVisibleCanvasBounds.origin.y
                                                        + _zoomedVisibleImagesSize.height));
}

- (void) updateVisibleCanvasInRect: (NSRect) canvasUpdateRect
{
    NSRect zoomedUpdateRect;

    canvasUpdateRect = NSIntersectionRect(canvasUpdateRect, _visibleCanvasBounds);

    if (NSIsEmptyRect(canvasUpdateRect))
    {
        return;
    }

    zoomedUpdateRect.origin = NSMakePoint(canvasUpdateRect.origin.x * _zoomFactor
                                                - _zoomedVisibleCanvasBounds.origin.x,
                                            canvasUpdateRect.origin.y * _zoomFactor
                                                - _zoomedVisibleCanvasBounds.origin.y);
    zoomedUpdateRect.size = NSMakeSize(canvasUpdateRect.size.width * _zoomFactor,
                                        canvasUpdateRect.size.height * _zoomFactor);

    if (_shouldDisplayGrid)
    {
        [_zoomedVisibleCanvasBitmap ppScaledCopyFromImageBitmap: _canvasBitmap
                                        inRect: canvasUpdateRect
                                        toPoint: zoomedUpdateRect.origin
                                        scalingFactor: _zoomFactor
                                        gridType: _gridType
                                        gridPixelValue: _gridColorPixelValue];

        if (_shouldDisplayGridGuidelines)
        {
            [_zoomedVisibleCanvasBitmap ppDrawImageGuidelinesInBounds: zoomedUpdateRect
                                            topLeftPhase: _gridGuidelinesTopLeftPhase
                                            unscaledSpacingSize: _gridGuidelineSpacingSize
                                            scalingFactor: _zoomFactor
                                            guidelinePixelValue: _gridGuidelineColorPixelValue];
        }
    }
    else
    {
        [_zoomedVisibleCanvasBitmap ppScaledCopyFromImageBitmap: _canvasBitmap
                                        inRect: canvasUpdateRect
                                        toPoint: zoomedUpdateRect.origin
                                        scalingFactor: _zoomFactor];
    }

    [self recacheZoomedVisibleCanvasImageInBounds: zoomedUpdateRect];

    zoomedUpdateRect.origin =
        PPGeometry_PointSum(zoomedUpdateRect.origin, _offsetZoomedVisibleCanvasBounds.origin);

    [self setNeedsDisplayInRect: zoomedUpdateRect];
}

// recacheZoomedVisibleCanvasImageInBounds: method is a patch target on GNUstep
// (PPGNUstepGlue_ImageRecacheSpeedups)

- (void) recacheZoomedVisibleCanvasImageInBounds: (NSRect) bounds
{
    [_zoomedVisibleCanvasImage recache];
}

- (void) updateVisibleBackground
{
    NSImageInterpolation imageInterpolation;

    if (gShouldDrawDirectlyToZoomedVisibleBackgroundImage)
    {
        [_zoomedVisibleBackgroundImage lockFocus];
    }
    else
    {
        [_zoomedVisibleBackgroundBitmap ppSetAsCurrentGraphicsContext];
    }

    [[NSGraphicsContext currentContext] setPatternPhase:
                                            NSMakePoint(-_zoomedVisibleCanvasBounds.origin.x,
                                                        -_zoomedVisibleCanvasBounds.origin.y)];

    [_backgroundColor set];
    NSRectFill(PPGeometry_OriginRectOfSize(_zoomedVisibleCanvasBounds.size));

    if (_shouldDisplayBackgroundImage && _backgroundImage)
    {
        NSRect imageFrame, zoomedImageBounds;
        NSCompositingOperation compositingOperation;

        imageFrame = PPGeometry_OriginRectOfSize([_backgroundImage size]);

        zoomedImageBounds =
            PPGeometry_ScaledBoundsForFrameOfSizeToFitFrameOfSize(imageFrame.size,
                                                                    _zoomedCanvasFrame.size);

        imageInterpolation =
            (_shouldSmoothenBackgroundImage && !_disallowBackgroundImageSmoothingForScrolling) ?
                    NSImageInterpolationLow : NSImageInterpolationNone;

        [[NSGraphicsContext currentContext] setImageInterpolation: imageInterpolation];

        zoomedImageBounds.origin.x -= _zoomedVisibleCanvasBounds.origin.x;
        zoomedImageBounds.origin.y -= _zoomedVisibleCanvasBounds.origin.y;

        compositingOperation =
                        (_backgroundImageIsOpaque) ? NSCompositeCopy : NSCompositeSourceOver;

        [_backgroundImage drawInRect: zoomedImageBounds
                            fromRect: imageFrame
                            operation: compositingOperation
                            fraction: 1.0f];
    }

    if (gShouldDrawDirectlyToZoomedVisibleBackgroundImage)
    {
        [_zoomedVisibleBackgroundImage unlockFocus];
    }
    else
    {
        [_zoomedVisibleBackgroundBitmap ppRestoreGraphicsContext];
        [_zoomedVisibleBackgroundImage recache];
    }

    [self setNeedsDisplayInRect: _offsetZoomedVisibleCanvasBounds];
}

- (void) setupMouseTracking
{
    NSRect newViewBoundsTrackingRect = NSZeroRect, newVisibleCanvasTrackingRect = NSZeroRect;
    bool mouseIsInsideNewViewBoundsTrackingRect = NO,
            mouseIsInsideNewVisibleCanvasTrackingRect = NO;

    if ([[self window] isKeyWindow])
    {
        NSPoint mouseLocationInView;
        bool mouseIsInsideVisiblePopupOrPanel = NO;

        mouseLocationInView =
            [self convertPoint: [[self window] mouseLocationOutsideOfEventStream] fromView: nil];

        newViewBoundsTrackingRect = _clipViewVisibleRect;

        if (!NSIsEmptyRect(newViewBoundsTrackingRect))
        {
            if (NSPointInRect(mouseLocationInView, newViewBoundsTrackingRect))
            {
                if (![[PPPopupPanelsController sharedController] mouseIsInsideActivePopupPanel]
                    && ![[PPPanelsController sharedController] mouseIsInsideVisiblePanel])
                {
                    mouseIsInsideNewViewBoundsTrackingRect = YES;
                }
                else    // mouse is inside active popup or visible panel
                {
                    mouseIsInsideVisiblePopupOrPanel = YES;
                }
            }
        }

        newVisibleCanvasTrackingRect =
                    NSIntersectionRect(_offsetZoomedVisibleCanvasBounds, _clipViewVisibleRect);

        if (!NSIsEmptyRect(newVisibleCanvasTrackingRect) && !mouseIsInsideVisiblePopupOrPanel)
        {
            mouseIsInsideNewVisibleCanvasTrackingRect =
                (NSPointInRect(mouseLocationInView, newVisibleCanvasTrackingRect)) ? YES : NO;

            // On OS X versions that round off mouse coordinates (10.7 & earlier), treat points
            // touching the edge of the tracking rect as inside it - this prevents setting the
            // incorrect cursor for rounded-off points that are actually inside the canvas

            if (!mouseIsInsideNewVisibleCanvasTrackingRect
                && gRuntimeRoundsOffSubpixelMouseCoordinates
                && PPGeometry_PointTouchesEdgePixelOfRect(mouseLocationInView,
                                                            newVisibleCanvasTrackingRect))
            {
                mouseIsInsideNewVisibleCanvasTrackingRect = YES;
            }
        }
    }

    if (!NSEqualRects(newViewBoundsTrackingRect, _viewBoundsTrackingRect))
    {
        if (_viewBoundsTrackingRectTag)
        {
            [self removeTrackingRect: _viewBoundsTrackingRectTag];
            _viewBoundsTrackingRectTag = 0;

            _viewBoundsTrackingRect = NSZeroRect;
        }

        if (!NSIsEmptyRect(newViewBoundsTrackingRect))
        {
            _viewBoundsTrackingRectTag =
                                [self addTrackingRect: newViewBoundsTrackingRect
                                        owner: self
                                        userData: NULL
                                        assumeInside: mouseIsInsideNewViewBoundsTrackingRect];

            if (_viewBoundsTrackingRectTag)
            {
                _viewBoundsTrackingRect = newViewBoundsTrackingRect;
            }
        }
    }

    if (!NSEqualRects(newVisibleCanvasTrackingRect, _visibleCanvasTrackingRect))
    {
        if (_visibleCanvasTrackingRectTag)
        {
            [self removeTrackingRect: _visibleCanvasTrackingRectTag];
            _visibleCanvasTrackingRectTag = 0;

            _visibleCanvasTrackingRect = NSZeroRect;
        }

        if (!NSIsEmptyRect(newVisibleCanvasTrackingRect))
        {
            _visibleCanvasTrackingRectTag =
                            [self addTrackingRect: newVisibleCanvasTrackingRect
                                    owner: self
                                    userData: NULL
                                    assumeInside: mouseIsInsideNewVisibleCanvasTrackingRect];

            if (_visibleCanvasTrackingRectTag)
            {
                _visibleCanvasTrackingRect = newVisibleCanvasTrackingRect;
            }
            else
            {
                mouseIsInsideNewVisibleCanvasTrackingRect = NO;
            }
        }
    }

    if (_mouseIsInsideVisibleCanvasTrackingRect != mouseIsInsideNewVisibleCanvasTrackingRect)
    {
        _mouseIsInsideVisibleCanvasTrackingRect = mouseIsInsideNewVisibleCanvasTrackingRect;

        [self updateCursor];
    }
}

- (void) handleScrollingBegin
{
    if (_isScrolling)
        return;

    _isScrolling = YES;

    [self updateCursor];

    [self disableBackgroundImageSmoothingForScrollingBegin];
}

- (void) handleScrollingEnd
{
    _isScrolling = NO;

    [self updateCursorForCurrentMouseLocation];

    [self performDelayedUpdateOfBackgroundImageSmoothingForScrollingEnd];
}

- (void) performDelayedUpdateOfBackgroundImageSmoothingForScrollingEnd
{
    [[self class] cancelPreviousPerformRequestsWithTarget: self
                    selector: @selector(updateBackgroundImageSmoothingForScrollingEnd)
                    object: nil];

    [self performSelector: @selector(updateBackgroundImageSmoothingForScrollingEnd)
            withObject: nil
            afterDelay: kTimeDelayForImageSmoothingRefreshAfterScrollingEnds];
}

- (void) makeWindowKeyIfMain
{
    [[self window] ppMakeKeyWindowIfMain];
}

@end
