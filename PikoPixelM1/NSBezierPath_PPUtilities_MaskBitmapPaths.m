/*
    NSBezierPath_PPUtilities_MaskBitmapPaths.m

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

#import "NSBezierPath_PPUtilities.h"

#import "NSBitmapImageRep_PPUtilities.h"
#import "PPGeometry.h"


#pragma mark Macros & definitions for +ppAppendOutlinePathsForMaskBitmap:... method

//*******************************************************************************************/
// +ppAppendOutlinePathsForMaskBitmap:... method appends paths that can be used to draw an
// animated, continuous "marching ants" outline around the selected (nonzero) pixels in a
// 1-channel mask bitmap.
//
//   PPCanvasView currently animates the selection outline using a pattern color, so the
// outline needs to be in two separate paths in order for the "marching ants" motion to appear
// continuous (horizontal lines on top need to move to the right, and move to the left on the
// bottom); If a single closed path is animated by offsetting a pattern color, all parallel
// lines will move in the same direction and won't appear continuous - the "ants" would appear
// to be coming out of some corners in both directions, then disappearing into opposite corners.
//
//   The outline paths are calculated by scanning the mask bitmap two rows at a time, examining
// 4 pixels at once (2x2 grid) for patterns of pixels that should be represented as corners on
// the outline. Neighboring corners are then connected by adding vertical or horizontal lines
// to the appropriate path.
//
//   An outline corner's type (the direction the outline takes into and out of the corner's
// vertex) is used to determine the particular set of lines to add to the outline path(s).
// The corner type is calculated by converting the 4 mask-pixel values into a 4-bit bitmask;
// The mask's 16 possible values are then used to index into a lookup table,
// kCornerTypeFor2x2PixelBitMask[], which matches the bitmask pattern to one of 11 possible
// types of corners (several pixel patterns result in "NotACorner"). The corner type is
// represented by the enum, PPCornerType.


//*******************************************************************************************/
// macroShiftMaskPixelsInto2x2BitMask(): Macro to convert a 2x2 grid of mask pixel values into
// a bitmask, with each bit representing whether the pixel's value is nonzero. The bitfields
// are:
// +---+---+
// | 2 | 0 |
// +---+---+
// | 3 | 1 |
// +---+---+
// The macro shifts in two pixel values at a time from the right side, as pixelValueAbove &
// pixelValueBelow (0 & 1), shifting the previous right column to the left (0 -> 2, 1 -> 3).

#define macroShiftMaskPixelsInto2x2BitMask(mask, pixelValueAbove, pixelValueBelow)          \
            {                                                                               \
                mask = (mask << 2) & 0x0F;                                                  \
                if (pixelValueAbove) mask |= 1;                                             \
                if (pixelValueBelow) mask |= 2;                                             \
            }


//*******************************************************************************************/
// PPCornerType enumerates the 11 possible types of outline path corners:
// (L=Left, R=Right, T=Top, B=Bottom, N/C=NotACorner)
//
//  N/C   L-B   T-L   R-T   B-R   B-L   R-B   T-R   L-T   LB,RT TL,BR
//               |     ^                       |     ^     ^     |
//        -+    <+     +-    +>   <+     +-    +>   -+    -+-   <+>
//         v                 |     |     v                 v     |

typedef enum
{
    kPPCornerType_NotACorner,
    kPPCornerType_LeftToBottom,
    kPPCornerType_TopToLeft,
    kPPCornerType_RightToTop,
    kPPCornerType_BottomToRight,
    kPPCornerType_BottomToLeft,
    kPPCornerType_RightToBottom,
    kPPCornerType_TopToRight,
    kPPCornerType_LeftToTop,
    kPPCornerType_LeftToBottom_RightToTop,
    kPPCornerType_TopToLeft_BottomToRight,

} PPCornerType;


