/*
    PPOvalTool.m

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

#import "PPOvalTool.h"

#import "PPDocument.h"
#import "PPGeometry.h"
#import "NSCursor_PPUtilities.h"


#define kOvalToolAttributesMask     (0)


@implementation PPOvalTool : PPTool

- (void) mouseDownForDocument: (PPDocument *) ppDocument
            withCanvasView: (PPCanvasView *) canvasView
            currentPoint: (NSPoint) currentPoint
            modifierKeyFlags: (unsigned) modifierKeyFlags
{
    [ppDocument beginDrawingWithPenMode: kPPPenMode_Fill];

    [ppDocument drawPixelAtPoint: currentPoint];
}

- (void) mouseDraggedOrModifierKeysChangedForDocument: (PPDocument *) ppDocument
            withCanvasView: (PPCanvasView *) canvasView
            currentPoint: (NSPoint) currentPoint
            lastPoint: (NSPoint) lastPoint
            mouseDownPoint: (NSPoint) mouseDownPoint
            modifierKeyFlags: (unsigned) modifierKeyFlags
{
    NSRect rect;
    bool shouldFillOval;

    if (modifierKeyFlags & kModifierKeyMask_LockAspectRatio)
    {
        currentPoint = PPGeometry_FarthestPointOnDiagonal(mouseDownPoint, currentPoint);
    }

    if (modifierKeyFlags & kModifierKeyMask_CenterShapeAtMouseDown)
    {
        rect = PPGeometry_PixelBoundsWithCenterAndCornerPoint(mouseDownPoint, currentPoint);
    }
    else
    {
        rect = PPGeometry_PixelBoundsWithCornerPoints(mouseDownPoint, currentPoint);
    }

    shouldFillOval = (modifierKeyFlags & kModifierKeyMask_FillShape) ? YES : NO;

    [ppDocument undoCurrentDrawingAtNextDraw];
    [ppDocument drawOvalInRect: rect andFill: shouldFillOval];
}

- (void) mouseUpForDocument: (PPDocument *) ppDocument
            withCanvasView: (PPCanvasView *) canvasView
            currentPoint: (NSPoint) currentPoint
            mouseDownPoint: (NSPoint) mouseDownPoint
            modifierKeyFlags: (unsigned) modifierKeyFlags
{
    [ppDocument finishDrawing];
}

- (NSCursor *) cursor
{
    return [NSCursor ppOvalToolCursor];
}

- (unsigned) toolAttributeFlags
{
    return kOvalToolAttributesMask;
}

@end
