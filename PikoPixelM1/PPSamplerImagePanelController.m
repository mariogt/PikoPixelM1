/*
    PPSamplerImagePanelController.m

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

#import "PPSamplerImagePanelController.h"

#import "PPUIColors_Panels.h"
#import "PPDocument.h"
#import "PPMiniColorWell.h"
#import "PPSamplerImageView.h"
#import "NSObject_PPUtilities.h"
#import "PPDocumentWindowController.h"
#import "PPDocumentSamplerImage.h"
#import "PPGeometry.h"
#import "PPPanelDefaultFramePinnings.h"


#define kSamplerImagePanelNibName   @"SamplerImagePanel"


#define kMinAllowedSamplerViewDimension             128
#define kMaxAllowedSamplerViewDimension             600
#define kDefaultImageSizeDimension                  200


@interface PPSamplerImagePanelController (PrivateMethods)

- (void) handlePPDocumentNotification_ChangedFillColor: (NSNotification *) notification;
- (void) handlePPDocumentNotification_UpdatedSamplerImages: (NSNotification *) notification;
- (void) handlePPDocumentNotification_SwitchedActiveSamplerImage:
                                                            (NSNotification *) notification;

- (void) updateSamplerPanelStateForCurrentDocument;

- (void) setupWithActiveSamplerImageFromCurrentDocument;

- (void) updateArrowButtonsVisibility;

- (void) handleResizingBegin;
- (void) handleResizingEnd;

@end

@implementation PPSamplerImagePanelController

#pragma mark Actions

- (IBAction) previousSamplerImageButtonPressed: (id) sender
{
    [_ppDocument activatePreviousSamplerImageForPanelType: kPPSamplerImagePanelType_Panel];
}

- (IBAction) nextSamplerImageButtonPressed: (id) sender
{
    [_ppDocument activateNextSamplerImageForPanelType: kPPSamplerImagePanelType_Panel];
}

#pragma mark NSWindowController overrides

- (void) windowDidLoad
{
    NSWindow *window;
    NSRect windowFrame, imageViewFrame;

    window = [self window];
    windowFrame = [window frame];
    imageViewFrame = [_samplerImageView frame];

    _sizeDifferenceBetweenPanelAndSamplerImageView =
                            PPGeometry_SizeDifference(windowFrame.size, imageViewFrame.size);

    // minimum size handled manually - make sure window defaults don't interfere
    [window setContentMinSize: NSZeroSize];

    [_miniColorWell setOutlineColor: kUIColor_SamplerImagePanel_ColorWellOutline];

    [_samplerImageView setSamplerImagePanelType: kPPSamplerImagePanelType_Panel
                        minViewDimension: kMinAllowedSamplerViewDimension
                        maxViewDimension: kMaxAllowedSamplerViewDimension
                        defaultImageDimension: kDefaultImageSizeDimension
                        delegate: self];

    // setupWithActiveSamplerImageFromCurrentDocument will resize the window frame so it has
    // the correct dimensions when the frame is pinned (in [super windowDidLoad])
    [self setupWithActiveSamplerImageFromCurrentDocument];

    // [super windowDidLoad] may show the panel, so call as late as possible
    [super windowDidLoad];
}

#pragma mark PPPanelController overrides

+ (NSString *) panelNibName
{
    return kSamplerImagePanelNibName;
}

- (void) setPanelEnabled: (bool) enablePanel
{
    if (enablePanel
        && ![_ppDocument hasActiveSamplerImageForPanelType: kPPSamplerImagePanelType_Panel])
    {
        enablePanel = NO;
    }

    [_ppDocument setShouldEnableSamplerImagePanel: enablePanel];

    [self updateSamplerPanelStateForCurrentDocument];
}

- (void) addAsObserverForPPDocumentNotifications
{
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];

    if (!_ppDocument)
        return;

    [notificationCenter addObserver: self
                        selector: @selector(handlePPDocumentNotification_ChangedFillColor:)
                        name: PPDocumentNotification_ChangedFillColor
                        object: _ppDocument];

    [notificationCenter addObserver: self
                        selector: @selector(handlePPDocumentNotification_UpdatedSamplerImages:)
                        name: PPDocumentNotification_UpdatedSamplerImages
                        object: _ppDocument];

    [notificationCenter addObserver: self
                        selector:
                            @selector(handlePPDocumentNotification_SwitchedActiveSamplerImage:)
                        name: PPDocumentNotification_SwitchedActiveSamplerImage
                        object: _ppDocument];
}

- (void) removeAsObserverForPPDocumentNotifications
{
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];

    [notificationCenter removeObserver: self
                        name: PPDocumentNotification_ChangedFillColor
                        object: _ppDocument];

    [notificationCenter removeObserver: self
                        name: PPDocumentNotification_UpdatedSamplerImages
                        object: _ppDocument];

    [notificationCenter removeObserver: self
                        name: PPDocumentNotification_SwitchedActiveSamplerImage
                        object: _ppDocument];
}

- (PPFramePinningType) pinningTypeForDefaultWindowFrame
{
    return kPPPanelDefaultFramePinning_SamplerImage;
}

- (void) setupPanelForCurrentPPDocument
{
    // [super setupPanelForCurrentPPDocument] may show the panel, so call as late as possible
    [super setupPanelForCurrentPPDocument];

    [self updateSamplerPanelStateForCurrentDocument];
}

#pragma mark NSWindow delegate methods

- (NSSize) windowWillResize: (NSWindow *) sender toSize: (NSSize) proposedFrameSize
{
    NSSize currentFrameSize, proposedSamplerImageViewSize, newSamplerImageViewSize;

    currentFrameSize = [[self window] frame].size;

    if (!_panelIsResizing)
    {
        [self handleResizingBegin];
        [self ppPerformSelectorAtomicallyFromNewStackFrame: @selector(handleResizingEnd)];
    }

    if (NSEqualSizes(currentFrameSize, proposedFrameSize))
    {
        goto ERROR;
    }

    if (currentFrameSize.width != proposedFrameSize.width)
    {
        _panelResizableDirectionsMask |= kPPResizableDirectionsMask_Horizontal;
    }

    if (currentFrameSize.height != proposedFrameSize.height)
    {
        _panelResizableDirectionsMask |= kPPResizableDirectionsMask_Vertical;
    }

    proposedSamplerImageViewSize =
        PPGeometry_SizeDifference(proposedFrameSize,
                                    _sizeDifferenceBetweenPanelAndSamplerImageView);

    newSamplerImageViewSize =
        [_samplerImageView viewSizeForResizingToProposedViewSize: proposedSamplerImageViewSize
                            resizableDirectionsMask: _panelResizableDirectionsMask];

    if (PPGeometry_IsZeroSize(newSamplerImageViewSize))
    {
        goto ERROR;
    }

    return PPGeometry_SizeSum(newSamplerImageViewSize,
                                _sizeDifferenceBetweenPanelAndSamplerImageView);

ERROR:
    return currentFrameSize;
}

#pragma mark PPSamplerImageView delegate methods

- (void) ppSamplerImageView: (PPSamplerImageView *) samplerImageView
            didBrowseColor: (NSColor *) color
{
    if (samplerImageView != _samplerImageView)
    {
        return;
    }

    if (!_initialDocumentFillColor)
    {
        _initialDocumentFillColor = [[_ppDocument fillColor] retain];
    }

    _samplerImageViewIsBrowsingOutsideImage = (color) ? NO : YES;

    if (!color)
    {
        color = _initialDocumentFillColor;
    }

    [_ppDocument setFillColorWithoutUndoRegistration: color];
}

- (void) ppSamplerImageView: (PPSamplerImageView *) samplerImageView
            didSelectColor: (NSColor *) color
{
    if (samplerImageView != _samplerImageView)
    {
        return;
    }

    _samplerImageViewIsBrowsingOutsideImage = NO;

    [_ppDocument setFillColorWithoutUndoRegistration: _initialDocumentFillColor];

    if (color)
    {
        [_ppDocument setFillColor: color];
    }

    [_initialDocumentFillColor release];
    _initialDocumentFillColor = nil;
}

- (void) ppSamplerImageViewDidCancelSelection: (PPSamplerImageView *) samplerImageView
{
    if (samplerImageView != _samplerImageView)
    {
        return;
    }

    _samplerImageViewIsBrowsingOutsideImage = NO;

    [_ppDocument setFillColorWithoutUndoRegistration: _initialDocumentFillColor];

    [_initialDocumentFillColor release];
    _initialDocumentFillColor = nil;
}

#pragma mark PPDocument notifications

- (void) handlePPDocumentNotification_ChangedFillColor: (NSNotification *) notification
{
    NSColor *colorWellColor = nil;

    if (!_samplerImageViewIsBrowsingOutsideImage)
    {
        colorWellColor = [_ppDocument fillColor];
    }

    [_miniColorWell setColor: colorWellColor];
}

- (void) handlePPDocumentNotification_UpdatedSamplerImages: (NSNotification *) notification
{
    [self updateSamplerPanelStateForCurrentDocument];
}

- (void) handlePPDocumentNotification_SwitchedActiveSamplerImage:
                                                            (NSNotification *) notification
{
    NSNumber *samplerImagePanelTypeNumber;

    samplerImagePanelTypeNumber =
        [[notification userInfo]
                        objectForKey: PPDocumentNotification_UserInfoKey_SamplerImagePanelType];

    if (samplerImagePanelTypeNumber
        && ([samplerImagePanelTypeNumber intValue] != kPPSamplerImagePanelType_Panel))
    {
        return;
    }

    [self setupWithActiveSamplerImageFromCurrentDocument];
}

#pragma mark Private methods

- (void) updateSamplerPanelStateForCurrentDocument
{
    bool shouldDisplayPanel =
            ([_ppDocument shouldEnableSamplerImagePanel]
                && [_ppDocument hasActiveSamplerImageForPanelType:
                                                            kPPSamplerImagePanelType_Panel]);

    if (shouldDisplayPanel)
    {
        // make sure panel is loaded before accessing IBOutlets
        if (!_panelDidLoad)
        {
            [self window];
        }

        _samplerImageViewIsBrowsingOutsideImage = NO;
        [_miniColorWell setColor: [_ppDocument fillColor]];

        [self updateArrowButtonsVisibility];

        [self setupWithActiveSamplerImageFromCurrentDocument];
    }

    [super setPanelEnabled: shouldDisplayPanel];

    if (!_panelDidLoad)
        return;

    [_samplerImageView setupMouseTracking];

    if (!shouldDisplayPanel)
    {
        if ([_samplerImageView mouseIsSamplingImage])
        {
            [_samplerImageView forceStopSamplingImage];
        }

        [_samplerImageView setSamplerImage: nil];
    }
}

- (void) setupWithActiveSamplerImageFromCurrentDocument
{
    PPDocumentSamplerImage *samplerImage;
    NSSize samplerImageViewSize;
    NSRect newWindowFrame;

    samplerImage = [_ppDocument activeSamplerImageForPanelType: kPPSamplerImagePanelType_Panel];

    [_samplerImageView setSamplerImage: samplerImage];

    if (!samplerImage)
        return;

    samplerImageViewSize = [_samplerImageView viewSizeForScaledCurrentSamplerImage];

    newWindowFrame = [[self window] frame];
    newWindowFrame.size =
        PPGeometry_SizeSum(samplerImageViewSize, _sizeDifferenceBetweenPanelAndSamplerImageView);

    [[self window] setFrame: newWindowFrame display: NO];
}

- (void) updateArrowButtonsVisibility
{
    bool shouldHideButtons = ([_ppDocument numSamplerImages] < 2) ? YES : NO;

    [_previousSamplerImageButton setHidden: shouldHideButtons];
    [_nextSamplerImageButton setHidden: shouldHideButtons];
}

- (void) handleResizingBegin
{
    if (_panelIsResizing)
        return;

    _panelIsResizing = YES;

    [_samplerImageView disableMouseTracking: YES];

    _panelResizableDirectionsMask = kPPResizableDirectionsMask_None;
}

- (void) handleResizingEnd
{
    if (!_panelIsResizing)
        return;

    _panelIsResizing = NO;

    [_samplerImageView disableMouseTracking: NO];
}

@end
