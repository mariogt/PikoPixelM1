/*
    PPOSXGlue_NavigatorSliderVisibility.m

    Copyright 2020 Josh Freeman
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

//  On OS X 10.10 Yosemite & later, the Navigator popup panel's zoom slider's bar doesn't appear.
//  This happens because the slider's bar is drawn with a dark, partially-transparent color that
// won't show up over dark backgrounds.
//  Workaround is to manually insert a brightly-colored (white) view behind the slider bar, so
// the transparent bar will appear lighter than the surrounding dark background.

#ifdef __APPLE__

#import <Cocoa/Cocoa.h>
#import "NSObject_PPUtilities.h"
#import "PPAppBootUtilities.h"
#import "PPNavigatorPopupPanelController.h"
#import "PPSRGBUtilities.h"


#define PP_SDK_HAS_NSSLIDERCELL_BARRECTFLIPPED_METHOD                           \
            (_PP_MAC_OS_X_SDK_VERSION_IS_AT_LEAST_10_(9))

#define PP_RUNTIME_CHECK__RUNTIME_HAS_TRANSPARENT_SLIDER_BARS                   \
            (_PP_RUNTIME_CHECK__MAC_OS_X_VERSION_IS_AT_LEAST_10_(10))

#define PP_RUNTIME_CHECK__NSSLIDERCELL_BARRECTFLIPPED_HAS_OFFBYONE_BUG          \
            (_PP_RUNTIME_CHECK__MAC_OS_X_VERSION_IS_AT_LEAST_10_(12)            \
                && _PP_RUNTIME_CHECK__MAC_OS_X_VERSION_IS_EARLIER_THAN_10_(14))


#define kBrightBackgroundViewColor                                              \
            [NSColor ppSRGBColorWithWhite: 1.0 alpha: 1.0]


@interface NSSlider (PPOSXGlue_NavigatorSliderVisibilityUtilities)

- (void) ppOSXGlue_AddBrightBackgroundViewUnderSliderBar;

@end

#if !PP_SDK_HAS_NSSLIDERCELL_BARRECTFLIPPED_METHOD

@interface NSSliderCell (BarRectFlippedMethodForLegacySDKs)

- (NSRect) barRectFlipped: (BOOL) flipped;

@end

#endif // !PP_SDK_HAS_NSSLIDERCELL_BARRECTFLIPPED_METHOD

@implementation NSObject (PPOSXGlue_NavigatorSliderVisibility)

+ (void) ppOSXGlue_NavigatorSliderVisibility_InstallPatches
{
    macroSwizzleInstanceMethod(PPNavigatorPopupPanelController, windowDidLoad,
                                ppOSXPatch_WindowDidLoad);
}

+ (void) load
{
    if (PP_RUNTIME_CHECK__RUNTIME_HAS_TRANSPARENT_SLIDER_BARS)
    {
        macroPerformNSObjectSelectorAfterAppLoads(
                                        ppOSXGlue_NavigatorSliderVisibility_InstallPatches);
    }
}

@end

@implementation PPNavigatorPopupPanelController (PPOSXGlue_NavigatorSliderVisibility)

- (void) ppOSXPatch_WindowDidLoad
{
    [self ppOSXPatch_WindowDidLoad];

    [_zoomSlider ppOSXGlue_AddBrightBackgroundViewUnderSliderBar];
}

@end

@implementation NSSlider (PPOSXGlue_NavigatorSliderVisibilityUtilities)

- (void) ppOSXGlue_AddBrightBackgroundViewUnderSliderBar
{
    NSView *superView;
    NSRect sliderBarBounds, backgroundViewFrame;
    NSTextField *backgroundView;
    BOOL isFlipped;

    superView = [self superview];

    if (!superView)
        goto ERROR;

    isFlipped = [self isFlipped];

    sliderBarBounds = [[self cell] barRectFlipped: isFlipped];

    if (NSIsEmptyRect(sliderBarBounds))
    {
        goto ERROR;
    }

    if (PP_RUNTIME_CHECK__NSSLIDERCELL_BARRECTFLIPPED_HAS_OFFBYONE_BUG)
    {
        // On 10.12 & 10.13, barRectFlipped: returns a rect with an origin.y that's too high
        // (off by a pixel)
        sliderBarBounds.origin.y += (isFlipped) ? 1 : -1;
    }

    if (sliderBarBounds.size.height > 2)
    {
        sliderBarBounds = NSInsetRect(sliderBarBounds, 1, 1);
    }

    backgroundViewFrame = [self convertRect: sliderBarBounds toView: superView];

    backgroundView = [[[NSTextField alloc] initWithFrame: backgroundViewFrame] autorelease];

    if (!backgroundView)
        goto ERROR;

    [backgroundView setBordered: NO];
    [backgroundView setEditable: NO];
    [backgroundView setDrawsBackground: YES];
    [backgroundView setBackgroundColor: kBrightBackgroundViewColor];

    [superView addSubview: backgroundView positioned: NSWindowBelow relativeTo: self];

    return;

ERROR:
    return;
}

@end

#endif  // __APPLE__
