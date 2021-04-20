/*
    NSColor_PPUtilities.m

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


#define kMaskBitmapOnColor          [NSColor colorWithDeviceWhite: 1.0f alpha: 1.0f]
#define kMaskBitmapOffColor         [NSColor colorWithDeviceWhite: 0.0f alpha: 1.0f]


// Occasionally see small floating-point differences (~1.0e-10) when comparing two calibrated
// colors that had the same original source (appears on 10.10 Yosemite - other versions too?).
// Epsilon value (largest difference allowed between two distinct component values to still be
// considered equal for practical purposes) is a few orders of magnitude larger to be safe, but
// still small compared to 1/255 stepsize between values in an 8-bit channel.

#define kEpsilonForColorComponentValueComparison        (1.0e-7)


static inline bool ColorComponentValuesAreWithinEpsilon(CGFloat component1, CGFloat component2);


@implementation NSColor (PPUtilities)

- (PPImageBitmapPixel) ppImageBitmapPixelValue
{
    static NSBitmapImageRep *bitmap = nil;
    static NSGraphicsContext *bitmapGraphicsContext = nil;
    unsigned char *bitmapData;

    if (!bitmap)
    {
        bitmap = [[NSBitmapImageRep ppImageBitmapOfSize: NSMakeSize(1.0f, 1.0f)] retain];

        if (!bitmap)
            goto ERROR;

        bitmapGraphicsContext =
                    [[NSGraphicsContext graphicsContextWithBitmapImageRep: bitmap] retain];

        if (!bitmapGraphicsContext)
            goto ERROR;

        [bitmapGraphicsContext setShouldAntialias: NO];
    }

    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext: bitmapGraphicsContext];

    [self set];
    NSRectFill(NSMakeRect(0.0f, 0.0f, 1.0f, 1.0f));

    [NSGraphicsContext restoreGraphicsState];

    bitmapData = [bitmap bitmapData];

    if (!bitmapData)
        goto ERROR;

    return *((PPImageBitmapPixel *) bitmapData);

ERROR:
    [bitmapGraphicsContext release];
    bitmapGraphicsContext = nil;

    [bitmap release];
    bitmap = nil;

    return (PPImageBitmapPixel) 0;
}

- (bool) ppIsEqualToColor: (NSColor *) otherColor
{
    CGFloat colorComponents[kNumPPImagePixelComponents],
            otherColorComponents[kNumPPImagePixelComponents];
    int componentIndex;

    self = [self ppSRGBColor];
    otherColor = [otherColor ppSRGBColor];

    if (!self || !otherColor)
    {
        goto ERROR;
    }

    if (([self numberOfComponents] != kNumPPImagePixelComponents)
        || ([otherColor numberOfComponents] != kNumPPImagePixelComponents))
    {
        goto ERROR;
    }

    [self getComponents: colorComponents];
    [otherColor getComponents: otherColorComponents];

    for (componentIndex=0; componentIndex<kNumPPImagePixelComponents; componentIndex++)
    {
        if (!ColorComponentValuesAreWithinEpsilon(colorComponents[componentIndex],
                                                    otherColorComponents[componentIndex]))
        {
            return NO;
        }
    }

    return YES;

ERROR:
    return NO;
}

- (NSColor *) ppColorBlendedWithColor: (NSColor *) otherColor
{
    if (!otherColor)
    {
        otherColor = [NSColor clearColor];
    }

    return [self ppSRGBColorBlendedWithFraction: 0.5f ofColor: otherColor];
}

- (NSColor *) ppColorBlendedWith25PercentOfColor: (NSColor *) otherColor
{
    if (!otherColor)
    {
        otherColor = [NSColor clearColor];
    }

    return [self ppSRGBColorBlendedWithFraction: 0.25f ofColor: otherColor];
}

+ (NSColor *) ppMaskBitmapOnColor
{
    static NSColor *maskOnColor = nil;

    if (!maskOnColor)
    {
        maskOnColor = [kMaskBitmapOnColor retain];
    }

    return maskOnColor;
}

+ (NSColor *) ppMaskBitmapOffColor
{
    static NSColor *maskOffColor = nil;

    if (!maskOffColor)
    {
        maskOffColor = [kMaskBitmapOffColor retain];
    }

    return maskOffColor;
}

#pragma mark Deprecated methods

// +ppColorWithData_DEPRECATED: was deprecated because it is not cross-platform compatible
// between OS X & GNUstep (uses NSArchiver format, which is platform-specific) - should not be
// used for current files, only for loading files created by older versions (1.0b4 & earlier)

+ (NSColor *) ppColorWithData_DEPRECATED: (NSData *) colorData
{
    id colorObject;

    if (!colorData)
        goto ERROR;

    colorObject = [NSUnarchiver unarchiveObjectWithData: colorData];

    if (!colorObject || ![colorObject isKindOfClass: [NSColor class]])
    {
        goto ERROR;
    }

    return (NSColor *) colorObject;

ERROR:
    return nil;
}

/*
- (NSData *) ppColorData_DEPRECATED
{
    return [NSArchiver archivedDataWithRootObject: self];
}
*/

@end

#pragma mark Private functions

static inline bool ColorComponentValuesAreWithinEpsilon(CGFloat component1, CGFloat component2)
{
    if (component1 == component2)
    {
        return YES;
    }
    else if (component1 < component2)
    {
        return ((component1 + kEpsilonForColorComponentValueComparison) >= component2) ?
                    YES : NO;
    }
    else
    {
        return ((component2 + kEpsilonForColorComponentValueComparison) >= component1) ?
                    YES : NO;
    }
}
