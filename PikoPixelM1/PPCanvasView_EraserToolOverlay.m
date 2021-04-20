/*
    PPCanvasView_EraserToolOverlay.m

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

#import "PPCanvasView.h"

#import "NSBitmapImageRep_PPUtilities.h"
#import "NSBezierPath_PPUtilities.h"
#import "PPGeometry.h"
#import "PPDefines.h"


#define kEraserToolOverlayOutlinePatternImageName       @"eraser_tool_overlay_outline_pattern"


static NSColor *gEraserToolOverlayOutlineColor = nil;


@interface PPCanvasView (EraserToolOverlayPrivateMethods)

- (NSRect) visibleDrawingBoundsForEraserToolPathWithBounds: (NSRect) pathBounds;

@end

@implementation PPCanvasView (EraserToolOverlay)

+ (void) initializeEraserToolOverlay
{
    NSImage *eraserToolOverlayOutlinePatternImage =
                            [NSImage imageNamed: kEraserToolOverlayOutlinePatternImageName];

    if (!eraserToolOverlayOutlinePatternImage)
        goto ERROR;

    gEraserToolOverlayOutlineColor =
                [[NSColor colorWithPatternImage: eraserToolOverlayOutlinePatternImage] retain];

    return;

ERROR:
    return;
}

- (bool) initEraserToolOverlayMembers
{
    _eraserToolOverlayPath_Outline = [[NSBezierPath bezierPath] retain];

    if (!_eraserToolOverlayPath_Outline)
        goto ERROR;

    return YES;

ERROR:
    return NO;
}

- (void) deallocEraserToolOverlayMembers
{
    [_eraserToolOverlayPath_Outline release];
    _eraserToolOverlayPath_Outline = nil;
}

- (void) setEraserToolOverlayToMask: (NSBitmapImageRep *) maskBitmap
            maskBounds: (NSRect) maskBounds
{
    NSRect pathDrawingBounds;
    NSAffineTransform *transform;
    NSRect overlayBounds, visibleClippingBounds;

    [self clearEraserToolOverlay];

    if (_zoomFactor < kMinScalingFactorToDrawGrid)
    {
        return;
    }

    if (![maskBitmap ppIsMaskBitmap])
    {
        goto ERROR;
    }

    pathDrawingBounds = [self visibleDrawingBoundsForEraserToolPathWithBounds: maskBounds];

    [_eraserToolOverlayPath_Outline ppAppendOutlinePathForMaskBitmap: maskBitmap
                                    inBounds: pathDrawingBounds];

    transform = [NSAffineTransform transform];

    if (!transform)
        return;

    [transform translateXBy: _canvasDrawingOffset.x + 0.5f
                        yBy: _canvasDrawingOffset.y - 0.5f];

    [transform scaleBy: _zoomFactor];

    overlayBounds = NSZeroRect;

    if (![_eraserToolOverlayPath_Outline isEmpty])
    {
        [_eraserToolOverlayPath_Outline transformUsingAffineTransform: transform];

        overlayBounds = [_eraserToolOverlayPath_Outline bounds];
    }

    _eraserToolOverlayDisplayBounds = PPGeometry_PixelBoundsCoveredByRect(overlayBounds);

    // allow the outline to extend one pixel beyond the right & bottom canvas edges
    visibleClippingBounds = _offsetZoomedVisibleCanvasBounds;
    visibleClippingBounds.size.width += 1.0f;
    visibleClippingBounds.origin.y -= 1.0f;
    visibleClippingBounds.size.height += 1.0f;

    _eraserToolOverlayDisplayBounds =
                    NSIntersectionRect(_eraserToolOverlayDisplayBounds, visibleClippingBounds);

    _shouldDisplayEraserToolOverlay =
                                (NSIsEmptyRect(_eraserToolOverlayDisplayBounds)) ? NO : YES;

    if (_shouldDisplayEraserToolOverlay)
    {
        [self setNeedsDisplayInRect: _eraserToolOverlayDisplayBounds];
    }

    return;

ERROR:
    return;
}

- (void) clearEraserToolOverlay
{
    [_eraserToolOverlayPath_Outline removeAllPoints];

    if (_shouldDisplayEraserToolOverlay)
    {
        [self setNeedsDisplayInRect: _eraserToolOverlayDisplayBounds];
    }

    _shouldDisplayEraserToolOverlay = NO;
    _eraserToolOverlayDisplayBounds = NSZeroRect;
}

- (void) drawEraserToolOverlay
{
    if (!_shouldDisplayEraserToolOverlay)
        return;

    [gEraserToolOverlayOutlineColor set];

    [_eraserToolOverlayPath_Outline stroke];
}

#pragma mark Private methods

- (NSRect) visibleDrawingBoundsForEraserToolPathWithBounds: (NSRect) pathBounds
{
    // outset drawing bounds from _visibleCanvasBounds by 2.0 in both directions - the extra
    // (single-pixel) border around the visible canvas prevents false (cropped) path edges
    // from appearing on the window

    NSRect visibleCanvasDrawingBounds =
                        NSIntersectionRect(NSInsetRect(_visibleCanvasBounds, -2.0f, -2.0f),
                                            _canvasFrame);

    return NSIntersectionRect(visibleCanvasDrawingBounds, pathBounds);
}

@end
