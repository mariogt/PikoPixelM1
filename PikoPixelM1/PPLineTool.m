/*
    PPLineTool.m

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

#import "PPLineTool.h"

#import "PPDocument.h"
#import "PPGeometry.h"
#import "NSCursor_PPUtilities.h"
#import "NSBezierPath_PPUtilities.h"


#define kLineToolAttributesMask     (0)


@interface PPLineTool (PrivateMethods)

- (void) beginNewSegment;
- (void) deleteLastSegment;

@end

@implementation PPLineTool

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

    _segmentStartPoint = _segmentEndPoint = currentPoint;
    _numSegments = 0;

    [self beginNewSegment];

    _modifierKeyDown_NewSegment =
                            (modifierKeyFlags & kModifierKeyMask_NewLineSegment) ? YES : NO;

    _modifierKeyDown_DeleteSegment =
                            (modifierKeyFlags & kModifierKeyMask_DeleteLineSegment) ? YES : NO;

#if PP_DEPLOYMENT_TARGET_ALLOWS_SYSTEM_INTERCEPTION_OF_COMMAND_KEY

    _commandKeyIsPressed = (modifierKeyFlags & NSCommandKeyMask) ? YES : NO;
    _disallowDeleteSegment = _commandKeyIsPressed;

#endif

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
    bool modifierKeyDown_NewSegment, modifierKeyDown_DeleteSegment, allowDeleteSegment,
            shouldFillDrawPath, shouldRedrawLine = NO, endPointDidMove;

    // new/delete segment modifiers

    modifierKeyDown_NewSegment =
                            (modifierKeyFlags & kModifierKeyMask_NewLineSegment) ? YES : NO;

    modifierKeyDown_DeleteSegment =
                            (modifierKeyFlags & kModifierKeyMask_DeleteLineSegment) ? YES : NO;

    allowDeleteSegment = (!modifierKeyDown_NewSegment) ? YES : NO;

#if PP_DEPLOYMENT_TARGET_ALLOWS_SYSTEM_INTERCEPTION_OF_COMMAND_KEY

    // some Linux/BSD desktop environments intercept the Command/Super key when it's pressed
    // by itself, so the user has to press Command+Option/Super+Alt in order to enable the
    // "Fill Drawn Shape" mode, however, this may interfere with the "Delete Segment" mode
    // (Option/Alt key); in order to avoid conflicts between the two modes, the "Delete Segment"
    // mode is disallowed as soon as the Command-key modifier flag's raised (the key may have
    // already been pressed for awhile, but doesn't pass through to PP until another modifier's
    // pressed), and "Delete Segment" is not allowed again until both the Command & Option keys
    // are up

    _commandKeyIsPressed = (modifierKeyFlags & NSCommandKeyMask) ? YES : NO;

    if (_commandKeyIsPressed)
    {
        _disallowDeleteSegment = YES;
    }
    else if (_disallowDeleteSegment && !modifierKeyDown_DeleteSegment)
    {
        _disallowDeleteSegment = NO;
    }

    if (_disallowDeleteSegment)
    {
        allowDeleteSegment = NO;
    }

#endif // PP_DEPLOYMENT_TARGET_ALLOWS_SYSTEM_INTERCEPTION_OF_COMMAND_KEY

    if (_modifierKeyDown_NewSegment != modifierKeyDown_NewSegment)
    {
        _modifierKeyDown_NewSegment = modifierKeyDown_NewSegment;

        if (_modifierKeyDown_NewSegment && !modifierKeyDown_DeleteSegment)
        {
            [self beginNewSegment];
        }
    }

    if (_modifierKeyDown_DeleteSegment != modifierKeyDown_DeleteSegment)
    {
        _modifierKeyDown_DeleteSegment = modifierKeyDown_DeleteSegment;

        if (_modifierKeyDown_DeleteSegment && allowDeleteSegment)
        {
            [self deleteLastSegment];

            shouldRedrawLine = YES;
        }
    }

    // fill shape modifier

    if (_numSegments > 1)
    {
        shouldFillDrawPath = (modifierKeyFlags & kModifierKeyMask_FillShape) ? YES : NO;
    }
    else
    {
        shouldFillDrawPath = NO;
    }

    if (_shouldFillDrawPath != shouldFillDrawPath)
    {
        _shouldFillDrawPath = shouldFillDrawPath;

        shouldRedrawLine = YES;
    }

    // lock aspect ratio modifier

    if (modifierKeyFlags & kModifierKeyMask_LockAspectRatio)
    {
        currentPoint =
                PPGeometry_NearestPointOnOneSixteenthSlope(_segmentStartPoint, currentPoint);
    }

    // update draw path's end point

    endPointDidMove = (!NSEqualPoints(_segmentEndPoint, currentPoint)) ? YES : NO;

    if (endPointDidMove)
    {
        [_drawPath ppSetLastLineEndPointToPixelAtPoint: currentPoint];

        _segmentEndPoint = currentPoint;

        shouldRedrawLine = YES;
    }

    // draw

    if (shouldRedrawLine)
    {
        [ppDocument undoCurrentDrawingAtNextDraw];
        [ppDocument drawBezierPath: _drawPath andFill: _shouldFillDrawPath];
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
    _numSegments = 0;
}

- (NSCursor *) cursor
{
    return [NSCursor ppLineToolCursor];
}

- (unsigned) toolAttributeFlags
{
    return kLineToolAttributesMask;
}

#pragma mark Private methods

- (void) beginNewSegment
{
    [_drawPath ppAppendZeroLengthLineAtLastLineEndPoint];
    _segmentStartPoint = _segmentEndPoint;
    _numSegments++;
}

- (void) deleteLastSegment
{
    NSPoint previousStartPoint;

    if (_numSegments <= 1)
    {
        return;
    }

    if ([_drawPath ppRemoveLastLineStartPointAndGetPreviousStartPoint: &previousStartPoint])
    {
        _segmentStartPoint = previousStartPoint;
        _numSegments--;
    }
}

@end
