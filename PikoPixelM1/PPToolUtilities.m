/*
    PPToolUtilities.m

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

#import "PPToolUtilities.h"

#import "PPDefines.h"
#import "PPModifierKeyMasks.h"


PPSelectionMode PPToolUtils_SelectionModeForModifierKeyFlags(int modifierKeyFlags)
{
    if ((modifierKeyFlags & kModifierKeyMask_IntersectSelection)
            == kModifierKeyMask_IntersectSelection)
    {
        return kPPSelectionMode_Intersect;
    }
    else if (modifierKeyFlags & kModifierKeyMask_AddToSelection)
    {
        return kPPSelectionMode_Add;
    }
    else if (modifierKeyFlags & kModifierKeyMask_CutFromSelection)
    {
        return kPPSelectionMode_Subtract;
    }
    else
    {
        return kPPSelectionMode_Replace;
    }
}

PPPixelMatchingMode PPToolUtils_PixelMatchingModeForModifierKeyFlags(int modifierKeyFlags)
{
    if (modifierKeyFlags & kModifierKeyMask_MatchGlobally)
    {
        return kPPPixelMatchingMode_Anywhere;
    }
    else if (modifierKeyFlags & kModifierKeyMask_MatchDiagonally)
    {
        return kPPPixelMatchingMode_BordersAndDiagonals;
    }
    else
    {
        return kPPPixelMatchingMode_Borders;
    }
}

PPMoveOperationType PPToolUtils_InteractiveMoveTypeForModifierKeyFlags(int modifierKeyFlags)
{
    if (modifierKeyFlags & kModifierKeyMask_MoveACopy)
    {
        return kPPMoveOperationType_LeaveCopyInPlace;
    }
    else if (modifierKeyFlags & kModifierKeyMask_MoveSelectionOutlineOnly)
    {
        return kPPMoveOperationType_SelectionOutlineOnly;
    }
    else
    {
        return kPPMoveOperationType_Normal;
    }
}

unsigned PPToolUtils_ColorMatchToleranceForMouseDistance(unsigned mouseDistance)
{
    // returns tolerance value, 0-255, calculated from the normalized square of the mouse
    // distance (normalized to kMatchToolToleranceIndicator_MaxRadius), with some biased
    // rounding (to reduce the range over which the tolerance stays at zero);
    // the normalized squaring is done to make the tolerance less sensitive to mouse movement
    // (more precise) at the lower end of the tolerance range, since that's where precision is
    // more likely to be needed (tolerance values around 0-50)

    if (mouseDistance > kMatchToolToleranceIndicator_MaxRadius)
    {
        mouseDistance = kMatchToolToleranceIndicator_MaxRadius;
    }

    return (unsigned) ceilf(-0.2f   // -0.2 offset reduces bias of ceilf
                            + (float) (255 * mouseDistance * mouseDistance)
                             / ((float) (kMatchToolToleranceIndicator_MaxRadius
                                         * kMatchToolToleranceIndicator_MaxRadius)));
}
