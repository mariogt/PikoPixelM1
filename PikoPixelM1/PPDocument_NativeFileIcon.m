/*
    PPDocument_NativeFileIcon.m

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

#import "PPDocument_NativeFileIcon.h"

#import "PPGeometry.h"
#import "NSBitmapImageRep_PPUtilities.h"
#import "NSImage_PPUtilities.h"


#define kMinDimensionForFileIcon    256


@implementation PPDocument (NativeFileIcon)

- (NSImage *) nativeFileIconImage
{
    float maxCanvasDimension, scalingFactor;
    NSSize iconSize, scaledImageSize;
    NSPoint scaledImageOrigin;
    NSBitmapImageRep *iconBitmap;
    NSImage *iconImage;

    // File icon image needs to be square (non-square file icons are distorted on 10.7+)
    // and contain transparency (opaque icons have display issues on 10.4/10.5)

    if (NSIsEmptyRect(_canvasFrame))
    {
        goto ERROR;
    }

    maxCanvasDimension = MAX(_canvasFrame.size.width, _canvasFrame.size.height);

    if (maxCanvasDimension < kMinDimensionForFileIcon)
    {
        scalingFactor = ceilf(((float) kMinDimensionForFileIcon) / maxCanvasDimension);
    }
    else
    {
        scalingFactor = 1.0f;
    }

    iconSize =
        PPGeometry_SizeScaledByFactorAndRoundedToIntegerValues(
                                            NSMakeSize(maxCanvasDimension, maxCanvasDimension),
                                            scalingFactor);

    scaledImageSize =
        PPGeometry_SizeScaledByFactorAndRoundedToIntegerValues(_canvasFrame.size, scalingFactor);

    scaledImageOrigin = PPGeometry_OriginPointForCenteringSizeInSize(scaledImageSize, iconSize);

    iconBitmap = [NSBitmapImageRep ppImageBitmapOfSize: iconSize];

    if (!iconBitmap)
        goto ERROR;

    [iconBitmap ppScaledCopyFromImageBitmap: _mergedVisibleLayersBitmap
                inRect: _canvasFrame
                toPoint: scaledImageOrigin
                scalingFactor: scalingFactor];

    if (PPGeometry_RectIsSquare(_canvasFrame)
        && ![_mergedVisibleLayersBitmap ppImageBitmapHasTransparentPixels])
    {
        // workaround for 10.4/10.5 issue where setting a file's icon to a completely-opaque
        // image results in a blank icon: if the image is square (leaves no transparent edges
        // when scaled & centered on the icon) and completely opaque, then force transparency
        // by decreasing the alpha value of one pixel (top-left corner)

        PPImageBitmapPixel *iconPixel = (PPImageBitmapPixel *) [iconBitmap bitmapData];

        if (!iconPixel)
            goto ERROR;

        macroImagePixelComponent_Alpha(iconPixel) = kMaxImagePixelComponentValue - 1;
    }

    iconImage = [NSImage ppImageWithBitmap: iconBitmap];

    if (!iconImage)
        goto ERROR;

    return iconImage;

ERROR:
    return nil;
}

@end
