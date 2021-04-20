/*
    PPCanvasView_MagnifierToolOverlay.m

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

#import "PPGeometry.h"
#import "PPSRGBUtilities.h"


#define kUIColor_MagnifierToolOverlayLine           \
            [NSColor ppSRGBColorWithWhite: 0.0f alpha: 0.95f]

#define kUIColor_MagnifierToolOverlayLineHalo       \
            [NSColor ppSRGBColorWithWhite: 1.0f alpha: 0.95f]

#define kMagnifierToolOverlayLineWidth      (0.0f)
#define kMagnifierToolOverlayLineHaloWidth  (3.0f)


static NSColor *gMagnifierToolOverlayLineColor = nil, *gMagnifierToolOverlayLineHaloColor = nil;


@implementation PPCanvasView (MagnifierToolOverlay)

+ (void) initializeMagnifierToolOverlay
{
    if (!gMagnifierToolOverlayLineColor)
    {
        gMagnifierToolOverlayLineColor = [kUIColor_MagnifierToolOverlayLine retain];
    }

    if (!gMagnifierToolOverlayLineHaloColor)
    {
        gMagnifierToolOverlayLineHaloColor = [kUIColor_MagnifierToolOverlayLineHalo retain];
    }
}

- (bool) initMagnifierToolOverlayMembers
{
    _magnifierToolOverlayRectPath = [[NSBezierPath bezierPath] retain];

    if (!_magnifierToolOverlayRectPath)
        goto ERROR;

    return YES;

ERROR:
    return NO;
}

- (void) deallocMagnifierToolOverlayMembers
{
    [_magnifierToolOverlayRectPath release];
    _magnifierToolOverlayRectPath = nil;
}

- (void) setMagnifierToolOverlayToViewRect: (NSRect) rect
{
    NSRect updateRect;

    rect = PPGeometry_PixelCenteredRect(NSIntersectionRect(rect, _offsetZoomedCanvasFrame));

    if (NSEqualRects(rect, _magnifierToolOverlayRect))
    {
        return;
    }

    updateRect = NSInsetRect(NSUnionRect(rect, _magnifierToolOverlayRect),
                                -kMagnifierToolOverlayLineHaloWidth/2.0f,
                                -kMagnifierToolOverlayLineHaloWidth/2.0f);
    updateRect = PPGeometry_PixelBoundsCoveredByRect(updateRect);

    _magnifierToolOverlayRect = rect;

    [_magnifierToolOverlayRectPath removeAllPoints];

    if (!NSIsEmptyRect(_magnifierToolOverlayRect))
    {
        [_magnifierToolOverlayRectPath appendBezierPathWithRect: _magnifierToolOverlayRect];
        _shouldDisplayMagnifierToolOverlay = YES;
    }
    else
    {
        _shouldDisplayMagnifierToolOverlay = NO;
    }

    [self setNeedsDisplayInRect: updateRect];
}

- (void) clearMagnifierToolOverlay
{
    [self setMagnifierToolOverlayToViewRect: NSZeroRect];
}

- (void) drawMagnifierToolOverlay
{
    if (!_shouldDisplayMagnifierToolOverlay)
        return;

    [_magnifierToolOverlayRectPath setLineWidth: kMagnifierToolOverlayLineHaloWidth];
    [gMagnifierToolOverlayLineHaloColor set];
    [_magnifierToolOverlayRectPath stroke];

    [_magnifierToolOverlayRectPath setLineWidth: kMagnifierToolOverlayLineWidth];
    [gMagnifierToolOverlayLineColor set];
    [_magnifierToolOverlayRectPath stroke];
}

@end
