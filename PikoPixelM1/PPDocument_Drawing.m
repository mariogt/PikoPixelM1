/*
    PPDocument_Drawing.m

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

#import "PPDocument.h"

#import "PPDocument_Notifications.h"
#import "NSBitmapImageRep_PPUtilities.h"
#import "NSColor_PPUtilities.h"
#import "NSBezierPath_PPUtilities.h"
#import "PPGeometry.h"
#import "PPDocumentLayer.h"


@interface PPDocument (DrawingPrivateMethods)

- (void) handleUpdateToDrawingLayerBitmapInBounds: (NSRect) bounds;

- (void) drawBezierPath: (NSBezierPath *) path
            andFill: (bool) shouldFillPath
            pathIsPixelated: (bool) pathIsPixelated;

- (void) performDrawUsingMask: (NSBitmapImageRep *) drawingMask
            inBounds: (NSRect) drawBounds;

- (void) undoCurrentDrawingAndForceDrawingLayerUpdate: (bool) shouldSendDrawingLayerUpdate;

- (void) prepareUndoDrawingInBounds: (NSRect) undoBounds;

- (void) undoDrawingWithTIFFData: (NSData *) undoBitmapTIFFData atPoint: (NSPoint) origin;

- (void) mergeInteractiveEraseMaskWithMaskBitmap: (NSBitmapImageRep *) maskBitmap
            inBounds: (NSRect) maskBounds;

- (void) clearInteractiveEraseMask;

@end

@implementation PPDocument (Drawing)

- (NSColor *) fillColor
{
    return _fillColor;
}

- (void) setFillColor: (NSColor *) fillColor
{
    NSColor *fillColor_sRGB, *oldFillColor;
    NSUndoManager *undoManager;

    if (!fillColor)
        goto ERROR;

    fillColor_sRGB = [fillColor ppSRGBColor];

    if (!fillColor_sRGB)
        goto ERROR;

    oldFillColor = [[_fillColor retain] autorelease];

    [_fillColor release];
    _fillColor = [fillColor retain];

    [_fillColor_sRGB release];
    _fillColor_sRGB = [fillColor_sRGB retain];

    _fillColorPixelValue_sRGB = [_fillColor_sRGB ppImageBitmapPixelValue];

    undoManager = [self undoManager];
    [[undoManager prepareWithInvocationTarget: self] setFillColor: oldFillColor];

    if (![undoManager isUndoing] && ![undoManager isRedoing])
    {
        [undoManager setActionName: NSLocalizedString(@"Change Draw Color", nil)];
    }

    [self postNotification_ChangedFillColor];

    return;

ERROR:
    return;
}

- (void) setFillColorWithoutUndoRegistration: (NSColor *) fillColor
{
    NSUndoManager *undoManager;
    bool needToReenableUndoRegistration = NO;

    undoManager = [self undoManager];

    if ([undoManager isUndoRegistrationEnabled])
    {
        [undoManager disableUndoRegistration];

        needToReenableUndoRegistration = YES;
    }

    [self setFillColor: fillColor];

    if (needToReenableUndoRegistration)
    {
        [undoManager enableUndoRegistration];
    }
}

- (void) beginDrawingWithPenMode: (PPPenMode) penMode
{
    if (![_drawingLayer isEnabled] || _isDrawing)
    {
        return;
    }

    _penMode = (penMode != kPPPenMode_Erase) ? kPPPenMode_Fill : kPPPenMode_Erase;

    _drawingUndoBounds = NSZeroRect;
    _shouldUndoCurrentDrawing = NO;

    // improve drawing performance by disabling thumbnail updates until the draw's done
    [self disableThumbnailImageUpdateNotifications: YES];

    _isDrawing = YES;
}

- (void) finishDrawing
{
    if (!_isDrawing)
        return;

    if (_shouldUndoCurrentDrawing)
    {
        [self undoCurrentDrawingAndForceDrawingLayerUpdate: YES];
    }

    _isDrawing = NO;

    [self disableThumbnailImageUpdateNotifications: NO];

    if (!NSIsEmptyRect(_drawingUndoBounds))
    {
        [self prepareUndoDrawingInBounds: _drawingUndoBounds];

        [[self undoManager] setActionName: (_penMode != kPPPenMode_Erase) ? NSLocalizedString(@"Draw", nil) : NSLocalizedString(@"Erase", nil)];

        _drawingUndoBounds = NSZeroRect;

        [self sendThumbnailImageUpdateNotifications];

        if (_penMode == kPPPenMode_Erase)
        {
            [self clearInteractiveEraseMask];
        }
    }
}

- (void) undoCurrentDrawingAtNextDraw
{
    if (!_isDrawing)
        return;

    _shouldUndoCurrentDrawing = YES;
}

- (void) drawPixelAtPoint: (NSPoint) point
{
    if (!_isDrawing)
        return;

    [self drawLineFromPoint: point toPoint: point];
}

- (void) drawLineFromPoint: (NSPoint) startPoint toPoint: (NSPoint) endPoint
{
    NSBezierPath *linePath;

    if (!_isDrawing)
        return;

    linePath = [NSBezierPath bezierPath];

    [linePath ppAppendLineFromPixelAtPoint: startPoint toPixelAtPoint: endPoint];

    [self drawBezierPath: linePath
            andFill: NO
            pathIsPixelated: NO];
}

- (void) drawRect: (NSRect) rect andFill: (bool) shouldFill
{
    if (!_isDrawing)
        return;

    rect = PPGeometry_PixelCenteredRect(rect);

    [self drawBezierPath: [NSBezierPath bezierPathWithRect: rect]
            andFill: shouldFill
            pathIsPixelated: YES];
}

- (void) drawOvalInRect: (NSRect) rect andFill: (bool) shouldFill
{
    if (!_isDrawing)
        return;

    rect = PPGeometry_PixelCenteredRect(rect);

    [self drawBezierPath: [NSBezierPath ppPixelatedBezierPathWithOvalInRect: rect]
            andFill: shouldFill
            pathIsPixelated: YES];
}

- (void) drawBezierPath: (NSBezierPath *) path andFill: (bool) shouldFill
{
    [self drawBezierPath: path
            andFill: shouldFill
            pathIsPixelated: NO];
}

- (void) drawColorRampWithStartingColor: (NSColor *) startColor
            fromPoint: (NSPoint) startPoint
            toPoint: (NSPoint) endPoint
            returnedRampBounds: (NSRect *) returnedRampBounds
            returnedDrawMask: (NSBitmapImageRep **) returnedDrawMask
{
    NSColor *endColor;
    NSPoint deltaPoint;
    unsigned rampLength;
    NSRect rampBounds, drawBounds, updateBounds = NSZeroRect;
    NSBitmapImageRep *rampBitmap;
    bool shouldSwapRampEndpointColors = NO, rampIsVertical = NO;

    if (!_isDrawing)
        goto ERROR;

    if (_shouldUndoCurrentDrawing)
    {
        updateBounds = NSUnionRect(updateBounds, _drawingUndoBounds);

        [self undoCurrentDrawingAndForceDrawingLayerUpdate: NO];
    }

    if (!startColor)
        goto ERROR;

    startPoint = PPGeometry_PointClippedToIntegerValues(startPoint);
    endPoint = PPGeometry_PointClippedToIntegerValues(endPoint);

    if (!NSPointInRect(startPoint, _canvasFrame)
        || !NSPointInRect(endPoint, _canvasFrame))
    {
        goto ERROR;
    }

    deltaPoint = PPGeometry_PointDifference(endPoint, startPoint);

    if (fabsf((float) deltaPoint.x) >= fabsf((float) deltaPoint.y))
    {
        // horizontal ramp
        endPoint.y = startPoint.y;

        if (startPoint.x > endPoint.x)
        {
            shouldSwapRampEndpointColors = YES;
        }

        rampLength = fabsf((float) deltaPoint.x) + 1;
    }
    else
    {
        // vertical ramp
        endPoint.x = startPoint.x;

        if (startPoint.y < endPoint.y)
        {
            shouldSwapRampEndpointColors = YES;
        }

        rampLength = fabsf((float) deltaPoint.y) + 1;
        rampIsVertical = YES;
    }

    endColor = startColor;

    if (rampLength > 1)
    {
        if (shouldSwapRampEndpointColors)
        {
            startColor = _fillColor_sRGB;
        }
        else
        {
            endColor = _fillColor_sRGB;
        }
    }

    if (rampIsVertical)
    {
        rampBitmap = [NSBitmapImageRep ppVerticalGradientPatternBitmapWithHeight: rampLength
                                        topColor: startColor
                                        bottomColor: endColor];
    }
    else
    {
        rampBitmap = [NSBitmapImageRep ppHorizontalGradientPatternBitmapWithWidth: rampLength
                                        leftColor: startColor
                                        rightColor: endColor];
    }

    rampBounds = PPGeometry_PixelBoundsWithCornerPoints(startPoint, endPoint);

    if (!rampBitmap
        || !NSEqualSizes(rampBounds.size, [rampBitmap ppSizeInPixels]))
    {
        goto ERROR;
    }

    if (_hasSelection)
    {
        [_drawingMask ppCopyFromBitmap: _selectionMask
                        inRect: rampBounds
                        toPoint: rampBounds.origin];

        drawBounds = [_drawingMask ppMaskBoundsInRect: rampBounds];

        if (!NSIsEmptyRect(drawBounds))
        {
            NSBitmapImageRep *rampDrawMask =
                                    [_drawingMask ppShallowDuplicateFromBounds: rampBounds];

            [_drawingLayerBitmap ppMaskedCopyFromImageBitmap: rampBitmap
                                    usingMask: rampDrawMask
                                    toPoint: rampBounds.origin];
        }
    }
    else
    {
        [_drawingMask ppMaskPixelsInBounds: rampBounds];
        drawBounds = rampBounds;

        [_drawingLayerBitmap ppCopyFromBitmap: rampBitmap toPoint: rampBounds.origin];
    }

    _drawingUndoBounds = NSUnionRect(_drawingUndoBounds, drawBounds);
    updateBounds = NSUnionRect(updateBounds, drawBounds);

    if (!NSIsEmptyRect(updateBounds))
    {
        [self handleUpdateToDrawingLayerBitmapInBounds: updateBounds];
    }

    if (returnedRampBounds)
    {
        *returnedRampBounds = rampBounds;
    }

    if (returnedDrawMask)
    {
        *returnedDrawMask = _drawingMask;
    }

    return;

ERROR:
    if (!NSIsEmptyRect(updateBounds))
    {
        [self handleUpdateToDrawingLayerBitmapInBounds: updateBounds];
    }

    if (returnedRampBounds)
    {
        *returnedRampBounds = NSZeroRect;
    }

    if (returnedDrawMask)
    {
        *returnedDrawMask = nil;
    }

    return;
}

- (NSColor *) colorAtPoint: (NSPoint) point
                inTarget: (PPLayerOperationTarget) target
{
    NSBitmapImageRep *sourceBitmap = [self sourceBitmapForLayerOperationTarget: target];

    return [sourceBitmap ppImageColorAtPoint: point];
}

- (void) fillPixelsMatchingColorAtPoint: (NSPoint) point
            colorMatchTolerance: (unsigned) colorMatchTolerance
            pixelMatchingMode: (PPPixelMatchingMode) pixelMatchingMode
            returnedMatchMask: (NSBitmapImageRep **) returnedMatchMask
            returnedMatchMaskBounds: (NSRect *) returnedMatchMaskBounds
{
    NSBitmapImageRep *matchMask;
    NSRect matchMaskBounds;

    if (!_isDrawing)
        goto ERROR;

    if (_shouldUndoCurrentDrawing)
    {
        [self undoCurrentDrawingAndForceDrawingLayerUpdate: YES];
    }

    matchMask = [self maskForPixelsMatchingColorAtPoint: point
                        colorMatchTolerance: colorMatchTolerance
                        pixelMatchingMode: pixelMatchingMode
                        shouldIntersectSelectionMask: YES];

    if (!matchMask)
        goto ERROR;

    matchMaskBounds =
            [matchMask ppMaskBoundsInRect: (_hasSelection) ? _selectionBounds : _canvasFrame];

    if (!NSIsEmptyRect(matchMaskBounds))
    {
        [self performDrawUsingMask: matchMask inBounds: matchMaskBounds];
    }

    if (returnedMatchMask)
    {
        *returnedMatchMask = matchMask;
    }

    if (returnedMatchMaskBounds)
    {
        *returnedMatchMaskBounds = matchMaskBounds;
    }

    return;

ERROR:
    if (returnedMatchMask)
    {
        *returnedMatchMask = nil;
    }

    if (returnedMatchMaskBounds)
    {
        *returnedMatchMaskBounds = NSZeroRect;
    }

    return;
}

- (void) noninteractiveFillSelectedDrawingArea
{
    if (_isDrawing || !_hasSelection || ![_drawingLayer isEnabled])
    {
        return;
    }

    [_drawingLayerBitmap ppMaskedFillUsingMask: _selectionMask
                            inBounds: _selectionBounds
                            fillPixelValue: _fillColorPixelValue_sRGB];

    [self handleUpdateToDrawingLayerBitmapInBounds: _selectionBounds];

    [self prepareUndoDrawingInBounds: _selectionBounds];

    [[self undoManager] setActionName: NSLocalizedString(@"Fill Selected Pixels", nil)];
}

- (void) noninteractiveEraseSelectedAreaInTarget: (PPLayerOperationTarget) operationTarget
            andClearSelectionMask: (bool) shouldClearSelectionMask
{
    NSString *targetName, *actionName;

    if (_isDrawing || !_hasSelection)
    {
        return;
    }

    [self setupTargetLayerIndexesForOperationTarget: operationTarget];

    if (_numTargetLayerIndexes > 0)
    {
        NSBitmapImageRep *updateBitmap, *eraseMask;
        bool eraseMaskCoversAllPixels, isMultilayerOperation;
        int i, layerIndex;

        updateBitmap = [NSBitmapImageRep ppImageBitmapOfSize: _selectionBounds.size];
        eraseMask = [_selectionMask ppShallowDuplicateFromBounds: _selectionBounds];

        if (!updateBitmap || !eraseMask)
        {
            goto ERROR;
        }

        eraseMaskCoversAllPixels = [eraseMask ppMaskCoversAllPixels] ? YES : NO;

        isMultilayerOperation = (_numTargetLayerIndexes > 1) ? YES : NO;

        if (isMultilayerOperation)
        {
            [self beginMultilayerOperation];
        }

        for (i=0; i<_numTargetLayerIndexes; i++)
        {
            layerIndex = _targetLayerIndexes[i];

            if (!eraseMaskCoversAllPixels)
            {
                [updateBitmap ppCopyFromBitmap: [[self layerAtIndex: layerIndex] bitmap]
                                inRect: _selectionBounds
                                toPoint: NSZeroPoint];

                [updateBitmap ppMaskedEraseUsingMask: eraseMask];
            }

            [self copyImageBitmap: updateBitmap
                    toLayerAtIndex: layerIndex
                    atPoint: _selectionBounds.origin];
        }

        if (isMultilayerOperation)
        {
            [self finishMultilayerOperation];
        }

        if (shouldClearSelectionMask)
        {
            targetName = [self nameWithSelectionStateForLayerOperationTarget: operationTarget];
        }
    }
    else    // !(_numTargetLayerIndexes > 0)
    {
        if (!shouldClearSelectionMask)
            goto ERROR;

        targetName = @"Selection Outline";
    }

    if (shouldClearSelectionMask)
    {
        [self deselectAll];

        actionName = [NSString stringWithFormat: @"Delete (%@)", targetName];

        if (!actionName)
        {
            actionName = @"Delete Selection";
        }
    }
    else
    {
        actionName = @"Erase Selected Pixels";
    }

    [[self undoManager] setActionName: NSLocalizedString(actionName, nil)];

    return;

ERROR:
    return;
}

- (bool) getInteractiveEraseMask: (NSBitmapImageRep **) returnedEraseMask
            andBounds: (NSRect *) returnedEraseBounds
{
    if (!_isDrawing || (_penMode != kPPPenMode_Erase))
    {
        goto ERROR;
    }

    if (returnedEraseMask)
    {
        *returnedEraseMask = _interactiveEraseMask;
    }

    if (returnedEraseBounds)
    {
        *returnedEraseBounds = _interactiveEraseBounds;
    }

    return YES;

ERROR:
    return NO;
}

- (void) copyImageBitmapToDrawingLayer: (NSBitmapImageRep *) bitmap atPoint: (NSPoint) origin
{
    NSRect updateBounds;

    if (![bitmap ppIsImageBitmap])
    {
        goto ERROR;
    }

    origin = PPGeometry_PointClippedToIntegerValues(origin);

    updateBounds.origin = origin;
    updateBounds.size = [bitmap ppSizeInPixels];

    updateBounds = NSIntersectionRect(updateBounds, _canvasFrame);

    if (NSIsEmptyRect(updateBounds))
    {
        goto ERROR;
    }

    [_drawingLayerBitmap ppCopyFromBitmap: bitmap toPoint: origin];

    [self handleUpdateToDrawingLayerBitmapInBounds: updateBounds];

    if (!_isDrawing)
    {
        [self prepareUndoDrawingInBounds: updateBounds];
    }

    return;

ERROR:
    return;
}

#pragma mark Private methods

- (void) handleUpdateToDrawingLayerBitmapInBounds: (NSRect) bounds
{
    [_drawingLayer handleUpdateToBitmapInRect: bounds];

    [self handleUpdateToLayerAtIndex: _indexOfDrawingLayer inRect: bounds];
}

- (void) drawBezierPath: (NSBezierPath *) path
            andFill: (bool) shouldFill
            pathIsPixelated: (bool) pathIsPixelated
{
    NSRect drawBounds;
    bool needToThresholdAntialiasedMask = NO;

    if (!_isDrawing || !path)
    {
        return;
    }

    // currently doesn't account for path's linewidth
    drawBounds = PPGeometry_PixelBoundsCoveredByRect([path bounds]);

    if (_hasSelection)
    {
        drawBounds = NSIntersectionRect(drawBounds, _selectionBounds);
    }
    else
    {
        drawBounds = NSIntersectionRect(drawBounds, _canvasFrame);
    }

    if (NSIsEmptyRect(drawBounds))
    {
        return;
    }

    [_drawingMask ppClearBitmapInBounds: drawBounds];

    [_drawingMask ppSetAsCurrentGraphicsContext];
    [[NSColor ppMaskBitmapOnColor] set];

    if (shouldFill)
    {
        //  A pixelated path is a path with well-defined pixel boundaries - it's made up
        // exclusively of horizontal, vertical, or 1:1 diagonal line-elements, each with
        // pixel-centered endpoints - this prevents interpolation/roundoff issues from curve
        // elements or differently-sloped lines, which can cause the path's fill area to have a
        // slightly different shape than a stroke of the same path (due to some additional or
        // missing pixels along the path's edges).

        if (pathIsPixelated)
        {
            [path fill];
        }
        else
        {
            //  Workaround for non-pixelated paths to make the fill area match the stroke is to
            // enable the graphics context's antialiasing when filling, then threshold the
            // mask to convert the antialiased middle-grey pixel-values (1-254) to 0 or 255.

            [path ppAntialiasedFill];

            needToThresholdAntialiasedMask = YES;
        }
    }

    [path stroke];

    [_drawingMask ppRestoreGraphicsContext];

    if (needToThresholdAntialiasedMask)
    {
        [_drawingMask ppThresholdMaskBitmapPixelValuesInBounds: drawBounds];
    }

    if (_hasSelection)
    {
        [_drawingMask ppIntersectMaskWithMaskBitmap: _selectionMask inBounds: drawBounds];

        drawBounds = [_drawingMask ppMaskBoundsInRect: drawBounds];

        if (NSIsEmptyRect(drawBounds))
        {
            return;
        }
    }

    [self performDrawUsingMask: _drawingMask inBounds: drawBounds];
}

- (void) performDrawUsingMask: (NSBitmapImageRep *) drawingMask
            inBounds: (NSRect) drawBounds
{
    NSRect updateBounds = NSZeroRect;

    if (!_isDrawing || !drawingMask)
    {
        goto ERROR;
    }

    if (_shouldUndoCurrentDrawing)
    {
        updateBounds = _drawingUndoBounds;

        [self undoCurrentDrawingAndForceDrawingLayerUpdate: NO];
    }

    drawBounds = NSIntersectionRect(drawBounds, _canvasFrame);

    if (!NSIsEmptyRect(drawBounds))
    {
        PPImageBitmapPixel fillPixelValue;

        fillPixelValue = (_penMode == kPPPenMode_Fill) ? _fillColorPixelValue_sRGB : 0;

        [_drawingLayerBitmap ppMaskedFillUsingMask: drawingMask
                                inBounds: drawBounds
                                fillPixelValue: fillPixelValue];

        updateBounds = NSUnionRect(updateBounds, drawBounds);
        _drawingUndoBounds = NSUnionRect(_drawingUndoBounds, drawBounds);

        if (_penMode == kPPPenMode_Erase)
        {
            [self mergeInteractiveEraseMaskWithMaskBitmap: drawingMask inBounds: drawBounds];
        }
    }

    if (!NSIsEmptyRect(updateBounds))
    {
        [self handleUpdateToDrawingLayerBitmapInBounds: updateBounds];
    }

    return;

ERROR:
    return;
}

- (void) undoCurrentDrawingAndForceDrawingLayerUpdate: (bool) shouldSendDrawingLayerUpdate
{
    if (!_isDrawing || !_shouldUndoCurrentDrawing)
    {
        return;
    }

    if (!NSIsEmptyRect(_drawingUndoBounds))
    {
        [_drawingLayerBitmap ppCopyFromBitmap: _drawingUndoBitmap
                                inRect: _drawingUndoBounds
                                toPoint: _drawingUndoBounds.origin];

        if (shouldSendDrawingLayerUpdate)
        {
            [self handleUpdateToDrawingLayerBitmapInBounds: _drawingUndoBounds];
        }

        _drawingUndoBounds = NSZeroRect;

        if (_penMode == kPPPenMode_Erase)
        {
            [self clearInteractiveEraseMask];
        }
    }

    _shouldUndoCurrentDrawing = NO;
}

- (void) prepareUndoDrawingInBounds: (NSRect) undoBounds
{
    NSData *undoBitmapTIFFData = [_drawingUndoBitmap ppCompressedTIFFDataFromBounds: undoBounds];

    if (!undoBitmapTIFFData)
        goto ERROR;

    [[[self undoManager] prepareWithInvocationTarget: self]
                                                undoDrawingWithTIFFData: undoBitmapTIFFData
                                                                atPoint: undoBounds.origin];

    [[self undoManager] setActionName: NSLocalizedString(@"Drawing", nil)];

    [_drawingUndoBitmap ppCopyFromBitmap: _drawingLayerBitmap
                            inRect: undoBounds
                            toPoint: undoBounds.origin];

    return;

ERROR:
    return;
}

- (void) undoDrawingWithTIFFData: (NSData *) undoBitmapTIFFData atPoint: (NSPoint) origin
{
    NSBitmapImageRep *undoBitmap;
    NSRect undoBounds;
    NSData *redoBitmapTIFFData;

    if (!undoBitmapTIFFData)
        goto ERROR;

    undoBitmap = [NSBitmapImageRep imageRepWithData: undoBitmapTIFFData];

    if (!undoBitmap)
        goto ERROR;

    undoBounds =
            NSMakeRect(origin.x, origin.y, [undoBitmap pixelsWide], [undoBitmap pixelsHigh]);

    redoBitmapTIFFData = [_drawingLayerBitmap ppCompressedTIFFDataFromBounds: undoBounds];

    [_drawingLayerBitmap ppCopyFromBitmap: undoBitmap toPoint: origin];
    [_drawingUndoBitmap ppCopyFromBitmap: undoBitmap toPoint: origin];

    [self handleUpdateToDrawingLayerBitmapInBounds: undoBounds];

    if (!redoBitmapTIFFData)
        goto ERROR;

    [[[self undoManager] prepareWithInvocationTarget: self]
                                                undoDrawingWithTIFFData: redoBitmapTIFFData
                                                                atPoint: origin];

    return;

ERROR:
    return;
}

- (void) mergeInteractiveEraseMaskWithMaskBitmap: (NSBitmapImageRep *) maskBitmap
            inBounds: (NSRect) maskBounds
{
    [_interactiveEraseMask ppMergeMaskWithMaskBitmap: maskBitmap inBounds: maskBounds];

    _interactiveEraseBounds = NSUnionRect(_interactiveEraseBounds, maskBounds);
}

- (void) clearInteractiveEraseMask
{
    if (NSIsEmptyRect(_interactiveEraseBounds))
    {
        return;
    }

    [_interactiveEraseMask ppClearBitmapInBounds: _interactiveEraseBounds];

    _interactiveEraseBounds = NSZeroRect;
}

@end
