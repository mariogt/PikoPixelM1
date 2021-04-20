/*
    NSBitmapImageRep_PPUtilities_PatternBitmaps.m

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

#import "NSColor_PPUtilities.h"
#import "PPGeometry.h"
#import "PPSRGBUtilities.h"
#import "PPImagePixelAlphaPremultiplyTables.h"


#define kMinPatternSizeForPixelFramingInFillOverlayPattern          (4.0f)
#define kMinPatternSizeForDoubleLineWidthInFillOverlayPattern       (17.0f)

#define kMinVerticalGradientHeight                                  (5)


static PPImageBitmapPixel *PPImagePixelGradientArrayOfSizeWithEndColors(unsigned arraySize,
                                                                        NSColor *firstColor,
                                                                        NSColor *lastColor);


@interface NSBitmapImageRep (PPUtilities_PatternBitmapsPrivateMethods)

+ (NSBitmapImageRep *) ppPixelCheckerboardPatternBitmapWithColor1: (NSColor *) color1
                                                        color2: (NSColor *) color2;

@end

@implementation NSBitmapImageRep (PPUtilities_PatternBitmaps)

+ (NSBitmapImageRep *) ppCheckerboardPatternBitmapWithBoxDimension: (float) boxDimension
                            color1: (NSColor *) color1
                            color2: (NSColor *) color2
{
    NSSize patternSize;
    NSBitmapImageRep *patternBitmap;
    unsigned char *patternRow;
    PPImageBitmapPixel color1PixelValue, color2PixelValue, averagedPixelValue, *patternPixel;
    int patternBytesPerRow, bytesToCopyPerRow, pixelCounter, rowCounter;

    boxDimension = floorf(boxDimension);

    if (boxDimension < 2.0f)
    {
        return [self ppPixelCheckerboardPatternBitmapWithColor1: color1 color2: color2];
    }

    patternSize = NSMakeSize(2.0f * boxDimension, 2.0f * boxDimension);
    patternBitmap = [NSBitmapImageRep ppImageBitmapOfSize: patternSize];

    if (!patternBitmap)
        goto ERROR;

    patternRow = [patternBitmap bitmapData];

    if (!patternRow)
        goto ERROR;

    patternBytesPerRow = [patternBitmap bytesPerRow];
    bytesToCopyPerRow = patternSize.width * sizeof(PPImageBitmapPixel);

    color1PixelValue = [color1 ppImageBitmapPixelValue];
    color2PixelValue = [color2 ppImageBitmapPixelValue];
    averagedPixelValue = [[color1 ppColorBlendedWithColor: color2] ppImageBitmapPixelValue];

    // first row of top half

    patternPixel = (PPImageBitmapPixel *) patternRow;
    pixelCounter = boxDimension - 1;

    while (pixelCounter--)
    {
        *patternPixel++ = color1PixelValue;
    }

    *patternPixel++ = averagedPixelValue;

    pixelCounter = boxDimension - 1;

    while (pixelCounter--)
    {
        *patternPixel++ = color2PixelValue;
    }

    *patternPixel = averagedPixelValue;

    patternRow += patternBytesPerRow;

    // lower rows of top half

    rowCounter = boxDimension - 2;

    while (rowCounter--)
    {
        memcpy(patternRow, &patternRow[-patternBytesPerRow], bytesToCopyPerRow);

        patternRow += patternBytesPerRow;
    }

    // middle row

    patternPixel = (PPImageBitmapPixel *) patternRow;
    pixelCounter = patternSize.width;

    while (pixelCounter--)
    {
        *patternPixel++ = averagedPixelValue;
    }

    patternRow += patternBytesPerRow;

    // first row of bottom half

    patternPixel = (PPImageBitmapPixel *) patternRow;
    pixelCounter = boxDimension - 1;

    while (pixelCounter--)
    {
        *patternPixel++ = color2PixelValue;
    }

    *patternPixel++ = averagedPixelValue;

    pixelCounter = boxDimension - 1;

    while (pixelCounter--)
    {
        *patternPixel++ = color1PixelValue;
    }

    *patternPixel++ = averagedPixelValue;

    patternRow += patternBytesPerRow;

    // lower rows of bottom half

    rowCounter = boxDimension - 2;

    while (rowCounter--)
    {
        memcpy(patternRow, &patternRow[-patternBytesPerRow], bytesToCopyPerRow);

        patternRow += patternBytesPerRow;
    }

    // bottom row

    patternPixel = (PPImageBitmapPixel *) patternRow;
    pixelCounter = patternSize.width;

    while (pixelCounter--)
    {
        *patternPixel++ = averagedPixelValue;
    }

    return patternBitmap;

ERROR:
    return nil;
}

+ (NSBitmapImageRep *) ppDiagonalCheckerboardPatternBitmapWithBoxDimension:
                                                                    (float) boxDimension
                            color1: (NSColor *) color1
                            color2: (NSColor *) color2
{
    NSSize patternSize;
    NSBitmapImageRep *patternBitmap;
    NSColor *averageColor;
    int row, rowCounter, leftEdgeCol, rightEdgeCol;

    boxDimension = floorf(boxDimension);

    if (boxDimension < 1.0f)
    {
        boxDimension = 1.0f;
    }

    patternSize = NSMakeSize(2.0f * boxDimension, 2.0f * boxDimension);
    patternBitmap = [NSBitmapImageRep ppImageBitmapOfSize: patternSize];

    if (!patternBitmap)
        goto ERROR;

    averageColor = [color1 ppColorBlendedWithColor: color2];

    if (!averageColor)
        goto ERROR;

    [patternBitmap ppSetAsCurrentGraphicsContext];

    [color2 set];
    NSRectFill(PPGeometry_OriginRectOfSize(patternSize));

    row = 0;

    [averageColor set];
    NSRectFill(NSMakeRect(0.0f, row, 1.0f, 1.0f));

    [color1 set];
    NSRectFill(NSMakeRect(1.0f, row, patternSize.width - 1.0f, 1.0f));

    row++;

    leftEdgeCol = 1;
    rightEdgeCol = patternSize.width - 1;
    rowCounter = boxDimension - 1;

    while (rowCounter > 0)
    {
        [averageColor set];
        NSRectFill(NSMakeRect(leftEdgeCol, row, 1.0f, 1.0f));
        NSRectFill(NSMakeRect(rightEdgeCol, row, 1.0f, 1.0f));

        [color1 set];
        NSRectFill(NSMakeRect(leftEdgeCol + 1, row, rightEdgeCol - leftEdgeCol - 1, 1.0f));

        leftEdgeCol++;
        rightEdgeCol--;
        row++;
        rowCounter--;
    }

    [averageColor set];
    NSRectFill(NSMakeRect(patternSize.width - boxDimension, row, 1.0f, 1.0f));

    row++;

    leftEdgeCol--;
    rightEdgeCol++;
    rowCounter = boxDimension - 1;

    while (rowCounter > 0)
    {
        [averageColor set];
        NSRectFill(NSMakeRect(leftEdgeCol, row, 1.0f, 1.0f));
        NSRectFill(NSMakeRect(rightEdgeCol, row, 1.0f, 1.0f));

        [color1 set];
        NSRectFill(NSMakeRect(leftEdgeCol + 1, row, rightEdgeCol - leftEdgeCol - 1, 1.0f));

        leftEdgeCol--;
        rightEdgeCol++;
        row++;
        rowCounter--;
    }

    [patternBitmap ppRestoreGraphicsContext];

    return patternBitmap;

ERROR:
    return nil;
}

+ (NSBitmapImageRep *) ppIsometricCheckerboardPatternBitmapWithBoxDimension:
                                                                    (float) boxDimension
                            color1: (NSColor *) color1
                            color2: (NSColor *) color2
{
    NSSize patternSize;
    NSBitmapImageRep *patternBitmap;
    NSColor *averageColor, *mixed25PercentColor, *mixed75PercentColor;
    int row, rowCounter, leftEdgeCol, rightEdgeCol;

    boxDimension = floorf(boxDimension);

    if (boxDimension < 1.0f)
    {
        boxDimension = 1.0f;
    }

    patternSize = NSMakeSize(4.0f * boxDimension, 2.0f * boxDimension);
    patternBitmap = [NSBitmapImageRep ppImageBitmapOfSize: patternSize];

    if (!patternBitmap)
        goto ERROR;

    averageColor = [color1 ppColorBlendedWithColor: color2];
    mixed25PercentColor = [color2 ppColorBlendedWith25PercentOfColor: color1];
    mixed75PercentColor = [color1 ppColorBlendedWith25PercentOfColor: color2];

    if (!averageColor)
        goto ERROR;

    [patternBitmap ppSetAsCurrentGraphicsContext];

    [color2 set];
    NSRectFill(PPGeometry_OriginRectOfSize(patternSize));

    row = 0;

    [averageColor set];
    NSRectFill(NSMakeRect(0.0f, row, 2.0f, 1.0f));

    [color1 set];
    NSRectFill(NSMakeRect(2.0f, row, patternSize.width - 2.0f, 1.0f));

    row++;

    leftEdgeCol = 2;
    rightEdgeCol = patternSize.width - 2;
    rowCounter = boxDimension - 1;

    while (rowCounter > 0)
    {
        [mixed25PercentColor set];
        NSRectFill(NSMakeRect(leftEdgeCol, row, 1.0f, 1.0f));
        NSRectFill(NSMakeRect(rightEdgeCol + 1.0f, row, 1.0f, 1.0f));

        [mixed75PercentColor set];
        NSRectFill(NSMakeRect(leftEdgeCol + 1.0f, row, 1.0f, 1.0f));
        NSRectFill(NSMakeRect(rightEdgeCol, row, 1.0f, 1.0f));

        [color1 set];
        NSRectFill(NSMakeRect(leftEdgeCol + 2, row, rightEdgeCol - leftEdgeCol - 2, 1.0f));

        leftEdgeCol += 2;
        rightEdgeCol -= 2;
        row++;
        rowCounter--;
    }

    [averageColor set];
    NSRectFill(NSMakeRect(patternSize.width - 2.0f * boxDimension, row, 2.0f, 1.0f));

    row++;

    leftEdgeCol -= 2;
    rightEdgeCol += 2;
    rowCounter = boxDimension - 1;

    while (rowCounter > 0)
    {
        [mixed25PercentColor set];
        NSRectFill(NSMakeRect(leftEdgeCol, row, 1.0f, 1.0f));
        NSRectFill(NSMakeRect(rightEdgeCol + 1.0f, row, 1.0f, 1.0f));

        [mixed75PercentColor set];
        NSRectFill(NSMakeRect(leftEdgeCol + 1.0f, row, 1.0f, 1.0f));
        NSRectFill(NSMakeRect(rightEdgeCol, row, 1.0f, 1.0f));

        [color1 set];
        NSRectFill(NSMakeRect(leftEdgeCol + 2, row, rightEdgeCol - leftEdgeCol - 2, 1.0f));

        leftEdgeCol -= 2;
        rightEdgeCol += 2;
        row++;
        rowCounter--;
    }

    [patternBitmap ppRestoreGraphicsContext];

    return patternBitmap;

ERROR:
    return nil;
}

+ (NSBitmapImageRep *) ppDiagonalLinePatternBitmapWithLineWidth: (float) lineWidth
                            color1: (NSColor *) color1
                            color2: (NSColor *) color2
{
    NSSize patternSize;
    NSBitmapImageRep *patternBitmap;
    unsigned char *patternRow;
    PPImageBitmapPixel color1PixelValue, color2PixelValue, averagedPixelValue, *patternPixel;
    int patternBytesPerRow, pixelCounter, rowCounter, wraparoundBytesPerRow, shiftedBytesPerRow;

    lineWidth = floorf(lineWidth);

    if (lineWidth < 2.0f)
    {
        return [self ppPixelCheckerboardPatternBitmapWithColor1: color1 color2: color2];
    }

    patternSize = NSMakeSize(2.0f * lineWidth, 2.0f * lineWidth);
    patternBitmap = [NSBitmapImageRep ppImageBitmapOfSize: patternSize];

    if (!patternBitmap)
        goto ERROR;

    patternRow = [patternBitmap bitmapData];

    if (!patternRow)
        goto ERROR;

    patternBytesPerRow = [patternBitmap bytesPerRow];

    color1PixelValue = [color1 ppImageBitmapPixelValue];
    color2PixelValue = [color2 ppImageBitmapPixelValue];
    averagedPixelValue = [[color1 ppColorBlendedWithColor: color2] ppImageBitmapPixelValue];

    // first row

    patternPixel = (PPImageBitmapPixel *) patternRow;
    pixelCounter = lineWidth - 1;

    while (pixelCounter--)
    {
        *patternPixel++ = color1PixelValue;
    }

    *patternPixel++ = averagedPixelValue;

    pixelCounter = lineWidth - 1;

    while (pixelCounter--)
    {
        *patternPixel++ = color2PixelValue;
    }

    *patternPixel = averagedPixelValue;

    patternRow += patternBytesPerRow;

    // remaining rows

    wraparoundBytesPerRow = sizeof(PPImageBitmapPixel);
    shiftedBytesPerRow = patternSize.width * sizeof(PPImageBitmapPixel) - wraparoundBytesPerRow;

    rowCounter = patternSize.height - 1;

    while (rowCounter--)
    {
        memcpy(patternRow, &patternRow[-patternBytesPerRow + wraparoundBytesPerRow],
                shiftedBytesPerRow);

        memcpy(&patternRow[shiftedBytesPerRow], &patternRow[-patternBytesPerRow],
                wraparoundBytesPerRow);

        patternRow += patternBytesPerRow;
    }

    return patternBitmap;

ERROR:
    return nil;
}

+ (NSBitmapImageRep *) ppIsometricLinePatternBitmapWithLineWidth: (float) lineWidth
                            color1: (NSColor *) color1
                            color2: (NSColor *) color2
{
    NSSize patternSize;
    NSBitmapImageRep *patternBitmap;
    unsigned char *patternRow;
    PPImageBitmapPixel color1PixelValue, color2PixelValue, mixed25PercentPixelValue,
                        mixed75PercentPixelValue, *patternPixel;
    int patternBytesPerRow, pixelCounter, rowCounter, wraparoundBytesPerRow, shiftedBytesPerRow;

    lineWidth = floorf(2.0f * lineWidth);

    if (lineWidth < 2.0f)
    {
        lineWidth = 2.0f;
    }

    patternSize = NSMakeSize(2.0f * lineWidth, lineWidth);
    patternBitmap = [NSBitmapImageRep ppImageBitmapOfSize: patternSize];

    if (!patternBitmap)
        goto ERROR;

    patternRow = [patternBitmap bitmapData];

    if (!patternRow)
        goto ERROR;

    patternBytesPerRow = [patternBitmap bytesPerRow];

    color1PixelValue = [color1 ppImageBitmapPixelValue];
    color2PixelValue = [color2 ppImageBitmapPixelValue];
    mixed25PercentPixelValue =
                [[color2 ppColorBlendedWith25PercentOfColor: color1] ppImageBitmapPixelValue];
    mixed75PercentPixelValue =
                [[color1 ppColorBlendedWith25PercentOfColor: color2] ppImageBitmapPixelValue];

    // first row

    patternPixel = (PPImageBitmapPixel *) patternRow;
    pixelCounter = lineWidth - 2;

    while (pixelCounter--)
    {
        *patternPixel++ = color1PixelValue;
    }

    *patternPixel++ = mixed75PercentPixelValue;
    *patternPixel++ = mixed25PercentPixelValue;

    pixelCounter = lineWidth - 2;

    while (pixelCounter--)
    {
        *patternPixel++ = color2PixelValue;
    }

    *patternPixel++ = mixed25PercentPixelValue;
    *patternPixel++ = mixed75PercentPixelValue;

    patternRow += patternBytesPerRow;

    // remaining rows

    wraparoundBytesPerRow = 2 * sizeof(PPImageBitmapPixel);
    shiftedBytesPerRow = patternSize.width * sizeof(PPImageBitmapPixel) - wraparoundBytesPerRow;

    rowCounter = patternSize.height - 1;

    while (rowCounter--)
    {
        memcpy(patternRow, &patternRow[-patternBytesPerRow + wraparoundBytesPerRow],
                shiftedBytesPerRow);

        memcpy(&patternRow[shiftedBytesPerRow], &patternRow[-patternBytesPerRow],
                wraparoundBytesPerRow);

        patternRow += patternBytesPerRow;
    }

    return patternBitmap;

ERROR:
    return nil;
}

+ (NSBitmapImageRep *) ppHorizontalGradientPatternBitmapWithWidth: (unsigned) width
                            leftColor: (NSColor *) leftColor
                            rightColor: (NSColor *) rightColor
{
    NSBitmapImageRep *gradientBitmap;
    PPImageBitmapPixel *gradientPixelValuesArray = NULL;
    unsigned char *gradientBitmapData;

    if (width < 1)
    {
        goto ERROR;
    }

    gradientBitmap = [NSBitmapImageRep ppImageBitmapOfSize: NSMakeSize(width, 1.0f)];

    if (!gradientBitmap)
        goto ERROR;

    gradientPixelValuesArray = PPImagePixelGradientArrayOfSizeWithEndColors(width, leftColor,
                                                                            rightColor);

    if (!gradientPixelValuesArray)
        goto ERROR;

    gradientBitmapData = [gradientBitmap bitmapData];

    if (!gradientBitmapData)
        goto ERROR;

    memcpy(gradientBitmapData, gradientPixelValuesArray, width * sizeof(PPImageBitmapPixel));

    free(gradientPixelValuesArray);

    return gradientBitmap;

ERROR:
    if (gradientPixelValuesArray)
    {
        free(gradientPixelValuesArray);
    }

    return nil;
}

+ (NSBitmapImageRep *) ppVerticalGradientPatternBitmapWithHeight: (unsigned) height
                            topColor: (NSColor *) topColor
                            bottomColor: (NSColor *) bottomColor
{
    NSBitmapImageRep *gradientBitmap;
    PPImageBitmapPixel *gradientPixelValuesArray = NULL, *gradientBitmapPixel,
                        *gradientArrayPixel;
    unsigned char *gradientBitmapData, *gradientBitmapRow;
    NSInteger bytesPerRow, pixelCounter;

    if (height < 1)
    {
        goto ERROR;
    }

    gradientBitmap = [NSBitmapImageRep ppImageBitmapOfSize: NSMakeSize(1.0f, height)];

    if (!gradientBitmap)
        goto ERROR;

    gradientPixelValuesArray = PPImagePixelGradientArrayOfSizeWithEndColors(height, topColor,
                                                                            bottomColor);

    if (!gradientPixelValuesArray)
        goto ERROR;

    gradientBitmapData = [gradientBitmap bitmapData];

    if (!gradientBitmapData)
        goto ERROR;

    bytesPerRow = [gradientBitmap bytesPerRow];

    gradientBitmapRow = gradientBitmapData;

    gradientArrayPixel = &gradientPixelValuesArray[0];

    pixelCounter = height;

    while (pixelCounter--)
    {
        gradientBitmapPixel = (PPImageBitmapPixel *) gradientBitmapRow;

        *gradientBitmapPixel = *gradientArrayPixel++;

        gradientBitmapRow += bytesPerRow;
    }

    free(gradientPixelValuesArray);

    return gradientBitmap;

ERROR:
    if (gradientPixelValuesArray)
    {
        free(gradientPixelValuesArray);
    }

    return nil;
}

+ (NSBitmapImageRep *) ppCenteredVerticalGradientPatternBitmapWithHeight: (unsigned) height
                            innerColor: (NSColor *) innerColor
                            outerColor: (NSColor *) outerColor
{
    NSBitmapImageRep *gradientBitmap;
    NSInteger arraySize, bytesPerRow, pixelCounter;
    PPImageBitmapPixel *gradientPixelValuesArray = NULL, *gradientBitmapPixel,
                        *gradientArrayPixel;
    unsigned char *gradientBitmapData, *gradientBitmapRow;

    if (height < kMinVerticalGradientHeight)
    {
        goto ERROR;
    }

    gradientBitmap = [NSBitmapImageRep ppImageBitmapOfSize: NSMakeSize(1.0f, height)];

    if (!gradientBitmap)
        goto ERROR;

    arraySize = ceilf((height + 1.0f)/ 2.0f);

    gradientPixelValuesArray = PPImagePixelGradientArrayOfSizeWithEndColors(arraySize,
                                                                            outerColor,
                                                                            innerColor);

    if (!gradientPixelValuesArray)
        goto ERROR;

    gradientBitmapData = [gradientBitmap bitmapData];

    if (!gradientBitmapData)
        goto ERROR;

    bytesPerRow = [gradientBitmap bytesPerRow];

    gradientBitmapRow = gradientBitmapData;

    gradientArrayPixel = &gradientPixelValuesArray[0];

    pixelCounter = arraySize;

    while (pixelCounter--)
    {
        gradientBitmapPixel = (PPImageBitmapPixel *) gradientBitmapRow;

        *gradientBitmapPixel = *gradientArrayPixel++;

        gradientBitmapRow += bytesPerRow;
    }

    gradientArrayPixel--;

    pixelCounter = arraySize - 2;

    if ((height - pixelCounter) > arraySize)
    {
        gradientBitmapPixel = (PPImageBitmapPixel *) gradientBitmapRow;

        *gradientBitmapPixel = *gradientArrayPixel;

        gradientBitmapRow += bytesPerRow;
    }

    gradientArrayPixel--;

    while (pixelCounter--)
    {
        gradientBitmapPixel = (PPImageBitmapPixel *) gradientBitmapRow;

        *gradientBitmapPixel = *gradientArrayPixel--;

        gradientBitmapRow += bytesPerRow;
    }

    free(gradientPixelValuesArray);

    return gradientBitmap;

ERROR:
    if (gradientPixelValuesArray)
    {
        free(gradientPixelValuesArray);
    }

    return nil;
}

+ (NSBitmapImageRep *) ppFillOverlayPatternBitmapWithSize: (float) patternSize
                            fillColor: (NSColor *) fillColor
{
    NSBitmapImageRep *patternBitmap;
    NSRect pixelFrame;

    if (!fillColor)
        goto ERROR;

    patternSize = floorf(patternSize);

    if (patternSize < kMinPatternSizeForPixelFramingInFillOverlayPattern)
    {
        return [self ppPixelCheckerboardPatternBitmapWithColor1: fillColor
                        color2: [NSColor clearColor]];
    }

    patternBitmap =
            [NSBitmapImageRep ppImageBitmapOfSize: NSMakeSize(patternSize, patternSize)];

    if (!patternBitmap)
        goto ERROR;

    [patternBitmap ppSetAsCurrentGraphicsContext];

    [fillColor set];

    pixelFrame = NSMakeRect(1.0f, 0.0f, patternSize - 1.0f, patternSize - 1.0f);
    NSFrameRect(pixelFrame);

    if (patternSize >= kMinPatternSizeForDoubleLineWidthInFillOverlayPattern)
    {
        pixelFrame = NSInsetRect(pixelFrame, 1.0f, 1.0f);
        NSFrameRect(pixelFrame);
    }

    [patternBitmap ppRestoreGraphicsContext];

    return patternBitmap;

ERROR:
    return nil;
}

#pragma mark Private methods

+ (NSBitmapImageRep *) ppPixelCheckerboardPatternBitmapWithColor1: (NSColor *) color1
                                                        color2: (NSColor *) color2
{
    NSSize patternSize;
    NSBitmapImageRep *patternBitmap;
    unsigned char *patternRow;
    int patternBytesPerRow;
    PPImageBitmapPixel color1PixelValue, color2PixelValue, *patternPixel;

    patternSize = NSMakeSize(2.0f, 2.0f);
    patternBitmap = [NSBitmapImageRep ppImageBitmapOfSize: patternSize];

    if (!patternBitmap)
        goto ERROR;

    patternRow = [patternBitmap bitmapData];

    if (!patternRow)
        goto ERROR;

    patternBytesPerRow = [patternBitmap bytesPerRow];

    color1PixelValue = [color1 ppImageBitmapPixelValue];
    color2PixelValue = [color2 ppImageBitmapPixelValue];

    // first row

    patternPixel = (PPImageBitmapPixel *) patternRow;

    *patternPixel++ = color1PixelValue;
    *patternPixel = color2PixelValue;

    patternRow += patternBytesPerRow;

    // second row

    patternPixel = (PPImageBitmapPixel *) patternRow;

    *patternPixel++ = color2PixelValue;
    *patternPixel = color1PixelValue;

    return patternBitmap;

ERROR:
    return nil;
}

@end

#pragma mark Private functions

static PPImageBitmapPixel *PPImagePixelGradientArrayOfSizeWithEndColors(unsigned arraySize,
                                                                        NSColor *firstColor,
                                                                        NSColor *lastColor)
{
    PPImageBitmapPixel *pixelArray, *currentPixel;
    CGFloat firstColorComponents[kNumPPImagePixelComponents],
            lastColorComponents[kNumPPImagePixelComponents], gradientCounterMax,
            gradientCounter, gradientRemainderCounter, alphaComponent, linearComponent;
    int componentIndex;
    PPImagePixelComponent *premultiplyTable;

    if (!arraySize)
        goto ERROR;

    firstColor = [firstColor ppSRGBColor];
    lastColor = [lastColor ppSRGBColor];

    if (!firstColor || !lastColor)
    {
        goto ERROR;
    }

    pixelArray = (PPImageBitmapPixel *) malloc (arraySize * sizeof(PPImageBitmapPixel));

    if (!pixelArray)
        goto ERROR;

    if (arraySize <= 2)
    {
        pixelArray[arraySize-1] = [lastColor ppImageBitmapPixelValue];

        if (arraySize > 1)
        {
            pixelArray[0] = [firstColor ppImageBitmapPixelValue];
        }

        return pixelArray;
    }

    [firstColor getComponents: firstColorComponents];
    [lastColor getComponents: lastColorComponents];

    // convert RGB components from sRGB to Linear
    for (componentIndex=0; componentIndex<3; componentIndex++)
    {
        firstColorComponents[componentIndex] =
            macroSRGBUtils_LinearFloatValueFromSRGBFloatValue(
                                                        firstColorComponents[componentIndex]);

        lastColorComponents[componentIndex] =
            macroSRGBUtils_LinearFloatValueFromSRGBFloatValue(
                                                        lastColorComponents[componentIndex]);
    }

    //  If either end color is completely transparent (zero alpha), its RGB components are
    // likely also zero (black) - blending with those color values will result in an incorrect
    // gradient that darkens to black as it approaches the transparent end.
    //  To prevent the color values from darkening (only the alpha values should change), copy
    // the other end's RGB values to the transparent end.

    if (firstColorComponents[kPPImagePixelComponent_Alpha] == 0)
    {
        for (componentIndex=0; componentIndex<3; componentIndex++)
        {
            firstColorComponents[componentIndex] = lastColorComponents[componentIndex];
        }
    }
    else if (lastColorComponents[kPPImagePixelComponent_Alpha] == 0)
    {
        for (componentIndex=0; componentIndex<3; componentIndex++)
        {
            lastColorComponents[componentIndex] = firstColorComponents[componentIndex];
        }
    }

    currentPixel = &pixelArray[0];

    gradientCounterMax = arraySize - 1;

    for (gradientCounter=0; gradientCounter<=gradientCounterMax; gradientCounter+=1.0)
    {
        gradientRemainderCounter = gradientCounterMax - gradientCounter;

        // Alpha component
        alphaComponent =
            (firstColorComponents[kPPImagePixelComponent_Alpha] * gradientRemainderCounter
                    + lastColorComponents[kPPImagePixelComponent_Alpha] * gradientCounter)
            / gradientCounterMax;

        macroImagePixelComponent_Alpha(currentPixel) =
                                        roundf(alphaComponent * kMaxImagePixelComponentValue);

        premultiplyTable = macroAlphaPremultiplyTableForImagePixel(currentPixel);

        // RGB components

        for (componentIndex=0; componentIndex<3; componentIndex++)
        {
            linearComponent =
                (firstColorComponents[componentIndex] * gradientRemainderCounter
                        + lastColorComponents[componentIndex] * gradientCounter)
                / gradientCounterMax;

            macroImagePixelComponent(currentPixel, componentIndex) =
                premultiplyTable[
                    ((int) roundf(
                            macroSRGBUtils_SRGBFloatValueFromLinearFloatValue(linearComponent)
                            * kMaxImagePixelComponentValue))];
        }

        currentPixel++;
    }

    return pixelArray;

ERROR:
    return NULL;
}
