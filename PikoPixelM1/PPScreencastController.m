/*
    PPScreencastController.m

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

#import "PPOptional.h"
#if PP_OPTIONAL__BUILD_WITH_SCREENCASTING

#import "PPScreencastController.h"

#import "PPScreencastPopupPanelController.h"
#import "PPKeyConstants.h"
#import "PPModifierKeyMasks.h"
#import "NSObject_PPUtilities.h"


#define kMouseDownDisplayChar               ((unichar) 0x25C9)  // fisheye char

#define kMaxCharsInStateString              (kScreencastMaxSimultaneousKeysAllowed + 6)
                                            // +6: 4 modifier keys, mousedown char, & space


static unichar DisplayCharForKeyChar(unichar keyChar);


@interface PPScreencastController (PrivateMethods)

- (void) addAsObserverForNSApplicationNotifications;
- (void) removeAsObserverForNSApplicationNotifications;
- (void) handleNSApplicationNotification_WillResignActive: (NSNotification *) notification;

- (void) addAsObserverForNSMenuNotifications;
- (void) removeAsObserverForNSMenuNotifications;
- (void) handleNSMenuNotification_DidEndTracking: (NSNotification *) notification;

- (bool) handleMouseDown;
- (bool) handleMouseUp;
- (bool) handleKeyDown: (NSString *) key;
- (bool) handleKeyUp: (NSString *) key;
- (bool) handleFlagsChanged: (unsigned) modifierFlags;

- (void) checkCurrentEventModiferFlags;

- (int) keysDownIndexForChar: (unichar) keyChar;

- (void) clearScreencastState;

- (void) updateScreencastPopupStateString;

@end

@implementation PPScreencastController

+ (PPScreencastController *) sharedController
{
    static PPScreencastController *sharedController = nil;

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

    if (!PP_RUNTIME_CHECK_OPTIONAL__RUNTIME_SUPPORTS_SCREENCASTING)
    {
        goto ERROR;
    }

    _screencastPopupController = [[PPScreencastPopupPanelController controller] retain];

    if (!_screencastPopupController)
        goto ERROR;

    return self;

ERROR:
    [self release];

    return nil;
}

- (void) dealloc
{
    [self setEnabled: NO];

    [_screencastPopupController release];

    [super dealloc];
}

- (void) setEnabled: (bool) enableScreencasting
{
    enableScreencasting = (enableScreencasting) ? YES : NO;

    if (_screencastingIsEnabled == enableScreencasting)
    {
        return;
    }

    if (enableScreencasting)
    {
        [self addAsObserverForNSApplicationNotifications];
        [self addAsObserverForNSMenuNotifications];
    }
    else
    {
        [self removeAsObserverForNSApplicationNotifications];
        [self removeAsObserverForNSMenuNotifications];
    }

    _screencastingIsEnabled = enableScreencasting;
}

- (void) handleEvent: (NSEvent *) event
{
    bool needToUpdateStateString;

    if (!_screencastingIsEnabled)
        return;

    switch ([event type])
    {
        case NSLeftMouseDown:
        {
            needToUpdateStateString = [self handleMouseDown];
        }
        break;

        case NSLeftMouseUp:
        {
            needToUpdateStateString = [self handleMouseUp];
        }
        break;

        case NSKeyDown:
        {
            needToUpdateStateString = [self handleKeyDown: [event charactersIgnoringModifiers]];
        }
        break;

        case NSKeyUp:
        {
            needToUpdateStateString = [self handleKeyUp: [event charactersIgnoringModifiers]];
        }
        break;

        case NSFlagsChanged:
        {
            needToUpdateStateString = [self handleFlagsChanged: [event modifierFlags]];
        }
        break;

        default:
        {
            needToUpdateStateString = NO;
        }
        break;
    }

    if (needToUpdateStateString)
    {
        [self updateScreencastPopupStateString];
    }
}

#pragma mark NSApplication notifications

- (void) addAsObserverForNSApplicationNotifications
{
    [[NSNotificationCenter defaultCenter]
                                addObserver: self
                                selector:
                                    @selector(handleNSApplicationNotification_WillResignActive:)
                                name: NSApplicationWillResignActiveNotification
                                object: NSApp];
}

- (void) removeAsObserverForNSApplicationNotifications
{
    [[NSNotificationCenter defaultCenter] removeObserver: self
                                            name: NSApplicationWillResignActiveNotification
                                            object: NSApp];
}

- (void) handleNSApplicationNotification_WillResignActive: (NSNotification *) notification
{
    [self clearScreencastState];
}

#pragma mark NSMenu notifications

- (void) addAsObserverForNSMenuNotifications
{
    [[NSNotificationCenter defaultCenter]
                                addObserver: self
                                selector: @selector(handleNSMenuNotification_DidEndTracking:)
                                name: NSMenuDidEndTrackingNotification
                                object: nil];
}

- (void) removeAsObserverForNSMenuNotifications
{
    [[NSNotificationCenter defaultCenter] removeObserver: self
                                            name: NSMenuDidEndTrackingNotification
                                            object: nil];
}

- (void) handleNSMenuNotification_DidEndTracking: (NSNotification *) notification
{
    bool needToUpdateStateString = NO;

    if (_numKeysDown)
    {
        _numKeysDown = 0;

        needToUpdateStateString = YES;
    }

    if (needToUpdateStateString)
    {
        [self updateScreencastPopupStateString];
    }

    [self ppPerformSelectorFromNewStackFrame: @selector(checkCurrentEventModiferFlags)];
}

#pragma mark Event handlers

- (bool) handleMouseDown
{
    if (_mouseIsDown)
    {
        return NO;
    }

    _mouseIsDown = YES;

    return YES;
}

- (bool) handleMouseUp
{
    if (!_mouseIsDown)
    {
        return NO;
    }

    _mouseIsDown = NO;

    return YES;
}

- (bool) handleKeyDown: (NSString *) key
{
    unichar keyDownChar;

    key = [key uppercaseString];

    if (![key length] || (_numKeysDown >= kScreencastMaxSimultaneousKeysAllowed))
    {
        return NO;
    }

    keyDownChar = [key characterAtIndex: 0];

    if ([self keysDownIndexForChar: keyDownChar] >= 0)
    {
        return NO;
    }

    _keysDown[_numKeysDown++] = keyDownChar;

    return YES;
}

- (bool) handleKeyUp: (NSString *) key
{
    unichar keyUpChar;
    int keyIndex;

    key = [key uppercaseString];

    if (![key length])
    {
        return NO;
    }

    keyUpChar = [key characterAtIndex: 0];

    keyIndex = [self keysDownIndexForChar: keyUpChar];

    if (keyIndex < 0)
    {
        return NO;
    }

    _numKeysDown--;

    while (keyIndex < _numKeysDown)
    {
        _keysDown[keyIndex] = _keysDown[keyIndex+1];

        keyIndex++;
    }

    return YES;
}

- (bool) handleFlagsChanged: (unsigned) modifierFlags
{
    modifierFlags &= kModifierKeyMask_RecognizedModifierKeys;

    if (modifierFlags == _currentModifierFlags)
    {
        return NO;
    }

    // if the shift key is released while there's other keys down, the remaining keys can
    // 'stick', since their keyUp event's char may not match the initial keyDown char (for
    // instance, shift+'1' will keyDown as '!', but lifting the shift key before the '1' key's
    // released will cause keyUp with '1' instead of '!');
    // to prevent keys from getting stuck, clear keys down when the shift key is released

    if ((_currentModifierFlags & NSShiftKeyMask) && !(modifierFlags & NSShiftKeyMask))
    {
        _numKeysDown = 0;
    }

    _currentModifierFlags = modifierFlags;

    return YES;
}

#pragma mark Private methods

- (void) checkCurrentEventModiferFlags
{
    if ([self handleFlagsChanged: [[NSApp currentEvent] modifierFlags]])
    {
        [self updateScreencastPopupStateString];
    }
}

- (int) keysDownIndexForChar: (unichar) keyChar
{
    int index;

    for (index=0; index<_numKeysDown; index++)
    {
        if (_keysDown[index] == keyChar)
        {
            return index;
        }
    }

    return -1;
}

- (void) clearScreencastState
{
    _numKeysDown = 0;

    _currentModifierFlags = 0;

    _mouseIsDown = NO;

    [self updateScreencastPopupStateString];
}

- (void) updateScreencastPopupStateString
{
    unichar stateChars[kMaxCharsInStateString];
    unsigned numStateChars = 0, index;
    NSString *stateString = nil;

    if (_currentModifierFlags & NSControlKeyMask)
    {
        stateChars[numStateChars++] = kControlKeyCharForDisplay;
    }

    if (_currentModifierFlags & NSAlternateKeyMask)
    {
        stateChars[numStateChars++] = kAlternateKeyCharForDisplay;
    }

    if (_currentModifierFlags & NSShiftKeyMask)
    {
        stateChars[numStateChars++] = kShiftKeyCharForDisplay;
    }

    if (_currentModifierFlags & NSCommandKeyMask)
    {
        stateChars[numStateChars++] = kCommandKeyCharForDisplay;
    }

    for (index=0; index<_numKeysDown; index++)
    {
        stateChars[numStateChars++] = DisplayCharForKeyChar(_keysDown[index]);
    }

    if (_mouseIsDown)
    {
        if (numStateChars)
        {
            stateChars[numStateChars++] = ' ';
        }

        stateChars[numStateChars++] = kMouseDownDisplayChar;
    }

    if (numStateChars)
    {
        stateString = [NSString stringWithCharacters: stateChars length: numStateChars];
    }

    [_screencastPopupController setStateString: stateString];
}

@end

#pragma mark Private functions

static unichar DisplayCharForKeyChar(unichar keyChar)
{
    if ((keyChar >= 'a') && (keyChar <= 'z'))
    {
        keyChar += ('A' - 'a');
    }
    else
    {
        switch (keyChar)
        {
            case NSLeftArrowFunctionKey:
            {
                keyChar = kLeftArrowKeyCharForDisplay;
            }
            break;

            case NSRightArrowFunctionKey:
            {
                keyChar = kRightArrowKeyCharForDisplay;
            }
            break;

            case NSUpArrowFunctionKey:
            {
                keyChar = kUpArrowKeyCharForDisplay;
            }
            break;

            case NSDownArrowFunctionKey:
            {
                keyChar = kDownArrowKeyCharForDisplay;
            }
            break;

            case kTabKeyChar:
            {
                keyChar = kTabKeyCharForDisplay;
            }
            break;

            case kReturnKeyChar:
            {
                keyChar = kReturnKeyCharForDisplay;
            }
            break;

            case kSpaceKeyChar:
            {
                keyChar =
                    (PP_RUNTIME_CHECK__RUNTIME_SUPPORTS_BOTTOM_SQUARE_BRACKET_UNICODE_CHAR) ?
                        kBottomBracketCharForSpaceKeyDisplay : kSpaceKeyChar;
            }
            break;

            case kEscKeyChar:
            {
                keyChar = kEscKeyCharForDisplay;
            }
            break;

            case NSDeleteCharacter:
            {
                keyChar = kDeleteKeyCharForDisplay;
            }
            break;

            default:
            break;
        }
    }

    return keyChar;
}

#endif  // PP_OPTIONAL__BUILD_WITH_SCREENCASTING
