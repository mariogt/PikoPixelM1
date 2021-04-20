/*
    PPCompositeThumbnail.m

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

#import "PPCompositeThumbnail.h"

#import "NSBitmapImageRep_PPUtilities.h"
#import "NSImage_PPUtilities.h"


@implementation PPCompositeThumbnail

+ compositeThumbnailFromView: (NSView *) view
    thumbnailOrigin: (NSPoint) thumbnailOrigin
{
    return [[[self alloc] initWithView: view thumbnailOrigin: thumbnailOrigin] autorelease];
}

- initWithView: (NSView *) view
    thumbnailOrigin: (NSPoint) thumbnailOrigin
{
    NSRect viewBounds;
    NSBitmapImageRep *compositeBitmap;
    NSImage *compositeImage;

    self = [super init];

    if (!self)
        goto ERROR;

    if (!view)
        goto ERROR;

    viewBounds = [view bounds];

    if (NSIsEmptyRect(viewBounds))
    {
        goto ERROR;
    }

    compositeBitmap = [NSBitmapImageRep ppImageBitmapOfSize: viewBounds.size];

    if (!compositeBitmap)
        goto ERROR;

    compositeImage = [NSImage ppImageWithBitmap: compositeBitmap];

    if (!compositeImage)
        goto ERROR;

    [view cacheDisplayInRect: viewBounds toBitmapImageRep: compositeBitmap];
    [compositeImage recache];

    _compositeBitmap = [compositeBitmap retain];
    _compositeImage = [compositeImage retain];

    _thumbnailOrigin = thumbnailOrigin;

    return self;

ERROR:
    [self release];

    return nil;
}

- init
{
    return [self initWithView: nil thumbnailOrigin: NSZeroPoint];
}

- (void) dealloc
{
    [_compositeBitmap release];
    [_compositeImage release];

    [super dealloc];
}

- (void) setThumbnailBitmap: (NSBitmapImageRep *) thumbnailBitmap
{
    [_compositeBitmap ppCopyFromBitmap: thumbnailBitmap toPoint: _thumbnailOrigin];

    [_compositeImage recache];
}

- (NSImage *) compositeImage
{
    return _compositeImage;
}

@end
