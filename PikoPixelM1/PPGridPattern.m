/*
    PPGridPattern.m

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

#import "PPGridPattern.h"

#import "PPDefines.h"
#import "NSColor_PPUtilities.h"
#import "PPUserDefaultsInitialValues.h"
#import "PPGeometry.h"
#import "NSBitmapImageRep_PPUtilities.h"
#import "NSImage_PPUtilities.h"


#define kGridPatternCodingVersion_Current               kGridPatternCodingVersion_1

// Coding Version 1
// Added coding version, guideline members (spacing size, color, display flag), & preset name
#define kGridPatternCodingVersion_1                     1
#define kGridPatternCodingKey_CodingVersion             @"CodingVersion"
#define kGridPatternCodingKey_PixelGridType             kGridPatternCodingKey_v0_PixelGridType
#define kGridPatternCodingKey_PixelGridColor            kGridPatternCodingKey_v0_PixelGridColor
#define kGridPatternCodingKey_GuidelineSpacingSize      @"GuidelineSpacingSize"
#define kGridPatternCodingKey_GuidelineColor            @"GuidelineColor"
#define kGridPatternCodingKey_GuidelinesVisibility      @"GuidelinesVisibility"
#define kGridPatternCodingKey_PresetName                @"PresetName"

// Coding Version 0
// Used in PikoPixel 1.0 beta6 & earlier
#define kGridPatternCodingVersion_0                     0
#define kGridPatternCodingKey_v0_PixelGridType          @"PixelGridType"
#define kGridPatternCodingKey_v0_PixelGridColor         @"PixelGridColor"


#define kGridPatternPreviewForegroundImageResourceName  @"gridpatternpreview_foreground.png"


@interface PPGridPattern (PrivateMethods)

- initWithPixelGridType: (PPGridType) pixelGridType
    pixelGridColor: (NSColor *) pixelGridColor;

- (id) initWithCoder_v0: (NSCoder *) aDecoder;

@end

@implementation PPGridPattern

+ gridPatternWithPixelGridType: (PPGridType) pixelGridType
    pixelGridColor: (NSColor *) pixelGridColor
    guidelineSpacingSize: (NSSize) guidelineSpacingSize
    guidelineColor: (NSColor *) guidelineColor
    shouldDisplayGuidelines: (bool) shouldDisplayGuidelines;
{
    return [[[self alloc] initWithPixelGridType: pixelGridType
                            pixelGridColor: pixelGridColor
                            guidelineSpacingSize: guidelineSpacingSize
                            guidelineColor: guidelineColor
                            shouldDisplayGuidelines: shouldDisplayGuidelines]
                    autorelease];
}

+ gridPatternWithPixelGridType: (PPGridType) pixelGridType
    pixelGridColor: (NSColor *) pixelGridColor
{
    return [[[self alloc] initWithPixelGridType: pixelGridType
                            pixelGridColor: pixelGridColor]
                    autorelease];
}

- initWithPixelGridType: (PPGridType) pixelGridType
    pixelGridColor: (NSColor *) pixelGridColor
    guidelineSpacingSize: (NSSize) guidelineSpacingSize
    guidelineColor: (NSColor *) guidelineColor
    shouldDisplayGuidelines: (bool) shouldDisplayGuidelines
{
    self = [super init];

    if (!self)
        goto ERROR;

    if (!PPGridType_IsValid(pixelGridType))
    {
        goto ERROR;
    }

    pixelGridColor = [pixelGridColor ppSRGBColor];
    guidelineColor = [guidelineColor ppSRGBColor];

    if (!pixelGridColor || !guidelineColor)
    {
        goto ERROR;
    }

    guidelineSpacingSize =
        PPGeometry_SizeClippedToIntegerValues(
            PPGeometry_SizeClampedToMinMaxValues(guidelineSpacingSize,
                                                    kMinGridGuidelineSpacing,
                                                    kMaxGridGuidelineSpacing));

    _pixelGridType = pixelGridType;
    _pixelGridColor = [pixelGridColor retain];

    _guidelineSpacingSize = guidelineSpacingSize;
    _guidelineColor = [guidelineColor retain];
    _shouldDisplayGuidelines = (shouldDisplayGuidelines) ? YES : NO;

    return self;

ERROR:
    [self release];

    return nil;
}

- initWithPixelGridType: (PPGridType) pixelGridType
    pixelGridColor: (NSColor *) pixelGridColor
{
    static NSColor *defaultGuidelineColor = nil;
    static NSSize defaultGuidelineSpacingSize = {0,0};

    if (!defaultGuidelineColor)
    {
        PPGridPattern *defaultInitialGridPattern = kUserDefaultsInitialValue_GridPattern;

        if (defaultInitialGridPattern)
        {
            defaultGuidelineColor = [[defaultInitialGridPattern guidelineColor] retain];
            defaultGuidelineSpacingSize = [defaultInitialGridPattern guidelineSpacingSize];
        }
        else
        {
            defaultGuidelineColor = [[NSColor blackColor] retain];
            defaultGuidelineSpacingSize = NSMakeSize(8,8);
        }
    }

    return [self initWithPixelGridType: pixelGridType
                    pixelGridColor: pixelGridColor
                    guidelineSpacingSize: defaultGuidelineSpacingSize
                    guidelineColor: defaultGuidelineColor
                    shouldDisplayGuidelines: NO];
}

- init
{
    return [self initWithPixelGridType: -1
                    pixelGridColor: nil
                    guidelineSpacingSize: NSZeroSize
                    guidelineColor: nil
                    shouldDisplayGuidelines: NO];
}

- (void) dealloc
{
    [_pixelGridColor release];
    [_guidelineColor release];

    [_presetName release];

    [super dealloc];
}

- (PPGridType) pixelGridType
{
    return _pixelGridType;
}

- (NSColor *) pixelGridColor
{
    return _pixelGridColor;
}

- (NSSize) guidelineSpacingSize
{
    return _guidelineSpacingSize;
}

- (NSColor *) guidelineColor
{
    return _guidelineColor;
}

- (bool) shouldDisplayGuidelines
{
    return _shouldDisplayGuidelines;
}

- (bool) isEqualToGridPattern: (PPGridPattern *) otherPattern
{
    if (self == otherPattern)
    {
        return YES;
    }

    if (!otherPattern
        || (_pixelGridType != otherPattern->_pixelGridType)
        || ![_pixelGridColor ppIsEqualToColor: otherPattern->_pixelGridColor]
        || !NSEqualSizes(_guidelineSpacingSize, otherPattern->_guidelineSpacingSize)
        || ![_guidelineColor ppIsEqualToColor: otherPattern->_guidelineColor]
        || (_shouldDisplayGuidelines != otherPattern->_shouldDisplayGuidelines))
    {
        return NO;
    }

    return YES;
}

- (PPGridPattern *) gridPatternByTogglingPixelGridType
{
    PPGridType toggledPixelGridType;

    toggledPixelGridType = _pixelGridType + 1;

    if (!PPGridType_IsValid(toggledPixelGridType))
    {
        toggledPixelGridType = 0;
    }

    return [[self class] gridPatternWithPixelGridType: toggledPixelGridType
                            pixelGridColor: _pixelGridColor
                            guidelineSpacingSize: _guidelineSpacingSize
                            guidelineColor: _guidelineColor
                            shouldDisplayGuidelines: _shouldDisplayGuidelines];
}

- (PPGridPattern *) gridPatternByTogglingGuidelinesVisibility
{
    return [[self class] gridPatternWithPixelGridType: _pixelGridType
                            pixelGridColor: _pixelGridColor
                            guidelineSpacingSize: _guidelineSpacingSize
                            guidelineColor: _guidelineColor
                            shouldDisplayGuidelines: (_shouldDisplayGuidelines) ? NO : YES];
}

- (PPGridPattern *) gridPatternByEnablingGuidelinesVisibility
{
    if (_shouldDisplayGuidelines)
    {
        return [[self retain] autorelease];
    }
    else
    {
        return [self gridPatternByTogglingGuidelinesVisibility];
    }
}

- (NSData *) archivedData
{
    return [NSKeyedArchiver archivedDataWithRootObject: self];
}

+ (PPGridPattern *) gridPatternWithArchivedData: (NSData *) archivedData
{
    PPGridPattern *pattern = [NSKeyedUnarchiver unarchiveObjectWithData: archivedData];

    if (![pattern isKindOfClass: [PPGridPattern class]])
    {
        goto ERROR;
    }

    return pattern;

ERROR:
    return nil;
}

#pragma mark NSCoding protocol

- (id) initWithCoder: (NSCoder *) aDecoder
{
    int codingVersion = [aDecoder decodeIntForKey: kGridPatternCodingKey_CodingVersion];

    if (codingVersion == kGridPatternCodingVersion_0)
    {
        return [self initWithCoder_v0: aDecoder];
    }

    self = [self initWithPixelGridType:
                        [aDecoder decodeIntForKey: kGridPatternCodingKey_PixelGridType]
                    pixelGridColor:
                        [aDecoder decodeObjectForKey: kGridPatternCodingKey_PixelGridColor]
                    guidelineSpacingSize:
                        [aDecoder decodeSizeForKey: kGridPatternCodingKey_GuidelineSpacingSize]
                    guidelineColor:
                        [aDecoder decodeObjectForKey: kGridPatternCodingKey_GuidelineColor]
                    shouldDisplayGuidelines:
                        [aDecoder decodeBoolForKey: kGridPatternCodingKey_GuidelinesVisibility]];

    if ([aDecoder containsValueForKey: kGridPatternCodingKey_PresetName])
    {
        [self setPresetName: [aDecoder decodeObjectForKey: kGridPatternCodingKey_PresetName]];
    }

    return self;
}

- (void) encodeWithCoder: (NSCoder *) coder
{
    [coder encodeInt: kGridPatternCodingVersion_Current
            forKey: kGridPatternCodingKey_CodingVersion];

    [coder encodeInt: _pixelGridType forKey: kGridPatternCodingKey_PixelGridType];
    [coder encodeObject: _pixelGridColor forKey: kGridPatternCodingKey_PixelGridColor];

    [coder encodeSize: _guidelineSpacingSize forKey: kGridPatternCodingKey_GuidelineSpacingSize];
    [coder encodeObject: _guidelineColor forKey: kGridPatternCodingKey_GuidelineColor];
    [coder encodeBool: _shouldDisplayGuidelines
            forKey: kGridPatternCodingKey_GuidelinesVisibility];

    if (_presetName)
    {
        [coder encodeObject: _presetName forKey: kGridPatternCodingKey_PresetName];
    }
}

- (id) initWithCoder_v0: (NSCoder *) aDecoder
{
    self = [self initWithPixelGridType:
                        [aDecoder decodeIntForKey: kGridPatternCodingKey_v0_PixelGridType]
                    pixelGridColor:
                        [aDecoder decodeObjectForKey: kGridPatternCodingKey_v0_PixelGridColor]];

    return self;
}

/*
- (void) encodeWithCoder_v0: (NSCoder *) coder
{
    [coder encodeInt: _pixelGridType forKey: kGridPatternCodingKey_v0_PixelGridType];
    [coder encodeObject: _pixelGridColor forKey: kGridPatternCodingKey_v0_PixelGridColor];
}
*/

