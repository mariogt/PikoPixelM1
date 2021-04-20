/*
    PPColorPickerPopupPanelController.m

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

#import "PPColorPickerPopupPanelController.h"

#import "PPColorPickerPopupPanel.h"
#import "PPDocument.h"
#import "PPToolsPanelController.h"
#import "PPUserDefaults.h"
#import "PPUIColors_Panels.h"
#import "PPPopupPanelsController.h"
#import "PPPopupPanelActionKeys.h"
#import "NSObject_PPUtilities.h"
#import "PPGeometry.h"


#define kColorPickerPopupPanelNibName           @"ColorPickerPopupPanel"

#define kColorPickerPopupPanelBorderThickness   20.0f


@interface PPColorPickerPopupPanelController (PrivateMethods)

- (void) handlePPDocumentNotification_ChangedFillColor: (NSNotification *) notification;

- (void) addAsObserverForNSColorPanelNotifications;
- (void) removeAsObserverForNSColorPanelNotifications;
- (void) handleNSColorPanelNotification_WillMove: (NSNotification *) notification;
- (void) handleNSColorPanelNotification_DidResize: (NSNotification *) notification;
- (void) handleNSColorPanelNotification_WillClose: (NSNotification *) notification;

- (void) setupClickableControlsMouseTracking;
- (void) mouseEntered: (NSEvent *) theEvent;
- (void) mouseExited: (NSEvent *) theEvent;

- (void) updateDocumentFillColor;
- (void) updatePopupPanelSizeForColorPanelFrameSize;
- (void) updatePopupPanelPositionForColorPanelPosition;
- (void) updateColorWellColor;
- (void) updateSamplerImageButtonsVisibility;

- (void) setColorPanelAsPopupChildWindow: (bool) shouldSetColorPanelAsChildWindow;

@end

@implementation PPColorPickerPopupPanelController

#pragma mark Actions

- (IBAction) colorWellUpdated: (id) sender
{
    [self ppPerformSelectorAtomicallyFromNewStackFrame: @selector(updateDocumentFillColor)];
}

- (IBAction) contentFrameButtonPressed: (id) sender
{
    NSColorPanel *sharedColorPanel = [NSColorPanel sharedColorPanel];

    if ([sharedColorPanel isVisible])
    {
        [sharedColorPanel orderFront: self];
    }
}

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
    [super windowDidLoad];

    _colorPanelMode = [PPUserDefaults colorPickerPopupPanelMode];
    _colorPanelContentSize = [PPUserDefaults colorPickerPopupPanelContentSize];

    [_nekoButton setHidden: YES];
}

#pragma mark PPPopupPanelController overrides

+ (NSString *) panelNibName
{
    return kColorPickerPopupPanelNibName;
}

- (void) setPanelEnabled: (bool) enablePanel
{
    bool popupPanelIsVisible = [self panelIsVisible];

    if (enablePanel && !popupPanelIsVisible)
    {
        NSColorPanel *colorPanel;
        NSSize colorPanelFrameSize, colorPanelContentSize;
        NSPoint colorPanelOrigin;

        colorPanel = [NSColorPanel sharedColorPanel];
        [colorPanel orderOut: self];

        _oldColorPanelFrame = [colorPanel frame];
        _oldColorPanelMode = [colorPanel mode];

        // make sure panel is loaded before accessing IBOutlets
        if (!_panelDidLoad)
        {
            [self window];
        }

        [self updateColorWellColor];

        [self updateSamplerImageButtonsVisibility];

        // mode should be set before content size, otherwise frame may be resized because it
        // doesn't fit the initial (wrong) mode
        [colorPanel setMode: _colorPanelMode];
        [colorPanel setContentSize: _colorPanelContentSize];

        colorPanelFrameSize = [colorPanel frame].size;

        if (!NSEqualSizes(_colorPanelFrameSize, colorPanelFrameSize))
        {
            _colorPanelFrameSize = colorPanelFrameSize;

            [self updatePopupPanelSizeForColorPanelFrameSize];
        }

        colorPanelContentSize = [[colorPanel contentView] frame].size;

        if (!NSEqualSizes(_colorPanelContentSize, colorPanelContentSize))
        {
            _colorPanelContentSize = colorPanelContentSize;

            _needToSaveColorPanelContentSizeToDefaults = YES;
        }

        [super setPanelEnabled: enablePanel];

        colorPanelOrigin = [[self window] frame].origin;
        colorPanelOrigin.x += kColorPickerPopupPanelBorderThickness;
        colorPanelOrigin.y += kColorPickerPopupPanelBorderThickness;

        [colorPanel setFrameOrigin: colorPanelOrigin];

        _needToReactivateToolPanelColorWell =
                            [[PPToolsPanelController sharedController] fillColorWellIsActive];

        [_colorWell activate: YES];
        [colorPanel orderFront: self];

        // setup clickable controls mouse tracking only after showing the color panel,
        // otherwise the color panel may show briefly in its old location when the setup
        // makes the color panel the child window of the popup panel
        [self setupClickableControlsMouseTracking];

        [self addAsObserverForNSColorPanelNotifications];
        [_nekoButton setHidden: NO];
    }
    else if (!enablePanel && popupPanelIsVisible)
    {
        NSColorPanel *colorPanel;
        int initialColorPanelMode;

        colorPanel = [NSColorPanel sharedColorPanel];

        [self removeAsObserverForNSColorPanelNotifications];
        [_nekoButton setHidden: YES];

        [self setColorPanelAsPopupChildWindow: NO];

        [colorPanel endEditingFor: nil];

        initialColorPanelMode = _colorPanelMode;
        _colorPanelMode = [colorPanel mode];

        if (_colorPanelMode != initialColorPanelMode)
        {
            [PPUserDefaults setColorPickerPopupPanelMode: _colorPanelMode];
        }

        if (_needToSaveColorPanelContentSizeToDefaults)
        {
            [PPUserDefaults setColorPickerPopupPanelContentSize: _colorPanelContentSize];
            _needToSaveColorPanelContentSizeToDefaults = NO;
        }

        [super setPanelEnabled: enablePanel];

        [self setupClickableControlsMouseTracking];

        if ([_colorWell isActive])
        {
            [_colorWell deactivate];
        }

        if (!NSIsEmptyRect(_oldColorPanelFrame))
        {
            [colorPanel setMode: _oldColorPanelMode];
            [colorPanel setFrame: _oldColorPanelFrame display: YES];
        }

        if (_needToReactivateToolPanelColorWell)
        {
            [[PPToolsPanelController sharedController] activateFillColorWell];
        }
        else if ([[PPToolsPanelController sharedController] fillColorWellIsActive])
        {
            [NSApp orderFrontColorPanel: self];
        }
    }
    else
    {
        [super setPanelEnabled: enablePanel];
    }
}

- (void) addAsObserverForPPDocumentNotifications
{
    if (!_ppDocument)
        return;

    [[NSNotificationCenter defaultCenter]
                            addObserver: self
                            selector: @selector(handlePPDocumentNotification_ChangedFillColor:)
                            name: PPDocumentNotification_ChangedFillColor
                            object: _ppDocument];
}

- (void) removeAsObserverForPPDocumentNotifications
{
    [[NSNotificationCenter defaultCenter] removeObserver: self
                                            name: PPDocumentNotification_ChangedFillColor
                                            object: _ppDocument];
}

- (NSColor *) backgroundColorForPopupPanel
{
    return kUIColor_ColorPickerPopupPanel_Background;
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

#pragma mark PPColorPickerPopupPanel delegate methods

- (void) colorPickerPopupPanelDidFinishHandlingMouseDownEvent: (PPColorPickerPopupPanel *) panel
{
    if ([self panelIsVisible])
    {
        if (![_colorWell isActive])
        {
            [_colorWell activate: YES];
        }

        [[NSColorPanel sharedColorPanel] orderFront: self];
    }
}

#pragma mark PPDocument notifications

- (void) handlePPDocumentNotification_ChangedFillColor: (NSNotification *) notification
{
    [self updateColorWellColor];
}

#pragma mark NSColorPanel notifications

- (void) addAsObserverForNSColorPanelNotifications
{
    NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
    NSColorPanel *colorPanel = [NSColorPanel sharedColorPanel];

    [defaultCenter addObserver: self
                    selector: @selector(handleNSColorPanelNotification_WillMove:)
                    name: NSWindowWillMoveNotification
                    object: colorPanel];

    [defaultCenter addObserver: self
                    selector: @selector(handleNSColorPanelNotification_DidResize:)
                    name: NSWindowDidResizeNotification
                    object: colorPanel];

    [defaultCenter addObserver: self
                    selector: @selector(handleNSColorPanelNotification_WillClose:)
                    name: NSWindowWillCloseNotification
                    object: colorPanel];
}

- (void) removeAsObserverForNSColorPanelNotifications
{
    NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
    NSColorPanel *colorPanel = [NSColorPanel sharedColorPanel];

    [defaultCenter removeObserver: self
                    name: NSWindowWillMoveNotification
                    object: colorPanel];

    [defaultCenter removeObserver: self
                    name: NSWindowDidResizeNotification
                    object: colorPanel];

    [defaultCenter removeObserver: self
                    name: NSWindowWillCloseNotification
                    object: colorPanel];
}

- (void) handleNSColorPanelNotification_WillMove: (NSNotification *) notification
{
    NSColorPanel *colorPanel = [NSColorPanel sharedColorPanel];

    _oldColorPanelFrame = [colorPanel frame];
    _oldColorPanelMode = [colorPanel mode];

    _needToReactivateToolPanelColorWell = YES;
}

- (void) handleNSColorPanelNotification_DidResize: (NSNotification *) notification
{
    NSColorPanel *colorPanel;
    NSSize colorPanelContentSize;

    colorPanel = [NSColorPanel sharedColorPanel];

    colorPanelContentSize = [[colorPanel contentView] frame].size;

    if (!NSEqualSizes(_colorPanelContentSize, colorPanelContentSize))
    {
        _colorPanelContentSize = colorPanelContentSize;

        _needToSaveColorPanelContentSizeToDefaults = YES;
    }

    _colorPanelFrameSize = [colorPanel frame].size;

    [self updatePopupPanelSizeForColorPanelFrameSize];
    [self updatePopupPanelPositionForColorPanelPosition];

    [self ppPerformSelectorAtomicallyFromNewStackFrame:
                                            @selector(setupClickableControlsMouseTracking)];
}

- (void) handleNSColorPanelNotification_WillClose: (NSNotification *) notification
{
    [self setPanelEnabled: NO];
}

#pragma mark Clickable controls mouse tracking

- (void) setupClickableControlsMouseTracking
{
    if (_clickableControlsBoundsTrackingRectTag)
    {
        [_clickableControlsBoundsTrackingView
                                removeTrackingRect: _clickableControlsBoundsTrackingRectTag];

        _clickableControlsBoundsTrackingRectTag = 0;
    }

    if ([self panelIsVisible])
    {
        NSPoint mouseLocationInWindow;
        NSRect trackingRect;
        bool mouseIsInsideTrackingRect;

        mouseLocationInWindow = [[self window] mouseLocationOutsideOfEventStream];
        trackingRect = [_clickableControlsBoundsTrackingView frame];

        mouseIsInsideTrackingRect =
                            (NSPointInRect(mouseLocationInWindow, trackingRect)) ? YES : NO;

        _clickableControlsBoundsTrackingRectTag =
            [_clickableControlsBoundsTrackingView addTrackingRect: trackingRect
                                                    owner: self
                                                    userData: NULL
                                                    assumeInside: mouseIsInsideTrackingRect];

        [self setColorPanelAsPopupChildWindow: mouseIsInsideTrackingRect];
    }
}

- (void) mouseEntered: (NSEvent *) theEvent
{
    NSTrackingRectTag trackingRectTag = [theEvent trackingNumber];

    if (trackingRectTag != _clickableControlsBoundsTrackingRectTag)
    {
        return;
    }

    if (![_colorWell isActive])
    {
        [_colorWell activate: YES];
    }

    // when the mouse is inside the clickable controls bounds tracking rect (which loosely
    // bounds the arrow buttons & the color panel's resize control), setting the color panel
    // to be a child window of the popup forces the popup to always stay behind the color panel,
    // so that mouseclicks on the popup won't bring it to the front and obscure the color panel
    [self setColorPanelAsPopupChildWindow: YES];
}

- (void) mouseExited: (NSEvent *) theEvent
{
    NSTrackingRectTag trackingRectTag = [theEvent trackingNumber];

    if (trackingRectTag != _clickableControlsBoundsTrackingRectTag)
    {
        return;
    }

    if (![_colorWell isActive])
    {
        [_colorWell activate: YES];
    }

    // when the mouse is outside the clickable controls bounds tracking rect (out of range of
    // clickable controls), remove the color panel as a child window of the popup panel so that
    // a mouseclick on the popup can bring it to the front & reveal the neko image easter egg
    [self setColorPanelAsPopupChildWindow: NO];
}

#pragma mark Private methods

- (void) updateDocumentFillColor
{
    [_ppDocument setFillColor: [_colorWell color]];
}

- (void) updatePopupPanelSizeForColorPanelFrameSize
{
    static NSSize popupPanelMarginSize = {2.0f * kColorPickerPopupPanelBorderThickness,
                                            2.0f * kColorPickerPopupPanelBorderThickness};

    NSSize newPopupPanelSize = PPGeometry_SizeSum(_colorPanelFrameSize, popupPanelMarginSize);

    [[self window] setContentSize: newPopupPanelSize];
}

- (void) updatePopupPanelPositionForColorPanelPosition
{
    NSPoint newPopupPanelOrigin;

    newPopupPanelOrigin = [[NSColorPanel sharedColorPanel] frame].origin;
    newPopupPanelOrigin.x -= kColorPickerPopupPanelBorderThickness;
    newPopupPanelOrigin.y -= kColorPickerPopupPanelBorderThickness;

    [[self window] setFrameOrigin: newPopupPanelOrigin];
}

- (void) updateColorWellColor
{
    [_colorWell setColor: [_ppDocument fillColor]];
}

- (void) updateSamplerImageButtonsVisibility
{
    bool shouldHideButtons = ([_ppDocument numSamplerImages] <= 0) ? YES : NO;

    [_previousSamplerImageButton setHidden: shouldHideButtons];
    [_nextSamplerImageButton setHidden: shouldHideButtons];
}

- (void) setColorPanelAsPopupChildWindow: (bool) shouldSetColorPanelAsChildWindow
{
    NSColorPanel *colorPanel = [NSColorPanel sharedColorPanel];

    if (shouldSetColorPanelAsChildWindow)
    {
        if (_colorPanelIsChildWindow)
            return;

        [[self window] addChildWindow: colorPanel ordered: NSWindowAbove];
        _colorPanelIsChildWindow = YES;
    }
    else
    {
        if (!_colorPanelIsChildWindow)
            return;

        [[self window] removeChildWindow: colorPanel];
        _colorPanelIsChildWindow = NO;
    }
}

@end