//*******************************************************************************************/
// kCornerTypeFor2x2PixelBitMask[] is a lookup table for coverting the 16 possible values of
// the mask-pixel 2x2 bitmask into one of the 11 possible corner types:
// (@=Selected (nonzero) pixel, .=Unselected pixel)
//
//    0     1     2     3     4     5     6     7     8     9    10    11    12    13    14    15
//  . .   .^@   . .   .|@   @|.   @ @   @|.   @ @   . .   .^@   . .   .^@   @|.   @ @   @|.   @ @
//         +-    +>    |    <+    ---   <+>   <+    -+    -+-   ---   -+     |     +-    +>
//  . .   . .   .|@   .|@   . .   . .   .|@   .|@   @v.   @v.   @ @   @ @   @|.   @v.   @ @   @ @
//  N/C   R-T   B-R   N/C   T-L   N/C   TL,BR B-L   L-B   LB,RT N/C   L-T   N/C   R-B   T-R   N/C

const int kCornerTypeFor2x2PixelBitMask[16] =
{
    kPPCornerType_NotACorner,
    kPPCornerType_RightToTop,
    kPPCornerType_BottomToRight,
    kPPCornerType_NotACorner,
    kPPCornerType_TopToLeft,
    kPPCornerType_NotACorner,
    kPPCornerType_TopToLeft_BottomToRight,
    kPPCornerType_BottomToLeft,
    kPPCornerType_LeftToBottom,
    kPPCornerType_LeftToBottom_RightToTop,
    kPPCornerType_NotACorner,
    kPPCornerType_LeftToTop,
    kPPCornerType_NotACorner,
    kPPCornerType_RightToBottom,
    kPPCornerType_TopToRight,
    kPPCornerType_NotACorner
};


//*******************************************************************************************/
// Horizontal-line macros for +ppAppendOutlinePathsForMaskBitmap:... method

#define macroSaveCurrentPointAsHorizontalLineEndpoint                                       \
            {                                                                               \
                horizontalLineEndpoint = currentPoint.x;                                    \
            }

#define macroHorizontalLineEndpoint                                                         \
                (NSMakePoint(horizontalLineEndpoint, currentPoint.y))

#define macroAddHorizontalLineRightToCurrentPoint                                           \
            {                                                                               \
                [topRightPath moveToPoint: macroHorizontalLineEndpoint];                    \
                [topRightPath lineToPoint: currentPoint];                                   \
            }

#define macroAddHorizontalLineLeftFromCurrentPoint                                          \
            {                                                                               \
                [bottomLeftPath moveToPoint: currentPoint];                                 \
                [bottomLeftPath lineToPoint: macroHorizontalLineEndpoint];                  \
            }


//*******************************************************************************************/
// Vertical-line macros for +ppAppendOutlinePathsForMaskBitmap:... method

#define macroSaveCurrentPointAsVerticalLineEndpoint                                         \
            {                                                                               \
                verticalLineEndpoints[currentCol] = currentPoint.y;                         \
            }

#define macroVerticalLineEndpoint                                                           \
                (NSMakePoint(currentPoint.x, verticalLineEndpoints[currentCol]))

#define macroAddVerticalLineDownToCurrentPoint                                              \
            {                                                                               \
                [topRightPath moveToPoint: macroVerticalLineEndpoint];                      \
                [topRightPath lineToPoint: currentPoint];                                   \
            }

#define macroAddVerticalLineUpFromCurrentPoint                                              \
            {                                                                               \
                [bottomLeftPath moveToPoint: currentPoint];                                 \
                [bottomLeftPath lineToPoint: macroVerticalLineEndpoint];                    \
            }


//*******************************************************************************************/
// macroHandleCornerTypeAtCurrentPoint(): Macro for +ppAppendOutlinePathsForMaskBitmap:...
// method which handles adding lines to the appropriate path or storing line endpoints for
// later use, depending on the current point's corner type

