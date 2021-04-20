/*
    NSBitmapImageRep_PPUtilities_ColorMasking.m

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


#define kMaxMatchTolerance      kMaxImagePixelComponentValue


#define macroImagePixelMatchesMinAndMaxPixels(imagePixel, minPixel, maxPixel)       \
                                                                                    \
            (((macroImagePixelComponent_Red(imagePixel)                             \
                >= macroImagePixelComponent_Red(minPixel))                          \
                                                                                    \
            && (macroImagePixelComponent_Green(imagePixel)                          \
                >= macroImagePixelComponent_Green(minPixel))                        \
                                                                                    \
            && (macroImagePixelComponent_Blue(imagePixel)                           \
                >= macroImagePixelComponent_Blue(minPixel))                         \
                                                                                    \
            && (macroImagePixelComponent_Alpha(imagePixel)                          \
                >= macroImagePixelComponent_Alpha(minPixel))                        \
                                                                                    \
            && (macroImagePixelComponent_Red(imagePixel)                            \
                <= macroImagePixelComponent_Red(maxPixel))                          \
                                                                                    \
            && (macroImagePixelComponent_Green(imagePixel)                          \
                <= macroImagePixelComponent_Green(maxPixel))                        \
                                                                                    \
            && (macroImagePixelComponent_Blue(imagePixel)                           \
                <= macroImagePixelComponent_Blue(maxPixel))                         \
                                                                                    \
            && (macroImagePixelComponent_Alpha(imagePixel)                          \
                <= macroImagePixelComponent_Alpha(maxPixel))) ?                     \
                                                                                    \
            YES : NO)


static bool GetMinAndMaxMatchingPixelsForImagePixelWithTolerance(
                                                        PPImageBitmapPixel *sourcePixel,
                                                        unsigned matchTolerance,
                                                        PPImageBitmapPixel *returnedMinPixel,
                                                        PPImageBitmapPixel *returnedMaxPixel);


@interface NSBitmapImageRep (PPUtilities_ColorMaskingPrivateMethods)

- (bool) seedMatchingMaskInRow: (unsigned) row
            col: (unsigned) col
            colorMatchTolerance: (int) colorMatchTolerance
            sourceBitmap: (NSBitmapImageRep *) sourceBitmap
            selectionMask: (NSBitmapImageRep *) selectionMask
            returnedMinMatchingPixel: (PPImageBitmapPixel *) returnedMinMatchingPixel
            returnedMaxMatchingPixel: (PPImageBitmapPixel *) returnedMaxMatchingPixel;

- (bool) expandMatchingMaskInRow: (unsigned) row
            startCol: (unsigned) startCol
            endCol: (unsigned) endCol
            minMatchingPixel: (PPImageBitmapPixel *) minMatchingPixel
            maxMatchingPixel: (PPImageBitmapPixel *) maxMatchingPixel
            sourceBitmap: (NSBitmapImageRep *) sourceBitmap
            selectionMask: (NSBitmapImageRep *) selectionMask
            shouldCheckDiagonals: (bool) shouldCheckDiagonals;

@end

@implementation NSBitmapImageRep (PPUtilities_ColorMasking)

- (void) ppMaskNeighboringPixelsMatchingColorAtPoint: (NSPoint) point
            inImageBitmap: (NSBitmapImageRep *) sourceBitmap
            colorMatchTolerance: (unsigned) colorMatchTolerance
            selectionMask: (NSBitmapImageRep *) selectionMask
            selectionMaskBounds: (NSRect) selectionMaskBounds
            matchDiagonally: (bool) matchDiagonally
{
    NSRect bitmapFrame, matchBounds;
    int maskHeight, row, startCol, endCol, rowToCheck, lastRowToCheck, bottomRow, rowAbove,
        rowBelow;
    PPImageBitmapPixel minMatchingPixelValue, maxMatchingPixelValue;
    unsigned char *rowCheckFlags;

    if (![sourceBitmap ppIsImageBitmapAndSameSizeAsMaskBitmap: self])
    {
        goto ERROR;
    }

    bitmapFrame = [self ppFrameInPixels];

    point = PPGeometry_PointClippedToIntegerValues(point);

    if (PPGeometry_IsZeroSize(bitmapFrame.size)
        || !NSPointInRect(point, bitmapFrame))
    {
        goto ERROR;
    }

    if (selectionMask)
    {
        if (![sourceBitmap ppIsImageBitmapAndSameSizeAsMaskBitmap: selectionMask])
        {
            goto ERROR;
        }

        selectionMaskBounds =
                NSIntersectionRect(PPGeometry_PixelBoundsCoveredByRect(selectionMaskBounds),
                                    bitmapFrame);

        if (NSIsEmptyRect(selectionMaskBounds))
        {
            goto ERROR;
        }

        matchBounds = selectionMaskBounds;
    }
    else
    {
        matchBounds = bitmapFrame;
    }

    maskHeight = bitmapFrame.size.height;

    row = maskHeight - point.y - 1;

    startCol = matchBounds.origin.x;
    endCol = startCol + matchBounds.size.width - 1;

    if (![self seedMatchingMaskInRow: row
                    col: point.x
                    colorMatchTolerance: colorMatchTolerance
                    sourceBitmap: sourceBitmap
                    selectionMask: selectionMask
                    returnedMinMatchingPixel: &minMatchingPixelValue
                    returnedMaxMatchingPixel: &maxMatchingPixelValue])
    {
        goto ERROR;
    }

    if (maskHeight < 2)
    {
        return;
    }

    rowCheckFlags = (unsigned char *) calloc (maskHeight, sizeof(*rowCheckFlags));

    if (!rowCheckFlags)
        goto ERROR;

    bottomRow = maskHeight - 1;
    rowToCheck = bottomRow;
    lastRowToCheck = 0;

    if (row > 0)
    {
        rowAbove = row - 1;

        rowCheckFlags[rowAbove] = YES;

        rowToCheck = lastRowToCheck = rowAbove;
    }

    if (row < bottomRow)
    {
        rowBelow = row + 1;

        rowCheckFlags[rowBelow] = YES;

        if (rowToCheck > rowBelow)
        {
            rowToCheck = rowBelow;
        }

        lastRowToCheck = rowBelow;
    }

    while (rowToCheck <= lastRowToCheck)
    {
        if (rowCheckFlags[rowToCheck])
        {
            rowCheckFlags[rowToCheck] = NO;

            if ([self expandMatchingMaskInRow: rowToCheck
                        startCol: startCol
                        endCol: endCol
                        minMatchingPixel: &minMatchingPixelValue
                        maxMatchingPixel: &maxMatchingPixelValue
                        sourceBitmap: sourceBitmap
                        selectionMask: selectionMask
                        shouldCheckDiagonals: matchDiagonally])
            {
                row = rowToCheck;

                if (row < bottomRow)
                {
                    rowBelow = row + 1;

                    rowCheckFlags[rowBelow] = YES;

                    rowToCheck = rowBelow;

                    if (lastRowToCheck < rowBelow)
                    {
                        lastRowToCheck = rowBelow;
                    }
                }

                if (row > 0)
                {
                    rowAbove = row - 1;

                    rowCheckFlags[rowAbove] = YES;

                    rowToCheck = rowAbove;
                }
            }
            else
            {
                rowToCheck++;
            }
        }
        else
        {
            rowToCheck++;
        }
    }

    free(rowCheckFlags);

    return;

ERROR:
    if ([self ppIsMaskBitmap])
    {
        [self ppClearBitmap];
    }

    return;
}

- (void) ppMaskAllPixelsMatchingColorAtPoint: (NSPoint) point
            inImageBitmap: (NSBitmapImageRep *) sourceBitmap
            colorMatchTolerance: (unsigned) colorMatchTolerance
            selectionMask: (NSBitmapImageRep *) selectionMask
            selectionMaskBounds: (NSRect) selectionMaskBounds
{
    NSRect bitmapFrame, matchBounds;
    unsigned char *destinationMaskData, *destinationMaskRow, *sourceBitmapData,
                    *sourceBitmapRow;
    int destinationMaskBytesPerRow, destinationMaskDataOffset, sourceBitmapBytesPerRow,
        sourceBitmapDataOffset, rowOffset, rowCounter, pixelsPerRow, pixelCounter;
    PPImageBitmapPixel *sourcePixelToMatch, minMatchingPixelValue, maxMatchingPixelValue;
    PPMaskBitmapPixel *destinationMaskPixel;

    if (![sourceBitmap ppIsImageBitmapAndSameSizeAsMaskBitmap: self])
    {
        goto ERROR;
    }

    bitmapFrame = [self ppFrameInPixels];

    point = PPGeometry_PointClippedToIntegerValues(point);

    if (NSIsEmptyRect(bitmapFrame)
        || !NSPointInRect(point, bitmapFrame))
    {
        goto ERROR;
    }

    if (selectionMask)
    {
        if (![sourceBitmap ppIsImageBitmapAndSameSizeAsMaskBitmap: selectionMask])
        {
            goto ERROR;
        }

        selectionMaskBounds =
                NSIntersectionRect(PPGeometry_PixelBoundsCoveredByRect(selectionMaskBounds),
                                    bitmapFrame);

        if (NSIsEmptyRect(selectionMaskBounds))
        {
            goto ERROR;
        }

        matchBounds = selectionMaskBounds;
    }
    else
    {
        matchBounds = bitmapFrame;
    }

    [self ppClearBitmap];

    destinationMaskData = [self bitmapData];
    sourceBitmapData = [sourceBitmap bitmapData];

    if (!destinationMaskData || !sourceBitmapData)
    {
        goto ERROR;
    }

    destinationMaskBytesPerRow = [self bytesPerRow];
    sourceBitmapBytesPerRow = [sourceBitmap bytesPerRow];

    rowOffset = bitmapFrame.size.height - matchBounds.size.height - matchBounds.origin.y;

    destinationMaskDataOffset = rowOffset * destinationMaskBytesPerRow
                                + matchBounds.origin.x * sizeof(PPMaskBitmapPixel);

    sourceBitmapDataOffset = rowOffset * sourceBitmapBytesPerRow
                                + matchBounds.origin.x * sizeof(PPImageBitmapPixel);

    destinationMaskRow = &destinationMaskData[destinationMaskDataOffset];
    sourceBitmapRow = &sourceBitmapData[sourceBitmapDataOffset];

    rowCounter = matchBounds.size.height;
    pixelsPerRow = matchBounds.size.width;

    sourceBitmapDataOffset = (bitmapFrame.size.height - point.y - 1) * sourceBitmapBytesPerRow
                                + point.x * sizeof(PPImageBitmapPixel);
    sourcePixelToMatch = (PPImageBitmapPixel *) &sourceBitmapData[sourceBitmapDataOffset];

    if (!GetMinAndMaxMatchingPixelsForImagePixelWithTolerance(sourcePixelToMatch,
                                                                colorMatchTolerance,
                                                                &minMatchingPixelValue,
                                                                &maxMatchingPixelValue))
    {
        goto ERROR;
    }

    if (selectionMask)
    {
        // Has selection mask
        unsigned char *selectionMaskData, *selectionMaskRow;
        int selectionMaskBytesPerRow, selectionMaskDataOffset;
        PPMaskBitmapPixel *selectionMaskPixel;

        selectionMaskData = [selectionMask bitmapData];

        if (!selectionMaskData)
            goto ERROR;

        selectionMaskBytesPerRow = [selectionMask bytesPerRow];

        selectionMaskDataOffset = rowOffset * selectionMaskBytesPerRow
                                    + matchBounds.origin.x * sizeof(PPMaskBitmapPixel);

        selectionMaskRow = &selectionMaskData[selectionMaskDataOffset];

        while (rowCounter--)
        {
            destinationMaskPixel = (PPMaskBitmapPixel *) destinationMaskRow;
            sourcePixelToMatch = (PPImageBitmapPixel *) sourceBitmapRow;
            selectionMaskPixel = (PPMaskBitmapPixel *) selectionMaskRow;

            pixelCounter = pixelsPerRow;

            while (pixelCounter--)
            {
                if (*selectionMaskPixel
                    && macroImagePixelMatchesMinAndMaxPixels(sourcePixelToMatch,
                                                                &minMatchingPixelValue,
                                                                &maxMatchingPixelValue))
                {
                    *destinationMaskPixel = kMaskPixelValue_ON;
                }

                destinationMaskPixel++;
                sourcePixelToMatch++;
                selectionMaskPixel++;
            }

            destinationMaskRow += destinationMaskBytesPerRow;
            sourceBitmapRow += sourceBitmapBytesPerRow;
            selectionMaskRow += selectionMaskBytesPerRow;
        }
    }
    else
    {
        // No selection mask

        while (rowCounter--)
        {
            destinationMaskPixel = (PPMaskBitmapPixel *) destinationMaskRow;
            sourcePixelToMatch = (PPImageBitmapPixel *) sourceBitmapRow;

            pixelCounter = pixelsPerRow;

            while (pixelCounter--)
            {
                if (macroImagePixelMatchesMinAndMaxPixels(sourcePixelToMatch,
                                                            &minMatchingPixelValue,
                                                            &maxMatchingPixelValue))
                {
                    *destinationMaskPixel = kMaskPixelValue_ON;
                }

                destinationMaskPixel++;
                sourcePixelToMatch++;
            }

            destinationMaskRow += destinationMaskBytesPerRow;
            sourceBitmapRow += sourceBitmapBytesPerRow;
        }
    }

    return;

ERROR:
    if ([self ppIsMaskBitmap])
    {
        [self ppClearBitmap];
    }

    return;
}

- (void) ppMaskVisiblePixelsInImageBitmap: (NSBitmapImageRep *) sourceBitmap
            selectionMask: (NSBitmapImageRep *) selectionMask
{
    int maskWidth, maskHeight, destinationMaskBytesPerRow, sourceBitmapBytesPerRow,
        selectionMaskBytesPerRow, rowCounter, columnCounter;
    unsigned char *destinationMaskRow, *sourceBitmapRow, *selectionMaskRow;
    PPMaskBitmapPixel *destinationMaskPixel, *selectionMaskPixel;
    PPImageBitmapPixel *sourceBitmapPixel;

    maskWidth = [self pixelsWide];
    maskHeight = [self pixelsHigh];

    destinationMaskRow = [self bitmapData];
    destinationMaskBytesPerRow = [self bytesPerRow];

    sourceBitmapRow = [sourceBitmap bitmapData];
    sourceBitmapBytesPerRow = [sourceBitmap bytesPerRow];

    if (!destinationMaskRow || !sourceBitmapRow)
    {
        goto ERROR;
    }

    if (selectionMask)
    {
        selectionMaskRow = [selectionMask bitmapData];
        selectionMaskBytesPerRow = [selectionMask bytesPerRow];

        if (!selectionMaskRow)
            goto ERROR;
    }

    rowCounter = maskHeight;

    if (selectionMask)
    {
        // Has selection mask

        while (rowCounter--)
        {
            destinationMaskPixel = (PPMaskBitmapPixel *) destinationMaskRow;
            sourceBitmapPixel = (PPImageBitmapPixel *) sourceBitmapRow;
            selectionMaskPixel = (PPMaskBitmapPixel *) selectionMaskRow;

            columnCounter = maskWidth;

            while (columnCounter--)
            {
                if (macroImagePixelComponent_Alpha(sourceBitmapPixel))
                {
                    *destinationMaskPixel = kMaskPixelValue_ON;
                }

                destinationMaskPixel++;
                sourceBitmapPixel++;
                selectionMaskPixel++;
            }

            destinationMaskRow += destinationMaskBytesPerRow;
            sourceBitmapRow += sourceBitmapBytesPerRow;
            selectionMaskRow += selectionMaskBytesPerRow;
        }
    }
    else
    {
        // No selection mask

        while (rowCounter--)
        {
            destinationMaskPixel = (PPMaskBitmapPixel *) destinationMaskRow;
            sourceBitmapPixel = (PPImageBitmapPixel *) sourceBitmapRow;

            columnCounter = maskWidth;

            while (columnCounter--)
            {
                if (macroImagePixelComponent_Alpha(sourceBitmapPixel))
                {
                    *destinationMaskPixel = kMaskPixelValue_ON;
                }

                destinationMaskPixel++;
                sourceBitmapPixel++;
            }

            destinationMaskRow += destinationMaskBytesPerRow;
            sourceBitmapRow += sourceBitmapBytesPerRow;
        }
    }

    return;

ERROR:
    return;
}

#pragma mark Private methods

- (bool) seedMatchingMaskInRow: (unsigned) row
            col: (unsigned) col
            colorMatchTolerance: (int) colorMatchTolerance
            sourceBitmap: (NSBitmapImageRep *) sourceBitmap
            selectionMask: (NSBitmapImageRep *) selectionMask
            returnedMinMatchingPixel: (PPImageBitmapPixel *) returnedMinMatchingPixel
            returnedMaxMatchingPixel: (PPImageBitmapPixel *) returnedMaxMatchingPixel
{
    int maskWidth, maskHeight, checkCol, maskablePixelsStartCol, maskablePixelsEndCol;
    unsigned char *destinationMaskData, *sourceBitmapData, *selectionMaskData,
                    *destinationMaskRow, *sourceBitmapRow, *selectionMaskRow;
    PPImageBitmapPixel *sourcePixelToMatch, minMatchingPixelValue, maxMatchingPixelValue;

    [self ppClearBitmap];

    maskWidth = [self pixelsWide];
    maskHeight = [self pixelsHigh];

    if ((col >= maskWidth) || (row >= maskHeight))
    {
        goto ERROR;
    }

    destinationMaskData = [self bitmapData];
    sourceBitmapData = [sourceBitmap bitmapData];

    if (!destinationMaskData || !sourceBitmapData)
    {
        goto ERROR;
    }

    destinationMaskRow = &destinationMaskData[[self bytesPerRow] * row];
    sourceBitmapRow = &sourceBitmapData[[sourceBitmap bytesPerRow] * row];

    if (selectionMask)
    {
        selectionMaskData = [selectionMask bitmapData];

        if (!selectionMaskData)
            goto ERROR;

        selectionMaskRow = &selectionMaskData[[selectionMask bytesPerRow] * row];

        if (!selectionMaskRow[col])
            goto ERROR;
    }

    maskablePixelsStartCol = maskablePixelsEndCol = col;
    sourcePixelToMatch =
                (PPImageBitmapPixel *) &sourceBitmapRow[col * sizeof(PPImageBitmapPixel)];

    if (!GetMinAndMaxMatchingPixelsForImagePixelWithTolerance(sourcePixelToMatch,
                                                                colorMatchTolerance,
                                                                &minMatchingPixelValue,
                                                                &maxMatchingPixelValue))
    {
        goto ERROR;
    }

    if (col > 0)
    {
        checkCol = col - 1;
        sourcePixelToMatch =
            (PPImageBitmapPixel *) &sourceBitmapRow[checkCol * sizeof(PPImageBitmapPixel)];

        while (checkCol >= 0)
        {
            if ((selectionMask && !selectionMaskRow[checkCol])
                || !macroImagePixelMatchesMinAndMaxPixels(sourcePixelToMatch,
                                                            &minMatchingPixelValue,
                                                            &maxMatchingPixelValue))
            {
                break;
            }

            maskablePixelsStartCol = checkCol;
            checkCol--;
            sourcePixelToMatch--;
        }
    }

    if (col < (maskWidth - 1))
    {
        checkCol = col + 1;
        sourcePixelToMatch =
            (PPImageBitmapPixel *) &sourceBitmapRow[checkCol * sizeof(PPImageBitmapPixel)];

        while (checkCol < maskWidth)
        {
            if ((selectionMask && !selectionMaskRow[checkCol])
                || !macroImagePixelMatchesMinAndMaxPixels(sourcePixelToMatch,
                                                            &minMatchingPixelValue,
                                                            &maxMatchingPixelValue))
            {
                break;
            }

            maskablePixelsEndCol = checkCol;
            checkCol++;
            sourcePixelToMatch++;
        }
    }

    memset(&destinationMaskRow[maskablePixelsStartCol], -1,
            maskablePixelsEndCol - maskablePixelsStartCol + 1);

    if (returnedMinMatchingPixel)
    {
        *returnedMinMatchingPixel = minMatchingPixelValue;
    }

    if (returnedMaxMatchingPixel)
    {
        *returnedMaxMatchingPixel = maxMatchingPixelValue;
    }

    return YES;

ERROR:
    return NO;
}

- (bool) expandMatchingMaskInRow: (unsigned) row
            startCol: (unsigned) startCol
            endCol: (unsigned) endCol
            minMatchingPixel: (PPImageBitmapPixel *) minMatchingPixel
            maxMatchingPixel: (PPImageBitmapPixel *) maxMatchingPixel
            sourceBitmap: (NSBitmapImageRep *) sourceBitmap
            selectionMask: (NSBitmapImageRep *) selectionMask
            shouldCheckDiagonals: (bool) shouldCheckDiagonals
{
    int maskWidth, maskHeight, col, destinationBytesPerRow, maskablePixelsStartCol,
        maskablePixelsEndCol, checkStartCol, checkEndCol, i;
    unsigned char *destinationMaskData, *sourceBitmapData, *selectionMaskData,
                    *destinationMaskRow;
    PPMaskBitmapPixel *destinationMaskPixel, *selectionMaskPixel = NULL;
    PPImageBitmapPixel *sourcePixelToMatch;
    bool didExpandMask, foundMaskablePixelsEndCol, shouldEnableMaskablePixels;

    maskWidth = [self pixelsWide];
    maskHeight = [self pixelsHigh];

    if ((row >= maskHeight) || (startCol > maskWidth) || (endCol > maskWidth)
        || (startCol > endCol))
    {
        goto ERROR;
    }

    destinationMaskData = [self bitmapData];
    sourceBitmapData = [sourceBitmap bitmapData];

    if (!destinationMaskData || !sourceBitmapData)
    {
        goto ERROR;
    }

    if (selectionMask)
    {
        selectionMaskData = [selectionMask bitmapData];

        if (!selectionMaskData)
            goto ERROR;

        selectionMaskPixel =
            (PPMaskBitmapPixel *) &selectionMaskData[[selectionMask bytesPerRow] * row
                                                    + startCol * sizeof(PPMaskBitmapPixel)];
    }

    destinationBytesPerRow = [self bytesPerRow];
    destinationMaskRow = &destinationMaskData[destinationBytesPerRow * row];
    destinationMaskPixel =
        (PPMaskBitmapPixel *) &destinationMaskRow[startCol * sizeof(PPMaskBitmapPixel)];

    sourcePixelToMatch =
        (PPImageBitmapPixel *) &sourceBitmapData[[sourceBitmap bytesPerRow] * row
                                                    + startCol * sizeof(PPImageBitmapPixel)];


    didExpandMask = NO;
    col = startCol;

    while (col <= endCol)
    {
        if ((!selectionMask || *selectionMaskPixel)
            && !*destinationMaskPixel
            && macroImagePixelMatchesMinAndMaxPixels(sourcePixelToMatch,
                                                        minMatchingPixel,
                                                        maxMatchingPixel))
        {
            maskablePixelsStartCol = col;

            col++;
            destinationMaskPixel++;
            sourcePixelToMatch++;
            selectionMaskPixel++;

            foundMaskablePixelsEndCol = NO;

            while ((col <= endCol) && !foundMaskablePixelsEndCol)
            {
                if ((selectionMask && !*selectionMaskPixel)
                        || !macroImagePixelMatchesMinAndMaxPixels(sourcePixelToMatch,
                                                                    minMatchingPixel,
                                                                    maxMatchingPixel))
                {
                    maskablePixelsEndCol = col - 1;
                    foundMaskablePixelsEndCol = YES;
                }

                if (!foundMaskablePixelsEndCol)
                {
                    col++;
                    destinationMaskPixel++;
                    sourcePixelToMatch++;
                    selectionMaskPixel++;
                }
            }

            if (!foundMaskablePixelsEndCol)
            {
                maskablePixelsEndCol = endCol;
            }

            checkStartCol = maskablePixelsStartCol;
            checkEndCol = maskablePixelsEndCol;

            if (shouldCheckDiagonals)
            {
                if (checkStartCol > startCol)
                {
                    checkStartCol--;
                }

                if (checkEndCol < endCol)
                {
                    checkEndCol++;
                }
            }

            shouldEnableMaskablePixels = NO;

            if (row > 0)
            {
                unsigned char *destinationMaskRowAbove;

                destinationMaskRowAbove = &destinationMaskRow[-destinationBytesPerRow];

                for (i=checkStartCol; i<=checkEndCol; i++)
                {
                    if (destinationMaskRowAbove[i])
                    {
                        shouldEnableMaskablePixels = YES;
                        break;
                    }
                }
            }

            if (!shouldEnableMaskablePixels && (row < (maskHeight - 1)))
            {
                unsigned char *destinationMaskRowBelow;

                destinationMaskRowBelow = &destinationMaskRow[destinationBytesPerRow];

                for (i=checkStartCol; i<=checkEndCol; i++)
                {
                    if (destinationMaskRowBelow[i])
                    {
                        shouldEnableMaskablePixels = YES;
                        break;
                    }
                }
            }

            if (shouldEnableMaskablePixels)
            {
                memset(&destinationMaskRow[maskablePixelsStartCol], -1,
                        maskablePixelsEndCol - maskablePixelsStartCol + 1);

                didExpandMask = YES;
            }
        }

        col++;
        destinationMaskPixel++;
        sourcePixelToMatch++;
        selectionMaskPixel++;
    }

    return didExpandMask;

ERROR:
    return NO;
}

@end

#pragma mark Private functions

static bool GetMinAndMaxMatchingPixelsForImagePixelWithTolerance(
                                                        PPImageBitmapPixel *sourcePixel,
                                                        unsigned matchTolerance,
                                                        PPImageBitmapPixel *returnedMinPixel,
                                                        PPImageBitmapPixel *returnedMaxPixel)
{
    unsigned toleranceLowerBound, toleranceUpperBound;
    PPImagePixelComponentType componentType;
    PPImagePixelComponent sourcePixelComponent, minPixelComponent, maxPixelComponent;

    if (!sourcePixel || !returnedMinPixel || !returnedMaxPixel)
    {
        goto ERROR;
    }

    if (matchTolerance > kMaxMatchTolerance)
    {
        matchTolerance = kMaxMatchTolerance;
    }

    toleranceLowerBound = matchTolerance;
    toleranceUpperBound = kMaxImagePixelComponentValue - matchTolerance;

    for (componentType=0; componentType<kNumPPImagePixelComponents; componentType++)
    {
        sourcePixelComponent = macroImagePixelComponent(sourcePixel, componentType);

        minPixelComponent =
            (sourcePixelComponent > toleranceLowerBound) ?
                    sourcePixelComponent - matchTolerance : 0;

        maxPixelComponent =
            (sourcePixelComponent < toleranceUpperBound) ?
                    sourcePixelComponent + matchTolerance : kMaxImagePixelComponentValue;

        macroImagePixelComponent(returnedMinPixel, componentType) = minPixelComponent;
        macroImagePixelComponent(returnedMaxPixel, componentType) = maxPixelComponent;
    }

    return YES;

ERROR:
    return NO;
}
