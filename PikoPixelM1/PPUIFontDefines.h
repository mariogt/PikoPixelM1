/*
    PPUIFontDefines.h

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


// Tool Modifier Tips

//      Header
#define kUIFont_ToolModifierTips_Header             \
            [NSFont fontWithName: @"LucidaGrande" size: 11.0f]

#define kUIFontColor_ToolModifierTips_Header        \
            [NSColor ppSRGBColorWithWhite: 0.0f alpha: 1.0f]


//      Subheader
#define kUIFont_ToolModifierTips_Subheader          \
            [NSFont fontWithName: @"LucidaGrande" size: 9.0f]

#define kUIFontColor_ToolModifierTips_Subheader     \
            [NSColor ppSRGBColorWithRed: 0.26f green: 0.06f blue: 0.01f alpha: 1.0f]


//      Tips
#define kUIFont_ToolModifierTips_Tips               \
            [NSFont fontWithName: @"LucidaGrande-Bold" size: 11.0f]

#define kUIFontColor_ToolModifierTips_Tips          \
            [NSColor ppSRGBColorWithRed: 0.02f green: 0.1f blue: 0.43f alpha: 1.0f]


// Disabled Titles

//      Table
#define kUIFont_DisabledTitle_Table                 \
            [NSFont systemFontOfSize: 0.0]

#define kUIFontColor_DisabledTitle_Table            \
            [NSColor ppSRGBColorWithWhite: 0.66f alpha: 1.0f]


//      Popup Button
#define kUIFont_DisabledTitle_PopupButton           \
            [NSFont boldSystemFontOfSize: 0.0]

#define kUIFontColor_DisabledTitle_PopupButton      \
            [NSColor ppSRGBColorWithWhite: 0.62f alpha: 1.0f]


//      Popup Menu Item
#define kUIFont_DisabledTitle_PopupMenuItem         \
            [NSFont boldSystemFontOfSize: 0.0]

#define kUIFontColor_DisabledTitle_PopupMenuItem    \
            [NSColor ppSRGBColorWithWhite: 0.73f alpha: 1.0f]