#define macroHandleCornerTypeAtCurrentPoint(cornerType)                                     \
            {                                                                               \
                switch (cornerType)                                                         \
                {                                                                           \
                    case kPPCornerType_NotACorner:                                          \
                    break;                                                                  \
                                                                                            \
                    case kPPCornerType_LeftToBottom:                                        \
                        macroAddHorizontalLineRightToCurrentPoint;                          \
                        macroSaveCurrentPointAsVerticalLineEndpoint;                        \
                    break;                                                                  \
                                                                                            \
                    case kPPCornerType_TopToLeft:                                           \
                        macroAddVerticalLineDownToCurrentPoint;                             \
                        macroAddHorizontalLineLeftFromCurrentPoint;                         \
                    break;                                                                  \
                                                                                            \
                    case kPPCornerType_RightToTop:                                          \
                        macroSaveCurrentPointAsHorizontalLineEndpoint;                      \
                        macroAddVerticalLineUpFromCurrentPoint;                             \
                    break;                                                                  \
                                                                                            \
                    case kPPCornerType_BottomToRight:                                       \
                        macroSaveCurrentPointAsVerticalLineEndpoint;                        \
                        macroSaveCurrentPointAsHorizontalLineEndpoint;                      \
                    break;                                                                  \
                                                                                            \
                    case kPPCornerType_BottomToLeft:                                        \
                        macroSaveCurrentPointAsVerticalLineEndpoint;                        \
                        macroAddHorizontalLineLeftFromCurrentPoint;                         \
                    break;                                                                  \
                                                                                            \
                    case kPPCornerType_RightToBottom:                                       \
                        macroSaveCurrentPointAsHorizontalLineEndpoint;                      \
                        macroSaveCurrentPointAsVerticalLineEndpoint;                        \
                    break;                                                                  \
                                                                                            \
                    case kPPCornerType_TopToRight:                                          \
                        macroAddVerticalLineDownToCurrentPoint;                             \
                        macroSaveCurrentPointAsHorizontalLineEndpoint;                      \
                    break;                                                                  \
                                                                                            \
                    case kPPCornerType_LeftToTop:                                           \
                        macroAddHorizontalLineRightToCurrentPoint;                          \
                        macroAddVerticalLineUpFromCurrentPoint;                             \
                    break;                                                                  \
                                                                                            \
                    case kPPCornerType_LeftToBottom_RightToTop:                             \
                        macroAddHorizontalLineRightToCurrentPoint;                          \
                        macroAddVerticalLineUpFromCurrentPoint;                             \
                        macroSaveCurrentPointAsHorizontalLineEndpoint;                      \
                        macroSaveCurrentPointAsVerticalLineEndpoint;                        \
                    break;                                                                  \
                                                                                            \
                    case kPPCornerType_TopToLeft_BottomToRight:                             \
                        macroAddVerticalLineDownToCurrentPoint;                             \
                        macroAddHorizontalLineLeftFromCurrentPoint;                         \
                        macroSaveCurrentPointAsHorizontalLineEndpoint;                      \
                        macroSaveCurrentPointAsVerticalLineEndpoint;                        \
                    break;                                                                  \
                                                                                            \
                    default:                                                                \
                    break;                                                                  \
                }                                                                           \
            }


@implementation NSBezierPath (PPUtilities_MaskBitmapPaths)

