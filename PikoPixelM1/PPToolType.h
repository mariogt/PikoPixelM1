/*
    PPToolType.h

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


typedef enum
{
    kPPToolType_Pencil,
    kPPToolType_Eraser,
    kPPToolType_Fill,
    kPPToolType_Line,
    kPPToolType_Rect,
    kPPToolType_Oval,
    kPPToolType_FreehandSelect,
    kPPToolType_RectSelect,
    kPPToolType_MagicWand,
    kPPToolType_ColorSampler,
    kPPToolType_Move,
    kPPToolType_Magnifier,
    kPPToolType_ColorRamp,  // not shown in Tools panel; activated via Line Tool + modifier keys

    // add new PPToolType values above this line

    kNumPPToolTypes

} PPToolType;


static inline bool PPToolType_IsValid(PPToolType toolType)
{
    return (((unsigned) toolType) < kNumPPToolTypes) ? YES : NO;
}


// PPToolTypeMask

#define kPPToolTypeMask_Pencil          (1 << kPPToolType_Pencil)
#define kPPToolTypeMask_Eraser          (1 << kPPToolType_Eraser)
#define kPPToolTypeMask_Fill            (1 << kPPToolType_Fill)
#define kPPToolTypeMask_Line            (1 << kPPToolType_Line)
#define kPPToolTypeMask_Rect            (1 << kPPToolType_Rect)
#define kPPToolTypeMask_Oval            (1 << kPPToolType_Oval)
#define kPPToolTypeMask_FreehandSelect  (1 << kPPToolType_FreehandSelect)
#define kPPToolTypeMask_RectSelect      (1 << kPPToolType_RectSelect)
#define kPPToolTypeMask_MagicWand       (1 << kPPToolType_MagicWand)
#define kPPToolTypeMask_ColorSampler    (1 << kPPToolType_ColorSampler)
#define kPPToolTypeMask_Move            (1 << kPPToolType_Move)
#define kPPToolTypeMask_Magnifier       (1 << kPPToolType_Magnifier)
#define kPPToolTypeMask_ColorRamp       (1 << kPPToolType_ColorRamp)


static inline unsigned PPToolTypeMaskForPPToolType(PPToolType toolType)
{
    return (1 << toolType);
}
