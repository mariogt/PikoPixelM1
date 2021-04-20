/*
    PPHotkeys.m

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

#import "PPHotkeys.h"

#import "PPKeyboardLayout.h"
#import "PPDefines.h"
#import "PPKeyConstants.h"
#import "NSFileManager_PPUtilities.h"


#define kHotkeysDictResourceType            @"plist"
#define kHotkeysDictResourcePrefix          @"Hotkeys_"

#define kApplicationSupportFolderName       @"PikoPixel"
#define kCustomHotkeysDictFilename          @"CustomHotkeys.plist"


#define kHotkeysDictKey_PencilTool                      @"PencilTool"
#define kHotkeysDictKey_EraserTool                      @"EraserTool"
#define kHotkeysDictKey_FillTool                        @"FillTool"
#define kHotkeysDictKey_LineTool                        @"LineTool"
#define kHotkeysDictKey_RectTool                        @"RectTool"
#define kHotkeysDictKey_OvalTool                        @"OvalTool"
#define kHotkeysDictKey_FreehandSelectTool              @"FreehandSelectTool"
#define kHotkeysDictKey_RectSelectTool                  @"RectSelectTool"
#define kHotkeysDictKey_MagicWandTool                   @"MagicWandTool"
#define kHotkeysDictKey_ColorSamplerTool                @"ColorSamplerTool"
#define kHotkeysDictKey_MoveTool                        @"MoveTool"
#define kHotkeysDictKey_MagnifierTool                   @"MagnifierTool"

#define kHotkeysDictKey_NavigatorPopup                  @"NavigatorPopup"
#define kHotkeysDictKey_ToolsPopup                      @"ToolsPopup"
#define kHotkeysDictKey_ColorPickerPopup                @"ColorPickerPopup"
#define kHotkeysDictKey_LayerControlsPopup              @"LayerControlsPopup"

#define kHotkeysDictKey_NavigatorPopupAlternate         @"NavigatorPopup_Alternate"
#define kHotkeysDictKey_ToolsPopupAlternate             @"ToolsPopup_Alternate"
#define kHotkeysDictKey_ColorPickerPopupAlternate       @"ColorPickerPopup_Alternate"
#define kHotkeysDictKey_LayerControlsPopupAlternate     @"LayerControlsPopup_Alternate"

#define kHotkeysDictKey_SwitchCanvasViewMode            @"SwitchCanvasViewMode"
#define kHotkeysDictKey_SwitchLayerOperationTarget      @"SwitchLayerOperationTarget"
#define kHotkeysDictKey_ToggleActivePanels              @"ToggleActivePanels"
#define kHotkeysDictKey_ToggleColorPickerPanel          @"ToggleColorPickerPanel"
#define kHotkeysDictKey_ZoomIn                          @"ZoomIn"
#define kHotkeysDictKey_ZoomOut                         @"ZoomOut"
#define kHotkeysDictKey_ZoomToFit                       @"ZoomToFit"
#define kHotkeysDictKey_BlinkDocumentLayers             @"BlinkDocumentLayers"


NSString *gHotkeys[kNumPPHotkeyTypes];
NSArray *gHotkeyDictKeys = nil;
NSString *PPHotkeysNotification_UpdatedHotkeys = @"PPHotkeysNotification_UpdatedHotkeys";
static NSDictionary *gDefaultHotkeysDict = nil;
static NSString *gCustomHotkeysDictResourcePath = nil;


static bool SetupHotkeyDictKeysArray(void);
static bool SetupDefaultHotkeysDictForCurrentKeyboardLayout(void);
static bool SetupCustomHotkeysDictResourcePath(void);

static NSString *HotkeysDictResourcePathForLanguageCode(NSString *languageCode);
static NSDictionary *HotkeysDictAtFilepath(NSString *filepath);
static void LoadHotkeysArrayFromDict(NSDictionary *hotkeysDict);

static void SaveCustomHotkeysDict(NSDictionary *hotkeysDict);
static void DeleteCustomHotkeysDict(void);

static NSString *ModifiedHotkeyForXMLKey(NSString *xmlKey);
static NSString *ModifiedXMLKeyForHotkey(NSString *hotkey);


@implementation PPHotkeys

+ (void) initialize
{
    NSDictionary *hotkeysDict;

    if ([self class] != [PPHotkeys class])
    {
        return;
    }

    SetupHotkeyDictKeysArray();
    SetupDefaultHotkeysDictForCurrentKeyboardLayout();
    SetupCustomHotkeysDictResourcePath();

    hotkeysDict = HotkeysDictAtFilepath(gCustomHotkeysDictResourcePath);

    if (!hotkeysDict)
    {
        hotkeysDict = gDefaultHotkeysDict;
    }

    LoadHotkeysArrayFromDict(hotkeysDict);
}

+ (void) setupGlobals
{
    // this gets called multiple times when the classes that depend on gHotkeys[] are setting
    // up themselves - the actual setup is done in +initialize (called automatically the first
    // time a message is received)
}

+ (NSArray *) availableKeyboardLayoutLanguageCodes
{
    static NSMutableArray *languageCodes = nil;
    int resourcePrefixLength;
    NSArray *resourcePaths;
    NSEnumerator *resourcePathEnumerator;
    NSString *resourcePath, *resourceFilename;

    if (languageCodes)
    {
        return languageCodes;
    }

    languageCodes = [[NSMutableArray array] retain];

    resourcePrefixLength = [kHotkeysDictResourcePrefix length];

    resourcePaths = [NSBundle pathsForResourcesOfType: kHotkeysDictResourceType
                                inDirectory: [[NSBundle mainBundle] resourcePath]];

    resourcePathEnumerator = [resourcePaths objectEnumerator];

    while (resourcePath = [resourcePathEnumerator nextObject])
    {
        resourceFilename = [resourcePath lastPathComponent];

        if ([resourceFilename hasPrefix: kHotkeysDictResourcePrefix])
        {
            resourceFilename = [resourceFilename stringByDeletingPathExtension];

            if ([resourceFilename length] > resourcePrefixLength)
            {
                [languageCodes addObject:
                                [resourceFilename substringFromIndex: resourcePrefixLength]];
            }
        }
    }

    [languageCodes sortUsingSelector: @selector(compare:)];

    return languageCodes;
}

+ (NSDictionary *) hotkeysDictForLanguageCode: (NSString *) languageCode
{
    NSString *hotkeysDictResourcePath;
    NSDictionary *hotkeysDict = nil;

    hotkeysDictResourcePath = HotkeysDictResourcePathForLanguageCode(languageCode);

    if (hotkeysDictResourcePath)
    {
        hotkeysDict = HotkeysDictAtFilepath(hotkeysDictResourcePath);
    }

    if (!hotkeysDictResourcePath || !hotkeysDict)
    {
        hotkeysDictResourcePath =
                    HotkeysDictResourcePathForLanguageCode(kDefaultKeyboardLayoutLanguageCode);

        if (!hotkeysDictResourcePath)
            goto ERROR;

        hotkeysDict = HotkeysDictAtFilepath(hotkeysDictResourcePath);

        if (!hotkeysDict)
            goto ERROR;
    }

    return hotkeysDict;

ERROR:
    return gDefaultHotkeysDict;
}

+ (bool) setHotkeysFromDict: (NSDictionary *) hotkeysDict
{
    if (![hotkeysDict count])
    {
        goto ERROR;
    }

    LoadHotkeysArrayFromDict(hotkeysDict);

    if (![hotkeysDict isEqualToDictionary: gDefaultHotkeysDict])
    {
        SaveCustomHotkeysDict(hotkeysDict);
    }
    else
    {
        DeleteCustomHotkeysDict();
    }

    return YES;

ERROR:
    return NO;
}

+ (NSString *) localizedBacktickKeyEquivalent
{
    // gDefaultHotkeysDict is loaded from the presets matching the current keyboard language
    // layout, and the default 'switch canvas view mode' hotkey (almost) always matches
    // the key in the position directly above the Tab key (on US layouts, it's the backtick
    // key: `)

    return [gDefaultHotkeysDict objectForKey: kHotkeysDictKey_SwitchCanvasViewMode];
}

@end

#pragma mark Private functions

static bool SetupHotkeyDictKeysArray(void)
{
    NSArray *hotkeyDictKeys;

    if (gHotkeyDictKeys)
    {
        return YES;
    }

    hotkeyDictKeys = [NSArray arrayWithObjects:
                                    // Must match PPHotkeyType values

                                    kHotkeysDictKey_PencilTool,
                                    kHotkeysDictKey_EraserTool,
                                    kHotkeysDictKey_FillTool,
                                    kHotkeysDictKey_LineTool,
                                    kHotkeysDictKey_RectTool,
                                    kHotkeysDictKey_OvalTool,
                                    kHotkeysDictKey_FreehandSelectTool,
                                    kHotkeysDictKey_RectSelectTool,
                                    kHotkeysDictKey_MagicWandTool,
                                    kHotkeysDictKey_ColorSamplerTool,
                                    kHotkeysDictKey_MoveTool,
                                    kHotkeysDictKey_MagnifierTool,

                                    kHotkeysDictKey_ToolsPopup,
                                    kHotkeysDictKey_ColorPickerPopup,
                                    kHotkeysDictKey_LayerControlsPopup,
                                    kHotkeysDictKey_NavigatorPopup,

                                    kHotkeysDictKey_ToolsPopupAlternate,
                                    kHotkeysDictKey_ColorPickerPopupAlternate,
                                    kHotkeysDictKey_LayerControlsPopupAlternate,
                                    kHotkeysDictKey_NavigatorPopupAlternate,

                                    kHotkeysDictKey_SwitchCanvasViewMode,
                                    kHotkeysDictKey_SwitchLayerOperationTarget,
                                    kHotkeysDictKey_ToggleActivePanels,
                                    kHotkeysDictKey_ToggleColorPickerPanel,
                                    kHotkeysDictKey_ZoomIn,
                                    kHotkeysDictKey_ZoomOut,
                                    kHotkeysDictKey_ZoomToFit,
                                    kHotkeysDictKey_BlinkDocumentLayers,

                                    nil];

    if ([hotkeyDictKeys count] != kNumPPHotkeyTypes)
    {
        goto ERROR;
    }

    gHotkeyDictKeys = [hotkeyDictKeys retain];

    return YES;

ERROR:
    return NO;
}

static bool SetupDefaultHotkeysDictForCurrentKeyboardLayout(void)
{
    NSString *keyboardLayoutLanguageCode;

    if (gDefaultHotkeysDict)
    {
        return YES;
    }

    keyboardLayoutLanguageCode = PPKeyboardLayout_LanguageLocaleString();

    if (![keyboardLayoutLanguageCode length])
    {
        keyboardLayoutLanguageCode = kDefaultKeyboardLayoutLanguageCode;
    }

    gDefaultHotkeysDict =
                [[PPHotkeys hotkeysDictForLanguageCode: keyboardLayoutLanguageCode] retain];

    if (!gDefaultHotkeysDict)
    {
        if ([keyboardLayoutLanguageCode isEqualToString: kDefaultKeyboardLayoutLanguageCode])
        {
            goto ERROR;
        }

        gDefaultHotkeysDict =
            [[PPHotkeys hotkeysDictForLanguageCode: kDefaultKeyboardLayoutLanguageCode] retain];

        if (!gDefaultHotkeysDict)
            goto ERROR;
    }

    return YES;

ERROR:
    return NO;
}

static bool SetupCustomHotkeysDictResourcePath(void)
{
    if (gCustomHotkeysDictResourcePath)
    {
        return YES;
    }

    gCustomHotkeysDictResourcePath =
        [[NSFileManager ppFilepathForSupportFileWithName: kCustomHotkeysDictFilename] retain];

    if (!gCustomHotkeysDictResourcePath)
        goto ERROR;

    return YES;

ERROR:
    return NO;
}

static NSString *HotkeysDictResourcePathForLanguageCode(NSString *languageCode)
{
    NSString *filename;

    if (![languageCode length])
    {
        goto ERROR;
    }

    filename = [NSString stringWithFormat: @"%@%@.%@",
                                            kHotkeysDictResourcePrefix,
                                            languageCode,
                                            kHotkeysDictResourceType];

    if (!filename)
        goto ERROR;

    return [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent: filename];

ERROR:
    return nil;
}

static NSDictionary *HotkeysDictAtFilepath(NSString *filepath)
{
    NSDictionary *xmlKeysDict;
    NSMutableDictionary *hotkeysDict;
    int i;
    NSString *dictKey, *hotkey;

    if (![[NSFileManager defaultManager] isReadableFileAtPath: filepath])
    {
        goto ERROR;
    }

    xmlKeysDict = [NSDictionary dictionaryWithContentsOfFile: filepath];

    if (![xmlKeysDict count])
    {
        goto ERROR;
    }

    hotkeysDict = [NSMutableDictionary dictionaryWithDictionary: xmlKeysDict];

    if (!hotkeysDict)
        goto ERROR;

    for (i=0; i<kNumPPHotkeyTypes; i++)
    {
        dictKey = [gHotkeyDictKeys objectAtIndex: i];

        hotkey = ModifiedHotkeyForXMLKey([xmlKeysDict objectForKey: dictKey]);

        if (hotkey)
        {
            [hotkeysDict setObject: hotkey forKey: dictKey];
        }
    }

    return [NSDictionary dictionaryWithDictionary: hotkeysDict];

ERROR:
    return nil;
}

static void LoadHotkeysArrayFromDict(NSDictionary *hotkeysDict)
{
    NSString *dictKey;
    int i;

    for (i=0; i<kNumPPHotkeyTypes; i++)
    {
        [gHotkeys[i] autorelease];
        gHotkeys[i] = nil;

        dictKey = [gHotkeyDictKeys objectAtIndex: i];

        if (dictKey)
        {
            gHotkeys[i] = [[hotkeysDict objectForKey: dictKey] retain];
        }

        if (!gHotkeys[i])
        {
            gHotkeys[i] = [@"" retain];
        }
    }

    [[NSNotificationCenter defaultCenter]
                                postNotificationName: PPHotkeysNotification_UpdatedHotkeys
                                object: nil];
}

static void SaveCustomHotkeysDict(NSDictionary *hotkeysDict)
{
    NSMutableDictionary *xmlKeysDict;
    int i;
    NSString *dictKey, *xmlKey;

    if (!gCustomHotkeysDictResourcePath)
        goto ERROR;

    if (!hotkeysDict)
        goto ERROR;

    xmlKeysDict = [NSMutableDictionary dictionaryWithDictionary: hotkeysDict];

    if (!xmlKeysDict)
        goto ERROR;

    for (i=0; i<kNumPPHotkeyTypes; i++)
    {
        dictKey = [gHotkeyDictKeys objectAtIndex: i];

        if (!dictKey)
            goto ERROR;

        xmlKey = ModifiedXMLKeyForHotkey([hotkeysDict objectForKey: dictKey]);

        if (xmlKey)
        {
            [xmlKeysDict setObject: xmlKey forKey: dictKey];
        }
    }

    if (![[NSFileManager defaultManager] ppVerifySupportFileDirectory])
    {
        goto ERROR;
    }

    [xmlKeysDict writeToFile: gCustomHotkeysDictResourcePath atomically: YES];

    return;

ERROR:
    return;
}

static void DeleteCustomHotkeysDict(void)
{
    if (!gCustomHotkeysDictResourcePath)
        return;

    [[NSFileManager defaultManager] ppDeleteSupportFileAtPath: gCustomHotkeysDictResourcePath];
}

static NSString *ModifiedHotkeyForXMLKey(NSString *xmlKey)
{
    if ([xmlKey isEqualToString: kTabKeyForXML])
    {
        return kTabKey;
    }
    else if ([xmlKey isEqualToString: kReturnKeyForXML])
    {
        return kReturnKey;
    }
    else if ([xmlKey isEqualToString: kEscKeyForXML])
    {
        return kEscKey;
    }

    return nil;
}

static NSString *ModifiedXMLKeyForHotkey(NSString *hotkey)
{
    if ([hotkey isEqualToString: kTabKey])
    {
        return kTabKeyForXML;
    }
    else if ([hotkey isEqualToString: kReturnKey])
    {
        return kReturnKeyForXML;
    }
    else if ([hotkey isEqualToString: kEscKey])
    {
        return kEscKeyForXML;
    }

    return nil;
}
