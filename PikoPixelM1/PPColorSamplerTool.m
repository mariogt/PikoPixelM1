/*
    PPColorSamplerTool.m

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

#import "PPColorSamplerTool.h"

#import "PPDocument.h"
#import "NSCursor_PPUtilities.h"


#define kColorSamplerToolAttributesMask                                     \
            (kPPToolAttributeMask_RequiresPointsCroppedToCanvasBounds       \
            | kPPToolAttributeMask_MatchCanvasDisplayModeToOperationTarget)


@implementation PPColorSamplerTool

- (void) mouseDownForDocument: (PPDocument *) ppDocument
            withCanvasView: (PPCanvasView *) canvasView
            currentPoint: (NSPoint) currentPoint
            modifierKeyFlags: (unsigned) modifierKeyFlags
{
    NSColor *fillColor;

    _initialFillColor = [[ppDocument fillColor] retain];

    fillColor = [ppDocument colorAtPoint: currentPoint
                            inTarget: [ppDocument layerOperationTarget]];

    [ppDocument setFillColorWithoutUndoRegistration: fillColor];
}

- (void) mouseDraggedOrModifierKeysChangedForDocument: (PPDocument *) ppDocument
            withCanvasView: (PPCanvasView *) canvasView
            currentPoint: (NSPoint) currentPoint
            lastPoint: (NSPoint) lastPoint
            mouseDownPoint: (NSPoint) mouseDownPoint
            modifierKeyFlags: (unsigned) modifierKeyFlags
{
    NSColor *fillColor;

    if (NSEqualPoints(currentPoint, lastPoint))
    {
        return;
    }

    fillColor = [ppDocument colorAtPoint: currentPoint
                            inTarget: [ppDocument layerOperationTarget]];

    [ppDocument setFillColorWithoutUndoRegistration: fillColor];
}

- (void) mouseUpForDocument: (PPDocument *) ppDocument
            withCanvasView: (PPCanvasView *) canvasView
            currentPoint: (NSPoint) currentPoint
            mouseDownPoint: (NSPoint) mouseDownPoint
            modifierKeyFlags: (unsigned) modifierKeyFlags
{
    NSColor *fillColor;

    fillColor = [ppDocument colorAtPoint: currentPoint
                            inTarget: [ppDocument layerOperationTarget]];

    // restore the initial fill color before setting the new fill color so the undo manager can
    // register the correct previous color
    [ppDocument setFillColorWithoutUndoRegistration: _initialFillColor];

    [ppDocument setFillColor: fillColor];

    [_initialFillColor release];
    _initialFillColor = nil;
}

- (NSCursor *) cursor
{
    return [NSCursor ppColorSamplerToolCursor];
}

- (unsigned) toolAttributeFlags
{
    return kColorSamplerToolAttributesMask;
}

@end
