/*
    PPHotkeyDisplayUtilities.m

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

#import "PPHotkeyDisplayUtilities.h"

#import "PPKeyConstants.h"


NSString *PPDisplayKeyForHotkey(NSString *hotkey)
{
    int hotkeyLength;
    unichar hotkeyChar, displayKeyChar = 0;

    hotkeyLength = [hotkey length];

    if (hotkeyLength > 1)
    {
        hotkey = [hotkey substringFromIndex: hotkeyLength - 1];
        hotkeyLength = [hotkey length];
    }

    if (!hotkeyLength)
        goto ERROR;

    hotkeyChar = [hotkey characterAtIndex: 0];

    switch (hotkeyChar)
    {
        case kTabKeyChar:
        {
            displayKeyChar = kTabKeyCharForDisplay;
        }
        break;

        case kReturnKeyChar:
        {
            displayKeyChar = kReturnKeyCharForDisplay;
        }
        break;

        case kSpaceKeyChar:
        {
            displayKeyChar =
                (PP_RUNTIME_CHECK__RUNTIME_SUPPORTS_BOTTOM_SQUARE_BRACKET_UNICODE_CHAR) ?
                    kBottomBracketCharForSpaceKeyDisplay : kSpaceKeyChar;
        }
        break;

        case kEscKeyChar:
        {
            displayKeyChar = kEscKeyCharForDisplay;
        }
        break;

        default:
        {
            return hotkey;
        }
        break;
    }

    return [NSString stringWithFormat: @"%C", displayKeyChar];

ERROR:
    return @"";
}

NSString *PPHotkeyForDisplayKey(NSString *displayKey)
{
    unichar displayKeyChar, hotkeyChar = 0;

    if (![displayKey length])
    {
        goto ERROR;
    }

    displayKeyChar = [displayKey characterAtIndex: 0];

    switch (displayKeyChar)
    {
        case kTabKeyCharForDisplay:
        {
            hotkeyChar = kTabKeyChar;
        }
        break;

        case kReturnKeyCharForDisplay:
        {
            hotkeyChar = kReturnKeyChar;
        }
        break;

        case kBottomBracketCharForSpaceKeyDisplay:
        {
            hotkeyChar = kSpaceKeyChar;
        }
        break;

        case kEscKeyCharForDisplay:
        {
            hotkeyChar = kEscKeyChar;
        }
        break;

        default:
        {
            return displayKey;
        }
        break;
    }

    return [NSString stringWithFormat: @"%C", hotkeyChar];

ERROR:
    return @"";
}
