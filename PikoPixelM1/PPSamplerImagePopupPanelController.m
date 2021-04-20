/*
    PPSamplerImagePopupPanelController.m

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

#import "PPSamplerImagePopupPanelController.h"

#import "PPUIColors_Panels.h"
#import "PPDocument.h"
#import "PPMiniColorWell.h"
#import "PPSamplerImageView.h"
#import "PPResizeControl.h"
#import "PPPopupPanelsController.h"
#import "PPPopupPanelActionKeys.h"
#import "PPGeometry.h"


#define kSamplerImagePopupPanelNibName          @"SamplerImagePopupPanel"


#define kMinAllowedSamplerViewDimension             80
#define kMaxAllowedSamplerViewDimension             700
#define kDefaultImageSizeDimension                  120


@interface PPSamplerImagePopupPanelController (PrivateMethods)

- (void) handlePPDocumentNotification_ChangedFillColor: (NSNotification *) notification;

- (void) setupWithActiveSamplerImageFromCurrentDocument;

@end

@implementation PPSamplerImagePopupPanelController

#pragma mark Actions

- (IBAction) previousSamplerImageButtonPressed: (id) sender
{
    [[PPPopupPanelsController sharedController] positionNextActivePopupAtCurrentPopupOrigin];

    [_ppDocument activatePreviousSamplerImageForPanelType: kPPSamplerImagePanelType_PopupPanel];
}

- (IBAction) nextSamplerImageButtonPressed: (id) sender
{
    [[PPPopupPanelsController sharedController] positionNextActivePopupAtCurrentPopupOrigin];

    [_ppDocument activateNextSamplerImageForPanelType: kPPSamplerImagePanelType_PopupPanel];
}

#pragma mark NSWindowController overrides

- (void) windowDidLoad
{
    NSRect windowFrame, imageViewFrame;

    [super windowDidLoad];

    windowFrame = [[self window] frame];
    imageViewFrame = [_samplerImageView frame];

    _sizeDifferenceBetweenPanelAndSamplerImageView =
                            PPGeometry_SizeDifference(windowFrame.size, imageViewFrame.size);

    [_miniColorWell setOutlineColor: kUIColor_SamplerImagePopupPanel_ColorWellOutline];

    [_samplerImageView setSamplerImagePanelType: kPPSamplerImagePanelType_PopupPanel
                        minViewDimension: kMinAllowedSamplerViewDimension
                        maxViewDimension: kMaxAllowedSamplerViewDimension
                        defaultImageDimension: kDefaultImageSizeDimension
                        delegate: self];

    [_resizeControl setDelegate: self];
}

#pragma mark PPPopupPanelController overrides

+ (NSString *) panelNibName
{
    return kSamplerImagePopupPanelNibName;
}

- (void) addAsObserverForPPDocumentNotifications
{
    if (!_ppDocument)
        return;

    [[NSNotificationCenter defaultCenter]
                                addObserver: self
                                selector:
                                    @selector(handlePPDocumentNotification_ChangedFillColor:)
                                name: PPDocumentNotification_ChangedFillColor
                                object: _ppDocument];
}

- (void) removeAsObserverForPPDocumentNotifications
{
    [[NSNotificationCenter defaultCenter] removeObserver: self
                                            name: PPDocumentNotification_ChangedFillColor
                                            object: _ppDocument];
}

- (void) setupPanelBeforeMakingVisible
{
    // call setupWithActiveSamplerImageFromCurrentDocument before calling
    // [super setupPanelBeforeMakingVisible], because
    // setupWithActiveSamplerImageFromCurrentDocument may resize the panel, and
    // [super setupPanelBeforeMakingVisible] repositions the panel based on its size (centering
    // at the current mouse position)

    [self setupWithActiveSamplerImageFromCurrentDocument];

    [super setupPanelBeforeMakingVisible];

    _samplerImageViewIsBrowsingOutsideImage = NO;
    [_miniColorWell setColor: [_ppDocument fillColor]];
}

- (void) setupPanelAfterVisibilityChange
{
    [super setupPanelAfterVisibilityChange];

    [_samplerImageView setupMouseTracking];

    if (![self panelIsVisible])
    {
        if ([_samplerImageView mouseIsSamplingImage])
        {
            [_samplerImageView forceStopSamplingImage];
        }

        [_samplerImageView setSamplerImage: nil];
    }
}

- (NSColor *) backgroundColorForPopupPanel
{
    return kUIColor_SamplerImagePopupPanel_Background;
}

- (bool) handleActionKey: (NSString *) key
{
    if ([key isEqualToString: kColorsPopupPanelActionKey_NextSamplerImage])
    {
        [_ppDocument activateNextSamplerImageForPanelType: kPPSamplerImagePanelType_PopupPanel];

        return YES;
    }

    return NO;
}

- (void) handleDirectionCommand: (PPDirectionType) directionType
{
    if (directionType == kPPDirectionType_Right)
    {
        [_ppDocument activateNextSamplerImageForPanelType: kPPSamplerImagePanelType_PopupPanel];
    }
    else if (directionType == kPPDirectionType_Left)
    {
        [_ppDocument activatePreviousSamplerImageForPanelType:
                                                        kPPSamplerImagePanelType_PopupPanel];
    }
}

#pragma mark NSWindow delegate methods

- (NSSize) windowWillResize: (NSWindow *) sender toSize: (NSSize) proposedFrameSize
{
    NSSize proposedSamplerImageViewSize, newSamplerImageViewSize;

    proposedSamplerImageViewSize =
        PPGeometry_SizeDifference(proposedFrameSize,
                                    _sizeDifferenceBetweenPanelAndSamplerImageView);

    newSamplerImageViewSize =
        [_samplerImageView viewSizeForResizingToProposedViewSize: proposedSamplerImageViewSize
                            resizableDirectionsMask: kPPResizableDirectionsMask_Both];

    return PPGeometry_SizeSum(newSamplerImageViewSize,
                                _sizeDifferenceBetweenPanelAndSamplerImageView);
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

#pragma mark PPResizeControl delegate methods

- (void) ppResizeControlDidBeginResizing: (PPResizeControl *) resizeControl
{
    [_samplerImageView disableMouseTracking: YES];
}

- (void) ppResizeControlDidFinishResizing: (PPResizeControl *) resizeControl
{
    [_samplerImageView disableMouseTracking: NO];
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

#pragma mark Private methods

- (void) setupWithActiveSamplerImageFromCurrentDocument
{
    NSSize samplerImageViewSize;
    NSRect newWindowFrame;

    [_samplerImageView setSamplerImage:
                                [_ppDocument activeSamplerImageForPanelType:
                                                        kPPSamplerImagePanelType_PopupPanel]];

    samplerImageViewSize = [_samplerImageView viewSizeForScaledCurrentSamplerImage];

    newWindowFrame = [[self window] frame];
    newWindowFrame.size =
        PPGeometry_SizeSum(samplerImageViewSize, _sizeDifferenceBetweenPanelAndSamplerImageView);

    [[self window] setFrame: newWindowFrame display: NO];
}

@end
