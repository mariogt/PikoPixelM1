/*
    PPTextAttributesDicts.m

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

#import "PPTextAttributesDicts.h"

#import "PPUIFontDefines.h"


NSDictionary *PPTextAttributesDict_ToolModifierTips_Header(void)
{
    static NSDictionary *headerAttributesDict = nil;

    if (!headerAttributesDict)
    {
        NSFont *font = kUIFont_ToolModifierTips_Header;
        NSNumber *underlineNumber = [NSNumber numberWithInt: 1];
        NSColor *color = kUIFontColor_ToolModifierTips_Header;

        if (!font || !underlineNumber)
        {
            goto ERROR;
        }

        headerAttributesDict = [[NSDictionary dictionaryWithObjectsAndKeys:
                                                font, NSFontAttributeName,
                                                underlineNumber, NSUnderlineStyleAttributeName,
                                                color, NSForegroundColorAttributeName,
                                                nil]
                                        retain];
    }

    return headerAttributesDict;

ERROR:
    return nil;
}

NSDictionary *PPTextAttributesDict_ToolModifierTips_Subheader(void)
{
    static NSDictionary *subheaderAttributesDict = nil;

    if (!subheaderAttributesDict)
    {
        NSFont *font = kUIFont_ToolModifierTips_Subheader;
        NSColor *color = kUIFontColor_ToolModifierTips_Subheader;

        if (!font)
            goto ERROR;

        subheaderAttributesDict = [[NSDictionary dictionaryWithObjectsAndKeys:
                                                    font, NSFontAttributeName,
                                                    color, NSForegroundColorAttributeName,
                                                    nil]
                                        retain];
    }

    return subheaderAttributesDict;

ERROR:
    return nil;
}

NSDictionary *PPTextAttributesDict_ToolModifierTips_Tips(void)
{
    static NSDictionary *tipsAttributesDict = nil;

    if (!tipsAttributesDict)
    {
        NSFont *font = kUIFont_ToolModifierTips_Tips;
        NSColor *color = kUIFontColor_ToolModifierTips_Tips;

        if (!font)
            goto ERROR;

        tipsAttributesDict = [[NSDictionary dictionaryWithObjectsAndKeys:
                                                    font, NSFontAttributeName,
                                                    color, NSForegroundColorAttributeName,
                                                    nil]
                                    retain];
    }

    return tipsAttributesDict;

ERROR:
    return nil;
}

NSDictionary *PPTextAttributesDict_DisabledTitle_Table(void)
{
    static NSDictionary *tableAttributesDict = nil;

    if (!tableAttributesDict)
    {
        NSFont *font = kUIFont_DisabledTitle_Table;
        NSColor *color = kUIFontColor_DisabledTitle_Table;

        if (!font || !color)
        {
            goto ERROR;
        }

        tableAttributesDict = [[NSDictionary dictionaryWithObjectsAndKeys:
                                                    font, NSFontAttributeName,
                                                    color, NSForegroundColorAttributeName,
                                                    nil]
                                            retain];
    }

    return tableAttributesDict;

ERROR:
    return nil;
}

NSDictionary *PPTextAttributesDict_DisabledTitle_PopupButton(void)
{
    static NSDictionary *buttonAttributesDict = nil;

    if (!buttonAttributesDict)
    {
        NSFont *font = kUIFont_DisabledTitle_PopupButton;
        NSColor *color = kUIFontColor_DisabledTitle_PopupButton;

        if (!font || !color)
        {
            goto ERROR;
        }

        buttonAttributesDict = [[NSDictionary dictionaryWithObjectsAndKeys:
                                                    font, NSFontAttributeName,
                                                    color, NSForegroundColorAttributeName,
                                                    nil]
                                            retain];
    }

    return buttonAttributesDict;

ERROR:
    return nil;
}

NSDictionary *PPTextAttributesDict_DisabledTitle_PopupMenuItem(void)
{
    static NSDictionary *menuItemAttributesDict = nil;

    if (!menuItemAttributesDict)
    {
        NSFont *font = kUIFont_DisabledTitle_PopupMenuItem;
        NSColor *color = kUIFontColor_DisabledTitle_PopupMenuItem;

        if (!font || !color)
        {
            goto ERROR;
        }

        menuItemAttributesDict = [[NSDictionary dictionaryWithObjectsAndKeys:
                                                    font, NSFontAttributeName,
                                                    color, NSForegroundColorAttributeName,
                                                    nil]
                                            retain];
    }

    return menuItemAttributesDict;

ERROR:
    return nil;
}
