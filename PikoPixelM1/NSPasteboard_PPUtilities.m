/*
    NSPasteboard_PPUtilities.m

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

#import "NSPasteboard_PPUtilities.h"

#import "NSData_PPNativePasteboardType.h"
#import "NSBitmapImageRep_PPUtilities.h"


#define kPPPasteboardImportTypeNames        \
                                {kPPNativePasteboardType, NSTIFFPboardType}

static NSArray *PPPasteboardImportTypes(void);


@implementation NSPasteboard (PPUtilities)

+ (bool) ppPasteboardHasBitmap
{
    NSPasteboard *pasteboard;
    NSArray *pasteboardTypes;

    pasteboard = [NSPasteboard generalPasteboard];
    pasteboardTypes = PPPasteboardImportTypes();

    if (!pasteboard || !pasteboardTypes)
    {
        return NO;
    }

    return ([pasteboard availableTypeFromArray: pasteboardTypes]) ? YES : NO;
}

+ (bool) ppGetImageBitmap: (NSBitmapImageRep **) returnedImageBitmap
            maskBitmap: (NSBitmapImageRep **) returnedMaskBitmap
            bitmapOrigin: (NSPoint *) returnedBitmapOrigin
            canvasSize: (NSSize *) returnedCanvasSize
            andOpacity: (float *) returnedOpacity
{
    NSPasteboard *pasteboard;
    NSString *availableType;
    NSBitmapImageRep *imageBitmap, *maskBitmap;
    NSPoint bitmapOrigin;
    NSSize canvasSize;
    float opacity;

    pasteboard = [NSPasteboard generalPasteboard];

    availableType = [pasteboard availableTypeFromArray: PPPasteboardImportTypes()];

    if (!availableType)
        goto ERROR;

    if ([availableType isEqualToString: kPPNativePasteboardType])
    {
        NSData *pasteboardData = [pasteboard dataForType: availableType];

        if (![pasteboardData ppNativePasteboardDataGetImageBitmap: &imageBitmap
                                maskBitmap: &maskBitmap
                                bitmapOrigin: &bitmapOrigin
                                canvasSize: &canvasSize
                                opacity: &opacity])
        {
            goto ERROR;
        }
    }
    else
    {
        NSImageRep *pasteboardImageRep = [NSImageRep imageRepWithPasteboard: pasteboard];

        imageBitmap = [pasteboardImageRep ppImageBitmap];

        if (!imageBitmap)
            goto ERROR;

        maskBitmap = nil;
        bitmapOrigin = NSZeroPoint;
        canvasSize = [imageBitmap ppSizeInPixels];
        opacity = 1.0f;
    }

    if (returnedImageBitmap)
    {
        *returnedImageBitmap = imageBitmap;
    }

    if (returnedMaskBitmap)
    {
        *returnedMaskBitmap = maskBitmap;
    }

    if (returnedBitmapOrigin)
    {
        *returnedBitmapOrigin = bitmapOrigin;
    }

    if (returnedCanvasSize)
    {
        *returnedCanvasSize = canvasSize;
    }

    if (returnedOpacity)
    {
        *returnedOpacity = opacity;
    }

    return YES;

ERROR:
    return NO;
}

+ (void) ppSetImageBitmap: (NSBitmapImageRep *) imageBitmap
            maskBitmap: (NSBitmapImageRep *) maskBitmap
            bitmapOrigin: (NSPoint) bitmapOrigin
            canvasSize: (NSSize) canvasSize
            andOpacity: (float) opacity
{
    NSData *nativePasteboardData, *tiffData;
    NSPasteboard *pasteboard;
    NSArray *pasteboardTypes;

    if (!imageBitmap || !maskBitmap)
    {
        goto ERROR;
    }

    imageBitmap = [imageBitmap ppImageBitmapMaskedWithMask: maskBitmap];

    if (!imageBitmap)
        goto ERROR;

    nativePasteboardData = [NSData ppNativePasteboardDataWithImageBitmap: imageBitmap
                                    maskBitmap: maskBitmap
                                    bitmapOrigin: bitmapOrigin
                                    canvasSize: canvasSize
                                    opacity: opacity];

    if (!nativePasteboardData)
        goto ERROR;

    if (opacity < 1.0f)
    {
        imageBitmap = [imageBitmap ppImageBitmapDissolvedToOpacity: opacity];
    }

    tiffData = [imageBitmap ppCompressedTIFFData];

    if (!tiffData)
        goto ERROR;

    pasteboard = [NSPasteboard generalPasteboard];
    pasteboardTypes =
                [NSArray arrayWithObjects: kPPNativePasteboardType, NSTIFFPboardType, nil];

    if (!pasteboard || !pasteboardTypes)
    {
        goto ERROR;
    }

    [pasteboard declareTypes: pasteboardTypes owner: self];

    [pasteboard setData: nativePasteboardData
                forType: kPPNativePasteboardType];

    [pasteboard setData: tiffData
                forType: NSTIFFPboardType];

    return;

ERROR:
    return;
}

+ (bool) ppGetImageBitmap: (NSBitmapImageRep **) returnedImageBitmap
{
    NSBitmapImageRep *imageBitmap;
    float opacity;

    if (!returnedImageBitmap)
        goto ERROR;

    if (![self ppGetImageBitmap: &imageBitmap
                maskBitmap: NULL
                bitmapOrigin: NULL
                canvasSize: NULL
                andOpacity: &opacity])
    {
        goto ERROR;
    }

    if (opacity < 1.0f)
    {
        NSBitmapImageRep *dissolvedBitmap =
                                    [imageBitmap ppImageBitmapDissolvedToOpacity: opacity];

        if (dissolvedBitmap)
        {
            imageBitmap = dissolvedBitmap;
        }
    }

    *returnedImageBitmap = imageBitmap;

    return YES;

ERROR:
    return NO;
}

+ (void) ppSetImageBitmap: (NSBitmapImageRep *) imageBitmap
{
    NSData *tiffData;
    NSPasteboard *pasteboard;
    NSArray *pasteboardTypes;

    if (!imageBitmap)
        goto ERROR;

    tiffData = [imageBitmap ppCompressedTIFFData];

    if (!tiffData)
        goto ERROR;

    pasteboard = [NSPasteboard generalPasteboard];
    pasteboardTypes = [NSArray arrayWithObjects: NSTIFFPboardType, nil];

    if (!pasteboard || !pasteboardTypes)
    {
        goto ERROR;
    }

    [pasteboard declareTypes: pasteboardTypes owner: self];

    [pasteboard setData: tiffData
                forType: NSTIFFPboardType];

    return;

ERROR:
    return;
}

@end

static NSArray *PPPasteboardImportTypes(void)
{
    static NSArray *pasteboardImportTypes = nil;

    if (!pasteboardImportTypes)
    {
        id pasteboardImportTypeNames[] = kPPPasteboardImportTypeNames;
        int numTypes = sizeof(pasteboardImportTypeNames) / sizeof(*pasteboardImportTypeNames);

        pasteboardImportTypes =
                [[NSArray arrayWithObjects: pasteboardImportTypeNames count: numTypes] retain];
    }

    return pasteboardImportTypes;
}
