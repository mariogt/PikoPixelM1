/*
    PPModifiablePPToolTypesMasks.h

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

#import "PPToolType.h"


//  A PPDocument's active tool can be 'modified': switched to a different tool by pressing one
// or more modifier keys.

//  Modifier-switching to a specific tool is usually only allowed from a few initial tool types.
// For instance, switching to the Eraser tool via modifier is only possible when the initial
// tool is the Pencil or Line Tool.

//  For each modifier-switchable destination tool type, its kModifiablePPToolTypesMask_* define
// determines the set of initial tool types that allow modifier-switching to it.


#define kModifiablePPToolTypesMask_Eraser                                               \
            (kPPToolTypeMask_Pencil | kPPToolTypeMask_Line)

#define kModifiablePPToolTypesMask_Fill                                                 \
            (kPPToolTypeMask_Pencil | kPPToolTypeMask_Line | kPPToolTypeMask_Rect       \
            | kPPToolTypeMask_Oval)

#define kModifiablePPToolTypesMask_ColorSampler                                         \
            (kPPToolTypeMask_Pencil | kPPToolTypeMask_Fill | kPPToolTypeMask_Line       \
            | kPPToolTypeMask_Rect | kPPToolTypeMask_Oval)

#define kModifiablePPToolTypesMask_Move                                                 \
            (kPPToolTypeMask_Pencil | kPPToolTypeMask_Eraser | kPPToolTypeMask_Fill     \
            | kPPToolTypeMask_Line | kPPToolTypeMask_FreehandSelect                     \
            | kPPToolTypeMask_RectSelect)

#define kModifiablePPToolTypesMask_Magnifier                                            \
            (~kPPToolTypeMask_Magnifier)

#define kModifiablePPToolTypesMask_ColorRamp                                            \
            (kPPToolTypeMask_Line)
