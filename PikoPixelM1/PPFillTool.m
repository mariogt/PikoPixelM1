/*
    PPFillTool.m

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

#import "PPFillTool.h"

#import "PPDocument.h"
#import "PPCanvasView.h"
#import "PPGeometry.h"
#import "PPToolUtilities.h"
#import "NSCursor_PPUtilities.h"


#define kFillToolAttributesMask                                                     \
            (kPPToolAttributeMask_RequiresPointsInViewCoordinates                   \
            | kPPToolAttributeMask_DisableAutoscrolling                             \
            | kPPToolAttributeMask_MatchCanvasDisplayModeToOperationTarget)


@implementation PPFillTool

- (void) mouseDownForDocument: (PPDocument *) ppDocument
            withCanvasView: (PPCanvasView *) canvasView
            currentPoint: (NSPoint) currentPoint
            modifierKeyFlags: (unsigned) modifierKeyFlags
{
    unsigned colorMatchTolerance;
    PPPixelMatchingMode pixelMatchingMode;
    NSBitmapImageRep *matchMask;
    NSRect matchMaskBounds;

    // tool receives points in view coordinates, must convert to get image coordinates
    _mouseDownLocationInImage = [canvasView imagePointFromViewPoint: currentPoint
                                                clippedToCanvasBounds: YES];

    colorMatchTolerance = 0;
    pixelMatchingMode = PPToolUtils_PixelMatchingModeForModifierKeyFlags(modifierKeyFlags);

    [ppDocument beginDrawingWithPenMode: kPPPenMode_Fill];

    [ppDocument fillPixelsMatchingColorAtPoint: _mouseDownLocationInImage
                    colorMatchTolerance: colorMatchTolerance
                    pixelMatchingMode: pixelMatchingMode
                    returnedMatchMask: &matchMask
                    returnedMatchMaskBounds: &matchMaskBounds];

    [canvasView beginFillToolOverlayForOperationTarget: [ppDocument layerOperationTarget]
                    fillColor: [ppDocument fillColor]];

    [canvasView setFillToolOverlayToMask: matchMask maskBounds: matchMaskBounds];

    [canvasView showMatchToolToleranceIndicatorAtViewPoint: currentPoint];

    _lastColorMatchTolerance = colorMatchTolerance;
    _lastPixelMatchingMode = pixelMatchingMode;
}

- (void) mouseDraggedOrModifierKeysChangedForDocument: (PPDocument *) ppDocument
            withCanvasView: (PPCanvasView *) canvasView
            currentPoint: (NSPoint) currentPoint
            lastPoint: (NSPoint) lastPoint
            mouseDownPoint: (NSPoint) mouseDownPoint
            modifierKeyFlags: (unsigned) modifierKeyFlags
{
    unsigned mouseDistance, colorMatchTolerance;
    PPPixelMatchingMode pixelMatchingMode;
    NSBitmapImageRep *matchMask;
    NSRect matchMaskBounds;

    mouseDistance = PPGeometry_IntegerDistanceBetweenPoints(mouseDownPoint, currentPoint);
    colorMatchTolerance = PPToolUtils_ColorMatchToleranceForMouseDistance(mouseDistance);

    pixelMatchingMode = PPToolUtils_PixelMatchingModeForModifierKeyFlags(modifierKeyFlags);

    if ((colorMatchTolerance != _lastColorMatchTolerance)
        || (pixelMatchingMode != _lastPixelMatchingMode))
    {
        [ppDocument undoCurrentDrawingAtNextDraw];

        [ppDocument fillPixelsMatchingColorAtPoint: _mouseDownLocationInImage
                        colorMatchTolerance: colorMatchTolerance
                        pixelMatchingMode: pixelMatchingMode
                        returnedMatchMask: &matchMask
                        returnedMatchMaskBounds: &matchMaskBounds];

        [canvasView setFillToolOverlayToMask: matchMask maskBounds: matchMaskBounds];

        _lastColorMatchTolerance = colorMatchTolerance;
        _lastPixelMatchingMode = pixelMatchingMode;
    }

    [canvasView setMatchToolToleranceIndicatorRadius: mouseDistance];
}

- (void) mouseUpForDocument: (PPDocument *) ppDocument
            withCanvasView: (PPCanvasView *) canvasView
            currentPoint: (NSPoint) currentPoint
            mouseDownPoint: (NSPoint) mouseDownPoint
            modifierKeyFlags: (unsigned) modifierKeyFlags
{
    [canvasView hideMatchToolToleranceIndicator];
    [canvasView endFillToolOverlay];

    [ppDocument finishDrawing];
}

- (NSCursor *) cursor
{
    return [NSCursor ppFillToolCursor];
}

- (unsigned) toolAttributeFlags
{
    return kFillToolAttributesMask;
}

@end
