/*
    PPImageSizePresets.m

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

#import "PPImageSizePresets.h"

#import "PPDefines.h"
#import "PPGeometry.h"
#import "NSFileManager_PPUtilities.h"


#define kCustomPresetsFilename                      @"ImageSizePresets.plist"

#define kCustomPresetsDictKey_PresetStrings         @"Preset Strings"

#define kDefaultPresetStrings                       [NSArray arrayWithObjects:              \
                                                                @"Small (32x32)",           \
                                                                @"Medium (64x64)",          \
                                                                @"Large (128x128)",         \
                                                                @"Extra Large (256x256)",   \
                                                                nil]

NSString *PPImageSizePresetsNotification_UpdatedPresets =
                                            @"PPImageSizePresetsNotification_UpdatedPresets";

static NSString *gCustomPresetsFilePath = nil;
static NSArray *gDefaultPresetStrings = nil, *gPresetStrings = nil;


static bool SetupDefaultPresetStrings(void);
static bool SetupCustomPresetsFilePath(void);
static void LoadPresetStrings(void);
static void SavePresetStrings(NSArray *presetStrings);
static NSArray *VerifiedPresetStringsForPresetStrings(NSArray *presetStrings);


@implementation PPImageSizePresets

+ (void) initialize
{
    if ([self class] != [PPImageSizePresets class])
    {
        return;
    }

    SetupDefaultPresetStrings();
    LoadPresetStrings();
}

+ (NSArray *) presetStrings
{
    return gPresetStrings;
}

+ (void) setPresetStrings: (NSArray *) presetStrings
{
    SavePresetStrings(presetStrings);
    LoadPresetStrings();

    [[NSNotificationCenter defaultCenter]
                                postNotificationName:
                                                PPImageSizePresetsNotification_UpdatedPresets
                                object: nil];
}

+ (NSArray *) appDefaultPresetStrings
{
    return gDefaultPresetStrings;
}

@end

#pragma mark Public functions

NSString *PPImageSizePresets_PresetStringForNameAndSize(NSString *name, NSSize size)
{
    if (![name length] || PPGeometry_IsZeroSize(size))
    {
        return nil;
    }

    return [NSString stringWithFormat: @"%@ (%dx%d)",
                                        name, (int) size.width, (int) size.height];
}

NSString *PPImageSizePresets_NameForPresetString(NSString *presetString)
{
    NSRange cutoffRange = [presetString rangeOfString: @" (" options: NSBackwardsSearch];

    if (!cutoffRange.length)
    {
        goto ERROR;
    }

    return [presetString substringToIndex: cutoffRange.location];

ERROR:
    return nil;
}

NSSize PPImageSizePresets_SizeForPresetString(NSString *presetString)
{
    NSRange range, replacementRange;
    NSMutableString *sizeString;
    NSSize presetSize;

    range = [presetString rangeOfString: @"(" options: NSBackwardsSearch];

    if (!range.length)
    {
        goto ERROR;
    }

    sizeString =
        [NSMutableString stringWithString: [presetString substringFromIndex: range.location]];

    replacementRange = NSMakeRange(0, [sizeString length]);

    if (!range.length)
    {
        goto ERROR;
    }

    [sizeString replaceOccurrencesOfString: @"("
                    withString: @"{"
                    options: 0
                    range: replacementRange];

    [sizeString replaceOccurrencesOfString: @")"
                    withString: @"}"
                    options: 0
                    range: replacementRange];

    [sizeString replaceOccurrencesOfString: @"x"
                    withString: @","
                    options: 0
                    range: replacementRange];

    presetSize = NSSizeFromString(sizeString);

    if (PPGeometry_IsZeroSize(presetSize)
        || (presetSize.width > kMaxCanvasDimension)
        || (presetSize.height > kMaxCanvasDimension))
    {
        goto ERROR;
    }

    return presetSize;

ERROR:
    return NSZeroSize;
}

#pragma mark Private functions

static bool SetupDefaultPresetStrings(void)
{
    if (gDefaultPresetStrings)
    {
        return YES;
    }

    gDefaultPresetStrings =
                        [VerifiedPresetStringsForPresetStrings(kDefaultPresetStrings) retain];

    if (!gDefaultPresetStrings)
        goto ERROR;

    return YES;

ERROR:
    return NO;
}

static bool SetupCustomPresetsFilePath(void)
{
    if (gCustomPresetsFilePath)
    {
        return YES;
    }

    gCustomPresetsFilePath =
            [[NSFileManager ppFilepathForSupportFileWithName: kCustomPresetsFilename] retain];

    if (!gCustomPresetsFilePath)
        goto ERROR;

    return YES;

ERROR:
    return NO;
}

static void LoadPresetStrings(void)
{
    NSDictionary *customPresetsDict;
    NSArray *customPresetStrings;

    [gPresetStrings autorelease];
    gPresetStrings = nil;

    if (!gCustomPresetsFilePath && !SetupCustomPresetsFilePath())
    {
        goto ERROR;
    }

    if (![[NSFileManager defaultManager] isReadableFileAtPath: gCustomPresetsFilePath])
    {
        goto ERROR;
    }

    customPresetsDict = [NSDictionary dictionaryWithContentsOfFile: gCustomPresetsFilePath];
    customPresetStrings = [customPresetsDict objectForKey: kCustomPresetsDictKey_PresetStrings];

    if (![customPresetStrings isKindOfClass: [NSArray class]])
    {
        goto ERROR;
    }

    gPresetStrings = [VerifiedPresetStringsForPresetStrings(customPresetStrings) retain];

    if (![gPresetStrings count])
    {
        goto ERROR;
    }

    return;

ERROR:
    gPresetStrings = [gDefaultPresetStrings retain];
}

static void SavePresetStrings(NSArray *presetStrings)
{
    NSFileManager *fileManager;

    if (!gCustomPresetsFilePath && !SetupCustomPresetsFilePath())
    {
        goto ERROR;
    }

    fileManager = [NSFileManager defaultManager];

    presetStrings = VerifiedPresetStringsForPresetStrings(presetStrings);

    if (![presetStrings count] || [presetStrings isEqualToArray: gDefaultPresetStrings])
    {
        [fileManager ppDeleteSupportFileAtPath: gCustomPresetsFilePath];
    }
    else
    {
        NSDictionary *customPresetsDict;

        if (![fileManager ppVerifySupportFileDirectory])
        {
            goto ERROR;
        }

        customPresetsDict = [NSDictionary dictionaryWithObject: presetStrings
                                            forKey: kCustomPresetsDictKey_PresetStrings];

        [customPresetsDict writeToFile: gCustomPresetsFilePath atomically: YES];
    }

    return;

ERROR:
    return;
}

static NSArray *VerifiedPresetStringsForPresetStrings(NSArray *presetStrings)
{
    NSMutableArray *verifiedPresetStrings;
    NSEnumerator *presetEnumerator;
    NSString *presetString;

    if (![presetStrings count])
    {
        goto ERROR;
    }

    verifiedPresetStrings = [NSMutableArray array];

    if (!verifiedPresetStrings)
        goto ERROR;

    presetEnumerator = [presetStrings objectEnumerator];

    while (presetString = [presetEnumerator nextObject])
    {
        if ([presetString isKindOfClass: [NSString class]]
                && !PPGeometry_IsZeroSize(PPImageSizePresets_SizeForPresetString(presetString)))
        {
            [verifiedPresetStrings addObject: presetString];
        }
    }

    if ([presetStrings count] != [verifiedPresetStrings count])
    {
        presetStrings = [NSArray arrayWithArray: verifiedPresetStrings];

        if (!presetStrings)
        {
            presetStrings = verifiedPresetStrings;
        }
    }

    return presetStrings;

ERROR:
    return nil;
}
