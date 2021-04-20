/*
    PPSamplerImageView.m

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

#import "PPSamplerImageView.h"

#import "PPGeometry.h"
#import "PPDocumentSamplerImage.h"
#import "NSCursor_PPUtilities.h"
#import "NSObject_PPUtilities.h"
#import "PPCanvasView.h"
#import "PPCursorManager.h"
#import "NSColor_PPUtilities.h"
#import "NSBitmapImageRep_PPUtilities.h"


#define kMinAllowedValueForMinViewDimension         30
#define kMaxAllowedValueForMaxViewDimension         1000


#define kUIColor_SamplerBackgroundPattern                                               \
            [NSColor ppDiagonalCheckerboardPatternColorWithBoxDimension: 2.0f           \
                        color1: [NSColor ppSRGBColorWithWhite: 0.42f alpha: 1.0f]       \
                        color2: [NSColor ppSRGBColorWithWhite: 0.53f alpha: 1.0f]]


static NSColor *gSamplerBackgroundColor = nil;


@interface PPSamplerImageView (PrivateMethods)

- (void) addAsObserverForPPSamplerImageViewNotifications;
- (void) removeAsObserverForPPSamplerImageViewNotifications;
- (void) handlePPSamplerImageViewNotification_FrameDidChange: (NSNotification *) notification;

- (void) resetImageBoundsTrackingRect;

- (void) updateCursor;

- (float) defaultScaleForCurrentImage;

- (void) setupMinAndMaxScalesForImageFrame;

- (void) setupDrawBoundsAndTrackingForImageAndViewFrames;

- (void) setSamplerImageScaleWithImageDrawBoundsAndFrame;

- (void) beginSamplingImageAtWindowPoint: (NSPoint) locationInWindow;
- (void) continueSamplingImageAtWindowPoint: (NSPoint) locationInWindow;
- (void) finishSamplingImage;

- (NSColor *) colorAtWindowPoint: (NSPoint) windowLocation;

- (void) setLastSampledColor: (NSColor *) color;

- (void) notifyDelegateDidBrowseColor: (NSColor *) color;
- (void) notifyDelegateDidSelectColor: (NSColor *) color;
- (void) notifyDelegateDidCancelSelection;

@end

@implementation PPSamplerImageView

+ (void) initialize
{
    if ([self class] != [PPSamplerImageView class])
    {
        return;
    }

    gSamplerBackgroundColor = [kUIColor_SamplerBackgroundPattern retain];
}

- (id) initWithFrame: (NSRect) frameRect
{
    self = [super initWithFrame: frameRect];

    if (!self)
        goto ERROR;

    _minViewDimension = kMinAllowedValueForMinViewDimension;
    _maxViewDimension = kMaxAllowedValueForMaxViewDimension;
    _defaultImageDimension = kMinAllowedValueForMinViewDimension;

    [self addAsObserverForPPSamplerImageViewNotifications];

    return self;

ERROR:
    [self release];

    return nil;
}

- (void) dealloc
{
    [self removeAsObserverForPPSamplerImageViewNotifications];

    [_samplerImage release];

    [_lastSampledColor release];

    [super dealloc];
}

- (void) setSamplerImagePanelType: (PPSamplerImagePanelType) panelType
            minViewDimension: (float) minViewDimension
            maxViewDimension: (float) maxViewDimension
            defaultImageDimension: (float) defaultImageDimension
            delegate: (id) delegate
{
    if (minViewDimension < kMinAllowedValueForMinViewDimension)
    {
        minViewDimension = kMinAllowedValueForMinViewDimension;
    }

    if (maxViewDimension > kMaxAllowedValueForMaxViewDimension)
    {
        maxViewDimension = kMaxAllowedValueForMaxViewDimension;
    }

    if (maxViewDimension < minViewDimension)
    {
        maxViewDimension = minViewDimension;
    }

    if (defaultImageDimension < minViewDimension)
    {
        defaultImageDimension = minViewDimension;
    }
    else if (defaultImageDimension > maxViewDimension)
    {
        defaultImageDimension = maxViewDimension;
    }

    _panelType = panelType;
    _minViewDimension = minViewDimension;
    _maxViewDimension = maxViewDimension;
    _defaultImageDimension = defaultImageDimension;
    _delegate = delegate;

    if (_samplerImage)
    {
        [self setupMinAndMaxScalesForImageFrame];
    }
}

- (void) setSamplerImage: (PPDocumentSamplerImage *) samplerImage
{
    NSSize samplerImageSize;

    if (_samplerImage == samplerImage)
    {
        return;
    }

    [_samplerImage release];
    _samplerImage = [samplerImage retain];

    samplerImageSize = (samplerImage) ? [samplerImage size] : NSZeroSize;

    _imageFrame = PPGeometry_OriginRectOfSize(samplerImageSize);

    [self setupMinAndMaxScalesForImageFrame];

    [self setupDrawBoundsAndTrackingForImageAndViewFrames];
}

- (NSSize) viewSizeForResizingToProposedViewSize: (NSSize) proposedViewSize
            resizableDirectionsMask: (unsigned) resizableDirectionsMask
{
    float horizontalScale = 0.0f, verticalScale = 0.0f, scale;
    NSSize viewSize;

    if (NSIsEmptyRect(_imageFrame))
    {
        goto ERROR;
    }

    if (!(resizableDirectionsMask & kPPResizableDirectionsMask_Both))
    {
        goto ERROR;
    }

    if (resizableDirectionsMask & kPPResizableDirectionsMask_Horizontal)
    {
        if (proposedViewSize.width >= _minViewDimension)
        {
            horizontalScale = proposedViewSize.width / _imageFrame.size.width;
        }
        else
        {
            if (proposedViewSize.width > _minViewDimension / 2.0f)
            {
                horizontalScale = (2.0f * proposedViewSize.width - _minViewDimension)
                                    / _imageFrame.size.width;
            }
            else
            {
                horizontalScale = _minScaleForCurrentImage;
            }
        }
    }

    if (resizableDirectionsMask & kPPResizableDirectionsMask_Vertical)
    {
        if (proposedViewSize.height >= _minViewDimension)
        {
            verticalScale = proposedViewSize.height / _imageFrame.size.height;
        }
        else
        {
            if (proposedViewSize.height > _minViewDimension / 2.0f)
            {
                verticalScale = (2.0f * proposedViewSize.height - _minViewDimension)
                                    / _imageFrame.size.height;
            }
            else
            {
                verticalScale = _minScaleForCurrentImage;
            }
        }
    }

    scale = MAX(horizontalScale, verticalScale);

    if (scale > _maxScaleForCurrentImage)
    {
        scale = _maxScaleForCurrentImage;
    }
    else if (scale < _minScaleForCurrentImage)
    {
        scale = _minScaleForCurrentImage;
    }

    viewSize = PPGeometry_SizeScaledByFactorAndRoundedToIntegerValues(_imageFrame.size, scale);

    if (viewSize.width < _minViewDimension)
    {
        viewSize.width = _minViewDimension;
    }

    if (viewSize.height < _minViewDimension)
    {
        viewSize.height = _minViewDimension;
    }

    return viewSize;

ERROR:
    return NSZeroSize;
}

- (NSSize) viewSizeForScaledCurrentSamplerImage
{
    float scale;
    NSSize viewSize;

    if (!_samplerImage)
        goto ERROR;

    scale = [_samplerImage scalingFactorForSamplerImagePanelType: _panelType];

    if (scale < _minScaleForCurrentImage)
    {
        scale = (scale > 0.0f) ? _minScaleForCurrentImage : [self defaultScaleForCurrentImage];
    }
    else if (scale > _maxScaleForCurrentImage)
    {
        scale = _maxScaleForCurrentImage;
    }

    viewSize = PPGeometry_SizeScaledByFactorAndRoundedToIntegerValues(_imageFrame.size, scale);

    if (viewSize.width < _minViewDimension)
    {
        viewSize.width = _minViewDimension;
    }

    if (viewSize.height < _minViewDimension)
    {
        viewSize.height = _minViewDimension;
    }

    return viewSize;

ERROR:
    return NSMakeSize(_minViewDimension, _minViewDimension);
}

- (void) setupMouseTracking
{
    [self resetImageBoundsTrackingRect];

    [self updateCursor];
}

- (void) disableMouseTracking: (bool) shouldDisableTracking
{
    if (_mouseIsSamplingImage)
    {
        // disallow tracking while sampling
        shouldDisableTracking = YES;
    }
    else
    {
        shouldDisableTracking = (shouldDisableTracking) ? YES : NO;
    }

    if (_disallowMouseTracking == shouldDisableTracking)
    {
        return;
    }

    _disallowMouseTracking = shouldDisableTracking;

    [self setupMouseTracking];
}

- (bool) mouseIsSamplingImage
{
    return _mouseIsSamplingImage;
}

- (void) forceStopSamplingImage
{
    if (_mouseIsSamplingImage)
    {
        [self finishSamplingImage];
    }
}

#pragma mark NSView overrides

- (BOOL) acceptsFirstMouse: (NSEvent *) theEvent
{
    return YES;
}

- (void) drawRect: (NSRect) rect
{
    [[NSGraphicsContext currentContext] setImageInterpolation: NSImageInterpolationNone];

    [gSamplerBackgroundColor set];
    NSRectFill(_imageDrawBounds);

    [[_samplerImage image] drawInRect: _imageDrawBounds
                            fromRect: _imageFrame
                            operation: NSCompositeSourceOver
                            fraction: 1.0f];
}

- (void) mouseDown: (NSEvent *) theEvent
{
    [self beginSamplingImageAtWindowPoint: [theEvent locationInWindow]];
}

- (void) mouseDragged: (NSEvent *) theEvent
{
    [self continueSamplingImageAtWindowPoint: [theEvent locationInWindow]];
}

- (void) mouseUp: (NSEvent *) theEvent
{
    [self finishSamplingImage];
}

- (void) mouseEntered: (NSEvent *) theEvent
{
    NSTrackingRectTag trackingRectTag = [theEvent trackingNumber];

    if (trackingRectTag == _imageBoundsTrackingRectTag)
    {
        if (!_mouseIsInsideImageBoundsTrackingRect)
        {
            _mouseIsInsideImageBoundsTrackingRect = YES;

            [self updateCursor];
        }
    }
    else
    {
        [super mouseEntered: theEvent];
    }
}

- (void) mouseExited: (NSEvent *) theEvent
{
    NSTrackingRectTag trackingRectTag = [theEvent trackingNumber];

    if (trackingRectTag == _imageBoundsTrackingRectTag)
    {
        if (_mouseIsInsideImageBoundsTrackingRect)
        {
            _mouseIsInsideImageBoundsTrackingRect = NO;

            [self updateCursor];
        }
    }
    else
    {
        [super mouseExited: theEvent];
    }
}

#pragma mark PPSamplerImageView notifications

- (void) addAsObserverForPPSamplerImageViewNotifications
{
    [self setPostsFrameChangedNotifications: YES];

    [[NSNotificationCenter defaultCenter]
                            addObserver: self
                            selector:
                                @selector(handlePPSamplerImageViewNotification_FrameDidChange:)
                            name: NSViewFrameDidChangeNotification
                            object: self];
}

- (void) removeAsObserverForPPSamplerImageViewNotifications
{
    [[NSNotificationCenter defaultCenter] removeObserver: self
                                            name: NSViewFrameDidChangeNotification
                                            object: self];
}

- (void) handlePPSamplerImageViewNotification_FrameDidChange: (NSNotification *) notification
{
    [self setupDrawBoundsAndTrackingForImageAndViewFrames];

    [self setSamplerImageScaleWithImageDrawBoundsAndFrame];
}

#pragma mark Mouse tracking

- (void) resetImageBoundsTrackingRect
{
    NSRect newTrackingRect = NSZeroRect;
    bool mouseIsInsideNewTrackingRect = NO;

    if ([[self window] isVisible] && !_disallowMouseTracking)
    {
        newTrackingRect = _imageDrawBounds;

        if (!NSIsEmptyRect(newTrackingRect))
        {
            NSPoint mouseLocationInView =
                        [self convertPoint: [[self window] mouseLocationOutsideOfEventStream]
                                fromView: nil];

            mouseIsInsideNewTrackingRect =
                            (NSPointInRect(mouseLocationInView, newTrackingRect)) ? YES : NO;
        }
    }

    if (!NSEqualRects(newTrackingRect, _imageBoundsTrackingRect))
    {
        if (_imageBoundsTrackingRectTag)
        {
            [self removeTrackingRect: _imageBoundsTrackingRectTag];
            _imageBoundsTrackingRectTag = 0;

            _imageBoundsTrackingRect = NSZeroRect;
        }

        if (!NSIsEmptyRect(newTrackingRect))
        {
            _imageBoundsTrackingRectTag = [self addTrackingRect: newTrackingRect
                                                owner: self
                                                userData: NULL
                                                assumeInside: mouseIsInsideNewTrackingRect];

            if (_imageBoundsTrackingRectTag)
            {
                _imageBoundsTrackingRect = newTrackingRect;
            }
            else
            {
                mouseIsInsideNewTrackingRect = NO;
            }
        }
    }

    _mouseIsInsideImageBoundsTrackingRect = mouseIsInsideNewTrackingRect;
}

#pragma mark Cursor updates

- (void) updateCursor
{
    NSCursor *cursor;
    PPCursorLevel cursorLevel;

    cursor = (_mouseIsInsideImageBoundsTrackingRect || _mouseIsSamplingImage) ?
                [NSCursor ppColorSamplerToolCursor] : nil;

    cursorLevel = (_panelType == kPPSamplerImagePanelType_PopupPanel) ?
                        kPPCursorLevel_PopupPanel : kPPCursorLevel_Panel;

    [[PPCursorManager sharedManager] setCursor: cursor
                                        atLevel: cursorLevel
                                        isDraggingMouse: _mouseIsSamplingImage];
}

#pragma mark Private methods

- (float) defaultScaleForCurrentImage
{
    float maxImageDimension;

    if (!_samplerImage)
        goto ERROR;

    maxImageDimension = MAX(_imageFrame.size.width, _imageFrame.size.height);

    return _defaultImageDimension / maxImageDimension;

ERROR:
    return 1.0f;
}

- (void) setupMinAndMaxScalesForImageFrame
{
    float maxImageDimension;

    if (NSIsEmptyRect(_imageFrame))
    {
        return;
    }

    maxImageDimension = MAX(_imageFrame.size.width, _imageFrame.size.height);

    _maxScaleForCurrentImage = _maxViewDimension / maxImageDimension;
    _minScaleForCurrentImage = _minViewDimension / maxImageDimension;
}

- (void) setupDrawBoundsAndTrackingForImageAndViewFrames
{
    _imageDrawBounds = PPGeometry_ScaledBoundsForFrameOfSizeToFitFrameOfSize(_imageFrame.size,
                                                                            [self bounds].size);

    if ([[self window] isVisible])
    {
        [self setupMouseTracking];
    }

    [self setNeedsDisplay: YES];
}

- (void) setSamplerImageScaleWithImageDrawBoundsAndFrame
{
    float scale = (_imageDrawBounds.size.width / _imageFrame.size.width
                    + _imageDrawBounds.size.height / _imageFrame.size.height)
                        / 2.0f;

    [_samplerImage setScalingFactor: scale forSamplerImagePanelType: _panelType];
}

- (void) beginSamplingImageAtWindowPoint: (NSPoint) locationInWindow
{
    NSPoint locationInView;
    NSColor *sampledColor;

    locationInView = [self convertPoint: locationInWindow fromView: nil];

    if (!NSPointInRect(locationInView, _imageDrawBounds))
    {
        return;
    }

    _mouseIsSamplingImage = YES;
    [self disableMouseTracking: YES];

    sampledColor = [self colorAtWindowPoint: locationInWindow];

    if (sampledColor)
    {
        [self notifyDelegateDidBrowseColor: sampledColor];
    }

    [self setLastSampledColor: sampledColor];
}

- (void) continueSamplingImageAtWindowPoint: (NSPoint) locationInWindow
{
    NSColor *sampledColor;

    if (!_mouseIsSamplingImage)
        return;

    sampledColor = [self colorAtWindowPoint: locationInWindow];

    if ((sampledColor && ![_lastSampledColor isEqual: sampledColor])
        || (!sampledColor && _lastSampledColor))
    {
        [self notifyDelegateDidBrowseColor: sampledColor];

        [self setLastSampledColor: sampledColor];
    }
}

- (void) finishSamplingImage
{
    if (!_mouseIsSamplingImage)
        return;

    _mouseIsSamplingImage = NO;
    [self disableMouseTracking: NO];

    if (_lastSampledColor)
    {
        [self notifyDelegateDidSelectColor: _lastSampledColor];
    }
    else
    {
        [self notifyDelegateDidCancelSelection];
    }

    [self setLastSampledColor: nil];
}

- (NSColor *) colorAtWindowPoint: (NSPoint) windowLocation
{
    float horizontalScale, verticalScale;
    NSPoint viewLocation, imageLocation;

    horizontalScale = _imageDrawBounds.size.width / _imageFrame.size.width;
    verticalScale = _imageDrawBounds.size.height / _imageFrame.size.height;

    viewLocation = [self convertPoint: windowLocation fromView: nil];

    if (!NSPointInRect(viewLocation, _imageDrawBounds))
    {
        goto ERROR;
    }

    imageLocation =
        NSMakePoint(floorf((viewLocation.x - _imageDrawBounds.origin.x) / horizontalScale),
                    floorf((viewLocation.y - _imageDrawBounds.origin.y) / verticalScale));

    if (!NSPointInRect(imageLocation, _imageFrame))
    {
        goto ERROR;
    }

    return [[_samplerImage bitmap] ppImageColorAtPoint: imageLocation];

ERROR:
    return nil;
}

- (void) setLastSampledColor: (NSColor *) color
{
    if (_lastSampledColor == color)
    {
        return;
    }

    [_lastSampledColor release];
    _lastSampledColor = [color retain];
}

#pragma mark Delegate notifiers

- (void) notifyDelegateDidBrowseColor: (NSColor *) color
{
    if ([_delegate respondsToSelector: @selector(ppSamplerImageView:didBrowseColor:)])
    {
        [_delegate ppSamplerImageView: self didBrowseColor: color];
    }
}

- (void) notifyDelegateDidSelectColor: (NSColor *) color
{
    if (!color)
        return;

    if ([_delegate respondsToSelector: @selector(ppSamplerImageView:didSelectColor:)])
    {
        [_delegate ppSamplerImageView: self didSelectColor: color];
    }
}

- (void) notifyDelegateDidCancelSelection
{
    if ([_delegate respondsToSelector: @selector(ppSamplerImageViewDidCancelSelection:)])
    {
        [_delegate ppSamplerImageViewDidCancelSelection: self];
    }
}

@end
