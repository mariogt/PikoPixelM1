/*
    PPKeyboardLayout.m

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

#import "PPKeyboardLayout.h"

#import "PPDefines.h"


#if PP_DEPLOYMENT_TARGET_SUPPORTS_CARBON

#import <Carbon/Carbon.h>


#define kKeyboardNameToLocaleDictResourceName                   @"KeyboardNameToLocale"


#if PP_DEPLOYMENT_TARGET_DEPRECATED_KEYBOARDLAYOUT

NSString *PPKeyboardLayout_LanguageLocaleString(void)
{
    static NSDictionary *keyboardNameToLocaleDict = nil;
    TISInputSourceRef inputSourceRef;
    NSString *keyboardName, *localeString;
    NSArray *languageNames;

    if (!keyboardNameToLocaleDict)
    {
        NSString *dictPath = [[NSBundle mainBundle]
                                        pathForResource: kKeyboardNameToLocaleDictResourceName
                                        ofType: @"plist"];

        if (dictPath)
        {
            keyboardNameToLocaleDict =
                [[NSDictionary dictionaryWithContentsOfFile: dictPath] retain];
        }
    }

    inputSourceRef = TISCopyCurrentKeyboardLayoutInputSource();

    if (!inputSourceRef)
        goto ERROR;

    keyboardName =
            (NSString *) TISGetInputSourceProperty(inputSourceRef, kTISPropertyLocalizedName);

    if (keyboardName)
    {
        localeString = [keyboardNameToLocaleDict objectForKey: keyboardName];

        if (localeString)
        {
            return [NSString stringWithString: localeString];
        }
    }

    languageNames =
        (NSArray *) TISGetInputSourceProperty(inputSourceRef, kTISPropertyInputSourceLanguages);

    if (![languageNames count])
    {
        goto ERROR;
    }

    return [NSString stringWithString: [languageNames objectAtIndex: 0]];

ERROR:
    return kDefaultKeyboardLayoutLanguageCode;
}

#else   // Deployment target supports keyboard layout

NSString *PPKeyboardLayout_LanguageLocaleString(void)
{
    OSStatus status;
    KeyboardLayoutRef keyboardLayout;
    CFStringRef stringRef;
    NSString *localeString;

    status = KLGetCurrentKeyboardLayout(&keyboardLayout);

    if (status != noErr)
    {
        goto ERROR;
    }

    status = KLGetKeyboardLayoutProperty(keyboardLayout, kKLLanguageCode,
                                            (const void **) &stringRef);

    if (status != noErr)
    {
        goto ERROR;
    }

    localeString = (NSString *) stringRef;

    if (![localeString length])
    {
        goto ERROR;
    }

    return [NSString stringWithString: localeString];

ERROR:
    return kDefaultKeyboardLayoutLanguageCode;
}

#endif  // PP_DEPLOYMENT_TARGET_DEPRECATED_KEYBOARDLAYOUT


#else   // Deployment target doesn't support Carbon

NSString *PPKeyboardLayout_LanguageLocaleString(void)
{
    return kDefaultKeyboardLayoutLanguageCode;
}

#endif  // PP_DEPLOYMENT_TARGET_SUPPORTS_CARBON
