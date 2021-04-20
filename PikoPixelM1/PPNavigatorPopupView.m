/*
    PPNavigatorPopupView.m

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

#import "PPNavigatorPopupView.h"

#import "PPCanvasView.h"
#import "NSObject_PPUtilities.h"
#import "PPCursorManager.h"
#import "PPGeometry.h"
#import "NSEvent_PPUtilities.h"


#define kUIColor_VisibleCanvasFrame                     [NSColor redColor]

#define kVisibleCanvasFrameLineWidth                    2


static NSColor *gVisibleCanvasFrameColor = nil;


@interface PPNavigatorPopupView (PrivateMethods)

- (void) addAsObserverForPPCanvasViewNotifications;
- (void) removeAsObserverForPPCanvasViewNotifications;
- (void) handlePPCanvasViewNotification_UpdatedNormalizedVisibleBounds:
                                                                (NSNotification *) notification;

- (void) setupVisibleCanvasBoundsAndTrackingRectForWindowVisibility;

- (void) setupVisibleCanvasBounds;

- (void) setupMouseTracking;
- (void) setupViewBoundsTrackingRect;
- (void) setupVisibleCanvasBoundsTrackingRect;

- (void) setMouseIsDraggingVisibleBounds: (bool) mouseIsDraggingVisibleBounds;

- (void) updateCursor;

@end

@implementation PPNavigatorPopupView

+ (void) initialize
{
    if ([self class] != [PPNavigatorPopupView class])
    {
        return;
    }

    gVisibleCanvasFrameColor = [kUIColor_VisibleCanvasFrame retain];
}

- (void) dealloc
{
    [self setCanvasView: nil];

    [super dealloc];
}

- (void) setCanvasView: (PPCanvasView *) canvasView
{
    if (_canvasView == canvasView)
    {
        return;
    }

    if (_canvasView)
    {
        [self removeAsObserverForPPCanvasViewNotifications];
    }

    [_canvasView release];
    _canvasView = [canvasView retain];

    if (_canvasView)
    {
        [self addAsObserverForPPCanvasViewNotifications];

        [self setupVisibleCanvasBoundsAndTrackingRectForWindowVisibility];
    }
}

- (void) handleWindowWillBecomeVisible
{
    if (_needToRedrawView)
    {
        [self setNeedsDisplay: YES];
        _needToRedrawView = NO;
    }

    [self setupVisibleCanvasBounds];
}

- (void) handleWindowVisibilityChange
{
    _windowIsVisible = [[self window] isVisible];

    [self setupMouseTracking];

    if (!_windowIsVisible)
    {
        if (_mouseIsDraggingVisibleBounds)
        {
            [self setMouseIsDraggingVisibleBounds: NO];
        }

        // setupMouseTracking only updates the cursor when the window's visible, so update it
        // manually when hiding the window in order to reset from the hand cursor
        [self updateCursor];
    }
}

- (void) disableMouseTracking: (bool) shouldDisableTracking
{
    shouldDisableTracking = (shouldDisableTracking) ? YES : NO;

    if (_disallowMouseTracking == shouldDisableTracking)
    {
        return;
    }

    _disallowMouseTracking = shouldDisableTracking;

    [self setupMouseTracking];
}

#pragma mark PPThumbnailImageView overrides

- (void) setImage: (NSImage *) image
{
    [super setImage: image];

    [self setupVisibleCanvasBoundsAndTrackingRectForWindowVisibility];
}

- (void) handleUpdateToImage
{
    if (_windowIsVisible)
    {
        [super handleUpdateToImage];
    }
    else
    {
        _needToRedrawView = YES;
    }
}

#pragma mark NSView overrides

- (void) drawRect: (NSRect) rect
{
    [super drawRect: rect];

    if (!NSIsEmptyRect(_visibleCanvasBounds))
    {
        [gVisibleCanvasFrameColor set];
        NSFrameRectWithWidth(_visibleCanvasBounds, kVisibleCanvasFrameLineWidth);
    }
}

- (void) mouseDown: (NSEvent *) theEvent
{
    NSPoint mouseLocationInView;

    [self setMouseIsDraggingVisibleBounds: YES];

    mouseLocationInView = [self convertPoint: [theEvent locationInWindow] fromView: nil];

    if (!NSPointInRect(mouseLocationInView, _visibleCanvasBounds))
    {
        NSPoint mouseLocationInScaledImage, mouseLocationInImage;

        mouseLocationInScaledImage =
            PPGeometry_PointDifference(mouseLocationInView, _scaledThumbnailImageBounds.origin);

        mouseLocationInImage = NSMakePoint(mouseLocationInScaledImage.x / _thumbnailScale,
                                            mouseLocationInScaledImage.y / _thumbnailScale);

        [_canvasView centerEnclosingScrollViewAtImagePoint: mouseLocationInImage];
    }
}

- (void) mouseDragged: (NSEvent *) theEvent
{
    NSPoint mouseDragAmount, imageDragAmount, newCenterOfVisibleImage;

    if (!_mouseIsDraggingVisibleBounds)
        return;

    // merge event's deltaX/Y with other mouseDragged events in queue (saves some redrawing)
    mouseDragAmount = [theEvent ppMouseDragDeltaPointByMergingWithEnqueuedMouseDraggedEvents];

    imageDragAmount.x = mouseDragAmount.x / _thumbnailScale;
    imageDragAmount.y = mouseDragAmount.y / _thumbnailScale;

    newCenterOfVisibleImage =
        PPGeometry_PointSum([_canvasView imagePointAtCenterOfVisibleCanvas], imageDragAmount);

    [_canvasView centerEnclosingScrollViewAtImagePoint: newCenterOfVisibleImage];
}

- (void) mouseUp: (NSEvent *) theEvent
{
    [self setMouseIsDraggingVisibleBounds: NO];
}

- (void) mouseEntered: (NSEvent *) theEvent
{
    NSTrackingRectTag trackingNumber = [theEvent trackingNumber];

    if (trackingNumber == _viewBoundsTrackingRectTag)
    {
        if (!_mouseIsInsideViewBoundsTrackingRect)
        {
            _mouseIsInsideViewBoundsTrackingRect = YES;

            [self updateCursor];
        }
    }
    else if (trackingNumber == _visibleCanvasBoundsTrackingRectTag)
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
    NSTrackingRectTag trackingNumber = [theEvent trackingNumber];

    if (trackingNumber == _viewBoundsTrackingRectTag)
    {
        if (_mouseIsInsideViewBoundsTrackingRect)
        {
            _mouseIsInsideViewBoundsTrackingRect = NO;

            [self updateCursor];
        }
    }
    else if (trackingNumber == _visibleCanvasBoundsTrackingRectTag)
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

- (BOOL) acceptsFirstMouse: (NSEvent *) theEvent
{
    return YES;
}

#pragma mark PPCanvasView notifications

- (void) addAsObserverForPPCanvasViewNotifications
{
    if (!_canvasView)
        return;

    [[NSNotificationCenter defaultCenter]
                addObserver: self
                selector:
                    @selector(handlePPCanvasViewNotification_UpdatedNormalizedVisibleBounds:)
                name: PPCanvasViewNotification_UpdatedNormalizedVisibleBounds
                object: _canvasView];
}

- (void) removeAsObserverForPPCanvasViewNotifications
{
    [[NSNotificationCenter defaultCenter]
                                removeObserver: self
                                name: PPCanvasViewNotification_UpdatedNormalizedVisibleBounds
                                object: _canvasView];
}

- (void) handlePPCanvasViewNotification_UpdatedNormalizedVisibleBounds:
                                                                (NSNotification *) notification
{
    if (_mouseIsDraggingVisibleBounds)
    {
        // while dragging, the cursor can forget its state and revert to an arrow, so refresh it
        [[PPCursorManager sharedManager] refreshCursorIfNeeded];
    }

    [self setupVisibleCanvasBoundsAndTrackingRectForWindowVisibility];
}

#pragma mark Private methods

- (void) setupVisibleCanvasBoundsAndTrackingRectForWindowVisibility
{
    if (_windowIsVisible)
    {
        [self setupVisibleCanvasBounds];
        [self setupVisibleCanvasBoundsTrackingRect];
        [self updateCursor];
    }
    else    // !(_windowIsVisible)
    {
        _visibleCanvasBounds = NSZeroRect;
        _needToRedrawView = YES;
    }
}

- (void) setupVisibleCanvasBounds
{
    NSRect normalizedVisibleCanvasBounds, newVisibleCanvasBounds;

    normalizedVisibleCanvasBounds = [_canvasView normalizedVisibleBounds];

    newVisibleCanvasBounds = NSMakeRect(normalizedVisibleCanvasBounds.origin.x
                                            * _scaledThumbnailImageBounds.size.width
                                                + _scaledThumbnailImageBounds.origin.x,
                                        normalizedVisibleCanvasBounds.origin.y
                                            * _scaledThumbnailImageBounds.size.height
                                                + _scaledThumbnailImageBounds.origin.y,
                                        normalizedVisibleCanvasBounds.size.width
                                            * _scaledThumbnailImageBounds.size.width,
                                        normalizedVisibleCanvasBounds.size.height
                                            * _scaledThumbnailImageBounds.size.height);

    newVisibleCanvasBounds =
        PPGeometry_PixelBoundsCoveredByRect(
            NSIntersectionRect(newVisibleCanvasBounds, [self bounds]));

    if (!NSEqualRects(_visibleCanvasBounds, newVisibleCanvasBounds))
    {
        NSRect updateRect = NSUnionRect(_visibleCanvasBounds, newVisibleCanvasBounds);

        _visibleCanvasBounds = newVisibleCanvasBounds;

        [self setNeedsDisplayInRect: updateRect];
    }
}

- (void) setupMouseTracking
{
    [self setupViewBoundsTrackingRect];
    [self setupVisibleCanvasBoundsTrackingRect];

    if (_windowIsVisible)
    {
        [self updateCursor];
    }
}

- (void) setupViewBoundsTrackingRect
{
    NSRect newTrackingRect = NSZeroRect;
    bool mouseIsInsideNewTrackingRect = NO;

    if (_windowIsVisible && !_disallowMouseTracking)
    {
        newTrackingRect = [self bounds];

        if (!NSIsEmptyRect(newTrackingRect))
        {
            NSPoint mouseLocationInView =
                        [self convertPoint: [[self window] mouseLocationOutsideOfEventStream]
                                fromView: nil];

            mouseIsInsideNewTrackingRect =
                            (NSPointInRect(mouseLocationInView, newTrackingRect)) ? YES : NO;
        }
    }

    if (!NSEqualRects(newTrackingRect, _viewBoundsTrackingRect))
    {
        if (_viewBoundsTrackingRectTag)
        {
            [self removeTrackingRect: _viewBoundsTrackingRectTag];
            _viewBoundsTrackingRectTag = 0;

            _viewBoundsTrackingRect = NSZeroRect;
        }

        if (!NSIsEmptyRect(newTrackingRect))
        {
            _viewBoundsTrackingRectTag = [self addTrackingRect: newTrackingRect
                                                owner: self
                                                userData: NULL
                                                assumeInside: mouseIsInsideNewTrackingRect];

            if (_viewBoundsTrackingRectTag)
            {
                _viewBoundsTrackingRect = newTrackingRect;
            }
            else
            {
                mouseIsInsideNewTrackingRect = NO;
            }
        }
    }

    _mouseIsInsideViewBoundsTrackingRect = mouseIsInsideNewTrackingRect;
}

- (void) setupVisibleCanvasBoundsTrackingRect
{
    NSRect newTrackingRect = NSZeroRect;
    bool mouseIsInsideNewTrackingRect = NO;

    if (_windowIsVisible && !_disallowMouseTracking)
    {
        newTrackingRect = _visibleCanvasBounds;

        if (!NSIsEmptyRect(newTrackingRect))
        {
            NSPoint mouseLocationInView =
                        [self convertPoint: [[self window] mouseLocationOutsideOfEventStream]
                                fromView: nil];

            mouseIsInsideNewTrackingRect =
                            (NSPointInRect(mouseLocationInView, newTrackingRect)) ? YES : NO;
        }
    }

    if (!NSEqualRects(newTrackingRect, _visibleCanvasBoundsTrackingRect))
    {
        if (_visibleCanvasBoundsTrackingRectTag)
        {
            [self removeTrackingRect: _visibleCanvasBoundsTrackingRectTag];
            _visibleCanvasBoundsTrackingRectTag = 0;

            _visibleCanvasBoundsTrackingRect = NSZeroRect;
        }

        if (!NSIsEmptyRect(newTrackingRect))
        {
            _visibleCanvasBoundsTrackingRectTag =
                                        [self addTrackingRect: newTrackingRect
                                                owner: self
                                                userData: NULL
                                                assumeInside: mouseIsInsideNewTrackingRect];

            if (_visibleCanvasBoundsTrackingRectTag)
            {
                _visibleCanvasBoundsTrackingRect = newTrackingRect;
            }
            else
            {
                mouseIsInsideNewTrackingRect = NO;
            }
        }
    }

    if (_mouseIsInsideVisibleCanvasTrackingRect != mouseIsInsideNewTrackingRect)
    {
        _mouseIsInsideVisibleCanvasTrackingRect = mouseIsInsideNewTrackingRect;

        [self updateCursor];
    }
}

- (void) setMouseIsDraggingVisibleBounds: (bool) mouseIsDraggingVisibleBounds
{
    _mouseIsDraggingVisibleBounds = (mouseIsDraggingVisibleBounds) ? YES : NO;

    [self disableMouseTracking: _mouseIsDraggingVisibleBounds];
}

- (void) updateCursor
{
    NSCursor *cursor;

    if (_mouseIsDraggingVisibleBounds)
    {
        cursor = [NSCursor closedHandCursor];
    }
    else if (_mouseIsInsideVisibleCanvasTrackingRect)
    {
        cursor = [NSCursor openHandCursor];
    }
    else if (_mouseIsInsideViewBoundsTrackingRect)
    {
        cursor = [NSCursor pointingHandCursor];
    }
    else
    {
        cursor = nil;
    }

    [[PPCursorManager sharedManager] setCursor: cursor
                                        atLevel: kPPCursorLevel_PopupPanel
                                        isDraggingMouse: _mouseIsDraggingVisibleBounds];
}

@end
