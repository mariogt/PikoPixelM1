/*
    PPDocumentScaleSheetController.m

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

#import "PPDocumentScaleSheetController.h"

#import "PPDefines.h"
#import "NSTextField_PPUtilities.h"
#import "NSBitmapImageRep_PPUtilities.h"
#import "NSImage_PPUtilities.h"
#import "PPGeometry.h"


#define kDocumentScaleSheetNibName                  @"DocumentScaleSheet"

#define kMaxAllowedScalingFactor                    50
#define kMinValidScalingFactor                      2

#define kMarginPaddingForScrollerlessScrollView     2


@interface PPDocumentScaleSheetController (PrivateMethods)

- initWithCanvasBitmap: (NSBitmapImageRep *) canvasBitmap andDelegate: (id) delegate;

- (void) addAsObserverForNSViewNotificationsFromPreviewClipView;
- (void) removeAsObserverForNSViewNotificationsFromPreviewClipView;
- (void) handlePreviewClipViewNotification_BoundsDidChange: (NSNotification *) notification;

- (void) setScalingType: (PPScalingType) scalingType;
- (void) updateScalingFactorControlValues;
- (void) updatePreviewImageForCurrentScaledSize;
- (void) scrollPreviewToNormalizedCenter;

@end


#if PP_SDK_REQUIRES_PROTOCOLS_FOR_DELEGATES_AND_DATASOURCES

@interface PPDocumentScaleSheetController (RequiredProtocols) <NSTextFieldDelegate>
@end

#endif  // PP_SDK_REQUIRES_PROTOCOLS_FOR_DELEGATES_AND_DATASOURCES


@implementation PPDocumentScaleSheetController

+ (bool) beginScaleSheetForDocumentWindow: (NSWindow *) window
            canvasBitmap: (NSBitmapImageRep *) canvasBitmap
            delegate: (id) delegate;
{
    PPDocumentScaleSheetController *controller;

    controller =
        [[[self alloc] initWithCanvasBitmap: canvasBitmap andDelegate: delegate] autorelease];

    if (![controller beginSheetModalForWindow: window])
    {
        goto ERROR;
    }

    return YES;

ERROR:
    return NO;
}

- initWithCanvasBitmap: (NSBitmapImageRep *) canvasBitmap andDelegate: (id) delegate
{
    NSImage *canvasImage;
    float maxDimension;
    int scalingTypeCounter;

    self = [super initWithNibNamed: kDocumentScaleSheetNibName delegate: delegate];

    if (!self)
        goto ERROR;

    if (!canvasBitmap)
        goto ERROR;

    canvasImage = [NSImage ppImageWithBitmap: canvasBitmap];

    if (!canvasImage)
        goto ERROR;

    _canvasBitmap = [canvasBitmap retain];
    _canvasImage = [canvasImage retain];

    _originalSize = [_canvasBitmap ppSizeInPixels];

    maxDimension = MAX(_originalSize.width, _originalSize.height);

    _maxScalingFactorForScalingType[kPPScalingType_Upscale] =
            MAX(MIN(kMaxAllowedScalingFactor, floorf(kMaxCanvasDimension / maxDimension)), 1);

    _maxScalingFactorForScalingType[kPPScalingType_Downscale] =
            MAX(MIN(kMaxAllowedScalingFactor, floorf(maxDimension / kMinCanvasDimension)), 1);

    for (scalingTypeCounter=0; scalingTypeCounter<kNumPPScalingTypes; scalingTypeCounter++)
    {
        if (_maxScalingFactorForScalingType[scalingTypeCounter] > kMinValidScalingFactor)
        {
            _minScalingFactorForScalingType[scalingTypeCounter] = kMinValidScalingFactor;
        }
        else
        {
            _minScalingFactorForScalingType[scalingTypeCounter] =
                                            _maxScalingFactorForScalingType[scalingTypeCounter];
        }
    }

    _previewScrollViewInitialFrame = [[_previewImageView enclosingScrollView] frame];
    _previewScrollerWidth =
                _previewScrollViewInitialFrame.size.width
                    - [[[_previewImageView enclosingScrollView] contentView] frame].size.width;

    _previewViewNormalizedCenter = NSMakePoint(0.5f, 0.5f);

    [_previewImageView setImage: [NSImage ppImageWithBitmap: canvasBitmap]];
    [_previewImageView setImageScaling: NSImageScaleAxesIndependently];

    [self addAsObserverForNSViewNotificationsFromPreviewClipView];

    [_scalingFactorTextField setDelegate: self];

    [self setScalingType: kPPScalingType_Upscale];

    return self;

ERROR:
    [self release];

    return nil;
}

- init
{
    return [self initWithCanvasBitmap: nil andDelegate: nil];
}

- (void) dealloc
{
    [self removeAsObserverForNSViewNotificationsFromPreviewClipView];

    [_canvasImage release];
    [_canvasBitmap release];

    [super dealloc];
}

#pragma mark Actions

- (IBAction) scalingFactorTypePopUpButtonItemSelected: (id) sender
{
    [self setScalingType: [[_scalingFactorTypePopUpButton selectedItem] tag]];
}

- (IBAction) scalingFactorSliderMoved: (id) sender
{
    unsigned newScalingFactor = [_scalingFactorSlider intValue];

    if (newScalingFactor == _scalingFactor)
    {
        return;
    }

    _scalingFactor = newScalingFactor;

    [self updateScalingFactorControlValues];
}

#pragma mark PPDocumentSheetController overrides (delegate notifiers)

- (void) notifyDelegateSheetDidFinish
{
    if (_scalingFactor < kMinValidScalingFactor)
    {
        [self notifyDelegateSheetDidCancel];
        return;
    }

    if ([_delegate respondsToSelector: @selector(documentScaleSheetDidFinishWithNewImageSize:)])
    {
        [_delegate documentScaleSheetDidFinishWithNewImageSize: _scaledSize];
    }
}

- (void) notifyDelegateSheetDidCancel
{
    if ([_delegate respondsToSelector: @selector(documentScaleSheetDidCancel)])
    {
        [_delegate documentScaleSheetDidCancel];
    }
}

#pragma mark NSTextField delegate methods (Scaling factor textfield)

- (void) controlTextDidChange: (NSNotification *) notification
{
    int newScalingFactor =
            [_scalingFactorTextField ppClampIntValueToMax:
                                                _maxScalingFactorForScalingType[_scalingType]
                                        min: _minScalingFactorForScalingType[_scalingType]
                                        defaultValue: _scalingFactor];

    if (newScalingFactor != _scalingFactor)
    {
        _scalingFactor = newScalingFactor;

        [self updateScalingFactorControlValues];
    }
}

#pragma mark NSView notifications (Preview imageview’s clipview)

- (void) addAsObserverForNSViewNotificationsFromPreviewClipView
{
    NSClipView *clipView = [[_previewImageView enclosingScrollView] contentView];

    if (!clipView)
        return;

    [clipView setPostsBoundsChangedNotifications: YES];

    [[NSNotificationCenter defaultCenter]
                                    addObserver: self
                                    selector:
                                        @selector(
                                            handlePreviewClipViewNotification_BoundsDidChange:)
                                    name: NSViewBoundsDidChangeNotification
                                    object: clipView];
}

- (void) removeAsObserverForNSViewNotificationsFromPreviewClipView
{
    NSClipView *clipView = [[_previewImageView enclosingScrollView] contentView];

    [[NSNotificationCenter defaultCenter] removeObserver: self
                                            name: NSViewBoundsDidChangeNotification
                                            object: clipView];
}

- (void) handlePreviewClipViewNotification_BoundsDidChange: (NSNotification *) notification
{
    NSRect documentVisibleRect;

    if (_shouldPreservePreviewNormalizedCenter)
        return;

    documentVisibleRect = [[_previewImageView enclosingScrollView] documentVisibleRect];

    _previewViewNormalizedCenter =
        NSMakePoint(((documentVisibleRect.origin.x + documentVisibleRect.size.width / 2.0)
                            / _scaledSize.width),
                        ((documentVisibleRect.origin.y + documentVisibleRect.size.height / 2.0)
                            / _scaledSize.height));
}

#pragma mark Private methods

- (void) setScalingType: (PPScalingType) scalingType
{
    unsigned minScalingFactor, maxScalingFactor;

    if (((unsigned) scalingType) >= kNumPPScalingTypes)
    {
        goto ERROR;
    }

    _scalingType = scalingType;

    [_scalingFactorTypePopUpButton selectItemWithTag: (NSInteger) _scalingType];

    minScalingFactor = _minScalingFactorForScalingType[_scalingType];
    maxScalingFactor = _maxScalingFactorForScalingType[_scalingType];

    [_scalingFactorSlider setMinValue: minScalingFactor];
    [_scalingFactorSlider setMaxValue: maxScalingFactor];

    if (_scalingFactor < minScalingFactor)
    {
        _scalingFactor = minScalingFactor;
    }
    else if (_scalingFactor > maxScalingFactor)
    {
        _scalingFactor = maxScalingFactor;
    }

    [self updateScalingFactorControlValues];

    return;

ERROR:
    return;
}

- (void) updateScalingFactorControlValues
{
    unsigned maxScalingFactor, minScalingFactor;
    NSSize oldScaledSize = _scaledSize;
    bool scalingFactorIsValid = YES;
    NSString *scaledSizeString;

    maxScalingFactor = _maxScalingFactorForScalingType[_scalingType];
    minScalingFactor = _minScalingFactorForScalingType[_scalingType];

    if (_scalingFactor > maxScalingFactor)
    {
        _scalingFactor = maxScalingFactor;
    }
    else if (_scalingFactor < kMinValidScalingFactor)
    {
        // allow positive integers less than kMinValidScalingFactor, because the user might be
        // in the process of typing a larger number
        if (_scalingFactor > 0)
        {
            scalingFactorIsValid = NO;
        }
        else
        {
            _scalingFactor = minScalingFactor;
        }
    }

    if ([_scalingFactorTextField intValue] != _scalingFactor)
    {
        [_scalingFactorTextField setIntValue: _scalingFactor];
    }

    if (scalingFactorIsValid)
    {
        if ([_scalingFactorSlider intValue] != _scalingFactor)
        {
            [_scalingFactorSlider setIntValue: _scalingFactor];
        }

        if (_scalingType == kPPScalingType_Downscale)
        {
            _scaledSize.width = roundf(_originalSize.width / (float) _scalingFactor);

            if (_scaledSize.width < 1)
            {
                _scaledSize.width = 1;
            }

            _scaledSize.height = roundf(_originalSize.height / (float) _scalingFactor);

            if (_scaledSize.height < 1)
            {
                _scaledSize.height = 1;
            }
        }
        else    // !(_scalingType == kPPScalingType_Downscale)
        {
            _scaledSize.width = _originalSize.width * _scalingFactor;
            _scaledSize.height = _originalSize.height * _scalingFactor;
        }

        if (!NSEqualSizes(_scaledSize, oldScaledSize))
        {
            [self updatePreviewImageForCurrentScaledSize];
        }

        scaledSizeString = [NSString stringWithFormat: @"%dx%d", (int) _scaledSize.width,
                                                        (int) _scaledSize.height];
    }
    else    // !scalingFactorIsValid
    {
        scaledSizeString = @"-";
    }

    [_newSizeTextField setStringValue: scaledSizeString];
}

- (void) updatePreviewImageForCurrentScaledSize
{
    NSScrollView *previewScrollView;
    NSSize contentViewSize;
    NSRect newPreviewScrollViewFrame;
    int viewMarginPadding;

    _shouldPreservePreviewNormalizedCenter = YES;

    previewScrollView = [_previewImageView enclosingScrollView];

    [_previewImageView setFrameSize: _scaledSize];
    [previewScrollView setFrame: _previewScrollViewInitialFrame];

    contentViewSize = [[previewScrollView contentView] frame].size;

    newPreviewScrollViewFrame = _previewScrollViewInitialFrame;

    if (_scaledSize.width < contentViewSize.width)
    {
        if (_scaledSize.height > contentViewSize.height)
        {
            viewMarginPadding = _previewScrollerWidth;
        }
        else
        {
            viewMarginPadding = kMarginPaddingForScrollerlessScrollView;
        }

        newPreviewScrollViewFrame.size.width = _scaledSize.width + viewMarginPadding;
    }

    if (_scaledSize.height < contentViewSize.height)
    {
        if (_scaledSize.width > contentViewSize.width)
        {
            viewMarginPadding = _previewScrollerWidth;
        }
        else
        {
            viewMarginPadding = kMarginPaddingForScrollerlessScrollView;
        }

        newPreviewScrollViewFrame.size.height = _scaledSize.height + viewMarginPadding;
    }

    newPreviewScrollViewFrame =
        PPGeometry_CenterRectInRect(newPreviewScrollViewFrame, _previewScrollViewInitialFrame);

    [previewScrollView setFrame: newPreviewScrollViewFrame];

    // Changing scrollview frame causes drawing artifacts (10.4) - fix by redrawing superview
    [[previewScrollView superview] setNeedsDisplayInRect: _previewScrollViewInitialFrame];

    // NSImageView seems to ignore (non)antialiasing settings when drawing downsized images
    // (on 10.5+?), so when downscaling, have to set the preview to a manually-resized image

    if (_scalingType == kPPScalingType_Downscale)
    {
        // use a local autorelease pool to make sure old images & bitmaps get dealloc'd during
        // slider tracking
        NSAutoreleasePool *autoreleasePool = [[NSAutoreleasePool alloc] init];

        [_previewImageView setImage:
                            [NSImage ppImageWithBitmap:
                                        [_canvasBitmap ppBitmapResizedToSize: _scaledSize
                                                        shouldScale: YES]]];

        [autoreleasePool release];
    }
    else    // !(_scalingType == kPPScalingType_Downscale)
    {
        // upscaling - let NSImageView handle the resizing
        [_previewImageView setImage: _canvasImage];
    }

    [self scrollPreviewToNormalizedCenter];

    _shouldPreservePreviewNormalizedCenter = NO;
}

- (void) scrollPreviewToNormalizedCenter
{
    NSSize clipViewSize = [[[_previewImageView enclosingScrollView] contentView] bounds].size;
    NSPoint centerPoint = NSMakePoint(_previewViewNormalizedCenter.x * _scaledSize.width
                                        - clipViewSize.width / 2.0f,
                                    _previewViewNormalizedCenter.y * _scaledSize.height
                                        - clipViewSize.height / 2.0f);

    [_previewImageView scrollPoint: centerPoint];
}

@end
