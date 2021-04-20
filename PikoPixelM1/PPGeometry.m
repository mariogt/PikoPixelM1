/*
    PPGeometry.m

    Copyright 2013-2018,2020 Josh Freeman
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

#import "PPGeometry.h"


// disable clang warnings about fabsf() truncating passed double-type values to float-type
// (absolute-value warnings are enabled by default on Xcode 6.2 & later)
#ifdef __clang__
#   pragma clang diagnostic ignored "-Wabsolute-value"
#endif  // __clang__


NSPoint PPGeometry_CenterOfRect(NSRect rect)
{
    return NSMakePoint(rect.origin.x + rect.size.width / 2.0f,
                        rect.origin.y + rect.size.height / 2.0f);
}

NSRect PPGeometry_OriginRectOfSize(NSSize frameSize)
{
    return NSMakeRect(0.0f, 0.0f, ceilf(frameSize.width), ceilf(frameSize.height));
}

NSRect PPGeometry_CenterRectInRect(NSRect rectToBeCentered, NSRect centerRect)
{
    NSPoint centerPoint = PPGeometry_CenterOfRect(centerRect);

    rectToBeCentered.origin =
                PPGeometry_OriginPointForCenteringRectAtPoint(rectToBeCentered, centerPoint);

    return rectToBeCentered;
}

NSRect PPGeometry_PixelBoundsCoveredByRect(NSRect rect)
{
    NSRect coveredRect;

    if (NSIsEmptyRect(rect))
    {
        return NSZeroRect;
    }

    coveredRect.origin = NSMakePoint(floorf(rect.origin.x), floorf(rect.origin.y));
    coveredRect.size =
                NSMakeSize(ceilf(rect.origin.x + rect.size.width) - coveredRect.origin.x,
                            ceilf(rect.origin.y + rect.size.height) - coveredRect.origin.y);

    return coveredRect;
}

NSRect PPGeometry_PixelBoundsWithCornerPoints(NSPoint corner1, NSPoint corner2)
{
    NSRect rect;

    if (corner1.x < corner2.x)
    {
        rect.origin.x = corner1.x;
        rect.size.width = corner2.x - corner1.x + 1.0f;
    }
    else
    {
        rect.origin.x = corner2.x;
        rect.size.width = corner1.x - corner2.x + 1.0f;
    }

    if (corner1.y < corner2.y)
    {
        rect.origin.y = corner1.y;
        rect.size.height = corner2.y - corner1.y + 1.0f;
    }
    else
    {
        rect.origin.y = corner2.y;
        rect.size.height = corner1.y - corner2.y + 1.0f;
    }

    return PPGeometry_PixelBoundsCoveredByRect(rect);
}

NSRect PPGeometry_PixelBoundsWithCenterAndCornerPoint(NSPoint center, NSPoint corner)
{
    float deltaX, deltaY;
    NSRect rect;

    deltaX = fabsf(corner.x - center.x);
    deltaY = fabsf(corner.y - center.y);

    rect.origin = NSMakePoint(center.x - deltaX, center.y - deltaY);
    rect.size = NSMakeSize(1.0f + 2.0f * deltaX, 1.0f + 2.0f * deltaY);

    return PPGeometry_PixelBoundsCoveredByRect(rect);
}

NSRect PPGeometry_PixelCenteredRect(NSRect rect)
{
    if (NSIsEmptyRect(rect))
    {
        return NSZeroRect;
    }

    rect = PPGeometry_PixelBoundsCoveredByRect(rect);

    rect.origin = PPGeometry_PixelCenteredPoint(rect.origin);

    if (rect.size.width > 1.0f)
    {
        rect.size.width -= 1.0f;
    }
    else
    {
        rect.size.width = 0.25f;
    }

    if (rect.size.height > 1.0f)
    {
        rect.size.height -= 1.0f;
    }
    else
    {
        rect.size.height = 0.25f;
    }

    return rect;
}

NSRect PPGeometry_RectScaledByFactor(NSRect rect, float scalingFactor)
{
    return NSMakeRect(rect.origin.x * scalingFactor, rect.origin.y * scalingFactor,
                        rect.size.width * scalingFactor, rect.size.height * scalingFactor);
}

bool PPGeometry_RectCoversMultiplePoints(NSRect rect)
{
    if (NSIsEmptyRect(rect))
    {
        return NO;
    }

    rect = PPGeometry_PixelBoundsCoveredByRect(rect);

    return ((rect.size.width > 1.0f) || (rect.size.height > 1.0f)) ? YES : NO;
}

bool PPGeometry_RectIsSquare(NSRect rect)
{
    return ((rect.size.width > 0.0f)
            && (rect.size.width == rect.size.height))
                ? YES : NO;
}

NSPoint PPGeometry_PointClippedToIntegerValues(NSPoint point)
{
    return NSMakePoint(floorf(point.x), floorf(point.y));
}

NSPoint PPGeometry_PointClippedToRect(NSPoint point, NSRect rect)
{
    if (point.x < rect.origin.x)
    {
        point.x = rect.origin.x;
    }
    else if (point.x >= (rect.origin.x + rect.size.width))
    {
        point.x = rect.origin.x + rect.size.width - 1.0f;
    }

    if (point.y < rect.origin.y)
    {
        point.y = rect.origin.y;
    }
    else if (point.y >= (rect.origin.y + rect.size.height))
    {
        point.y = rect.origin.y + rect.size.height - 1.0f;
    }

    return point;
}

NSPoint PPGeometry_PointSum(NSPoint point1, NSPoint point2)
{
    return NSMakePoint(point1.x + point2.x, point1.y + point2.y);
}

NSPoint PPGeometry_PointDifference(NSPoint point1, NSPoint point2)
{
    return NSMakePoint(point1.x - point2.x, point1.y - point2.y);
}

float PPGeometry_DistanceBetweenPoints(NSPoint point1, NSPoint point2)
{
    NSPoint deltaPoint = PPGeometry_PointDifference(point1, point2);

    return sqrtf(deltaPoint.x * deltaPoint.x + deltaPoint.y * deltaPoint.y);
}

unsigned PPGeometry_IntegerDistanceBetweenPoints(NSPoint point1, NSPoint point2)
{
    return (unsigned) roundf(PPGeometry_DistanceBetweenPoints(point1, point2));
}

NSPoint PPGeometry_PixelCenteredPoint(NSPoint point)
{
    return NSMakePoint(floorf(point.x) + 0.5f, floorf(point.y) + 0.5f);
}

bool PPGeometry_PointTouchesEdgePixelOfRect(NSPoint point, NSRect rect)
{
    if ((fabsf(point.y - NSMaxY(rect)) <= 1.0f) // top edge
        || (fabsf(point.y - NSMinY(rect)) <= 1.0f)) // bottom edge
    {
        // point.x between left & right edges?
        return ((point.x >= (NSMinX(rect) - 1.0f)) && (point.x <= (NSMaxX(rect) + 1.0f))) ?
                    YES : NO;
    }

    if ((fabsf(point.x - NSMinX(rect)) <= 1.0f) // left edge
        || (fabsf(point.x - NSMaxX(rect)) <= 1.0f)) // right edge
    {
        // point.y between bottom & top edges?
        return ((point.y >= (NSMinY(rect) - 1.0f)) && (point.y <= (NSMaxY(rect) + 1.0f))) ?
                    YES : NO;
    }

    return NO;
}

NSSize PPGeometry_SizeClippedToIntegerValues(NSSize size)
{
    return NSMakeSize(floorf(size.width), floorf(size.height));
}

NSSize PPGeometry_SizeClampedToMinMaxValues(NSSize size, float minValue, float maxValue)
{
    if (size.width < minValue)
    {
        size.width = minValue;
    }
    else if (size.width > maxValue)
    {
        size.width = maxValue;
    }

    if (size.height < minValue)
    {
        size.height = minValue;
    }
    else if (size.height > maxValue)
    {
        size.height = maxValue;
    }

    return size;
}

NSSize PPGeometry_SizeSum(NSSize size1, NSSize size2)
{
    return NSMakeSize(size1.width + size2.width, size1.height + size2.height);
}

NSSize PPGeometry_SizeDifference(NSSize size1, NSSize size2)
{
    return NSMakeSize(size1.width - size2.width, size1.height - size2.height);
}

NSSize PPGeometry_SizeScaledByFactorAndRoundedToIntegerValues(NSSize size, float scalingFactor)
{
    return NSMakeSize(roundf(size.width * scalingFactor), roundf(size.height * scalingFactor));
}

bool PPGeometry_IsZeroSize(NSSize size)
{
    return ((size.width <= 0.0f) || (size.height <= 0.0f)) ? YES : NO;
}

bool PPGeometry_SizeExceedsDimension(NSSize size, float dimension)
{
    return ((size.width > dimension) || (size.height > dimension)) ? YES : NO;
}

NSPoint PPGeometry_OriginPointForCenteringRectAtPoint(NSRect rect, NSPoint centerPoint)
{
    return NSMakePoint(roundf(centerPoint.x - (rect.size.width / 2.0f)),
                        roundf(centerPoint.y - (rect.size.height / 2.0f)));
}

NSPoint PPGeometry_OriginPointForCenteringSizeInSize(NSSize centeringSize, NSSize centerSize)
{
    NSPoint centerPoint;
    NSRect rectToBeCentered;

    centerPoint = NSMakePoint(centerSize.width / 2.0f, centerSize.height / 2.0f);
    rectToBeCentered = PPGeometry_OriginRectOfSize(centeringSize);

    return PPGeometry_OriginPointForCenteringRectAtPoint(rectToBeCentered, centerPoint);
}

NSRect PPGeometry_ScaledBoundsForFrameOfSizeToFitFrameOfSize(NSSize sourceSize,
                                                            NSSize destinationSize)
{
    float sourceAspectRatio, destinationAspectRatio;
    NSRect scaledBounds;

    if (PPGeometry_IsZeroSize(sourceSize) || PPGeometry_IsZeroSize(destinationSize))
    {
        return NSZeroRect;
    }

    sourceAspectRatio = sourceSize.width / sourceSize.height;
    destinationAspectRatio = destinationSize.width / destinationSize.height;

    if (sourceAspectRatio == destinationAspectRatio)
    {
        scaledBounds = PPGeometry_OriginRectOfSize(destinationSize);
    }
    else if (sourceAspectRatio >= destinationAspectRatio)
    {
        float scaledHeight = roundf(destinationSize.width / sourceAspectRatio);

        if (scaledHeight < 1.0f)
        {
            scaledHeight = 1.0f;
        }

        scaledBounds.origin.x = 0.0f;
        scaledBounds.origin.y = roundf((destinationSize.height - scaledHeight) / 2.0f);

        scaledBounds.size.width = destinationSize.width;
        scaledBounds.size.height = scaledHeight;
    }
    else
    {
        float scaledWidth = roundf(destinationSize.height * sourceAspectRatio);

        if (scaledWidth < 1.0f)
        {
            scaledWidth = 1.0f;
        }

        scaledBounds.origin.x = roundf((destinationSize.width - scaledWidth) / 2.0f);
        scaledBounds.origin.y = 0.0f;

        scaledBounds.size.width = scaledWidth;
        scaledBounds.size.height = destinationSize.height;
    }

    return scaledBounds;
}

float PPGeometry_ScalingFactorOfSourceRectToDestinationRect(NSRect sourceRect,
                                                            NSRect destinationRect)
{
    if (sourceRect.size.width == 0)
    {
        return 0;
    }

    return (destinationRect.size.width / sourceRect.size.width);
}

NSPoint PPGeometry_OriginPointForConfiningRectInsideRect(NSRect rect, NSRect confinementBounds)
{
    if (rect.origin.x < confinementBounds.origin.x)
    {
        rect.origin.x = confinementBounds.origin.x;
    }
    else
    {
        float maxAllowedX = confinementBounds.origin.x + confinementBounds.size.width;

        if ((rect.origin.x + rect.size.width) > maxAllowedX)
        {
            rect.origin.x = maxAllowedX - rect.size.width;
        }
    }

    if (rect.origin.y < confinementBounds.origin.y)
    {
        rect.origin.y = confinementBounds.origin.y;
    }
    else
    {
        float maxAllowedY = confinementBounds.origin.y + confinementBounds.size.height;

        if ((rect.origin.y + rect.size.height) > maxAllowedY)
        {
            rect.origin.y = maxAllowedY - rect.size.height;
        }
    }

    return rect.origin;
}

NSPoint PPGeometry_FarthestPointOnDiagonal(NSPoint originPoint, NSPoint point)
{
    float deltaX, deltaY, delta;
    NSPoint nearestPoint;

    deltaX = fabsf(point.x - originPoint.x);
    deltaY = fabsf(point.y - originPoint.y);

    delta = (deltaX > deltaY) ? deltaX : deltaY;

    if (point.x >= originPoint.x)
    {
        nearestPoint.x = originPoint.x + delta;
    }
    else
    {
        nearestPoint.x = originPoint.x - delta;
    }

    if (point.y >= originPoint.y)
    {
        nearestPoint.y = originPoint.y + delta;
    }
    else
    {
        nearestPoint.y = originPoint.y - delta;
    }

    return PPGeometry_PointClippedToIntegerValues(nearestPoint);
}

NSPoint PPGeometry_NearestPointOnOneSixteenthSlope(NSPoint originPoint, NSPoint point)
{
    float deltaX, deltaY, xSign, ySign, slope;
    NSPoint nearestPoint;

    deltaX = fabsf(point.x - originPoint.x);
    deltaY = fabsf(point.y - originPoint.y);

    if ((deltaX == 0.0f) || (deltaY == 0.0f) || ((deltaX <= 2.0f) && (deltaY <= 2.0f)))
    {
        return point;
    }

    xSign = (point.x >= originPoint.x) ? 1.0f : -1.0f;
    ySign = (point.y >= originPoint.y) ? 1.0f : -1.0f;

    nearestPoint = point;
    slope = deltaY / deltaX;

    if (slope >= 4.0f)
    {
        nearestPoint.x = originPoint.x;
    }
    else if (slope >= 2.0f)
    {
        // roundup by 1 to make line endpoints draw properly (lineshift after 2 pixels, not 1)
        nearestPoint.y = originPoint.y + ySign * (2.0f * deltaX + 1.0f);
    }
    else if (slope >= 4.0f/3.0f)
    {
        if (deltaY/2.0f != floorf(deltaY/2.0f))
        {
            deltaY += 1.0f;
            nearestPoint.y += ySign;
        }

        nearestPoint.x = originPoint.x + xSign * (deltaY / 2.0f);
        nearestPoint.y += ySign; // roundup by 1 to make line endpoints draw properly
    }
    else if (slope >= 1.0f)
    {
        nearestPoint.y = originPoint.y + ySign * deltaX;
    }
    else if (slope >= 0.75f)
    {
        nearestPoint.x = originPoint.x + xSign * deltaY;
    }
    else if (slope >= 0.5f)
    {
        if (deltaX/2.0f != floorf(deltaX/2.0f))
        {
            deltaX += 1.0f;
            nearestPoint.x += xSign;
        }

        nearestPoint.x += xSign; // roundup by 1 to make line endpoints draw properly
        nearestPoint.y = originPoint.y + ySign * deltaX / 2.0f;
    }
    else if (slope >= 0.25f)
    {
        // roundup by 1 to make line endpoints draw properly (lineshift after 2 pixels, not 1)
        nearestPoint.x = originPoint.x + xSign * (2.0f * deltaY + 1.0f);
    }
    else
    {
        nearestPoint.y = originPoint.y;
    }

    return PPGeometry_PointClippedToIntegerValues(nearestPoint);
}

NSPoint PPGeometry_OffsetPointToNextNearestVertexOnGridWithSpacingSize(NSPoint point,
                                                                        NSSize spacingSize)
{
    int pointX, pointY, spacingWidth, spacingHeight, remainderX, remainderY;

    pointX = floorf(point.x);
    pointY = floorf(point.y);

    spacingWidth = floorf(spacingSize.width);
    spacingHeight = floorf(spacingSize.height);

    if ((spacingWidth <= 0) || (spacingHeight <= 0))
    {
        goto ERROR;
    }

    if (pointX < 0)
    {
        pointX = spacingWidth + (pointX % spacingWidth);
    }

    if (pointY < 0)
    {
        pointY = spacingHeight + (pointY % spacingHeight);
    }

    remainderX = pointX % spacingWidth;
    remainderY = pointY % spacingHeight;

    return NSMakePoint((remainderX) ? spacingWidth - remainderX : 0.0f,
                        (remainderY) ? spacingHeight - remainderY : 0.0f);

ERROR:
    return NSZeroPoint;
}

NSRect PPGeometry_GridBoundsCoveredByRectOnCanvasOfSizeWithGridOfSpacingSize(NSRect rect,
                                                                            NSSize canvasSize,
                                                                            NSSize spacingSize)
{
    NSPoint offsetToGridVertex, topRightPoint;
    NSRect gridAlignedRect;
    float gridlinesBottomGap;

    canvasSize = PPGeometry_SizeClippedToIntegerValues(canvasSize);
    spacingSize = PPGeometry_SizeClippedToIntegerValues(spacingSize);

    if (NSIsEmptyRect(rect)
        || PPGeometry_IsZeroSize(canvasSize)
        || PPGeometry_IsZeroSize(spacingSize))
    {
        return rect;
    }

    rect = PPGeometry_PixelBoundsCoveredByRect(rect);

    // bottom-left

    offsetToGridVertex =
        PPGeometry_OffsetPointToNextNearestVertexOnGridWithSpacingSize(
                                NSMakePoint(rect.origin.x, canvasSize.height - rect.origin.y),
                                spacingSize);

    if (offsetToGridVertex.x)
    {
        offsetToGridVertex.x = spacingSize.width - offsetToGridVertex.x;
    }

    gridAlignedRect.origin = PPGeometry_PointDifference(rect.origin, offsetToGridVertex);

    // top-right

    topRightPoint = NSMakePoint(NSMaxX(rect), NSMaxY(rect));

    gridlinesBottomGap =
        PPGeometry_OffsetPointToNextNearestVertexOnGridWithSpacingSize(
                                                        NSMakePoint(0.0f, canvasSize.height),
                                                        spacingSize).y;

    offsetToGridVertex =
        PPGeometry_OffsetPointToNextNearestVertexOnGridWithSpacingSize(
                            NSMakePoint(topRightPoint.x, topRightPoint.y + gridlinesBottomGap),
                            spacingSize);

    gridAlignedRect.size =
                NSMakeSize(topRightPoint.x + offsetToGridVertex.x - gridAlignedRect.origin.x,
                            topRightPoint.y + offsetToGridVertex.y - gridAlignedRect.origin.y);

    return NSIntersectionRect(gridAlignedRect, PPGeometry_OriginRectOfSize(canvasSize));
}
