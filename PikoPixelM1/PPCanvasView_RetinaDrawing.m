/*
    PPCanvasView_RetinaDrawing.m

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

#if PP_DEPLOYMENT_TARGET_SUPPORTS_RETINA_DISPLAY

#import "NSBitmapImageRep_PPUtilities.h"
#import "PPGeometry.h"


@interface PPCanvasView (RetinaDrawingPrivateMethods)

- (void) setupRetinaDisplayBuffer;
- (bool) currentDisplayIsRetina;

@end

#if !PP_SDK_HAS_BACKINGSCALEFACTOR_METHODS

@interface NSWindow (BackingScaleFactorMethodForLegacySDKs)

- (CGFloat) backingScaleFactor;

@end

#endif // !PP_SDK_HAS_BACKINGSCALEFACTOR_METHODS

#if !PP_SDK_HAS_NSIMAGEREP_DRAWINRECTFROMRECT_METHOD

@interface NSImageRep (DrawInRectFromRectMethodForLegacySDKs)

- (BOOL) drawInRect: (NSRect) dstSpacePortionRect
            fromRect: (NSRect) srcSpacePortionRect
            operation: (NSCompositingOperation) op
            fraction: (CGFloat) requestedAlpha
            respectFlipped: (BOOL) respectContextIsFlipped
            hints: (NSDictionary *) hints;

@end

#endif // !PP_SDK_HAS_NSIMAGEREP_DRAWINRECTFROMRECT_METHOD

@implementation PPCanvasView (RetinaDrawing)

- (void) setupRetinaDrawingForCurrentDisplay
{
    _currentDisplayIsRetina = [self currentDisplayIsRetina];

    if (_currentDisplayIsRetina)
    {
        [self setupRetinaDisplayBuffer];
    }
    else
    {
        [self destroyRetinaDrawingMembers];
    }
}

- (void) setupRetinaDrawingForResizedView;
{
    if (!_currentDisplayIsRetina)
        return;

    [self setupRetinaDisplayBuffer];
}

- (void) destroyRetinaDrawingMembers
{
    if (!_retinaDisplayBuffer)
        return;

    [_retinaDisplayBuffer release];
    _retinaDisplayBuffer = nil;
}

- (void) beginDrawingToRetinaDisplayBufferInRect: (NSRect) rect
{
    NSAffineTransform *transform;

    if (!_retinaDisplayBuffer)
        return;

    [_retinaDisplayBuffer ppSetAsCurrentGraphicsContext];

    transform = [NSAffineTransform transform];
    [transform translateXBy: -_offsetZoomedVisibleCanvasBounds.origin.x
                        yBy: -_offsetZoomedVisibleCanvasBounds.origin.y];

    [transform set];
}

- (void) finishDrawingToRetinaDisplayBufferInRect: (NSRect) rect
{
    NSRect bufferRect;

    if (!_retinaDisplayBuffer)
        return;

    [_retinaDisplayBuffer ppRestoreGraphicsContext];

    rect = NSIntersectionRect(rect, _offsetZoomedVisibleCanvasBounds);

    bufferRect.origin = PPGeometry_PointDifference(rect.origin,
                                                    _offsetZoomedVisibleCanvasBounds.origin);
    bufferRect.size = rect.size;

    [_retinaDisplayBuffer drawInRect: rect
                            fromRect: bufferRect
                            operation: NSCompositeCopy
                            fraction: 1.0
                            respectFlipped: YES
                            hints: nil];
}

#pragma mark Private methods

- (void) setupRetinaDisplayBuffer
{
    [self destroyRetinaDrawingMembers];

    _retinaDisplayBuffer =
                    [[NSBitmapImageRep ppImageBitmapOfSize: _zoomedVisibleImagesSize] retain];
}

- (bool) currentDisplayIsRetina
{
    static bool needToCheckBackingScaleFactorSelector = YES,
                backingScaleFactorSelectorIsSupported = NO;

    if (needToCheckBackingScaleFactorSelector)
    {
        backingScaleFactorSelectorIsSupported =
            ([NSWindow instancesRespondToSelector: @selector(backingScaleFactor)]) ? YES : NO;

        needToCheckBackingScaleFactorSelector = NO;
    }

    if (!backingScaleFactorSelectorIsSupported
        || ([[self window] backingScaleFactor] <= 1.0))
    {
        return NO;
    }

    return YES;
}

@end

#endif  // PP_DEPLOYMENT_TARGET_SUPPORTS_RETINA_DISPLAY
