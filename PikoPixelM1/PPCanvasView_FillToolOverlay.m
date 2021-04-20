/*
    PPCanvasView_FillToolOverlay.m

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
#import "NSColor_PPUtilities.h"
#import "PPGeometry.h"


#define kUIColor_FillToolOverlayOutline                     \
            [NSColor ppSRGBColorWithRed: 0.0f green: 0.0f blue: 1.0f alpha: 0.6f]


static NSColor *gOverlayOutlineColor = nil;


@interface PPCanvasView (FillToolOverlayPrivateMethods)

- (NSPoint) fillColorPatternPhaseForCurrentViewGeometry;

- (NSRect) visibleDrawingBoundsForFillToolPathWithBounds: (NSRect) pathBounds;

@end

@implementation PPCanvasView (FillToolOverlay)

+ (void) initializeFillToolOverlay
{
    gOverlayOutlineColor = [kUIColor_FillToolOverlayOutline retain];
}

- (bool) initFillToolOverlayMembers
{
    _fillToolOverlayPath_Fill = [[NSBezierPath bezierPath] retain];
    _fillToolOverlayPath_Outline = [[NSBezierPath bezierPath] retain];

    if (!_fillToolOverlayPath_Fill || !_fillToolOverlayPath_Outline)
    {
        goto ERROR;
    }

    return YES;

ERROR:
    return NO;
}

- (void) deallocFillToolOverlayMembers
{
    [_fillToolOverlayPatternColor release];
    _fillToolOverlayPatternColor = nil;

    [_fillToolOverlayPath_Fill release];
    _fillToolOverlayPath_Fill = nil;

    [_fillToolOverlayPath_Outline release];
    _fillToolOverlayPath_Outline = nil;
}

- (void) beginFillToolOverlayForOperationTarget: (PPLayerOperationTarget) operationTarget
            fillColor: (NSColor *) fillColor;
{
    if (_fillToolOverlayPatternColor)
    {
        [self endFillToolOverlay];
    }

    if (!PPLayerOperationTarget_IsValid(operationTarget)
        || !fillColor)
    {
        goto ERROR;
    }

    if (operationTarget == kPPLayerOperationTarget_DrawingLayerOnly)
    {
        return;
    }

    _fillToolOverlayPatternColor = [[NSColor ppFillOverlayPatternColorWithSize: _zoomFactor
                                                fillColor: fillColor]
                                        retain];

    if (!_fillToolOverlayPatternColor)
        goto ERROR;

    _fillToolOverlayPatternPhase = [self fillColorPatternPhaseForCurrentViewGeometry];

    return;

ERROR:
    return;
}

- (void) setFillToolOverlayToMask: (NSBitmapImageRep *) maskBitmap
            maskBounds: (NSRect) maskBounds
{
    NSRect pathDrawingBounds;
    NSAffineTransform *transform;
    NSRect overlayBounds, visibleClippingBounds;

    if (!_fillToolOverlayPatternColor)
        return;

    [_fillToolOverlayPath_Fill removeAllPoints];
    [_fillToolOverlayPath_Outline removeAllPoints];

    if (_shouldDisplayFillToolOverlay)
    {
        [self setNeedsDisplayInRect: _fillToolOverlayDisplayBounds];
    }

    if (![maskBitmap ppIsMaskBitmap])
    {
        goto ERROR;
    }

    pathDrawingBounds = [self visibleDrawingBoundsForFillToolPathWithBounds: maskBounds];

    [_fillToolOverlayPath_Fill ppAppendFillPathForMaskBitmap: maskBitmap
                                inBounds: pathDrawingBounds];

    [_fillToolOverlayPath_Outline ppAppendOutlinePathForMaskBitmap: maskBitmap
                                    inBounds: pathDrawingBounds];

    transform = [NSAffineTransform transform];

    if (!transform)
        return;

    [transform translateXBy: _canvasDrawingOffset.x + 0.5f
                        yBy: _canvasDrawingOffset.y - 0.5f];

    [transform scaleBy: _zoomFactor];

    overlayBounds = NSZeroRect;

    if (![_fillToolOverlayPath_Fill isEmpty])
    {
        [_fillToolOverlayPath_Fill transformUsingAffineTransform: transform];
        [_fillToolOverlayPath_Outline transformUsingAffineTransform: transform];

        overlayBounds = [_fillToolOverlayPath_Fill bounds];
    }

    _fillToolOverlayDisplayBounds = PPGeometry_PixelBoundsCoveredByRect(overlayBounds);

    // allow the outline to extend one pixel beyond the right & bottom canvas edges
    visibleClippingBounds = _offsetZoomedVisibleCanvasBounds;
    visibleClippingBounds.size.width += 1.0f;
    visibleClippingBounds.origin.y -= 1.0f;
    visibleClippingBounds.size.height += 1.0f;

    _fillToolOverlayDisplayBounds =
                    NSIntersectionRect(_fillToolOverlayDisplayBounds, visibleClippingBounds);

    _shouldDisplayFillToolOverlay = (NSIsEmptyRect(_fillToolOverlayDisplayBounds)) ? NO : YES;

    if (_shouldDisplayFillToolOverlay)
    {
        [self setNeedsDisplayInRect: _fillToolOverlayDisplayBounds];
    }

    return;

ERROR:
    [self endFillToolOverlay];

    return;
}

- (void) endFillToolOverlay
{
    [_fillToolOverlayPatternColor release];
    _fillToolOverlayPatternColor = nil;

    [_fillToolOverlayPath_Fill removeAllPoints];
    [_fillToolOverlayPath_Outline removeAllPoints];

    if (_shouldDisplayFillToolOverlay)
    {
        [self setNeedsDisplayInRect: _fillToolOverlayDisplayBounds];
    }

    _shouldDisplayFillToolOverlay = NO;
    _fillToolOverlayDisplayBounds = NSZeroRect;
}

- (void) drawFillToolOverlay
{
    if (!_shouldDisplayFillToolOverlay)
        return;

    [_fillToolOverlayPatternColor set];
    [[NSGraphicsContext currentContext] setPatternPhase: _fillToolOverlayPatternPhase];
    [_fillToolOverlayPath_Fill fill];

    [gOverlayOutlineColor set];
    [_fillToolOverlayPath_Outline stroke];
}

#pragma mark Private methods

- (NSPoint) fillColorPatternPhaseForCurrentViewGeometry
{
    NSScrollView *scrollView;
    NSSize scrollViewFrameSize, contentViewFrameSize;
    NSPoint visibleOrigin;

    scrollView = [self enclosingScrollView];
    scrollViewFrameSize = [scrollView frame].size;
    contentViewFrameSize = [scrollView contentSize];
    visibleOrigin = [[scrollView contentView] documentVisibleRect].origin;

    return NSMakePoint(_canvasDrawingOffset.x - visibleOrigin.x,
                        _canvasDrawingOffset.y
                            + scrollViewFrameSize.height
                            - contentViewFrameSize.height
                            - visibleOrigin.y);
}

- (NSRect) visibleDrawingBoundsForFillToolPathWithBounds: (NSRect) pathBounds
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
