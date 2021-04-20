/*
    PPDocument_Tiling.m

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

#import "PPDocumentLayer.h"
#import "NSBitmapImageRep_PPUtilities.h"
#import "NSImage_PPUtilities.h"


@interface PPDocument (TilingPrivateMethods)

- (NSColor *) tilingPatternColorFromSelectionInBitmap: (NSBitmapImageRep *) sourceBitmap;

- (bool) tileSelectionInBitmap: (NSBitmapImageRep *) sourceBitmap
            toBitmap: (NSBitmapImageRep *) destinationBitmap;

- (bool) tileSelectionInLayerAtIndex: (int) index;

@end

@implementation PPDocument (Tiling)

- (void) tileSelection
{
    bool isMultilayerOperation;
    int i;
    NSString *actionName;

    if (!_hasSelection)
        goto ERROR;

    [self setupTargetLayerIndexesForOperationTarget: _layerOperationTarget];

    if (!_numTargetLayerIndexes)
        goto ERROR;

    isMultilayerOperation = (_numTargetLayerIndexes > 1) ? YES : NO;

    if (isMultilayerOperation)
    {
        [self beginMultilayerOperation];
    }

    for (i=0; i<_numTargetLayerIndexes; i++)
    {
        [self tileSelectionInLayerAtIndex: _targetLayerIndexes[i]];
    }

    if (isMultilayerOperation)
    {
        [self finishMultilayerOperation];
    }

    actionName =
        [NSString stringWithFormat: @"Tile Selection (%@)",
                                    [self nameOfLayerOperationTarget: _layerOperationTarget]];

    [[self undoManager] setActionName: actionName];

    return;

ERROR:
    return;
}

- (void) tileSelectionAsNewLayer
{
    PPDocumentLayer *layer;
    NSBitmapImageRep *sourceBitmap, *destinationBitmap;
    NSString *actionName;

    layer = [PPDocumentLayer layerWithSize: _canvasFrame.size
                                andName: @"Tiled Layer from Selection"];

    if (!layer)
        goto ERROR;

    sourceBitmap = [self sourceBitmapForLayerOperationTarget: _layerOperationTarget];
    destinationBitmap = [layer bitmap];

    if (!sourceBitmap || !destinationBitmap)
    {
        goto ERROR;
    }

    if (![self tileSelectionInBitmap: sourceBitmap toBitmap: destinationBitmap])
    {
        goto ERROR;
    }

    [layer handleUpdateToBitmapInRect: _canvasFrame];

    if (_layerOperationTarget == kPPLayerOperationTarget_DrawingLayerOnly)
    {
        [layer setOpacity: [_drawingLayer opacity]];
    }

    [self insertLayer: layer atIndex: _indexOfDrawingLayer + 1 andSetAsDrawingLayer: YES];

    actionName =
        [NSString stringWithFormat: @"Add Layer (Tiled %@ Selection)",
                                    [self nameOfLayerOperationTarget: _layerOperationTarget]];

    [[self undoManager] setActionName: actionName];

    return;

ERROR:
    return;
}

#pragma mark Private methods

- (NSColor *) tilingPatternColorFromSelectionInBitmap: (NSBitmapImageRep *) sourceBitmap
{
    NSBitmapImageRep *tileBitmap, *tileInvertedSelectionMask;
    NSImage *tileImage;

    if (!sourceBitmap || !_hasSelection)
    {
        goto ERROR;
    }

    tileBitmap = [sourceBitmap ppBitmapCroppedToBounds: _selectionBounds];

    tileInvertedSelectionMask = [_selectionMask ppBitmapCroppedToBounds: _selectionBounds];
    [tileInvertedSelectionMask ppInvertMaskBitmap];

    if (!tileBitmap || !tileInvertedSelectionMask)
    {
        goto ERROR;
    }

    if ([tileInvertedSelectionMask ppMaskIsNotEmpty])
    {
        [tileBitmap ppMaskedEraseUsingMask: tileInvertedSelectionMask];
    }

    tileImage = [NSImage ppImageWithBitmap: tileBitmap];

    if (!tileImage)
        goto ERROR;

    return [NSColor colorWithPatternImage: tileImage];

ERROR:
    return nil;
}

- (bool) tileSelectionInBitmap: (NSBitmapImageRep *) sourceBitmap
            toBitmap: (NSBitmapImageRep *) destinationBitmap
{
    NSColor *tilingPatternColor;

    if (!sourceBitmap || !destinationBitmap)
    {
        goto ERROR;
    }

    tilingPatternColor = [self tilingPatternColorFromSelectionInBitmap: sourceBitmap];

    if (!tilingPatternColor)
        goto ERROR;

    [destinationBitmap ppSetAsCurrentGraphicsContext];

    [tilingPatternColor set];
    [[NSGraphicsContext currentContext] setPatternPhase: _selectionBounds.origin];

    NSRectFill(_canvasFrame);

    [destinationBitmap ppRestoreGraphicsContext];

    return YES;

ERROR:
    return NO;
}

- (bool) tileSelectionInLayerAtIndex: (int) index
{
    PPDocumentLayer *layer;
    NSBitmapImageRep *tiledBitmap;

    layer = [self layerAtIndex: index];

    if (!layer)
        goto ERROR;

    tiledBitmap = [NSBitmapImageRep ppImageBitmapOfSize: _canvasFrame.size];

    if (!tiledBitmap)
        goto ERROR;

    if (![self tileSelectionInBitmap: [layer bitmap] toBitmap: tiledBitmap])
    {
        goto ERROR;
    }

    [self copyImageBitmap: tiledBitmap toLayerAtIndex: index atPoint: NSZeroPoint];

    return YES;

ERROR:
    return NO;
}

@end
