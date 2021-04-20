/*
    PPCanvasView_ColorRampToolOverlay.m

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


#define kMinZoomFactorToDrawOverlay             5

#define kMinZoomFactorToDrawWideOutlines        14
#define kMinZoomFactorToDrawXMarks              8


#define kOverlayPathLineWidth_WideOutline       (2.0)
#define kOverlayPathLineWidth_NarrowOutline     (0.0)

#define kOverlayPathLineWidth_XMarkLine         (0.0)
#define kOverlayPathLineWidth_XMarkHalo         (2.0)


#define kUIColor_ColorRampToolOverlay_Outline                           \
            [NSColor ppDiagonalLinePatternColorWithLineWidth: 2.0f      \
                                color1: [NSColor blackColor]            \
                                color2: [NSColor whiteColor]]

#define kUIColor_ColorRampToolOverlay_XMarkLine                         \
            [NSColor ppSRGBColorWithWhite: 0.6 alpha: 0.7]

#define kUIColor_ColorRampToolOverlay_XMarkHalo                         \
            [NSColor ppSRGBColorWithWhite: 0.85 alpha: 0.7]


static NSColor *gOverlayColor_Outline = nil, *gOverlayColor_XMarkLine = nil,
                *gOverlayColor_XMarkHalo = nil;


@implementation PPCanvasView (ColorRampToolOverlay)

+ (void) initializeColorRampToolOverlay
{
    gOverlayColor_Outline = [kUIColor_ColorRampToolOverlay_Outline retain];

    gOverlayColor_XMarkLine = [kUIColor_ColorRampToolOverlay_XMarkLine retain];

    gOverlayColor_XMarkHalo = [kUIColor_ColorRampToolOverlay_XMarkHalo retain];
}

- (bool) initColorRampToolOverlayMembers
{
    _colorRampToolOverlayPath_Outline = [[NSBezierPath bezierPath] retain];
    _colorRampToolOverlayPath_XMarks = [[NSBezierPath bezierPath] retain];

    if (!_colorRampToolOverlayPath_Outline || !_colorRampToolOverlayPath_XMarks)
    {
        goto ERROR;
    }

    return YES;

ERROR:
    return NO;
}

- (void) deallocColorRampToolOverlayMembers
{
    [_colorRampToolOverlayPath_Outline release];
    _colorRampToolOverlayPath_Outline = nil;

    [_colorRampToolOverlayPath_XMarks release];
    _colorRampToolOverlayPath_XMarks = nil;
}

- (void) setColorRampToolOverlayToMask: (NSBitmapImageRep *) maskBitmap
            maskBounds: (NSRect) maskBounds
{
    NSAffineTransform *canvasViewTransform;
    NSRect outlinePathDisplayBounds, displayClippingBounds;
    CGFloat outlinePathLineWidth, outlinePathLineHalfWidth, canvasDisplayOutsetAmount;

    [self clearColorRampToolOverlay];

    if (![maskBitmap ppIsMaskBitmap])
    {
        goto ERROR;
    }

    maskBounds = NSIntersectionRect(PPGeometry_PixelBoundsCoveredByRect(maskBounds),
                                    [maskBitmap ppFrameInPixels]);

    if (NSIsEmptyRect(maskBounds))
    {
        goto ERROR;
    }

    if (_zoomFactor < kMinZoomFactorToDrawOverlay)
    {
        return;
    }

    canvasViewTransform = [NSAffineTransform transform];

    if (!canvasViewTransform)
    {
        goto ERROR;
    }

    [canvasViewTransform translateXBy: _canvasDrawingOffset.x + 0.5f
                            yBy: _canvasDrawingOffset.y - 0.5f];

    [canvasViewTransform scaleBy: _zoomFactor];


    if (_hasSelectionOutline)
    {
        [_colorRampToolOverlayPath_XMarks
                                    ppAppendXMarksForUnmaskedPixelsInMaskBitmap: maskBitmap
                                    inBounds: maskBounds];

        [_colorRampToolOverlayPath_XMarks transformUsingAffineTransform: canvasViewTransform];
    }

    [_colorRampToolOverlayPath_Outline appendBezierPathWithRect: maskBounds];

    if (maskBounds.size.width > 1.0)
    {
        [_colorRampToolOverlayPath_Outline
                                        ppAppendPixelColumnSeparatorLinesInBounds: maskBounds];
    }
    else if (maskBounds.size.height > 1.0)
    {
        [_colorRampToolOverlayPath_Outline ppAppendPixelRowSeparatorLinesInBounds: maskBounds];
    }

    [_colorRampToolOverlayPath_Outline transformUsingAffineTransform: canvasViewTransform];

    outlinePathLineWidth =
        (_zoomFactor >= kMinZoomFactorToDrawWideOutlines) ?
            kOverlayPathLineWidth_WideOutline : kOverlayPathLineWidth_NarrowOutline;

    outlinePathLineHalfWidth = outlinePathLineWidth / 2.0f;

    [_colorRampToolOverlayPath_Outline setLineWidth: outlinePathLineWidth];

    outlinePathDisplayBounds = [_colorRampToolOverlayPath_Outline bounds];

    if (outlinePathLineHalfWidth > 0)
    {
        // outset outlinePathDisplayBounds to account for path's linewidth
        outlinePathDisplayBounds = NSInsetRect(outlinePathDisplayBounds,
                                                -outlinePathLineHalfWidth,
                                                -outlinePathLineHalfWidth);
    }

    // allow the display bounds to extend past the canvas edges to account for the linewidth

    canvasDisplayOutsetAmount = 1.0f + outlinePathLineHalfWidth;

    displayClippingBounds = NSInsetRect(_offsetZoomedVisibleCanvasBounds,
                                        -canvasDisplayOutsetAmount,
                                        -canvasDisplayOutsetAmount);

    _colorRampToolOverlayDisplayBounds =
        PPGeometry_PixelBoundsCoveredByRect(
                        NSIntersectionRect(outlinePathDisplayBounds, displayClippingBounds));

    if (!NSIsEmptyRect(_colorRampToolOverlayDisplayBounds))
    {
        _shouldDisplayColorRampToolOverlay = YES;

        [self setNeedsDisplayInRect: _colorRampToolOverlayDisplayBounds];
    }

    return;

ERROR:
    return;
}

- (void) clearColorRampToolOverlay
{
    [_colorRampToolOverlayPath_Outline removeAllPoints];
    [_colorRampToolOverlayPath_XMarks removeAllPoints];

    if (_shouldDisplayColorRampToolOverlay)
    {
        [self setNeedsDisplayInRect: _colorRampToolOverlayDisplayBounds];
    }

    _shouldDisplayColorRampToolOverlay = NO;
    _colorRampToolOverlayDisplayBounds = NSZeroRect;
}

- (void) drawColorRampToolOverlay
{
    if (!_shouldDisplayColorRampToolOverlay)
        return;

    if (![_colorRampToolOverlayPath_XMarks isEmpty]
        && (_zoomFactor >= kMinZoomFactorToDrawXMarks))
    {
        [gOverlayColor_XMarkHalo set];
        [_colorRampToolOverlayPath_XMarks setLineWidth: kOverlayPathLineWidth_XMarkHalo];
        [_colorRampToolOverlayPath_XMarks stroke];

        [gOverlayColor_XMarkLine set];
        [_colorRampToolOverlayPath_XMarks setLineWidth: kOverlayPathLineWidth_XMarkLine];
        [_colorRampToolOverlayPath_XMarks stroke];
    }

    [gOverlayColor_Outline set];
    [_colorRampToolOverlayPath_Outline stroke];
}

@end
