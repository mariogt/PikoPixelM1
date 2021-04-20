/*
    PPDocument_Resizing.m

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
#import "PPGeometry.h"


@interface PPDocument (ResizingPrivateMethods)

- (NSBitmapImageRep *) selectionMaskResizedForCanvasSize: (NSSize) newSize
                        shouldScale: (bool) shouldScale
                        returnedMaskOrigin: (NSPoint *) returnedMaskOrigin;

- (NSArray *) layersResizedToSize: (NSSize) newSize shouldScale: (bool) shouldScale;
- (NSArray *) layersCroppedToBounds: (NSRect) croppingBounds
                andMaskedWithMask: (NSBitmapImageRep *) maskBitmap;

@end

@implementation PPDocument (Resizing)

- (void) resizeToSize: (NSSize) newSize shouldScale: (bool) shouldScale
{
    NSBitmapImageRep *resizedSelectionMask = nil;
    NSPoint resizedSelectionMaskOrigin = NSZeroPoint;
    NSArray *resizedLayers;

    newSize = PPGeometry_SizeClippedToIntegerValues(newSize);

    if (NSEqualSizes(newSize, _canvasFrame.size))
    {
        return;
    }

    if (_hasSelection)
    {
        resizedSelectionMask = [self selectionMaskResizedForCanvasSize: newSize
                                        shouldScale: shouldScale
                                        returnedMaskOrigin: &resizedSelectionMaskOrigin];
    }

    resizedLayers = [self layersResizedToSize: newSize shouldScale: shouldScale];

    if (!resizedLayers)
        goto ERROR;

    [self setLayers: resizedLayers];

    if (resizedSelectionMask)
    {
        [self setSelectionMaskAreaWithBitmap: resizedSelectionMask
                atPoint: resizedSelectionMaskOrigin];
    }

    [[self undoManager] setActionName: (shouldScale) ? NSLocalizedString(@"Scale Canvas", nil) : NSLocalizedString(@"Resize Canvas", nil)];

    return;

ERROR:
    return;
}

- (void) cropToSelectionBounds
{
    NSBitmapImageRep *croppedSelectionMask;
    NSArray *croppedLayers;

    if (!_hasSelection)
        goto ERROR;

    croppedSelectionMask = [_selectionMask ppBitmapCroppedToBounds: _selectionBounds];

    if (!croppedSelectionMask)
        goto ERROR;

    croppedLayers = [self layersCroppedToBounds: _selectionBounds
                            andMaskedWithMask: croppedSelectionMask];

    if (!croppedLayers)
        goto ERROR;

    [self setLayers: croppedLayers];

    [self setSelectionMask: croppedSelectionMask];

    [[self undoManager] setActionName: NSLocalizedString(@"Crop Canvas to Selection", nil)];

    return;

ERROR:
    return;
}

#pragma mark Private methods

- (NSBitmapImageRep *) selectionMaskResizedForCanvasSize: (NSSize) newSize
                        shouldScale: (bool) shouldScale
                        returnedMaskOrigin: (NSPoint *) returnedMaskOrigin
{
    NSBitmapImageRep *resizedSelectionMask;
    NSRect resizedSelectionBounds;

    if (!_hasSelection || !returnedMaskOrigin)
    {
        goto ERROR;
    }

    resizedSelectionMask =
                    [_selectionMask ppBitmapResizedToSize: newSize shouldScale: shouldScale];

    if (shouldScale)
    {
        [resizedSelectionMask ppThresholdMaskBitmapPixelValues];
    }

    resizedSelectionBounds = [resizedSelectionMask ppMaskBounds];

    if (NSIsEmptyRect(resizedSelectionBounds))
    {
        return nil;
    }

    resizedSelectionMask =
                        [resizedSelectionMask ppBitmapCroppedToBounds: resizedSelectionBounds];

    if (!resizedSelectionMask)
        goto ERROR;

    *returnedMaskOrigin = resizedSelectionBounds.origin;

    return resizedSelectionMask;

ERROR:
    return nil;
}

- (NSArray *) layersResizedToSize: (NSSize) newSize shouldScale: (bool) shouldScale
{
    NSMutableArray *resizedLayers;
    PPDocumentLayer *layer, *resizedLayer;
    int i;

    resizedLayers = [NSMutableArray array];

    if (!resizedLayers)
        goto ERROR;

    for (i=0; i<_numLayers; i++)
    {
        layer = [_layers objectAtIndex: i];
        resizedLayer = [layer layerResizedToSize: newSize shouldScale: shouldScale];

        if (!resizedLayer)
            goto ERROR;

        [resizedLayers addObject: resizedLayer];
    }

    return resizedLayers;

ERROR:
    return nil;
}

- (NSArray *) layersCroppedToBounds: (NSRect) croppingBounds
                andMaskedWithMask: (NSBitmapImageRep *) maskBitmap
{
    NSMutableArray *croppedLayers;
    NSBitmapImageRep *eraseMask = nil;
    NSRect eraseBounds;
    NSEnumerator *layerEnumerator;
    PPDocumentLayer *layer, *croppedLayer;

    croppingBounds = NSIntersectionRect(PPGeometry_PixelBoundsCoveredByRect(croppingBounds),
                                        _canvasFrame);

    if (NSIsEmptyRect(croppingBounds) || !maskBitmap)
    {
        goto ERROR;
    }

    if (!NSEqualSizes(croppingBounds.size, [maskBitmap ppSizeInPixels]))
    {
        goto ERROR;
    }

    croppedLayers = [NSMutableArray array];

    if (!croppedLayers)
        goto ERROR;

    if (![maskBitmap ppMaskCoversAllPixels])
    {
        eraseMask = [[maskBitmap copy] autorelease];

        if (!eraseMask)
            goto ERROR;

        [eraseMask ppInvertMaskBitmap];

        eraseBounds = [eraseMask ppMaskBounds];
    }

    layerEnumerator = [_layers objectEnumerator];

    while (layer = [layerEnumerator nextObject])
    {
        croppedLayer = [layer layerCroppedToBounds: croppingBounds];

        if (!croppedLayer)
            goto ERROR;

        if (eraseMask)
        {
            [[croppedLayer bitmap] ppMaskedEraseUsingMask: eraseMask
                                    inBounds: eraseBounds];

            [croppedLayer handleUpdateToBitmapInRect: eraseBounds];
        }

        [croppedLayers addObject: croppedLayer];
    }

    if ([croppedLayers count] != _numLayers)
    {
        goto ERROR;
    }

    return croppedLayers;

ERROR:
    return nil;
}

@end
