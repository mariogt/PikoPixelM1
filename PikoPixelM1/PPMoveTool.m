/*
    PPMoveTool.m

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

#import "PPMoveTool.h"

#import "PPDocument.h"
#import "PPDocumentWindowController.h"
#import "PPToolUtilities.h"
#import "PPCanvasView.h"
#import "PPGeometry.h"
#import "NSCursor_PPUtilities.h"


#define kMoveToolAttributesMask                                                         \
            (kPPToolAttributeMask_CursorDependsOnModifierKeys                           \
            | kPPToolAttributeMask_MatchCanvasDisplayModeToOperationTarget              \
            | kPPToolAttributeMask_DisallowMatchingCanvasDisplayModeToDrawLayerTarget)


@implementation PPMoveTool

#pragma mark PPTool overrides

- (void) mouseDownForDocument: (PPDocument *) ppDocument
            withCanvasView: (PPCanvasView *) canvasView
            currentPoint: (NSPoint) currentPoint
            modifierKeyFlags: (unsigned) modifierKeyFlags
{
    PPMoveOperationType moveType;

    moveType = PPToolUtils_InteractiveMoveTypeForModifierKeyFlags(modifierKeyFlags);

    [ppDocument beginInteractiveMoveWithTarget: [ppDocument layerOperationTarget]
                canvasDisplayMode: [[ppDocument ppDocumentWindowController] canvasDisplayMode]
                moveType: moveType];

    if (moveType == kPPMoveOperationType_SelectionOutlineOnly)
    {
        [canvasView setSelectionToolOverlayToMask: [ppDocument selectionMask]
                    maskBounds: [ppDocument selectionBounds]
                    selectionMode: kPPSelectionMode_Replace
                    intersectMask: nil];
    }

    _lastMoveType = moveType;
}

- (void) mouseDraggedOrModifierKeysChangedForDocument: (PPDocument *) ppDocument
            withCanvasView: (PPCanvasView *) canvasView
            currentPoint: (NSPoint) currentPoint
            lastPoint: (NSPoint) lastPoint
            mouseDownPoint: (NSPoint) mouseDownPoint
            modifierKeyFlags: (unsigned) modifierKeyFlags
{
    NSPoint moveOffset;
    PPMoveOperationType moveType;

    moveOffset = PPGeometry_PointDifference(currentPoint, mouseDownPoint);
    moveType = PPToolUtils_InteractiveMoveTypeForModifierKeyFlags(modifierKeyFlags);

    [ppDocument setInteractiveMoveOffset: moveOffset andMoveType: moveType];

    if (moveType == kPPMoveOperationType_SelectionOutlineOnly)
    {
        [canvasView setSelectionToolOverlayToMask: [ppDocument selectionMask]
                    maskBounds: [ppDocument selectionBounds]
                    selectionMode: kPPSelectionMode_Replace
                    intersectMask: nil];
    }
    else if (_lastMoveType == kPPMoveOperationType_SelectionOutlineOnly)
    {
        [canvasView clearSelectionToolOverlay];
    }

    _lastMoveType = moveType;
}

- (void) mouseUpForDocument: (PPDocument *) ppDocument
            withCanvasView: (PPCanvasView *) canvasView
            currentPoint: (NSPoint) currentPoint
            mouseDownPoint: (NSPoint) mouseDownPoint
            modifierKeyFlags: (unsigned) modifierKeyFlags
{
    if (_lastMoveType == kPPMoveOperationType_SelectionOutlineOnly)
    {
        [canvasView clearSelectionToolOverlay];
    }

    [ppDocument finishInteractiveMove];
}

- (NSCursor *) cursor
{
    return [NSCursor ppMoveToolCursor];
}

- (NSCursor *) cursorForModifierKeyFlags: (unsigned) modifierKeyFlags
{
    PPMoveOperationType moveType;

    moveType = PPToolUtils_InteractiveMoveTypeForModifierKeyFlags(modifierKeyFlags);

    if (moveType == kPPMoveOperationType_SelectionOutlineOnly)
    {
        return [NSCursor ppMoveSelectionOutlineToolCursor];
    }

    return [NSCursor ppMoveToolCursor];
}

- (unsigned) toolAttributeFlags
{
    return kMoveToolAttributesMask;
}

@end
