/*
    PPPatternPresets.m

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

#import "PPPatternPresets.h"

#import "PPPresettablePatternProtocol.h"
#import "NSFileManager_PPUtilities.h"


#define kPatternPresetsDictKey_Patterns     @"Patterns"


NSString *PPPatternPresetsNotification_UpdatedPresets =
                                                @"PPPatternPresetsNotification_UpdatedPresets";


static NSString *StoredPresetsFilepathForFilenameAndFiletype(NSString *storedPresetsFilename,
                                                                NSString *presetsFiletype);


@interface PPPatternPresets (PrivateMethods)

- (NSArray *) verifiedPatternsFromArray: (NSArray *) importedArray;

- (bool) savePatterns: (NSArray *) patterns toFile: (NSString *) filepath;
- (NSArray *) patternsFromFile: (NSString *) filepath;

- (void) loadPatternsFromStoredPresets;
- (void) savePatternsToStoredPresets;

- (void) postNotification_UpdatedPresets;

@end

@implementation PPPatternPresets

+ sharedPresets
{
    // must be overridden by subclasses - base implementation returns nil
    return nil;
}

- initWithPresettablePatternClass: (Class) patternClass
    storedPresetsFilename: (NSString *) storedPresetsFilename
    presetsFiletype: (NSString *) presetsFiletype
{
    NSArray *presetsFiletypes;
    NSString *storedPresetsFilepath;

    self = [super init];

    if (!self)
        goto ERROR;

    if (![patternClass conformsToProtocol: @protocol(PPPresettablePattern)]
        || ![storedPresetsFilename length]
        || ![presetsFiletype length])
    {
        goto ERROR;
    }

    presetsFiletypes = [NSArray arrayWithObject: presetsFiletype];

    storedPresetsFilepath =
            StoredPresetsFilepathForFilenameAndFiletype(storedPresetsFilename, presetsFiletype);

    if (![presetsFiletypes count]
        || ![storedPresetsFilepath length])
    {
        goto ERROR;
    }

    _patternClass = [patternClass retain];

    _presetsFiletypes = [presetsFiletypes retain];

    _storedPresetsFilepath = [storedPresetsFilepath retain];

    [self loadPatternsFromStoredPresets];

    return self;

ERROR:
    [self release];

    return nil;
}

- (void) dealloc
{
    [_patternClass release];

    [_patterns release];

    [_presetsFiletypes release];

    [_storedPresetsFilepath release];

    [super dealloc];
}

- (NSArray *) patterns
{
    return _patterns;
}

- (void) setPatterns: (NSArray *) patterns
{
    [_patterns autorelease];
    _patterns = [[self verifiedPatternsFromArray: patterns] retain];

    [self savePatternsToStoredPresets];
    [self loadPatternsFromStoredPresets];

    [self postNotification_UpdatedPresets];
}

- (bool) savePatternsToPresetsFile: (NSString *) filepath
{
    return [self savePatterns: _patterns toFile: filepath];
}

- (void) addPatternsFromPresetsFile: (NSString *) filepath
{
    NSArray *importedPatterns, *newPresets;
    int numPresets, presetIndex;
    NSMutableArray *patternsToAdd;
    NSEnumerator *importedPatternsEnumerator;
    id <PPPresettablePattern> pattern;
    bool presetsContainPattern;

    importedPatterns = [self patternsFromFile: filepath];

    if (![importedPatterns count])
    {
        goto ERROR;
    }

    numPresets = [_patterns count];

    if (!numPresets)
    {
        [self setPatterns: importedPatterns];
        return;
    }

    patternsToAdd = [NSMutableArray array];

    if (!patternsToAdd)
        goto ERROR;

    importedPatternsEnumerator = [importedPatterns objectEnumerator];

    while (pattern = [importedPatternsEnumerator nextObject])
    {
        presetsContainPattern = NO;

        presetIndex = numPresets - 1;

        while ((presetIndex >= 0) && !presetsContainPattern)
        {
            if ([pattern isEqualToPresettablePattern: [_patterns objectAtIndex: presetIndex]])
            {
                presetsContainPattern = YES;
            }

            presetIndex--;
        }

        if (!presetsContainPattern)
        {
            [patternsToAdd addObject: pattern];
        }
    }

    if (![patternsToAdd count])
    {
        return;
    }

    newPresets = [_patterns arrayByAddingObjectsFromArray: patternsToAdd];

    if (!newPresets)
        goto ERROR;

    [self setPatterns: newPresets];

    return;

ERROR:
    return;
}

- (NSArray *) presetsFiletypes
{
    return _presetsFiletypes;
}

#pragma mark Private methods

- (NSArray *) verifiedPatternsFromArray: (NSArray *) importedPatterns
{
    int numImportedPatterns;
    NSMutableArray *verifiedPatterns;
    NSEnumerator *patternEnumerator;
    id pattern;
    NSArray *returnedPatterns;

    numImportedPatterns = [importedPatterns count];

    if (!numImportedPatterns)
        goto ERROR;

    verifiedPatterns = [NSMutableArray array];

    if (!verifiedPatterns)
        goto ERROR;

    patternEnumerator = [importedPatterns objectEnumerator];

    while (pattern = [patternEnumerator nextObject])
    {
        if ([pattern isKindOfClass: _patternClass])
        {
            [verifiedPatterns addObject: pattern];
        }
    }

    if ([verifiedPatterns count] == numImportedPatterns)
    {
        returnedPatterns = importedPatterns;
    }
    else
    {
        returnedPatterns = [NSArray arrayWithArray: verifiedPatterns];

        if (!returnedPatterns)
        {
            returnedPatterns = verifiedPatterns;
        }
    }

    return returnedPatterns;

ERROR:
    return nil;
}

- (bool) savePatterns: (NSArray *) patterns toFile: (NSString *) filepath
{
    NSDictionary *presetsDict;

    patterns = [self verifiedPatternsFromArray: patterns];

    if (![patterns count] || ![filepath length])
    {
        goto ERROR;
    }

    presetsDict = [NSDictionary dictionaryWithObject: patterns
                                forKey: kPatternPresetsDictKey_Patterns];

    if (!presetsDict)
        goto ERROR;

    return [NSKeyedArchiver archiveRootObject: presetsDict toFile: filepath];

ERROR:
    return NO;
}

- (NSArray *) patternsFromFile: (NSString *) filepath;
{
    NSDictionary *presetsDict;
    NSArray *patterns;

    if (![filepath length]
        || (![[NSFileManager defaultManager] isReadableFileAtPath: filepath]))
    {
        goto ERROR;
    }

    presetsDict = [NSKeyedUnarchiver unarchiveObjectWithFile: filepath];

    if (![presetsDict isKindOfClass: [NSDictionary class]])
    {
        goto ERROR;
    }

    patterns = [presetsDict objectForKey: kPatternPresetsDictKey_Patterns];

    if (![patterns isKindOfClass: [NSArray class]])
    {
        goto ERROR;
    }

    patterns = [self verifiedPatternsFromArray: patterns];

    if (![patterns count])
    {
        goto ERROR;
    }

    return patterns;

ERROR:
    return nil;
}

- (void) loadPatternsFromStoredPresets
{
    [_patterns release];
    _patterns = [[self patternsFromFile: _storedPresetsFilepath] retain];
}

- (void) savePatternsToStoredPresets
{
    NSFileManager *fileManager = [NSFileManager defaultManager];

    if ([_patterns count])
    {
        if (![fileManager ppVerifySupportFileDirectory])
        {
            goto ERROR;
        }

        [self savePatterns: _patterns toFile: _storedPresetsFilepath];
    }
    else
    {
        [fileManager ppDeleteSupportFileAtPath: _storedPresetsFilepath];
    }

    return;

ERROR:
    return;
}

- (void) postNotification_UpdatedPresets
{
    [[NSNotificationCenter defaultCenter] postNotificationName:
                                                    PPPatternPresetsNotification_UpdatedPresets
                                            object: self];
}

@end

#pragma mark Private functions

static NSString *StoredPresetsFilepathForFilenameAndFiletype(NSString *storedPresetsFilename,
                                                                NSString *presetsFiletype)
{
    if (![storedPresetsFilename length]
        || ![presetsFiletype length])
    {
        goto ERROR;
    }

    if (![[storedPresetsFilename pathExtension] length])
    {
        storedPresetsFilename =
            [storedPresetsFilename stringByAppendingPathExtension: presetsFiletype];

        if (!storedPresetsFilename)
            goto ERROR;
    }

    return [NSFileManager ppFilepathForSupportFileWithName: storedPresetsFilename];

ERROR:
    return nil;
}
