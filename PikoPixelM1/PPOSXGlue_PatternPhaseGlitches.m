/*
    PPOSXGlue_PatternPhaseGlitches.m

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

//  On OS X 10.5 Leopard, an NSView area drawn by filling with a pattern-color can be
// out-of-phase with an adjacent area already filled with the same pattern-color, giving the
// appearance of video glitches where the different areas touch - the out-of-phase issue seems
// to depend on the fill-rect's origin's x-coordinate (different areas whose fill-rect's left
// edges are the same will have the patterns line up correctly).
//  Currently this issue only affects PPPreviewView, as it's the only view that uses
// pattern-colors for partial redraws - everywhere else, pattern-colors are only used to fill
// the entire context (no adjacent areas remain visible).
//  Workaround is to set the drawing context's pattern phase to a 'safe' value - somehow,
// manually setting the pattern phase to a point with an x-value of 4n+1 (1,5,9...) seems to
// resolve the issue (?).
//  The issue no longer appears as of 10.6.

#ifdef __APPLE__

#import <Cocoa/Cocoa.h>
#import "NSObject_PPUtilities.h"
#import "PPAppBootUtilities.h"
#import "PPPreviewView.h"


#define PP_RUNTIME_CHECK__RUNTIME_HAS_PATTERN_PHASE_GLITCH_ISSUE                \
            (_PP_RUNTIME_CHECK__MAC_OS_X_VERSION_IS_AT_LEAST_10_(5)             \
                && _PP_RUNTIME_CHECK__MAC_OS_X_VERSION_IS_EARLIER_THAN_10_(6))


@implementation NSObject (PPOSXGlue_PatternPhaseGlitches)

+ (void) ppOSXGlue_PatternPhaseGlitches_InstallPatches
{
    macroSwizzleInstanceMethod(PPPreviewView, drawRect:, ppOSXPatch_DrawRect:);
}

+ (void) load
{
    if (PP_RUNTIME_CHECK__RUNTIME_HAS_PATTERN_PHASE_GLITCH_ISSUE)
    {
        macroPerformNSObjectSelectorAfterAppLoads(ppOSXGlue_PatternPhaseGlitches_InstallPatches);
    }
}

@end

@implementation PPPreviewView (PPOSXGlue_PatternPhaseGlitches)

- (void) ppOSXPatch_DrawRect: (NSRect) rect
{
    static NSPoint unglitchedPatternPhase = {5.0f, 0.0f};

    [[NSGraphicsContext currentContext] setPatternPhase: unglitchedPatternPhase];

    [self ppOSXPatch_DrawRect: rect];
}

@end

#endif  // __APPLE__
