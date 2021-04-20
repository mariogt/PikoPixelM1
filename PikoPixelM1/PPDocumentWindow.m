/*
    PPDocumentWindow.m

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

#import "PPDocumentWindow.h"

#import "PPModifierKeyMasks.h"
#import "PPKeyConstants.h"
#import "PPPopupPanelsController.h"
#import "PPDocumentWindowController.h"


static bool ShouldForwardKeyCharsToWindowController(NSString *keyChars);
static NSCharacterSet *TabAndEscKeysCharSet(void);
static NSCharacterSet *ArrowKeysCharSet(void);


@implementation PPDocumentWindow

#pragma mark NSWindow overrides

- (void) sendEvent: (NSEvent *) theEvent
{
    NSEventType eventType = [theEvent type];

    // Intercept certain non-modifier key events & forward them directly to the
    // window controller, otherwise Cocoa handles them
    if (((eventType == NSKeyDown) || (eventType == NSKeyUp))
        && !([theEvent modifierFlags] & kModifierKeyMask_RecognizedModifierKeys)
        && (ShouldForwardKeyCharsToWindowController([theEvent charactersIgnoringModifiers])))
    {
        SEL eventHandlerSelector =
                            (eventType == NSKeyDown) ? @selector(keyDown:) : @selector(keyUp:);

        [[self windowController] performSelector: eventHandlerSelector
                                    withObject: theEvent];
    }
    else
    {
        [super sendEvent: theEvent];
    }
}

- (BOOL) validateMenuItem: (PPSDKNativeType_NSMenuItemPtr) menuItem
{
    PPDocumentWindowController *ppWindowController = [self windowController];

    if ([ppWindowController isKindOfClass: [PPDocumentWindowController class]]
        && [ppWindowController isTrackingMouseInCanvasView])
    {
        return NO;
    }

    return [super validateMenuItem: menuItem];
}

@end

#pragma mark Private functions

static bool ShouldForwardKeyCharsToWindowController(NSString *keyChars)
{
    static NSCharacterSet *tabAndEscKeysCharSet = nil, *arrowKeysCharSet = nil;

    if (!tabAndEscKeysCharSet)
    {
        tabAndEscKeysCharSet = [TabAndEscKeysCharSet() retain];

        if (!tabAndEscKeysCharSet)
            goto ERROR;
    }

    if (!arrowKeysCharSet)
    {
        arrowKeysCharSet = [ArrowKeysCharSet() retain];

        if (!arrowKeysCharSet)
            goto ERROR;
    }

    if (!keyChars)
        goto ERROR;

    // Always forward Tab or Esc keys, otherwise Cocoa intercepts them
    if ([keyChars rangeOfCharacterFromSet: tabAndEscKeysCharSet].length)
    {
        return YES;
    }

    // Forward arrow keys if a popup is visible, otherwise they may be intercepted as menu key
    // equivalents
    if ([keyChars rangeOfCharacterFromSet: arrowKeysCharSet].length
        && [[PPPopupPanelsController sharedController] hasActivePopupPanel])
    {
        return YES;
    }

    return NO;

ERROR:
    return NO;
}

static NSCharacterSet *TabAndEscKeysCharSet(void)
{
    unichar tabAndEscKeyChars[] = {kTabKeyChar, kEscKeyChar};
    NSString *tabAndEscKeysString =
                    [NSString stringWithCharacters: tabAndEscKeyChars
                                length: sizeof(tabAndEscKeyChars) / sizeof(*tabAndEscKeyChars)];

    if (!tabAndEscKeysString)
        goto ERROR;

    return [NSCharacterSet characterSetWithCharactersInString: tabAndEscKeysString];

ERROR:
    return nil;
}

static NSCharacterSet *ArrowKeysCharSet(void)
{
    unichar arrowKeyChars[] = {NSLeftArrowFunctionKey, NSRightArrowFunctionKey,
                                NSUpArrowFunctionKey, NSDownArrowFunctionKey};
    NSString *arrowKeysString =
                    [NSString stringWithCharacters: arrowKeyChars
                                length: sizeof(arrowKeyChars) / sizeof(*arrowKeyChars)];

    if (!arrowKeysString)
        goto ERROR;

    return [NSCharacterSet characterSetWithCharactersInString: arrowKeysString];

ERROR:
    return nil;
}
