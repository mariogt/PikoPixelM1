/*
    PPThumbnailImageView.m

    Copyright 2013-2018,2020 Josh Freeman
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

#import "PPThumbnailImageView.h"

#import "NSBitmapImageRep_PPUtilities.h"
#import "PPGeometry.h"
#import "PPBackgroundPattern.h"
#import "PPDefines.h"
#import "PPThumbnailUtilities.h"


@interface PPThumbnailImageView (PrivateMethods)

- (void) resizeBackgroundBitmapWithDestinationBounds;
- (bool) setupScaledBackgroundPattern;
- (void) setupBackgroundImageDrawMembers;
- (void) drawBackgroundBitmap;

@end

@implementation PPThumbnailImageView

- (id) initWithFrame: (NSRect) frameRect
{
    self = [super initWithFrame: frameRect];

    if (!self)
        goto ERROR;

    _viewSize = [self frame].size;

    return self;

ERROR:
    [self release];

    return nil;
}

- (void) dealloc
{
    [_sourceImage release];
    [_sourceBackgroundPattern release];
    [_scaledBackgroundPattern release];
    [_sourceBackgroundImage release];
    [_backgroundBitmap release];

    [super dealloc];
}

- (void) setImage: (NSImage *) image
{
    NSSize imageSize;

    if (_sourceImage == image)
    {
        return;
    }

    [_sourceImage release];
    _sourceImage = [image retain];

    imageSize = (image) ? [image size] : NSZeroSize;

    if (!NSEqualSizes(_sourceImageFrame.size, imageSize))
    {
        _sourceImageFrame.size = imageSize;

        _scaledThumbnailImageBounds =
            PPGeometry_ScaledBoundsForFrameOfSizeToFitFrameOfSize(imageSize, _viewSize);

        _thumbnailScale =
            PPGeometry_ScalingFactorOfSourceRectToDestinationRect(_sourceImageFrame,
                                                                _scaledThumbnailImageBounds);

        _imageInterpolationType =
            PPThumbUtils_ImageInterpolationForScalingFactor(_thumbnailScale);

        [self setupScaledBackgroundPattern];

        if (_sourceBackgroundImage)
        {
            [self setupBackgroundImageDrawMembers];
        }

        [self resizeBackgroundBitmapWithDestinationBounds];
    }

    [self setNeedsDisplay: YES];
}

- (void) handleUpdateToImage
{
    [self setNeedsDisplay: YES];
}

- (void) setBackgroundPattern: (PPBackgroundPattern *) backgroundPattern
{
    [self setBackgroundPattern: backgroundPattern andBackgroundImage: nil];
}

- (void) setBackgroundPattern: (PPBackgroundPattern *) backgroundPattern
            andBackgroundImage: (NSImage *) backgroundImage
{
    if (![_sourceBackgroundPattern isEqualToBackgroundPattern: backgroundPattern])
    {
        [_sourceBackgroundPattern release];
        _sourceBackgroundPattern = [backgroundPattern retain];

        if ([self setupScaledBackgroundPattern])
        {
            _backgroundBitmapIsDirty = YES;
        }
    }

    if (_sourceBackgroundImage != backgroundImage)
    {
        [_sourceBackgroundImage release];
        _sourceBackgroundImage = [backgroundImage retain];

        [self setupBackgroundImageDrawMembers];

        _backgroundBitmapIsDirty = YES;
    }

    if (_backgroundBitmapIsDirty)
    {
        [self setNeedsDisplay: YES];
    }
}

#pragma mark NSView overrides

- (void) drawRect: (NSRect) rect
{
    if (_backgroundBitmapIsDirty)
    {
        [self drawBackgroundBitmap];
    }

    [_backgroundBitmap drawInRect: _scaledThumbnailImageBounds];

    [[NSGraphicsContext currentContext] setImageInterpolation: _imageInterpolationType];

    [_sourceImage drawInRect: _scaledThumbnailImageBounds
                    fromRect: _sourceImageFrame
                    operation: NSCompositeSourceOver
                    fraction: 1.0f];
}

#pragma mark Private methods

- (void) resizeBackgroundBitmapWithDestinationBounds
{
    if (NSIsEmptyRect(_scaledThumbnailImageBounds))
    {
        return;
    }

    if (_backgroundBitmap)
    {
        if (NSEqualSizes(_scaledThumbnailImageBounds.size, [_backgroundBitmap ppSizeInPixels]))
        {
            return;
        }

        [_backgroundBitmap release];
    }

    _backgroundBitmap =
            [[NSBitmapImageRep ppImageBitmapOfSize: _scaledThumbnailImageBounds.size] retain];

    _backgroundBitmapIsDirty = YES;

    [self setNeedsDisplay: YES];
}

- (bool) setupScaledBackgroundPattern
{
    float scalingFactor;
    PPBackgroundPattern *scaledBackgroundPattern;

    if (!_sourceBackgroundPattern || !_sourceImage)
    {
        goto ERROR;
    }

    scalingFactor = _thumbnailScale * kScalingFactorForThumbnailBackgroundPatternSize;

    if (scalingFactor > 1.0f)
    {
        scalingFactor = 1.0f;
    }

    scaledBackgroundPattern =
                    [_sourceBackgroundPattern backgroundPatternScaledByFactor: scalingFactor];

    if ([_scaledBackgroundPattern isEqualToBackgroundPattern: scaledBackgroundPattern])
    {
        return NO;
    }

    [_scaledBackgroundPattern release];
    _scaledBackgroundPattern = [scaledBackgroundPattern retain];

    return YES;

ERROR:
    return NO;
}

- (void) setupBackgroundImageDrawMembers
{
    if (!_sourceBackgroundImage)
        goto ERROR;

    _sourceBackgroundImageFrame = PPGeometry_OriginRectOfSize([_sourceBackgroundImage size]);

    if (NSIsEmptyRect(_sourceBackgroundImageFrame))
    {
        goto ERROR;
    }

    _sourceBackgroundImageDrawBounds =
        PPGeometry_ScaledBoundsForFrameOfSizeToFitFrameOfSize(_sourceBackgroundImageFrame.size,
                                                            _scaledThumbnailImageBounds.size);

    _backgroundImageInterpolationType =
        PPThumbUtils_ImageInterpolationForSourceRectToDestinationRect(
                                                            _sourceBackgroundImageFrame,
                                                            _sourceBackgroundImageDrawBounds);

    return;

ERROR:
    _sourceBackgroundImageDrawBounds = NSZeroRect;

    return;
}

- (void) drawBackgroundBitmap
{
    [_backgroundBitmap ppSetAsCurrentGraphicsContext];

    [[_scaledBackgroundPattern patternFillColor] set];
    NSRectFill([_backgroundBitmap ppFrameInPixels]);

    if (_sourceBackgroundImage)
    {
        [[NSGraphicsContext currentContext]
                                    setImageInterpolation: _backgroundImageInterpolationType];

        [_sourceBackgroundImage drawInRect: _sourceBackgroundImageDrawBounds
                        fromRect: _sourceBackgroundImageFrame
                        operation: NSCompositeSourceOver
                        fraction: 1.0f];
    }

    [_backgroundBitmap ppRestoreGraphicsContext];

    _backgroundBitmapIsDirty = NO;
}

@end
