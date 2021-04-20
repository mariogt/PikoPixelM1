/*
    PPCanvasView_SelectionToolOverlay.m

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
#import "PPDocument.h"


#define kSelectionToolOverlayAddPatternImageName        @"selection_tool_overlay_add_pattern"
#define kSelectionToolOverlaySubtractPatternImageName   \
                                                    @"selection_tool_overlay_subtract_pattern"

#define kUIColor_SelectionToolOverlayPathFill           \
            [NSColor ppSRGBColorWithWhite: 0.0f alpha: 0.18f]

#define kUIColor_SelectionToolOverlayOutline            \
            [NSColor ppSRGBColorWithRed: 0.0f green: 0.0f blue: 1.0f alpha: 0.6f]

#define kSelectionToolOverlayAnimationTimerInterval         (0.1f)

#define kSelectionToolOverlayAnimationStartDelayInterval    (0.08f)


static NSColor *gOverlayAddFillColor = nil, *gOverlaySubtractFillColor = nil,
                *gOverlayPathFillColor, *gOverlayOutlineColor;
static float gSelectionToolOverlayAnimationPatternWidth = 0.0f;


@interface PPCanvasView (SelectionToolOverlayPrivateMethods)

- (NSRect) visibleDrawingBoundsForPathWithBounds: (NSRect) pathBounds;

- (void) setSelectionToolOverlayToPath: (NSBezierPath *) path
            selectionMode: (PPSelectionMode) selectionMode
            intersectMask: (NSBitmapImageRep *) intersectMask
            toolPath: (NSBezierPath *) toolPath
            shouldAntialias: (bool) shouldAntialias;

- (void) setupSelectionToolOverlayAnimationTimerForCurrentState;
- (void) startSelectionToolOverlayAnimationTimer;
- (void) stopSelectionToolOverlayAnimationTimer;
- (void) selectionToolOverlayAnimationTimerDidFire: (NSTimer *) theTimer;
- (void) resetSelectionToolOverlayAnimationStartDate;
- (void) clearSelectionToolOverlayAnimationStartDate;

@end

@implementation PPCanvasView (SelectionToolOverlay)

+ (void) initializeSelectionToolOverlay
{
    NSImage *patternImage;

    patternImage = [NSImage imageNamed: kSelectionToolOverlayAddPatternImageName];
    gOverlayAddFillColor = [[NSColor colorWithPatternImage: patternImage] retain];

    patternImage = [NSImage imageNamed: kSelectionToolOverlaySubtractPatternImageName];
    gOverlaySubtractFillColor = [[NSColor colorWithPatternImage: patternImage] retain];

    gOverlayPathFillColor = [kUIColor_SelectionToolOverlayPathFill retain];

    gOverlayOutlineColor = [kUIColor_SelectionToolOverlayOutline retain];

    gSelectionToolOverlayAnimationPatternWidth = [patternImage size].width;
}

- (bool) initSelectionToolOverlayMembers
{
    _selectionToolOverlayPath_Working = [[NSBezierPath bezierPath] retain];
    _selectionToolOverlayPath_AddFill = [[NSBezierPath bezierPath] retain];
    _selectionToolOverlayPath_SubtractFill = [[NSBezierPath bezierPath] retain];
    _selectionToolOverlayPath_ToolPath = [[NSBezierPath bezierPath] retain];
    _selectionToolOverlayPath_Outline = [[NSBezierPath bezierPath] retain];

    if (!_selectionToolOverlayPath_Working
        || !_selectionToolOverlayPath_AddFill
        || !_selectionToolOverlayPath_SubtractFill
        || !_selectionToolOverlayPath_ToolPath
        || !_selectionToolOverlayPath_Outline)
    {
        goto ERROR;
    }

    return YES;

ERROR:
    return NO;
}

- (void) deallocSelectionToolOverlayMembers
{
    [self stopSelectionToolOverlayAnimationTimer];

    [_selectionToolOverlayPath_Working release];
    _selectionToolOverlayPath_Working = nil;

    [_selectionToolOverlayPath_AddFill release];
    _selectionToolOverlayPath_AddFill = nil;

    [_selectionToolOverlayPath_SubtractFill release];
    _selectionToolOverlayPath_SubtractFill = nil;

    [_selectionToolOverlayPath_ToolPath release];
    _selectionToolOverlayPath_ToolPath = nil;

    [_selectionToolOverlayPath_Outline release];
    _selectionToolOverlayPath_Outline = nil;


    [_selectionToolOverlayWorkingMask release];
    _selectionToolOverlayWorkingMask = nil;

    [_selectionToolOverlayWorkingPathMask release];
    _selectionToolOverlayWorkingPathMask = nil;
}

- (bool) resizeSelectionToolOverlayMasksToSize: (NSSize) size
{
    NSBitmapImageRep *selectionToolOverlayWorkingMask, *selectionToolOverlayWorkingPathMask;

    if (PPGeometry_IsZeroSize(size))
    {
        goto ERROR;
    }

    selectionToolOverlayWorkingMask = [NSBitmapImageRep ppMaskBitmapOfSize: size];
    selectionToolOverlayWorkingPathMask = [NSBitmapImageRep ppMaskBitmapOfSize: size];

    if (!selectionToolOverlayWorkingMask || !selectionToolOverlayWorkingPathMask)
    {
        goto ERROR;
    }

    [_selectionToolOverlayWorkingMask release];
    _selectionToolOverlayWorkingMask = [selectionToolOverlayWorkingMask retain];

    [_selectionToolOverlayWorkingPathMask release];
    _selectionToolOverlayWorkingPathMask = [selectionToolOverlayWorkingPathMask retain];

    return YES;

ERROR:
    return NO;
}

- (void) setSelectionToolOverlayToRect: (NSRect) rect
            selectionMode: (PPSelectionMode) selectionMode
            intersectMask: (NSBitmapImageRep *) intersectMask
            toolPathRect: (NSRect) toolPathRect
{
    NSBezierPath *selectionPath, *toolPath;

    selectionPath = _selectionToolOverlayPath_Working;

    rect = PPGeometry_PixelCenteredRect(rect);
    toolPathRect = PPGeometry_PixelCenteredRect(toolPathRect);

    if (NSEqualRects(rect, toolPathRect))
    {
        toolPath = selectionPath;
    }
    else
    {
        toolPath = _selectionToolOverlayPath_ToolPath;

        [toolPath removeAllPoints];
        [toolPath appendBezierPathWithRect: toolPathRect];

#if PP_DEPLOYMENT_TARGET_INCORRECTLY_FILLS_PIXEL_CENTERED_RECTS

        //  GNUstep (Cairo?) incorrectly fills pixel-centered rects: corner pixels are left
        // blank, and the edge pixels are antialiased.
        //  In most cases this issue doesn't appear because a rectangular path-fill is usually
        // accompanied by a path-stroke, which fixes the edge/corner pixels.
        //  In this case, the fill path (rect) doesn't match the stroke path (toolPathRect), so
        // rect needs to be converted from pixel-centered to pixel-bounded to properly draw the
        // edge pixels.

        rect = PPGeometry_PixelBoundsCoveredByRect(rect);

#endif  // PP_DEPLOYMENT_TARGET_INCORRECTLY_FILLS_PIXEL_CENTERED_RECTS
    }

    [selectionPath removeAllPoints];
    [selectionPath appendBezierPathWithRect: rect];

    [self setSelectionToolOverlayToPath: selectionPath
            selectionMode: selectionMode
            intersectMask: intersectMask
            toolPath: toolPath
            shouldAntialias: NO];
}

- (void) setSelectionToolOverlayToPath: (NSBezierPath *) path
            selectionMode: (PPSelectionMode) selectionMode
            intersectMask: (NSBitmapImageRep *) intersectMask
{
    [self setSelectionToolOverlayToPath: path
            selectionMode: selectionMode
            intersectMask: intersectMask
            toolPath: path
            shouldAntialias: YES];
}

- (void) setSelectionToolOverlayToMask: (NSBitmapImageRep *) maskBitmap
            maskBounds: (NSRect) maskBounds
            selectionMode: (PPSelectionMode) selectionMode
            intersectMask: (NSBitmapImageRep *) intersectMask
{
    NSRect pathDrawingBounds;
    NSAffineTransform *transform;
    NSRect overlayBounds;

    [_selectionToolOverlayPath_AddFill removeAllPoints];
    [_selectionToolOverlayPath_SubtractFill removeAllPoints];
    [_selectionToolOverlayPath_Outline removeAllPoints];

    if (_shouldDisplaySelectionToolOverlay)
    {
        [self setNeedsDisplayInRect: _selectionToolOverlayDisplayBounds];
    }

    [self setShouldHideSelectionOutline:
                                    (selectionMode == kPPSelectionMode_Replace) ? YES : NO];

    if (![maskBitmap ppIsMaskBitmap])
    {
        goto ERROR;
    }

    pathDrawingBounds = maskBounds;

    if (!_isAutoscrolling)
    {
        pathDrawingBounds = [self visibleDrawingBoundsForPathWithBounds: pathDrawingBounds];
    }

    [_selectionToolOverlayPath_Outline ppAppendOutlinePathForMaskBitmap: maskBitmap
                                        inBounds: pathDrawingBounds];

    switch (selectionMode)
    {
        case kPPSelectionMode_Intersect:
        {
            if (![intersectMask ppIsMaskBitmap]
                || !NSEqualSizes([maskBitmap ppSizeInPixels], [intersectMask ppSizeInPixels]))
            {
                goto ERROR;
            }

            // add path
            [_selectionToolOverlayWorkingMask ppCopyFromBitmap: maskBitmap
                                                inRect: pathDrawingBounds
                                                toPoint: pathDrawingBounds.origin];

            [_selectionToolOverlayWorkingMask ppIntersectMaskWithMaskBitmap: intersectMask
                                                inBounds: pathDrawingBounds];

            [_selectionToolOverlayPath_AddFill
                            ppAppendFillPathForMaskBitmap: _selectionToolOverlayWorkingMask
                            inBounds: pathDrawingBounds];

            // subtract path
            [_selectionToolOverlayWorkingMask ppCopyFromBitmap: maskBitmap
                                                inRect: pathDrawingBounds
                                                toPoint: pathDrawingBounds.origin];

            [_selectionToolOverlayWorkingMask ppSubtractMaskBitmap: intersectMask
                                                inBounds: pathDrawingBounds];

            [_selectionToolOverlayPath_SubtractFill
                            ppAppendFillPathForMaskBitmap: _selectionToolOverlayWorkingMask
                            inBounds: pathDrawingBounds];
        }
        break;

        case kPPSelectionMode_Subtract:
        {
            [_selectionToolOverlayPath_SubtractFill ppAppendFillPathForMaskBitmap: maskBitmap
                                                        inBounds: pathDrawingBounds];
        }
        break;

        default:
        {
            [_selectionToolOverlayPath_AddFill ppAppendFillPathForMaskBitmap: maskBitmap
                                                inBounds: pathDrawingBounds];
        }
        break;
    }

    transform = [NSAffineTransform transform];

    if (!transform)
        return;

    [transform translateXBy: _canvasDrawingOffset.x + 0.5f
                        yBy: _canvasDrawingOffset.y - 0.5f];

    [transform scaleBy: _zoomFactor];

    [_selectionToolOverlayPath_Outline transformUsingAffineTransform: transform];

    overlayBounds = NSZeroRect;

    if (![_selectionToolOverlayPath_AddFill isEmpty])
    {
        [_selectionToolOverlayPath_AddFill transformUsingAffineTransform: transform];

        overlayBounds = [_selectionToolOverlayPath_AddFill bounds];
    }

    if (![_selectionToolOverlayPath_SubtractFill isEmpty])
    {
        [_selectionToolOverlayPath_SubtractFill transformUsingAffineTransform: transform];

        overlayBounds = NSUnionRect(overlayBounds,
                                    [_selectionToolOverlayPath_SubtractFill bounds]);
    }

    if (![_selectionToolOverlayPath_ToolPath isEmpty])
    {
        [_selectionToolOverlayPath_ToolPath transformUsingAffineTransform: transform];
    }

    _selectionToolOverlayDisplayBounds = PPGeometry_PixelBoundsCoveredByRect(overlayBounds);

    if (!_autoscrollingIsEnabled)
    {
        NSRect visibleClippingBounds;

        // allow the outline to extend one pixel beyond the right & bottom canvas edges
        visibleClippingBounds = _offsetZoomedVisibleCanvasBounds;
        visibleClippingBounds.size.width += 1.0f;
        visibleClippingBounds.origin.y -= 1.0f;
        visibleClippingBounds.size.height += 1.0f;

        _selectionToolOverlayDisplayBounds =
                NSIntersectionRect(_selectionToolOverlayDisplayBounds, visibleClippingBounds);
    }

    _shouldDisplaySelectionToolOverlay =
                            (NSIsEmptyRect(_selectionToolOverlayDisplayBounds)) ? NO : YES;

    if (_shouldDisplaySelectionToolOverlay)
    {
        [self setNeedsDisplayInRect: _selectionToolOverlayDisplayBounds];
    }

    [self setupSelectionToolOverlayAnimationTimerForCurrentState];

    return;

ERROR:
    [self clearSelectionToolOverlay];

    return;
}

- (void) clearSelectionToolOverlay
{
    [self stopSelectionToolOverlayAnimationTimer];

    [_selectionToolOverlayPath_AddFill removeAllPoints];
    [_selectionToolOverlayPath_SubtractFill removeAllPoints];
    [_selectionToolOverlayPath_Outline removeAllPoints];
    [_selectionToolOverlayPath_ToolPath removeAllPoints];

    if (_shouldDisplaySelectionToolOverlay)
    {
        [self setNeedsDisplayInRect: _selectionToolOverlayDisplayBounds];
    }

    _shouldDisplaySelectionToolOverlay = NO;
    _selectionToolOverlayDisplayBounds = NSZeroRect;

    [self setShouldHideSelectionOutline: NO];
}

- (void) drawSelectionToolOverlay
{
    if (!_shouldDisplaySelectionToolOverlay)
        return;

    [[NSGraphicsContext currentContext] setPatternPhase: _selectionToolOverlayAnimationPhase];

    [gOverlayAddFillColor set];
    [_selectionToolOverlayPath_AddFill fill];

    [gOverlaySubtractFillColor set];
    [_selectionToolOverlayPath_SubtractFill fill];

    [gOverlayPathFillColor set];
    [_selectionToolOverlayPath_ToolPath fill];

    [gOverlayOutlineColor set];
    [_selectionToolOverlayPath_Outline stroke];
}

#pragma mark Private methods

- (NSRect) visibleDrawingBoundsForPathWithBounds: (NSRect) pathBounds
{
    // outset drawing bounds from _visibleCanvasBounds by 2.0 in both directions - the extra
    // (single-pixel) border around the visible canvas prevents false (cropped) path edges
    // from appearing on the window

    NSRect visibleCanvasDrawingBounds =
                        NSIntersectionRect(NSInsetRect(_visibleCanvasBounds, -2.0f, -2.0f),
                                            _canvasFrame);

    return NSIntersectionRect(visibleCanvasDrawingBounds, pathBounds);
}

- (void) setSelectionToolOverlayToPath: (NSBezierPath *) path
            selectionMode: (PPSelectionMode) selectionMode
            intersectMask: (NSBitmapImageRep *) intersectMask
            toolPath: (NSBezierPath *) toolPath
            shouldAntialias: (bool) shouldAntialias
{
    NSRect pathDrawingBounds, toolPathDrawingBounds;

    pathDrawingBounds = PPGeometry_PixelBoundsCoveredByRect([path bounds]);

    if (!_isAutoscrolling)
    {
        pathDrawingBounds = [self visibleDrawingBoundsForPathWithBounds: pathDrawingBounds];
    }

    if (toolPath == path)
    {
        toolPathDrawingBounds = pathDrawingBounds;
    }
    else
    {
        toolPathDrawingBounds =
                    NSIntersectionRect(PPGeometry_PixelBoundsCoveredByRect([toolPath bounds]),
                                        pathDrawingBounds);
    }

    [_selectionToolOverlayWorkingPathMask ppClearBitmapInBounds: pathDrawingBounds];

    [_selectionToolOverlayWorkingPathMask ppSetAsCurrentGraphicsContext];

    [[NSColor ppMaskBitmapOnColor] set];
    [toolPath stroke];

    [_selectionToolOverlayPath_ToolPath removeAllPoints];
    [_selectionToolOverlayPath_ToolPath
                        ppAppendFillPathForMaskBitmap: _selectionToolOverlayWorkingPathMask
                        inBounds: toolPathDrawingBounds];

    if (shouldAntialias)
    {
        // antialiasing is necessary when filling a non-rectangular path, otherwise the fill
        // will cover a larger area than the stroke (some curve edges will add a pixel);
        // make sure to correct the antialiasing afterwards by thresholding the mask's pixel
        // values to 0 & 255

        [path ppAntialiasedFill];
    }
    else
    {
        [path fill];
    }

    [_selectionToolOverlayWorkingPathMask ppRestoreGraphicsContext];

    if (shouldAntialias)
    {
        [_selectionToolOverlayWorkingPathMask
                                ppThresholdMaskBitmapPixelValuesInBounds: pathDrawingBounds];
    }

    [self setSelectionToolOverlayToMask: _selectionToolOverlayWorkingPathMask
            maskBounds: pathDrawingBounds
            selectionMode: selectionMode
            intersectMask: intersectMask];
}

#pragma mark Animation timer

- (void) setupSelectionToolOverlayAnimationTimerForCurrentState
{
    if (_shouldDisplaySelectionToolOverlay)
    {
        [self resetSelectionToolOverlayAnimationStartDate];

        if (!_selectionToolOverlayAnimationTimer)
        {
            [self startSelectionToolOverlayAnimationTimer];
        }
    }
    else
    {
        [self clearSelectionToolOverlayAnimationStartDate];

        if (_selectionToolOverlayAnimationTimer)
        {
            [self stopSelectionToolOverlayAnimationTimer];
        }
    }
}

- (void) startSelectionToolOverlayAnimationTimer
{
    if (_selectionToolOverlayAnimationTimer)
        return;

    _selectionToolOverlayAnimationTimer =
        [[NSTimer scheduledTimerWithTimeInterval: kSelectionToolOverlayAnimationTimerInterval
                                    target: self
                                    selector:
                                        @selector(selectionToolOverlayAnimationTimerDidFire:)
                                    userInfo: nil
                                    repeats: YES]
                retain];
}

- (void) stopSelectionToolOverlayAnimationTimer
{
    if (_selectionToolOverlayAnimationStartDate)
    {
        [self clearSelectionToolOverlayAnimationStartDate];
    }

    if (!_selectionToolOverlayAnimationTimer)
        return;

    [_selectionToolOverlayAnimationTimer invalidate];
    [_selectionToolOverlayAnimationTimer release];
    _selectionToolOverlayAnimationTimer = nil;
}

- (void) selectionToolOverlayAnimationTimerDidFire: (NSTimer *) theTimer
{
    if (!_shouldDisplaySelectionToolOverlay)
        return;

    if (_selectionToolOverlayAnimationStartDate
        && ([_selectionToolOverlayAnimationStartDate timeIntervalSinceNow] > 0.0f))
    {
        return;
    }

    _selectionToolOverlayAnimationPhase.x += 1.0;

    if (_selectionToolOverlayAnimationPhase.x >= gSelectionToolOverlayAnimationPatternWidth)
    {
        _selectionToolOverlayAnimationPhase.x = 0.0f;
    }

    [self setNeedsDisplayInRect: _selectionToolOverlayDisplayBounds];
}

- (void) resetSelectionToolOverlayAnimationStartDate
{
    if (_selectionToolOverlayAnimationStartDate)
    {
        [_selectionToolOverlayAnimationStartDate release];
    }

    _selectionToolOverlayAnimationStartDate =
        [[NSDate dateWithTimeIntervalSinceNow: kSelectionToolOverlayAnimationStartDelayInterval]
                                        retain];
}

- (void) clearSelectionToolOverlayAnimationStartDate
{
    if (!_selectionToolOverlayAnimationStartDate)
        return;

    [_selectionToolOverlayAnimationStartDate release];
    _selectionToolOverlayAnimationStartDate = nil;
}

@end
