/*
    PPDocument_Moving.m

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
#import "PPDocumentLayer.h"
#import "PPGeometry.h"


@interface PPDocument (MovingPrivateMethods)

- (void) handleUpdateToInteractiveMoveTargetBitmapInBounds: (NSRect) bounds;

- (void) performMoveOnOperationTarget: (PPLayerOperationTarget) operationTarget
            moveType: (PPMoveOperationType) moveType
            moveOffset: (NSPoint) offset
            nudgeDirectionName: (NSString *) nudgeDirectionName;

- (void) moveLayerAtIndex: (int) layerIndex
            byOffset: (NSPoint) offset
            andLeaveCopyInPlace: (bool) leaveCopyInPlace;

- (void) moveSelectionMaskByOffset: (NSPoint) offset;

- (NSPoint) moveOffsetForDirectionType: (PPDirectionType) directionType;
- (NSString *) nameOfDirectionType: (PPDirectionType) directionType;

- (bool) setupInteractiveMoveBitmaps;
- (void) destroyInteractiveMoveBitmaps;

- (void) setActionNameForMoveType: (PPMoveOperationType) moveType
            withTarget: (PPLayerOperationTarget) operationTarget
            nudgeDirectionName: (NSString *) nudgeDirectionName;

@end

@implementation PPDocument (Moving)

- (void) nudgeInDirection: (PPDirectionType) directionType
            moveType: (PPMoveOperationType) moveType
            target: (PPLayerOperationTarget) operationTarget
{
    if (!PPDirectionType_IsValid(directionType))
    {
        goto ERROR;
    }

    if (moveType == kPPMoveOperationType_LeaveCopyInPlace)
    {
        // nudge doesn't allow leaving a copy in place
        goto ERROR;
    }

    [self performMoveOnOperationTarget: operationTarget
            moveType: moveType
            moveOffset: [self moveOffsetForDirectionType: directionType]
            nudgeDirectionName: [self nameOfDirectionType: directionType]];

    return;

ERROR:
    return;
}

- (void) beginInteractiveMoveWithTarget: (PPLayerOperationTarget) operationTarget
            canvasDisplayMode: (PPLayerDisplayMode) canvasDisplayMode
            moveType: (PPMoveOperationType) moveType
{
    if (_isPerformingInteractiveMove)
        return;

    if (!PPLayerOperationTarget_IsValid(operationTarget)
        || !PPLayerDisplayMode_IsValid(canvasDisplayMode)
        || !PPMoveOperationType_IsValid(moveType))
    {
        goto ERROR;
    }

    if ((operationTarget == kPPLayerOperationTarget_DrawingLayerOnly)
        || (canvasDisplayMode == kPPLayerDisplayMode_DrawingLayerOnly))
    {
        _interactiveMoveDisplayMode = kPPLayerDisplayMode_DrawingLayerOnly;
    }
    else
    {
        _interactiveMoveDisplayMode = kPPLayerDisplayMode_VisibleLayers;
    }

    _interactiveMoveOperationTarget = operationTarget;

    if (![self setupInteractiveMoveBitmaps])
    {
        goto ERROR;
    }

    _interactiveMoveInitialSelectionBounds = _selectionBounds;

    if (moveType == kPPMoveOperationType_Normal)
    {
        [_interactiveMoveUnderlyingBitmap
                                ppMaskedEraseUsingMask: _interactiveMoveInitialSelectionMask
                                inBounds: _interactiveMoveInitialSelectionBounds];
    }

    _lastInteractiveMoveType = moveType;
    _lastInteractiveMoveOffset = NSZeroPoint;
    _lastInteractiveMoveBounds = (_hasSelection) ? _selectionBounds : _canvasFrame;

    // improve drawing performance by disabling thumbnail updates until the move's done
    [self disableThumbnailImageUpdateNotifications: YES];

    _isPerformingInteractiveMove = YES;

    return;

ERROR:
    return;
}

- (void) setInteractiveMoveOffset: (NSPoint) offset
            andMoveType: (PPMoveOperationType) moveType
{
    NSRect moveBounds = NSZeroRect, updateRect = NSZeroRect;

    if (!_isPerformingInteractiveMove)
        return;

    if (!PPMoveOperationType_IsValid(moveType))
    {
        moveType = kPPMoveOperationType_Normal;
    }

    if (NSEqualPoints(offset, _lastInteractiveMoveOffset)
        && (moveType == _lastInteractiveMoveType))
    {
        return;
    }

    if (_hasSelection)
    {
        NSPoint moveOrigin;

        if (moveType != _lastInteractiveMoveType)
        {
            if (moveType == kPPMoveOperationType_Normal)
            {
                [_interactiveMoveUnderlyingBitmap
                                ppMaskedEraseUsingMask: _interactiveMoveInitialSelectionMask
                                inBounds: _interactiveMoveInitialSelectionBounds];
            }
            else
            {
                [_interactiveMoveUnderlyingBitmap
                                ppCopyFromBitmap: _interactiveMoveFloatingBitmap
                                toPoint: _interactiveMoveInitialSelectionBounds.origin];

            }

            [_interactiveMoveTargetBitmap
                                    ppCopyFromBitmap: _interactiveMoveUnderlyingBitmap
                                    inRect: _interactiveMoveInitialSelectionBounds
                                    toPoint: _interactiveMoveInitialSelectionBounds.origin];

            updateRect = NSUnionRect(updateRect, _interactiveMoveInitialSelectionBounds);
        }

        if (!NSIsEmptyRect(_lastInteractiveMoveBounds))
        {
            if (_lastInteractiveMoveType != kPPMoveOperationType_SelectionOutlineOnly)
            {
                [_interactiveMoveTargetBitmap ppCopyFromBitmap:
                                                            _interactiveMoveUnderlyingBitmap
                                                inRect: _lastInteractiveMoveBounds
                                                toPoint: _lastInteractiveMoveBounds.origin];

                updateRect = NSUnionRect(updateRect, _lastInteractiveMoveBounds);
            }
        }

        moveOrigin = PPGeometry_PointSum(_interactiveMoveInitialSelectionBounds.origin, offset);

        moveBounds.origin = moveOrigin;
        moveBounds.size = _interactiveMoveInitialSelectionBounds.size;
        moveBounds = NSIntersectionRect(moveBounds, _canvasFrame);

        if (!NSIsEmptyRect(moveBounds))
        {
            if (moveType != kPPMoveOperationType_SelectionOutlineOnly)
            {
                [_interactiveMoveTargetBitmap
                                ppMaskedCopyFromImageBitmap: _interactiveMoveFloatingBitmap
                                usingMask: _interactiveMoveFloatingMask
                                toPoint: moveOrigin];

                updateRect = NSUnionRect(updateRect, moveBounds);
            }
        }

        if (!NSEqualRects(_lastInteractiveMoveBounds, moveBounds))
        {
            if (!NSIsEmptyRect(_lastInteractiveMoveBounds))
            {
                [_selectionMask ppClearBitmapInBounds: _lastInteractiveMoveBounds];
            }

            if (!NSIsEmptyRect(moveBounds))
            {
                [_selectionMask ppCopyFromBitmap: _interactiveMoveFloatingMask
                                toPoint: moveOrigin];
            }

            _selectionBounds = [_selectionMask ppMaskBoundsInRect: moveBounds];

            [self postNotification_UpdatedSelection];
        }
    }
    else
    {
        if (_lastInteractiveMoveType != moveType)
        {
            _lastInteractiveMoveBounds = _canvasFrame;
        }

        if (moveType == kPPMoveOperationType_Normal)
        {
            [_interactiveMoveTargetBitmap ppClearBitmapInBounds: _lastInteractiveMoveBounds];
        }
        else
        {
            [_interactiveMoveTargetBitmap ppCopyFromBitmap: _interactiveMoveUnderlyingBitmap
                                            inRect: _lastInteractiveMoveBounds
                                            toPoint: _lastInteractiveMoveBounds.origin];
        }

        if (moveType != kPPMoveOperationType_SelectionOutlineOnly)
        {
            [_interactiveMoveTargetBitmap ppCopyFromBitmap: _interactiveMoveUnderlyingBitmap
                                            toPoint: offset];
        }

        moveBounds =
            NSIntersectionRect(NSOffsetRect(_canvasFrame, offset.x, offset.y), _canvasFrame);

        updateRect = NSUnionRect(moveBounds, _lastInteractiveMoveBounds);
    }

    _lastInteractiveMoveType = moveType;
    _lastInteractiveMoveOffset = offset;
    _lastInteractiveMoveBounds = moveBounds;

    updateRect = NSIntersectionRect(updateRect, _canvasFrame);

    [self handleUpdateToInteractiveMoveTargetBitmapInBounds: updateRect];
}

- (void) finishInteractiveMove
{
    NSRect updateRect = NSZeroRect;

    if (!_isPerformingInteractiveMove)
        return;

    if (_hasSelection)
    {
        if (!NSIsEmptyRect(_lastInteractiveMoveBounds))
        {
            [_interactiveMoveTargetBitmap ppCopyFromBitmap: _interactiveMoveUnderlyingBitmap
                                            inRect: _lastInteractiveMoveBounds
                                            toPoint: _lastInteractiveMoveBounds.origin];

            [_selectionMask ppClearBitmapInBounds: _lastInteractiveMoveBounds];

            updateRect = NSUnionRect(updateRect, _lastInteractiveMoveBounds);
        }

        if (_lastInteractiveMoveType == kPPMoveOperationType_Normal)
        {
            [_interactiveMoveTargetBitmap
                                    ppCopyFromBitmap: _interactiveMoveFloatingBitmap
                                    toPoint: _interactiveMoveInitialSelectionBounds.origin];

            updateRect = NSUnionRect(updateRect, _interactiveMoveInitialSelectionBounds);
        }

        [_selectionMask ppCopyFromBitmap: _interactiveMoveFloatingMask
                        toPoint: _interactiveMoveInitialSelectionBounds.origin];

        _selectionBounds = _interactiveMoveInitialSelectionBounds;
    }
    else
    {
        updateRect = (_lastInteractiveMoveType == kPPMoveOperationType_Normal) ?
                        _canvasFrame : _lastInteractiveMoveBounds;

        [_interactiveMoveTargetBitmap ppCopyFromBitmap: _interactiveMoveUnderlyingBitmap
                                        inRect: updateRect
                                        toPoint: updateRect.origin];
    }

    updateRect = NSIntersectionRect(updateRect, _canvasFrame);

    [self handleUpdateToInteractiveMoveTargetBitmapInBounds: updateRect];

    [self destroyInteractiveMoveBitmaps];

    _isPerformingInteractiveMove = NO;

    [self disableThumbnailImageUpdateNotifications: NO];

    if (NSEqualPoints(_lastInteractiveMoveOffset, NSZeroPoint))
    {
        return;
    }

    [self performMoveOnOperationTarget: _interactiveMoveOperationTarget
            moveType: _lastInteractiveMoveType
            moveOffset: _lastInteractiveMoveOffset
            nudgeDirectionName: nil];
}

#pragma mark Private methods

// handleUpdateToInteractiveMoveTargetBitmapInBounds: method is a patch target on GNUstep
// (PPGNUstepGlue_ImageRecacheSpeedups)

- (void) handleUpdateToInteractiveMoveTargetBitmapInBounds: (NSRect) bounds
{
    if (NSIsEmptyRect(bounds))
    {
        return;
    }

    if (_interactiveMoveDisplayMode == kPPLayerDisplayMode_DrawingLayerOnly)
    {
        [_drawingLayer handleUpdateToBitmapInRect: bounds];

        [self handleUpdateToLayerAtIndex: _indexOfDrawingLayer inRect: bounds];
    }
    else
    {
        [_mergedVisibleLayersThumbnailImage recache];

        [self postNotification_UpdatedMergedVisibleAreaInRect: bounds];
    }
}

- (void) performMoveOnOperationTarget: (PPLayerOperationTarget) operationTarget
            moveType: (PPMoveOperationType) moveType
            moveOffset: (NSPoint) offset
            nudgeDirectionName: (NSString *) nudgeDirectionName
{
    if (NSEqualPoints(offset, NSZeroPoint)
        || !PPMoveOperationType_IsValid(moveType))
    {
        goto ERROR;
    }

    if (moveType != kPPMoveOperationType_SelectionOutlineOnly)
    {
        if (!PPLayerOperationTarget_IsValid(operationTarget))
        {
            goto ERROR;
        }

        [self setupTargetLayerIndexesForOperationTarget: operationTarget];

        if (!_numTargetLayerIndexes)
        {
            moveType = kPPMoveOperationType_SelectionOutlineOnly;
        }
    }

    if (moveType == kPPMoveOperationType_SelectionOutlineOnly)
    {
        if (!_hasSelection)
            goto ERROR;
    }
    else    // (moveType != kPPMoveOperationType_SelectionOutlineOnly)
    {
        bool isMultilayerOperation, leaveCopyInPlace;
        int i;

        isMultilayerOperation = (_numTargetLayerIndexes > 1) ? YES : NO;

        if (isMultilayerOperation)
        {
            [self beginMultilayerOperation];
        }

        leaveCopyInPlace = (moveType == kPPMoveOperationType_LeaveCopyInPlace) ? YES : NO;

        for (i=0; i<_numTargetLayerIndexes; i++)
        {
            [self moveLayerAtIndex: _targetLayerIndexes[i]
                    byOffset: offset
                    andLeaveCopyInPlace: leaveCopyInPlace];
        }

        if (isMultilayerOperation)
        {
            [self finishMultilayerOperation];
        }
    }

    if (_hasSelection)
    {
        [self moveSelectionMaskByOffset: offset];
    }

    [self setActionNameForMoveType: moveType
            withTarget: operationTarget
            nudgeDirectionName: nudgeDirectionName];

    return;

ERROR:
    return;
}

- (void) moveLayerAtIndex: (int) layerIndex
            byOffset: (NSPoint) offset
            andLeaveCopyInPlace: (bool) leaveCopyInPlace
{
    PPDocumentLayer *layer;
    NSBitmapImageRep *layerBitmap, *updateBitmap;
    NSRect updateBounds;

    layer = [self layerAtIndex: layerIndex];
    layerBitmap = [layer bitmap];

    if (!layer || !layerBitmap)
    {
        goto ERROR;
    }

    if (_hasSelection)
    {
        NSPoint updateCopyPoint;

        updateBounds.size = _selectionBounds.size;
        updateBounds.origin = PPGeometry_PointSum(_selectionBounds.origin, offset);

        if (!leaveCopyInPlace)
        {
            updateBounds = NSUnionRect(updateBounds, _selectionBounds);
        }

        updateBounds = NSIntersectionRect(updateBounds, _canvasFrame);

        if (NSIsEmptyRect(updateBounds))
        {
            goto ERROR;
        }

        updateBitmap = [layerBitmap ppBitmapCroppedToBounds: updateBounds];

        if (!updateBitmap)
            goto ERROR;

        if (!leaveCopyInPlace)
        {
            NSBitmapImageRep *updateMask =
                                [_selectionMask ppShallowDuplicateFromBounds: updateBounds];

            if (!updateMask)
                goto ERROR;

            [updateBitmap ppMaskedEraseUsingMask: updateMask];
        }

        updateCopyPoint = PPGeometry_PointDifference(offset, updateBounds.origin);

        [updateBitmap ppMaskedCopyFromImageBitmap: layerBitmap
                        usingMask: _selectionMask
                        toPoint: updateCopyPoint];
    }
    else
    {
        if (!leaveCopyInPlace)
        {
            updateBounds = _canvasFrame;

            updateBitmap = [NSBitmapImageRep ppImageBitmapOfSize: updateBounds.size];

            [updateBitmap ppCopyFromBitmap: layerBitmap toPoint: offset];
        }
        else
        {
            NSRect moveSourceBounds;

            updateBounds.size = _canvasFrame.size;
            updateBounds.origin = PPGeometry_PointSum(_canvasFrame.origin, offset);
            updateBounds = NSIntersectionRect(updateBounds, _canvasFrame);

            moveSourceBounds.size = updateBounds.size;
            moveSourceBounds.origin = PPGeometry_PointDifference(updateBounds.origin, offset);

            updateBitmap = [layerBitmap ppBitmapCroppedToBounds: moveSourceBounds];
        }

        if (!updateBitmap)
            goto ERROR;
    }

    [self copyImageBitmap: updateBitmap toLayerAtIndex: layerIndex atPoint: updateBounds.origin];

    return;

ERROR:
    return;
}

- (void) moveSelectionMaskByOffset: (NSPoint) offset
{
    NSRect updateBounds;
    NSBitmapImageRep *updateMask;
    NSPoint updateMaskSelectionBoundsOrigin;

    updateBounds.size = _selectionBounds.size;
    updateBounds.origin = PPGeometry_PointSum(_selectionBounds.origin, offset);
    updateBounds = NSIntersectionRect(NSUnionRect(updateBounds, _selectionBounds),
                                        _canvasFrame);

    updateMask = [NSBitmapImageRep ppMaskBitmapOfSize: updateBounds.size];

    if (!updateMask)
        goto ERROR;

    updateMaskSelectionBoundsOrigin =
        NSMakePoint(_selectionBounds.origin.x + offset.x - updateBounds.origin.x,
                    _selectionBounds.origin.y + offset.y - updateBounds.origin.y);

    [updateMask ppCopyFromBitmap: _selectionMask
                inRect: _selectionBounds
                toPoint: updateMaskSelectionBoundsOrigin];

    [self setSelectionMaskAreaWithBitmap: updateMask atPoint: updateBounds.origin];

    return;

ERROR:
    return;
}

- (NSPoint) moveOffsetForDirectionType: (PPDirectionType) directionType
{
    switch (directionType)
    {
        case kPPDirectionType_Left:
            return NSMakePoint(-1.0f, 0.0f);
        break;

        case kPPDirectionType_Right:
            return NSMakePoint(1.0f, 0.0f);
        break;

        case kPPDirectionType_Up:
            return NSMakePoint(0.0f, 1.0f);
        break;

        case kPPDirectionType_Down:
            return NSMakePoint(0.0f, -1.0f);
        break;

        default:
            return NSZeroPoint;
        break;
    }
}

- (NSString *) nameOfDirectionType: (PPDirectionType) directionType
{
    switch (directionType)
    {
        case kPPDirectionType_Left:
            return @"Left";
        break;

        case kPPDirectionType_Right:
            return @"Right";
        break;

        case kPPDirectionType_Up:
            return @"Up";
        break;

        case kPPDirectionType_Down:
            return @"Down";
        break;

        default:
            return @"";
        break;
    }
}

- (bool) setupInteractiveMoveBitmaps
{
    _interactiveMoveTargetBitmap =
        (_interactiveMoveDisplayMode == kPPLayerDisplayMode_DrawingLayerOnly) ?
            _drawingLayerBitmap : _mergedVisibleLayersBitmap;

    [_interactiveMoveTargetBitmap retain];

    _interactiveMoveUnderlyingBitmap = [_interactiveMoveTargetBitmap copy];

    if (!_interactiveMoveUnderlyingBitmap)
        goto ERROR;

    if (_hasSelection)
    {
        _interactiveMoveInitialSelectionMask = [_selectionMask copy];

        _interactiveMoveFloatingBitmap =
            [[_interactiveMoveTargetBitmap ppBitmapCroppedToBounds: _selectionBounds] retain];

        _interactiveMoveFloatingMask =
            [[_selectionMask ppBitmapCroppedToBounds: _selectionBounds] retain];

        if (!_interactiveMoveInitialSelectionMask
            || !_interactiveMoveFloatingBitmap
            || !_interactiveMoveFloatingMask)
        {
            goto ERROR;
        }
    }

    return YES;

ERROR:
    [self destroyInteractiveMoveBitmaps];

    return NO;
}

- (void) destroyInteractiveMoveBitmaps
{
    [_interactiveMoveTargetBitmap release];
    _interactiveMoveTargetBitmap = nil;

    [_interactiveMoveUnderlyingBitmap release];
    _interactiveMoveUnderlyingBitmap = nil;

    [_interactiveMoveInitialSelectionMask release];
    _interactiveMoveInitialSelectionMask = nil;

    [_interactiveMoveFloatingBitmap release];
    _interactiveMoveFloatingBitmap = nil;

    [_interactiveMoveFloatingMask release];
    _interactiveMoveFloatingMask = nil;
}

- (void) setActionNameForMoveType: (PPMoveOperationType) moveType
            withTarget: (PPLayerOperationTarget) operationTarget
            nudgeDirectionName: (NSString *) nudgeDirectionName
{
    NSUndoManager *undoManager;
    NSString *operationName = nil, *targetName = nil, *actionName;

    undoManager = [self undoManager];

    if ([undoManager isUndoing] || [undoManager isRedoing])
    {
        return;
    }

    if (nudgeDirectionName)
    {
        operationName = [NSString stringWithFormat: @"Nudge %@", nudgeDirectionName];
    }

    if (!operationName)
    {
        operationName = @"Move";
    }

    if (moveType == kPPMoveOperationType_SelectionOutlineOnly)
    {
        targetName = @"Selection Outline";
    }
    else
    {
        targetName = [self nameWithSelectionStateForLayerOperationTarget: operationTarget];

        if (!targetName)
            goto ERROR;

        if (moveType == kPPMoveOperationType_LeaveCopyInPlace)
        {
            targetName = [NSString stringWithFormat: @"Copy of %@", targetName];

            if (!targetName)
                goto ERROR;
        }
    }

    actionName = [NSString stringWithFormat: @"%@ (%@)", operationName, targetName];

    if (!actionName)
        goto ERROR;

    [undoManager setActionName: actionName];

    return;

ERROR:
    actionName = [NSString stringWithFormat: @"%@ (UNKNOWN)", operationName];

    if (!actionName)
    {
        actionName = operationName;
    }

    [undoManager setActionName: actionName];

    return;
}

@end
