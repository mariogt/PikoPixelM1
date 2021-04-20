/*
    PPDocument_PixelMatching.m

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

#import "PPGeometry.h"
#import "NSBitmapImageRep_PPUtilities.h"


@implementation PPDocument (PixelMatching)

- (NSBitmapImageRep *) maskForPixelsMatchingColorAtPoint: (NSPoint) point
                        colorMatchTolerance: (unsigned) colorMatchTolerance
                        pixelMatchingMode: (PPPixelMatchingMode) pixelMatchingMode
                        shouldIntersectSelectionMask: (bool) shouldIntersectSelectionMask
{
    NSBitmapImageRep *matchingMask, *sourceBitmap, *selectionMask;

    // this method can get called repeatedly, so instead of constructing a new bitmap each time,
    // use _drawingMask member as the returned matchingMask (ok as long as it's only used
    // temporarily)
    matchingMask = _drawingMask;

    point = PPGeometry_PointClippedToRect(PPGeometry_PointClippedToIntegerValues(point),
                                            _canvasFrame);

    sourceBitmap = [self sourceBitmapForLayerOperationTarget: _layerOperationTarget];

    if (!sourceBitmap)
        goto ERROR;

    selectionMask = (_hasSelection && shouldIntersectSelectionMask) ? _selectionMask : nil;

    if (pixelMatchingMode == kPPPixelMatchingMode_Anywhere)
    {
        [matchingMask ppMaskAllPixelsMatchingColorAtPoint: point
                        inImageBitmap: sourceBitmap
                        colorMatchTolerance: colorMatchTolerance
                        selectionMask: selectionMask
                        selectionMaskBounds: _selectionBounds];
    }
    else
    {
        bool matchDiagonally =
                    (pixelMatchingMode == kPPPixelMatchingMode_BordersAndDiagonals) ? YES : NO;

        [matchingMask ppMaskNeighboringPixelsMatchingColorAtPoint: point
                        inImageBitmap: sourceBitmap
                        colorMatchTolerance: colorMatchTolerance
                        selectionMask: selectionMask
                        selectionMaskBounds: _selectionBounds
                        matchDiagonally: matchDiagonally];
    }

    return matchingMask;

ERROR:
    return nil;
}

@end
