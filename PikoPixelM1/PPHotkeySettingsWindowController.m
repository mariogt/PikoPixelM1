/*
    PPHotkeySettingsWindowController.m

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

#import "PPHotkeySettingsWindowController.h"

#import "PPHotkeys.h"
#import "PPHotkeyDisplayUtilities.h"
#import "PPKeyboardLayout.h"
#import "PPKeyConstants.h"
#import "PPDefines.h"


#define kHotkeySettingsWindowNibName        @"HotkeySettings"

#define kReturnMenuItemTitle                @"Return"
#define kTabMenuItemTitle                   @"Tab"
#define kEscMenuItemTitle                   @"Esc"


@interface PPHotkeySettingsWindowController (PrivateMethods)

- (bool) setupKeyFieldsMatricesArray;
- (bool) setupSystemKeyPopUpButtonMenu;
- (bool) setupLanguagePopUpButtonMenu;

- (void) saveKeyFieldsToHotkeys;
- (void) loadKeyFieldsFromHotkeysArray;
- (void) loadKeyFieldsFromHotkeysDict: (NSDictionary *) hotkeysDict;

- (NSCell *) activeKeyFieldTextCell;

@end


#if PP_SDK_REQUIRES_PROTOCOLS_FOR_DELEGATES_AND_DATASOURCES

@interface PPHotkeySettingsWindowController (RequiredProtocols) <NSMatrixDelegate>
@end

#endif  // PP_SDK_REQUIRES_PROTOCOLS_FOR_DELEGATES_AND_DATASOURCES


@implementation PPHotkeySettingsWindowController

+ (PPHotkeySettingsWindowController *) sharedController
{
    static PPHotkeySettingsWindowController *sharedController = nil;

    if (!sharedController)
    {
        sharedController = [[self alloc] init];
    }

    return sharedController;
}

- init
{
    self = [super init];

    if (!self)
        goto ERROR;

    _currentHotkeysSet = [[NSMutableSet set] retain];

    if (!_currentHotkeysSet)
        goto ERROR;
    //check
    //if (![NSBundle loadNibNamed: kHotkeySettingsWindowNibName owner: self]
    if(![[NSBundle mainBundle] loadNibNamed:kHotkeySettingsWindowNibName owner:self topLevelObjects:nil]
        || ![self setupKeyFieldsMatricesArray]
        || ![self setupSystemKeyPopUpButtonMenu]
        || ![self setupLanguagePopUpButtonMenu])
    {
        goto ERROR;
    }

    [self loadKeyFieldsFromHotkeysArray];

    return self;

ERROR:
    [self release];

    return nil;
}

- (void) dealloc
{
    [_keyFieldsMatrices release];
    [_previousKeyFieldValue release];
    [_currentHotkeysSet release];

    [super dealloc];
}

- (void) showPanel
{
    [_window makeKeyAndOrderFront: self];
    [_window makeMainWindow];
}

#pragma mark Actions

- (IBAction) insertSystemKeyButtonPressed: (id) sender
{
    unichar hotkeyChar;
    NSString *hotkey, *displayKey;
    NSCell *activeKeyFieldCell;
    NSString *previousCellValue;

    hotkeyChar = [_systemKeyPopUpButton selectedTag];
    hotkey = [NSString stringWithCharacters: &hotkeyChar length: 1];
    displayKey = PPDisplayKeyForHotkey(hotkey);

    if (![displayKey length]
        || [_currentHotkeysSet containsObject: displayKey])
    {
        goto ERROR;
    }

    activeKeyFieldCell = [self activeKeyFieldTextCell];

    if (!activeKeyFieldCell)
        goto ERROR;

    previousCellValue = [activeKeyFieldCell stringValue];

    if (previousCellValue)
    {
        [_currentHotkeysSet removeObject: previousCellValue];
    }

    [_currentHotkeysSet addObject: displayKey];
    [activeKeyFieldCell setStringValue: displayKey];

    [_previousKeyFieldValue release];
    _previousKeyFieldValue = [displayKey retain];

    return;

ERROR:
    NSBeep();
}

- (IBAction) loadDefaultsForLanguageButtonPressed: (id) sender
{
    NSDictionary *hotkeysDict =
            [PPHotkeys hotkeysDictForLanguageCode: [_languagePopUpButton titleOfSelectedItem]];

    [self loadKeyFieldsFromHotkeysDict: hotkeysDict];
}

- (IBAction) OKButtonPressed: (id) sender
{
    [self saveKeyFieldsToHotkeys];

    [_window orderOut: self];
}

- (IBAction) cancelButtonPressed: (id) sender
{
    [_window orderOut: self];

    [self loadKeyFieldsFromHotkeysArray];
}

#pragma mark NSMatrix delegate methods

- (void) controlTextDidBeginEditing: (NSNotification *) notification
{
    NSMatrix *activeKeyFieldsMatrix = [notification object];

    [_previousKeyFieldValue release];
    _previousKeyFieldValue = [[activeKeyFieldsMatrix stringValue] retain];
}

- (void) controlTextDidChange: (NSNotification *) notification
{
    NSMatrix *activeKeyFieldsMatrix;
    NSString *previousKeyFieldValue, *keyFieldValue;
    int previousKeyFieldValueLength, keyFieldValueLength;

    activeKeyFieldsMatrix = [notification object];

    previousKeyFieldValue = _previousKeyFieldValue;
    previousKeyFieldValueLength = [previousKeyFieldValue length];

    if (!previousKeyFieldValueLength)
    {
        previousKeyFieldValue = gHotkeys[[activeKeyFieldsMatrix tag]];
    }
    else if (previousKeyFieldValueLength > 1)
    {
        previousKeyFieldValue = [previousKeyFieldValue substringToIndex: 1];
    }

    keyFieldValue = [activeKeyFieldsMatrix stringValue];
    keyFieldValueLength = [keyFieldValue length];

    if (!keyFieldValueLength)
    {
        keyFieldValue = previousKeyFieldValue;
    }
    else if (keyFieldValueLength > 1)
    {
        if (![keyFieldValue hasSuffix: previousKeyFieldValue])
        {
            keyFieldValue = [keyFieldValue substringFromIndex: keyFieldValueLength - 1];
        }
        else
        {
            keyFieldValue =
                [keyFieldValue substringWithRange: NSMakeRange(keyFieldValueLength - 2, 1)];
        }
    }

    keyFieldValue = PPDisplayKeyForHotkey(keyFieldValue);

    if (![keyFieldValue length]
        || [_currentHotkeysSet containsObject: keyFieldValue])
    {
        if (_previousKeyFieldValue
            && ![keyFieldValue isEqualToString: _previousKeyFieldValue])
        {
            NSBeep();
        }

        keyFieldValue = _previousKeyFieldValue;
    }

    [activeKeyFieldsMatrix setStringValue: keyFieldValue];
    [activeKeyFieldsMatrix selectText: self];

    if ([_previousKeyFieldValue isEqualToString: keyFieldValue])
    {
        return;
    }

    [_currentHotkeysSet addObject: keyFieldValue];

    if (_previousKeyFieldValue)
    {
        [_currentHotkeysSet removeObject: _previousKeyFieldValue];
    }

    [_previousKeyFieldValue release];
    _previousKeyFieldValue = [keyFieldValue retain];
}

#pragma mark Private methods

- (bool) setupKeyFieldsMatricesArray
{
    NSArray *matricesArray;
    NSEnumerator *matricesEnumerator, *cellsEnumerator;
    NSMatrix *matrix;
    int hotkeyIndex;
    NSCell *cell;

    matricesArray = [NSArray arrayWithObjects:
                                _toolFieldsMatrix1,
                                _toolFieldsMatrix2,
                                _popupPanelFieldsMatrix,
                                _actionFieldsMatrix,
                                nil];

    if ([matricesArray count] != 4)
    {
        goto ERROR;
    }

    matricesEnumerator = [matricesArray objectEnumerator];

    while (matrix = [matricesEnumerator nextObject])
    {
        [matrix setDelegate: self];

        hotkeyIndex = [matrix tag];

        cellsEnumerator = [[matrix cells] objectEnumerator];

        while (cell = [cellsEnumerator nextObject])
        {
            [cell setTag: hotkeyIndex++];
        }
    }

    _keyFieldsMatrices = [matricesArray retain];

    return YES;

ERROR:
    return NO;
}

- (bool) setupSystemKeyPopUpButtonMenu
{
    NSMenu *menu;
    NSString *menuItemTitle;
    NSMenuItem *menuItem;

    menu = [[[NSMenu alloc] init] autorelease];

    if (!menu)
        goto ERROR;

    // Return menu item
    menuItemTitle =
        [NSString stringWithFormat: @"%C %@", kReturnKeyCharForDisplay, kReturnMenuItemTitle];

    menuItem = [[[NSMenuItem alloc] initWithTitle: menuItemTitle
                                    action: NULL
                                    keyEquivalent: @""]
                                autorelease];

    if (!menuItem)
        goto ERROR;

    [menuItem setTag: kReturnKeyChar];

    [menu addItem: menuItem];


    // Tab menu item
    menuItemTitle =
            [NSString stringWithFormat: @"%C %@", kTabKeyCharForDisplay, kTabMenuItemTitle];

    menuItem = [[[NSMenuItem alloc] initWithTitle: menuItemTitle
                                    action: NULL
                                    keyEquivalent: @""]
                                autorelease];

    if (!menuItem)
        goto ERROR;

    [menuItem setTag: kTabKeyChar];

    [menu addItem: menuItem];


    // Esc menu item
    menuItemTitle =
            [NSString stringWithFormat: @"%C %@", kEscKeyCharForDisplay, kEscMenuItemTitle];

    menuItem = [[[NSMenuItem alloc] initWithTitle: menuItemTitle
                                    action: NULL
                                    keyEquivalent: @""]
                                autorelease];

    if (!menuItem)
        goto ERROR;

    [menuItem setTag: kEscKeyChar];

    [menu addItem: menuItem];


    [_systemKeyPopUpButton setMenu: menu];

    return YES;

ERROR:
    return NO;
}

- (bool) setupLanguagePopUpButtonMenu
{
    NSMenu *menu;
    NSArray *availableLanguageCodes;
    int numAvailableLanguageCodes, i;
    NSString *keyboardLayoutLanguageCode;

    menu = [[[NSMenu alloc] init] autorelease];

    availableLanguageCodes = [PPHotkeys availableKeyboardLayoutLanguageCodes];
    numAvailableLanguageCodes = [availableLanguageCodes count];

    if (![availableLanguageCodes count] || !menu)
    {
        goto ERROR;
    }

    for (i=0; i<numAvailableLanguageCodes; i++)
    {
        [menu addItemWithTitle: [availableLanguageCodes objectAtIndex: i]
                action: NULL
                keyEquivalent: @""];
    }

    [_languagePopUpButton setMenu: menu];

    keyboardLayoutLanguageCode = PPKeyboardLayout_LanguageLocaleString();

    if (![availableLanguageCodes containsObject: keyboardLayoutLanguageCode])
    {
        keyboardLayoutLanguageCode = kDefaultKeyboardLayoutLanguageCode;
    }

    [_languagePopUpButton selectItemWithTitle: NSLocalizedString(keyboardLayoutLanguageCode, nil)];

    return YES;

ERROR:
    return NO;
}

- (void) saveKeyFieldsToHotkeys
{
    NSMutableDictionary *hotkeyDict;
    NSEnumerator *matricesEnumerator, *cellsEnumerator;
    NSMatrix *matrix;
    NSCell *cell;
    PPHotkeyType hotkeyType;
    NSString *displayKey;

    if ([gHotkeyDictKeys count] != kNumPPHotkeyTypes)
    {
        goto ERROR;
    }

    hotkeyDict = [NSMutableDictionary dictionary];

    if (!hotkeyDict)
        goto ERROR;

    matricesEnumerator = [_keyFieldsMatrices objectEnumerator];

    while (matrix = [matricesEnumerator nextObject])
    {
        cellsEnumerator = [[matrix cells] objectEnumerator];

        while (cell = [cellsEnumerator nextObject])
        {
            displayKey = [cell stringValue];
            hotkeyType = [cell tag];

            if (![displayKey length]
                || !PPHotkeyType_IsValid(hotkeyType))
            {
                goto ERROR;
            }

            [hotkeyDict setObject: PPHotkeyForDisplayKey(displayKey)
                        forKey: [gHotkeyDictKeys objectAtIndex: hotkeyType]];
        }
    }

    [PPHotkeys setHotkeysFromDict: hotkeyDict];

    return;

ERROR:
    return;
}

- (void) loadKeyFieldsFromHotkeysArray
{
    NSEnumerator *matricesEnumerator, *cellsEnumerator;
    NSMatrix *matrix;
    NSCell *cell;
    PPHotkeyType hotkeyType;
    NSString *hotkey, *displayKey;

    [_currentHotkeysSet removeAllObjects];

    matricesEnumerator = [_keyFieldsMatrices objectEnumerator];

    while (matrix = [matricesEnumerator nextObject])
    {
        cellsEnumerator = [[matrix cells] objectEnumerator];

        while (cell = [cellsEnumerator nextObject])
        {
            hotkeyType = [cell tag];

            if (PPHotkeyType_IsValid(hotkeyType))
            {
                hotkey = gHotkeys[hotkeyType];
            }
            else
            {
                hotkey = nil;
            }

            displayKey = PPDisplayKeyForHotkey(hotkey);

            [cell setStringValue: displayKey];

            if (displayKey)
            {
                [_currentHotkeysSet addObject: displayKey];
            }
        }
    }
}

- (void) loadKeyFieldsFromHotkeysDict: (NSDictionary *) hotkeysDict
{
    NSEnumerator *matricesEnumerator, *cellsEnumerator;
    NSMatrix *matrix;
    NSCell *cell;
    PPHotkeyType hotkeyType;
    NSString *hotkey, *dictKey, *displayKey;

    if ([hotkeysDict count] != kNumPPHotkeyTypes)
    {
        return;
    }

    [_currentHotkeysSet removeAllObjects];

    matricesEnumerator = [_keyFieldsMatrices objectEnumerator];

    while (matrix = [matricesEnumerator nextObject])
    {
        cellsEnumerator = [[matrix cells] objectEnumerator];

        while (cell = [cellsEnumerator nextObject])
        {
            hotkey = nil;
            hotkeyType = [cell tag];

            if (PPHotkeyType_IsValid(hotkeyType))
            {
                dictKey = [gHotkeyDictKeys objectAtIndex: hotkeyType];

                if (dictKey)
                {
                    hotkey = [hotkeysDict objectForKey: dictKey];
                }
            }

            displayKey = PPDisplayKeyForHotkey(hotkey);

            [cell setStringValue: displayKey];

            if (displayKey)
            {
                [_currentHotkeysSet addObject: displayKey];
            }
        }
    }
}

- (NSCell *) activeKeyFieldTextCell
{
    NSText *activeTextFieldEditor;
    NSMatrix *activeKeyFieldsMatrix;

    activeTextFieldEditor = [_window fieldEditor: NO forObject: nil];

    if (!activeTextFieldEditor)
        goto ERROR;

    activeKeyFieldsMatrix = (NSMatrix *) [activeTextFieldEditor delegate];

    if (![activeKeyFieldsMatrix isKindOfClass: [NSMatrix class]])
    {
        goto ERROR;
    }

    return [activeKeyFieldsMatrix selectedCell];

ERROR:
    return nil;
}

@end
