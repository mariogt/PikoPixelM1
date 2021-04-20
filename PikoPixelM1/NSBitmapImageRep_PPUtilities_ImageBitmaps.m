/*
    NSBitmapImageRep_PPUtilities_ImageBitmaps.m

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

#import "PPDefines.h"
#import "PPGeometry.h"
#import "NSColor_PPUtilities.h"
#import "NSImage_PPUtilities.h"


#define kImageBitmapBitsPerSample                                           \
            (sizeof(PPImagePixelComponent) * 8)

#define kImageBitmapSamplesPerPixel                                         \
            (sizeof(PPImageBitmapPixel) / sizeof(PPImagePixelComponent))


#define kMaxScalingFactorToForceDotsGridType                6
#define kCrosshairLegSizeToScalingFactorRatio               (1.0/7.0)


@implementation NSBitmapImageRep (PPUtilities_ImageBitmaps)

+ (NSBitmapImageRep *) ppImageBitmapOfSize: (NSSize) size
{
    NSBitmapImageRep *imageBitmap;

    size = PPGeometry_SizeClippedToIntegerValues(size);

    if (PPGeometry_IsZeroSize(size))
    {
        goto ERROR;
    }

    imageBitmap = [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes: NULL
                                                pixelsWide: size.width
                                                pixelsHigh: size.height
                                                bitsPerSample: kImageBitmapBitsPerSample
                                                samplesPerPixel: kImageBitmapSamplesPerPixel
                                                hasAlpha: YES
                                                isPlanar: NO
                                                colorSpaceName: NSCalibratedRGBColorSpace
                                                bytesPerRow: 0
                                                bitsPerPixel: 0]
                                        autorelease];

    if (!imageBitmap)
        goto ERROR;

    // use sRGB colorspace
    [imageBitmap ppAttachSRGBColorProfile];

    [imageBitmap ppClearBitmap];

    return imageBitmap;

ERROR:
    return nil;
}

+ (NSBitmapImageRep *) ppImageBitmapWithImportedData: (NSData *) importedData
{
    return [[NSBitmapImageRep imageRepWithData: importedData] ppImageBitmap];
}

+ (NSBitmapImageRep *) ppImageBitmapFromImageResource: (NSString *) imageName
{
    NSString *imageResourcePath;
    NSData *imageData;

    if (!imageName)
        goto ERROR;

    imageResourcePath = [[NSBundle mainBundle] pathForImageResource: imageName];

    if (!imageResourcePath)
        goto ERROR;

    imageData = [NSData dataWithContentsOfFile: imageResourcePath];

    if (!imageData)
        goto ERROR;

    return [NSBitmapImageRep ppImageBitmapWithImportedData: imageData];

ERROR:
    return nil;
}

- (bool) ppIsImageBitmap
{
    return (([self samplesPerPixel] == kImageBitmapSamplesPerPixel)
                && ([self bitsPerSample] == kImageBitmapBitsPerSample))
            ? YES : NO;
}

- (bool) ppIsImageBitmapAndSameSizeAsMaskBitmap: (NSBitmapImageRep *) maskBitmap
{
    if ([self ppIsImageBitmap]
        && [maskBitmap ppIsMaskBitmap]
        && NSEqualSizes([self ppSizeInPixels], [maskBitmap ppSizeInPixels]))
    {
        return YES;
    }
    else
    {
        return NO;
    }
}

// ppImageColorAtPoint: is used instead of the Cocoa-native -[NSBitmapImageRep colorAtX:y:],
// because it returns image-bitmap colors in the correct colorspace (sRGB); As of OS X 10.6,
// colorAtX:y: incorrectly ignores image-bitmaps' custom colorspace, returning colors in
// NSCalibratedRGBColorSpace

- (NSColor *) ppImageColorAtPoint: (NSPoint) point
{
    NSRect bitmapFrame;
    unsigned char *bitmapData;
    int rowOffset, dataOffset;
    PPImageBitmapPixel *bitmapPixel;
    CGFloat alphaComponent, redValue, greenValue, blueValue, alphaValue;

    if (![self ppIsImageBitmap])
    {
        goto ERROR;
    }

    bitmapFrame = [self ppFrameInPixels];

    point = PPGeometry_PointClippedToRect(PPGeometry_PointClippedToIntegerValues(point),
                                            bitmapFrame);

    bitmapData = [self bitmapData];

    if (!bitmapData)
        goto ERROR;

    rowOffset = bitmapFrame.size.height - 1 - point.y;

    dataOffset = rowOffset * [self bytesPerRow] + point.x * sizeof(PPImageBitmapPixel);

    bitmapPixel = (PPImageBitmapPixel *) &bitmapData[dataOffset];

    alphaComponent = macroImagePixelComponent_Alpha(bitmapPixel);

    if (alphaComponent > 0)
    {
        // nonzero alpha: un-premultiply RGB components
        redValue= ((CGFloat) macroImagePixelComponent_Red(bitmapPixel)) / alphaComponent;

        greenValue = ((CGFloat) macroImagePixelComponent_Green(bitmapPixel)) / alphaComponent;

        blueValue = ((CGFloat) macroImagePixelComponent_Blue(bitmapPixel)) / alphaComponent;

        alphaValue = alphaComponent / ((CGFloat) kMaxImagePixelComponentValue);
    }
    else
    {
        // zero alpha: all components are zero due to premultiply
        redValue = greenValue = blueValue = alphaValue = 0;
    }

    return [NSColor ppSRGBColorWithRed: redValue
                                green: greenValue
                                blue: blueValue
                                alpha: alphaValue];

ERROR:
    return nil;
}

- (bool) ppImageBitmapHasTransparentPixels
{
    unsigned char *bitmapRow;
    int bytesPerRow, pixelsPerRow, rowCounter, pixelCounter;
    NSSize bitmapSize;
    PPImageBitmapPixel *bitmapPixel;

    if (![self ppIsImageBitmap])
    {
        goto ERROR;
    }

    bitmapRow = [self bitmapData];

    if (!bitmapRow)
        goto ERROR;

    bytesPerRow = [self bytesPerRow];

    bitmapSize = [self ppSizeInPixels];

    pixelsPerRow = bitmapSize.width;
    rowCounter = bitmapSize.height;

    while (rowCounter--)
    {
        bitmapPixel = (PPImageBitmapPixel *) bitmapRow;
        pixelCounter = pixelsPerRow;

        while (pixelCounter--)
        {
            if (macroImagePixelComponent_Alpha(bitmapPixel) != kMaxImagePixelComponentValue)
            {
                return YES;
            }

            bitmapPixel++;
        }

        bitmapRow += bytesPerRow;
    }

    return NO;

ERROR:
    return NO;
}

- (void) ppMaskedFillUsingMask: (NSBitmapImageRep *) maskBitmap
            inBounds: (NSRect) fillBounds
            fillPixelValue: (PPImageBitmapPixel) fillPixelValue
{
    NSRect bitmapFrame;
    unsigned char *destinationData, *maskData, *destinationRow, *maskRow;
    int destinationBytesPerRow, maskBytesPerRow, rowOffset, destinationDataOffset,
            maskDataOffset, pixelsPerRow, rowCounter, pixelCounter;
    PPImageBitmapPixel *destinationPixel;
    PPMaskBitmapPixel *maskPixel;

    if (![self ppIsImageBitmapAndSameSizeAsMaskBitmap: maskBitmap])
    {
        goto ERROR;
    }

    bitmapFrame = [self ppFrameInPixels];

    fillBounds =
            NSIntersectionRect(PPGeometry_PixelBoundsCoveredByRect(fillBounds), bitmapFrame);

    if (NSIsEmptyRect(fillBounds))
    {
        goto ERROR;
    }

    destinationData = [self bitmapData];
    maskData = [maskBitmap bitmapData];

    if (!destinationData || !maskData)
    {
        goto ERROR;
    }

    rowOffset = bitmapFrame.size.height - fillBounds.size.height - fillBounds.origin.y;

    destinationBytesPerRow = [self bytesPerRow];
    destinationDataOffset =
        rowOffset * destinationBytesPerRow + fillBounds.origin.x * sizeof(PPImageBitmapPixel);
    destinationRow = &destinationData[destinationDataOffset];

    maskBytesPerRow = [maskBitmap bytesPerRow];
    maskDataOffset =
            rowOffset * maskBytesPerRow + fillBounds.origin.x * sizeof(PPMaskBitmapPixel);
    maskRow = &maskData[maskDataOffset];

    pixelsPerRow = fillBounds.size.width;
    rowCounter = fillBounds.size.height;

    while (rowCounter--)
    {
        destinationPixel = (PPImageBitmapPixel *) destinationRow;
        maskPixel = (PPMaskBitmapPixel *) maskRow;

        pixelCounter = pixelsPerRow;

        while (pixelCounter--)
        {
            if (*maskPixel++)
            {
                *destinationPixel = fillPixelValue;
            }

            destinationPixel++;
        }

        destinationRow += destinationBytesPerRow;
        maskRow += maskBytesPerRow;
    }

    return;

ERROR:
    return;
}

- (void) ppMaskedEraseUsingMask: (NSBitmapImageRep *) maskBitmap
{
    [self ppMaskedFillUsingMask: maskBitmap
            inBounds: [self ppFrameInPixels]
            fillPixelValue: 0];
}

- (void) ppMaskedEraseUsingMask: (NSBitmapImageRep *) maskBitmap
            inBounds: (NSRect) eraseBounds
{
    [self ppMaskedFillUsingMask: maskBitmap
            inBounds: eraseBounds
            fillPixelValue: 0];
}

- (void) ppMaskedCopyFromImageBitmap: (NSBitmapImageRep *) sourceBitmap
            usingMask: (NSBitmapImageRep *) maskBitmap
{
    return [self ppMaskedCopyFromImageBitmap: sourceBitmap
                    usingMask: maskBitmap
                    inBounds: [self ppFrameInPixels]];
}

- (void) ppMaskedCopyFromImageBitmap: (NSBitmapImageRep *) sourceBitmap
            usingMask: (NSBitmapImageRep *) maskBitmap
            inBounds: (NSRect) copyBounds
{
    NSRect bitmapFrame;
    unsigned char *destinationData, *sourceData, *maskData, *destinationRow, *sourceRow,
                    *maskRow;
    int destinationBytesPerRow, sourceBytesPerRow, maskBytesPerRow, rowOffset,
            destinationDataOffset, sourceDataOffset, maskDataOffset,
            pixelsPerRow, rowCounter, pixelCounter;
    PPImageBitmapPixel *destinationPixel, *sourcePixel;
    PPMaskBitmapPixel *maskPixel;

    if (![self ppIsImageBitmap]
        || ![sourceBitmap ppIsImageBitmapAndSameSizeAsMaskBitmap: maskBitmap])
    {
        goto ERROR;
    }

    bitmapFrame = [self ppFrameInPixels];

    if (!NSEqualSizes(bitmapFrame.size, [sourceBitmap ppSizeInPixels]))
    {
        goto ERROR;
    }

    copyBounds =
            NSIntersectionRect(PPGeometry_PixelBoundsCoveredByRect(copyBounds), bitmapFrame);

    if (NSIsEmptyRect(copyBounds))
    {
        goto ERROR;
    }

    destinationData = [self bitmapData];
    sourceData = [sourceBitmap bitmapData];
    maskData = [maskBitmap bitmapData];

    if (!destinationData || !sourceData || !maskData)
    {
        goto ERROR;
    }

    destinationBytesPerRow = [self bytesPerRow];
    sourceBytesPerRow = [sourceBitmap bytesPerRow];
    maskBytesPerRow = [maskBitmap bytesPerRow];

    rowOffset = bitmapFrame.size.height - copyBounds.size.height - copyBounds.origin.y;

    destinationDataOffset =
        rowOffset * destinationBytesPerRow + copyBounds.origin.x * sizeof(PPImageBitmapPixel);

    sourceDataOffset =
        rowOffset * sourceBytesPerRow + copyBounds.origin.x * sizeof(PPImageBitmapPixel);

    maskDataOffset =
        rowOffset * maskBytesPerRow + copyBounds.origin.x * sizeof(PPMaskBitmapPixel);

    destinationRow = &destinationData[destinationDataOffset];
    sourceRow = &sourceData[sourceDataOffset];
    maskRow = &maskData[maskDataOffset];

    pixelsPerRow = copyBounds.size.width;
    rowCounter = copyBounds.size.height;

    while (rowCounter--)
    {
        destinationPixel = (PPImageBitmapPixel *) destinationRow;
        sourcePixel = (PPImageBitmapPixel *) sourceRow;
        maskPixel = (PPMaskBitmapPixel *) maskRow;

        pixelCounter = pixelsPerRow;

        while (pixelCounter--)
        {
            if (*maskPixel++)
            {
                *destinationPixel = *sourcePixel;
            }

            destinationPixel++;
            sourcePixel++;
        }

        destinationRow += destinationBytesPerRow;
        sourceRow += sourceBytesPerRow;
        maskRow += maskBytesPerRow;
    }

    return;

ERROR:
    return;
}

- (void) ppMaskedCopyFromImageBitmap:(NSBitmapImageRep *) sourceBitmap
            usingMask: (NSBitmapImageRep *) maskBitmap
            toPoint: (NSPoint) targetPoint
{
    NSRect destinationFrame, sourceFrame, destinationCopyBounds, sourceCopyBounds;
    unsigned char *destinationData, *sourceData, *maskData, *destinationRow, *sourceRow,
                    *maskRow;
    int destinationBytesPerRow, sourceBytesPerRow, maskBytesPerRow, rowOffset,
            destinationDataOffset, sourceDataOffset, maskDataOffset,
            pixelsPerRow, rowCounter, pixelCounter;
    PPImageBitmapPixel *destinationPixel, *sourcePixel;
    PPMaskBitmapPixel *maskPixel;

    if (![self ppIsImageBitmap]
        || ![sourceBitmap ppIsImageBitmapAndSameSizeAsMaskBitmap: maskBitmap])
    {
        goto ERROR;
    }

    targetPoint = PPGeometry_PointClippedToIntegerValues(targetPoint);

    destinationFrame = [self ppFrameInPixels];
    sourceFrame = [sourceBitmap ppFrameInPixels];

    destinationCopyBounds =
                NSIntersectionRect(NSOffsetRect(sourceFrame, targetPoint.x, targetPoint.y),
                                    destinationFrame);

    if (NSIsEmptyRect(destinationCopyBounds))
    {
        goto ERROR;
    }

    sourceCopyBounds = NSOffsetRect(destinationCopyBounds, -targetPoint.x, -targetPoint.y);

    destinationData = [self bitmapData];
    sourceData = [sourceBitmap bitmapData];
    maskData = [maskBitmap bitmapData];

    if (!destinationData || !sourceData || !maskData)
    {
        goto ERROR;
    }

    destinationBytesPerRow = [self bytesPerRow];
    sourceBytesPerRow = [sourceBitmap bytesPerRow];
    maskBytesPerRow = [maskBitmap bytesPerRow];

    rowOffset = destinationFrame.size.height - destinationCopyBounds.size.height
                - destinationCopyBounds.origin.y;

    destinationDataOffset = rowOffset * destinationBytesPerRow
                            + destinationCopyBounds.origin.x * sizeof(PPImageBitmapPixel);

    rowOffset = sourceFrame.size.height - sourceCopyBounds.size.height
                - sourceCopyBounds.origin.y;

    sourceDataOffset = rowOffset * sourceBytesPerRow
                        + sourceCopyBounds.origin.x * sizeof(PPImageBitmapPixel);

    maskDataOffset = rowOffset * maskBytesPerRow
                        + sourceCopyBounds.origin.x * sizeof(PPMaskBitmapPixel);

    destinationRow = &destinationData[destinationDataOffset];
    sourceRow = &sourceData[sourceDataOffset];
    maskRow = &maskData[maskDataOffset];

    pixelsPerRow = destinationCopyBounds.size.width;
    rowCounter = destinationCopyBounds.size.height;

    while (rowCounter--)
    {
        destinationPixel = (PPImageBitmapPixel *) destinationRow;
        sourcePixel = (PPImageBitmapPixel *) sourceRow;
        maskPixel = (PPMaskBitmapPixel *) maskRow;

        pixelCounter = pixelsPerRow;

        while (pixelCounter--)
        {
            if (*maskPixel++)
            {
                *destinationPixel = *sourcePixel;
            }

            destinationPixel++;
            sourcePixel++;
        }

        destinationRow += destinationBytesPerRow;
        sourceRow += sourceBytesPerRow;
        maskRow += maskBytesPerRow;
    }

    return;

ERROR:
    return;
}

- (void) ppScaledCopyFromImageBitmap: (NSBitmapImageRep *) sourceBitmap
            inRect: (NSRect) sourceRect
            toPoint: (NSPoint) destinationPoint
            scalingFactor: (unsigned) scalingFactor
{
    NSRect destinationRect, sourceBitmapFrame, destinationBitmapFrame;
    unsigned char *sourceData, *destinationData, *scaledRowData, *sourceRow, *destinationRow;
    int sourceBytesPerRow, numSourceRowsToSkip, sourceDataOffset, destinationBytesPerRow,
        numDestinationRowsToSkip, destinationDataOffset, scaledRowDataSize,
        numTimesToCopyScaledRow, pixelsPerRow, rowCounter, pixelCounter, scaleCounter;
    PPImageBitmapPixel *currentSourcePixel, *currentScaledPixel;

    if (scalingFactor == 1)
    {
        [self ppCopyFromBitmap: sourceBitmap
                inRect: sourceRect
                toPoint: destinationPoint];

        return;
    }

    if (![self ppIsImageBitmap] || ![sourceBitmap ppIsImageBitmap]
        || (scalingFactor < 1))
    {
        goto ERROR;
    }

    sourceRect = PPGeometry_PixelBoundsCoveredByRect(sourceRect);

    if (NSIsEmptyRect(sourceRect))
    {
        goto ERROR;
    }

    destinationRect.origin = PPGeometry_PointClippedToIntegerValues(destinationPoint);
    destinationRect.size = NSMakeSize(sourceRect.size.width * scalingFactor,
                                        sourceRect.size.height * scalingFactor);

    sourceBitmapFrame = [sourceBitmap ppFrameInPixels];
    destinationBitmapFrame = [self ppFrameInPixels];

    if (!NSContainsRect(sourceBitmapFrame, sourceRect)
        || !NSContainsRect(destinationBitmapFrame, destinationRect))
    {
        goto ERROR;
    }

    sourceData = [sourceBitmap bitmapData];
    destinationData = [self bitmapData];

    if (!sourceData || !destinationData)
    {
        goto ERROR;
    }

    sourceBytesPerRow = [sourceBitmap bytesPerRow];
    numSourceRowsToSkip =
                sourceBitmapFrame.size.height - (sourceRect.origin.y + sourceRect.size.height);
    sourceDataOffset = numSourceRowsToSkip * sourceBytesPerRow
                            + sizeof(PPImageBitmapPixel) * sourceRect.origin.x;
    sourceRow = &sourceData[sourceDataOffset];

    destinationBytesPerRow = [self bytesPerRow];
    numDestinationRowsToSkip = destinationBitmapFrame.size.height
                                - (destinationRect.origin.y + destinationRect.size.height);
    destinationDataOffset = numDestinationRowsToSkip * destinationBytesPerRow
                                + sizeof(PPImageBitmapPixel) * destinationRect.origin.x;
    destinationRow = &destinationData[destinationDataOffset];

    scaledRowDataSize = sourceRect.size.width * sizeof(PPImageBitmapPixel) * scalingFactor;
    numTimesToCopyScaledRow = scalingFactor - 1;

    pixelsPerRow = sourceRect.size.width;
    rowCounter = sourceRect.size.height;

    while (rowCounter--)
    {
        currentSourcePixel = (PPImageBitmapPixel *) sourceRow;
        currentScaledPixel = (PPImageBitmapPixel *) destinationRow;

        pixelCounter = pixelsPerRow;

        while (pixelCounter--)
        {
            scaleCounter = scalingFactor;

            while (scaleCounter--)
            {
                *currentScaledPixel++ = *currentSourcePixel;
            }

            currentSourcePixel++;
        }

        scaledRowData = destinationRow;
        destinationRow += destinationBytesPerRow;

        scaleCounter = numTimesToCopyScaledRow;

        while (scaleCounter--)
        {
            memcpy(destinationRow, scaledRowData, scaledRowDataSize);

            destinationRow += destinationBytesPerRow;
        }

        sourceRow += sourceBytesPerRow;
    }

    return;

ERROR:
    return;
}

- (void) ppScaledCopyFromImageBitmap: (NSBitmapImageRep *) sourceBitmap
            inRect: (NSRect) sourceRect
            toPoint: (NSPoint) destinationPoint
            scalingFactor: (unsigned) scalingFactor
            gridType: (PPGridType) gridType
            gridPixelValue: (PPImageBitmapPixel) gridPixelValue
{
    NSRect destinationRect, sourceBitmapFrame, destinationBitmapFrame;
    unsigned char *sourceData, *destinationData, *sourceRow, *destinationRow, *scaledRowData;
    int scaledRowDataSize, sourceBytesPerRow, numSourceRowsToSkip, sourceDataOffset,
            destinationBytesPerRow, numDestinationRowsToSkip, destinationDataOffset,
            pixelsPerRow, rowCounter, pixelCounter, scaledPixelCounter, scaledRowCounter;
    PPImageBitmapPixel *currentSourcePixel, *currentScaledPixel;

    if (scalingFactor < kMinScalingFactorToDrawGrid)
    {
        if (scalingFactor == 1)
        {
            [self ppCopyFromBitmap: sourceBitmap
                    inRect: sourceRect
                    toPoint: destinationPoint];

            return;
        }
        else
        {
            [self ppScaledCopyFromImageBitmap: sourceBitmap
                    inRect: sourceRect
                    toPoint: destinationPoint
                    scalingFactor: scalingFactor];

            return;
        }
    }

    if (![self ppIsImageBitmap] || ![sourceBitmap ppIsImageBitmap])
    {
        goto ERROR;
    }

    if (scalingFactor <= kMaxScalingFactorToForceDotsGridType)
    {
        if (gridType != kPPGridType_Lines)
        {
            gridType = kPPGridType_Dots;
        }
    }

    sourceRect = PPGeometry_PixelBoundsCoveredByRect(sourceRect);

    if (NSIsEmptyRect(sourceRect))
    {
        goto ERROR;
    }

    destinationRect.origin = PPGeometry_PointClippedToIntegerValues(destinationPoint);
    destinationRect.size = NSMakeSize(sourceRect.size.width * scalingFactor,
                                        sourceRect.size.height * scalingFactor);

    sourceBitmapFrame = [sourceBitmap ppFrameInPixels];
    destinationBitmapFrame = [self ppFrameInPixels];

    if (!NSContainsRect(sourceBitmapFrame, sourceRect)
        || !NSContainsRect(destinationBitmapFrame, destinationRect))
    {
        goto ERROR;
    }

    sourceData = [sourceBitmap bitmapData];
    destinationData = [self bitmapData];

    if (!sourceData || !destinationData)
    {
        goto ERROR;
    }

    sourceBytesPerRow = [sourceBitmap bytesPerRow];
    numSourceRowsToSkip =
            sourceBitmapFrame.size.height - (sourceRect.origin.y + sourceRect.size.height);
    sourceDataOffset = numSourceRowsToSkip * sourceBytesPerRow
                        + sizeof(PPImageBitmapPixel) * sourceRect.origin.x;
    sourceRow = &sourceData[sourceDataOffset];

    destinationBytesPerRow = [self bytesPerRow];
    numDestinationRowsToSkip = destinationBitmapFrame.size.height
                                - (destinationRect.origin.y + destinationRect.size.height);
    destinationDataOffset = numDestinationRowsToSkip * destinationBytesPerRow
                                + sizeof(PPImageBitmapPixel) * destinationRect.origin.x;
    destinationRow = &destinationData[destinationDataOffset];

    pixelsPerRow = sourceRect.size.width;

    scaledRowDataSize = pixelsPerRow * scalingFactor * sizeof(PPImageBitmapPixel);

    switch (gridType)
    {
        case kPPGridType_Lines:     // GRIDTYPE: Lines
        {
            unsigned char *scaledHorizontalGridLineData;

            // set up horizontal grid line

            scaledHorizontalGridLineData = destinationRow;

            currentScaledPixel = (PPImageBitmapPixel *) scaledHorizontalGridLineData;
            scaledPixelCounter = pixelsPerRow * scalingFactor;

            while (scaledPixelCounter--)
            {
                *currentScaledPixel++ = gridPixelValue;
            }

            // row loop

            rowCounter = sourceRect.size.height;

            while (rowCounter--)
            {
                // copy horizontal grid line

                if (destinationRow != scaledHorizontalGridLineData)
                {
                    memcpy(destinationRow, scaledHorizontalGridLineData, scaledRowDataSize);
                }

                destinationRow += destinationBytesPerRow;

                // set up scaled row data

                scaledRowData = destinationRow;

                currentSourcePixel = (PPImageBitmapPixel *) sourceRow;
                currentScaledPixel = (PPImageBitmapPixel *) scaledRowData;

                pixelCounter = pixelsPerRow;

                while (pixelCounter--)
                {
                    // vertical grid line
                    *currentScaledPixel++ = gridPixelValue;

                    // scaled source-pixel data
                    scaledPixelCounter = scalingFactor - 1;

                    while (scaledPixelCounter--)
                    {
                        *currentScaledPixel++ = *currentSourcePixel;
                    }

                    currentSourcePixel++;
                }

                destinationRow += destinationBytesPerRow;

                // copy scaled row data to remaining rows

                scaledRowCounter = scalingFactor - 2;

                while (scaledRowCounter--)
                {
                    memcpy(destinationRow, scaledRowData, scaledRowDataSize);
                    destinationRow += destinationBytesPerRow;
                }

                sourceRow += sourceBytesPerRow;
            }
        }
        break;

        case kPPGridType_Dots:  // GRIDTYPE: Dots
        {
            rowCounter = sourceRect.size.height;

            while (rowCounter--)
            {
                // set up scaled row data

                scaledRowData = destinationRow;

                currentSourcePixel = (PPImageBitmapPixel *) sourceRow;
                currentScaledPixel = (PPImageBitmapPixel *) scaledRowData;

                pixelCounter = pixelsPerRow;

                while (pixelCounter--)
                {
                    // scaled source-pixel data (no grid pixels - dots are drawn at the end)

                    scaledPixelCounter = scalingFactor;

                    while (scaledPixelCounter--)
                    {
                        *currentScaledPixel++ = *currentSourcePixel;
                    }

                    currentSourcePixel++;
                }

                destinationRow += destinationBytesPerRow;

                // copy scaled row data to remaining rows

                scaledRowCounter = scalingFactor - 1;

                while (scaledRowCounter--)
                {
                    memcpy(destinationRow, scaledRowData, scaledRowDataSize);
                    destinationRow += destinationBytesPerRow;
                }

                // draw dots to first scaled row

                currentScaledPixel = (PPImageBitmapPixel *) scaledRowData;

                pixelCounter = pixelsPerRow;

                while (pixelCounter--)
                {
                    *currentScaledPixel = gridPixelValue;
                    currentScaledPixel += scalingFactor;
                }

                sourceRow += sourceBytesPerRow;
            }
        }
        break;

        default:    // GRIDTYPE: Crosshairs or Large Dots
        {
            unsigned gridLegLength, numScaledPixelsBetweenGridLegs;
            unsigned char *scaledRowWithVerticalGridLegData;

            if (gridType == kPPGridType_LargeDots)
            {
                // Large Dots
                gridLegLength = 1;
            }
            else
            {
                // Crosshairs
                gridLegLength = roundf(scalingFactor * kCrosshairLegSizeToScalingFactorRatio);
            }

            numScaledPixelsBetweenGridLegs = scalingFactor - 2 * gridLegLength - 1;

            // row loop

            rowCounter = sourceRect.size.height;

            while (rowCounter--)
            {
                // set up scaled row data

                scaledRowData = destinationRow;

                currentSourcePixel = (PPImageBitmapPixel *) sourceRow;
                currentScaledPixel = (PPImageBitmapPixel *) scaledRowData;

                pixelCounter = pixelsPerRow;

                while (pixelCounter--)
                {
                   // scaled source-pixel data (no grid pixels)

                    scaledPixelCounter = scalingFactor;

                    while (scaledPixelCounter--)
                    {
                        *currentScaledPixel++ = *currentSourcePixel;
                    }

                    currentSourcePixel++;
                }

                destinationRow += destinationBytesPerRow;

                // set up scaled row with vertical grid-leg data (single left-edge grid-pixel)

                scaledRowWithVerticalGridLegData = destinationRow;
                memcpy(scaledRowWithVerticalGridLegData, scaledRowData, scaledRowDataSize);

                currentScaledPixel = (PPImageBitmapPixel *) scaledRowWithVerticalGridLegData;

                pixelCounter = pixelsPerRow;

                while (pixelCounter--)
                {
                    *currentScaledPixel = gridPixelValue;
                    currentScaledPixel += scalingFactor;
                }

                destinationRow += destinationBytesPerRow;

                // copy scaled row with vertical grid-leg data to upper rows

                scaledRowCounter = gridLegLength - 1;

                while (scaledRowCounter--)
                {
                    memcpy(destinationRow, scaledRowWithVerticalGridLegData, scaledRowDataSize);
                    destinationRow += destinationBytesPerRow;
                }

                // copy scaled row data between grid-leg rows

                scaledRowCounter = numScaledPixelsBetweenGridLegs;

                while (scaledRowCounter--)
                {
                    memcpy(destinationRow, scaledRowData, scaledRowDataSize);
                    destinationRow += destinationBytesPerRow;
                }

                // copy scaled row with vertical grid-leg data to lower rows

                scaledRowCounter = gridLegLength;

                while (scaledRowCounter--)
                {
                    memcpy(destinationRow, scaledRowWithVerticalGridLegData, scaledRowDataSize);
                    destinationRow += destinationBytesPerRow;
                }

                // draw horizontal grid-legs on first scaled row

                currentScaledPixel = (PPImageBitmapPixel *) scaledRowData;

                pixelCounter = pixelsPerRow;

                while (pixelCounter--)
                {
                    // center pixel at intersection of horizontal & vertical grid legs
                    *currentScaledPixel++ = gridPixelValue;

                    scaledPixelCounter = gridLegLength;

                    while (scaledPixelCounter--)
                    {
                        *currentScaledPixel++ = gridPixelValue;
                    }

                    currentScaledPixel += numScaledPixelsBetweenGridLegs;

                    scaledPixelCounter = gridLegLength;

                    while (scaledPixelCounter--)
                    {
                        *currentScaledPixel++ = gridPixelValue;
                    }
                }

                sourceRow += sourceBytesPerRow;
            }
        }
        break;
    }

    return;

ERROR:
    return;
}

- (NSBitmapImageRep *) ppImageBitmapWithMaxDimension: (float) maxDimension
{
    NSSize originalBitmapSize, maxSize, shrunkenBitmapSize;
    NSBitmapImageRep *shrunkenBitmap;
    NSImage *originalBitmapImage;

    originalBitmapSize = [self ppSizeInPixels];

    if (!PPGeometry_SizeExceedsDimension(originalBitmapSize, maxDimension))
    {
        return [self ppImageBitmap];
    }

    maxSize = NSMakeSize(maxDimension, maxDimension);

    shrunkenBitmapSize =
        PPGeometry_ScaledBoundsForFrameOfSizeToFitFrameOfSize(originalBitmapSize, maxSize).size;

    shrunkenBitmap = [NSBitmapImageRep ppImageBitmapOfSize: shrunkenBitmapSize];

    originalBitmapImage = [NSImage ppImageWithBitmap: self];

    if (!shrunkenBitmap || !originalBitmapImage)
    {
        goto ERROR;
    }

    [shrunkenBitmap ppSetAsCurrentGraphicsContext];

    [[NSGraphicsContext currentContext] setImageInterpolation: NSImageInterpolationNone];

    [originalBitmapImage drawInRect: PPGeometry_OriginRectOfSize(shrunkenBitmapSize)
                            fromRect: PPGeometry_OriginRectOfSize(originalBitmapSize)
                            operation: NSCompositeCopy
                            fraction: 1.0f];

    [shrunkenBitmap ppRestoreGraphicsContext];

    return shrunkenBitmap;

ERROR:
    return nil;
}

- (NSBitmapImageRep *) ppImageBitmapCompositedWithBackgroundColor: (NSColor *) backgroundColor
                        andBackgroundImage: (NSImage *) backgroundImage
                        backgroundImageInterpolation:
                                        (NSImageInterpolation) backgroundImageInterpolation
{
    NSRect bitmapFrame;
    NSBitmapImageRep *compositedBitmap;
    NSImage *bitmapImage;

    if (!backgroundColor && !backgroundImage)
    {
        goto ERROR;
    }

    bitmapFrame = [self ppFrameInPixels];
    compositedBitmap = [NSBitmapImageRep ppImageBitmapOfSize: bitmapFrame.size];

    bitmapImage = [NSImage ppImageWithBitmap: self];

    if (!compositedBitmap || !bitmapImage)
    {
        goto ERROR;
    }

    [compositedBitmap ppSetAsCurrentGraphicsContext];

    if (backgroundColor)
    {
        [backgroundColor set];
        NSRectFill(bitmapFrame);
    }

    if (backgroundImage)
    {
        NSRect backgroundImageFrame, backgroundDestinationBounds;

        backgroundImageFrame = PPGeometry_OriginRectOfSize([backgroundImage size]);

        backgroundDestinationBounds =
            PPGeometry_ScaledBoundsForFrameOfSizeToFitFrameOfSize(backgroundImageFrame.size,
                                                                    bitmapFrame.size);

        [[NSGraphicsContext currentContext]
                                        setImageInterpolation: backgroundImageInterpolation];

        [backgroundImage drawInRect: backgroundDestinationBounds
                            fromRect: backgroundImageFrame
                            operation: NSCompositeSourceOver
                            fraction: 1.0f];
    }

    [[NSGraphicsContext currentContext] setImageInterpolation: NSImageInterpolationNone];

    [bitmapImage drawInRect: bitmapFrame
                    fromRect: bitmapFrame
                    operation: NSCompositeSourceOver
                    fraction: 1.0f];

    [compositedBitmap ppRestoreGraphicsContext];

    return compositedBitmap;

ERROR:
    return self;
}

- (NSBitmapImageRep *) ppImageBitmapDissolvedToOpacity: (float) opacity
{
    NSBitmapImageRep *dissolvedBitmap;

    if (![self ppIsImageBitmap])
    {
        goto ERROR;
    }

    if (opacity >= 1.0f)
    {
        dissolvedBitmap = [[self copy] autorelease];

        if (!dissolvedBitmap)
            goto ERROR;
    }
    else
    {
        NSRect bitmapFrame = [self ppFrameInPixels];

        dissolvedBitmap = [NSBitmapImageRep ppImageBitmapOfSize: bitmapFrame.size];

        if (!dissolvedBitmap)
            goto ERROR;

        if (opacity > 0.0f)
        {
            NSImage *image = [NSImage ppImageWithBitmap: self];

            if (!image)
                goto ERROR;

            [dissolvedBitmap ppSetAsCurrentGraphicsContext];

            [image drawInRect: bitmapFrame
                    fromRect: bitmapFrame
                    operation: NSCompositeCopy
                    fraction: opacity];

            [dissolvedBitmap ppRestoreGraphicsContext];
        }
    }

    return dissolvedBitmap;

ERROR:
    return nil;
}

- (NSBitmapImageRep *) ppImageBitmapMaskedWithMask: (NSBitmapImageRep *) maskBitmap
{
    NSBitmapImageRep *maskedBitmap;

    if (![self ppIsImageBitmapAndSameSizeAsMaskBitmap: maskBitmap])
    {
        goto ERROR;
    }

    maskedBitmap = [NSBitmapImageRep ppImageBitmapOfSize: [self ppSizeInPixels]];

    if (!maskedBitmap)
        goto ERROR;

    [maskedBitmap ppMaskedCopyFromImageBitmap: self
                    usingMask: maskBitmap];

    return maskedBitmap;

ERROR:
    return nil;
}

- (NSBitmapImageRep *) ppImageBitmapScaledByFactor: (unsigned) scalingFactor
                        shouldDrawGrid: (bool) shouldDrawGrid
                        gridType: (PPGridType) gridType
                        gridColor: (NSColor *) gridColor
{
    NSRect bitmapFrame;
    NSSize scaledBitmapSize;
    NSBitmapImageRep *scaledBitmap;

    if (![self ppIsImageBitmap] || !scalingFactor)
    {
        goto ERROR;
    }

    bitmapFrame = [self ppFrameInPixels];

    scaledBitmapSize = NSMakeSize(bitmapFrame.size.width * scalingFactor,
                                    bitmapFrame.size.height * scalingFactor);

    scaledBitmap = [NSBitmapImageRep ppImageBitmapOfSize: scaledBitmapSize];

    if (!scaledBitmap)
        goto ERROR;

    if (shouldDrawGrid)
    {
        [scaledBitmap ppScaledCopyFromImageBitmap: self
                        inRect: bitmapFrame
                        toPoint: NSZeroPoint
                        scalingFactor: scalingFactor
                        gridType: gridType
                        gridPixelValue: [gridColor ppImageBitmapPixelValue]];
    }
    else
    {
        [scaledBitmap ppScaledCopyFromImageBitmap: self
                        inRect: bitmapFrame
                        toPoint: NSZeroPoint
                        scalingFactor: scalingFactor];
    }

    return scaledBitmap;

ERROR:
    return nil;
}

- (NSBitmapImageRep *) ppMaskBitmapForVisiblePixelsInImageBitmap
{
    NSSize bitmapSize;
    NSBitmapImageRep *maskBitmap;

    if (![self ppIsImageBitmap])
    {
        goto ERROR;
    }

    bitmapSize = [self ppSizeInPixels];

    if (PPGeometry_IsZeroSize(bitmapSize))
    {
        goto ERROR;
    }

    maskBitmap = [NSBitmapImageRep ppMaskBitmapOfSize: bitmapSize];

    if (!maskBitmap)
        goto ERROR;

    [maskBitmap ppMaskVisiblePixelsInImageBitmap: self selectionMask: nil];

    return maskBitmap;

ERROR:
    return nil;
}

- (void) ppDrawImageGuidelinesInBounds: (NSRect) drawBounds
            topLeftPhase: (NSPoint) topLeftPhase
            unscaledSpacingSize: (NSSize) unscaledSpacingSize
            scalingFactor: (unsigned) scalingFactor
            guidelinePixelValue: (PPImageBitmapPixel) guidelinePixelValue
{
    NSRect bitmapFrame;
    int colOffsetToNextVerticalLine, rowOffsetToNextHorizontalLine, drawBoundsLeftCol,
        drawBoundsRightCol, drawBoundsTopRow, drawBoundsBottomRow, colOfFirstVerticalLine,
        numVerticalLines = 0, rowOfFirstHorizontalLine, numHorizontalLines = 0, bytesPerRow,
        startRow, rowIncrement, rowDataOffsetToFirstVerticalLine, dataOffset, rowDataIncrement,
        horizontalLineDataSize, rowOfNextHorizontalLine, row, verticalLineCounter;
    NSPoint offsetToNextGuidelineVertex;
    unsigned char *bitmapData, *previousHorizontalLineData = NULL, *rowData;
    PPImageBitmapPixel *verticalLinePixel;

    if (![self ppIsImageBitmap])
    {
        goto ERROR;
    }

    bitmapFrame = [self ppFrameInPixels];

    drawBounds =
        NSIntersectionRect(PPGeometry_PixelBoundsCoveredByRect(drawBounds), bitmapFrame);

    if (NSIsEmptyRect(drawBounds))
    {
        goto ERROR;
    }

    topLeftPhase = PPGeometry_PointClippedToIntegerValues(topLeftPhase);

    if (scalingFactor > kMaxCanvasZoomFactor)
    {
        goto ERROR;
    }

    colOffsetToNextVerticalLine = unscaledSpacingSize.width * scalingFactor;
    rowOffsetToNextHorizontalLine = unscaledSpacingSize.height * scalingFactor;

    if ((colOffsetToNextVerticalLine < kMinScalingFactorToDrawGrid)
        || (rowOffsetToNextHorizontalLine < kMinScalingFactorToDrawGrid))
    {
        // guidelines are too close together at current scalingFactor, so don't draw
        return;
    }

    drawBoundsLeftCol = drawBounds.origin.x;
    drawBoundsRightCol = drawBoundsLeftCol + drawBounds.size.width - 1;

    drawBoundsTopRow =
                bitmapFrame.size.height - (drawBounds.origin.y + drawBounds.size.height);
    drawBoundsBottomRow = drawBoundsTopRow + drawBounds.size.height - 1;

    offsetToNextGuidelineVertex =
        PPGeometry_OffsetPointToNextNearestVertexOnGridWithSpacingSize(
                                                NSMakePoint(drawBoundsLeftCol + topLeftPhase.x,
                                                            drawBoundsTopRow + topLeftPhase.y),
                                                NSMakeSize(colOffsetToNextVerticalLine,
                                                            rowOffsetToNextHorizontalLine));

    if ((offsetToNextGuidelineVertex.x < 0) || (offsetToNextGuidelineVertex.y < 0))
    {
        goto ERROR;
    }

    colOfFirstVerticalLine = drawBoundsLeftCol + offsetToNextGuidelineVertex.x;

    if (colOfFirstVerticalLine <= drawBoundsRightCol)
    {
        numVerticalLines = 1 + (drawBoundsRightCol - colOfFirstVerticalLine)
                                    / colOffsetToNextVerticalLine;
    }

    rowOfFirstHorizontalLine = drawBoundsTopRow + offsetToNextGuidelineVertex.y;

    if (rowOfFirstHorizontalLine <= drawBoundsBottomRow)
    {
        numHorizontalLines = 1 + (drawBoundsBottomRow - rowOfFirstHorizontalLine)
                                    / rowOffsetToNextHorizontalLine;
    }

    if (!numVerticalLines && !numHorizontalLines)
    {
        // no guidelines within drawBounds - nothing to draw
        return;
    }

    bitmapData = [self bitmapData];
    bytesPerRow = [self bytesPerRow];

    if (!bitmapData || (bytesPerRow <= 0))
    {
        goto ERROR;
    }

    if (numVerticalLines > 0)
    {
        startRow = drawBoundsTopRow;
        rowIncrement = 1;

        rowDataOffsetToFirstVerticalLine =
                    (colOfFirstVerticalLine - drawBoundsLeftCol) * sizeof(PPImageBitmapPixel);
    }
    else
    {
        // no vertical guidelines within drawBounds - only need to draw horizontal guidelines
        startRow = rowOfFirstHorizontalLine;
        rowIncrement = rowOffsetToNextHorizontalLine;

        rowDataOffsetToFirstVerticalLine = 0;   // avoids analyzer warning (undefined subscript)
    }

    dataOffset = startRow * bytesPerRow + drawBoundsLeftCol * sizeof(PPImageBitmapPixel);

    rowData = &bitmapData[dataOffset];

    rowDataIncrement = rowIncrement * bytesPerRow;

    horizontalLineDataSize = drawBounds.size.width * sizeof(PPImageBitmapPixel);

    rowOfNextHorizontalLine = rowOfFirstHorizontalLine;

    row = startRow;

    while (row <= drawBoundsBottomRow)
    {
        if (row == rowOfNextHorizontalLine)
        {
            // row with horizontal line

            if (!previousHorizontalLineData)
            {
                PPImageBitmapPixel *currentPixel = (PPImageBitmapPixel *) rowData;
                int pixelCounter = drawBounds.size.width;

                while (pixelCounter--)
                {
                    *currentPixel++ = guidelinePixelValue;
                }
            }
            else
            {
                memcpy(rowData, previousHorizontalLineData, horizontalLineDataSize);
            }

            previousHorizontalLineData = rowData;

            rowOfNextHorizontalLine += rowOffsetToNextHorizontalLine;
        }
        else
        {
            // row with vertical lines

            verticalLinePixel =
                        (PPImageBitmapPixel *) &rowData[rowDataOffsetToFirstVerticalLine];

            verticalLineCounter = numVerticalLines;

            while (verticalLineCounter--)
            {
                *verticalLinePixel = guidelinePixelValue;

                verticalLinePixel += colOffsetToNextVerticalLine;
            }
        }

        rowData += rowDataIncrement;
        row += rowIncrement;
    }

    return;

ERROR:
    return;
}

@end