+ (void) ppAppendOutlinePathsForMaskBitmap: (NSBitmapImageRep *) maskBitmap
            inBounds: (NSRect) bounds
            toTopRightBezierPath: (NSBezierPath *) topRightPath
            andBottomLeftBezierPath: (NSBezierPath *) bottomLeftPath
{
    static float *verticalLineEndpoints = NULL;
    static int numVerticalLineEndpoints = 0;
    float horizontalLineEndpoint = 0;
    NSRect bitmapFrame;
    int bytesPerRow, rowOffset, dataOffset, startCol, endCol, numRows, numInteriorRows,
        rowCounter, currentCol, pixelValues2x2BitMask;
    NSPoint currentPoint;
    unsigned char *maskData, *currentRowAbove, *currentRowBelow;
    PPMaskBitmapPixel *currentPixelAbove, *currentPixelBelow;

    if (![maskBitmap ppIsMaskBitmap])
    {
        goto ERROR;
    }

    bitmapFrame = [maskBitmap ppFrameInPixels];

    bounds = NSIntersectionRect(PPGeometry_PixelBoundsCoveredByRect(bounds), bitmapFrame);

    if (NSIsEmptyRect(bounds))
    {
        goto ERROR;
    }

    if (!verticalLineEndpoints
        || (numVerticalLineEndpoints <= ((int) bitmapFrame.size.width)))
    {
        int requiredNumVerticalLineEndpoints = bitmapFrame.size.width + 1;

        if (verticalLineEndpoints)
        {
            free(verticalLineEndpoints);

            verticalLineEndpoints = NULL;
            numVerticalLineEndpoints = 0;
        }

        verticalLineEndpoints =
                        (float *) malloc (requiredNumVerticalLineEndpoints * sizeof(float));

        if (!verticalLineEndpoints)
            goto ERROR;

        numVerticalLineEndpoints = requiredNumVerticalLineEndpoints;
    }

    maskData = [maskBitmap bitmapData];

    if (!maskData)
        goto ERROR;

    bytesPerRow = [maskBitmap bytesPerRow];

    rowOffset = bitmapFrame.size.height - bounds.size.height - bounds.origin.y;

    dataOffset = rowOffset * bytesPerRow
                    + (int) bounds.origin.x * sizeof(PPMaskBitmapPixel);

    currentRowAbove = NULL;
    currentRowBelow = &maskData[dataOffset];

    startCol = bounds.origin.x;
    endCol = startCol + bounds.size.width;

    numRows = bounds.size.height;
    numInteriorRows = (numRows > 1) ? numRows - 1 : 0;

    // TOP ROW

    currentPixelBelow = (PPMaskBitmapPixel *) currentRowBelow;
    currentPoint = NSMakePoint(bounds.origin.x, bounds.origin.y + bounds.size.height);
    pixelValues2x2BitMask = 0;

    for (currentCol=startCol; currentCol<endCol; currentCol++)
    {
        macroShiftMaskPixelsInto2x2BitMask(pixelValues2x2BitMask, 0, *currentPixelBelow);
        macroHandleCornerTypeAtCurrentPoint(
                                    kCornerTypeFor2x2PixelBitMask[pixelValues2x2BitMask]);

        currentPixelBelow++;
        currentPoint.x += 1.0f;
    }

    // Last column (top row)

    macroShiftMaskPixelsInto2x2BitMask(pixelValues2x2BitMask, 0, 0);
    macroHandleCornerTypeAtCurrentPoint(kCornerTypeFor2x2PixelBitMask[pixelValues2x2BitMask]);

    currentRowAbove = currentRowBelow;
    currentRowBelow += bytesPerRow;
    currentPoint.y -= 1.0f;

    // INTERIOR ROWS

    rowCounter = numInteriorRows;

    while (rowCounter--)
    {
        currentPixelAbove = currentRowAbove;
        currentPixelBelow = currentRowBelow;
        currentPoint.x = bounds.origin.x;
        pixelValues2x2BitMask = 0;

        for (currentCol=startCol; currentCol<endCol; currentCol++)
        {
            macroShiftMaskPixelsInto2x2BitMask(pixelValues2x2BitMask, *currentPixelAbove,
                                                *currentPixelBelow);
            macroHandleCornerTypeAtCurrentPoint(
                                        kCornerTypeFor2x2PixelBitMask[pixelValues2x2BitMask]);

            currentPixelAbove++;
            currentPixelBelow++;
            currentPoint.x += 1.0f;
        }

        // Last column (interior rows)

        macroShiftMaskPixelsInto2x2BitMask(pixelValues2x2BitMask, 0, 0);
        macroHandleCornerTypeAtCurrentPoint(
                                        kCornerTypeFor2x2PixelBitMask[pixelValues2x2BitMask]);

        currentRowAbove = currentRowBelow;
        currentRowBelow += bytesPerRow;
        currentPoint.y -= 1.0f;
    }

    // BOTTOM ROW

    currentPixelAbove = (PPMaskBitmapPixel *) currentRowAbove;
    currentPoint.x = bounds.origin.x;
    pixelValues2x2BitMask = 0;

    for (currentCol=startCol; currentCol<endCol; currentCol++)
    {
        macroShiftMaskPixelsInto2x2BitMask(pixelValues2x2BitMask, *currentPixelAbove, 0);
        macroHandleCornerTypeAtCurrentPoint(
                                        kCornerTypeFor2x2PixelBitMask[pixelValues2x2BitMask]);

        currentPixelAbove++;
        currentPoint.x += 1.0f;
    }

    // Last column (bottom row)

    macroShiftMaskPixelsInto2x2BitMask(pixelValues2x2BitMask, 0, 0);
    macroHandleCornerTypeAtCurrentPoint(kCornerTypeFor2x2PixelBitMask[pixelValues2x2BitMask]);

    return;

ERROR:
    return;
}

