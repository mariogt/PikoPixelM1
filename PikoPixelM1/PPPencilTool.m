/*
    PPPencilTool.m

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

#import "PPPencilTool.h"

#import "PPDocument.h"
#import "NSCursor_PPUtilities.h"
#import "NSBezierPath_PPUtilities.h"


#define kPencilToolAttributesMask                                               \
            (kPPToolAttributeMask_RequiresPointsCroppedToCanvasBounds           \
            | kPPToolAttributeMask_DisableSkippingOfMouseDraggedEvents          \
            | kPPToolAttributeMask_DisableAutoscrolling)


@implementation PPPencilTool

- init
{
    self = [super init];

    if (!self)
        goto ERROR;

    _drawPath = [[NSBezierPath bezierPath] retain];

    if (!_drawPath)
        goto ERROR;

    return self;

ERROR:
    [self release];

    return nil;
}

- (void) dealloc
{
    [_drawPath release];

    [super dealloc];
}

- (void) mouseDownForDocument: (PPDocument *) ppDocument
            withCanvasView: (PPCanvasView *) canvasView
            currentPoint: (NSPoint) currentPoint
            modifierKeyFlags: (unsigned) modifierKeyFlags
{
    [_drawPath removeAllPoints];
    [_drawPath ppAppendSinglePixelLineAtPoint: currentPoint];

    _isDrawingLineSegment = NO;
    _shouldFillDrawPath = NO;

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
    bool isDrawingLineSegment, shouldFillDrawPath, shouldDrawAsBezierPath,
            mouseDidMoveToNewPoint;

    isDrawingLineSegment = (modifierKeyFlags & kModifierKeyMask_DrawLineSegment) ? YES : NO;

    if (_isDrawingLineSegment != isDrawingLineSegment)
    {
        _isDrawingLineSegment = isDrawingLineSegment;

        if (_isDrawingLineSegment)
        {
            // began drawing line segment, so append zero-length line element - its endpoint
            // will be updated by -[NSBezierPath ppSetLastLineEndPointToPixelAtPoint:] as
            // mouse moves
            [_drawPath ppAppendZeroLengthLineAtLastLineEndPoint];
        }
    }

    shouldFillDrawPath = (modifierKeyFlags & kModifierKeyMask_FillShape) ? YES : NO;

    if (_shouldFillDrawPath != shouldFillDrawPath)
    {
        _shouldFillDrawPath = shouldFillDrawPath;
        shouldDrawAsBezierPath = YES;
    }
    else
    {
        shouldDrawAsBezierPath = _shouldFillDrawPath;
    }

    mouseDidMoveToNewPoint = (!NSEqualPoints(lastPoint, currentPoint)) ? YES : NO;

    if (mouseDidMoveToNewPoint)
    {
        if (_isDrawingLineSegment)
        {
            [_drawPath ppSetLastLineEndPointToPixelAtPoint: currentPoint];
            shouldDrawAsBezierPath = YES;
        }
        else
        {
            [_drawPath ppLineToPixelAtPoint: currentPoint];
        }
    }

    if (shouldDrawAsBezierPath)
    {
        [ppDocument undoCurrentDrawingAtNextDraw];
        [ppDocument drawBezierPath: _drawPath andFill: _shouldFillDrawPath];
    }
    else if (mouseDidMoveToNewPoint)
    {
        [ppDocument drawLineFromPoint: lastPoint toPoint: currentPoint];
    }
}

- (void) mouseUpForDocument: (PPDocument *) ppDocument
            withCanvasView: (PPCanvasView *) canvasView
            currentPoint: (NSPoint) currentPoint
            mouseDownPoint: (NSPoint) mouseDownPoint
            modifierKeyFlags: (unsigned) modifierKeyFlags
{
    [ppDocument finishDrawing];

    [_drawPath removeAllPoints];
}

- (NSCursor *) cursor
{
    return [NSCursor ppPencilCursor];
}

- (unsigned) toolAttributeFlags
{
    return kPencilToolAttributesMask;
}

@end
