/*
    PPPreviewPanelController.m

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

#import "PPPreviewPanelController.h"

#import "PPDocument.h"
#import "PPPreviewView.h"
#import "PPDocumentWindowController.h"
#import "PPPanelDefaultFramePinnings.h"
#import "PPGeometry.h"


#define kPreviewPanelNibName                            @"PreviewPanel"

#define kMinScaleForContinousPreviewImageUpdateMode     (0.5f)


typedef enum
{
    kPPPreviewImageUpdateMode_Continuous,
    kPPPreviewImageUpdateMode_ThumbnailUpdatesOnly

} PPPreviewImageUpdateMode;


@interface PPPreviewPanelController (PrivateMethods)

- (void) handlePPDocumentNotification_UpdatedMergedVisibleArea:
                                                            (NSNotification *) notification;
- (void) handlePPDocumentNotification_UpdatedDrawingLayerArea: (NSNotification *) notification;

- (void) handlePPDocumentNotification_UpdatedMergedVisibleThumbnailImage:
                                                                (NSNotification *) notification;

- (void) handlePPDocumentNotification_UpdatedDrawingLayerThumbnailImage:
                                                                (NSNotification *) notification;

- (void) setupPreviewImage;

- (void) clearPreviewImage;

- (void) setupPreviewImageUpdateModeForScale: (float) scale;

- (void) forceWindowTitleRedisplay;

@end

@implementation PPPreviewPanelController

#pragma mark NSWindowController overrides

- (void) windowDidLoad
{
    NSWindow *window = [self window];

    _sizeDifferenceBetweenPanelAndPreviewView =
                    PPGeometry_SizeDifference([window frame].size, [_previewView frame].size);

    // PPreviewView handles minimum size, make sure window defaults don't interfere
    [window setContentMinSize: NSZeroSize];

    [_previewView setDelegate: self];

    // [super windowDidLoad] may show the panel, so call as late as possible
    [super windowDidLoad];
}

#pragma mark PPPanelController overrides

+ (NSString *) panelNibName
{
    return kPreviewPanelNibName;
}

- (void) addAsObserverForPPDocumentNotifications
{
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];

    if (!_ppDocument)
        return;

    [notificationCenter
                addObserver: self
                selector: @selector(handlePPDocumentNotification_UpdatedMergedVisibleArea:)
                name: PPDocumentNotification_UpdatedMergedVisibleArea
                object: _ppDocument];

    [notificationCenter
                addObserver: self
                selector:
                    @selector(handlePPDocumentNotification_UpdatedMergedVisibleThumbnailImage:)
                name: PPDocumentNotification_UpdatedMergedVisibleThumbnailImage
                object: _ppDocument];

    [notificationCenter
                addObserver: self
                selector: @selector(handlePPDocumentNotification_ReloadedDocument:)
                name: PPDocumentNotification_ReloadedDocument
                object: _ppDocument];
}

- (void) removeAsObserverForPPDocumentNotifications
{
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];

    [notificationCenter removeObserver: self
                        name: PPDocumentNotification_UpdatedMergedVisibleArea
                        object: _ppDocument];

    [notificationCenter removeObserver: self
                        name: PPDocumentNotification_UpdatedMergedVisibleThumbnailImage
                        object: _ppDocument];

    [notificationCenter removeObserver: self
                        name: PPDocumentNotification_ReloadedDocument
                        object: _ppDocument];
}

- (bool) defaultPanelEnabledState
{
    return YES;
}

- (PPFramePinningType) pinningTypeForDefaultWindowFrame
{
    return kPPPanelDefaultFramePinning_Preview;
}

- (void) setupPanelForCurrentPPDocument
{
    [self setupPreviewImage];

    // [super setupPanelForCurrentPPDocument] may show the panel, so call as late as possible
    [super setupPanelForCurrentPPDocument];
}

- (void) setupPanelBeforeMakingVisible
{
    [super setupPanelBeforeMakingVisible];

    if (_needToUpdatePreviewImage)
    {
        [_previewView handleUpdateToImage];
        _needToUpdatePreviewImage = NO;
    }
}

#pragma mark NSWindow delegate methods

- (NSSize) windowWillResize: (NSWindow *) sender toSize: (NSSize) proposedFrameSize
{
    NSSize proposedPreviewViewSize, newPreviewViewSize;

    proposedPreviewViewSize =
        PPGeometry_SizeDifference(proposedFrameSize, _sizeDifferenceBetweenPanelAndPreviewView);

    newPreviewViewSize = [_previewView prepareForNewFrameSize: proposedPreviewViewSize];

    return PPGeometry_SizeSum(newPreviewViewSize, _sizeDifferenceBetweenPanelAndPreviewView);
}

#pragma mark PPPreviewView delegate methods

- (void) ppPreviewView: (PPPreviewView *) previewView didChangeScale: (float) scale
{
    int percentScale = roundf(100.0f * scale);

    [self setupPreviewImageUpdateModeForScale: percentScale / 100.0f];

    [[self window] setTitle: [NSString stringWithFormat: @"%d%% Preview", percentScale]];

    [self forceWindowTitleRedisplay];
}

#pragma mark PPDocument notifications

- (void) handlePPDocumentNotification_UpdatedMergedVisibleArea: (NSNotification *) notification
{
    if (_previewImageUpdateMode == kPPPreviewImageUpdateMode_ThumbnailUpdatesOnly)
    {
        return;
    }

    if ([self panelIsVisible])
    {
        NSValue *updateAreaRectValue =
                    [[notification userInfo]
                                    objectForKey:
                                            PPDocumentNotification_UserInfoKey_UpdateAreaRect];

        if (updateAreaRectValue)
        {
            [_previewView handleUpdateToImageInRect: [updateAreaRectValue rectValue]];
        }
    }
    else
    {
        _needToUpdatePreviewImage = YES;
    }
}

- (void) handlePPDocumentNotification_UpdatedMergedVisibleThumbnailImage:
                                                                (NSNotification *) notification
{
    if (_previewImageUpdateMode != kPPPreviewImageUpdateMode_ThumbnailUpdatesOnly)
    {
        return;
    }

    if ([self panelIsVisible])
    {
        [_previewView handleUpdateToImage];
    }
    else
    {
        _needToUpdatePreviewImage = YES;
    }
}

- (void) handlePPDocumentNotification_ReloadedDocument: (NSNotification *) notification
{
    // the document's thumbnail image may remain the same object, and -[PPPreviewView setImage:]
    // won't redraw the view unless it's passed a different object from its current image, so
    // clear the preview view's image first to force it to redraw
    [self clearPreviewImage];

    [self setupPreviewImage];
}

#pragma mark Private methods

- (void) setupPreviewImage
{
    [_previewView setImage: [_ppDocument mergedVisibleLayersThumbnailImage]];

    _needToUpdatePreviewImage = NO;
}

- (void) clearPreviewImage
{
    [_previewView setImage: nil];
}

- (void) setupPreviewImageUpdateModeForScale: (float) scale
{
    _previewImageUpdateMode =
        (scale >= kMinScaleForContinousPreviewImageUpdateMode) ?
            kPPPreviewImageUpdateMode_Continuous :
            kPPPreviewImageUpdateMode_ThumbnailUpdatesOnly;
}

- (void) forceWindowTitleRedisplay
{
    NSView *contentView, *windowView;
    NSRect contentViewFrame, windowViewBounds, titleFrame;

    contentView = [[self window] contentView];
    windowView = [contentView superview];

    contentViewFrame = [contentView frame];
    windowViewBounds = [windowView bounds];

    titleFrame = windowViewBounds;
    titleFrame.size.height = windowViewBounds.size.height - contentViewFrame.size.height;
    titleFrame.origin.y = windowViewBounds.size.height - titleFrame.size.height;

    [windowView displayRect: titleFrame];
}

@end
