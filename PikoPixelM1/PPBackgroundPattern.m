/*
    PPBackgroundPattern.m

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

#import "PPBackgroundPattern.h"

#import "PPDefines.h"
#import "NSColor_PPUtilities.h"


#define kBackgroundPatternCodingVersion_Current     kBackgroundPatternCodingVersion_1

// Coding Version 1
// To allow sharing a .piko file between OS X & GNUstep, no longer encodes pattern colors
// with -[NSColor ppColorData], because that method used NSArchiver, which writes in a
// different format on each platform
#define kBackgroundPatternCodingVersion_1           1
#define kBackgroundPatternCodingKey_CodingVersion   @"CodingVersion"
#define kBackgroundPatternCodingKey_PatternType     kBackgroundPatternCodingKey_v0_PatternType
#define kBackgroundPatternCodingKey_PatternSize     kBackgroundPatternCodingKey_v0_PatternSize
#define kBackgroundPatternCodingKey_Color1          @"PatternColor1"
#define kBackgroundPatternCodingKey_Color2          @"PatternColor2"
#define kBackgroundPatternCodingKey_PresetName      kBackgroundPatternCodingKey_v0_PresetName

// Coding Version 0
// Used in PikoPixel 1.0 beta4 & earlier
#define kBackgroundPatternCodingVersion_0           0
#define kBackgroundPatternCodingKey_v0_PatternType  @"PatternType"
#define kBackgroundPatternCodingKey_v0_PatternSize  @"PatternSize"
#define kBackgroundPatternCodingKey_v0_Color1       @"Color1"
#define kBackgroundPatternCodingKey_v0_Color2       @"Color2"
#define kBackgroundPatternCodingKey_v0_PresetName   @"PresetName"


@interface PPBackgroundPattern (PrivateMethods)

- (id) initWithCoder_v0: (NSCoder *) aDecoder;

- (void) setupPatternFillColor;

@end

@implementation PPBackgroundPattern

+ backgroundPatternOfType: (PPBackgroundPatternType) patternType
    patternSize: (int) patternSize
    color1: (NSColor *) color1
    color2: (NSColor *) color2
{
    return [[[self alloc] initWithPatternType: patternType
                                patternSize: patternSize
                                color1: color1
                                color2: color2]
                    autorelease];
}

- initWithPatternType: (PPBackgroundPatternType) patternType
    patternSize: (int) patternSize
    color1: (NSColor *) color1
    color2: (NSColor *) color2
{
    self = [super init];

    if (!self)
        goto ERROR;

    if (!PPBackgroundPatternType_IsValid(patternType)
        || (patternSize < kMinBackgroundPatternSize)
        || (patternSize > kMaxBackgroundPatternSize))
    {
        goto ERROR;
    }

    if (!color2)
    {
        color2 = color1;
    }

    color1 = [color1 ppSRGBColor];
    color2 = [color2 ppSRGBColor];

    if (!color1 || !color2)
    {
        goto ERROR;
    }

    _patternType = patternType;
    _patternSize = patternSize;
    _color1 = [color1 retain];
    _color2 = [color2 retain];

    return self;

ERROR:
    [self release];

    return nil;
}

- init
{
    return [self initWithPatternType: 0 patternSize: 0 color1: nil color2: nil];
}

- (void) dealloc
{
    [_color1 release];
    [_color2 release];

    [_patternFillColor release];

    [_presetName release];

    [super dealloc];
}

- (PPBackgroundPatternType) patternType
{
    return _patternType;
}

- (int) patternSize
{
    return _patternSize;
}

- (NSColor *) color1
{
    return _color1;
}

- (NSColor *) color2
{
    return _color2;
}

- (NSColor *) patternFillColor
{
    if (!_patternFillColor)
    {
        [self setupPatternFillColor];
    }

    return _patternFillColor;
}

- (bool) isEqualToBackgroundPattern: (PPBackgroundPattern *) otherPattern
{
    if (self == otherPattern)
    {
        return YES;
    }

    if (!otherPattern
        || (_patternType != [otherPattern patternType])
        || (_patternSize != [otherPattern patternSize])
        || (![_color1 ppIsEqualToColor: [otherPattern color1]])
        || (![_color2 ppIsEqualToColor: [otherPattern color2]]))
    {
        return NO;
    }

    return YES;
}

- (PPBackgroundPattern *) backgroundPatternScaledByFactor: (float) scalingFactor
{
    int scaledPatternSize = roundf(scalingFactor * _patternSize);

    if (scaledPatternSize > kMaxBackgroundPatternSize)
    {
        scaledPatternSize = kMaxBackgroundPatternSize;
    }
    else if (scaledPatternSize < kMinBackgroundPatternSize)
    {
        scaledPatternSize = kMinBackgroundPatternSize;
    }

    if (scaledPatternSize == _patternSize)
    {
        return [[self retain] autorelease];
    }

    return [[self class] backgroundPatternOfType: _patternType
                            patternSize: scaledPatternSize
                            color1: _color1
                            color2: _color2];
}

- (NSData *) archivedData
{
    return [NSKeyedArchiver archivedDataWithRootObject: self];
}

+ (PPBackgroundPattern *) backgroundPatternWithArchivedData: (NSData *) archivedData
{
    PPBackgroundPattern *pattern = [NSKeyedUnarchiver unarchiveObjectWithData: archivedData];

    if (![pattern isKindOfClass: [PPBackgroundPattern class]])
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
    int codingVersion = [aDecoder decodeIntForKey: kBackgroundPatternCodingKey_CodingVersion];

    if (codingVersion == kBackgroundPatternCodingVersion_0)
    {
        return [self initWithCoder_v0: aDecoder];
    }

    self = [self initWithPatternType:
                        [aDecoder decodeIntForKey: kBackgroundPatternCodingKey_PatternType]
                    patternSize:
                        [aDecoder decodeIntForKey: kBackgroundPatternCodingKey_PatternSize]
                    color1: [aDecoder decodeObjectForKey: kBackgroundPatternCodingKey_Color1]
                    color2: [aDecoder decodeObjectForKey: kBackgroundPatternCodingKey_Color2]];

    if ([aDecoder containsValueForKey: kBackgroundPatternCodingKey_PresetName])
    {
        [self setPresetName:
                        [aDecoder decodeObjectForKey: kBackgroundPatternCodingKey_PresetName]];
    }

    return self;
}

- (void) encodeWithCoder: (NSCoder *) coder
{
    [coder encodeInt: kBackgroundPatternCodingVersion_Current
            forKey: kBackgroundPatternCodingKey_CodingVersion];

    [coder encodeInt: _patternType forKey: kBackgroundPatternCodingKey_PatternType];
    [coder encodeInt: _patternSize forKey: kBackgroundPatternCodingKey_PatternSize];

    [coder encodeObject: _color1 forKey: kBackgroundPatternCodingKey_Color1];
    [coder encodeObject: _color2 forKey: kBackgroundPatternCodingKey_Color2];

    if (_presetName)
    {
        [coder encodeObject: _presetName forKey: kBackgroundPatternCodingKey_PresetName];
    }
}


#if PP_DEPLOYMENT_TARGET_SUPPORTS_APPLE_NSARCHIVER_FORMAT

- (id) initWithCoder_v0: (NSCoder *) aDecoder
{
    NSData *color1Data, *color2Data;

    color1Data = [aDecoder decodeObjectForKey: kBackgroundPatternCodingKey_v0_Color1];
    color2Data = [aDecoder decodeObjectForKey: kBackgroundPatternCodingKey_v0_Color2];

    self = [self initWithPatternType:
                        [aDecoder decodeIntForKey: kBackgroundPatternCodingKey_v0_PatternType]
                    patternSize:
                        [aDecoder decodeIntForKey: kBackgroundPatternCodingKey_v0_PatternSize]
                    color1: [NSColor ppColorWithData_DEPRECATED: color1Data]
                    color2: [NSColor ppColorWithData_DEPRECATED: color2Data]];

    if ([aDecoder containsValueForKey: kBackgroundPatternCodingKey_v0_PresetName])
    {
        [self setPresetName:
                    [aDecoder decodeObjectForKey: kBackgroundPatternCodingKey_v0_PresetName]];
    }

    return self;
}

/*
- (void) encodeWithCoder_v0: (NSCoder *) coder
{
    [coder encodeInt: _patternType forKey: kBackgroundPatternCodingKey_v0_PatternType];
    [coder encodeInt: _patternSize forKey: kBackgroundPatternCodingKey_v0_PatternSize];

    [coder encodeObject: [_color1 ppColorData_DEPRECATED]
            forKey: kBackgroundPatternCodingKey_v0_Color1];

    [coder encodeObject: [_color2 ppColorData_DEPRECATED]
            forKey: kBackgroundPatternCodingKey_v0_Color2];

    if (_presetName)
    {
        [coder encodeObject: _presetName forKey: kBackgroundPatternCodingKey_v0_PresetName];
    }
}
*/

