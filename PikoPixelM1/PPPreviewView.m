/*
    PPPreviewView.m

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

#import "PPPreviewView.h"

#import "NSColor_PPUtilities.h"
#import "PPGeometry.h"
#import "PPResizableDirectionsMasks.h"
#import "NSObject_PPUtilities.h"


#define kMaxPreviewScale                        12

#define kMaxContinuousScale                     (0.75f)

#define kRoundoffLimitForMaxContinuousScale     ((kMaxContinuousScale + 1.0f) / 2.0f)

#define kMinAllowedViewDimension                128


#define kUIColor_LightCheckerboardPattern                                               \
            [NSColor ppCheckerboardPatternColorWithBoxDimension: 8.0f                   \
                        color1: [NSColor whiteColor]                                    \
                        color2: [NSColor ppSRGBColorWithWhite: 0.90f alpha: 1.0f]]

#define kUIColor_DarkCheckerboardPattern                                                \
            [NSColor ppCheckerboardPatternColorWithBoxDimension: 8.0f                   \
                        color1: [NSColor ppSRGBColorWithWhite: 0.35f alpha: 1.0f]       \
                        color2: [NSColor blackColor]]


static NSColor *gLightCheckerboardColor = nil, *gDarkCheckerboardColor = nil;


@interface PPPreviewView (PrivateMethods)

- (void) setScale: (float) scale;

- (void) setScaleForSize: (NSSize) size
            isResizing: (bool) isResizing;

- (float) dimensionScaleForImageWithLength: (float) imageLength
            onViewWithLength: (float) viewLength;

- (void) handleResizingBegin;
- (void) handleResizingEnd;

- (void) notifyDelegateDidChangeScale;

@end

@implementation PPPreviewView

+ (void) initialize
{
    if ([self class] != [PPPreviewView class])
    {
        return;
    }

    gLightCheckerboardColor = [kUIColor_LightCheckerboardPattern retain];
    gDarkCheckerboardColor = [kUIColor_DarkCheckerboardPattern retain];
}

- (void) dealloc
{
    [_image release];
    [_backgroundFillColor release];

    [super dealloc];
}

- (void) setImage: (NSImage *) image
{
    NSSize imageSize;

    if (_image == image)
    {
        return;
    }

    [_image release];
    _image = [image retain];

    imageSize = (image) ? [image size] : NSZeroSize;

    if (!NSEqualSizes(imageSize, _imageFrame.size))
    {
        float maxDimension =
                    (imageSize.width > imageSize.height) ? imageSize.width : imageSize.height;

        if (maxDimension < kMinAllowedViewDimension)
        {
            _minimumScaleForCurrentImage = kMaxContinuousScale;
        }
        else
        {
            _minimumScaleForCurrentImage =
                kMaxContinuousScale * kMinAllowedViewDimension / maxDimension;
        }

        _imageFrame.size = imageSize;

        [self setScaleForSize: [self frame].size isResizing: NO];
    }

    [self setNeedsDisplay: YES];
}

- (void) handleUpdateToImage
{
    [self handleUpdateToImageInRect: _imageFrame];
}

- (void) handleUpdateToImageInRect: (NSRect) imageUpdateRect
{
    NSRect viewUpdateRect;

    imageUpdateRect = NSIntersectionRect(imageUpdateRect, _imageFrame);

    if (NSIsEmptyRect(imageUpdateRect))
    {
        return;
    }

    viewUpdateRect = PPGeometry_RectScaledByFactor(imageUpdateRect, _previewScale);
    viewUpdateRect.origin =
                        PPGeometry_PointSum(viewUpdateRect.origin, _scaledImageBounds.origin);

    if (_previewScale < 1.0f)
    {
        viewUpdateRect = PPGeometry_PixelBoundsCoveredByRect(viewUpdateRect);
    }

    [self setNeedsDisplayInRect: viewUpdateRect];
}

- (NSSize) prepareForNewFrameSize: (NSSize) newFrameSize
{
    float oldPreviewScale = _previewScale;
    NSSize oldFrameSize = [self frame].size;
    bool didChangePreviewScale, didChangeFrameSize;

    if (!_viewIsResizing)
    {
        [self handleResizingBegin];
        [self ppPerformSelectorAtomicallyFromNewStackFrame: @selector(handleResizingEnd)];
    }

    if (oldFrameSize.width != newFrameSize.width)
    {
        _resizableDirectionsMask |= kPPResizableDirectionsMask_Horizontal;
    }

    if (oldFrameSize.height != newFrameSize.height)
    {
        _resizableDirectionsMask |= kPPResizableDirectionsMask_Vertical;
    }

    [self setScaleForSize: newFrameSize isResizing: YES];

    newFrameSize = _scaledImageBounds.size;

    if (newFrameSize.width < kMinAllowedViewDimension)
    {
        newFrameSize.width = kMinAllowedViewDimension;
    }

    if (newFrameSize.height < kMinAllowedViewDimension)
    {
        newFrameSize.height = kMinAllowedViewDimension;
    }

    didChangePreviewScale = (oldPreviewScale != _previewScale) ? YES : NO;
    didChangeFrameSize = (!NSEqualSizes(oldFrameSize, newFrameSize)) ? YES : NO;

    if (didChangePreviewScale && !didChangeFrameSize)
    {
        //  On OS X, when the frame size doesn't change, there's a short delay between the call
        // to -[NSView setNeedsDisplay:] (called when scale changes) and the system's call
        // to -[NSView display] (takes about a second for the view to update - due to dragging?).
        //  To avoid the delay, manually call displayIfNeeded to force an immediate redraw.

        [self displayIfNeeded];
    }

    return newFrameSize;
}

- (void) setBackgroundType: (PPPreviewBackgroundType) backgroundType
{
    NSColor *newBackgroundFillColor;

    if (!PPPreviewBackgroundType_IsValid(backgroundType))
    {
        return;
    }

    switch (backgroundType)
    {
        case kPPPreviewBackgroundType_LightCheckerboard:
        {
            newBackgroundFillColor = gLightCheckerboardColor;
        }
        break;

        case kPPPreviewBackgroundType_DarkCheckerboard:
        {
            newBackgroundFillColor = gDarkCheckerboardColor;
        }
        break;

        case kPPPreviewBackgroundType_SolidGrey:
        {
            newBackgroundFillColor = [NSColor grayColor];
        }
        break;

        case kPPPreviewBackgroundType_SolidWhite:
        {
            newBackgroundFillColor = [NSColor whiteColor];
        }
        break;

        case kPPPreviewBackgroundType_SolidBlack:
        default:
        {
            newBackgroundFillColor = [NSColor blackColor];
        }
        break;
    }

    if (!newBackgroundFillColor)
        return;

    _backgroundType = backgroundType;

    [_backgroundFillColor release];
    _backgroundFillColor = [newBackgroundFillColor retain];

    [self setNeedsDisplay: YES];
}

- (void) toggleBackgroundType
{
    PPPreviewBackgroundType newBackgroundType = _backgroundType + 1;

    if (newBackgroundType >= kNumPPPreviewBackgroundTypes)
    {
        newBackgroundType = 0;
    }

    [self setBackgroundType: newBackgroundType];
}

- (void) setDelegate: (id) delegate
{
    _delegate = delegate;
}

- (id) delegate
{
    return _delegate;
}

#pragma mark NSView overrides

- (void) awakeFromNib
{
    // check before calling [super awakeFromNib] - before 10.6, some classes didn't implement it
    if ([[PPPreviewView superclass] instancesRespondToSelector: @selector(awakeFromNib)])
    {
        [super awakeFromNib];
    }

    [self setBackgroundType: 0];
}

- (void) mouseDown: (NSEvent *) theEvent
{
    [self toggleBackgroundType];
}

- (BOOL) acceptsFirstMouse: (NSEvent *) theEvent
{
    return YES;
}

- (void) drawRect: (NSRect) rect
{
    NSImageInterpolation interpolationType;

    // gray margin surrounding image (if draw rect is outside image bounds)

    if (!NSContainsRect(_scaledImageBounds, rect))
    {
        [[NSColor lightGrayColor] set];
        NSRectFill(rect);
    }

    if (NSIsEmptyRect(_imageFrame))
    {
        return;
    }

    // image background color/pattern

    [_backgroundFillColor set];
    NSRectFill(_scaledImageBounds);

    // preview image

    interpolationType =
                (_previewScale < 1.0f) ? NSImageInterpolationLow : NSImageInterpolationNone;

    [[NSGraphicsContext currentContext] setImageInterpolation: interpolationType];

    [_image drawInRect: _scaledImageBounds
            fromRect: _imageFrame
            operation: NSCompositeSourceOver
            fraction: 1.0f];
}

- (void) setFrameSize: (NSSize) newSize
{
    [super setFrameSize: newSize];

    _scaledImageBounds = PPGeometry_CenterRectInRect(_scaledImageBounds, [self bounds]);
}

#pragma mark Private methods

- (void) setScale: (float) scale
{
    if (scale >= 1.0f)
    {
        scale = floorf(scale);

        if (scale > kMaxPreviewScale)
        {
            scale = kMaxPreviewScale;
        }
    }
    else if (scale > kMaxContinuousScale)
    {
        scale = kMaxContinuousScale;
    }
    else if (scale < _minimumScaleForCurrentImage)
    {
        scale = _minimumScaleForCurrentImage;
    }

    _scaledImageBounds.size =
            PPGeometry_SizeScaledByFactorAndRoundedToIntegerValues(_imageFrame.size, scale);

    _scaledImageBounds = PPGeometry_CenterRectInRect(_scaledImageBounds, [self bounds]);

    if (_previewScale != scale)
    {
        _previewScale = scale;

        [self setNeedsDisplay: YES];

        [self notifyDelegateDidChangeScale];
    }
}

- (void) setScaleForSize: (NSSize) size
            isResizing: (bool) isResizing
{
    float horizontalScale = 0.0f, verticalScale = 0.0f, newScale;

    if (PPGeometry_IsZeroSize(_imageFrame.size))
    {
        return;
    }

    if (isResizing && !(_resizableDirectionsMask & kPPResizableDirectionsMask_Both))
    {
        return;
    }

    if (!isResizing || (_resizableDirectionsMask & kPPResizableDirectionsMask_Horizontal))
    {
        horizontalScale = [self dimensionScaleForImageWithLength: size.width
                                    onViewWithLength: _imageFrame.size.width];
    }

    if (!isResizing || (_resizableDirectionsMask & kPPResizableDirectionsMask_Vertical))
    {
        verticalScale = [self dimensionScaleForImageWithLength: size.height
                                onViewWithLength: _imageFrame.size.height];
    }

    if (isResizing)
    {
        newScale = MAX(horizontalScale, verticalScale);

        if (newScale > 1.0f)
        {
            newScale = roundf(newScale);
        }
        else if (newScale > kRoundoffLimitForMaxContinuousScale)
        {
            newScale = 1.0f;
        }
    }
    else
    {
        newScale = MIN(horizontalScale, verticalScale);
    }

    [self setScale: newScale];
}

- (float) dimensionScaleForImageWithLength: (float) imageLength
            onViewWithLength: (float) viewLength
{
    float scale;

    if (viewLength <= 0.0f)
    {
        return _minimumScaleForCurrentImage;
    }

    if (imageLength >= kMinAllowedViewDimension)
    {
        scale = imageLength / viewLength;
    }
    else
    {
        // when size is less than the minimum allowed view dimension, the scale should shrink
        // to zero as the size approaches half the minimum (mouse is dragging towards the
        // view's center)
        scale = (kMinAllowedViewDimension - 2.0f * (kMinAllowedViewDimension - imageLength))
                    / viewLength;
    }

    if (scale < _minimumScaleForCurrentImage)
    {
        scale = _minimumScaleForCurrentImage;
    }
    else if (scale > kMaxPreviewScale)
    {
        scale = kMaxPreviewScale;
    }

    return scale;
}

- (void) handleResizingBegin
{
    if (_viewIsResizing)
        return;

    _viewIsResizing = YES;

    _resizableDirectionsMask = kPPResizableDirectionsMask_None;
}

- (void) handleResizingEnd
{
    _viewIsResizing = NO;
}

#pragma mark Delegate notifiers

- (void) notifyDelegateDidChangeScale
{
    if ([_delegate respondsToSelector: @selector(ppPreviewView:didChangeScale:)])
    {
        [_delegate ppPreviewView: self didChangeScale: _previewScale];
    }
}

@end
