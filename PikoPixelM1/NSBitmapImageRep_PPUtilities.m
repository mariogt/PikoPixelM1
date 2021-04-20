/*
    NSBitmapImageRep_PPUtilities.m

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


#define kMinimumBitmapAreaToUseTIFFDataLZWCompression       60


@interface NSBitmapImageRep (PPUtilitiesPrivateMethods)

- (int) ppBytesPerPixel;

- (NSBitmapImageRep *) ppUnclearedMatchedBitmapOfSize: (NSSize) bitmapSize;

- (NSBitmapImageRep *) ppBitmapScaledToSize: (NSSize) scaledSize;

- (NSBitmapImageRep *) ppBitmapCroppedToUncontainedBounds: (NSRect) croppingBounds;

- (void) ppAttachColorProfileFromBitmap: (NSBitmapImageRep *) sourceBitmap;

@end

@implementation NSBitmapImageRep (PPUtilities)

- (bool) ppIsEqualToBitmap: (NSBitmapImageRep *) comparisonBitmap
{
    int bytesPerPixel, sourceBytesPerRow, comparisonBytesPerRow, rowCounter;
    NSSize sizeInPixels;
    unsigned char *sourceRow, *comparisonRow;
    size_t numBytesToCheckPerRow;

    bytesPerPixel = [self ppBytesPerPixel];

    if (bytesPerPixel != [comparisonBitmap ppBytesPerPixel])
    {
        return NO;
    }

    sizeInPixels = [self ppSizeInPixels];

    if (!NSEqualSizes(sizeInPixels, [comparisonBitmap ppSizeInPixels]))
    {
        return NO;
    }

    sourceRow = [self bitmapData];
    comparisonRow = [comparisonBitmap bitmapData];

    if (!sourceRow || !comparisonRow)
    {
        return NO;
    }

    sourceBytesPerRow = [self bytesPerRow];
    comparisonBytesPerRow = [comparisonBitmap bytesPerRow];

    numBytesToCheckPerRow = sizeInPixels.width * bytesPerPixel;
    rowCounter = sizeInPixels.height;

    while (rowCounter--)
    {
        if (memcmp(sourceRow, comparisonRow, numBytesToCheckPerRow) != 0)
        {
            return NO;
        }

        sourceRow += sourceBytesPerRow;
        comparisonRow += comparisonBytesPerRow;
    }

    return YES;
}

- (bool) ppImportedBitmapHasAnimationFrames
{
    return ([[self valueForProperty: NSImageFrameCount] intValue] > 1) ? YES : NO;
}

- (NSData *) ppCompressedTIFFData
{
    NSSize bitmapSize;
    int bitmapArea;
    NSTIFFCompression compressionType;

    bitmapSize = [self ppSizeInPixels];

    bitmapArea = bitmapSize.width * bitmapSize.height;

    if (bitmapArea >= kMinimumBitmapAreaToUseTIFFDataLZWCompression)
    {
        compressionType = NSTIFFCompressionLZW;
    }
    else
    {
        compressionType = NSTIFFCompressionNone;
    }

    return [self TIFFRepresentationUsingCompression: compressionType factor: 1.0f];
}

- (NSData *) ppCompressedTIFFDataFromBounds: (NSRect) bounds
{
    // ppShallowDuplicateFromBounds: would be faster here, however, there's a bug on OS X 10.8
    // & earlier (GNUstep also?) where the TIFF compression loads the bitmapData rows using
    // bytesPerRow instead of pixelsWide * bytesPerPixel, which can cause it to read off the
    // end of the bitmapData buffer if the 'cropped' buffer includes the original's bottom row
    // and is offset from the original's left column. (Pointer to duplicate's left column
    // plus bytesPerRow could be past the end of the original's buffer).
    // So, sticking with the safe but slower ppBitmapCroppedToBounds: method.

    return [[self ppBitmapCroppedToBounds: bounds] ppCompressedTIFFData];
}

- (NSData *) ppCompressedPNGData
{
    return [self representationUsingType: NSPNGFileType properties: nil];
}

- (void) ppSetAsCurrentGraphicsContext
{
    NSGraphicsContext *graphicsContext;

    graphicsContext = [NSGraphicsContext graphicsContextWithBitmapImageRep: self];
    [graphicsContext setShouldAntialias: NO];

    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext: graphicsContext];
}

- (void) ppRestoreGraphicsContext
{
    [NSGraphicsContext restoreGraphicsState];
}

- (void) ppClearBitmap
{
    unsigned char *bitmapData;
    unsigned bytesPerRow, numBytesToClear, numPaddingBytesPerRow;

    bitmapData = [self bitmapData];

    if (!bitmapData)
        goto ERROR;

    bytesPerRow = [self bytesPerRow];

    numBytesToClear = [self pixelsHigh] * bytesPerRow;

    // just to be safe, assume the last row ends where the pixel data finishes
    // (last row may or may not have the full bytesPerRow allocated if it's larger
    // than the size of the row's pixel data)
    numPaddingBytesPerRow = bytesPerRow - [self pixelsWide] * [self ppBytesPerPixel];
    numBytesToClear -= numPaddingBytesPerRow;

    memset(bitmapData, 0, numBytesToClear);

    return;

ERROR:
    return;
}

- (void) ppClearBitmapInBounds: (NSRect) bounds
{
    NSRect bitmapFrame;
    unsigned char *bitmapData;
    unsigned numRowsToSkip, bytesPerRow, bytesPerPixel, numBytesToClearPerRow, rowCounter;

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
    bytesPerPixel = [self ppBytesPerPixel];
    numBytesToClearPerRow = bounds.size.width * bytesPerPixel;

    bitmapData += numRowsToSkip * bytesPerRow + (int) bounds.origin.x * bytesPerPixel;

    rowCounter = bounds.size.height;

    while (rowCounter--)
    {
        memset(bitmapData, 0, numBytesToClearPerRow);

        bitmapData += bytesPerRow;
    }

    return;

ERROR:
    return;
}

- (void) ppCopyFromBitmap: (NSBitmapImageRep *) sourceBitmap
            toPoint: (NSPoint) targetPoint
{
    [self ppCopyFromBitmap: sourceBitmap
            inRect: [sourceBitmap ppFrameInPixels]
            toPoint: targetPoint];
}

- (void) ppCopyFromBitmap: (NSBitmapImageRep *) sourceBitmap
            inRect: (NSRect) sourceRect
            toPoint: (NSPoint) targetPoint
{
    int bytesPerPixel, destinationBytesPerRow, destinationDataOffset, sourceBytesPerRow,
            sourceDataOffset, rowOffset, bytesToCopyPerRow, rowCounter;
    NSRect destinationFrame, destinationRect, sourceFrame;
    unsigned char *destinationData, *destinationRow, *sourceData, *sourceRow;

    bytesPerPixel = [self ppBytesPerPixel];

    if (bytesPerPixel != [sourceBitmap ppBytesPerPixel])
    {
        goto ERROR;
    }

    destinationFrame = [self ppFrameInPixels];

    sourceFrame = [sourceBitmap ppFrameInPixels];

    targetPoint = PPGeometry_PointClippedToIntegerValues(targetPoint);

    sourceRect =
            NSIntersectionRect(PPGeometry_PixelBoundsCoveredByRect(sourceRect), sourceFrame);

    destinationRect.origin = targetPoint;
    destinationRect.size = sourceRect.size;

    destinationRect = NSIntersectionRect(destinationRect, destinationFrame);

    if (NSIsEmptyRect(destinationRect))
    {
        goto ERROR;
    }

    if (!NSEqualSizes(destinationRect.size, sourceRect.size))
    {
        sourceRect.origin.x += destinationRect.origin.x - targetPoint.x;
        sourceRect.origin.y += destinationRect.origin.y - targetPoint.y;

        sourceRect.size = destinationRect.size;
    }

    destinationData = [self bitmapData];
    sourceData = [sourceBitmap bitmapData];

    if (!destinationData || !sourceData)
    {
        goto ERROR;
    }

    destinationBytesPerRow = [self bytesPerRow];

    rowOffset =
        destinationFrame.size.height - destinationRect.size.height - destinationRect.origin.y;

    destinationDataOffset =
        rowOffset * destinationBytesPerRow + destinationRect.origin.x * bytesPerPixel;

    destinationRow = &destinationData[destinationDataOffset];


    sourceBytesPerRow = [sourceBitmap bytesPerRow];

    rowOffset = sourceFrame.size.height - sourceRect.size.height - sourceRect.origin.y;

    sourceDataOffset = rowOffset * sourceBytesPerRow + sourceRect.origin.x * bytesPerPixel;

    sourceRow = &sourceData[sourceDataOffset];


    bytesToCopyPerRow = destinationRect.size.width * bytesPerPixel;

    rowCounter = destinationRect.size.height;

    while (rowCounter--)
    {
        memcpy(destinationRow, sourceRow, bytesToCopyPerRow);

        destinationRow += destinationBytesPerRow;
        sourceRow += sourceBytesPerRow;
    }

    return;

ERROR:
    return;
}

- (void) ppCenteredCopyFromBitmap: (NSBitmapImageRep *) sourceBitmap
{
    NSSize sourceSize, destinationSize;
    NSPoint drawingOrigin;

    sourceSize = [sourceBitmap ppSizeInPixels];
    destinationSize = [self ppSizeInPixels];

    drawingOrigin = PPGeometry_OriginPointForCenteringSizeInSize(sourceSize, destinationSize);

    [self ppCopyFromBitmap: sourceBitmap toPoint: drawingOrigin];
}

- (NSBitmapImageRep *) ppBitmapCroppedToBounds: (NSRect) croppingBounds
{
    NSRect sourceBitmapFrame;
    NSBitmapImageRep *croppedBitmap;
    unsigned char *sourceData, *croppedData, *sourceRow, *croppedRow;
    int bytesPerPixel, numSourceRowsToSkip, sourceBytesPerRow, croppedBytesPerRow, rowCounter;
    size_t numBytesToCopyPerRow;

    croppingBounds = PPGeometry_PixelBoundsCoveredByRect(croppingBounds);

    sourceBitmapFrame = [self ppFrameInPixels];

    if (!NSContainsRect(sourceBitmapFrame, croppingBounds))
    {
        return [self ppBitmapCroppedToUncontainedBounds: croppingBounds];
    }

    croppedBitmap = [self ppUnclearedMatchedBitmapOfSize: croppingBounds.size];

    if (!croppedBitmap)
        goto ERROR;

    sourceData = [self bitmapData];
    croppedData = [croppedBitmap bitmapData];

    if (!sourceData || !croppedData)
    {
        goto ERROR;
    }

    bytesPerPixel = [self ppBytesPerPixel];

    numSourceRowsToSkip = sourceBitmapFrame.size.height
                            - (croppingBounds.origin.y + croppingBounds.size.height);

    sourceBytesPerRow = [self bytesPerRow];
    sourceRow = sourceData;
    sourceRow += (sourceBytesPerRow * numSourceRowsToSkip)
                    + (bytesPerPixel * (int) croppingBounds.origin.x);

    croppedBytesPerRow = [croppedBitmap bytesPerRow];
    croppedRow = croppedData;

    numBytesToCopyPerRow = bytesPerPixel * croppingBounds.size.width;

    rowCounter = croppingBounds.size.height;

    while (rowCounter--)
    {
        memcpy(croppedRow, sourceRow, numBytesToCopyPerRow);

        croppedRow += croppedBytesPerRow;
        sourceRow += sourceBytesPerRow;
    }

    return croppedBitmap;

ERROR:
    return nil;
}

//  ppShallowDuplicateFromBounds: returns an autoreleased copy that uses the same bitmapData
// pointer as the original (depending on croppingBounds, it may be offset).
//  It's faster than ppBitmapCroppedToBounds:, which allocates a new buffer and copies the
// bitmapData. It should generally be used where the copy is just for reading, as writing to
// the copy's bitmapData will overwrite the original's. The copy should not outlive the
// original, as the copy's bitmapData pointer will become invalid when the original is
// deallocated.

- (NSBitmapImageRep *) ppShallowDuplicateFromBounds: (NSRect) croppingBounds;
{
    NSRect sourceBitmapFrame;
    unsigned char *sourceData, *croppedData;
    int bytesPerRow, numSourceRowsToSkip, croppedDataOffsetInSourceData;
    NSBitmapImageRep *croppedBitmap;

    croppingBounds = PPGeometry_PixelBoundsCoveredByRect(croppingBounds);

    sourceBitmapFrame = [self ppFrameInPixels];

    if (!NSContainsRect(sourceBitmapFrame, croppingBounds))
    {
        return [self ppBitmapCroppedToUncontainedBounds: croppingBounds];
    }

    sourceData = [self bitmapData];

    if (!sourceData)
        goto ERROR;

    bytesPerRow = [self bytesPerRow];

    numSourceRowsToSkip = sourceBitmapFrame.size.height
                            - (croppingBounds.origin.y + croppingBounds.size.height);

    croppedDataOffsetInSourceData = bytesPerRow * numSourceRowsToSkip
                                    + [self ppBytesPerPixel] * (int) croppingBounds.origin.x;

    croppedData = &sourceData[croppedDataOffsetInSourceData];

    croppedBitmap = [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes: &croppedData
                                                pixelsWide: croppingBounds.size.width
                                                pixelsHigh: croppingBounds.size.height
                                                bitsPerSample: [self bitsPerSample]
                                                samplesPerPixel: [self samplesPerPixel]
                                                hasAlpha: [self hasAlpha]
                                                isPlanar: NO
                                                colorSpaceName: [self colorSpaceName]
                                                bytesPerRow: bytesPerRow
                                                bitsPerPixel: 0]
                                        autorelease];

    if (!croppedBitmap)
        goto ERROR;

    [croppedBitmap ppAttachColorProfileFromBitmap: self];

    return croppedBitmap;

ERROR:
    return nil;
}

- (NSBitmapImageRep *) ppBitmapResizedToSize: (NSSize) newSize shouldScale: (bool) shouldScale
{
    NSBitmapImageRep *resizedBitmap = nil;

    newSize = PPGeometry_SizeClippedToIntegerValues(newSize);

    if (shouldScale)
    {
        resizedBitmap = [self ppBitmapScaledToSize: newSize];
    }
    else
    {
        NSRect resizeBounds = PPGeometry_CenterRectInRect(PPGeometry_OriginRectOfSize(newSize),
                                                            [self ppFrameInPixels]);

        resizedBitmap = [self ppBitmapCroppedToBounds: resizeBounds];
    }

    return resizedBitmap;
}

- (NSBitmapImageRep *) ppBitmapMirroredHorizontally
{
    NSSize bitmapSize;
    NSBitmapImageRep *mirroredBitmap;
    unsigned int bytesPerPixel, pixelsPerRow, rowCounter, sourceBytesPerRow,
                    destinationBytesPerRow, destinationRowLastPixelOffset, pixelCounter;
    unsigned char *sourceData, *destinationData, *sourceRow, *destinationRow;

    bitmapSize = [self ppSizeInPixels];

    mirroredBitmap = [self ppUnclearedMatchedBitmapOfSize: bitmapSize];

    if (!mirroredBitmap)
        goto ERROR;

    sourceData = [self bitmapData];
    destinationData = [mirroredBitmap bitmapData];

    if (!sourceData || !destinationData)
    {
        goto ERROR;
    }

    bytesPerPixel = [self ppBytesPerPixel];

    pixelsPerRow = bitmapSize.width;
    rowCounter = bitmapSize.height;

    sourceRow = sourceData;
    sourceBytesPerRow = [self bytesPerRow];

    destinationRow = destinationData;
    destinationBytesPerRow = [mirroredBitmap bytesPerRow];
    destinationRowLastPixelOffset = (pixelsPerRow - 1) * bytesPerPixel;

    switch (bytesPerPixel)
    {
        case sizeof(PPImageBitmapPixel):
        {
            PPImageBitmapPixel *sourceImagePixel, *destinationImagePixel;

            while (rowCounter--)
            {
                sourceImagePixel = (PPImageBitmapPixel *) sourceRow;
                destinationImagePixel =
                    (PPImageBitmapPixel *) (&destinationRow[destinationRowLastPixelOffset]);

                pixelCounter = pixelsPerRow;

                while (pixelCounter--)
                {
                    *destinationImagePixel-- = *sourceImagePixel++;
                }

                sourceRow += sourceBytesPerRow;
                destinationRow += destinationBytesPerRow;
            }
        }
        break;

        case sizeof(PPMaskBitmapPixel):
        {
            PPMaskBitmapPixel *sourceMaskPixel, *destinationMaskPixel;

            while (rowCounter--)
            {
                sourceMaskPixel = (PPMaskBitmapPixel *) sourceRow;
                destinationMaskPixel =
                    (PPMaskBitmapPixel *) (&destinationRow[destinationRowLastPixelOffset]);

                pixelCounter = pixelsPerRow;

                while (pixelCounter--)
                {
                    *destinationMaskPixel-- = *sourceMaskPixel++;
                }

                sourceRow += sourceBytesPerRow;
                destinationRow += destinationBytesPerRow;
            }
        }
        break;

        case sizeof(PPLinearRGB16BitmapPixel):
        {
            PPLinearRGB16BitmapPixel *sourceLinearPixel, *destinationLinearPixel;

            while (rowCounter--)
            {
                sourceLinearPixel = (PPLinearRGB16BitmapPixel *) sourceRow;
                destinationLinearPixel =
                    (PPLinearRGB16BitmapPixel *)
                        (&destinationRow[destinationRowLastPixelOffset]);

                pixelCounter = pixelsPerRow;

                while (pixelCounter--)
                {
                    *destinationLinearPixel-- = *sourceLinearPixel++;
                }

                sourceRow += sourceBytesPerRow;
                destinationRow += destinationBytesPerRow;
            }
        }
        break;

        default:
        break;
    }

    return mirroredBitmap;

ERROR:
    return nil;
}

- (NSBitmapImageRep *) ppBitmapMirroredVertically
{
    NSSize bitmapSize;
    NSBitmapImageRep *mirroredBitmap;
    unsigned char *sourceData, *destinationData, *sourceRow, *destinationRow;
    unsigned int sourceBytesPerRow, destinationBytesPerRow, destinationDataOffset,
                    rowDataSize, rowCounter;

    bitmapSize = [self ppSizeInPixels];

    mirroredBitmap = [self ppUnclearedMatchedBitmapOfSize: bitmapSize];

    if (!mirroredBitmap)
        goto ERROR;

    sourceData = [self bitmapData];
    destinationData = [mirroredBitmap bitmapData];

    if (!sourceData || !destinationData)
    {
        goto ERROR;
    }

    sourceBytesPerRow = [self bytesPerRow];
    sourceRow = sourceData;

    destinationBytesPerRow = [mirroredBitmap bytesPerRow];
    destinationDataOffset = (bitmapSize.height - 1) * destinationBytesPerRow;
    destinationRow = &destinationData[destinationDataOffset];;

    rowDataSize = bitmapSize.width * [self ppBytesPerPixel];
    rowCounter = bitmapSize.height;

    while (rowCounter--)
    {
        memcpy(destinationRow, sourceRow, rowDataSize);

        sourceRow += sourceBytesPerRow;
        destinationRow -= destinationBytesPerRow;
    }

    return mirroredBitmap;

ERROR:
    return nil;
}

- (NSBitmapImageRep *) ppBitmapRotated90Clockwise
{
    NSSize sourceBitmapSize, destinationBitmapSize;
    NSBitmapImageRep *destinationBitmap;
    unsigned char *sourceData, *destinationData, *sourceColumn, *destinationRow, *sourcePixel;
    unsigned int sourceBytesPerRow, destinationBytesPerRow, destinationRowLastPixelOffset,
                    bytesPerPixel, pixelsPerRow, rowCounter, pixelCounter;

    sourceBitmapSize = [self ppSizeInPixels];
    destinationBitmapSize = NSMakeSize(sourceBitmapSize.height, sourceBitmapSize.width);

    destinationBitmap = [self ppUnclearedMatchedBitmapOfSize: destinationBitmapSize];

    if (!destinationBitmap)
        goto ERROR;

    sourceData = [self bitmapData];
    destinationData = [destinationBitmap bitmapData];

    if (!sourceData || !destinationData)
    {
        goto ERROR;
    }

    bytesPerPixel = [self ppBytesPerPixel];

    pixelsPerRow = destinationBitmapSize.width;
    rowCounter = destinationBitmapSize.height;

    sourceBytesPerRow = [self bytesPerRow];
    sourceColumn = sourceData;

    destinationBytesPerRow = [destinationBitmap bytesPerRow];
    destinationRow = destinationData;
    destinationRowLastPixelOffset = (pixelsPerRow - 1) * bytesPerPixel;

    switch (bytesPerPixel)
    {
        case sizeof(PPImageBitmapPixel):
        {
            PPImageBitmapPixel *destinationImagePixel;

            while (rowCounter--)
            {
                sourcePixel = sourceColumn;
                destinationImagePixel =
                    (PPImageBitmapPixel *) (&destinationRow[destinationRowLastPixelOffset]);

                pixelCounter = pixelsPerRow;

                while (pixelCounter--)
                {
                    *destinationImagePixel-- = *((PPImageBitmapPixel *) sourcePixel);
                    sourcePixel += sourceBytesPerRow;
                }

                sourceColumn += bytesPerPixel;
                destinationRow += destinationBytesPerRow;
            }
        }
        break;

        case sizeof(PPMaskBitmapPixel):
        {
            PPMaskBitmapPixel *destinationMaskPixel;

            while (rowCounter--)
            {
                sourcePixel = sourceColumn;
                destinationMaskPixel =
                    (PPMaskBitmapPixel *) (&destinationRow[destinationRowLastPixelOffset]);

                pixelCounter = pixelsPerRow;

                while (pixelCounter--)
                {
                    *destinationMaskPixel-- = *((PPMaskBitmapPixel *) sourcePixel);
                    sourcePixel += sourceBytesPerRow;
                }

                sourceColumn += bytesPerPixel;
                destinationRow += destinationBytesPerRow;
            }
        }
        break;

        case sizeof(PPLinearRGB16BitmapPixel):
        {
            PPLinearRGB16BitmapPixel *destinationLinearPixel;

            while (rowCounter--)
            {
                sourcePixel = sourceColumn;
                destinationLinearPixel =
                    (PPLinearRGB16BitmapPixel *)
                        (&destinationRow[destinationRowLastPixelOffset]);

                pixelCounter = pixelsPerRow;

                while (pixelCounter--)
                {
                    *destinationLinearPixel-- = *((PPLinearRGB16BitmapPixel *) sourcePixel);
                    sourcePixel += sourceBytesPerRow;
                }

                sourceColumn += bytesPerPixel;
                destinationRow += destinationBytesPerRow;
            }
        }
        break;

        default:
        break;
    }

    return destinationBitmap;

ERROR:
    return nil;
}

- (NSBitmapImageRep *) ppBitmapRotated90Counterclockwise
{
    NSSize sourceBitmapSize, destinationBitmapSize;
    NSBitmapImageRep *destinationBitmap;
    unsigned char *sourceData, *destinationData, *sourceColumn, *destinationRow, *sourcePixel;
    unsigned int sourceBytesPerRow, destinationBytesPerRow, destinationDataOffset,
                    bytesPerPixel, pixelsPerRow, rowCounter, pixelCounter;

    sourceBitmapSize = [self ppSizeInPixels];
    destinationBitmapSize = NSMakeSize(sourceBitmapSize.height, sourceBitmapSize.width);

    destinationBitmap = [self ppUnclearedMatchedBitmapOfSize: destinationBitmapSize];

    if (!destinationBitmap)
        goto ERROR;

    sourceData = [self bitmapData];
    destinationData = [destinationBitmap bitmapData];

    if (!sourceData || !destinationData)
    {
        goto ERROR;
    }

    bytesPerPixel = [self ppBytesPerPixel];

    pixelsPerRow = destinationBitmapSize.width;
    rowCounter = destinationBitmapSize.height;

    sourceBytesPerRow = [self bytesPerRow];
    sourceColumn = sourceData;

    destinationBytesPerRow = [destinationBitmap bytesPerRow];
    destinationDataOffset = destinationBytesPerRow * (destinationBitmapSize.height - 1);
    destinationRow = &destinationData[destinationDataOffset];

    switch (bytesPerPixel)
    {
        case sizeof(PPImageBitmapPixel):
        {
            PPImageBitmapPixel *destinationImagePixel;

            while (rowCounter--)
            {
                sourcePixel = sourceColumn;
                destinationImagePixel = (PPImageBitmapPixel *) destinationRow;

                pixelCounter = pixelsPerRow;

                while (pixelCounter--)
                {
                    *destinationImagePixel++ = *((PPImageBitmapPixel *) sourcePixel);
                    sourcePixel += sourceBytesPerRow;
                }

                sourceColumn += bytesPerPixel;
                destinationRow -= destinationBytesPerRow;
            }
        }
        break;

        case sizeof(PPMaskBitmapPixel):
        {
            PPMaskBitmapPixel *destinationMaskPixel;

            while (rowCounter--)
            {
                sourcePixel = sourceColumn;
                destinationMaskPixel = (PPMaskBitmapPixel *) destinationRow;

                pixelCounter = pixelsPerRow;

                while (pixelCounter--)
                {
                    *destinationMaskPixel++ = *((PPMaskBitmapPixel *) sourcePixel);
                    sourcePixel += sourceBytesPerRow;
                }

                sourceColumn += bytesPerPixel;
                destinationRow -= destinationBytesPerRow;
            }
        }
        break;

        case sizeof(PPLinearRGB16BitmapPixel):
        {
            PPLinearRGB16BitmapPixel *destinationLinearPixel;

            while (rowCounter--)
            {
                sourcePixel = sourceColumn;
                destinationLinearPixel = (PPLinearRGB16BitmapPixel *) destinationRow;

                pixelCounter = pixelsPerRow;

                while (pixelCounter--)
                {
                    *destinationLinearPixel++ = *((PPLinearRGB16BitmapPixel *) sourcePixel);
                    sourcePixel += sourceBytesPerRow;
                }

                sourceColumn += bytesPerPixel;
                destinationRow -= destinationBytesPerRow;
            }
        }
        break;

        default:
        break;
    }

    return destinationBitmap;

ERROR:
    return nil;
}

- (NSBitmapImageRep *) ppBitmapRotated180
{
    return [[self ppBitmapMirroredHorizontally] ppBitmapMirroredVertically];
}

#pragma mark Private methods

- (int) ppBytesPerPixel
{
    return [self samplesPerPixel] * [self bitsPerSample] / 8;
}

- (NSBitmapImageRep *) ppUnclearedMatchedBitmapOfSize: (NSSize) bitmapSize
{
    NSBitmapImageRep *matchedBitmap;

    if (PPGeometry_IsZeroSize(bitmapSize))
    {
        goto ERROR;
    }

    matchedBitmap = [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes: NULL
                                                pixelsWide: bitmapSize.width
                                                pixelsHigh: bitmapSize.height
                                                bitsPerSample: [self bitsPerSample]
                                                samplesPerPixel: [self samplesPerPixel]
                                                hasAlpha: [self hasAlpha]
                                                isPlanar: NO
                                                colorSpaceName: [self colorSpaceName]
                                                bytesPerRow: 0
                                                bitsPerPixel: 0]
                                            autorelease];

    if (!matchedBitmap)
        goto ERROR;

    [matchedBitmap ppAttachColorProfileFromBitmap: self];

    return matchedBitmap;

ERROR:
    return nil;
}

- (NSBitmapImageRep *) ppBitmapScaledToSize: (NSSize) scaledSize
{
    NSBitmapImageRep *scaledBitmap = [self ppUnclearedMatchedBitmapOfSize: scaledSize];

    if (!scaledBitmap)
        goto ERROR;

    [scaledBitmap ppSetAsCurrentGraphicsContext];
    [[NSGraphicsContext currentContext] setImageInterpolation: NSImageInterpolationNone];

    [self drawInRect: [scaledBitmap ppFrameInPixels]];

    [scaledBitmap ppRestoreGraphicsContext];

    return scaledBitmap;

ERROR:
    return nil;
}

- (NSBitmapImageRep *) ppBitmapCroppedToUncontainedBounds: (NSRect) croppingBounds
{
    NSBitmapImageRep *croppedBitmap = [self ppUnclearedMatchedBitmapOfSize: croppingBounds.size];

    if (!croppedBitmap)
        goto ERROR;

    [croppedBitmap ppClearBitmap];

    [croppedBitmap ppCopyFromBitmap: self
                    toPoint: NSMakePoint(-croppingBounds.origin.x, -croppingBounds.origin.y)];

    return croppedBitmap;

ERROR:
    return nil;
}

- (void) ppAttachColorProfileFromBitmap: (NSBitmapImageRep *) sourceBitmap
{
    NSData *iccProfile = [sourceBitmap valueForProperty: NSImageColorSyncProfileData];

    if (iccProfile)
    {
        [self setProperty: NSImageColorSyncProfileData withValue: iccProfile];
    }
}

@end
