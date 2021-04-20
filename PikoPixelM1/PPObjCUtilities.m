/*
    PPObjCUtilities.m

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

#import "PPObjCUtilities.h"


static int CompareSelectorNames(const void *selector1, const void *selector2);


void PPObjCUtils_AlphabeticallySortSelectorArray(SEL *selectorArray, int numSelectors)
{
    if (!selectorArray || (numSelectors <= 0))
    {
        goto ERROR;
    }

    qsort(selectorArray, numSelectors, sizeof(SEL), CompareSelectorNames);

    return;

ERROR:
    return;
}

#pragma mark Private functions

static int CompareSelectorNames(const void *selector1, const void *selector2)
{
    return strcmp(sel_getName(*((SEL *) selector1)), sel_getName(*((SEL *) selector2)));
}
