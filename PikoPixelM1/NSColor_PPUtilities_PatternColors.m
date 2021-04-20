/*
    NSColor_PPUtilities_PatternColors.m

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

#import "NSColor_PPUtilities.h"

#import "NSBitmapImageRep_PPUtilities.h"
#import "NSImage_PPUtilities.h"


@implementation NSColor (PPUtilities_PatternColors)

+ (NSColor *) ppCheckerboardPatternColorWithBoxDimension: (float) boxDimension
                                                color1: (NSColor *) color1
                                                color2: (NSColor *) color2
{
    NSBitmapImageRep *patternBitmap;
    NSImage *patternImage;

    patternBitmap = [NSBitmapImageRep ppCheckerboardPatternBitmapWithBoxDimension: boxDimension
                                        color1: color1
                                        color2: color2];

    if (!patternBitmap)
        goto ERROR;

    patternImage = [NSImage ppImageWithBitmap: patternBitmap];

    if (!patternImage)
        goto ERROR;

    return [NSColor colorWithPatternImage: patternImage];

ERROR:
    return nil;
}

+ (NSColor *) ppDiagonalCheckerboardPatternColorWithBoxDimension: (float) boxDimension
                                                        color1: (NSColor *) color1
                                                        color2: (NSColor *) color2
{
    NSBitmapImageRep *patternBitmap;
    NSImage *patternImage;

    patternBitmap =
            [NSBitmapImageRep ppDiagonalCheckerboardPatternBitmapWithBoxDimension: boxDimension
                                color1: color1
                                color2: color2];

    if (!patternBitmap)
        goto ERROR;

    patternImage = [NSImage ppImageWithBitmap: patternBitmap];

    if (!patternImage)
        goto ERROR;

    return [NSColor colorWithPatternImage: patternImage];

ERROR:
    return nil;
}

+ (NSColor *) ppIsometricCheckerboardPatternColorWithBoxDimension: (float) boxDimension
                                                        color1: (NSColor *) color1
                                                        color2: (NSColor *) color2
{
    NSBitmapImageRep *patternBitmap;
    NSImage *patternImage;

    patternBitmap =
        [NSBitmapImageRep ppIsometricCheckerboardPatternBitmapWithBoxDimension: boxDimension
                            color1: color1
                            color2: color2];

    if (!patternBitmap)
        goto ERROR;

    patternImage = [NSImage ppImageWithBitmap: patternBitmap];

    if (!patternImage)
        goto ERROR;

    return [NSColor colorWithPatternImage: patternImage];

ERROR:
    return nil;
}

+ (NSColor *) ppDiagonalLinePatternColorWithLineWidth: (float) lineWidth
                                                color1: (NSColor *) color1
                                                color2: (NSColor *) color2
{
    NSBitmapImageRep *patternBitmap;
    NSImage *patternImage;

    patternBitmap = [NSBitmapImageRep ppDiagonalLinePatternBitmapWithLineWidth: lineWidth
                                        color1: color1
                                        color2: color2];

    if (!patternBitmap)
        goto ERROR;

    patternImage = [NSImage ppImageWithBitmap: patternBitmap];

    if (!patternImage)
        goto ERROR;

    return [NSColor colorWithPatternImage: patternImage];

ERROR:
    return nil;
}

+ (NSColor *) ppIsometricLinePatternColorWithLineWidth: (float) lineWidth
                                                color1: (NSColor *) color1
                                                color2: (NSColor *) color2
{
    NSBitmapImageRep *patternBitmap;
    NSImage *patternImage;

    patternBitmap = [NSBitmapImageRep ppIsometricLinePatternBitmapWithLineWidth: lineWidth
                                        color1: color1
                                        color2: color2];

    if (!patternBitmap)
        goto ERROR;

    patternImage = [NSImage ppImageWithBitmap: patternBitmap];

    if (!patternImage)
        goto ERROR;

    return [NSColor colorWithPatternImage: patternImage];

ERROR:
    return nil;
}

+ (NSColor *) ppCenteredVerticalGradientPatternColorWithHeight: (unsigned) height
                                                    innerColor: (NSColor *) innerColor
                                                    outerColor: (NSColor *) outerColor
{
    NSBitmapImageRep *patternBitmap;
    NSImage *patternImage;

    patternBitmap = [NSBitmapImageRep ppCenteredVerticalGradientPatternBitmapWithHeight: height
                                        innerColor: innerColor
                                        outerColor: outerColor];

    if (!patternBitmap)
        goto ERROR;

    patternImage = [NSImage ppImageWithBitmap: patternBitmap];

    if (!patternImage)
        goto ERROR;

    return [NSColor colorWithPatternImage: patternImage];

ERROR:
    return nil;
}

+ (NSColor *) ppFillOverlayPatternColorWithSize: (float) patternSize
                                    fillColor: (NSColor *) fillColor
{
    NSBitmapImageRep *patternBitmap;
    NSImage *patternImage;

    patternBitmap = [NSBitmapImageRep ppFillOverlayPatternBitmapWithSize: patternSize
                                        fillColor: fillColor];

    if (!patternBitmap)
        goto ERROR;

    patternImage = [NSImage ppImageWithBitmap: patternBitmap];

    if (!patternImage)
        goto ERROR;

    return [NSColor colorWithPatternImage: patternImage];

ERROR:
    return nil;
}

@end
