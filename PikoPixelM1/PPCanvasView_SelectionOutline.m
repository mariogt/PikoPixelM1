/*
    PPCanvasView_SelectionOutline.m

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


#define kSelectionOutlinePatternImageName           @"marching_ants_pattern"
#define kSelectionOutlineAnimationTimerInterval     0.15f
#define kSelectionOutlineAnimationPhaseInterval     1.0f


static NSColor *gSelectionOutlinePatternColor = nil;
static float gSelectionOutlinePatternWidth = 0.0f;


@interface PPCanvasView (SelectionOutlinePrivateMethods)

- (void) setupSelectionOutlineAnimationTimerForCurrentState;
- (void) startSelectionOutlineAnimationTimer;
- (void) stopSelectionOutlineAnimationTimer;
- (void) selectionOutlineAnimationTimerDidFire: (NSTimer *) theTimer;

- (void) setupSelectionOutlinePathsFromSelectionMask: (NSBitmapImageRep *) selectionMask
            maskBounds: (NSRect) maskBounds;
- (void) clearSelectionOutlinePaths;

- (void) setupZoomedSelectionOutlinePath;
- (void) clearZoomedSelectionOutlinePath;

@end

@implementation PPCanvasView (SelectionOutline)

+ (void) initializeSelectionOutline
{
    NSImage *selectionOutlinePatternImage;

    selectionOutlinePatternImage = [NSImage imageNamed: kSelectionOutlinePatternImageName];

    gSelectionOutlinePatternColor =
                        [[NSColor colorWithPatternImage: selectionOutlinePatternImage] retain];

    gSelectionOutlinePatternWidth = [selectionOutlinePatternImage size].width;
}

- (bool) initSelectionOutlineMembers
{
    return YES;
}

- (void) deallocSelectionOutlineMembers
{
    [self stopSelectionOutlineAnimationTimer];

    [self clearSelectionOutlinePaths];
}

- (void) setSelectionOutlineToMask: (NSBitmapImageRep *) selectionMask
            maskBounds: (NSRect) maskBounds
{
    NSRect updateBounds = _zoomedSelectionOutlineDisplayBounds;

    [self setupSelectionOutlinePathsFromSelectionMask: selectionMask
            maskBounds: maskBounds];

    updateBounds = NSUnionRect(updateBounds, _zoomedSelectionOutlineDisplayBounds);

    [self setupSelectionOutlineAnimationTimerForCurrentState];

    [self setNeedsDisplayInRect: updateBounds];
}

- (void) setShouldHideSelectionOutline: (bool) shouldHideSelectionOutline
{
    shouldHideSelectionOutline = (shouldHideSelectionOutline) ? YES : NO;

    if (shouldHideSelectionOutline == _shouldHideSelectionOutline)
    {
        return;
    }

    _shouldHideSelectionOutline = shouldHideSelectionOutline;

    [self setNeedsDisplayInRect: _zoomedSelectionOutlineDisplayBounds];
}

- (void) setShouldAnimateSelectionOutline: (bool) shouldAnimateSelectionOutline
{
    _shouldAnimateSelectionOutline = (shouldAnimateSelectionOutline) ? YES : NO;

    [self setupSelectionOutlineAnimationTimerForCurrentState];
}

- (void) updateSelectionOutlineForCurrentVisibleCanvas
{
    [self setupZoomedSelectionOutlinePath];
}

- (void) drawSelectionOutline
{
    NSGraphicsContext *graphicsContext;

    if (!_hasSelectionOutline || _shouldHideSelectionOutline)
    {
        return;
    }

    // the current implementation of the selection outline path allows the path to extend
    // one pixel beyond the right & bottom edges of the visible canvas; as a workaround,
    // set the clipping path to prevent drawing outside the canvas

    [NSGraphicsContext saveGraphicsState];
    [NSBezierPath clipRect: _offsetZoomedVisibleCanvasBounds];

    [gSelectionOutlinePatternColor set];

    graphicsContext = [NSGraphicsContext currentContext];

    [graphicsContext setPatternPhase: _selectionOutlineTopRightAnimationPhase];
    [_zoomedSelectionOutlineTopRightPath stroke];

    [graphicsContext setPatternPhase: _selectionOutlineBottomLeftAnimationPhase];
    [_zoomedSelectionOutlineBottomLeftPath stroke];

    [NSGraphicsContext restoreGraphicsState];
}

#pragma mark Marching ants timer (animated selection outline)

- (void) setupSelectionOutlineAnimationTimerForCurrentState
{
    bool shouldEnableSelectionOutlineAnimationTimer =
                        (_hasSelectionOutline && _shouldAnimateSelectionOutline) ? YES : NO;

    if (shouldEnableSelectionOutlineAnimationTimer)
    {
        if (!_selectionOutlineAnimationTimer)
        {
            [self startSelectionOutlineAnimationTimer];
        }
    }
    else
    {
        if (_selectionOutlineAnimationTimer)
        {
            [self stopSelectionOutlineAnimationTimer];
        }
    }
}

- (void) startSelectionOutlineAnimationTimer
{
    if (_selectionOutlineAnimationTimer)
        return;

    _selectionOutlineAnimationTimer =
            [[NSTimer scheduledTimerWithTimeInterval: kSelectionOutlineAnimationTimerInterval
                        target: self
                        selector: @selector(selectionOutlineAnimationTimerDidFire:)
                        userInfo: nil
                        repeats: YES]
                    retain];
}

- (void) stopSelectionOutlineAnimationTimer
{
    if (!_selectionOutlineAnimationTimer)
        return;

    [_selectionOutlineAnimationTimer invalidate];
    [_selectionOutlineAnimationTimer release];
    _selectionOutlineAnimationTimer = nil;
}

- (void) selectionOutlineAnimationTimerDidFire: (NSTimer *) theTimer
{
    if (!_hasSelectionOutline || _shouldHideSelectionOutline
        || !_shouldAnimateSelectionOutline)
    {
        return;
    }

    _selectionOutlineTopRightAnimationPhase.x += kSelectionOutlineAnimationPhaseInterval;

    if (_selectionOutlineTopRightAnimationPhase.x >= gSelectionOutlinePatternWidth)
    {
        _selectionOutlineTopRightAnimationPhase.x = 0.0f;
    }

    _selectionOutlineBottomLeftAnimationPhase.x = -_selectionOutlineTopRightAnimationPhase.x;

    [self setNeedsDisplayInRect: _zoomedSelectionOutlineDisplayBounds];
}

#pragma mark Private methods

- (void) setupSelectionOutlinePathsFromSelectionMask: (NSBitmapImageRep *) selectionMask
            maskBounds: (NSRect) maskBounds
{
    NSBezierPath *selectionOutlineTopRightPath, *selectionOutlineBottomLeftPath,
                    *selectionOutlinePath;
    NSRect selectionOutlinePathBounds;

    [self clearSelectionOutlinePaths];

    if (![selectionMask ppIsMaskBitmap])
    {
        return;
    }

    selectionOutlineTopRightPath = [NSBezierPath bezierPath];
    selectionOutlineBottomLeftPath = [NSBezierPath bezierPath];

    [NSBezierPath ppAppendOutlinePathsForMaskBitmap: selectionMask
                    inBounds: maskBounds
                    toTopRightBezierPath: selectionOutlineTopRightPath
                    andBottomLeftBezierPath: selectionOutlineBottomLeftPath];

    if ([selectionOutlineTopRightPath isEmpty])
    {
        return;
    }

    _selectionOutlineTopRightPath = [selectionOutlineTopRightPath retain];
    _selectionOutlineBottomLeftPath = [selectionOutlineBottomLeftPath retain];

    _hasSelectionOutline = YES;

    // edge paths

    selectionOutlinePathBounds = [_selectionOutlineTopRightPath bounds];

    // right edge
    if (NSMaxX(selectionOutlinePathBounds) >= [selectionMask pixelsWide])
    {
        selectionOutlinePath = [NSBezierPath bezierPath];

        [selectionOutlinePath ppAppendRightEdgePathForMaskBitmap: selectionMask];

        if (![selectionOutlinePath isEmpty])
        {
            _selectionOutlineRightEdgePath = [selectionOutlinePath retain];
        }
    }

    // bottom edge
    if (selectionOutlinePathBounds.origin.y < 1.0f)
    {
        selectionOutlinePath = [NSBezierPath bezierPath];

        [selectionOutlinePath ppAppendBottomEdgePathForMaskBitmap: selectionMask];

        if (![selectionOutlinePath isEmpty])
        {
            _selectionOutlineBottomEdgePath = [selectionOutlinePath retain];
        }
    }

    [self setupZoomedSelectionOutlinePath];
}

- (void) clearSelectionOutlinePaths
{
    if (_selectionOutlineTopRightPath)
    {
        [_selectionOutlineTopRightPath release];
        _selectionOutlineTopRightPath = nil;
    }

    if (_selectionOutlineBottomLeftPath)
    {
        [_selectionOutlineBottomLeftPath release];
        _selectionOutlineBottomLeftPath = nil;
    }

    if (_selectionOutlineRightEdgePath)
    {
        [_selectionOutlineRightEdgePath release];
        _selectionOutlineRightEdgePath = nil;
    }

    if (_selectionOutlineBottomEdgePath)
    {
        [_selectionOutlineBottomEdgePath release];
        _selectionOutlineBottomEdgePath = nil;
    }

    [self clearZoomedSelectionOutlinePath];

    _hasSelectionOutline = NO;
}

- (void) setupZoomedSelectionOutlinePath
{
    NSBezierPath *zoomedSelectionOutlineTopRightPath, *zoomedSelectionOutlineBottomLeftPath,
                    *zoomedSelectionOutlineEdgePath;
    NSAffineTransform *transform;

    [self clearZoomedSelectionOutlinePath];

    if (!_hasSelectionOutline)
        return;

    transform = [NSAffineTransform transform];
    zoomedSelectionOutlineTopRightPath = [[_selectionOutlineTopRightPath copy] autorelease];
    zoomedSelectionOutlineBottomLeftPath = [[_selectionOutlineBottomLeftPath copy] autorelease];

    if (!transform || !zoomedSelectionOutlineTopRightPath
        || !zoomedSelectionOutlineBottomLeftPath)
    {
        return;
    }

    [transform translateXBy: _canvasDrawingOffset.x + 0.5f
                        yBy: _canvasDrawingOffset.y - 0.5f];

    [transform scaleBy: _zoomFactor];

    [zoomedSelectionOutlineTopRightPath transformUsingAffineTransform: transform];
    [zoomedSelectionOutlineBottomLeftPath transformUsingAffineTransform: transform];

    if (_selectionOutlineRightEdgePath)
    {
        transform = [NSAffineTransform transform];
        zoomedSelectionOutlineEdgePath = [[_selectionOutlineRightEdgePath copy] autorelease];

        if (transform && zoomedSelectionOutlineEdgePath)
        {
            [transform translateXBy: _canvasDrawingOffset.x - 0.5f
                                yBy: _canvasDrawingOffset.y - 0.5f];

            [transform scaleBy: _zoomFactor];

            [zoomedSelectionOutlineEdgePath transformUsingAffineTransform: transform];

            [zoomedSelectionOutlineTopRightPath appendBezierPath:
                                                            zoomedSelectionOutlineEdgePath];
        }
    }

    if (_selectionOutlineBottomEdgePath)
    {
        transform = [NSAffineTransform transform];
        zoomedSelectionOutlineEdgePath = [[_selectionOutlineBottomEdgePath copy] autorelease];

        if (transform && zoomedSelectionOutlineEdgePath)
        {
            [transform translateXBy: _canvasDrawingOffset.x + 0.5f
                                yBy: _canvasDrawingOffset.y + 0.5f];

            [transform scaleBy: _zoomFactor];

            [zoomedSelectionOutlineEdgePath transformUsingAffineTransform: transform];

            [zoomedSelectionOutlineBottomLeftPath appendBezierPath:
                                                            zoomedSelectionOutlineEdgePath];
        }
    }

    _zoomedSelectionOutlineTopRightPath = [zoomedSelectionOutlineTopRightPath retain];
    _zoomedSelectionOutlineBottomLeftPath = [zoomedSelectionOutlineBottomLeftPath retain];

    _zoomedSelectionOutlineDisplayBounds =
            PPGeometry_PixelBoundsCoveredByRect([zoomedSelectionOutlineTopRightPath bounds]);
}

- (void) clearZoomedSelectionOutlinePath
{
    if (_zoomedSelectionOutlineTopRightPath)
    {
        [_zoomedSelectionOutlineTopRightPath release];
        _zoomedSelectionOutlineTopRightPath = nil;
    }

    if (_zoomedSelectionOutlineBottomLeftPath)
    {
        [_zoomedSelectionOutlineBottomLeftPath release];
        _zoomedSelectionOutlineBottomLeftPath = nil;
    }

    _zoomedSelectionOutlineDisplayBounds = NSZeroRect;
}

@end