#pragma mark NSCopying protocol

- (id) copyWithZone: (NSZone *) zone
{
    PPGridPattern *copiedPattern;

    copiedPattern =
        [[[self class] allocWithZone: zone]
                            initWithPixelGridType: _pixelGridType
                            pixelGridColor: [[_pixelGridColor copyWithZone: zone] autorelease]
                            guidelineSpacingSize: _guidelineSpacingSize
                            guidelineColor: [[_guidelineColor copyWithZone: zone] autorelease]
                            shouldDisplayGuidelines: _shouldDisplayGuidelines];

    if (_presetName)
    {
        [copiedPattern setPresetName: [[_presetName copyWithZone: zone] autorelease]];
    }

    return copiedPattern;
}

#pragma mark PPPresettablePattern protocol

- (void) setPresetName: (NSString *) presetName
{
    [_presetName autorelease];

    _presetName = [presetName retain];
}

- (NSString *) presetName
{
    return _presetName;
}

- (bool) isEqualToPresettablePattern: (id <PPPresettablePattern>) pattern
{
    if ([pattern isKindOfClass: [self class]])
    {
        return [self isEqualToGridPattern: (PPGridPattern *) pattern];
    }

    return NO;
}

- (NSColor *) patternColorForPresettablePatternViewOfSize: (NSSize) viewSize
{
    static NSBitmapImageRep *foregroundBitmap = nil;
    static NSSize foregroundBitmapSize = {0,0}, guidelineSpacingSize = {0,0};
    int viewSizeMinDimension, scalingFactor;
    NSBitmapImageRep *patternBitmap;
    NSImage *patternImage;

    if (!foregroundBitmap)
    {
        foregroundBitmap =
            [[NSBitmapImageRep ppImageBitmapFromImageResource:
                                            kGridPatternPreviewForegroundImageResourceName]
                            retain];

        if (!foregroundBitmap)
            goto ERROR;

        foregroundBitmapSize = [foregroundBitmap ppSizeInPixels];

        guidelineSpacingSize = NSMakeSize(foregroundBitmapSize.width / 2,
                                            foregroundBitmapSize.height / 2);
    }

    viewSizeMinDimension = MIN(viewSize.width, viewSize.height);

    scalingFactor =
            viewSizeMinDimension / MAX(foregroundBitmapSize.width, foregroundBitmapSize.height);

    if (scalingFactor < kMinScalingFactorToDrawGrid)
    {
        goto ERROR;
    }

    patternBitmap = [foregroundBitmap ppImageBitmapScaledByFactor: scalingFactor
                                        shouldDrawGrid: YES
                                        gridType: _pixelGridType
                                        gridColor: _pixelGridColor];

    if (!patternBitmap)
        goto ERROR;

    if (_shouldDisplayGuidelines)
    {
        [patternBitmap ppDrawImageGuidelinesInBounds: [patternBitmap ppFrameInPixels]
                        topLeftPhase: NSMakePoint(guidelineSpacingSize.width * scalingFactor / 2,
                                                guidelineSpacingSize.height * scalingFactor / 2)
                        unscaledSpacingSize: guidelineSpacingSize
                        scalingFactor: scalingFactor
                        guidelinePixelValue: [_guidelineColor ppImageBitmapPixelValue]];
    }

    patternImage = [NSImage ppImageWithBitmap: patternBitmap];

    if (!patternImage)
        goto ERROR;

    return [NSColor colorWithPatternImage: patternImage];

ERROR:
    return nil;
}

@end
