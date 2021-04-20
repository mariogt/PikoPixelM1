/*
    PPUIColors_Panels.h

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

#import <Cocoa/Cocoa.h>
#import "PPSRGBUtilities.h"


// Popup Panel backgrounds

#define kUIColor_ToolsPopupPanel_Background                                             \
            [NSColor ppSRGBColorWithRed: 0.0f green: 0.25f blue: 0.0f alpha: 0.85f]

#define kUIColor_ColorPickerPopupPanel_Background                                       \
            [NSColor ppSRGBColorWithWhite: 0.2f alpha: 0.85f]

#define kUIColor_SamplerImagePopupPanel_Background                                      \
            [NSColor ppSRGBColorWithWhite: 0.2f alpha: 0.95f]

#define kUIColor_LayerControlsPopupPanel_Background                                     \
            [NSColor ppSRGBColorWithRed: 0.32f green: 0.0f blue: 0.0f alpha: 0.85f]

#define kUIColor_NavigatorPopupPanel_Background                                         \
            [NSColor ppSRGBColorWithRed: 0.0f green: 0.0f blue: 0.26f alpha: 0.85f]

#define kUIColor_ScreencastPopupPanel_Background                                        \
            [NSColor ppSRGBColorWithRed: 0.92f green: 0.96f blue: 1.0f alpha: 0.95f]

#define kUIColor_DefaultPopupPanelBackground                                            \
            [NSColor ppSRGBColorWithWhite: 0.0f alpha: 0.85f]


// Tools Panel & Popup Panel

#define kUIColor_ToolsPanel_ActiveToolCellGradientInnerColor                            \
            [NSColor ppSRGBColorWithRed: 0.63f green: 0.64f blue: 0.64f alpha: 1.0f]

#define kUIColor_ToolsPanel_ActiveToolCellGradientOuterColor                            \
            [NSColor ppSRGBColorWithRed: 0.52f green: 0.53f blue: 0.53f alpha: 1.0f]

#define kUIColor_ToolsPanel_InactiveToolCellColor                                       \
            [NSColor ppSRGBColorWithWhite: 0.92f alpha: 1.0f]


// Sampler Image Popup Panel

#define kUIColor_SamplerImagePopupPanel_ColorWellOutline                                \
            [NSColor ppSRGBColorWithWhite: 0.62f alpha: 1.0f]


// Sampler Image Panel

#define kUIColor_SamplerImagePanel_ColorWellOutline                                     \
            [NSColor ppSRGBColorWithWhite: 0.51f alpha: 1.0f]

