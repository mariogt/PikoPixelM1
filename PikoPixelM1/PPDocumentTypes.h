/*
    PPDocumentTypes.h

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

#import <Foundation/Foundation.h>


typedef enum
{
    kPPPenMode_Fill,
    kPPPenMode_Erase

} PPPenMode;

typedef enum
{
    kPPSelectionMode_Replace,
    kPPSelectionMode_Intersect,
    kPPSelectionMode_Add,
    kPPSelectionMode_Subtract,

    kNumPPSelectionModes

} PPSelectionMode;

typedef enum
{
    kPPPixelMatchingMode_Borders,
    kPPPixelMatchingMode_BordersAndDiagonals,
    kPPPixelMatchingMode_Anywhere

} PPPixelMatchingMode;

typedef enum
{
    kPPLayerOperationTarget_DrawingLayerOnly,
    kPPLayerOperationTarget_VisibleLayers,
    kPPLayerOperationTarget_Canvas,

    kNumPPLayerOperationTargets

} PPLayerOperationTarget;

typedef enum
{
    kPPLayerBlendingMode_Standard,
    kPPLayerBlendingMode_Linear,

    kNumPPLayerBlendingModes

} PPLayerBlendingMode;

typedef enum
{
    kPPMoveOperationType_Normal,
    kPPMoveOperationType_LeaveCopyInPlace,
    kPPMoveOperationType_SelectionOutlineOnly,

    kNumPPMoveOperationTypes

} PPMoveOperationType;

typedef enum
{
    kPPDocumentSaveFormat_Normal,
    kPPDocumentSaveFormat_Export,
    kPPDocumentSaveFormat_Autosave

} PPDocumentSaveFormat;


static inline bool PPSelectionMode_IsValid(PPSelectionMode selectionMode)
{
    return (((unsigned) selectionMode) < kNumPPSelectionModes) ? YES : NO;
}

static inline bool PPLayerOperationTarget_IsValid(PPLayerOperationTarget layerOperationTarget)
{
    return (((unsigned) layerOperationTarget) < kNumPPLayerOperationTargets) ? YES : NO;
}

static inline bool PPLayerBlendingMode_IsValid(PPLayerBlendingMode layerBlendingMode)
{
    return (((unsigned) layerBlendingMode) < kNumPPLayerBlendingModes) ? YES : NO;
}

static inline bool PPMoveOperationType_IsValid(PPMoveOperationType moveType)
{
    return (((unsigned) moveType) < kNumPPMoveOperationTypes) ? YES : NO;
}

