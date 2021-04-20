/*
    PPUserDefaultsInitialValues.h

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

#import "PPBackgroundPattern.h"
#import "PPGridPattern.h"
#import "PPSRGBUtilities.h"


#define kUserDefaultsInitialValue_BackgroundPattern                                         \
                [PPBackgroundPattern                                                        \
                        backgroundPatternOfType: kPPBackgroundPatternType_IsometricLines    \
                        patternSize: 11                                                     \
                        color1: [NSColor ppSRGBColorWithWhite: 1.0f alpha: 1.0f]            \
                        color2: [NSColor ppSRGBColorWithWhite: 0.92f alpha: 1.0f]]

#define kUserDefaultsInitialValue_GridPattern                                               \
            [PPGridPattern gridPatternWithPixelGridType: kPPGridType_LargeDots              \
                            pixelGridColor:                                                 \
                                    [NSColor ppSRGBColorWithWhite: 0.73f alpha: 1.0f]       \
                            guidelineSpacingSize: NSMakeSize(8,8)                           \
                            guidelineColor:                                                 \
                                    [NSColor ppSRGBColorWithWhite: 0.23f alpha: 1.0f]       \
                            shouldDisplayGuidelines: NO]

#define kUserDefaultsInitialValue_GridVisibility    YES

#define kUserDefaultsInitialValue_ShouldDisplayFlattenedSaveNotice      YES


#if defined(__APPLE__)

#   define kUserDefaultsInitialValue_ColorPickerPopupPanelMode          NSCrayonModeColorPanel

#elif defined(GNUSTEP)  // !defined(__APPLE__)

    // GNUstep's Crayon Mode is currently unimplemented; use color wheel instead
#   define kUserDefaultsInitialValue_ColorPickerPopupPanelMode          NSWheelModeColorPanel

#endif  // defined(GNUSTEP)

