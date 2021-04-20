/*
    PPGeometry.h

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

#import <Foundation/Foundation.h>


NSPoint PPGeometry_CenterOfRect(NSRect rect);
NSRect PPGeometry_OriginRectOfSize(NSSize frameSize);
NSRect PPGeometry_CenterRectInRect(NSRect rectToBeCentered, NSRect centerRect);
NSRect PPGeometry_PixelBoundsCoveredByRect(NSRect rect);
NSRect PPGeometry_PixelBoundsWithCornerPoints(NSPoint corner1, NSPoint corner2);
NSRect PPGeometry_PixelBoundsWithCenterAndCornerPoint(NSPoint center, NSPoint corner);
NSRect PPGeometry_PixelCenteredRect(NSRect rect);
NSRect PPGeometry_RectScaledByFactor(NSRect rect, float scalingFactor);
bool PPGeometry_RectCoversMultiplePoints(NSRect rect);
bool PPGeometry_RectIsSquare(NSRect rect);
NSPoint PPGeometry_PointClippedToIntegerValues(NSPoint point);
NSPoint PPGeometry_PointClippedToRect(NSPoint point, NSRect rect);
NSPoint PPGeometry_PointSum(NSPoint point1, NSPoint point2);
NSPoint PPGeometry_PointDifference(NSPoint point1, NSPoint point2);
float PPGeometry_DistanceBetweenPoints(NSPoint point1, NSPoint point2);
unsigned PPGeometry_IntegerDistanceBetweenPoints(NSPoint point1, NSPoint point2);
NSPoint PPGeometry_PixelCenteredPoint(NSPoint point);
bool PPGeometry_PointTouchesEdgePixelOfRect(NSPoint point, NSRect rect);
NSSize PPGeometry_SizeClippedToIntegerValues(NSSize size);
NSSize PPGeometry_SizeClampedToMinMaxValues(NSSize size, float minValue, float maxValue);
NSSize PPGeometry_SizeSum(NSSize size1, NSSize size2);
NSSize PPGeometry_SizeDifference(NSSize size1, NSSize size2);
NSSize PPGeometry_SizeScaledByFactorAndRoundedToIntegerValues(NSSize size, float scalingFactor);
bool PPGeometry_IsZeroSize(NSSize size);
bool PPGeometry_SizeExceedsDimension(NSSize size, float dimension);
NSPoint PPGeometry_OriginPointForCenteringRectAtPoint(NSRect rect, NSPoint centerPoint);
NSPoint PPGeometry_OriginPointForCenteringSizeInSize(NSSize centeringSize, NSSize centerSize);
NSRect PPGeometry_ScaledBoundsForFrameOfSizeToFitFrameOfSize(NSSize sourceSize,
                                                            NSSize destinationSize);
float PPGeometry_ScalingFactorOfSourceRectToDestinationRect(NSRect sourceRect,
                                                            NSRect destinationRect);
NSPoint PPGeometry_OriginPointForConfiningRectInsideRect(NSRect rect, NSRect confinementBounds);
NSPoint PPGeometry_FarthestPointOnDiagonal(NSPoint originPoint, NSPoint point);
NSPoint PPGeometry_NearestPointOnOneSixteenthSlope(NSPoint originPoint, NSPoint point);
NSPoint PPGeometry_OffsetPointToNextNearestVertexOnGridWithSpacingSize(NSPoint point,
                                                                        NSSize spacingSize);
NSRect PPGeometry_GridBoundsCoveredByRectOnCanvasOfSizeWithGridOfSpacingSize(NSRect rect,
                                                                            NSSize canvasSize,
                                                                            NSSize spacingSize);
