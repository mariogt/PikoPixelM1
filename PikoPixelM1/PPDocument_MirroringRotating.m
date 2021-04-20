/*
    PPDocument_MirroringRotating.m

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

#import "NSBitmapImageRep_PPUtilities.h"
#import "PPDocumentLayer.h"
#import "PPGeometry.h"


#define kMirrorRotateOperationName_MirrorHorizontally           @"Flip Horizontally"
#define kMirrorRotateOperationName_MirrorVertically             @"Flip Vertically"

#if PP_SDK_ALLOWS_NONASCII_STRING_LITERALS

#   define kMirrorRotateOperationName_Rotate180                 @"Rotate 180°"
#   define kMirrorRotateOperationName_Rotate90Clockwise         @"Rotate 90° Clockwise"
#   define kMirrorRotateOperationName_Rotate90Counterclockwise  @"Rotate 90° Counterclockwise"

#else   // SDK requires ASCII string literals

#   define kMirrorRotateOperationName_Rotate180                 @"Rotate 180"
#   define kMirrorRotateOperationName_Rotate90Clockwise         @"Rotate 90 Clockwise"
#   define kMirrorRotateOperationName_Rotate90Counterclockwise  @"Rotate 90 Counterclockwise"

#endif  // PP_SDK_ALLOWS_NONASCII_STRING_LITERALS


typedef enum
{
    kPPMirrorRotateOperationType_MirrorHorizontally,
    kPPMirrorRotateOperationType_MirrorVertically,
    kPPMirrorRotateOperationType_Rotate180,
    kPPMirrorRotateOperationType_Rotate90Clockwise,
    kPPMirrorRotateOperationType_Rotate90Counterclockwise

} PPMirrorRotateOperationType;


static SEL NSBitmapImagRepPPUtilitiesSelectorForOperation(
                                                    PPMirrorRotateOperationType operation);

static bool OperationIsRotate90(PPMirrorRotateOperationType operation);

static void GetCleanupRectsForRotate90InBounds(NSRect bounds,
                                                NSRect *returnedCleanupRect1,
                                                NSRect *returnedCleanupRect2);


@interface PPDocument (MirroringRotatingPrivateMethods)

- (void) performOperation: (PPMirrorRotateOperationType) operation
            onTarget: (PPLayerOperationTarget) operationTarget;

- (bool) getDestinationOrigin: (NSPoint *) returnedDestinationOrigin
            preOperationCroppedMask: (NSBitmapImageRep **) returnedPreOperationCroppedMask
            andPostOperationCroppedMask: (NSBitmapImageRep **) returnedPostOperationCroppedMask
            forOperation: (PPMirrorRotateOperationType) operation;

- (void) performOperationWithSelector: (SEL) operationSelector
            onLayerWithIndex: (int) index
            destinationOrigin: (NSPoint) destinationOrigin
            preOperationCroppedMask: (NSBitmapImageRep *) preOperationCroppedMask
            postOperationCroppedMask: (NSBitmapImageRep *) postOperationCroppedMask
            preAndPostCroppedMasksAreEqual: (bool) preAndPostCroppedMasksAreEqual
            operationIsRotate90: (bool) operationIsRotate90;

- (bool) rotateNonsquareCanvas90WithOperationSelector: (SEL) operationSelector;

- (void) setUndoActionNameForOperation: (PPMirrorRotateOperationType) operation
            withTargetName: (NSString *) targetName;

@end

@implementation PPDocument (MirroringRotating)

- (void) mirrorHorizontallyWithTarget: (PPLayerOperationTarget) operationTarget
{
    [self performOperation: kPPMirrorRotateOperationType_MirrorHorizontally
                onTarget: operationTarget];
}

- (void) mirrorVerticallyWithTarget: (PPLayerOperationTarget) operationTarget
{
    [self performOperation: kPPMirrorRotateOperationType_MirrorVertically
                onTarget: operationTarget];
}

- (void) rotate180WithTarget: (PPLayerOperationTarget) operationTarget
{
    [self performOperation: kPPMirrorRotateOperationType_Rotate180
                onTarget: operationTarget];
}

- (void) rotate90ClockwiseWithTarget: (PPLayerOperationTarget) operationTarget
{
    [self performOperation: kPPMirrorRotateOperationType_Rotate90Clockwise
                onTarget: operationTarget];
}

- (void) rotate90CounterclockwiseWithTarget: (PPLayerOperationTarget) operationTarget
{
    [self performOperation: kPPMirrorRotateOperationType_Rotate90Counterclockwise
                onTarget: operationTarget];
}

#pragma mark Private methods

- (void) performOperation: (PPMirrorRotateOperationType) operation
            onTarget: (PPLayerOperationTarget) operationTarget
{
    SEL operationSelector;
    bool operationIsRotate90, operationIsReversible, isMultilayerOperation;
    NSString *targetName;
    NSPoint destinationOrigin = NSZeroPoint;
    NSBitmapImageRep *preOperationCroppedMask = nil, *postOperationCroppedMask = nil;
    NSUndoManager *undoManager;
    int i;

    operationSelector = NSBitmapImagRepPPUtilitiesSelectorForOperation(operation);

    if (!operationSelector)
        goto ERROR;

    operationIsRotate90 = OperationIsRotate90(operation);

    if (operationTarget == kPPLayerOperationTarget_Canvas)
    {
        if (operationIsRotate90 && !PPGeometry_RectIsSquare(_canvasFrame))
        {
            if ([self rotateNonsquareCanvas90WithOperationSelector: operationSelector])
            {
                targetName =
                        [self nameWithSelectionStateForLayerOperationTarget: operationTarget];

                [self setUndoActionNameForOperation: operation withTargetName: targetName];
            }

            return;
        }
        else
        {
            operationIsReversible = YES;
        }
    }
    else
    {
        if (_hasSelection)
        {
            if (![self getDestinationOrigin: &destinationOrigin
                        preOperationCroppedMask: &preOperationCroppedMask
                        andPostOperationCroppedMask: &postOperationCroppedMask
                        forOperation: operation])
            {
                goto ERROR;
            }

            operationIsReversible =
                        [preOperationCroppedMask ppIsEqualToBitmap: postOperationCroppedMask];
        }
        else
        {
            if (operationIsRotate90 && !PPGeometry_RectIsSquare(_canvasFrame))
            {
                if (![self getDestinationOrigin: &destinationOrigin
                            preOperationCroppedMask: NULL
                            andPostOperationCroppedMask: NULL
                            forOperation: operation])
                {
                    goto ERROR;
                }

                operationIsReversible = NO;
            }
            else
            {
                operationIsReversible = YES;
            }
        }
    }

    [self setupTargetLayerIndexesForOperationTarget: operationTarget];

    if (!_numTargetLayerIndexes && !_hasSelection)
    {
        goto ERROR;
    }

    undoManager = [self undoManager];

    if (operationIsReversible)
    {
        [undoManager disableUndoRegistration];
    }

    isMultilayerOperation = (_numTargetLayerIndexes > 1) ? YES : NO;

    if (isMultilayerOperation)
    {
        [self beginMultilayerOperation];
    }

    for (i=0; i<_numTargetLayerIndexes; i++)
    {
        [self performOperationWithSelector: operationSelector
                        onLayerWithIndex: _targetLayerIndexes[i]
                        destinationOrigin: destinationOrigin
                        preOperationCroppedMask: preOperationCroppedMask
                        postOperationCroppedMask: postOperationCroppedMask
                        preAndPostCroppedMasksAreEqual: operationIsReversible
                        operationIsRotate90: operationIsRotate90];
    }

    if (isMultilayerOperation)
    {
        [self finishMultilayerOperation];
    }

    if (_hasSelection)
    {
        if (operationTarget == kPPLayerOperationTarget_Canvas)
        {
            NSBitmapImageRep *postOperationSelectionMask =
                                            [_selectionMask performSelector: operationSelector];

            if (![_selectionMask ppIsEqualToBitmap: postOperationSelectionMask])
            {
                [self setSelectionMaskAreaWithBitmap: postOperationSelectionMask
                        atPoint: NSZeroPoint];
            }
        }
        else if (!operationIsReversible)
        {
            if (operationIsRotate90 && !PPGeometry_RectIsSquare(_selectionBounds))
            {
                NSRect cleanupRects[2] = {NSZeroRect, NSZeroRect};

                GetCleanupRectsForRotate90InBounds(_selectionBounds, &cleanupRects[0],
                                                    &cleanupRects[1]);

                for (i=0; i<2; i++)
                {
                    if (!NSIsEmptyRect(cleanupRects[i]))
                    {
                        [self setSelectionMaskAreaWithBitmap:
                                    [NSBitmapImageRep ppMaskBitmapOfSize: cleanupRects[i].size]
                                atPoint: cleanupRects[i].origin];
                    }
                }
            }

            [self setSelectionMaskAreaWithBitmap: postOperationCroppedMask
                                        atPoint: destinationOrigin];
        }
    }

    if (operationIsReversible)
    {
        PPMirrorRotateOperationType reverseOperation;

        [undoManager enableUndoRegistration];

        if (operationIsRotate90)
        {
            reverseOperation = (operation == kPPMirrorRotateOperationType_Rotate90Clockwise)
                                ? kPPMirrorRotateOperationType_Rotate90Counterclockwise
                                    : kPPMirrorRotateOperationType_Rotate90Clockwise;
        }
        else
        {
            reverseOperation = operation;
        }

        [[undoManager prepareWithInvocationTarget: self] performOperation: reverseOperation
                                                            onTarget: operationTarget];
    }

    if (_numTargetLayerIndexes > 0)
    {
        targetName = [self nameWithSelectionStateForLayerOperationTarget: operationTarget];
    }
    else
    {
        targetName = @"Selection Outline";
    }

    [self setUndoActionNameForOperation: operation withTargetName: targetName];

    return;

ERROR:
    return;
}

- (bool) getDestinationOrigin: (NSPoint *) returnedDestinationOrigin
            preOperationCroppedMask: (NSBitmapImageRep **) returnedPreOperationCroppedMask
            andPostOperationCroppedMask: (NSBitmapImageRep **) returnedPostOperationCroppedMask
            forOperation: (PPMirrorRotateOperationType) operation
{
    SEL operationSelector;
    NSRect operationBounds;

    if (!returnedDestinationOrigin
        || (_hasSelection
                && (!returnedPreOperationCroppedMask || !returnedPostOperationCroppedMask)))
    {
        goto ERROR;
    }

    operationSelector = NSBitmapImagRepPPUtilitiesSelectorForOperation(operation);

    if (!operationSelector)
        goto ERROR;

    if (_hasSelection)
    {
        NSBitmapImageRep *preOperationCroppedMask, *postOperationCroppedMask;

        preOperationCroppedMask = [_selectionMask ppBitmapCroppedToBounds: _selectionBounds];

        postOperationCroppedMask = [preOperationCroppedMask performSelector: operationSelector];

        if (!preOperationCroppedMask || !postOperationCroppedMask)
        {
            goto ERROR;
        }

        *returnedPreOperationCroppedMask = preOperationCroppedMask;
        *returnedPostOperationCroppedMask = postOperationCroppedMask;

        operationBounds = _selectionBounds;
    }
    else
    {
        if (returnedPreOperationCroppedMask)
        {
            *returnedPreOperationCroppedMask = nil;
        }

        if (returnedPostOperationCroppedMask)
        {
            *returnedPostOperationCroppedMask = nil;
        }

        operationBounds = _canvasFrame;
    }

    if (OperationIsRotate90(operation))
    {
        operationBounds = PPGeometry_CenterRectInRect(NSMakeRect(0.0f, 0.0f,
                                                                operationBounds.size.height,
                                                                operationBounds.size.width),
                                                        operationBounds);
    }

    *returnedDestinationOrigin = operationBounds.origin;

    return YES;

ERROR:
    return NO;
}

- (void) performOperationWithSelector: (SEL) operationSelector
            onLayerWithIndex: (int) index
            destinationOrigin: (NSPoint) destinationOrigin
            preOperationCroppedMask: (NSBitmapImageRep *) preOperationCroppedMask
            postOperationCroppedMask: (NSBitmapImageRep *) postOperationCroppedMask
            preAndPostCroppedMasksAreEqual: (bool) preAndPostCroppedMasksAreEqual
            operationIsRotate90: (bool) operationIsRotate90
{
    PPDocumentLayer *layer;
    NSBitmapImageRep *layerBitmap;

    if (!operationSelector)
        goto ERROR;

    layer = [self layerAtIndex: index];
    layerBitmap = [layer bitmap];

    if (!layer || !layerBitmap)
    {
        goto ERROR;
    }

    if (preOperationCroppedMask)
    {
        NSBitmapImageRep *updatedAreaBitmap, *operatedBitmap;

        if (!postOperationCroppedMask)
            goto ERROR;

        updatedAreaBitmap = [layerBitmap ppBitmapCroppedToBounds: _selectionBounds];
        operatedBitmap = [updatedAreaBitmap performSelector: operationSelector];

        if (!updatedAreaBitmap || !operatedBitmap)
        {
            goto ERROR;
        }

        if (!preAndPostCroppedMasksAreEqual)
        {
            [updatedAreaBitmap ppMaskedEraseUsingMask: preOperationCroppedMask];
        }

        if (operationIsRotate90 && !PPGeometry_RectIsSquare(_selectionBounds))
        {
            NSRect postOperationBounds;

            [self copyImageBitmap: updatedAreaBitmap
                    toLayerAtIndex: index
                    atPoint: _selectionBounds.origin];

            postOperationBounds.origin = destinationOrigin;
            postOperationBounds.size = [postOperationCroppedMask ppSizeInPixels];

            updatedAreaBitmap = [layerBitmap ppBitmapCroppedToBounds: postOperationBounds];
        }

        [updatedAreaBitmap ppMaskedCopyFromImageBitmap: operatedBitmap
                            usingMask: postOperationCroppedMask];

        [self copyImageBitmap: updatedAreaBitmap
                toLayerAtIndex: index
                atPoint: destinationOrigin];
    }
    else
    {
        NSBitmapImageRep *operatedBitmap;

        operatedBitmap = [layerBitmap performSelector: operationSelector];

        if (!operatedBitmap)
            goto ERROR;

        [self copyImageBitmap: operatedBitmap toLayerAtIndex: index atPoint: destinationOrigin];

        if (operationIsRotate90 && !PPGeometry_RectIsSquare(_canvasFrame))
        {
            NSRect cleanupRects[2] = {NSZeroRect, NSZeroRect};
            int i;

            GetCleanupRectsForRotate90InBounds(_canvasFrame, &cleanupRects[0],
                                                &cleanupRects[1]);

            for (i=0; i<2; i++)
            {
                if (!NSIsEmptyRect(cleanupRects[i]))
                {
                    [self copyImageBitmap:
                                [NSBitmapImageRep ppImageBitmapOfSize: cleanupRects[i].size]
                            toLayerAtIndex: index
                            atPoint: cleanupRects[i].origin];
                }
            }
        }
    }

    return;

ERROR:
    return;
}

- (bool) rotateNonsquareCanvas90WithOperationSelector: (SEL) operationSelector
{
    NSMutableArray *rotatedLayers;
    NSEnumerator *layerEnumerator;
    PPDocumentLayer *layer, *rotatedLayer;
    NSSize layerSize;
    NSRect rotatedLayerFrame = NSZeroRect;
    NSBitmapImageRep *rotatedLayerBitmap, *rotatedSelectionMask = nil;

    if (!operationSelector)
        goto ERROR;

    rotatedLayers = [NSMutableArray array];

    if (!rotatedLayers)
        goto ERROR;

    layerEnumerator = [_layers objectEnumerator];

    while (layer = [layerEnumerator nextObject])
    {
        layerSize = [layer size];

        rotatedLayerFrame = NSMakeRect(0, 0, layerSize.height, layerSize.width);

        rotatedLayer =
            [[[PPDocumentLayer alloc]
                                initWithSize: rotatedLayerFrame.size
                                name: [layer name]
                                tiffData: nil
                                opacity: [layer opacity]
                                isEnabled: [layer isEnabled]]
                            autorelease];


        rotatedLayerBitmap = [[layer bitmap] performSelector: operationSelector];

        if (!rotatedLayer || !rotatedLayerBitmap)
        {
            goto ERROR;
        }

        [[rotatedLayer bitmap] ppCopyFromBitmap: rotatedLayerBitmap
                                toPoint: NSZeroPoint];

        [rotatedLayer handleUpdateToBitmapInRect: rotatedLayerFrame];

        [rotatedLayers addObject: rotatedLayer];
    }

    if ([rotatedLayers count] != _numLayers)
    {
        goto ERROR;
    }

    if (_hasSelection)
    {
        rotatedSelectionMask = [_selectionMask performSelector: operationSelector];
    }

    [self setLayers: rotatedLayers];

    if (rotatedSelectionMask)
    {
        [self setSelectionMask: rotatedSelectionMask];
    }

    return YES;

ERROR:
    return NO;
}

- (void) setUndoActionNameForOperation: (PPMirrorRotateOperationType) operation
            withTargetName: (NSString *) targetName
{
    NSUndoManager *undoManager;
    NSString *operationName, *actionName = nil;

    undoManager = [self undoManager];

    if ([undoManager isUndoing] || [undoManager isRedoing])
    {
        return;
    }

    switch (operation)
    {
        case kPPMirrorRotateOperationType_MirrorHorizontally:
        {
            operationName = kMirrorRotateOperationName_MirrorHorizontally;
        }
        break;

        case kPPMirrorRotateOperationType_MirrorVertically:
        {
            operationName = kMirrorRotateOperationName_MirrorVertically;
        }
        break;

        case kPPMirrorRotateOperationType_Rotate180:
        {
            operationName = kMirrorRotateOperationName_Rotate180;
        }
        break;

        case kPPMirrorRotateOperationType_Rotate90Clockwise:
        {
            operationName = kMirrorRotateOperationName_Rotate90Clockwise;
        }
        break;

        case kPPMirrorRotateOperationType_Rotate90Counterclockwise:
        {
            operationName = kMirrorRotateOperationName_Rotate90Counterclockwise;
        }
        break;

        default:
        {
            operationName = @"Flip/Rotate";
        }
        break;
    }

    if (targetName)
    {
        actionName = [NSString stringWithFormat: @"%@ (%@)", operationName, targetName];
    }

    if (!actionName)
    {
        actionName = operationName;
    }

    [undoManager setActionName: NSLocalizedString(actionName, nil)];
}

@end

#pragma mark Private functions

static SEL NSBitmapImagRepPPUtilitiesSelectorForOperation(PPMirrorRotateOperationType operation)
{
    SEL operationSelector;

    switch (operation)
    {
        case kPPMirrorRotateOperationType_MirrorHorizontally:
        {
            operationSelector = @selector(ppBitmapMirroredHorizontally);
        }
        break;

        case kPPMirrorRotateOperationType_MirrorVertically:
        {
            operationSelector = @selector(ppBitmapMirroredVertically);
        }
        break;

        case kPPMirrorRotateOperationType_Rotate180:
        {
            operationSelector = @selector(ppBitmapRotated180);
        }
        break;

        case kPPMirrorRotateOperationType_Rotate90Clockwise:
        {
            operationSelector = @selector(ppBitmapRotated90Clockwise);
        }
        break;

        case kPPMirrorRotateOperationType_Rotate90Counterclockwise:
        {
            operationSelector = @selector(ppBitmapRotated90Counterclockwise);
        }
        break;

        default:
        {
            operationSelector = NULL;
        }
        break;
    }

    return operationSelector;
}

static bool OperationIsRotate90(PPMirrorRotateOperationType operation)
{
    if ((operation == kPPMirrorRotateOperationType_Rotate90Clockwise)
        || (operation == kPPMirrorRotateOperationType_Rotate90Counterclockwise))
    {
        return YES;
    }

    return NO;
}

static void GetCleanupRectsForRotate90InBounds(NSRect bounds,
                                                NSRect *returnedCleanupRect1,
                                                NSRect *returnedCleanupRect2)
{
    NSRect rotatedBounds, cleanupRects[2] = {NSZeroRect, NSZeroRect};

    if (!returnedCleanupRect1 || !returnedCleanupRect2)
    {
        goto ERROR;
    }

    rotatedBounds = PPGeometry_CenterRectInRect(NSMakeRect(0.0f, 0.0f, bounds.size.height,
                                                            bounds.size.width),
                                                bounds);

    if (bounds.size.width > rotatedBounds.size.width)
    {
        if (bounds.origin.x < rotatedBounds.origin.x)
        {
            cleanupRects[0].origin = bounds.origin;

            cleanupRects[0].size.width = rotatedBounds.origin.x - bounds.origin.x;
            cleanupRects[0].size.height = bounds.size.height;
        }

        if ((bounds.origin.x + bounds.size.width)
            > (rotatedBounds.origin.x + rotatedBounds.size.width))
        {
            cleanupRects[1].origin.x = rotatedBounds.origin.x + rotatedBounds.size.width;
            cleanupRects[1].origin.y = bounds.origin.y;

            cleanupRects[1].size.width = bounds.origin.x + bounds.size.width
                                            - cleanupRects[1].origin.x;
            cleanupRects[1].size.height = bounds.size.height;
        }
    }
    else if (bounds.size.height > rotatedBounds.size.height)
    {
        if (bounds.origin.y < rotatedBounds.origin.y)
        {
            cleanupRects[0].origin = bounds.origin;

            cleanupRects[0].size.width = bounds.size.width;
            cleanupRects[0].size.height = rotatedBounds.origin.y - bounds.origin.y;
        }

        if ((bounds.origin.y + bounds.size.height)
                > (rotatedBounds.origin.y + rotatedBounds.size.height))
        {
            cleanupRects[1].origin.x = bounds.origin.x;
            cleanupRects[1].origin.y = rotatedBounds.origin.y + rotatedBounds.size.height;

            cleanupRects[1].size.width = bounds.size.width;
            cleanupRects[1].size.height = bounds.origin.y + bounds.size.height
                                            - cleanupRects[1].origin.y;
        }
    }

    *returnedCleanupRect1 = cleanupRects[0];
    *returnedCleanupRect2 = cleanupRects[1];

    return;

ERROR:
    if (returnedCleanupRect1)
    {
        *returnedCleanupRect1 = NSZeroRect;
    }

    if (returnedCleanupRect2)
    {
        *returnedCleanupRect2 = NSZeroRect;
    }
}
