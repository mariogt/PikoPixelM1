/*
    NSBezierPath_PPUtilities.m

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

#import "PPGeometry.h"


@implementation NSBezierPath (PPUtilities)

- (void) ppAppendSinglePixelLineAtPoint: (NSPoint) point
{
    point = PPGeometry_PixelCenteredPoint(point);

    // the slightly-offset (+0.25, +0.25) line element prevents [self bounds] from returning
    // an empty rect

    [self moveToPoint: point];
    [self lineToPoint: NSMakePoint(point.x + 0.25f, point.y + 0.25f)];
    [self lineToPoint: point];
}

- (void) ppAppendLineFromPixelAtPoint: (NSPoint) startPoint toPixelAtPoint: (NSPoint) endPoint
{
    startPoint = PPGeometry_PixelCenteredPoint(startPoint);
    endPoint = PPGeometry_PixelCenteredPoint(endPoint);

    [self moveToPoint: startPoint];

    if ((startPoint.x == endPoint.x) || (startPoint.y == endPoint.y))
    {
        // the slightly-offset (+0.25, +0.25) line element prevents [self bounds] from
        // returning an empty rect (horizontal or vertical lines have a zero dimension)

        [self lineToPoint: NSMakePoint(startPoint.x + 0.25f, startPoint.y + 0.25f)];
        [self lineToPoint: startPoint];
    }

    if (!NSEqualPoints(startPoint, endPoint))
    {
        [self lineToPoint: endPoint];
    }
}

- (void) ppLineToPixelAtPoint: (NSPoint) point
{
    [self lineToPoint: PPGeometry_PixelCenteredPoint(point)];
}

- (void) ppSetLastLineEndPointToPixelAtPoint: (NSPoint) point
{
    NSInteger indexOfLastElement;

    point = PPGeometry_PixelCenteredPoint(point);

    indexOfLastElement = [self elementCount] - 1;

    if ((indexOfLastElement < 0)
        || ([self elementAtIndex: indexOfLastElement] != NSLineToBezierPathElement))
    {
        goto ERROR;
    }

    [self setAssociatedPoints: &point atIndex: indexOfLastElement];

    return;

ERROR:
    return;
}

- (void) ppAppendZeroLengthLineAtLastLineEndPoint
{
    NSInteger indexOfLastElement;
    NSPoint lastPoints[3];

    indexOfLastElement = [self elementCount] - 1;

    if ((indexOfLastElement < 0)
        || ([self elementAtIndex: indexOfLastElement associatedPoints: lastPoints]
                != NSLineToBezierPathElement))
    {
        goto ERROR;
    }

    [self lineToPoint: lastPoints[0]];

    return;

ERROR:
    return;
}

- (bool) ppRemoveLastLineStartPointAndGetPreviousStartPoint: (NSPoint *) returnedStartPoint
{
    NSInteger indexOfElementToCopy, indexOfLastElementToOverwrite, index;
    NSPoint copyPoints[3], overwritePoints[3];

    // removes the last line segment by overwriting the next-to-last lineTo element's point
    // (start point of the last line segment) with the point from the next previous different
    // element - since there's no way to delete elements from an NSBezierPath, this procedure
    // leaves 'removed' elements in place as zero-length lines, so it may need to scan through
    // one or more zero-length line elements (left by previous removals) to find one with a
    // different start point (each zero-length lineTo element's point will also have to be
    // overwritten with the updated start point)

    indexOfLastElementToOverwrite = [self elementCount] - 2;

    if (indexOfLastElementToOverwrite < 1)
    {
        goto ERROR;
    }

    if ([self elementAtIndex: indexOfLastElementToOverwrite associatedPoints: overwritePoints]
            != NSLineToBezierPathElement)
    {
        goto ERROR;
    }

    indexOfElementToCopy = indexOfLastElementToOverwrite;
    copyPoints[0] = overwritePoints[0];

    while (NSEqualPoints(copyPoints[0], overwritePoints[0]))
    {
        if ((--indexOfElementToCopy < 0)
            || ([self elementAtIndex: indexOfElementToCopy associatedPoints: copyPoints]
                    != NSLineToBezierPathElement))
        {
            goto ERROR;
        }
    }

    for (index=indexOfElementToCopy+1; index<=indexOfLastElementToOverwrite; index++)
    {
        [self setAssociatedPoints: copyPoints atIndex: index];
    }

    if (returnedStartPoint)
    {
        *returnedStartPoint = PPGeometry_PointClippedToIntegerValues(copyPoints[0]);
    }

    return YES;

ERROR:
    return NO;
}

- (void) ppAppendPixelColumnSeparatorLinesInBounds: (NSRect) bounds
{
    CGFloat firstCol, lastCol, topRow, bottomRow, col;

    bounds = PPGeometry_PixelBoundsCoveredByRect(bounds);

    firstCol = NSMinX(bounds) + 1.0;
    lastCol = NSMaxX(bounds) - 1.0;

    topRow = NSMaxY(bounds);
    bottomRow = NSMinY(bounds);

    for (col=firstCol; col<=lastCol; col+=1.0)
    {
        [self moveToPoint: NSMakePoint(col, topRow)];
        [self lineToPoint: NSMakePoint(col, bottomRow)];
    }
}

- (void) ppAppendPixelRowSeparatorLinesInBounds: (NSRect) bounds
{
    CGFloat firstRow, lastRow, leftCol, rightCol, row;

    bounds = PPGeometry_PixelBoundsCoveredByRect(bounds);

    firstRow = NSMinY(bounds) + 1.0;
    lastRow = NSMaxY(bounds) - 1.0;

    leftCol = NSMinX(bounds);
    rightCol = NSMaxX(bounds);

    for (row=firstRow; row<=lastRow; row+=1.0)
    {
        [self moveToPoint: NSMakePoint(leftCol, row)];
        [self lineToPoint: NSMakePoint(rightCol, row)];
    }
}

- (void) ppAntialiasedFill
{
    NSGraphicsContext *currentContext;
    bool oldShouldAntialias;

    currentContext = [NSGraphicsContext currentContext];

    oldShouldAntialias = [currentContext shouldAntialias];
    [currentContext setShouldAntialias: YES];

    [self fill];

    [currentContext setShouldAntialias: oldShouldAntialias];
}

//  A pixelated path is a path with well-defined pixel boundaries - it's made up exclusively of
// horizontal, vertical, or 1:1 diagonal line-elements, each with pixel-centered endpoints -
// this prevents interpolation/roundoff issues from curve elements or differently-sloped lines,
// which can cause the path's fill area to have a slightly different shape than a stroke of the
// same path (due to some additional or missing pixels along the path's edges).

+ (NSBezierPath *) ppPixelatedBezierPathWithOvalInRect: (NSRect) rect
{
    NSBezierPath *path;
    NSPoint *arcPoints = NULL, centerPoint, offsetToCenterOfPixel, diagonalTangentPoint,
            arcPoint, pixelEdgePoint;
    NSSize arcSize, arcSizeSquared;
    int numArcPoints = 0, maxNumArcPoints, i;
    float arcHorizontalAspectRatio, arcVerticalAspectRatio, cosArctanOfVerticalAspectRatio,
            pixelTopEdgeIntersectionPos;
    bool arcIsCircular = NO, arcIsTransposed = NO;

    rect = PPGeometry_PixelCenteredRect(rect);

    if ((rect.size.width <= 1) || (rect.size.height <= 1))
    {
        return [self bezierPathWithRect: rect];
    }

    path = [NSBezierPath bezierPath];

    if (!path)
        goto ERROR;

    centerPoint = PPGeometry_CenterOfRect(rect);

    offsetToCenterOfPixel = NSMakePoint((centerPoint.x == floorf(centerPoint.x)) ? 0.5f : 0.0f,
                                        (centerPoint.y == floorf(centerPoint.y)) ? 0.5f : 0.0f);

    arcSize = NSMakeSize(NSMaxX(rect) - centerPoint.x, NSMaxY(rect) - centerPoint.y);

    if (arcSize.height == arcSize.width)
    {
        arcIsCircular = YES;
    }
    else if (arcSize.height > arcSize.width)
    {
        // 'tall' non-circular arcs are calculated using transposed geometry (coordinates are
        // flipped diagonally) - a single codepath for calculating arcs with the same dimensions
        // but different rotations ([w,h] vs. [h,w]) prevents shape mismatches when rotating
        // because both orientations share the same roundoff errors

        arcSize = NSMakeSize(arcSize.height, arcSize.width);
        offsetToCenterOfPixel = NSMakePoint(offsetToCenterOfPixel.y, offsetToCenterOfPixel.x);
        arcIsTransposed = YES;
    }

    arcSizeSquared = NSMakeSize(arcSize.width * arcSize.width, arcSize.height * arcSize.height);

    arcHorizontalAspectRatio = arcSize.width / arcSize.height;

    arcVerticalAspectRatio = arcSize.height / arcSize.width;

    // rough upper-bounds for maximum expected number of arc points - verified for rects in
    // the size range, ([3 - 6000],[3 - 6000])
    maxNumArcPoints = ceilf(arcSize.height * (2.0f - arcVerticalAspectRatio)) + 8;

    arcPoints = (NSPoint *) malloc (sizeof(NSPoint) * maxNumArcPoints);

    if (!arcPoints)
        goto ERROR;

    // diagonalTangentPoint: point on the arc where the tangent is 1:1 diagonal, determines
    // where to switch from drawing vertical lines to horizonal lines

    cosArctanOfVerticalAspectRatio =
                        1.0f / sqrtf(1.0f + arcVerticalAspectRatio * arcVerticalAspectRatio);

    diagonalTangentPoint =
        NSMakePoint(arcSize.width * cosArctanOfVerticalAspectRatio,
                    arcSize.height * arcVerticalAspectRatio * cosArctanOfVerticalAspectRatio);

    arcPoint = NSMakePoint(arcSize.width, 0.0f);
    pixelEdgePoint.x = arcPoint.x - 0.5f;
    pixelEdgePoint.y = arcPoint.y + offsetToCenterOfPixel.y + 0.5f;

    pixelTopEdgeIntersectionPos =
                        ceilf(sqrtf(arcSizeSquared.height - pixelEdgePoint.y * pixelEdgePoint.y)
                                * arcHorizontalAspectRatio
                                - offsetToCenterOfPixel.x)
                            + offsetToCenterOfPixel.x;

    if (pixelTopEdgeIntersectionPos < arcPoint.x)
    {
        arcPoints[numArcPoints++] = arcPoint;

        if (offsetToCenterOfPixel.y)
        {
            arcPoint.y += offsetToCenterOfPixel.y;
            arcPoints[numArcPoints++] = arcPoint;
        }

        arcPoint.x = pixelTopEdgeIntersectionPos;

        arcPoints[numArcPoints++] = arcPoint;

        arcPoint.x -= 1.0f;
        arcPoint.y += 1.0f;
        pixelEdgePoint.x -= 1.0f;
    }

    while (arcPoint.x > diagonalTangentPoint.x)
    {
        arcPoints[numArcPoints++] = arcPoint;

        arcPoint.y = ceilf(sqrtf(arcSizeSquared.width - pixelEdgePoint.x * pixelEdgePoint.x)
                            * arcVerticalAspectRatio
                            - 1.0f
                            - offsetToCenterOfPixel.y)
                        + offsetToCenterOfPixel.y;

        if (arcPoint.y > diagonalTangentPoint.y)
        {
            arcPoint.y -= 1.0f;
        }

        if (arcPoint.y < arcPoints[numArcPoints-1].y)
        {
            arcPoint.y = arcPoints[numArcPoints-1].y;
        }

        if (arcPoint.y != arcPoints[numArcPoints-1].y)
        {
            arcPoints[numArcPoints++] = arcPoint;
        }

        arcPoint.x -= 1.0f;
        arcPoint.y += 1.0f;
        pixelEdgePoint.x -= 1.0f;
    }

    if (arcIsCircular)
    {
        int arcPointIndex;

        if (arcPoint.x >= arcPoint.y)
        {
            arcPoints[numArcPoints++] = arcPoint;
        }

        arcPointIndex = numArcPoints - 1;

        if (arcPoints[arcPointIndex].x == arcPoints[arcPointIndex].y)
        {
            arcPointIndex--;
        }

        while (arcPointIndex > 0)
        {
            arcPoint = NSMakePoint(arcPoints[arcPointIndex].y, arcPoints[arcPointIndex].x);

            arcPoints[numArcPoints++] = arcPoint;

            arcPointIndex--;
        }

        arcPoint = NSMakePoint(arcPoints[arcPointIndex].y, arcPoints[arcPointIndex].x);
    }

    pixelEdgePoint.y = arcPoint.y + 0.5f;

    while (arcPoint.y < arcSize.height)
    {
        arcPoints[numArcPoints++] = arcPoint;

        arcPoint.x = ceilf(sqrtf(arcSizeSquared.height - pixelEdgePoint.y * pixelEdgePoint.y)
                            * arcHorizontalAspectRatio
                            - offsetToCenterOfPixel.x)
                        + offsetToCenterOfPixel.x;

        if (arcPoint.x > arcPoints[numArcPoints-1].x)
        {
            arcPoint.x = arcPoints[numArcPoints-1].x;
        }

        if (arcPoint.x != arcPoints[numArcPoints-1].x)
        {
            arcPoints[numArcPoints++] = arcPoint;
        }

        arcPoint.x -= 1.0f;
        arcPoint.y += 1.0f;
        pixelEdgePoint.y += 1.0f;
    }

    arcPoints[numArcPoints++] = arcPoint;

    arcPoint = NSMakePoint(0.0f, arcSize.height);

    if (!NSEqualPoints(arcPoint, arcPoints[numArcPoints-1]))
    {
        arcPoints[numArcPoints++] = arcPoint;
    }

    if (arcIsTransposed)
    {
        int index1, index2, index1Cutoff;
        NSPoint tempPoint;

        // flip the transposed arc back to its desired orientation by reversing the order of the
        // arcPoints array & swapping each point's x & y coordinates

        // index1Cutoff's value includes the array's middle entry (if there is one) in the
        // reordering/swapping loop - the middle point doesn't need reordering, but its x & y
        // coordinates need to be swapped
        index1Cutoff = (numArcPoints + 1) / 2;

        for (index1=0, index2=numArcPoints-1; index1<index1Cutoff; index1++, index2--)
        {
            tempPoint = arcPoints[index1];
            arcPoints[index1] = NSMakePoint(arcPoints[index2].y, arcPoints[index2].x);
            arcPoints[index2] = NSMakePoint(tempPoint.y, tempPoint.x);
        }
    }

    [path moveToPoint: NSMakePoint(centerPoint.x + arcPoints[0].x,
                                    centerPoint.y + arcPoints[0].y)];

    for (i=1; i<numArcPoints; i++)
    {
        [path lineToPoint: NSMakePoint(centerPoint.x + arcPoints[i].x,
                                        centerPoint.y + arcPoints[i].y)];
    }

    for (i=numArcPoints-2; i>=0; i--)
    {
        [path lineToPoint: NSMakePoint(centerPoint.x - arcPoints[i].x,
                                        centerPoint.y + arcPoints[i].y)];
    }

    for (i=1; i<numArcPoints; i++)
    {
        [path lineToPoint: NSMakePoint(centerPoint.x - arcPoints[i].x,
                                        centerPoint.y - arcPoints[i].y)];
    }

    for (i=numArcPoints-2; i>=0; i--)
    {
        [path lineToPoint: NSMakePoint(centerPoint.x + arcPoints[i].x,
                                        centerPoint.y - arcPoints[i].y)];
    }

    free(arcPoints);

    return path;

ERROR:
    if (arcPoints)
    {
        free(arcPoints);
    }

    return nil;
}

@end
