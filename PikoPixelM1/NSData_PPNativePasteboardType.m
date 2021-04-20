/*
    NSData_PPNativePasteboardType.m

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

#import "NSData_PPNativePasteboardType.h"

#import "NSBitmapImageRep_PPUtilities.h"
#import "PPGeometry.h"


NSString *kPPNativePasteboardType = @"PikoPixel Native Pasteboard Type";


@implementation NSData (PPNativePasteboardType)

+ (NSData *) ppNativePasteboardDataWithImageBitmap: (NSBitmapImageRep *) imageBitmap
                maskBitmap: (NSBitmapImageRep *) maskBitmap
                bitmapOrigin: (NSPoint) bitmapOrigin
                canvasSize: (NSSize) canvasSize
                opacity: (float) opacity
{
    NSData *imageBitmapData, *maskBitmapData;
    NSString *positionRectString;
    NSNumber *opacityNumber;
    NSArray *nativePasteboardArray;

    if (![imageBitmap ppIsImageBitmapAndSameSizeAsMaskBitmap: maskBitmap])
    {
        goto ERROR;
    }

    imageBitmapData = [imageBitmap ppCompressedTIFFData];

    maskBitmapData = [maskBitmap ppCompressedTIFFData];

    positionRectString = NSStringFromRect(NSMakeRect(bitmapOrigin.x, bitmapOrigin.y,
                                                        canvasSize.width, canvasSize.height));

    opacityNumber = [NSNumber numberWithFloat: opacity];

    if (!imageBitmapData || !maskBitmapData || !positionRectString || !opacityNumber)
    {
        goto ERROR;
    }

    nativePasteboardArray = [NSArray arrayWithObjects: imageBitmapData, maskBitmapData,
                                                        positionRectString, opacityNumber, nil];

    if (!nativePasteboardArray)
        goto ERROR;

    return [NSArchiver archivedDataWithRootObject: nativePasteboardArray];

ERROR:
    return nil;
}

- (bool) ppNativePasteboardDataGetImageBitmap: (NSBitmapImageRep **) returnedImageBitmap
            maskBitmap: (NSBitmapImageRep **) returnedMaskBitmap
            bitmapOrigin: (NSPoint *) returnedBitmapOrigin
            canvasSize: (NSSize *) returnedCanvasSize
            opacity: (float *) returnedOpacity
{
    NSArray *nativePasteboardArray;
    NSData *imageBitmapData, *maskBitmapData;
    NSString *positionRectString;
    NSNumber *opacityNumber;
    NSBitmapImageRep *imageBitmap, *maskBitmap;
    NSRect positionRect;
    float opacity;

    nativePasteboardArray = [NSUnarchiver unarchiveObjectWithData: self];

    if (!nativePasteboardArray
        || ![nativePasteboardArray isKindOfClass: [NSArray class]]
        || ([nativePasteboardArray count] != 4))
    {
        goto ERROR;
    }

    imageBitmapData = [nativePasteboardArray objectAtIndex: 0];
    maskBitmapData = [nativePasteboardArray objectAtIndex: 1];
    positionRectString = [nativePasteboardArray objectAtIndex: 2];
    opacityNumber = [nativePasteboardArray objectAtIndex: 3];

    if (!imageBitmapData || !maskBitmapData || !positionRectString || !opacityNumber)
    {
        goto ERROR;
    }

    imageBitmap = [NSBitmapImageRep imageRepWithData: imageBitmapData];
    maskBitmap = [NSBitmapImageRep imageRepWithData: maskBitmapData];
    positionRect = NSRectFromString(positionRectString);
    opacity = [opacityNumber floatValue];

    if (!imageBitmap || !maskBitmap)
    {
        goto ERROR;
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
        *returnedBitmapOrigin = positionRect.origin;
    }

    if (returnedCanvasSize)
    {
        *returnedCanvasSize = positionRect.size;
    }

    if (returnedOpacity)
    {
        *returnedOpacity = opacity;
    }

    return YES;

ERROR:
    return NO;
}

@end
