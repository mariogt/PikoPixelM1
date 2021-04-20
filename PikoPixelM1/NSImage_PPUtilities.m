/*
    NSImage_PPUtilities.m

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

#import "NSImage_PPUtilities.h"

#import "NSBitmapImageRep_PPUtilities.h"
#import "PPGeometry.h"


@implementation NSImage (PPUtilities)

+ (NSImage *) ppImageWithBitmap: (NSBitmapImageRep *) bitmap
{
    NSSize imageSize;
    NSImage *image;

    if (!bitmap)
        goto ERROR;

    imageSize = [bitmap ppSizeInPixels];

    if (PPGeometry_IsZeroSize(imageSize))
    {
        goto ERROR;
    }

    image = [[[NSImage alloc] initWithSize: imageSize] autorelease];

    if (!image)
        goto ERROR;

    [image addRepresentation: bitmap];

    return image;

ERROR:
    return nil;
}

- (NSBitmapImageRep *) ppBitmap
{
    NSData *imageData;
    NSBitmapImageRep *bitmap;
    NSSize bitmapSize;

    imageData = [self TIFFRepresentation];

    if (!imageData)
        goto ERROR;

    bitmap = [NSBitmapImageRep imageRepWithData: imageData];

    if (!bitmap)
        goto ERROR;

    // -[NSBitmapImageRep imageRepWithData:] sometimes sets the wrong size, so set manually:
    bitmapSize = [bitmap ppSizeInPixels];
    [bitmap setSize: bitmapSize];

    return bitmap;

ERROR:
    return nil;
}

- (NSData *) ppCompressedBitmapData
{
    return [[self ppBitmap] ppCompressedTIFFData];
}

- (bool) ppIsOpaque
{
    NSBitmapImageRep *bitmap, *imageBitmap;

    bitmap = [self ppBitmap];

    if (!bitmap)
        goto ERROR;

    if (![bitmap hasAlpha])
    {
        return YES;
    }

    imageBitmap = [bitmap ppImageBitmap];

    if (!imageBitmap)
        goto ERROR;

    return ([imageBitmap ppImageBitmapHasTransparentPixels]) ? NO : YES;

ERROR:
    return NO;
}

@end
