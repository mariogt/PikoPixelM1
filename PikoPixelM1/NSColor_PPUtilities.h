/*
    NSColor_PPUtilities.h

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
#import "PPSRGBUtilities.h"
#import "PPBitmapPixelTypes.h"


@interface NSColor (PPUtilities)

- (PPImageBitmapPixel) ppImageBitmapPixelValue;

- (bool) ppIsEqualToColor: (NSColor *) otherColor;

- (NSColor *) ppColorBlendedWithColor: (NSColor *) otherColor;
- (NSColor *) ppColorBlendedWith25PercentOfColor: (NSColor *) otherColor;

+ (NSColor *) ppMaskBitmapOnColor;
+ (NSColor *) ppMaskBitmapOffColor;


// +ppColorWithData_DEPRECATED: was deprecated because it is not cross-platform compatible
// between OS X & GNUstep (uses NSArchiver format, which is platform-specific) - should not be
// used for current files, only for loading files created by older versions (1.0b4 & earlier)

+ (NSColor *) ppColorWithData_DEPRECATED: (NSData *) colorData;

@end

@interface NSColor (PPUtilities_PatternColors)

+ (NSColor *) ppCheckerboardPatternColorWithBoxDimension: (float) boxDimension
                                                color1: (NSColor *) color1
                                                color2: (NSColor *) color2;

+ (NSColor *) ppDiagonalCheckerboardPatternColorWithBoxDimension: (float) boxDimension
                                                        color1: (NSColor *) color1
                                                        color2: (NSColor *) color2;

+ (NSColor *) ppIsometricCheckerboardPatternColorWithBoxDimension: (float) boxDimension
                                                        color1: (NSColor *) color1
                                                        color2: (NSColor *) color2;

+ (NSColor *) ppDiagonalLinePatternColorWithLineWidth: (float) lineWidth
                                                color1: (NSColor *) color1
                                                color2: (NSColor *) color2;

+ (NSColor *) ppIsometricLinePatternColorWithLineWidth: (float) lineWidth
                                                color1: (NSColor *) color1
                                                color2: (NSColor *) color2;

+ (NSColor *) ppCenteredVerticalGradientPatternColorWithHeight: (unsigned) height
                                                    innerColor: (NSColor *) innerColor
                                                    outerColor: (NSColor *) outerColor;

+ (NSColor *) ppFillOverlayPatternColorWithSize: (float) patternSize
                                    fillColor: (NSColor *) fillColor;

@end
