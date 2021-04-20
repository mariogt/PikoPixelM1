/*
    PPMagicWandTool.m

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

#import "PPMagicWandTool.h"

#import "PPDocument.h"
#import "PPCanvasView.h"
#import "PPGeometry.h"
#import "PPToolUtilities.h"
#import "NSBitmapImageRep_PPUtilities.h"
#import "NSCursor_PPUtilities.h"


#define kWandToolAttributesMask                                                 \
            (kPPToolAttributeMask_RequiresPointsInViewCoordinates               \
            | kPPToolAttributeMask_DisableAutoscrolling                         \
            | kPPToolAttributeMask_MatchCanvasDisplayModeToOperationTarget)


@interface PPMagicWandTool (PrivateMethods)

- (void) updateSelectionToolOverlayOnCanvasView: (PPCanvasView *) canvasView
            withColorMatchTolerance: (unsigned) colorMatchTolerance
            andModifierKeyFlags: (int) modifierKeyFlags
            forDocument: (PPDocument *) ppDocument;

- (void) setupValueOfSelectionMaskCoversMouseDownPointWithDocument: (PPDocument *) ppDocument;

@end

@implementation PPMagicWandTool

- (void) mouseDownForDocument: (PPDocument *) ppDocument
            withCanvasView: (PPCanvasView *) canvasView
            currentPoint: (NSPoint) currentPoint
            modifierKeyFlags: (unsigned) modifierKeyFlags
{
    // tool receives points in view coordinates, must convert to get image coordinates
    _mouseDownLocationInImage = [canvasView imagePointFromViewPoint: currentPoint
                                                clippedToCanvasBounds: YES];

    [canvasView showMatchToolToleranceIndicatorAtViewPoint: currentPoint];
    _lastColorMatchTolerance = -1;  // force update

    _needToSetupValueOfSelectionMaskCoversMouseDownPoint = YES;

    [self updateSelectionToolOverlayOnCanvasView: canvasView
            withColorMatchTolerance: 0
            andModifierKeyFlags: modifierKeyFlags
            forDocument: ppDocument];
}

- (void) mouseDraggedOrModifierKeysChangedForDocument: (PPDocument *) ppDocument
            withCanvasView: (PPCanvasView *) canvasView
            currentPoint: (NSPoint) currentPoint
            lastPoint: (NSPoint) lastPoint
            mouseDownPoint: (NSPoint) mouseDownPoint
            modifierKeyFlags: (unsigned) modifierKeyFlags
{
    unsigned mouseDistance, colorMatchTolerance;

    mouseDistance = PPGeometry_IntegerDistanceBetweenPoints(mouseDownPoint, currentPoint);
    colorMatchTolerance = PPToolUtils_ColorMatchToleranceForMouseDistance(mouseDistance);

    [self updateSelectionToolOverlayOnCanvasView: canvasView
            withColorMatchTolerance: colorMatchTolerance
            andModifierKeyFlags: modifierKeyFlags
            forDocument: ppDocument];

    [canvasView setMatchToolToleranceIndicatorRadius: mouseDistance];
}

- (void) mouseUpForDocument: (PPDocument *) ppDocument
            withCanvasView: (PPCanvasView *) canvasView
            currentPoint: (NSPoint) currentPoint
            mouseDownPoint: (NSPoint) mouseDownPoint
            modifierKeyFlags: (unsigned) modifierKeyFlags
{
    unsigned colorMatchTolerance;
    PPPixelMatchingMode pixelMatchingMode;
    PPSelectionMode selectionMode;

    [canvasView hideMatchToolToleranceIndicator];
    [canvasView clearSelectionToolOverlay];

    colorMatchTolerance =
        PPToolUtils_ColorMatchToleranceForMouseDistance(
                        PPGeometry_IntegerDistanceBetweenPoints(mouseDownPoint, currentPoint));

    pixelMatchingMode = PPToolUtils_PixelMatchingModeForModifierKeyFlags(modifierKeyFlags);

    selectionMode = PPToolUtils_SelectionModeForModifierKeyFlags(modifierKeyFlags);

    [ppDocument selectPixelsMatchingColorAtPoint: _mouseDownLocationInImage
                    colorMatchTolerance: colorMatchTolerance
                    pixelMatchingMode: pixelMatchingMode
                    selectionMode: selectionMode];
}

- (NSCursor *) cursor
{
    return [NSCursor ppMagicWandCursor];
}

- (unsigned) toolAttributeFlags
{
    return kWandToolAttributesMask;
}

#pragma mark Private methods

- (void) updateSelectionToolOverlayOnCanvasView: (PPCanvasView *) canvasView
            withColorMatchTolerance: (unsigned) colorMatchTolerance
            andModifierKeyFlags: (int) modifierKeyFlags
            forDocument: (PPDocument *) ppDocument
{
    PPPixelMatchingMode pixelMatchingMode;
    PPSelectionMode selectionMode;
    NSBitmapImageRep *matchMask, *intersectMask;
    bool matchMaskShouldIntersectSelectionMask;

    pixelMatchingMode = PPToolUtils_PixelMatchingModeForModifierKeyFlags(modifierKeyFlags);
    selectionMode = PPToolUtils_SelectionModeForModifierKeyFlags(modifierKeyFlags);

    if ((colorMatchTolerance == _lastColorMatchTolerance)
        && (pixelMatchingMode == _lastPixelMatchingMode)
        && (selectionMode == _lastSelectionMode))
    {
        return;
    }

    intersectMask =
            (selectionMode == kPPSelectionMode_Intersect) ? [ppDocument selectionMask] : nil;

    if ((selectionMode == kPPSelectionMode_Subtract)
            || (selectionMode == kPPSelectionMode_Intersect))
    {
        if (_needToSetupValueOfSelectionMaskCoversMouseDownPoint)
        {
            [self setupValueOfSelectionMaskCoversMouseDownPointWithDocument: ppDocument];
        }

        matchMaskShouldIntersectSelectionMask = _selectionMaskCoversMouseDownPoint;
    }
    else
    {
        matchMaskShouldIntersectSelectionMask = NO;
    }

    matchMask =
        [ppDocument maskForPixelsMatchingColorAtPoint: _mouseDownLocationInImage
                        colorMatchTolerance: colorMatchTolerance
                        pixelMatchingMode: pixelMatchingMode
                        shouldIntersectSelectionMask: matchMaskShouldIntersectSelectionMask];

    [canvasView setSelectionToolOverlayToMask: matchMask
                    maskBounds: [matchMask ppMaskBounds]
                    selectionMode: selectionMode
                    intersectMask: intersectMask];

    _lastColorMatchTolerance = colorMatchTolerance;
    _lastPixelMatchingMode = pixelMatchingMode;
    _lastSelectionMode = selectionMode;
}

- (void) setupValueOfSelectionMaskCoversMouseDownPointWithDocument: (PPDocument *) ppDocument
{
    _selectionMaskCoversMouseDownPoint =
                    [[ppDocument selectionMask] ppMaskCoversPoint: _mouseDownLocationInImage];

    _needToSetupValueOfSelectionMaskCoversMouseDownPoint = NO;
}

@end