- (void) ppAppendOutlinePathForMaskBitmap: (NSBitmapImageRep *) maskBitmap
            inBounds: (NSRect) bounds
{
    [NSBezierPath ppAppendOutlinePathsForMaskBitmap: maskBitmap
                    inBounds: bounds
                    toTopRightBezierPath: self
                    andBottomLeftBezierPath: self];
}

- (void) ppAppendRightEdgePathForMaskBitmap: (NSBitmapImageRep *) maskBitmap
{
    NSSize bitmapSize;
    int bytesPerRow, lastCol, rowCounter;
    unsigned char *bitmapData;
    PPMaskBitmapPixel *currentPixel;
    NSPoint currentPoint, lineStartPoint;
    bool didStartLine;

    if (![maskBitmap ppIsMaskBitmap])
    {
        goto ERROR;
    }

    bitmapSize = [maskBitmap ppSizeInPixels];

    if (PPGeometry_IsZeroSize(bitmapSize))
    {
        goto ERROR;
    }

    bitmapData = [maskBitmap bitmapData];

    if (!bitmapData)
        goto ERROR;

    bytesPerRow = [maskBitmap bytesPerRow];

    lastCol = bitmapSize.width - 1;

    currentPixel = (PPMaskBitmapPixel *) &bitmapData[lastCol];
    currentPoint = NSMakePoint(bitmapSize.width, bitmapSize.height);

    didStartLine = NO;

    rowCounter = bitmapSize.height;

    while (rowCounter--)
    {
        if (*currentPixel)
        {
            if (!didStartLine)
            {
                lineStartPoint = currentPoint;
                didStartLine = YES;
            }
        }
        else
        {
            if (didStartLine)
            {
                [self moveToPoint: lineStartPoint];
                [self lineToPoint: currentPoint];

                didStartLine = NO;
            }
        }

        currentPixel += bytesPerRow;
        currentPoint.y -= 1.0f;
    }

    if (didStartLine)
    {
        [self moveToPoint: lineStartPoint];
        [self lineToPoint: currentPoint];
    }

    return;

ERROR:
    return;
}

- (void) ppAppendBottomEdgePathForMaskBitmap: (NSBitmapImageRep *) maskBitmap
{
    NSSize bitmapSize;
    int lastRow, pixelCounter;
    unsigned char *bitmapData;
    PPMaskBitmapPixel *currentPixel;
    NSPoint currentPoint, lineEndPoint;
    bool didStartLine;

    if (![maskBitmap ppIsMaskBitmap])
    {
        goto ERROR;
    }

    bitmapSize = [maskBitmap ppSizeInPixels];

    if (PPGeometry_IsZeroSize(bitmapSize))
    {
        goto ERROR;
    }

    bitmapData = [maskBitmap bitmapData];

    if (!bitmapData)
        goto ERROR;

    lastRow = bitmapSize.height - 1;

    currentPixel = (PPMaskBitmapPixel *) &bitmapData[lastRow * [maskBitmap bytesPerRow]];
    currentPoint = NSZeroPoint;

    didStartLine = NO;

    pixelCounter = bitmapSize.width;

    while (pixelCounter--)
    {
        if (*currentPixel)
        {
            if (!didStartLine)
            {
                lineEndPoint = currentPoint;
                didStartLine = YES;
            }
        }
        else
        {
            if (didStartLine)
            {
                [self moveToPoint: currentPoint];
                [self lineToPoint: lineEndPoint];

                didStartLine = NO;
            }
        }

        currentPixel++;
        currentPoint.x += 1.0f;
    }

    if (didStartLine)
    {
        [self moveToPoint: currentPoint];
        [self lineToPoint: lineEndPoint];
    }

    return;

ERROR:
    return;
}