#else   // !PP_DEPLOYMENT_TARGET_SUPPORTS_APPLE_NSARCHIVER_FORMAT

- (id) initWithCoder_v0: (NSCoder *) aDecoder
{
    return [self init];
}

#endif  // PP_DEPLOYMENT_TARGET_SUPPORTS_APPLE_NSARCHIVER_FORMAT

#pragma mark NSCopying protocol

- (id) copyWithZone: (NSZone *) zone
{
    PPBackgroundPattern *copiedPattern;

    copiedPattern = [[[self class] allocWithZone: zone]
                                        initWithPatternType: _patternType
                                        patternSize: _patternSize
                                        color1: [[_color1 copyWithZone: zone] autorelease]
                                        color2: [[_color2 copyWithZone: zone] autorelease]];

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
        return [self isEqualToBackgroundPattern: (PPBackgroundPattern *) pattern];
    }

    return NO;
}

- (NSColor *) patternColorForPresettablePatternViewOfSize: (NSSize) viewSize
{
    return [self patternFillColor];
}

#pragma mark Private methods

- (void) setupPatternFillColor
{
    NSColor *patternFillColor;

    switch (_patternType)
    {
        case kPPBackgroundPatternType_DiagonalLines:
        {
            patternFillColor = [NSColor ppDiagonalLinePatternColorWithLineWidth: _patternSize
                                                                        color1: _color1
                                                                        color2: _color2];
        }
        break;

        case kPPBackgroundPatternType_IsometricLines:
        {
            patternFillColor = [NSColor ppIsometricLinePatternColorWithLineWidth: _patternSize
                                                                        color1: _color1
                                                                        color2: _color2];
        }
        break;

        case kPPBackgroundPatternType_Checkerboard:
        {
            patternFillColor =
                            [NSColor ppCheckerboardPatternColorWithBoxDimension: _patternSize
                                                                        color1: _color1
                                                                        color2: _color2];
        }
        break;

        case kPPBackgroundPatternType_DiagonalCheckerboard:
        {
            patternFillColor =
                    [NSColor ppDiagonalCheckerboardPatternColorWithBoxDimension: _patternSize
                                                                        color1: _color1
                                                                        color2: _color2];
        }
        break;

        case kPPBackgroundPatternType_IsometricCheckerboard:
        {
            patternFillColor =
                    [NSColor ppIsometricCheckerboardPatternColorWithBoxDimension: _patternSize
                                                                        color1: _color1
                                                                        color2: _color2];
        }
        break;

        case kPPBackgroundPatternType_Solid:
        default:
        {
            patternFillColor = _color1;
        }
        break;
    }

    if (_patternFillColor)
    {
        [_patternFillColor release];
    }

    _patternFillColor = [patternFillColor retain];
}

@end
