/*
    PPEraserTool.m

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

#import "PPEraserTool.h"

#import "PPDocument.h"
#import "PPCanvasView.h"
#import "NSCursor_PPUtilities.h"
#import "NSBezierPath_PPUtilities.h"


#define kEraserToolAttributesMask                                               \
            (kPPToolAttributeMask_RequiresPointsCroppedToCanvasBounds           \
            | kPPToolAttributeMask_DisableSkippingOfMouseDraggedEvents          \
            | kPPToolAttributeMask_DisableAutoscrolling)


@implementation PPEraserTool

- init
{
    self = [super init];

    if (!self)
        goto ERROR;

    _erasePath = [[NSBezierPath bezierPath] retain];

    if (!_erasePath)
        goto ERROR;

    return self;

ERROR:
    [self release];

    return nil;
}

- (void) dealloc
{
    [_erasePath release];

    [super dealloc];
}

- (void) mouseDownForDocument: (PPDocument *) ppDocument
            withCanvasView: (PPCanvasView *) canvasView
            currentPoint: (NSPoint) currentPoint
            modifierKeyFlags: (unsigned) modifierKeyFlags
{
    NSBitmapImageRep *eraseMask;
    NSRect eraseBounds;

    [_erasePath removeAllPoints];
    [_erasePath ppAppendSinglePixelLineAtPoint: currentPoint];

    [ppDocument beginDrawingWithPenMode: kPPPenMode_Erase];
    [ppDocument drawPixelAtPoint: currentPoint];

    if ([ppDocument getInteractiveEraseMask: &eraseMask andBounds: &eraseBounds])
    {
        [canvasView setEraserToolOverlayToMask: eraseMask maskBounds: eraseBounds];
    }

    _shouldFillErasePath = NO;
}

- (void) mouseDraggedOrModifierKeysChangedForDocument: (PPDocument *) ppDocument
            withCanvasView: (PPCanvasView *) canvasView
            currentPoint: (NSPoint) currentPoint
            lastPoint: (NSPoint) lastPoint
            mouseDownPoint: (NSPoint) mouseDownPoint
            modifierKeyFlags: (unsigned) modifierKeyFlags
{
    bool shouldFillErasePath, shouldDrawAsBezierPath, mouseDidMoveToNewPoint;
    NSBitmapImageRep *eraseMask;
    NSRect eraseBounds;

    shouldFillErasePath = (modifierKeyFlags & kModifierKeyMask_FillShape) ? YES : NO;

    if (_shouldFillErasePath != shouldFillErasePath)
    {
        _shouldFillErasePath = shouldFillErasePath;
        shouldDrawAsBezierPath = YES;
    }
    else
    {
        shouldDrawAsBezierPath = _shouldFillErasePath;
    }

    mouseDidMoveToNewPoint = (!NSEqualPoints(lastPoint, currentPoint)) ? YES : NO;

    if (mouseDidMoveToNewPoint)
    {
        [_erasePath ppLineToPixelAtPoint: currentPoint];
    }

    if (shouldDrawAsBezierPath)
    {
        [ppDocument undoCurrentDrawingAtNextDraw];
        [ppDocument drawBezierPath: _erasePath andFill: _shouldFillErasePath];
    }
    else if (mouseDidMoveToNewPoint)
    {
        [ppDocument drawLineFromPoint: lastPoint toPoint: currentPoint];
    }

    if ([ppDocument getInteractiveEraseMask: &eraseMask andBounds: &eraseBounds])
    {
        [canvasView setEraserToolOverlayToMask: eraseMask maskBounds: eraseBounds];
    }
}

- (void) mouseUpForDocument: (PPDocument *) ppDocument
            withCanvasView: (PPCanvasView *) canvasView
            currentPoint: (NSPoint) currentPoint
            mouseDownPoint: (NSPoint) mouseDownPoint
            modifierKeyFlags: (unsigned) modifierKeyFlags
{
    [ppDocument finishDrawing];

    [_erasePath removeAllPoints];

    [canvasView clearEraserToolOverlay];
}

- (NSCursor *) cursor
{
    return [NSCursor ppEraserCursor];
}

- (unsigned) toolAttributeFlags
{
    return kEraserToolAttributesMask;
}

@end
