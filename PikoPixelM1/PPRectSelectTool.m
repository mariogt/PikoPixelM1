/*
    PPRectSelectTool.m

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

#import "PPRectSelectTool.h"

#import "PPDocument.h"
#import "PPCanvasView.h"
#import "PPGeometry.h"
#import "PPGridPattern.h"
#import "PPToolUtilities.h"
#import "NSCursor_PPUtilities.h"


#define kRectSelectToolAttributesMask           (0)


@interface PPRectSelectTool (PrivateMethods)

- (NSRect) selectionRectForMouseDownPoint: (NSPoint) mouseDownPoint
            andCurrentPoint: (NSPoint) currentPoint;

- (void) updateSelectionToolOverlayOnCanvasView: (PPCanvasView *) canvasView
            withSelectionRect: (NSRect) selectionRect
            andModifierKeyFlags: (int) modifierKeyFlags
            forDocument: (PPDocument *) ppDocument;

- (void) forceGridGuidelinesEnabled: (bool) forceGridGuidelinesEnabled
            onCanvasView: (PPCanvasView *) canvasView
            withDocument: (PPDocument *) ppDocument;

- (bool) shouldClearDocumentSelectionWithSelectionRect: (NSRect) selectionRect
            andSelectionMode: (PPSelectionMode) selectionMode;

@end

@implementation PPRectSelectTool

- (void) mouseDownForDocument: (PPDocument *) ppDocument
            withCanvasView: (PPCanvasView *) canvasView
            currentPoint: (NSPoint) currentPoint
            modifierKeyFlags: (unsigned) modifierKeyFlags
{
    NSRect selectionRect;

    _canvasBounds = PPGeometry_OriginRectOfSize([ppDocument canvasSize]);

    _rectMoveOffset = NSZeroPoint;

    _shouldSnapSelectionToGridGuidelines = NO;

    selectionRect = [self selectionRectForMouseDownPoint: currentPoint
                            andCurrentPoint: currentPoint];

    [self updateSelectionToolOverlayOnCanvasView: canvasView
            withSelectionRect: selectionRect
            andModifierKeyFlags: modifierKeyFlags
            forDocument: ppDocument];
}

- (void) mouseDraggedOrModifierKeysChangedForDocument: (PPDocument *) ppDocument
            withCanvasView: (PPCanvasView *) canvasView
            currentPoint: (NSPoint) currentPoint
            lastPoint: (NSPoint) lastPoint
            mouseDownPoint: (NSPoint) mouseDownPoint
            modifierKeyFlags: (unsigned) modifierKeyFlags
{
    NSRect selectionRect;

    if (modifierKeyFlags & kModifierKeyMask_MoveRectSelectionOutline)
    {
        _rectMoveOffset =
                PPGeometry_PointSum(_rectMoveOffset,
                                        PPGeometry_PointDifference(currentPoint, lastPoint));
    }

    selectionRect = [self selectionRectForMouseDownPoint: mouseDownPoint
                            andCurrentPoint: currentPoint];

    [self updateSelectionToolOverlayOnCanvasView: canvasView
            withSelectionRect: selectionRect
            andModifierKeyFlags: modifierKeyFlags
            forDocument: ppDocument];
}

- (void) mouseUpForDocument: (PPDocument *) ppDocument
            withCanvasView: (PPCanvasView *) canvasView
            currentPoint: (NSPoint) currentPoint
            mouseDownPoint: (NSPoint) mouseDownPoint
            modifierKeyFlags: (unsigned) modifierKeyFlags
{
    NSRect selectionRect;
    PPSelectionMode selectionMode;

    [canvasView clearSelectionToolOverlay];

    selectionRect = [self selectionRectForMouseDownPoint: mouseDownPoint
                            andCurrentPoint: currentPoint];

    if (_shouldSnapSelectionToGridGuidelines)
    {
        selectionRect = [ppDocument gridGuidelineBoundsCoveredByRect: selectionRect];

        [self forceGridGuidelinesEnabled: NO onCanvasView: canvasView withDocument: ppDocument];
    }

    selectionMode = PPToolUtils_SelectionModeForModifierKeyFlags(modifierKeyFlags);

    if ([self shouldClearDocumentSelectionWithSelectionRect: selectionRect
                andSelectionMode: selectionMode])
    {
        [ppDocument deselectAll];
        return;
    }

    if (!NSIsEmptyRect(selectionRect))
    {
        [ppDocument selectRect: selectionRect selectionMode: selectionMode];
    }
}

- (NSCursor *) cursor
{
    return [NSCursor ppRectSelectCursor];
}

- (unsigned) toolAttributeFlags
{
    return kRectSelectToolAttributesMask;
}

#pragma mark Private methods

- (NSRect) selectionRectForMouseDownPoint: (NSPoint) mouseDownPoint
            andCurrentPoint: (NSPoint) currentPoint
{
    NSPoint pinnedCornerPoint;
    NSRect selectionRect;

    pinnedCornerPoint = PPGeometry_PointSum(mouseDownPoint, _rectMoveOffset);

    selectionRect = PPGeometry_PixelBoundsWithCornerPoints(pinnedCornerPoint, currentPoint);

    return NSIntersectionRect(selectionRect, _canvasBounds);
}

- (void) updateSelectionToolOverlayOnCanvasView: (PPCanvasView *) canvasView
            withSelectionRect: (NSRect) selectionRect
            andModifierKeyFlags: (int) modifierKeyFlags
            forDocument: (PPDocument *) ppDocument
{
    PPSelectionMode selectionMode;
    NSBitmapImageRep *intersectMask;
    NSRect toolPathRect;
    bool shouldSnapSelectionToGridGuidelines;

    selectionMode = PPToolUtils_SelectionModeForModifierKeyFlags(modifierKeyFlags);

    intersectMask =
            (selectionMode == kPPSelectionMode_Intersect) ? [ppDocument selectionMask] : nil;

    shouldSnapSelectionToGridGuidelines =
                    (modifierKeyFlags & kModifierKeyMask_SnapSelectionToGuidelines) ? YES : NO;

    if (_shouldSnapSelectionToGridGuidelines != shouldSnapSelectionToGridGuidelines)
    {
        _shouldSnapSelectionToGridGuidelines = shouldSnapSelectionToGridGuidelines;

        [self forceGridGuidelinesEnabled: shouldSnapSelectionToGridGuidelines
                onCanvasView: canvasView
                withDocument: ppDocument];
    }

    toolPathRect = selectionRect;

    if (_shouldSnapSelectionToGridGuidelines)
    {
        selectionRect = [ppDocument gridGuidelineBoundsCoveredByRect: selectionRect];
    }

    [canvasView setSelectionToolOverlayToRect: selectionRect
                    selectionMode: selectionMode
                    intersectMask: intersectMask
                    toolPathRect: toolPathRect];
}

- (void) forceGridGuidelinesEnabled: (bool) forceGridGuidelinesEnabled
            onCanvasView: (PPCanvasView *) canvasView
            withDocument: (PPDocument *) ppDocument
{
    PPGridPattern *gridPattern;
    bool shouldDisplayCanvasGrid;

    if ([ppDocument shouldDisplayGridAndGridGuidelines])
    {
        return;
    }

    gridPattern = [ppDocument gridPattern];

    if (forceGridGuidelinesEnabled)
    {
        gridPattern = [gridPattern gridPatternByEnablingGuidelinesVisibility];
        shouldDisplayCanvasGrid = YES;
    }
    else
    {
        shouldDisplayCanvasGrid = [ppDocument shouldDisplayGrid];
    }

    [canvasView setGridPattern: gridPattern gridVisibility: shouldDisplayCanvasGrid];
}

- (bool) shouldClearDocumentSelectionWithSelectionRect: (NSRect) selectionRect
            andSelectionMode: (PPSelectionMode) selectionMode
{
    if (PPGeometry_RectCoversMultiplePoints(selectionRect))
    {
        return NO;
    }

    if (!NSIsEmptyRect(selectionRect))  // selectionRect covers single point
    {
        if ((selectionMode == kPPSelectionMode_Replace)
            && NSEqualPoints(_rectMoveOffset, NSZeroPoint))
        {
            return YES;
        }
    }
    else    // selectionRect is empty
    {
        if ((selectionMode == kPPSelectionMode_Replace)
            || (selectionMode == kPPSelectionMode_Intersect))
        {
            return YES;
        }
    }

    return NO;
}

@end
