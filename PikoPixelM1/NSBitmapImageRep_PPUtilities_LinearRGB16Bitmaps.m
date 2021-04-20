/*
    NSBitmapImageRep_PPUtilities_LinearRGB16Bitmaps.m

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
#import "PPImagePixelAlphaPremultiplyTables.h"
#import "PPSRGBUtilities.h"


#define kLinearRGB16BitmapBitsPerSample                                             \
            (sizeof(PPLinear16PixelComponent) * 8)

#define kLinearRGB16BitmapSamplesPerPixel                                           \
            (sizeof(PPLinearRGB16BitmapPixel) / sizeof(PPLinear16PixelComponent))


#define kImagePixelComponentToLinear16PixelComponentConversionFactor                \
            (kMaxLinear16PixelComponentValue / kMaxImagePixelComponentValue)

#define macroRoundoffValueForDivisor(divisor)                                       \
            (((divisor) + 1) / 2)

#define kImageToLinear16ConversionPrenormalizationRoundoff                          \
            macroRoundoffValueForDivisor(                                           \
                kImagePixelComponentToLinear16PixelComponentConversionFactor)

#define kLinear16PixelComponentPrenormalizationRoundoff                             \
            macroRoundoffValueForDivisor(kMaxLinear16PixelComponentValue)


#define macroClampFloatValueTo0_1(floatValue)                                       \
            ((floatValue >= 1.0f) ? 1.0f : ((floatValue <= 0.0f) ? 0.0f : floatValue))


static PPImagePixelComponent *gSRGBValuesForLinear16ValuesTable;
static PPLinear16PixelComponent *gLinear16ValuesForSRGBValuesTable;


static bool SetupGlobalLinearConversionTables(void);


@implementation NSBitmapImageRep (PPUtilities_LinearRGB16Bitmaps)

+ (void) load
{
    SetupGlobalLinearConversionTables();
}

+ (NSBitmapImageRep *) ppLinearRGB16BitmapOfSize: (NSSize) size
{
    NSBitmapImageRep *linearBitmap;

    size = PPGeometry_SizeClippedToIntegerValues(size);

    if (PPGeometry_IsZeroSize(size))
    {
        goto ERROR;
    }

    linearBitmap =
            [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes: NULL
                                        pixelsWide: size.width
                                        pixelsHigh: size.height
                                        bitsPerSample: kLinearRGB16BitmapBitsPerSample
                                        samplesPerPixel: kLinearRGB16BitmapSamplesPerPixel
                                        hasAlpha: YES
                                        isPlanar: NO
                                        colorSpaceName: NSDeviceRGBColorSpace
                                        bitmapFormat: NSAlphaNonpremultipliedBitmapFormat
                                        bytesPerRow: 0
                                        bitsPerPixel: 0]
                                autorelease];

    if (!linearBitmap)
        goto ERROR;

    [linearBitmap ppClearBitmap];

    return linearBitmap;

ERROR:
    return nil;

}

- (NSBitmapImageRep *) ppLinearRGB16BitmapFromImageBitmap
{
    NSRect frame;
    NSBitmapImageRep *linearBitmap;

    if (![self ppIsImageBitmap])
    {
        goto ERROR;
    }

    frame = [self ppFrameInPixels];

    if (NSIsEmptyRect(frame))
    {
        goto ERROR;
    }

    linearBitmap = [NSBitmapImageRep ppLinearRGB16BitmapOfSize: frame.size];

    if (!linearBitmap)
        goto ERROR;

    [linearBitmap ppLinearCopyFromImageBitmap: self inBounds: frame];

    return linearBitmap;

ERROR:
    return nil;
}

- (NSBitmapImageRep *) ppImageBitmapFromLinearRGB16Bitmap
{
    NSRect frame;
    NSBitmapImageRep *imageBitmap;

    if (![self ppIsLinearRGB16Bitmap])
    {
        goto ERROR;
    }

    frame = [self ppFrameInPixels];

    if (NSIsEmptyRect(frame))
    {
        goto ERROR;
    }

    imageBitmap = [NSBitmapImageRep ppImageBitmapOfSize: frame.size];

    if (!imageBitmap)
        goto ERROR;

    [self ppLinearCopyToImageBitmap: imageBitmap inBounds: frame];

    return imageBitmap;

ERROR:
    return nil;
}

- (bool) ppIsLinearRGB16Bitmap
{
    return (([self bitsPerSample] == kLinearRGB16BitmapBitsPerSample)
                && ([self samplesPerPixel] == kLinearRGB16BitmapSamplesPerPixel))
            ? YES : NO;
}

- (void) ppLinearCopyFromImageBitmap: (NSBitmapImageRep *) sourceBitmap
            inBounds: (NSRect) copyBounds
{
    NSRect bitmapFrame;
    unsigned char *destinationData, *sourceData, *destinationRow, *sourceRow;
    int destinationBytesPerRow, sourceBytesPerRow, rowOffset, destinationDataOffset,
            sourceDataOffset, pixelsPerRow, rowCounter, pixelCounter;
    PPLinearRGB16BitmapPixel *destinationPixel;
    PPImageBitmapPixel *sourcePixel;
    PPImagePixelComponent *unpremultiplyTable;

    if (![self ppIsLinearRGB16Bitmap]
        || ![sourceBitmap ppIsImageBitmap])
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

    if (!destinationData || !sourceData)
    {
        goto ERROR;
    }

    destinationBytesPerRow = [self bytesPerRow];
    sourceBytesPerRow = [sourceBitmap bytesPerRow];

    rowOffset = bitmapFrame.size.height - copyBounds.size.height - copyBounds.origin.y;

    destinationDataOffset =
        rowOffset * destinationBytesPerRow
            + copyBounds.origin.x * sizeof(PPLinearRGB16BitmapPixel);

    sourceDataOffset =
        rowOffset * sourceBytesPerRow + copyBounds.origin.x * sizeof(PPImageBitmapPixel);

    destinationRow = &destinationData[destinationDataOffset];
    sourceRow = &sourceData[sourceDataOffset];

    pixelsPerRow = copyBounds.size.width;
    rowCounter = copyBounds.size.height;

    while (rowCounter--)
    {
        destinationPixel = (PPLinearRGB16BitmapPixel *) destinationRow;
        sourcePixel = (PPImageBitmapPixel *) sourceRow;

        pixelCounter = pixelsPerRow;

        while (pixelCounter--)
        {
            if (macroImagePixelComponent_Alpha(sourcePixel) == 0)
            {
                *destinationPixel = 0;
            }
            else if (macroImagePixelComponent_Alpha(sourcePixel)
                        == kMaxImagePixelComponentValue)
            {
                macroLinearRGB16PixelComponent_Red(destinationPixel) =
                    gLinear16ValuesForSRGBValuesTable[
                                                macroImagePixelComponent_Red(sourcePixel)];

                macroLinearRGB16PixelComponent_Green(destinationPixel) =
                    gLinear16ValuesForSRGBValuesTable[
                                                macroImagePixelComponent_Green(sourcePixel)];

                macroLinearRGB16PixelComponent_Blue(destinationPixel) =
                    gLinear16ValuesForSRGBValuesTable[
                                                macroImagePixelComponent_Blue(sourcePixel)];

                macroLinearRGB16PixelComponent_Alpha(destinationPixel) =
                                                            kMaxLinear16PixelComponentValue;
            }
            else
            {
                unpremultiplyTable = macroAlphaUnpremultiplyTableForImagePixel(sourcePixel);

                macroLinearRGB16PixelComponent_Red(destinationPixel) =
                    gLinear16ValuesForSRGBValuesTable[
                            unpremultiplyTable[macroImagePixelComponent_Red(sourcePixel)]];

                macroLinearRGB16PixelComponent_Green(destinationPixel) =
                    gLinear16ValuesForSRGBValuesTable[
                            unpremultiplyTable[macroImagePixelComponent_Green(sourcePixel)]];

                macroLinearRGB16PixelComponent_Blue(destinationPixel) =
                    gLinear16ValuesForSRGBValuesTable[
                            unpremultiplyTable[macroImagePixelComponent_Blue(sourcePixel)]];

                macroLinearRGB16PixelComponent_Alpha(destinationPixel) =
                    ((int) macroImagePixelComponent_Alpha(sourcePixel))
                        * kImagePixelComponentToLinear16PixelComponentConversionFactor;

            }

            destinationPixel++;
            sourcePixel++;
        }

        destinationRow += destinationBytesPerRow;
        sourceRow += sourceBytesPerRow;
    }

    return;

ERROR:
    return;
}

- (void) ppLinearCopyToImageBitmap: (NSBitmapImageRep *) destinationBitmap
            inBounds: (NSRect) copyBounds
{
    NSRect bitmapFrame;
    unsigned char *destinationData, *sourceData, *destinationRow, *sourceRow;
    int destinationBytesPerRow, sourceBytesPerRow, rowOffset, destinationDataOffset,
            sourceDataOffset, pixelsPerRow, rowCounter, pixelCounter;
    PPImageBitmapPixel *destinationPixel;
    PPLinearRGB16BitmapPixel *sourcePixel;
    PPImagePixelComponent *premultiplyTable;

    if (![self ppIsLinearRGB16Bitmap]
        || ![destinationBitmap ppIsImageBitmap])
    {
        goto ERROR;
    }

    bitmapFrame = [self ppFrameInPixels];

    if (!NSEqualSizes(bitmapFrame.size, [destinationBitmap ppSizeInPixels]))
    {
        goto ERROR;
    }

    copyBounds =
            NSIntersectionRect(PPGeometry_PixelBoundsCoveredByRect(copyBounds), bitmapFrame);

    if (NSIsEmptyRect(copyBounds))
    {
        goto ERROR;
    }

    destinationData = [destinationBitmap bitmapData];
    sourceData = [self bitmapData];

    if (!destinationData || !sourceData)
    {
        goto ERROR;
    }

    destinationBytesPerRow = [destinationBitmap bytesPerRow];
    sourceBytesPerRow = [self bytesPerRow];

    rowOffset = bitmapFrame.size.height - copyBounds.size.height - copyBounds.origin.y;

    destinationDataOffset =
        rowOffset * destinationBytesPerRow + copyBounds.origin.x * sizeof(PPImageBitmapPixel);

    sourceDataOffset =
        rowOffset * sourceBytesPerRow + copyBounds.origin.x * sizeof(PPLinearRGB16BitmapPixel);

    destinationRow = &destinationData[destinationDataOffset];
    sourceRow = &sourceData[sourceDataOffset];

    pixelsPerRow = copyBounds.size.width;
    rowCounter = copyBounds.size.height;

    while (rowCounter--)
    {
        destinationPixel = (PPImageBitmapPixel *) destinationRow;
        sourcePixel = (PPLinearRGB16BitmapPixel *) sourceRow;

        pixelCounter = pixelsPerRow;

        while (pixelCounter--)
        {
            macroImagePixelComponent_Alpha(destinationPixel) =
                (macroLinearRGB16PixelComponent_Alpha(sourcePixel)
                    + kImageToLinear16ConversionPrenormalizationRoundoff)
                / kImagePixelComponentToLinear16PixelComponentConversionFactor;

            if (macroImagePixelComponent_Alpha(destinationPixel) == 0)
            {
                *destinationPixel = 0;
            }
            else if (macroImagePixelComponent_Alpha(destinationPixel)
                        == kMaxImagePixelComponentValue)
            {
                macroImagePixelComponent_Red(destinationPixel) =
                    gSRGBValuesForLinear16ValuesTable[
                                            macroLinearRGB16PixelComponent_Red(sourcePixel)];

                macroImagePixelComponent_Green(destinationPixel) =
                    gSRGBValuesForLinear16ValuesTable[
                                            macroLinearRGB16PixelComponent_Green(sourcePixel)];

                macroImagePixelComponent_Blue(destinationPixel) =
                    gSRGBValuesForLinear16ValuesTable[
                                            macroLinearRGB16PixelComponent_Blue(sourcePixel)];
            }
            else
            {
                premultiplyTable = macroAlphaPremultiplyTableForImagePixel(destinationPixel);

                macroImagePixelComponent_Red(destinationPixel) =
                    premultiplyTable[
                        gSRGBValuesForLinear16ValuesTable[
                            macroLinearRGB16PixelComponent_Red(sourcePixel)]];

                macroImagePixelComponent_Green(destinationPixel) =
                    premultiplyTable[
                        gSRGBValuesForLinear16ValuesTable[
                            macroLinearRGB16PixelComponent_Green(sourcePixel)]];

                macroImagePixelComponent_Blue(destinationPixel) =
                    premultiplyTable[
                        gSRGBValuesForLinear16ValuesTable[
                            macroLinearRGB16PixelComponent_Blue(sourcePixel)]];
            }

            destinationPixel++;
            sourcePixel++;
        }

        destinationRow += destinationBytesPerRow;
        sourceRow += sourceBytesPerRow;
    }

    return;

ERROR:
    return;
}

- (void) ppLinearBlendFromLinearBitmapUnderneath: (NSBitmapImageRep *) sourceBitmap
            sourceOpacity: (float) sourceOpacity
            inBounds: (NSRect) blendingBounds
{
    NSRect bitmapFrame;
    unsigned char *destinationData, *sourceData, *destinationRow, *sourceRow;
    unsigned int sourceOpacityFactor, destinationComponentAlphaFactor,
                    sourceComponentAlphaFactor, sumOfAlphaFactors,
                    alphaFactorsPrenormalizationRoundoff;
    int destinationBytesPerRow, sourceBytesPerRow, rowOffset,
            destinationDataOffset, sourceDataOffset, pixelsPerRow, rowCounter, pixelCounter;
    PPLinearRGB16BitmapPixel *destinationPixel, *sourcePixel;

    if (![self ppIsLinearRGB16Bitmap]
        || ![sourceBitmap ppIsLinearRGB16Bitmap])
    {
        goto ERROR;
    }

    sourceOpacity = macroClampFloatValueTo0_1(sourceOpacity);

    sourceOpacityFactor = roundf(sourceOpacity * kMaxLinear16PixelComponentValue);

    if (sourceOpacityFactor == 0)
    {
        return;
    }

    bitmapFrame = [self ppFrameInPixels];

    if (!NSEqualSizes(bitmapFrame.size, [sourceBitmap ppSizeInPixels]))
    {
        goto ERROR;
    }

    blendingBounds =
        NSIntersectionRect(PPGeometry_PixelBoundsCoveredByRect(blendingBounds), bitmapFrame);

    if (NSIsEmptyRect(blendingBounds))
    {
        goto ERROR;
    }

    destinationData = [self bitmapData];
    sourceData = [sourceBitmap bitmapData];

    if (!destinationData || !sourceData)
    {
        goto ERROR;
    }

    destinationBytesPerRow = [self bytesPerRow];
    sourceBytesPerRow = [sourceBitmap bytesPerRow];

    rowOffset = bitmapFrame.size.height - blendingBounds.size.height - blendingBounds.origin.y;

    destinationDataOffset =
        rowOffset * destinationBytesPerRow
        + blendingBounds.origin.x * sizeof(PPLinearRGB16BitmapPixel);

    sourceDataOffset =
        rowOffset * sourceBytesPerRow
        + blendingBounds.origin.x * sizeof(PPLinearRGB16BitmapPixel);

    destinationRow = &destinationData[destinationDataOffset];
    sourceRow = &sourceData[sourceDataOffset];

    pixelsPerRow = blendingBounds.size.width;
    rowCounter = blendingBounds.size.height;

    if (sourceOpacityFactor < kMaxLinear16PixelComponentValue)
    {
        while (rowCounter--)
        {
            destinationPixel = (PPLinearRGB16BitmapPixel *) destinationRow;
            sourcePixel = (PPLinearRGB16BitmapPixel *) sourceRow;

            pixelCounter = pixelsPerRow;

            while (pixelCounter--)
            {
                if (macroLinearRGB16PixelComponent_Alpha(destinationPixel) > 0)
                {
                    if ((macroLinearRGB16PixelComponent_Alpha(destinationPixel)
                                < kMaxLinear16PixelComponentValue)
                        && (macroLinearRGB16PixelComponent_Alpha(sourcePixel) > 0))
                    {
                        destinationComponentAlphaFactor =
                                    macroLinearRGB16PixelComponent_Alpha(destinationPixel);

                        sourceComponentAlphaFactor =
                            (sourceOpacityFactor
                                * (kMaxLinear16PixelComponentValue
                                    - destinationComponentAlphaFactor)
                                + kLinear16PixelComponentPrenormalizationRoundoff)
                            / kMaxLinear16PixelComponentValue;

                        if (macroLinearRGB16PixelComponent_Alpha(sourcePixel)
                                < kMaxLinear16PixelComponentValue)
                        {
                            sourceComponentAlphaFactor =
                                (sourceComponentAlphaFactor
                                    * macroLinearRGB16PixelComponent_Alpha(sourcePixel)
                                    + kLinear16PixelComponentPrenormalizationRoundoff)
                                / kMaxLinear16PixelComponentValue;
                        }

                        sumOfAlphaFactors =
                            destinationComponentAlphaFactor + sourceComponentAlphaFactor;

                        alphaFactorsPrenormalizationRoundoff =
                            macroRoundoffValueForDivisor(sumOfAlphaFactors);

                        macroLinearRGB16PixelComponent_Red(destinationPixel) =
                            (destinationComponentAlphaFactor
                                    * macroLinearRGB16PixelComponent_Red(destinationPixel)
                                + sourceComponentAlphaFactor
                                    * macroLinearRGB16PixelComponent_Red(sourcePixel)
                                + alphaFactorsPrenormalizationRoundoff)
                            / sumOfAlphaFactors;

                        macroLinearRGB16PixelComponent_Green(destinationPixel) =
                            (destinationComponentAlphaFactor
                                    * macroLinearRGB16PixelComponent_Green(destinationPixel)
                                + sourceComponentAlphaFactor
                                    * macroLinearRGB16PixelComponent_Green(sourcePixel)
                                + alphaFactorsPrenormalizationRoundoff)
                            / sumOfAlphaFactors;

                        macroLinearRGB16PixelComponent_Blue(destinationPixel) =
                            (destinationComponentAlphaFactor
                                    * macroLinearRGB16PixelComponent_Blue(destinationPixel)
                                + sourceComponentAlphaFactor
                                    * macroLinearRGB16PixelComponent_Blue(sourcePixel)
                                + alphaFactorsPrenormalizationRoundoff)
                            / sumOfAlphaFactors;

                        macroLinearRGB16PixelComponent_Alpha(destinationPixel) =
                            sumOfAlphaFactors;
                    }
                }
                else if (macroLinearRGB16PixelComponent_Alpha(sourcePixel) > 0)
                {
                    *destinationPixel = *sourcePixel;

                    macroLinearRGB16PixelComponent_Alpha(destinationPixel) =
                        (sourceOpacityFactor
                                * macroLinearRGB16PixelComponent_Alpha(destinationPixel)
                                + kLinear16PixelComponentPrenormalizationRoundoff)
                            / kMaxLinear16PixelComponentValue;
                }

                destinationPixel++;
                sourcePixel++;
            }

            destinationRow += destinationBytesPerRow;
            sourceRow += sourceBytesPerRow;
        }
    }
    else    // sourceOpacity is 1.0
    {
        while (rowCounter--)
        {
            destinationPixel = (PPLinearRGB16BitmapPixel *) destinationRow;
            sourcePixel = (PPLinearRGB16BitmapPixel *) sourceRow;

            pixelCounter = pixelsPerRow;

            while (pixelCounter--)
            {
                if (macroLinearRGB16PixelComponent_Alpha(destinationPixel) > 0)
                {
                    if ((macroLinearRGB16PixelComponent_Alpha(destinationPixel)
                                < kMaxLinear16PixelComponentValue)
                        && (macroLinearRGB16PixelComponent_Alpha(sourcePixel) > 0))
                    {
                        destinationComponentAlphaFactor =
                            macroLinearRGB16PixelComponent_Alpha(destinationPixel);

                        sourceComponentAlphaFactor =
                            kMaxLinear16PixelComponentValue - destinationComponentAlphaFactor;

                        if (macroLinearRGB16PixelComponent_Alpha(sourcePixel)
                                < kMaxLinear16PixelComponentValue)
                        {
                            sourceComponentAlphaFactor =
                                (sourceComponentAlphaFactor
                                    * macroLinearRGB16PixelComponent_Alpha(sourcePixel)
                                    + kLinear16PixelComponentPrenormalizationRoundoff)
                                / kMaxLinear16PixelComponentValue;
                        }

                        sumOfAlphaFactors =
                            destinationComponentAlphaFactor + sourceComponentAlphaFactor;

                        alphaFactorsPrenormalizationRoundoff =
                            macroRoundoffValueForDivisor(sumOfAlphaFactors);

                        macroLinearRGB16PixelComponent_Red(destinationPixel) =
                            (destinationComponentAlphaFactor
                                    * macroLinearRGB16PixelComponent_Red(destinationPixel)
                                + sourceComponentAlphaFactor
                                    * macroLinearRGB16PixelComponent_Red(sourcePixel)
                                + alphaFactorsPrenormalizationRoundoff)
                            / sumOfAlphaFactors;

                        macroLinearRGB16PixelComponent_Green(destinationPixel) =
                            (destinationComponentAlphaFactor
                                    * macroLinearRGB16PixelComponent_Green(destinationPixel)
                                + sourceComponentAlphaFactor
                                    * macroLinearRGB16PixelComponent_Green(sourcePixel)
                                + alphaFactorsPrenormalizationRoundoff)
                            / sumOfAlphaFactors;

                        macroLinearRGB16PixelComponent_Blue(destinationPixel) =
                            (destinationComponentAlphaFactor
                                    * macroLinearRGB16PixelComponent_Blue(destinationPixel)
                                + sourceComponentAlphaFactor
                                    * macroLinearRGB16PixelComponent_Blue(sourcePixel)
                                + alphaFactorsPrenormalizationRoundoff)
                            / sumOfAlphaFactors;

                        macroLinearRGB16PixelComponent_Alpha(destinationPixel) =
                            sumOfAlphaFactors;
                    }
                }
                else if (macroLinearRGB16PixelComponent_Alpha(sourcePixel) > 0)
                {
                    *destinationPixel = *sourcePixel;
                }

                destinationPixel++;
                sourcePixel++;
            }

            destinationRow += destinationBytesPerRow;
            sourceRow += sourceBytesPerRow;
        }
    }

    return;

ERROR:
    return;
}

- (void) ppLinearCopyFromLinearBitmap: (NSBitmapImageRep *) sourceBitmap
            opacity: (float) opacity
            inBounds: (NSRect) copyBounds
{
    NSRect bitmapFrame;
    unsigned char *destinationData, *sourceData, *destinationRow, *sourceRow;
    unsigned int opacityFactor;
    int destinationBytesPerRow, sourceBytesPerRow, rowOffset,
            destinationDataOffset, sourceDataOffset, pixelsPerRow, bytesToCopyPerRow,
            rowCounter, pixelCounter;
    PPLinearRGB16BitmapPixel *destinationPixel;

    if (![self ppIsLinearRGB16Bitmap]
        || ![sourceBitmap ppIsLinearRGB16Bitmap])
    {
        goto ERROR;
    }

    opacity = macroClampFloatValueTo0_1(opacity);

    opacityFactor = roundf(opacity * kMaxLinear16PixelComponentValue);

    if (opacityFactor >= kMaxLinear16PixelComponentValue)
    {
        [self ppCopyFromBitmap: sourceBitmap inRect: copyBounds toPoint: copyBounds.origin];
        return;
    }
    else if (opacityFactor == 0)
    {
        [self ppClearBitmapInBounds: copyBounds];
        return;
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

    if (!destinationData || !sourceData)
    {
        goto ERROR;
    }

    destinationBytesPerRow = [self bytesPerRow];
    sourceBytesPerRow = [sourceBitmap bytesPerRow];

    rowOffset = bitmapFrame.size.height - copyBounds.size.height - copyBounds.origin.y;

    destinationDataOffset =
        rowOffset * destinationBytesPerRow
        + copyBounds.origin.x * sizeof(PPLinearRGB16BitmapPixel);

    sourceDataOffset =
        rowOffset * sourceBytesPerRow
        + copyBounds.origin.x * sizeof(PPLinearRGB16BitmapPixel);

    destinationRow = &destinationData[destinationDataOffset];
    sourceRow = &sourceData[sourceDataOffset];

    pixelsPerRow = copyBounds.size.width;
    bytesToCopyPerRow = pixelsPerRow * sizeof(PPLinearRGB16BitmapPixel);

    rowCounter = copyBounds.size.height;

    while (rowCounter--)
    {
        // copy the row's pixel data

        memcpy(destinationRow, sourceRow, bytesToCopyPerRow);

        // loop over the copied pixels & multiply the alpha components by the opacity

        destinationPixel = (PPLinearRGB16BitmapPixel *) destinationRow;

        pixelCounter = pixelsPerRow;

        while (pixelCounter--)
        {
            macroLinearRGB16PixelComponent_Alpha(destinationPixel) =
                (opacityFactor
                    * macroLinearRGB16PixelComponent_Alpha(destinationPixel)
                    + kLinear16PixelComponentPrenormalizationRoundoff)
                / kMaxLinear16PixelComponentValue;

            destinationPixel++;
        }

        destinationRow += destinationBytesPerRow;
        sourceRow += sourceBytesPerRow;
    }

    return;

ERROR:
    return;
}

@end

#pragma mark Private functions

static bool SetupGlobalLinearConversionTables(void)
{
    int sizeOfSRGBValuesForLinearValuesTable, sizeOfLinearValuesForSRGBValuesTable,
        tableIndexCounter;
    unsigned char *tablesBuffer = NULL;
    PPImagePixelComponent *sRGBComponentTableEntry;
    PPLinear16PixelComponent *linearComponentTableEntry;
    float linearFloatValue, sRGBFloatValue;

    sizeOfSRGBValuesForLinearValuesTable =
                ((int) kMaxLinear16PixelComponentValue + 1) * sizeof(PPImagePixelComponent);

    sizeOfLinearValuesForSRGBValuesTable =
                ((int) kMaxImagePixelComponentValue + 1) * sizeof(PPLinear16PixelComponent);

    tablesBuffer = (unsigned char *) malloc (sizeOfSRGBValuesForLinearValuesTable
                                                + sizeOfLinearValuesForSRGBValuesTable);

    if (!tablesBuffer)
        goto ERROR;

    gSRGBValuesForLinear16ValuesTable =
                (PPImagePixelComponent *) &tablesBuffer[0];

    gLinear16ValuesForSRGBValuesTable =
                (PPLinear16PixelComponent *) &tablesBuffer[sizeOfSRGBValuesForLinearValuesTable];

    sRGBComponentTableEntry = gSRGBValuesForLinear16ValuesTable;

    for (tableIndexCounter=0; tableIndexCounter<=kMaxLinear16PixelComponentValue;
            tableIndexCounter++)
    {
        linearFloatValue =
                    ((float) tableIndexCounter) / ((float) kMaxLinear16PixelComponentValue);

        *sRGBComponentTableEntry++ =
            (PPImagePixelComponent)
                roundf(((float) kMaxImagePixelComponentValue)
                        * macroSRGBUtils_SRGBFloatValueFromLinearFloatValue(linearFloatValue));
    }

    linearComponentTableEntry = gLinear16ValuesForSRGBValuesTable;

    for (tableIndexCounter=0; tableIndexCounter<=kMaxImagePixelComponentValue;
            tableIndexCounter++)
    {
        sRGBFloatValue = ((float) tableIndexCounter) / ((float) kMaxImagePixelComponentValue);

        *linearComponentTableEntry++ =
            (PPLinear16PixelComponent)
                roundf(((float) kMaxLinear16PixelComponentValue)
                        * macroSRGBUtils_LinearFloatValueFromSRGBFloatValue(sRGBFloatValue));
    }

    return YES;

ERROR:
    if (tablesBuffer)
    {
        free(tablesBuffer);
    }

    gSRGBValuesForLinear16ValuesTable = NULL;
    gLinear16ValuesForSRGBValuesTable = NULL;

    return NO;
}
