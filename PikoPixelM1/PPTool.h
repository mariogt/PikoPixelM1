/*
    PPTool.h

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

#import <Cocoa/Cocoa.h>
#import "PPModifierKeyMasks.h"


#define kPPToolAttributeMask_RequiresPointsInViewCoordinates                    (1 << 0)
#define kPPToolAttributeMask_RequiresPointsCroppedToCanvasBounds                (1 << 1)
#define kPPToolAttributeMask_DisableSkippingOfMouseDraggedEvents                (1 << 2)
#define kPPToolAttributeMask_DisableAutoscrolling                               (1 << 3)
#define kPPToolAttributeMask_CursorDependsOnModifierKeys                        (1 << 4)
#define kPPToolAttributeMask_MatchCanvasDisplayModeToOperationTarget            (1 << 5)
#define kPPToolAttributeMask_DisallowMatchingCanvasDisplayModeToDrawLayerTarget (1 << 6)


@class PPDocument, PPCanvasView;

@interface PPTool : NSObject
{
}

+ tool;

- (void) mouseDownForDocument: (PPDocument *) ppDocument
            withCanvasView: (PPCanvasView *) canvasView
            currentPoint: (NSPoint) currentPoint
            modifierKeyFlags: (unsigned) modifierKeyFlags;

- (void) mouseDraggedOrModifierKeysChangedForDocument: (PPDocument *) ppDocument
            withCanvasView: (PPCanvasView *) canvasView
            currentPoint: (NSPoint) currentPoint
            lastPoint: (NSPoint) lastPoint
            mouseDownPoint: (NSPoint) mouseDownPoint
            modifierKeyFlags: (unsigned) modifierKeyFlags;

- (void) mouseUpForDocument: (PPDocument *) ppDocument
            withCanvasView: (PPCanvasView *) canvasView
            currentPoint: (NSPoint) currentPoint
            mouseDownPoint: (NSPoint) mouseDownPoint
            modifierKeyFlags: (unsigned) modifierKeyFlags;

- (NSCursor *) cursor;

// cursorForModifierKeyFlags: - for use when _CursorDependsOnModifierKeys is set in the
// toolAttributeFlags; default implementation just passes through to cursor method
- (NSCursor *) cursorForModifierKeyFlags: (unsigned) modifierKeyFlags;

- (unsigned) toolAttributeFlags;

@end
