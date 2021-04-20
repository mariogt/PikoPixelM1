/*
    PPUserDefaults.m

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

#import "PPUserDefaults.h"

#import "PPUserDefaultsInitialValues.h"
#import "PPBackgroundPattern.h"
#import "PPGridPattern.h"
#import "NSColor_PPUtilities.h"


#define kPPUserDefaultsKey_DefaultBackgroundPattern         @"DefaultBackgroundPattern"
#define kPPUserDefaultsKey_DefaultGridPattern               @"DefaultGridPattern"
#define kPPUserDefaultsKey_DefaultGridVisibility            @"DefaultGridVisibility"
#define kPPUserDefaultsKey_ShouldDisplayFlattenedSaveNotice @"ShouldDisplayFlattenedSaveNotice"
#define kPPUserDefaultsKey_ColorPickerPopupPanelMode        @"DefaultColorPickerPopupPanelMode"
#define kPPUserDefaultsKey_ColorPickerPopupPanelContentSize \
                                                    @"DefaultColorPickerPopupPanelContentSize"


static NSDictionary *DefaultsRegistrationDictionary(void);
static NSString *EnabledStateDefaultsKeyForPanelWithNibName(NSString *nibName);


@implementation PPUserDefaults

+ (void) initialize
{
    if (self != [PPUserDefaults class])
    {
        return;
    }

    [[NSUserDefaults standardUserDefaults] registerDefaults: DefaultsRegistrationDictionary()];
}

+ (void) setBackgroundPattern: (PPBackgroundPattern *) backgroundPattern
{
    NSData *backgroundPatternArchivedData;
    NSUserDefaults *userDefaults;

    if (!backgroundPattern)
        goto ERROR;

    backgroundPatternArchivedData = [backgroundPattern archivedData];

    if (!backgroundPatternArchivedData)
        goto ERROR;

    userDefaults = [NSUserDefaults standardUserDefaults];

    [userDefaults setObject: backgroundPatternArchivedData
                    forKey: kPPUserDefaultsKey_DefaultBackgroundPattern];

    [userDefaults synchronize];

    return;

ERROR:
    return;
}

+ (PPBackgroundPattern *) backgroundPattern
{
    NSData *backgroundPatternArchivedData =
            [[NSUserDefaults standardUserDefaults]
                                            objectForKey:
                                                kPPUserDefaultsKey_DefaultBackgroundPattern];

    if (!backgroundPatternArchivedData)
        goto ERROR;

    return
        [PPBackgroundPattern backgroundPatternWithArchivedData: backgroundPatternArchivedData];

ERROR:
    return nil;
}

+ (void) setGridPattern: (PPGridPattern *) gridPattern
            andGridVisibility: (bool) shouldDisplayGrid
{
    NSData *gridPatternArchivedData;
    NSUserDefaults *userDefaults;

    if (!gridPattern)
        goto ERROR;

    gridPatternArchivedData = [gridPattern archivedData];

    if (!gridPatternArchivedData)
        goto ERROR;

    userDefaults = [NSUserDefaults standardUserDefaults];

    [userDefaults setObject: gridPatternArchivedData
                    forKey: kPPUserDefaultsKey_DefaultGridPattern];

    [userDefaults setBool: (shouldDisplayGrid) ? YES : NO
                    forKey: kPPUserDefaultsKey_DefaultGridVisibility];

    [userDefaults synchronize];

    return;

ERROR:
    return;
}

+ (PPGridPattern *) gridPattern
{
    NSData *gridPatternArchivedData =
                [[NSUserDefaults standardUserDefaults] objectForKey:
                                                        kPPUserDefaultsKey_DefaultGridPattern];

    if (!gridPatternArchivedData)
        goto ERROR;

    return [PPGridPattern gridPatternWithArchivedData: gridPatternArchivedData];

ERROR:
    return nil;
}

+ (bool) gridVisibility
{
    return [[NSUserDefaults standardUserDefaults] boolForKey:
                                                    kPPUserDefaultsKey_DefaultGridVisibility];
}

+ (void) setEnabledState: (bool) panelEnabledState forPanelWithNibName: (NSString *) nibName
{
    NSString *panelEnabledStateDefaultsKey =
                                    EnabledStateDefaultsKeyForPanelWithNibName(nibName);

    if (!panelEnabledStateDefaultsKey)
        return;

    [[NSUserDefaults standardUserDefaults] setBool: (panelEnabledState) ? YES : NO
                                            forKey: panelEnabledStateDefaultsKey];
}

+ (bool) enabledStateForPanelWithNibName: (NSString *) nibName
{
    NSString *panelEnabledStateDefaultsKey =
                                    EnabledStateDefaultsKeyForPanelWithNibName(nibName);

    if (!panelEnabledStateDefaultsKey)
    {
        return NO;
    }

    return [[NSUserDefaults standardUserDefaults] boolForKey: panelEnabledStateDefaultsKey];
}

+ (void) registerDefaultEnabledState: (bool) panelEnabledState
            forPanelWithNibName: (NSString *) nibName
{
    NSString *panelEnabledStateDefaultsKey;
    NSNumber *panelEnabledStateNumber;
    NSDictionary *registrationDictionary;

    panelEnabledStateDefaultsKey = EnabledStateDefaultsKeyForPanelWithNibName(nibName);
    panelEnabledStateNumber = [NSNumber numberWithBool: (panelEnabledState) ? YES : NO];

    if (!panelEnabledStateDefaultsKey || !panelEnabledStateNumber)
    {
        return;
    }

    registrationDictionary = [NSDictionary dictionaryWithObject: panelEnabledStateNumber
                                                        forKey: panelEnabledStateDefaultsKey];

    if (!registrationDictionary)
        return;

    [[NSUserDefaults standardUserDefaults] registerDefaults: registrationDictionary];
}

+ (void) setShouldDisplayFlattenedSaveNotice: (bool) shouldDisplayFlattenedSaveNotice
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];

    [userDefaults setBool: (shouldDisplayFlattenedSaveNotice) ? YES : NO
                    forKey: kPPUserDefaultsKey_ShouldDisplayFlattenedSaveNotice];

    [userDefaults synchronize];
}

+ (bool) shouldDisplayFlattenedSaveNotice
{
    NSNumber *displayFlagAsNumber =
        [[NSUserDefaults standardUserDefaults]
                            objectForKey: kPPUserDefaultsKey_ShouldDisplayFlattenedSaveNotice];

    if (!displayFlagAsNumber)
    {
        return kUserDefaultsInitialValue_ShouldDisplayFlattenedSaveNotice;
    }

    return [displayFlagAsNumber boolValue];
}

+ (void) setColorPickerPopupPanelMode: (int) panelMode
{
    [[NSUserDefaults standardUserDefaults]
                                        setInteger: panelMode
                                        forKey: kPPUserDefaultsKey_ColorPickerPopupPanelMode];
}

+ (int) colorPickerPopupPanelMode
{
    NSNumber *panelModeAsNumber =
            [[NSUserDefaults standardUserDefaults]
                                objectForKey: kPPUserDefaultsKey_ColorPickerPopupPanelMode];

    if (!panelModeAsNumber)
    {
        return kUserDefaultsInitialValue_ColorPickerPopupPanelMode;
    }

    return [panelModeAsNumber intValue];
}

+ (void) setColorPickerPopupPanelContentSize: (NSSize) size
{
    NSString *sizeAsString = NSStringFromSize(size);

    if (!sizeAsString)
        return;

    [[NSUserDefaults standardUserDefaults]
                                setObject: sizeAsString
                                forKey: kPPUserDefaultsKey_ColorPickerPopupPanelContentSize];
}

+ (NSSize) colorPickerPopupPanelContentSize
{
    NSString *sizeAsString;
    NSSize size;

    sizeAsString =
        [[NSUserDefaults standardUserDefaults]
                            objectForKey: kPPUserDefaultsKey_ColorPickerPopupPanelContentSize];

    if (sizeAsString)
    {
        size = NSSizeFromString(sizeAsString);
    }
    else
    {
        NSColorPanel *sharedColorPanel;
        int sharedColorPanelMode;

        sharedColorPanel = [NSColorPanel sharedColorPanel];
        sharedColorPanelMode = [sharedColorPanel mode];

        [sharedColorPanel setMode: [self colorPickerPopupPanelMode]];
        size = [[NSColorPanel sharedColorPanel] frame].size;
        [sharedColorPanel setMode: sharedColorPanelMode];
    }

    return size;
}

@end

#pragma mark Private functions

static NSDictionary *DefaultsRegistrationDictionary(void)
{
    NSData *defaultBackgroundPatternArchivedData, *defaultGridPatternArchivedData;
    NSDictionary *defaultValues;

    defaultBackgroundPatternArchivedData =
                                [kUserDefaultsInitialValue_BackgroundPattern archivedData];

    defaultGridPatternArchivedData = [kUserDefaultsInitialValue_GridPattern archivedData];

    defaultValues =
        [NSDictionary dictionaryWithObjectsAndKeys:

                            defaultBackgroundPatternArchivedData,
                        kPPUserDefaultsKey_DefaultBackgroundPattern,

                            defaultGridPatternArchivedData,
                        kPPUserDefaultsKey_DefaultGridPattern,

                            [NSNumber numberWithBool: kUserDefaultsInitialValue_GridVisibility],
                        kPPUserDefaultsKey_DefaultGridVisibility,

                            [NSNumber numberWithBool:
                                    kUserDefaultsInitialValue_ShouldDisplayFlattenedSaveNotice],
                        kPPUserDefaultsKey_ShouldDisplayFlattenedSaveNotice,

                            [NSNumber numberWithInt:
                                        kUserDefaultsInitialValue_ColorPickerPopupPanelMode],
                        kPPUserDefaultsKey_ColorPickerPopupPanelMode,

                            // default value for ColorPickerPopupPanelContentSize is calculated
                            // dynamically, so no entry here

                            nil];

    return defaultValues;
}

static NSString *EnabledStateDefaultsKeyForPanelWithNibName(NSString *nibName)
{
    return [nibName stringByAppendingString: @"EnabledState"];
}
