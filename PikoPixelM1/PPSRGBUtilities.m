/*
    PPSRGBUtilities.m

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

#import "PPSRGBUtilities.h"


@interface NSColorSpace (PPSRGBUtilitiesPrivateMethods)

+ (NSColorSpace *) ppSRGBColorSpace;

@end

@interface NSData (PPSRGBUtilitiesPrivateMethods)

+ (NSData *) ppSRGB_ICCProfileFromSystemFile;

@end

#if !PP_SDK_HAS_NSWINDOW_SETCOLORSPACE_METHOD

@interface NSWindow (SetColorSpaceMethodForLegacySDKs)

- (void) setColorSpace: (NSColorSpace *) colorSpace;

@end

#endif

@implementation NSColor (PPSRGBUtilities)

+ (NSColor *) ppSRGBColorWithRed: (CGFloat) red
                green: (CGFloat) green
                blue: (CGFloat) blue
                alpha: (CGFloat) alpha
{
    CGFloat components[4] = {red, green, blue, alpha};

    return [self colorWithColorSpace: [NSColorSpace ppSRGBColorSpace]
                        components: components
                        count: 4];
}

+ (NSColor *) ppSRGBColorWithWhite: (CGFloat) white
                alpha: (CGFloat) alpha
{
    return [self ppSRGBColorWithRed: white
                            green: white
                            blue: white
                            alpha: alpha];
}

- (NSColor *) ppSRGBColor
{
    static NSColorSpace *sRGBColorSpace = nil;
    NSColor *sRGBColor;

    if (!sRGBColorSpace)
    {
        sRGBColorSpace = [[NSColorSpace ppSRGBColorSpace] retain];
    }

    sRGBColor = [self colorUsingColorSpace: sRGBColorSpace];

    if (!sRGBColor)
        goto ERROR;

    return sRGBColor;

ERROR:
    return nil;
}

- (NSColor *) ppSRGBColorBlendedWithFraction: (CGFloat) fraction
                ofColor: (NSColor *) otherColor
{
    CGFloat color1Fraction, color2Fraction, color1Components_sRGB[4], color2Components_sRGB[4],
            color1Component_Linear, color2Component_Linear, blendedComponent_Linear,
            blendedComponents_sRGB[4];
    int componentIndex;

    self = [self ppSRGBColor];
    otherColor = [otherColor ppSRGBColor];

    if (!self || !otherColor)
    {
        goto ERROR;
    }

    if (fraction >= 1.0)
    {
        return otherColor;
    }
    else if (fraction <= 0.0)
    {
        return self;
    }

    color1Fraction = 1.0 - fraction;
    color2Fraction = fraction;

    [self getComponents: color1Components_sRGB];
    [otherColor getComponents: color2Components_sRGB];

    // RGB channels

    for (componentIndex=0; componentIndex<3; componentIndex++)
    {
        color1Component_Linear =
            macroSRGBUtils_LinearFloatValueFromSRGBFloatValue(
                                                    color1Components_sRGB[componentIndex]);

        color2Component_Linear =
            macroSRGBUtils_LinearFloatValueFromSRGBFloatValue(
                                                    color2Components_sRGB[componentIndex]);

        blendedComponent_Linear = color1Fraction * color1Component_Linear
                                    + color2Fraction * color2Component_Linear;

        blendedComponents_sRGB[componentIndex] =
            macroSRGBUtils_SRGBFloatValueFromLinearFloatValue(blendedComponent_Linear);
    }

    // Alpha channel

    blendedComponents_sRGB[3] = color1Fraction * color1Components_sRGB[3]
                                    + color2Fraction * color2Components_sRGB[3];

    return [NSColor ppSRGBColorWithRed: blendedComponents_sRGB[0]
                                green: blendedComponents_sRGB[1]
                                blue: blendedComponents_sRGB[2]
                                alpha: blendedComponents_sRGB[3]];

ERROR:
    return nil;
}

@end

@implementation NSBitmapImageRep (PPSRGBUtilities)

- (void) ppAttachSRGBColorProfile
{
#if PP_DEPLOYMENT_TARGET_SUPPORTS_COLOR_MANAGEMENT

    static NSData *sRGB_ICCProfile = nil;

    if (!sRGB_ICCProfile)
    {
        sRGB_ICCProfile = [[[NSColorSpace ppSRGBColorSpace] ICCProfileData] retain];
    }

    if (sRGB_ICCProfile)
    {
        [self setProperty: NSImageColorSyncProfileData withValue: sRGB_ICCProfile];
    }

#endif // PP_DEPLOYMENT_TARGET_SUPPORTS_COLOR_MANAGEMENT
}

@end

@implementation NSWindow (PPSRGBUtilities)

- (void) ppSetSRGBColorSpace
{
#if PP_DEPLOYMENT_TARGET_SUPPORTS_COLOR_MANAGEMENT

    static bool needToCheckSetColorSpaceSelector = YES, setColorSpaceSelectorIsSupported = NO;

    if (needToCheckSetColorSpaceSelector)
    {
        setColorSpaceSelectorIsSupported =
            ([NSWindow instancesRespondToSelector: @selector(setColorSpace:)]) ? YES : NO;

        needToCheckSetColorSpaceSelector = NO;
    }

    if (setColorSpaceSelectorIsSupported)
    {
        [self setColorSpace: [NSColorSpace ppSRGBColorSpace]];
    }

#endif // PP_DEPLOYMENT_TARGET_SUPPORTS_COLOR_MANAGEMENT
}

@end

@implementation NSColorSpace (PPSRGBUtilitiesPrivateMethods)

+ (NSColorSpace *) ppSRGBColorSpace
{
    static NSColorSpace *sRGBColorSpace = nil;

    if (!sRGBColorSpace)
    {
        if ([[NSColorSpace class] respondsToSelector: @selector(sRGBColorSpace)])
        {
            sRGBColorSpace =
                [[[NSColorSpace class] performSelector: @selector(sRGBColorSpace)] retain];
        }

        if (!sRGBColorSpace)
        {
            NSData *sRGB_ICCProfile = [NSData ppSRGB_ICCProfileFromSystemFile];

            if (sRGB_ICCProfile)
            {
                sRGBColorSpace = [[NSColorSpace alloc] initWithICCProfileData: sRGB_ICCProfile];
            }
        }

        if (!sRGBColorSpace)
        {
            // can't get sRGB - just use generic RGB

            sRGBColorSpace = [[NSColorSpace genericRGBColorSpace] retain];
        }
    }

    return sRGBColorSpace;
}

@end

@implementation NSData (PPSRGBUtilitiesPrivateMethods)

#if defined(__APPLE__)

#   define kFilepath_sRGB_ICCProfile    @"/System/Library/ColorSync/Profiles/sRGB Profile.icc"

#else // !defined(__APPLE__)

#   define kFilepath_sRGB_ICCProfile    nil

#endif // !defined(__APPLE__)


+ (NSData *) ppSRGB_ICCProfileFromSystemFile
{
    NSData *iccProfile = nil;
    NSString *iccProfileFilepath = kFilepath_sRGB_ICCProfile;

    if (iccProfileFilepath)
    {
        iccProfile = [NSData dataWithContentsOfFile: iccProfileFilepath];
    }

    return iccProfile;
}

@end

