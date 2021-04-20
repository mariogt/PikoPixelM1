/*
    NSBitmapImageRep_PPUtilities_MaskBitmaps.m

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

#import "NSBitmapImageRep_PPUtilities.h"

#import "PPGeometry.h"


#define kMaskBitmapBitsPerSample        (sizeof(PPMaskBitmapPixel) * 8)

#define kMaskBitmapSamplesPerPixel      (1)


@implementation NSBitmapImageRep (PPUtilities_MaskBitmaps)

+ (NSBitmapImageRep *) ppMaskBitmapOfSize: (NSSize) size
{
    NSBitmapImageRep *maskBitmap;

    size = PPGeometry_SizeClippedToIntegerValues(size);

    if (PPGeometry_IsZeroSize(size))
    {
        goto ERROR;
    }

    maskBitmap = [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes: NULL
                                                pixelsWide: size.width
                                                pixelsHigh: size.height
                                                bitsPerSample: kMaskBitmapBitsPerSample
                                                samplesPerPixel: kMaskBitmapSamplesPerPixel
                                                hasAlpha: NO
                                                isPlanar: NO
                                                colorSpaceName: NSDeviceWhiteColorSpace
                                                bytesPerRow: 0
                                                bitsPerPixel: 0]
                                        autorelease];

    if (!maskBitmap)
        goto ERROR;

    [maskBitmap ppClearBitmap];

    return maskBitmap;

ERROR:
    return nil;
}

- (bool) ppIsMaskBitmap
{
    return ([self samplesPerPixel] == kMaskBitmapSamplesPerPixel) ? YES : NO;
}

- (NSRect) ppMaskBounds
{
    return [self ppMaskBoundsInRect: [self ppFrameInPixels]];
}

- (NSRect) ppMaskBoundsInRect: (NSRect) checkBounds
{
    NSRect frame;
    int bytesPerRow, maskLeft, maskTop, maskBottom, maskRight,
        checkLeft, checkRight, checkBottom, checkTop, row, col;
    unsigned char *upperLeftBoundedData, *rowData;
    PPMaskBitmapPixel *maskPixel;

    if (![self ppIsMaskBitmap])
    {
        goto ERROR;
    }

    frame = [self ppFrameInPixels];

    checkBounds = NSIntersectionRect(frame, PPGeometry_PixelBoundsCoveredByRect(checkBounds));

    if (NSIsEmptyRect(checkBounds))
    {
        goto ERROR;
    }

    checkBottom = checkBounds.origin.y;
    checkTop = checkBottom + checkBounds.size.height - 1;
    checkLeft = checkBounds.origin.x;
    checkRight = checkLeft + checkBounds.size.width - 1;

    bytesPerRow = [self bytesPerRow];

    upperLeftBoundedData = [self bitmapData];
    upperLeftBoundedData +=
        checkLeft
        + bytesPerRow
            * (int) (frame.size.height - (checkBounds.origin.y + checkBounds.size.height));

    maskRight = checkLeft;
    maskLeft = checkRight;
    maskTop = checkBottom;
    maskBottom = checkTop + 1;

    rowData = upperLeftBoundedData;

    for (row=checkTop; row>=checkBottom; row--)
    {
        maskPixel = (PPMaskBitmapPixel *) rowData;

        for (col=checkLeft; col<=checkRight; col++)
        {
            if (*maskPixel)
            {
                if (maskLeft > col)
                {
                    maskLeft = col;
                }

                if (maskRight < col)
                {
                    maskRight = col;
                }

                if (maskTop < row)
                {
                    maskTop = row;
                }

                maskBottom = row;
            }

            maskPixel++;
        }

        rowData += bytesPerRow;
    }

    if (maskBottom > checkTop)
    {
        return NSZeroRect;
    }

    return NSMakeRect(maskLeft, maskBottom, maskRight - maskLeft + 1, maskTop - maskBottom + 1);

ERROR:
    return NSZeroRect;
}

- (bool) ppMaskIsNotEmpty
{
    unsigned char *maskRow;
    NSSize maskSize;
    int bytesPerRow, pixelsPerRow, rowCounter, pixelCounter;
    PPMaskBitmapPixel *maskPixel;

    if (![self ppIsMaskBitmap])
    {
        goto ERROR;
    }

    maskRow = [self bitmapData];

    if (!maskRow)
        goto ERROR;

    bytesPerRow = [self bytesPerRow];

    maskSize = [self ppSizeInPixels];

    pixelsPerRow = maskSize.width;
    rowCounter = maskSize.height;

    while (rowCounter--)
    {
        maskPixel = (PPMaskBitmapPixel *) maskRow;
        pixelCounter = pixelsPerRow;

        while (pixelCounter--)
        {
            if (*maskPixel++)
            {
                return YES;
            }
        }

        maskRow += bytesPerRow;
    }

    return NO;

ERROR:
    return NO;
}

- (bool) ppMaskCoversAllPixels
{
    unsigned char *maskRow;
    NSSize maskSize;
    int bytesPerRow, pixelsPerRow, rowCounter, pixelCounter;
    PPMaskBitmapPixel *maskPixel;

    if (![self ppIsMaskBitmap])
    {
        goto ERROR;
    }

    maskRow = [self bitmapData];

    if (!maskRow)
        goto ERROR;

    bytesPerRow = [self bytesPerRow];

    maskSize = [self ppSizeInPixels];

    pixelsPerRow = maskSize.width;
    rowCounter = maskSize.height;

    while (rowCounter--)
    {
        maskPixel = (PPMaskBitmapPixel *) maskRow;
        pixelCounter = pixelsPerRow;

        while (pixelCounter--)
        {
            if (!*maskPixel++)
            {
                return NO;
            }
        }

        maskRow += bytesPerRow;
    }

    return YES;

ERROR:
    return NO;
}

- (bool) ppMaskCoversPoint: (NSPoint) point
{
    NSRect bitmapFrame;
    unsigned char *maskData;
    int maskDataOffset;
    PPMaskBitmapPixel *maskPixel;

    if (![self ppIsMaskBitmap])
    {
        goto ERROR;
    }

    bitmapFrame = [self ppFrameInPixels];

    point = PPGeometry_PointClippedToIntegerValues(point);

    if (!NSPointInRect(point, bitmapFrame))
    {
        goto ERROR;
    }

    maskData = [self bitmapData];

    if (!maskData)
        goto ERROR;

    maskDataOffset = (bitmapFrame.size.height - 1 - point.y) * [self bytesPerRow]
                        + point.x * sizeof(PPMaskBitmapPixel);

    maskPixel = (PPMaskBitmapPixel *) (&maskData[maskDataOffset]);

    return (*maskPixel) ? YES : NO;

ERROR:
    return NO;
}

- (void) ppMaskPixelsInBounds: (NSRect) bounds
{
    NSRect bitmapFrame;
    unsigned char *bitmapData;
    unsigned numRowsToSkip, bytesPerRow, bytesPerPixel, numBytesToSetPerRow, rowCounter;

    if (![self ppIsMaskBitmap])
    {
        goto ERROR;
    }

    bitmapFrame = [self ppFrameInPixels];

    bounds = NSIntersectionRect(PPGeometry_PixelBoundsCoveredByRect(bounds), bitmapFrame);

    if (NSIsEmptyRect(bounds))
    {
        return;
    }

    bitmapData = [self bitmapData];

    if (!bitmapData)
        goto ERROR;

    numRowsToSkip = bitmapFrame.size.height - (bounds.origin.y + bounds.size.height);
    bytesPerRow = [self bytesPerRow];
    bytesPerPixel = sizeof(PPMaskBitmapPixel);
    numBytesToSetPerRow = bounds.size.width * bytesPerPixel;

    bitmapData += numRowsToSkip * bytesPerRow + (int) bounds.origin.x * bytesPerPixel;

    rowCounter = bounds.size.height;

    while (rowCounter--)
    {
        memset(bitmapData, kMaskPixelValue_ON, numBytesToSetPerRow);

        bitmapData += bytesPerRow;
    }

    return;

ERROR:
    return;
}

- (void) ppIntersectMaskWithMaskBitmap: (NSBitmapImageRep *) maskBitmap
{
    [self ppIntersectMaskWithMaskBitmap: maskBitmap inBounds: [maskBitmap ppFrameInPixels]];
}

- (void) ppIntersectMaskWithMaskBitmap: (NSBitmapImageRep *) maskBitmap
            inBounds: (NSRect) intersectBounds
{
    NSRect bitmapFrame;
    unsigned char *destinationData, *maskData, *destinationRow, *maskRow;
    int destinationBytesPerRow, maskBytesPerRow, rowOffset, destinationDataOffset,
            maskDataOffset, pixelsPerRow, rowCounter, pixelCounter;
    PPMaskBitmapPixel *destinationPixel, *maskPixel;

    if (![self ppIsMaskBitmap] || ![maskBitmap ppIsMaskBitmap])
    {
        goto ERROR;
    }

    bitmapFrame = [self ppFrameInPixels];

    if (!NSEqualSizes(bitmapFrame.size, [maskBitmap ppSizeInPixels]))
    {
        goto ERROR;
    }

    intersectBounds =
        NSIntersectionRect(PPGeometry_PixelBoundsCoveredByRect(intersectBounds), bitmapFrame);

    if (NSIsEmptyRect(intersectBounds))
    {
        goto ERROR;
    }

    destinationData = [self bitmapData];
    maskData = [maskBitmap bitmapData];

    if (!destinationData || !maskData)
    {
        goto ERROR;
    }

    destinationBytesPerRow = [self bytesPerRow];
    maskBytesPerRow = [maskBitmap bytesPerRow];

    rowOffset =
        bitmapFrame.size.height - intersectBounds.size.height - intersectBounds.origin.y;

    destinationDataOffset = rowOffset * destinationBytesPerRow
                                + intersectBounds.origin.x * sizeof(PPMaskBitmapPixel);

    maskDataOffset =
        rowOffset * maskBytesPerRow + intersectBounds.origin.x * sizeof(PPMaskBitmapPixel);

    destinationRow = &destinationData[destinationDataOffset];
    maskRow = &maskData[maskDataOffset];

    pixelsPerRow = intersectBounds.size.width;
    rowCounter = intersectBounds.size.height;

    while (rowCounter--)
    {
        destinationPixel = (PPMaskBitmapPixel *) destinationRow;
        maskPixel = (PPMaskBitmapPixel *) maskRow;

        pixelCounter = pixelsPerRow;

        while (pixelCounter--)
        {
            if (*destinationPixel && !*maskPixel)
            {
                *destinationPixel = kMaskPixelValue_OFF;
            }

            destinationPixel++;
            maskPixel++;
        }

        destinationRow += destinationBytesPerRow;
        maskRow += maskBytesPerRow;
    }

    return;

ERROR:
    return;
}

- (void) ppSubtractMaskBitmap: (NSBitmapImageRep *) maskBitmap
{
    [self ppSubtractMaskBitmap: maskBitmap inBounds: [maskBitmap ppFrameInPixels]];
}

- (void) ppSubtractMaskBitmap: (NSBitmapImageRep *) maskBitmap
            inBounds: (NSRect) subtractBounds
{
    NSRect bitmapFrame;
    unsigned char *destinationData, *maskData, *destinationRow, *maskRow;
    int destinationBytesPerRow, maskBytesPerRow, rowOffset, destinationDataOffset,
            maskDataOffset, pixelsPerRow, rowCounter, pixelCounter;
    PPMaskBitmapPixel *destinationPixel, *maskPixel;

    if (![self ppIsMaskBitmap] || ![maskBitmap ppIsMaskBitmap])
    {
        goto ERROR;
    }

    bitmapFrame = [self ppFrameInPixels];

    if (!NSEqualSizes(bitmapFrame.size, [maskBitmap ppSizeInPixels]))
    {
        goto ERROR;
    }

    subtractBounds =
        NSIntersectionRect(PPGeometry_PixelBoundsCoveredByRect(subtractBounds), bitmapFrame);

    if (NSIsEmptyRect(subtractBounds))
    {
        goto ERROR;
    }

    destinationData = [self bitmapData];
    maskData = [maskBitmap bitmapData];

    if (!destinationData || !maskData)
    {
        goto ERROR;
    }

    destinationBytesPerRow = [self bytesPerRow];
    maskBytesPerRow = [maskBitmap bytesPerRow];

    rowOffset = bitmapFrame.size.height - subtractBounds.size.height - subtractBounds.origin.y;

    destinationDataOffset = rowOffset * destinationBytesPerRow
                                + subtractBounds.origin.x * sizeof(PPMaskBitmapPixel);

    maskDataOffset =
        rowOffset * maskBytesPerRow + subtractBounds.origin.x * sizeof(PPMaskBitmapPixel);

    destinationRow = &destinationData[destinationDataOffset];
    maskRow = &maskData[maskDataOffset];

    pixelsPerRow = subtractBounds.size.width;
    rowCounter = subtractBounds.size.height;

    while (rowCounter--)
    {
        destinationPixel = (PPMaskBitmapPixel *) destinationRow;
        maskPixel = (PPMaskBitmapPixel *) maskRow;

        pixelCounter = pixelsPerRow;

        while (pixelCounter--)
        {
            if (*destinationPixel && *maskPixel)
            {
                *destinationPixel = kMaskPixelValue_OFF;
            }

            destinationPixel++;
            maskPixel++;
        }

        destinationRow += destinationBytesPerRow;
        maskRow += maskBytesPerRow;
    }

    return;

ERROR:
    return;
}

- (void) ppMergeMaskWithMaskBitmap: (NSBitmapImageRep *) maskBitmap
{
    [self ppMergeMaskWithMaskBitmap: maskBitmap inBounds: [maskBitmap ppFrameInPixels]];
}

- (void) ppMergeMaskWithMaskBitmap: (NSBitmapImageRep *) maskBitmap
            inBounds: (NSRect) mergeBounds
{
    NSRect bitmapFrame;
    unsigned char *destinationData, *maskData, *destinationRow, *maskRow;
    int destinationBytesPerRow, maskBytesPerRow, rowOffset, destinationDataOffset,
            maskDataOffset, pixelsPerRow, rowCounter, pixelCounter;
    PPMaskBitmapPixel *destinationPixel, *maskPixel;

    if (![self ppIsMaskBitmap] || ![maskBitmap ppIsMaskBitmap])
    {
        goto ERROR;
    }

    bitmapFrame = [self ppFrameInPixels];

    if (!NSEqualSizes(bitmapFrame.size, [maskBitmap ppSizeInPixels]))
    {
        goto ERROR;
    }

    mergeBounds =
        NSIntersectionRect(PPGeometry_PixelBoundsCoveredByRect(mergeBounds), bitmapFrame);

    if (NSIsEmptyRect(mergeBounds))
    {
        goto ERROR;
    }

    destinationData = [self bitmapData];
    maskData = [maskBitmap bitmapData];

    if (!destinationData || !maskData)
    {
        goto ERROR;
    }

    destinationBytesPerRow = [self bytesPerRow];
    maskBytesPerRow = [maskBitmap bytesPerRow];

    rowOffset = bitmapFrame.size.height - mergeBounds.size.height - mergeBounds.origin.y;

    destinationDataOffset = rowOffset * destinationBytesPerRow
                                + mergeBounds.origin.x * sizeof(PPMaskBitmapPixel);

    maskDataOffset =
            rowOffset * maskBytesPerRow + mergeBounds.origin.x * sizeof(PPMaskBitmapPixel);

    destinationRow = &destinationData[destinationDataOffset];
    maskRow = &maskData[maskDataOffset];

    pixelsPerRow = mergeBounds.size.width;
    rowCounter = mergeBounds.size.height;

    while (rowCounter--)
    {
        destinationPixel = (PPMaskBitmapPixel *) destinationRow;
        maskPixel = (PPMaskBitmapPixel *) maskRow;

        pixelCounter = pixelsPerRow;

        while (pixelCounter--)
        {
            if (!*destinationPixel && *maskPixel)
            {
                *destinationPixel = kMaskPixelValue_ON;
            }

            destinationPixel++;
            maskPixel++;
        }

        destinationRow += destinationBytesPerRow;
        maskRow += maskBytesPerRow;
    }

    return;

ERROR:
    return;
}

- (void) ppInvertMaskBitmap
{
    NSSize maskSize;
    int bytesPerRow, pixelsPerRow, rowCounter, pixelCounter;
    unsigned char *maskData, *maskRow;
    PPMaskBitmapPixel *maskPixel;

    if (![self ppIsMaskBitmap])
    {
        goto ERROR;
    }

    maskData = [self bitmapData];

    if (!maskData)
        goto ERROR;

    maskRow = maskData;
    bytesPerRow = [self bytesPerRow];

    maskSize = [self ppSizeInPixels];

    pixelsPerRow = maskSize.width;
    rowCounter = maskSize.height;

    while (rowCounter--)
    {
        maskPixel = (PPMaskBitmapPixel *) maskRow;
        pixelCounter = pixelsPerRow;

        while (pixelCounter--)
        {
            *maskPixel = ~*maskPixel;

            maskPixel++;
        }

        maskRow += bytesPerRow;
    }

    return;

ERROR:
    return;
}

- (void) ppCloseHolesInMaskBitmap
{
    NSRect maskBounds;
    NSBitmapImageRep *workingMaskBitmap, *workingImageBitmap, *scratchMaskBitmap;
    NSInteger lastRow, lastCol, row, col;

    if (![self ppIsMaskBitmap])
    {
        goto ERROR;
    }

    maskBounds = [self ppMaskBounds];

    // no holes if width or height is 2 or less
    if ((maskBounds.size.width < 3) || (maskBounds.size.height < 3))
    {
        return;
    }

    workingMaskBitmap = [self ppBitmapCroppedToBounds: maskBounds];
    workingImageBitmap = [NSBitmapImageRep ppImageBitmapOfSize: maskBounds.size];

    scratchMaskBitmap = [NSBitmapImageRep ppMaskBitmapOfSize: maskBounds.size];

    if (!workingMaskBitmap || !workingImageBitmap || !scratchMaskBitmap)
    {
        goto ERROR;
    }

    [workingImageBitmap ppMaskedFillUsingMask: workingMaskBitmap
                        inBounds: maskBounds
                        fillPixelValue: -1];

    [workingMaskBitmap ppInvertMaskBitmap];

    lastRow = maskBounds.size.height - 1;
    lastCol = maskBounds.size.width - 1;

    // first row, all cols

    row = 0;

    for (col=0; col<=lastCol; col++)
    {
        if ([[workingMaskBitmap colorAtX: col y: row] whiteComponent] > 0.5f)
        {
            [scratchMaskBitmap
                    ppMaskNeighboringPixelsMatchingColorAtPoint: NSMakePoint(col, lastRow - row)
                    inImageBitmap: workingImageBitmap
                    colorMatchTolerance: 0.0f
                    selectionMask: nil
                    selectionMaskBounds: NSZeroRect
                    matchDiagonally: NO];

            [workingMaskBitmap ppSubtractMaskBitmap: scratchMaskBitmap];
        }
    }

    // middle rows, first & last cols

    for (row=1; row<lastRow; row++)
    {
        col = 0;

        if ([[workingMaskBitmap colorAtX: col y: row] whiteComponent] > 0.5f)
        {
            [scratchMaskBitmap
                    ppMaskNeighboringPixelsMatchingColorAtPoint: NSMakePoint(col, lastRow - row)
                    inImageBitmap: workingImageBitmap
                    colorMatchTolerance: 0.0f
                    selectionMask: nil
                    selectionMaskBounds: NSZeroRect
                    matchDiagonally: NO];

            [workingMaskBitmap ppSubtractMaskBitmap: scratchMaskBitmap];
        }

        col = lastCol;

        if ([[workingMaskBitmap colorAtX: col y: row] whiteComponent] > 0.5f)
        {
            [scratchMaskBitmap
                    ppMaskNeighboringPixelsMatchingColorAtPoint: NSMakePoint(col, lastRow - row)
                    inImageBitmap: workingImageBitmap
                    colorMatchTolerance: 0.0f
                    selectionMask: nil
                    selectionMaskBounds: NSZeroRect
                    matchDiagonally: NO];

            [workingMaskBitmap ppSubtractMaskBitmap: scratchMaskBitmap];
        }
    }

    // last row, all cols

    row = lastRow;

    for (col=0; col<=lastCol; col++)
    {
        if ([[workingMaskBitmap colorAtX: col y: row] whiteComponent] > 0.5f)
        {
            [scratchMaskBitmap
                    ppMaskNeighboringPixelsMatchingColorAtPoint: NSMakePoint(col, lastRow - row)
                    inImageBitmap: workingImageBitmap
                    colorMatchTolerance: 0.0f
                    selectionMask: nil
                    selectionMaskBounds: NSZeroRect
                    matchDiagonally: NO];

            [workingMaskBitmap ppSubtractMaskBitmap: scratchMaskBitmap];
        }
    }

    scratchMaskBitmap = [self ppShallowDuplicateFromBounds: maskBounds];

    if (!scratchMaskBitmap)
        goto ERROR;

    // merging to scratchMaskBitmap also merges to self, since they share bitmapData
    // (ShallowDuplicate)
    [scratchMaskBitmap ppMergeMaskWithMaskBitmap: workingMaskBitmap];

    return;

ERROR:
    return;
}

- (void) ppThresholdMaskBitmapPixelValues
{
    [self ppThresholdMaskBitmapPixelValuesInBounds: [self ppFrameInPixels]];
}

- (void) ppThresholdMaskBitmapPixelValuesInBounds: (NSRect) bounds
{
    NSRect bitmapFrame;
    unsigned char *maskData, *maskRow;
    int numRowsToSkip, bytesPerRow, maskDataOffset, pixelsPerRow, rowCounter, pixelCounter;
    PPMaskBitmapPixel *maskPixel;

    if (![self ppIsMaskBitmap])
    {
        goto ERROR;
    }

    bitmapFrame = [self ppFrameInPixels];

    bounds = NSIntersectionRect(bitmapFrame, PPGeometry_PixelBoundsCoveredByRect(bounds));

    if (NSIsEmptyRect(bounds))
    {
        goto ERROR;
    }

    maskData = [self bitmapData];

    if (!maskData)
        goto ERROR;

    numRowsToSkip = bitmapFrame.size.height - (bounds.origin.y + bounds.size.height);
    bytesPerRow = [self bytesPerRow];
    maskDataOffset = numRowsToSkip * bytesPerRow
                        + (int) bounds.origin.x * sizeof(PPMaskBitmapPixel);

    maskRow = &maskData[maskDataOffset];

    pixelsPerRow = bounds.size.width;
    rowCounter = bounds.size.height;

    while (rowCounter--)
    {
        maskPixel = (PPMaskBitmapPixel *) maskRow;
        pixelCounter = pixelsPerRow;

        while (pixelCounter--)
        {
            *maskPixel =
                (*maskPixel > kMaskPixelValue_Threshold) ?
                    kMaskPixelValue_ON : kMaskPixelValue_OFF;

            maskPixel++;
        }

        maskRow += bytesPerRow;
    }

    return;

ERROR:
    return;
}

@end
