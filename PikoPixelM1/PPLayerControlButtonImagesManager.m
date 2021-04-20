/*
    PPLayerControlButtonImagesManager.m

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

#import "PPLayerControlButtonImagesManager.h"

#import "PPLayerControlButtonImagesManager_Notifications.h"
#import "PPDocument.h"
#import "NSBitmapImageRep_PPUtilities.h"
#import "PPCompositeThumbnail.h"
#import "PPGeometry.h"
#import "PPBackgroundPattern.h"
#import "PPThumbnailUtilities.h"


#define kLayerControlButtonImageViewsNibName            @"LayerControlButtonImageViews"


@interface PPLayerControlButtonImagesManager (PrivateMethods)

- (void) addAsObserverForPPDocumentNotifications;
- (void) removeAsObserverForPPDocumentNotifications;
- (void) handlePPDocumentNotification_UpdatedMergedVisibleThumbnailImage:
                                                            (NSNotification *) notification;
- (void) handlePPDocumentNotification_UpdatedDrawingLayerThumbnailImage:
                                                                (NSNotification *) notification;
- (void) handlePPDocumentNotification_UpdatedBackgroundSettings:
                                                            (NSNotification *) notification;
- (void) handlePPDocumentNotification_ReloadedDocument: (NSNotification *) notification;

- (void) setupThumbnailDrawMembers;
- (void) invalidateThumbnailsAndPostChangeNotifications;
- (void) setupThumbnailBackgroundBitmap;
- (void) updateEnabledLayersCompositeThumbnails;
- (void) updateDrawLayerCompositeThumbnails;
- (void) updateThumbnailBitmap: (NSBitmapImageRep *) thumbnailBitmap
            withSourceImage: (NSImage *) sourceImage;

@end

@implementation PPLayerControlButtonImagesManager

+ sharedManager
{
    static PPLayerControlButtonImagesManager *sharedManager;

    if (!sharedManager)
    {
        sharedManager = [[self alloc] init];
    }

    return sharedManager;
}

- init
{
    self = [super init];

    if (!self)
        goto ERROR;
    //check
    //if (![NSBundle loadNibNamed: kLayerControlButtonImageViewsNibName owner: self])
    if(![[NSBundle mainBundle] loadNibNamed:kLayerControlButtonImageViewsNibName owner:self topLevelObjects:nil])
    {
        goto ERROR;
    }

    _thumbnailFramesize = [_displayModeDrawLayerThumbnailView frame].size;

    _thumbnailBackgroundBitmap =
                    [[NSBitmapImageRep ppImageBitmapOfSize: _thumbnailFramesize] retain];

    _drawLayerThumbnailBitmap =
                    [[NSBitmapImageRep ppImageBitmapOfSize: _thumbnailFramesize] retain];

    _enabledLayersThumbnailBitmap =
                    [[NSBitmapImageRep ppImageBitmapOfSize: _thumbnailFramesize] retain];

    if (!_thumbnailBackgroundBitmap
        || !_drawLayerThumbnailBitmap
        || !_enabledLayersThumbnailBitmap)
    {
        goto ERROR;
    }

    _displayModeDrawLayerCompositeThumbnail =
        [[PPCompositeThumbnail compositeThumbnailFromView: _displayModeDrawLayerView
                                    thumbnailOrigin:
                                            [_displayModeDrawLayerThumbnailView frame].origin]
                                retain];

    _displayModeEnabledLayersCompositeThumbnail =
        [[PPCompositeThumbnail compositeThumbnailFromView: _displayModeEnabledLayersView
                                    thumbnailOrigin:
                                        [_displayModeEnabledLayersThumbnailView frame].origin]
                                retain];

    _operationTargetDrawLayerCompositeThumbnail =
        [[PPCompositeThumbnail compositeThumbnailFromView: _operationTargetDrawLayerView
                                    thumbnailOrigin:
                                        [_operationTargetDrawLayerThumbnailView frame].origin]
                                retain];

    _operationTargetEnabledLayersCompositeThumbnail =
        [[PPCompositeThumbnail compositeThumbnailFromView: _operationTargetEnabledLayersView
                                thumbnailOrigin:
                                    [_operationTargetEnabledLayersThumbnailView frame].origin]
                            retain];

    if (!_displayModeDrawLayerCompositeThumbnail
        || !_displayModeEnabledLayersCompositeThumbnail
        || !_operationTargetDrawLayerCompositeThumbnail
        || !_operationTargetEnabledLayersCompositeThumbnail)
    {
        goto ERROR;
    }

    return self;

ERROR:
    [self release];

    return nil;
}

- (void) dealloc
{
    [self setPPDocument: nil];

    [_thumbnailBackgroundBitmap release];
    [_drawLayerThumbnailBitmap release];
    [_enabledLayersThumbnailBitmap release];

    [_displayModeDrawLayerCompositeThumbnail release];
    [_displayModeEnabledLayersCompositeThumbnail release];
    [_operationTargetDrawLayerCompositeThumbnail release];
    [_operationTargetEnabledLayersCompositeThumbnail release];

    [super dealloc];
}

- (void) setPPDocument: (PPDocument *) ppDocument
{
    if (_ppDocument == ppDocument)
    {
        return;
    }

    if (_ppDocument)
    {
        [self removeAsObserverForPPDocumentNotifications];
    }

    [_ppDocument release];
    _ppDocument = [ppDocument retain];

    if (_ppDocument)
    {
        [self setupThumbnailDrawMembers];

        [self invalidateThumbnailsAndPostChangeNotifications];

        [self addAsObserverForPPDocumentNotifications];
    }
}

- (NSImage *) buttonImageForDisplayMode: (PPLayerDisplayMode) displayMode
{
    if (_thumbnailBackgroundBitmapIsDirty)
    {
        [self setupThumbnailBackgroundBitmap];
    }

    if (displayMode == kPPLayerDisplayMode_DrawingLayerOnly)
    {
        if (_drawLayerThumbnailsAreDirty)
        {
            [self updateDrawLayerCompositeThumbnails];
        }

        return [_displayModeDrawLayerCompositeThumbnail compositeImage];
    }
    else
    {
        if (_enabledLayersThumbnailsAreDirty)
        {
            [self updateEnabledLayersCompositeThumbnails];
        }

        return [_displayModeEnabledLayersCompositeThumbnail compositeImage];
    }
}

- (NSImage *) buttonImageForOperationTarget: (PPLayerOperationTarget) operationTarget
{
    if (_thumbnailBackgroundBitmapIsDirty)
    {
        [self setupThumbnailBackgroundBitmap];
    }

    if (operationTarget == kPPLayerOperationTarget_DrawingLayerOnly)
    {
        if (_drawLayerThumbnailsAreDirty)
        {
            [self updateDrawLayerCompositeThumbnails];
        }

        return [_operationTargetDrawLayerCompositeThumbnail compositeImage];
    }
    else
    {
        if (_enabledLayersThumbnailsAreDirty)
        {
            [self updateEnabledLayersCompositeThumbnails];
        }

        return [_operationTargetEnabledLayersCompositeThumbnail compositeImage];
    }
}

#pragma mark PPDocument notifications

- (void) addAsObserverForPPDocumentNotifications
{
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];

    if (!_ppDocument)
        return;

    [notificationCenter addObserver: self
                        selector:
                            @selector(
                            handlePPDocumentNotification_UpdatedMergedVisibleThumbnailImage:)
                        name: PPDocumentNotification_UpdatedMergedVisibleThumbnailImage
                        object: _ppDocument];

    [notificationCenter addObserver: self
                        selector:
                            @selector(
                                handlePPDocumentNotification_UpdatedDrawingLayerThumbnailImage:)
                        name: PPDocumentNotification_UpdatedDrawingLayerThumbnailImage
                        object: _ppDocument];

    [notificationCenter addObserver: self
                        selector:
                            @selector(handlePPDocumentNotification_UpdatedBackgroundSettings:)
                        name: PPDocumentNotification_UpdatedBackgroundSettings
                        object: _ppDocument];


    [notificationCenter addObserver: self
                        selector: @selector(handlePPDocumentNotification_ReloadedDocument:)
                        name: PPDocumentNotification_ReloadedDocument
                        object: _ppDocument];

}

- (void) removeAsObserverForPPDocumentNotifications
{
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];

    [notificationCenter removeObserver: self
                        name: PPDocumentNotification_UpdatedMergedVisibleThumbnailImage
                        object: _ppDocument];

    [notificationCenter removeObserver: self
                        name: PPDocumentNotification_UpdatedDrawingLayerThumbnailImage
                        object: _ppDocument];

    [notificationCenter removeObserver: self
                        name: PPDocumentNotification_UpdatedBackgroundSettings
                        object: _ppDocument];

    [notificationCenter removeObserver: self
                        name: PPDocumentNotification_ReloadedDocument
                        object: _ppDocument];
}

- (void) handlePPDocumentNotification_UpdatedMergedVisibleThumbnailImage:
                                                            (NSNotification *) notification
{
    _enabledLayersThumbnailsAreDirty = YES;

    [self postNotification_ChangedEnabledLayersImages];
}

- (void) handlePPDocumentNotification_UpdatedDrawingLayerThumbnailImage:
                                                                (NSNotification *) notification
{
    _drawLayerThumbnailsAreDirty = YES;

    [self postNotification_ChangedDrawLayerImages];
}

- (void) handlePPDocumentNotification_UpdatedBackgroundSettings:
                                                            (NSNotification *) notification
{
    [self invalidateThumbnailsAndPostChangeNotifications];
}

- (void) handlePPDocumentNotification_ReloadedDocument: (NSNotification *) notification
{
    [self setupThumbnailDrawMembers];

    [self invalidateThumbnailsAndPostChangeNotifications];
}

#pragma mark Private methods

- (void) setupThumbnailDrawMembers
{
    _thumbnailDrawSourceBounds = PPGeometry_OriginRectOfSize([_ppDocument canvasSize]);

    _thumbnailDrawDestinationBounds =
        PPGeometry_ScaledBoundsForFrameOfSizeToFitFrameOfSize(_thumbnailDrawSourceBounds.size,
                                                                _thumbnailFramesize);

    _thumbnailInterpolation =
        PPThumbUtils_ImageInterpolationForSourceRectToDestinationRect(
                                                                _thumbnailDrawSourceBounds,
                                                                _thumbnailDrawDestinationBounds);
}

- (void) invalidateThumbnailsAndPostChangeNotifications
{
    _thumbnailBackgroundBitmapIsDirty = YES;
    _enabledLayersThumbnailsAreDirty = YES;
    _drawLayerThumbnailsAreDirty = YES;

    [self postNotification_ChangedEnabledLayersImages];
    [self postNotification_ChangedDrawLayerImages];
}

- (void) setupThumbnailBackgroundBitmap
{
    PPBackgroundPattern *documentBackgroundPattern, *thumbnailBackgroundPattern;
    float patternScalingFactor;
    NSColor *thumbnailBackgroundPatternColor;

    if (!_ppDocument || NSIsEmptyRect(_thumbnailDrawSourceBounds))
    {
        goto ERROR;
    }

    documentBackgroundPattern = [_ppDocument backgroundPattern];

    patternScalingFactor = kScalingFactorForThumbnailBackgroundPatternSize
                                * _thumbnailDrawDestinationBounds.size.width
                                / _thumbnailDrawSourceBounds.size.width;

    if (patternScalingFactor > 1.0f)
    {
        patternScalingFactor = 1.0f;
    }

    thumbnailBackgroundPattern =
            [documentBackgroundPattern backgroundPatternScaledByFactor: patternScalingFactor];

    thumbnailBackgroundPatternColor = [thumbnailBackgroundPattern patternFillColor];

    if (!thumbnailBackgroundPatternColor)
        goto ERROR;

    [_thumbnailBackgroundBitmap ppClearBitmap];

    [_thumbnailBackgroundBitmap ppSetAsCurrentGraphicsContext];

    [thumbnailBackgroundPatternColor set];

    NSRectFill(_thumbnailDrawDestinationBounds);

    [_thumbnailBackgroundBitmap ppRestoreGraphicsContext];

    _thumbnailBackgroundBitmapIsDirty = NO;

    return;

ERROR:
    return;
}

- (void) updateEnabledLayersCompositeThumbnails
{
    [self updateThumbnailBitmap: _enabledLayersThumbnailBitmap
            withSourceImage: [_ppDocument mergedVisibleLayersThumbnailImage]];

    [_displayModeEnabledLayersCompositeThumbnail
                                            setThumbnailBitmap: _enabledLayersThumbnailBitmap];

    [_operationTargetEnabledLayersCompositeThumbnail
                                            setThumbnailBitmap: _enabledLayersThumbnailBitmap];

    _enabledLayersThumbnailsAreDirty = NO;
}

- (void) updateDrawLayerCompositeThumbnails
{
    [self updateThumbnailBitmap: _drawLayerThumbnailBitmap
            withSourceImage: [_ppDocument drawingLayerThumbnailImage]];

    [_displayModeDrawLayerCompositeThumbnail setThumbnailBitmap: _drawLayerThumbnailBitmap];

    [_operationTargetDrawLayerCompositeThumbnail
                                            setThumbnailBitmap: _drawLayerThumbnailBitmap];

    _drawLayerThumbnailsAreDirty = NO;
}

- (void) updateThumbnailBitmap: (NSBitmapImageRep *) thumbnailBitmap
            withSourceImage: (NSImage *) sourceImage
{
    [thumbnailBitmap ppCopyFromBitmap: _thumbnailBackgroundBitmap toPoint: NSZeroPoint];

    [thumbnailBitmap ppSetAsCurrentGraphicsContext];

    [[NSGraphicsContext currentContext] setImageInterpolation: _thumbnailInterpolation];

    [sourceImage drawInRect: _thumbnailDrawDestinationBounds
                fromRect: _thumbnailDrawSourceBounds
                operation: NSCompositeSourceOver
                fraction: 1.0];

    [thumbnailBitmap ppRestoreGraphicsContext];
}

@end
