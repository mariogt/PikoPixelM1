/*
    NSImageRep_PPUtilities.m

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

#import "NSImageRep_PPUtilities.h"

#import "NSBitmapImageRep_PPUtilities.h"


@implementation NSImageRep (PPUtilities)

- (NSSize) ppSizeInPixels
{
    return NSMakeSize([self pixelsWide], [self pixelsHigh]);
}

- (NSRect) ppFrameInPixels
{
    return NSMakeRect(0, 0, [self pixelsWide], [self pixelsHigh]);
}

- (NSBitmapImageRep *) ppImageBitmap
{
    NSRect bitmapFrame;
    NSBitmapImageRep *imageBitmap;

    bitmapFrame = [self ppFrameInPixels];

    imageBitmap = [NSBitmapImageRep ppImageBitmapOfSize: bitmapFrame.size];

    if (!imageBitmap)
        goto ERROR;

    [imageBitmap ppSetAsCurrentGraphicsContext];

    [self drawInRect: bitmapFrame];

    [imageBitmap ppRestoreGraphicsContext];

    return imageBitmap;

ERROR:
    return nil;
}

@end
