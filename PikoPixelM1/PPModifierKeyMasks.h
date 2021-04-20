/*
    PPModifierKeyMasks.h

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


#define kModifierKeyMask_RecognizedModifierKeys     \
                    (NSShiftKeyMask | NSControlKeyMask | NSAlternateKeyMask | NSCommandKeyMask)

#define kModifierKeyMask_SelectEraserTool           (NSControlKeyMask)
#define kModifierKeyMask_SelectFillTool             (NSAlternateKeyMask | NSShiftKeyMask)
#define kModifierKeyMask_SelectColorSamplerTool     (NSAlternateKeyMask)
#define kModifierKeyMask_SelectMoveTool             (NSControlKeyMask | NSShiftKeyMask)
#define kModifierKeyMask_SelectMagnifierTool        (NSCommandKeyMask | NSAlternateKeyMask)
#define kModifierKeyMask_SelectColorRampTool        (NSControlKeyMask | NSAlternateKeyMask)
#define kModifierKeyMask_DrawLineSegment            (NSShiftKeyMask)
#define kModifierKeyMask_NewLineSegment             (NSControlKeyMask)
#define kModifierKeyMask_DeleteLineSegment          (NSAlternateKeyMask)
#define kModifierKeyMask_IntersectSelection         (NSAlternateKeyMask | NSShiftKeyMask)
#define kModifierKeyMask_AddToSelection             (NSShiftKeyMask)
#define kModifierKeyMask_CutFromSelection           (NSAlternateKeyMask)
#define kModifierKeyMask_SnapSelectionToGuidelines  (NSControlKeyMask)
#define kModifierKeyMask_MoveACopy                  (NSCommandKeyMask)
#define kModifierKeyMask_MoveSelectionOutlineOnly   (NSAlternateKeyMask)
#define kModifierKeyMask_MoveRectSelectionOutline   (NSCommandKeyMask)
#define kModifierKeyMask_MatchDiagonally            (NSControlKeyMask)
#define kModifierKeyMask_MatchGlobally              (NSCommandKeyMask)
#define kModifierKeyMask_LockAspectRatio            (NSShiftKeyMask)
#define kModifierKeyMask_CenterShapeAtMouseDown     (NSControlKeyMask)
#define kModifierKeyMask_FillShape                  (NSCommandKeyMask)
#define kModifierKeyMask_ZoomOut                    (NSShiftKeyMask)

#define kModifierKeyMask_SelectEraserToolWithFillShape              \
            (kModifierKeyMask_SelectEraserTool | kModifierKeyMask_FillShape)

#define kModifierKeyMask_SelectMoveToolWithSelectionOutlineOnly     \
            (kModifierKeyMask_SelectMoveTool | kModifierKeyMask_MoveSelectionOutlineOnly)

#define kModifierKeyMask_SelectMoveToolAndLeaveCopyInPlace          \
            (kModifierKeyMask_SelectMoveTool | kModifierKeyMask_MoveACopy)

#define kModifierKeyMask_SelectMagnifierToolWithZoomOut             \
            (kModifierKeyMask_SelectMagnifierTool | kModifierKeyMask_ZoomOut)

#define kModifierKeyMask_SelectMagnifierToolWithCenterShape         \
            (kModifierKeyMask_SelectMagnifierTool | kModifierKeyMask_CenterShapeAtMouseDown)
