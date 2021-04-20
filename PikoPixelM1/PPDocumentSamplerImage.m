/*
    PPDocumentSamplerImage.m

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

#import "PPDocumentSamplerImage.h"

#import "NSBitmapImageRep_PPUtilities.h"
#import "NSImage_PPUtilities.h"


#define kMaxSamplerImageDimension           800

#define kSamplerImageCodingKey_TIFFData     @"TIFFData"


@implementation PPDocumentSamplerImage

+ (PPDocumentSamplerImage *) samplerImageWithBitmap: (NSBitmapImageRep *) bitmap
{
    return [[[self alloc] initWithBitmap: bitmap] autorelease];
}

- (PPDocumentSamplerImage *) initWithBitmap: (NSBitmapImageRep *) bitmap
{
    NSImage *image;
    NSData *compressedBitmapData;

    self = [super init];

    if (!self)
        goto ERROR;

    bitmap = [bitmap ppImageBitmapWithMaxDimension: kMaxSamplerImageDimension];
    image = [NSImage ppImageWithBitmap: bitmap];
    compressedBitmapData = [bitmap ppCompressedTIFFData];

    if (!bitmap || !image || !compressedBitmapData)
    {
        goto ERROR;
    }

    _bitmap = [bitmap retain];
    _image = [image retain];
    _compressedBitmapData = [compressedBitmapData retain];

    return self;

ERROR:
    [self release];

    return nil;
}

- (void) dealloc
{
    [_bitmap release];
    [_image release];
    [_compressedBitmapData release];

    [super dealloc];
}

- (NSBitmapImageRep *) bitmap
{
    return _bitmap;
}

- (NSImage *) image
{
    return _image;
}

- (NSData *) compressedBitmapData
{
    return _compressedBitmapData;
}

- (NSSize) size
{
    return [_bitmap ppSizeInPixels];
}

- (float) scalingFactorForSamplerImagePanelType: (PPSamplerImagePanelType) panelType
{
    if (!PPSamplerImagePanelType_IsValid(panelType))
    {
        goto ERROR;
    }

    return _scalingFactorsForPanels[(int) panelType];

ERROR:
    return 0.0f;
}

- (void) setScalingFactor: (float) scalingFactor
            forSamplerImagePanelType: (PPSamplerImagePanelType) panelType
{
    if (!PPSamplerImagePanelType_IsValid(panelType))
    {
        goto ERROR;
    }

    _scalingFactorsForPanels[(int) panelType] = scalingFactor;

    return;

ERROR:
    return;
}

#pragma mark NSObject overrides

- (BOOL) isEqual: (id) object
{
    return [[object compressedBitmapData] isEqual: _compressedBitmapData];
}

- (NSUInteger) hash
{
    if (!_hash)
    {
        _hash = [_compressedBitmapData hash];
    }

    return _hash;
}

#pragma mark NSCoding protocol

- (id) initWithCoder: (NSCoder *) aDecoder
{
    NSData *tiffData = [aDecoder decodeObjectForKey: kSamplerImageCodingKey_TIFFData];
    NSBitmapImageRep *bitmap = [NSBitmapImageRep imageRepWithData: tiffData];

    return [self initWithBitmap: bitmap];
}

- (void) encodeWithCoder: (NSCoder *) aCoder
{
    [aCoder encodeObject: _compressedBitmapData
            forKey: kSamplerImageCodingKey_TIFFData];
}

#pragma mark NSCopying protocol

- (id) copyWithZone: (NSZone *) zone
{
    return [[[self class] allocWithZone: zone]
                                    initWithBitmap: [[_bitmap copyWithZone: zone] autorelease]];
}

@end
