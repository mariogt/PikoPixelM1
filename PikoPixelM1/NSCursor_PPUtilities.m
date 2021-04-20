/*
    NSCursor_PPUtilities.m

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

#import "NSCursor_PPUtilities.h"

#import "PPCursorDefines.h"


@implementation NSCursor (PPUtilities)

+ (NSCursor *) ppPencilCursor
{
    static NSCursor *pencilCursor = nil;

    if (!pencilCursor)
    {
        pencilCursor =
            [[NSCursor alloc] initWithImage: [NSImage imageNamed: kPPCursorImageName_Pencil]
                                hotSpot: kPPCursorHotSpotPoint_Pencil];
    }

    return pencilCursor;
}

+ (NSCursor *) ppEraserCursor;
{
    static NSCursor *eraserCursor = nil;

    if (!eraserCursor)
    {
        eraserCursor =
            [[NSCursor alloc] initWithImage: [NSImage imageNamed: kPPCursorImageName_Eraser]
                                hotSpot: kPPCursorHotSpotPoint_Eraser];
    }

    return eraserCursor;
}

+ (NSCursor *) ppFillToolCursor;
{
    static NSCursor *fillBucketCursor = nil;

    if (!fillBucketCursor)
    {
        fillBucketCursor =
            [[NSCursor alloc] initWithImage: [NSImage imageNamed: kPPCursorImageName_FillBucket]
                                hotSpot: kPPCursorHotSpotPoint_FillBucket];
    }

    return fillBucketCursor;
}

+ (NSCursor *) ppLineToolCursor;
{
    static NSCursor *lineToolCursor = nil;

    if (!lineToolCursor)
    {
        lineToolCursor =
            [[NSCursor alloc] initWithImage: [NSImage imageNamed: kPPCursorImageName_LineTool]
                                hotSpot: kPPCursorHotSpotPoint_LineTool];
    }

    return lineToolCursor;
}

+ (NSCursor *) ppRectToolCursor;
{
    static NSCursor *rectToolCursor = nil;

    if (!rectToolCursor)
    {
        rectToolCursor =
            [[NSCursor alloc] initWithImage: [NSImage imageNamed: kPPCursorImageName_RectTool]
                                hotSpot: kPPCursorHotSpotPoint_RectTool];
    }

    return rectToolCursor;
}

+ (NSCursor *) ppOvalToolCursor;
{
    static NSCursor *ovalToolCursor = nil;

    if (!ovalToolCursor)
    {
        ovalToolCursor =
            [[NSCursor alloc] initWithImage: [NSImage imageNamed: kPPCursorImageName_OvalTool]
                                hotSpot: kPPCursorHotSpotPoint_OvalTool];
    }

    return ovalToolCursor;
}

+ (NSCursor *) ppFreehandSelectCursor;
{
    static NSCursor *freehandSelectCursor = nil;

    if (!freehandSelectCursor)
    {
        freehandSelectCursor =
            [[NSCursor alloc] initWithImage:
                                        [NSImage imageNamed: kPPCursorImageName_FreehandSelect]
                                hotSpot: kPPCursorHotSpotPoint_FreehandSelect];
    }

    return freehandSelectCursor;
}

+ (NSCursor *) ppRectSelectCursor;
{
    static NSCursor *rectSelectCursor = nil;

    if (!rectSelectCursor)
    {
        rectSelectCursor =
            [[NSCursor alloc] initWithImage: [NSImage imageNamed: kPPCursorImageName_RectSelect]
                                hotSpot: kPPCursorHotSpotPoint_RectSelect];
    }

    return rectSelectCursor;
}

+ (NSCursor *) ppMagicWandCursor;
{
    static NSCursor *magicWandCursor = nil;

    if (!magicWandCursor)
    {
        magicWandCursor =
            [[NSCursor alloc] initWithImage: [NSImage imageNamed: kPPCursorImageName_MagicWand]
                                hotSpot: kPPCursorHotSpotPoint_MagicWand];
    }

    return magicWandCursor;
}

+ (NSCursor *) ppColorSamplerToolCursor;
{
    static NSCursor *colorSamplerCursor = nil;

    if (!colorSamplerCursor)
    {
        colorSamplerCursor =
            [[NSCursor alloc] initWithImage:
                                        [NSImage imageNamed: kPPCursorImageName_ColorSampler]
                                hotSpot: kPPCursorHotSpotPoint_ColorSampler];
    }

    return colorSamplerCursor;
}

+ (NSCursor *) ppMoveToolCursor;
{
    static NSCursor *moveToolCursor = nil;

    if (!moveToolCursor)
    {
        moveToolCursor =
            [[NSCursor alloc] initWithImage: [NSImage imageNamed: kPPCursorImageName_MoveTool]
                                hotSpot: kPPCursorHotSpotPoint_MoveTool];
    }

    return moveToolCursor;
}

+ (NSCursor *) ppMoveSelectionOutlineToolCursor
{
    static NSCursor *moveSelectionOutlineToolCursor = nil;

    if (!moveSelectionOutlineToolCursor)
    {
        moveSelectionOutlineToolCursor =
            [[NSCursor alloc] initWithImage:
                                    [NSImage imageNamed:
                                                kPPCursorImageName_MoveSelectionOutlineTool]
                                hotSpot: kPPCursorHotSpotPoint_MoveTool];
    }

    return moveSelectionOutlineToolCursor;
}

+ (NSCursor *) ppMagnifierCursor;
{
    static NSCursor *magnifierCursor = nil;

    if (!magnifierCursor)
    {
        magnifierCursor =
            [[NSCursor alloc] initWithImage: [NSImage imageNamed: kPPCursorImageName_Magnifier]
                                hotSpot: kPPCursorHotSpotPoint_Magnifier];
    }

    return magnifierCursor;
}

+ (NSCursor *) ppColorRampToolCursor
{
    static NSCursor *colorRampToolCursor = nil;

    if (!colorRampToolCursor)
    {
        colorRampToolCursor =
            [[NSCursor alloc] initWithImage:
                                        [NSImage imageNamed: kPPCursorImageName_ColorRampTool]
                                hotSpot: kPPCursorHotSpotPoint_ColorRampTool];
    }

    return colorRampToolCursor;
}

@end
