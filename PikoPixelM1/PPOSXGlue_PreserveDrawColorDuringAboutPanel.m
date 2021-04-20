/*
    PPOSXGlue_PreserveDrawColorDuringAboutPanel.m

    Copyright 2013-2018 Josh Freeman
    http://www.twilightedge.com

    This file is part of PikoPixel for Mac OS X.
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

//  On OS X 10.5 Leopard & later, opening the About Panel or clicking on its text will change
// the shared Color Panel's color to light blue - this affects any active color wells, so if the
// shared Color Panel is visible in order to select a document's draw color, showing or clicking
// the About Panel will cause the document's draw color to be set to light blue.
//  This happens because the About Panel's text views are set to use the Font Panel (even though
// they're not editable), so any interactions with the views will automatically update the Font
// Panel's settings, which includes updating the Color Panel with the Font Panel's current color.
//  Workaround prevents NSTextView instances from using the Font Panel by patching
// -[NSTextView usesFontPanel] to always return NO. Note that this disables the Font Panel for
// ALL text views, not just the About Panel's (figuring out which text views belong to the
// system's About Panel would be a more complicated workaround), however, this doesn't appear to
// cause any issues, since no current text view in PikoPixel needs to use the Font Panel.

#ifdef __APPLE__

#import <Cocoa/Cocoa.h>
#import "NSObject_PPUtilities.h"
#import "PPAppBootUtilities.h"


#define PP_RUNTIME_CHECK__ABOUT_PANEL_CAN_CAUSE_DRAW_COLOR_CHANGE       \
            (_PP_RUNTIME_CHECK__MAC_OS_X_VERSION_IS_AT_LEAST_10_(5))


@implementation NSObject (PPOSXGlue_PreserveDrawColorDuringAboutPanel)

+ (void) ppOSXGlue_PreserveDrawColorDuringAboutPanel_InstallPatches
{
    macroSwizzleInstanceMethod(NSTextView, usesFontPanel, ppOSXPatch_UsesFontPanel);
}

+ (void) load
{
    if (PP_RUNTIME_CHECK__ABOUT_PANEL_CAN_CAUSE_DRAW_COLOR_CHANGE)
    {
        macroPerformNSObjectSelectorAfterAppLoads(
                                    ppOSXGlue_PreserveDrawColorDuringAboutPanel_InstallPatches);
    }
}

@end

@implementation NSTextView (PPOSXGlue_PreserveDrawColorDuringAboutPanel)

- (BOOL) ppOSXPatch_UsesFontPanel
{
    return NO;
}

@end

#endif  // __APPLE__
