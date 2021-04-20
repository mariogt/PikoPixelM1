/*
    PPColorRampTool.m

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

#import "PPColorRampTool.h"

#import "PPDocument.h"
#import "PPCanvasView.h"
#import "NSCursor_PPUtilities.h"


#define kColorRampToolAttributesMask                                            \
            (kPPToolAttributeMask_RequiresPointsCroppedToCanvasBounds           \
            | kPPToolAttributeMask_MatchCanvasDisplayModeToOperationTarget)


@interface PPColorRampTool (PrivateMethods)

- (void) clearStartColor;

@end

@implementation PPColorRampTool

- (void) mouseDownForDocument: (PPDocument *) ppDocument
            withCanvasView: (PPCanvasView *) canvasView
            currentPoint: (NSPoint) currentPoint
            modifierKeyFlags: (unsigned) modifierKeyFlags
{
    NSRect rampBounds;
    NSBitmapImageRep *drawMask;

    [self clearStartColor];

    _startColor = [[ppDocument colorAtPoint: currentPoint
                                inTarget: [ppDocument layerOperationTarget]]
                            retain];

    [ppDocument beginDrawingWithPenMode: kPPPenMode_Fill];

    [ppDocument drawColorRampWithStartingColor: _startColor
                fromPoint: currentPoint
                toPoint: currentPoint
                returnedRampBounds: &rampBounds
                returnedDrawMask: &drawMask];

    [canvasView setColorRampToolOverlayToMask: drawMask
                maskBounds: rampBounds];
}

- (void) mouseDraggedOrModifierKeysChangedForDocument: (PPDocument *) ppDocument
            withCanvasView: (PPCanvasView *) canvasView
            currentPoint: (NSPoint) currentPoint
            lastPoint: (NSPoint) lastPoint
            mouseDownPoint: (NSPoint) mouseDownPoint
            modifierKeyFlags: (unsigned) modifierKeyFlags
{
    NSRect rampBounds;
    NSBitmapImageRep *drawMask;

    if (NSEqualPoints(currentPoint, lastPoint))
    {
        return;
    }

    [ppDocument undoCurrentDrawingAtNextDraw];

    [ppDocument drawColorRampWithStartingColor: _startColor
                fromPoint: mouseDownPoint
                toPoint: currentPoint
                returnedRampBounds: &rampBounds
                returnedDrawMask: &drawMask];

    [canvasView setColorRampToolOverlayToMask: drawMask
                maskBounds: rampBounds];
}

- (void) mouseUpForDocument: (PPDocument *) ppDocument
            withCanvasView: (PPCanvasView *) canvasView
            currentPoint: (NSPoint) currentPoint
            mouseDownPoint: (NSPoint) mouseDownPoint
            modifierKeyFlags: (unsigned) modifierKeyFlags
{
    [ppDocument finishDrawing];

    [canvasView clearColorRampToolOverlay];

    [self clearStartColor];
}

- (NSCursor *) cursor
{
    return [NSCursor ppColorRampToolCursor];
}

- (unsigned) toolAttributeFlags
{
    return kColorRampToolAttributesMask;
}

#pragma mark Private methods

- (void) clearStartColor
{
    if (!_startColor)
        return;

    [_startColor release];
    _startColor = nil;
}

@end
