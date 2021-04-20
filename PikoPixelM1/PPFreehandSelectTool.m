/*
    PPFreehandSelectTool.m

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

#import "PPFreehandSelectTool.h"

#import "PPDocument.h"
#import "PPCanvasView.h"
#import "PPToolUtilities.h"
#import "PPGeometry.h"
#import "NSCursor_PPUtilities.h"
#import "NSBezierPath_PPUtilities.h"


#define kFreehandSelectToolAttributesMask                                   \
            (kPPToolAttributeMask_RequiresPointsCroppedToCanvasBounds       \
            | kPPToolAttributeMask_DisableSkippingOfMouseDraggedEvents)


@interface PPFreehandSelectTool (PrivateMethods)

- (void) updateSelectionToolOverlayPathOnCanvasView: (PPCanvasView *) canvasView
            withModifierKeyFlags: (int) modifierKeyFlags
            forDocument: (PPDocument *) ppDocument;

@end

@implementation PPFreehandSelectTool

- init
{
    self = [super init];

    if (!self)
        goto ERROR;

    _toolPath = [[NSBezierPath bezierPath] retain];

    if (!_toolPath)
        goto ERROR;

    return self;

ERROR:
    [self release];

    return nil;
}

- (void) dealloc
{
    [_toolPath release];

    [super dealloc];
}

- (void) mouseDownForDocument: (PPDocument *) ppDocument
            withCanvasView: (PPCanvasView *) canvasView
            currentPoint: (NSPoint) currentPoint
            modifierKeyFlags: (unsigned) modifierKeyFlags
{
    [_toolPath removeAllPoints];
    [_toolPath ppAppendSinglePixelLineAtPoint: currentPoint];

    [self updateSelectionToolOverlayPathOnCanvasView: canvasView
            withModifierKeyFlags: modifierKeyFlags
            forDocument: ppDocument];
}

- (void) mouseDraggedOrModifierKeysChangedForDocument: (PPDocument *) ppDocument
            withCanvasView: (PPCanvasView *) canvasView
            currentPoint: (NSPoint) currentPoint
            lastPoint: (NSPoint) lastPoint
            mouseDownPoint: (NSPoint) mouseDownPoint
            modifierKeyFlags: (unsigned) modifierKeyFlags
{
    [_toolPath ppLineToPixelAtPoint: currentPoint];

    [self updateSelectionToolOverlayPathOnCanvasView: canvasView
            withModifierKeyFlags: modifierKeyFlags
            forDocument: ppDocument];
}

- (void) mouseUpForDocument: (PPDocument *) ppDocument
            withCanvasView: (PPCanvasView *) canvasView
            currentPoint: (NSPoint) currentPoint
            mouseDownPoint: (NSPoint) mouseDownPoint
            modifierKeyFlags: (unsigned) modifierKeyFlags
{
    PPSelectionMode selectionMode;

    [canvasView clearSelectionToolOverlay];

    selectionMode = PPToolUtils_SelectionModeForModifierKeyFlags(modifierKeyFlags);

    if ((selectionMode == kPPSelectionMode_Replace)
        && !PPGeometry_RectCoversMultiplePoints([_toolPath bounds]))
    {
        [ppDocument deselectAll];
        return;
    }

    [ppDocument selectPath: _toolPath selectionMode: selectionMode];

    [_toolPath removeAllPoints];
}

- (NSCursor *) cursor
{
    return [NSCursor ppFreehandSelectCursor];
}

- (unsigned) toolAttributeFlags
{
    return kFreehandSelectToolAttributesMask;
}

#pragma mark Private methods

- (void) updateSelectionToolOverlayPathOnCanvasView: (PPCanvasView *) canvasView
            withModifierKeyFlags: (int) modifierKeyFlags
            forDocument: (PPDocument *) ppDocument
{
    PPSelectionMode selectionMode;
    NSBitmapImageRep *intersectMask;

    selectionMode = PPToolUtils_SelectionModeForModifierKeyFlags(modifierKeyFlags);

    intersectMask =
            (selectionMode == kPPSelectionMode_Intersect) ? [ppDocument selectionMask] : nil;

    [canvasView setSelectionToolOverlayToPath: _toolPath
                    selectionMode: selectionMode
                    intersectMask: intersectMask];
}

@end
