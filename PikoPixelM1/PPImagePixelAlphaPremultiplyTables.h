/*
    PPImagePixelAlphaPremultiplyTables.h

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
#import "PPBitmapPixelTypes.h"

// Lookup tables for premultiplying & unpremultiplying image bitmap pixels' color values with
// their alpha values. (Table lookups are faster than multiplying/dividing+rounding-off).
//
// Tables are stored as a global array - one lookup table for each possible alpha value [0-255];
// Each lookup table contains entries for all possible color-channel values [0-255].
//
// To premultiply an image pixel:
//
// premultiplyTable = gImageAlphaPremultiplyTables[imagePixel.alphaComponent]
// premultipliedImagePixel.redComponent = premultiplyTable[imagePixel.redComponent]
// premultipliedImagePixel.greenComponent = premultiplyTable[imagePixel.greenComponent]
// premultipliedImagePixel.blueComponent = premultiplyTable[imagePixel.blueComponent]
//
// (Same process for unpremultiplying)


extern PPImagePixelComponent *gImageAlphaPremultiplyTables[],
                                *gImageAlphaUnpremultiplyTables[];


#define macroAlphaPremultiplyTableForImagePixel(imagePixel)             \
            gImageAlphaPremultiplyTables[macroImagePixelComponent_Alpha(imagePixel)]

#define macroAlphaUnpremultiplyTableForImagePixel(imagePixel)           \
            gImageAlphaUnpremultiplyTables[macroImagePixelComponent_Alpha(imagePixel)]
