/*
    PPSRGBUtilities.h

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

#import <Cocoa/Cocoa.h>


@interface NSColor (PPSRGBUtilities)

+ (NSColor *) ppSRGBColorWithRed: (CGFloat) red
                green: (CGFloat) green
                blue: (CGFloat) blue
                alpha: (CGFloat) alpha;

+ (NSColor *) ppSRGBColorWithWhite: (CGFloat) white
                alpha: (CGFloat) alpha;

- (NSColor *) ppSRGBColor;

- (NSColor *) ppSRGBColorBlendedWithFraction: (CGFloat) fraction
                ofColor: (NSColor *) otherColor;

@end

@interface NSBitmapImageRep (PPSRGBUtilities)

- (void) ppAttachSRGBColorProfile;

@end

@interface NSWindow (PPSRGBUtilities)

- (void) ppSetSRGBColorSpace;

@end


// Macros for converting sRGB values <-> Linear values
//  (Conversion formulas found in http://www.w3.org/Graphics/Color/srgb.pdf , under headers:
//  "Color component transfer function", "Inverting the color component transfer function")

#define macroSRGBUtils_LinearFloatValueFromSRGBFloatValue(sRGBValue)            \
            ((sRGBValue > 0.04045f) ?                                           \
                powf((sRGBValue + 0.055f) / 1.055f, 2.4f) :                     \
                sRGBValue / 12.92f)

#define macroSRGBUtils_SRGBFloatValueFromLinearFloatValue(linearValue)          \
            ((linearValue > 0.0031308f) ?                                       \
                1.055f * powf(linearValue, 1.0f / 2.4f) - 0.055f :              \
                linearValue * 12.92f)
