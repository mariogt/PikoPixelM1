/*
    PPDocument_LayerOperationTarget.m

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
#import "PPDocumentLayer.h"


@implementation PPDocument (LayerOperationTarget)

- (void) setLayerOperationTarget: (PPLayerOperationTarget) operationTarget
{
    if (!PPLayerOperationTarget_IsValid(operationTarget)
        || _isPerformingInteractiveMove)
    {
        return;
    }

    _layerOperationTarget = operationTarget;

    [self postNotification_SwitchedLayerOperationTarget];
}

- (PPLayerOperationTarget) layerOperationTarget
{
    return _layerOperationTarget;
}

- (bool) layerOperationTargetHasEnabledLayer
{
    bool targetHasEnabledLayer;

    switch (_layerOperationTarget)
    {
        case kPPLayerOperationTarget_DrawingLayerOnly:
        {
            targetHasEnabledLayer = ([_drawingLayer isEnabled]) ? YES : NO;
        }
        break;

        case kPPLayerOperationTarget_VisibleLayers:
        case kPPLayerOperationTarget_Canvas:
        {
            targetHasEnabledLayer = (_mergedVisibleBitmapHasEnabledLayer) ? YES : NO;
        }
        break;

        default:
        {
            targetHasEnabledLayer = NO;
        }
        break;
    }

    return targetHasEnabledLayer;
}

- (NSBitmapImageRep *) sourceBitmapForLayerOperationTarget:
                                                    (PPLayerOperationTarget) operationTarget
{
    NSBitmapImageRep *sourceBitmap;

    switch (operationTarget)
    {
        case kPPLayerOperationTarget_DrawingLayerOnly:
        {
            // if _drawingLayer isn't enabled, _dissolvedDrawingLayerBitmap will be clear pixels
            sourceBitmap =
                ([_drawingLayer isEnabled]) ? _drawingLayerBitmap : _dissolvedDrawingLayerBitmap;
        }
        break;

        case kPPLayerOperationTarget_VisibleLayers:
        default:
        {
            sourceBitmap = _mergedVisibleLayersBitmap;
        }
        break;
    }

    return sourceBitmap;
}

- (void) setupTargetLayerIndexesForOperationTarget: (PPLayerOperationTarget) operationTarget
{
    switch (operationTarget)
    {
        case kPPLayerOperationTarget_DrawingLayerOnly:
        {
            if ((_indexOfDrawingLayer >= 0) && [_drawingLayer isEnabled])
            {
                _targetLayerIndexes[0] = _indexOfDrawingLayer;
                _numTargetLayerIndexes = 1;
            }
            else
            {
                _numTargetLayerIndexes = 0;
            }
        }
        break;

        case kPPLayerOperationTarget_VisibleLayers:
        {
            PPDocumentLayer *layer;
            int i;

            _numTargetLayerIndexes = 0;

            for (i=0; i<_numLayers; i++)
            {
                layer = [_layers objectAtIndex: i];

                if ([layer isEnabled])
                {
                    _targetLayerIndexes[_numTargetLayerIndexes++] = i;
                }
            }
        }
        break;

        case kPPLayerOperationTarget_Canvas:
        {
            int i;

            for (i=0; i<_numLayers; i++)
            {
                _targetLayerIndexes[i] = i;
            }

            _numTargetLayerIndexes = _numLayers;
        }
        break;

        default:
        {
            _numTargetLayerIndexes = 0;
        }
        break;
    }
}

- (NSString *) nameOfLayerOperationTarget: (PPLayerOperationTarget) operationTarget
{
    static NSString *operationTargetNames[kNumPPLayerOperationTargets] =
                    {   // Strings must match enum value ordering of PPLayerOperationTarget:
                        @"Draw Layer",      // _DrawingLayerOnly
                        @"Enabled Layers",  // _VisibleLayers
                        @"Canvas"           // _Canvas
                    };

    if (!PPLayerOperationTarget_IsValid(operationTarget))
    {
        goto ERROR;
    }

    return operationTargetNames[operationTarget];

ERROR:
    return @"UNKNOWN TARGET";
}

- (NSString *) nameWithSelectionStateForLayerOperationTarget:
                                                    (PPLayerOperationTarget) operationTarget
{
    static NSString *operationTargetNamesWithSelection[kNumPPLayerOperationTargets] =
                    {   // Strings must match enum value ordering of PPLayerOperationTarget:
                        @"Draw Layer Selection",        // _DrawingLayerOnly
                        @"Enabled Layers Selection",    // _VisibleLayers
                        @"Canvas"                       // _Canvas (selection not used)
                    };

    if (_hasSelection && PPLayerOperationTarget_IsValid(operationTarget))
    {
        return operationTargetNamesWithSelection[operationTarget];
    }
    else
    {
        return [self nameOfLayerOperationTarget: operationTarget];
    }
}

@end