- (void) ppAppendFillPathForMaskBitmap: (NSBitmapImageRep *) maskBitmap
            inBounds: (NSRect) bounds
{
    NSRect bitmapFrame;
    unsigned char *maskData, *maskRow;
    int maskBytesPerRow, rowOffset, maskDataOffset, topRow, bottomRow, startCol, endCol,
        row, col, fillBeginCol;
    PPMaskBitmapPixel *maskPixel;
    NSRect fillRect;

    if (![maskBitmap ppIsMaskBitmap])
    {
        goto ERROR;
    }

    bitmapFrame = [maskBitmap ppFrameInPixels];

    bounds = NSIntersectionRect(PPGeometry_PixelBoundsCoveredByRect(bounds), bitmapFrame);

    if (NSIsEmptyRect(bounds))
    {
        goto ERROR;
    }

    maskData = [maskBitmap bitmapData];

    if (!maskData)
        goto ERROR;

    maskBytesPerRow = [maskBitmap bytesPerRow];

    rowOffset = bitmapFrame.size.height - bounds.size.height - bounds.origin.y;

    maskDataOffset = rowOffset * maskBytesPerRow
                        + (int) bounds.origin.x * sizeof(PPMaskBitmapPixel);

    maskRow = &maskData[maskDataOffset];

    bottomRow = bounds.origin.y;
    topRow = bottomRow + bounds.size.height - 1;

    startCol = bounds.origin.x;
    endCol = startCol + bounds.size.width - 1;

    for (row=topRow; row>=bottomRow; row--)
    {
        maskPixel = (PPMaskBitmapPixel *) maskRow;
        col = startCol;

        while (col <= endCol)
        {
            if (*maskPixel)
            {
                fillBeginCol = col;

                maskPixel++;
                col++;

                while ((col <= endCol) && *maskPixel)
                {
                    maskPixel++;
                    col++;
                }

                fillRect = NSMakeRect(fillBeginCol, row, col - fillBeginCol, 1);
                [self appendBezierPathWithRect: fillRect];
            }

            maskPixel++;
            col++;
        }

        maskRow += maskBytesPerRow;
    }

    return;

ERROR:
    return;
}

- (void) ppAppendXMarksForUnmaskedPixelsInMaskBitmap: (NSBitmapImageRep *) maskBitmap
            inBounds: (NSRect) bounds
{
    NSRect bitmapFrame;
    unsigned char *maskData, *maskRow;
    int maskBytesPerRow, rowOffset, maskDataOffset, topRow, bottomRow, startCol, endCol,
        row, col;
    PPMaskBitmapPixel *maskPixel;

    if (![maskBitmap ppIsMaskBitmap])
    {
        goto ERROR;
    }

    bitmapFrame = [maskBitmap ppFrameInPixels];

    bounds = NSIntersectionRect(PPGeometry_PixelBoundsCoveredByRect(bounds), bitmapFrame);

    if (NSIsEmptyRect(bounds))
    {
        goto ERROR;
    }

    maskData = [maskBitmap bitmapData];

    if (!maskData)
        goto ERROR;

    maskBytesPerRow = [maskBitmap bytesPerRow];

    rowOffset = bitmapFrame.size.height - bounds.size.height - bounds.origin.y;

    maskDataOffset = rowOffset * maskBytesPerRow
                        + (int) bounds.origin.x * sizeof(PPMaskBitmapPixel);

    maskRow = &maskData[maskDataOffset];

    bottomRow = bounds.origin.y;
    topRow = bottomRow + bounds.size.height - 1;

    startCol = bounds.origin.x;
    endCol = startCol + bounds.size.width - 1;

    for (row=topRow; row>=bottomRow; row--)
    {
        maskPixel = (PPMaskBitmapPixel *) maskRow;
        col = startCol;

        while (col <= endCol)
        {
            if (!*maskPixel)
            {
                [self moveToPoint: NSMakePoint(col, row)];
                [self lineToPoint: NSMakePoint(col+1, row+1)];

                [self moveToPoint: NSMakePoint(col, row+1)];
                [self lineToPoint: NSMakePoint(col+1, row)];
            }

            maskPixel++;
            col++;
        }

        maskRow += maskBytesPerRow;
    }

    return;

ERROR:
    return;
}

@end
