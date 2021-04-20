/*
    PPLayerControlsPopupPanelController.m

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

#import "PPLayerControlsPopupPanelController.h"

#import "PPDocument.h"
#import "PPDocumentLayer.h"
#import "PPDocumentWindowController.h"
#import "PPThumbnailImageView.h"
#import "NSObject_PPUtilities.h"
#import "PPUIColors_Panels.h"
#import "PPLayerControlButtonImagesManager.h"
#import "PPTitleablePopUpButton.h"
#import "PPGeometry.h"
#import "PPBackgroundPattern.h"
#import "PPTextAttributesDicts.h"
#import "NSBitmapImageRep_PPUtilities.h"
#import "NSImage_PPUtilities.h"
#import "PPThumbnailUtilities.h"


#define kLayerControlsPopupPanelNibName     @"LayerControlsPopupPanel"

#define kPopupMenuThumbnailSize             NSMakeSize(21.0f, 21.0f)

#define kDrawingLayerOpacityFormatString    @"%.1f%%"


@interface PPLayerControlsPopupPanelController (PrivateMethods)

- (void) handlePPDocumentNotification_UpdatedDrawingLayerThumbnailImage:
                                                            (NSNotification *) notification;
- (void) handlePPDocumentNotification_SwitchedDrawingLayer: (NSNotification *) notification;
- (void) handlePPDocumentNotification_ReorderedLayers: (NSNotification *) notification;
- (void) handlePPDocumentNotification_ChangedLayerAttribute: (NSNotification *) notification;
- (void) handlePPDocumentNotification_SwitchedLayerOperationTarget:
                                                            (NSNotification *) notification;
- (void) handlePPDocumentNotification_UpdatedBackgroundSettings:
                                                            (NSNotification *) notification;
- (void) handlePPDocumentNotification_ReloadedDocument: (NSNotification *) notification;


- (void) addAsObserverForPPDocumentWindowControllerNotifications;
- (void) removeAsObserverForPPDocumentWindowControllerNotifications;
- (void) handlePPDocumentWindowControllerNotification_ChangedCanvasDisplayMode:
                                                                (NSNotification *) notification;

- (void) addAsObserverForPPLayerControlButtonImagesManagerNotifications;
- (void) removeAsObserverForPPLayerControlButtonImagesManagerNotifications;
- (void) handlePPLayerControlButtonImagesManagerNotification_ChangedDrawLayerImages:
                                                                (NSNotification *) notification;
- (void) handlePPLayerControlButtonImagesManagerNotification_ChangedEnabledLayersImages:
                                                                (NSNotification *) notification;

- (void) handleOpacitySliderDidBeginTracking;
- (void) handleOpacitySliderDidFinishTracking;

- (void) setupWithPPDocumentWindowController:
                                    (PPDocumentWindowController *) ppDocumentWindowController;

- (void) setupDrawingLayerThumbnailImage;
- (void) setupDrawingLayerThumbnailImageBackground;

- (void) setupPopupMenuThumbnailDrawMembers;
- (void) setupPopupMenuThumbnailBackgroundBitmap;
- (void) destroyPopupMenuThumbnailBackgroundBitmap;

- (NSImage *) popupMenuThumbnailImageForLayerImage: (NSImage *) layerImage;

- (void) updateCanvasDisplayMode;
- (void) updateLayerOperationTarget;

- (void) updateLayerControlButtonImages;
- (void) updateCanvasDisplayModeButtonImage;
- (void) updateLayerOperationTargetButtonImage;

- (void) updateDrawingLayerControls;
- (void) updateDrawingLayerControlsIfPanelIsVisible;
- (void) updateDrawingLayerAttributeControls;
- (void) updateDrawingLayerOpacityTextField;

- (void) updateDrawingLayerPopUpButtonMenu;

- (int) layerIndexForPopUpButtonMenuItemAtIndex: (int) itemIndex;
- (int) popUpButtonMenuItemIndexForLayerAtIndex: (int) layerIndex;

- (float) drawingLayerOpacitySliderQuantizedValue;

@end

@implementation PPLayerControlsPopupPanelController

- (void) dealloc
{
    [self removeAsObserverForPPLayerControlButtonImagesManagerNotifications];

    [self setupWithPPDocumentWindowController: nil];

    [self destroyPopupMenuThumbnailBackgroundBitmap];

    [super dealloc];
}

#pragma mark Actions

- (IBAction) canvasDisplayModeButtonPressed: (id) sender
{
    [_ppDocumentWindowController toggleCanvasDisplayMode: self];
}

- (IBAction) layerOperationTargetButtonPressed: (id) sender
{
    [_ppDocumentWindowController toggleLayerOperationTarget: self];
}

- (IBAction) drawingLayerEnabledCheckboxClicked: (id) sender
{
    [[_ppDocument drawingLayer] setEnabled: [_drawingLayerEnabledCheckbox intValue]];
}

- (IBAction) drawingLayerPopupMenuItemSelected: (id) sender
{
    int indexOfSelectedDrawingLayer =
            [self layerIndexForPopUpButtonMenuItemAtIndex:
                                    [_drawingLayerTitleablePopUpButton indexOfSelectedItem]];

    [_ppDocument selectDrawingLayerAtIndex: indexOfSelectedDrawingLayer];
}

- (IBAction) drawingLayerOpacitySliderMoved: (id) sender
{
    if (!_isTrackingOpacitySlider)
    {
        [self handleOpacitySliderDidBeginTracking];
    }

    _ignoreNotificationForChangedLayerAttribute = YES;

    [[_ppDocument drawingLayer] setOpacityWithoutRegisteringUndo:
                                                [self drawingLayerOpacitySliderQuantizedValue]];

    _ignoreNotificationForChangedLayerAttribute = NO;

    [self updateDrawingLayerOpacityTextField];
}

#pragma mark NSWindowController overrrides

- (void) windowDidLoad
{
    _needToUpdateLayerControlButtonImages = YES;
    _needToUpdateDrawingLayerControls = YES;
    _needToUpdateDrawingLayerPopupButtonMenu = YES;

    // [super windowDidLoad] calls [self setupPanelForCurrentPPDocument], so any preliminary
    // setup required before calling setupPanelForCurrentPPDocument should go before this call
    [super windowDidLoad];

    [_backgroundFillTextField setBackgroundColor: [NSColor windowBackgroundColor]];

    [_drawingLayerTitleablePopUpButton setDelegate: self];

    [self addAsObserverForPPLayerControlButtonImagesManagerNotifications];
}

#pragma mark PPPopupPanelController overrides

+ (NSString *) panelNibName
{
    return kLayerControlsPopupPanelNibName;
}

- (void) setPPDocument: (PPDocument *) ppDocument
{
    [super setPPDocument: ppDocument];

    if (!_ppDocument)
    {
        [self setupWithPPDocumentWindowController: nil];
    }
}

- (void) addAsObserverForPPDocumentNotifications
{
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];

    if (!_ppDocument)
        return;

    [notificationCenter addObserver: self
                        selector:
                            @selector(
                            handlePPDocumentNotification_UpdatedDrawingLayerThumbnailImage:)
                        name: PPDocumentNotification_UpdatedDrawingLayerThumbnailImage
                        object: _ppDocument];

    [notificationCenter addObserver: self
                        selector: @selector(handlePPDocumentNotification_SwitchedDrawingLayer:)
                        name: PPDocumentNotification_SwitchedDrawingLayer
                        object: _ppDocument];

    [notificationCenter addObserver: self
                        selector: @selector(handlePPDocumentNotification_ReorderedLayers:)
                        name: PPDocumentNotification_ReorderedLayers
                        object: _ppDocument];

    [notificationCenter addObserver: self
                        selector: @selector(handlePPDocumentNotification_ChangedLayerAttribute:)
                        name: PPDocumentNotification_ChangedLayerAttribute
                        object: _ppDocument];

    [notificationCenter addObserver: self
                        selector:
                            @selector(handlePPDocumentNotification_SwitchedLayerOperationTarget:)
                        name: PPDocumentNotification_SwitchedLayerOperationTarget
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
                        name: PPDocumentNotification_UpdatedDrawingLayerThumbnailImage
                        object: _ppDocument];

    [notificationCenter removeObserver: self
                        name: PPDocumentNotification_SwitchedDrawingLayer
                        object: _ppDocument];

    [notificationCenter removeObserver: self
                        name: PPDocumentNotification_ReorderedLayers
                        object: _ppDocument];

    [notificationCenter removeObserver: self
                        name: PPDocumentNotification_ChangedLayerAttribute
                        object: _ppDocument];

    [notificationCenter removeObserver: self
                        name: PPDocumentNotification_SwitchedLayerOperationTarget
                        object: _ppDocument];

    [notificationCenter removeObserver: self
                        name: PPDocumentNotification_UpdatedBackgroundSettings
                        object: _ppDocument];

    [notificationCenter removeObserver: self
                        name: PPDocumentNotification_ReloadedDocument
                        object: _ppDocument];
}

- (void) setupPanelForCurrentPPDocument
{
    [super setupPanelForCurrentPPDocument];

    [self setupWithPPDocumentWindowController: [_ppDocument ppDocumentWindowController]];

    [self setupDrawingLayerThumbnailImage];
    [self setupDrawingLayerThumbnailImageBackground];

    [self setupPopupMenuThumbnailDrawMembers];
    [self setupPopupMenuThumbnailBackgroundBitmap];

    [self updateCanvasDisplayMode];
    [self updateLayerOperationTarget];

    [[PPLayerControlButtonImagesManager sharedManager] setPPDocument: _ppDocument];

    [self updateDrawingLayerControlsIfPanelIsVisible];

    _needToUpdateDrawingLayerPopupButtonMenu = YES;
}

- (void) setupPanelBeforeMakingVisible
{
    [super setupPanelBeforeMakingVisible];

    if (_needToUpdateLayerControlButtonImages)
    {
        [self updateLayerControlButtonImages];
    }

    if (_needToUpdateDrawingLayerControls)
    {
        [self updateDrawingLayerControls];
    }
}

- (NSColor *) backgroundColorForPopupPanel
{
    return kUIColor_LayerControlsPopupPanel_Background;
}

- (void) handleDirectionCommand: (PPDirectionType) directionType
{
    switch (directionType)
    {
        case kPPDirectionType_Left:
        {
            [_ppDocumentWindowController toggleCanvasDisplayMode: self];
        }
        break;

        case kPPDirectionType_Right:
        {
            [_ppDocumentWindowController toggleLayerOperationTarget: self];
        }
        break;

        case kPPDirectionType_Up:
        {
            [_ppDocumentWindowController makePreviousLayerActive: self];
        }
        break;

        case kPPDirectionType_Down:
        {
            [_ppDocumentWindowController makeNextLayerActive: self];
        }
        break;

        default:
        break;
    }
}

#pragma mark PPTitleablePopUpButton delegate methods

- (NSDictionary *) titleTextAttributesForMenuItemAtIndex: (int) itemIndex
                    onTitleablePopUpButton: (PPTitleablePopUpButton *) button
{
    int layerIndex;
    bool layerIsEnabled;

    layerIndex = [self layerIndexForPopUpButtonMenuItemAtIndex: itemIndex];

    layerIsEnabled = [[_ppDocument layerAtIndex: layerIndex] isEnabled];

    return (layerIsEnabled) ? nil : PPTextAttributesDict_DisabledTitle_PopupButton();
}

- (void) titleablePopUpButtonWillDisplayPopupMenu: (PPTitleablePopUpButton *) button
{
    if (_needToUpdateDrawingLayerPopupButtonMenu)
    {
        [self updateDrawingLayerPopUpButtonMenu];
    }
}

#pragma mark PPDocument notifications

- (void) handlePPDocumentNotification_UpdatedDrawingLayerThumbnailImage:
                                                                (NSNotification *) notification
{
    [_drawingLayerThumbnailView handleUpdateToImage];

    _needToUpdateDrawingLayerPopupButtonMenu = YES;
}

- (void) handlePPDocumentNotification_SwitchedDrawingLayer: (NSNotification *) notification
{
    [self setupDrawingLayerThumbnailImage];
    [self updateDrawingLayerControlsIfPanelIsVisible];
}

- (void) handlePPDocumentNotification_ReorderedLayers: (NSNotification *) notification
{
    [self setupDrawingLayerThumbnailImage];
    [self updateDrawingLayerControlsIfPanelIsVisible];

    _needToUpdateDrawingLayerPopupButtonMenu = YES;
}

- (void) handlePPDocumentNotification_ChangedLayerAttribute: (NSNotification *) notification
{
    NSDictionary *userInfo;
    NSNumber *layerIndexNumber;
    int layerIndex = -1;

    if (_ignoreNotificationForChangedLayerAttribute)
        return;

    userInfo = [notification userInfo];

    layerIndexNumber =
            [userInfo objectForKey: PPDocumentNotification_UserInfoKey_IndexOfChangedLayer];

    if (layerIndexNumber)
    {
        layerIndex = [layerIndexNumber intValue];
    }

    if (layerIndex == [_ppDocument indexOfDrawingLayer])
    {
        if ([self panelIsVisible])
        {
            [self updateDrawingLayerAttributeControls];
        }
        else
        {
            _needToUpdateDrawingLayerControls = YES;
        }
    }

    _needToUpdateDrawingLayerPopupButtonMenu = YES;
}

- (void) handlePPDocumentNotification_SwitchedLayerOperationTarget:
                                                            (NSNotification *) notification
{
    [self updateLayerOperationTarget];

    if ([self panelIsVisible])
    {
        [self updateLayerOperationTargetButtonImage];
    }
    else
    {
        _needToUpdateLayerControlButtonImages = YES;
    }
}

- (void) handlePPDocumentNotification_UpdatedBackgroundSettings:
                                                            (NSNotification *) notification
{
    [self setupDrawingLayerThumbnailImageBackground];

    [self setupPopupMenuThumbnailBackgroundBitmap];

    _needToUpdateDrawingLayerPopupButtonMenu = YES;
}

- (void) handlePPDocumentNotification_ReloadedDocument: (NSNotification *) notification
{
    [self setupPanelForCurrentPPDocument];
}

#pragma mark PPDocumentWindowController notifications

- (void) addAsObserverForPPDocumentWindowControllerNotifications
{
    if (!_ppDocumentWindowController)
        return;

    [[NSNotificationCenter defaultCenter]
        addObserver: self
        selector:
            @selector(handlePPDocumentWindowControllerNotification_ChangedCanvasDisplayMode:)
        name: PPDocumentWindowControllerNotification_ChangedCanvasDisplayMode
        object: _ppDocumentWindowController];
}

- (void) removeAsObserverForPPDocumentWindowControllerNotifications
{
    [[NSNotificationCenter defaultCenter]
                        removeObserver: self
                        name: PPDocumentWindowControllerNotification_ChangedCanvasDisplayMode
                        object: _ppDocumentWindowController];
}

- (void) handlePPDocumentWindowControllerNotification_ChangedCanvasDisplayMode:
                                                                (NSNotification *) notification
{
    [self updateCanvasDisplayMode];

    if ([self panelIsVisible])
    {
        [self updateCanvasDisplayModeButtonImage];
    }
    else
    {
        _needToUpdateLayerControlButtonImages = YES;
    }
}

#pragma mark PPLayerControlButtonImagesManager notifications

- (void) addAsObserverForPPLayerControlButtonImagesManagerNotifications
{
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];

    [notificationCenter
        addObserver: self
        selector:
            @selector(
                handlePPLayerControlButtonImagesManagerNotification_ChangedDrawLayerImages:)
        name: PPLayerControlButtonImagesManagerNotification_ChangedDrawLayerImages
        object: nil];

    [notificationCenter
        addObserver: self
        selector:
            @selector(
                handlePPLayerControlButtonImagesManagerNotification_ChangedEnabledLayersImages:)
        name: PPLayerControlButtonImagesManagerNotification_ChangedEnabledLayersImages
        object: nil];
}

- (void) removeAsObserverForPPLayerControlButtonImagesManagerNotifications
{
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];

    [notificationCenter
                removeObserver: self
                name: PPLayerControlButtonImagesManagerNotification_ChangedDrawLayerImages
                object: nil];

    [notificationCenter
                removeObserver: self
                name: PPLayerControlButtonImagesManagerNotification_ChangedEnabledLayersImages
                object: nil];
}

- (void) handlePPLayerControlButtonImagesManagerNotification_ChangedDrawLayerImages:
                                                                (NSNotification *) notification
{
    if (![self panelIsVisible])
    {
        _needToUpdateLayerControlButtonImages = YES;

        return;
    }

    if (_canvasDisplayMode == kPPLayerDisplayMode_DrawingLayerOnly)
    {
        [self updateCanvasDisplayModeButtonImage];
    }

    if (_layerOperationTarget == kPPLayerOperationTarget_DrawingLayerOnly)
    {
        [self updateLayerOperationTargetButtonImage];
    }
}

- (void) handlePPLayerControlButtonImagesManagerNotification_ChangedEnabledLayersImages:
                                                                (NSNotification *) notification
{
    if (![self panelIsVisible])
    {
        _needToUpdateLayerControlButtonImages = YES;

        return;
    }

    if (_canvasDisplayMode != kPPLayerDisplayMode_DrawingLayerOnly)
    {
        [self updateCanvasDisplayModeButtonImage];
    }

    if (_layerOperationTarget != kPPLayerOperationTarget_DrawingLayerOnly)
    {
        [self updateLayerOperationTargetButtonImage];
    }
}

#pragma mark Opacity slider tracking

- (void) handleOpacitySliderDidBeginTracking
{
    if (_isTrackingOpacitySlider)
        return;

    _isTrackingOpacitySlider = YES;

    _drawingLayerInitialOpacity = [[_ppDocument drawingLayer] opacity];

    [_ppDocument disableThumbnailImageUpdateNotifications: YES];

    // won't return to the main run loop until the slider's done tracking, so post a message
    // in the next stack frame to serve as notification that tracking's finished
    [self ppPerformSelectorFromNewStackFrame: @selector(handleOpacitySliderDidFinishTracking)];
}

- (void) handleOpacitySliderDidFinishTracking
{
    float newOpacity = [self drawingLayerOpacitySliderQuantizedValue];

    _isTrackingOpacitySlider = NO;

    [_ppDocument disableThumbnailImageUpdateNotifications: NO];

    if (newOpacity != _drawingLayerInitialOpacity)
    {
        [[_ppDocument drawingLayer] setOpacity: newOpacity];
    }
}

#pragma mark Private methods

- (void) setupWithPPDocumentWindowController:
                                    (PPDocumentWindowController *) ppDocumentWindowController
{
    if (_ppDocumentWindowController == ppDocumentWindowController)
    {
        return;
    }

    if (_ppDocumentWindowController)
    {
        [self removeAsObserverForPPDocumentWindowControllerNotifications];
    }

    [_ppDocumentWindowController release];
    _ppDocumentWindowController = [ppDocumentWindowController retain];

    if (_ppDocumentWindowController)
    {
        [self addAsObserverForPPDocumentWindowControllerNotifications];
    }
}

- (void) setupDrawingLayerThumbnailImage
{
    [_drawingLayerThumbnailView setImage: [_ppDocument drawingLayerThumbnailImage]];
}

- (void) setupDrawingLayerThumbnailImageBackground
{
    [_drawingLayerThumbnailView setBackgroundPattern: [_ppDocument backgroundPattern]];
}

- (void) setupPopupMenuThumbnailDrawMembers
{
    _popupMenuThumbnailDrawSourceRect.size = [_ppDocument canvasSize];
    _popupMenuThumbnailDrawDestinationRect =
        PPGeometry_ScaledBoundsForFrameOfSizeToFitFrameOfSize(
                                                        _popupMenuThumbnailDrawSourceRect.size,
                                                        kPopupMenuThumbnailSize);

    _popupMenuThumbnailInterpolation =
        PPThumbUtils_ImageInterpolationForSourceRectToDestinationRect(
                                                        _popupMenuThumbnailDrawSourceRect,
                                                        _popupMenuThumbnailDrawDestinationRect);
}

- (void) setupPopupMenuThumbnailBackgroundBitmap
{
    PPBackgroundPattern *documentBackgroundPattern, *thumbnailBackgroundPattern;
    float patternScalingFactor;
    NSColor *thumbnailBackgroundPatternColor;
    NSBitmapImageRep *backgroundBitmap;

    [self destroyPopupMenuThumbnailBackgroundBitmap];

    if (!_ppDocument || NSIsEmptyRect(_popupMenuThumbnailDrawSourceRect))
    {
        goto ERROR;
    }

    documentBackgroundPattern = [_ppDocument backgroundPattern];

    patternScalingFactor = kScalingFactorForThumbnailBackgroundPatternSize
                                * _popupMenuThumbnailDrawDestinationRect.size.width
                                / _popupMenuThumbnailDrawSourceRect.size.width;

    if (patternScalingFactor > 1.0f)
    {
        patternScalingFactor = 1.0f;
    }

    thumbnailBackgroundPattern =
            [documentBackgroundPattern backgroundPatternScaledByFactor: patternScalingFactor];

    thumbnailBackgroundPatternColor = [thumbnailBackgroundPattern patternFillColor];

    if (!thumbnailBackgroundPatternColor)
        goto ERROR;

    backgroundBitmap = [NSBitmapImageRep ppImageBitmapOfSize: kPopupMenuThumbnailSize];

    if (!backgroundBitmap)
        goto ERROR;

    [backgroundBitmap ppSetAsCurrentGraphicsContext];

    [thumbnailBackgroundPatternColor set];
    NSRectFill(_popupMenuThumbnailDrawDestinationRect);

    [backgroundBitmap ppRestoreGraphicsContext];

    _popupMenuThumbnailBackgroundBitmap = [backgroundBitmap retain];

    return;

ERROR:
    return;
}

- (NSImage *) popupMenuThumbnailImageForLayerImage: (NSImage *) layerImage
{
    NSBitmapImageRep *thumbnailBitmap;

    if (!layerImage)
        goto ERROR;

    thumbnailBitmap = [[_popupMenuThumbnailBackgroundBitmap copy] autorelease];

    if (!thumbnailBitmap)
        goto ERROR;

    [thumbnailBitmap ppSetAsCurrentGraphicsContext];

    [[NSGraphicsContext currentContext] setImageInterpolation: _popupMenuThumbnailInterpolation];

    [layerImage drawInRect: _popupMenuThumbnailDrawDestinationRect
                fromRect: _popupMenuThumbnailDrawSourceRect
                operation: NSCompositeSourceOver
                fraction: 1.0f];

    [thumbnailBitmap ppRestoreGraphicsContext];

    return [NSImage ppImageWithBitmap: thumbnailBitmap];

ERROR:
    return nil;
}

- (void) destroyPopupMenuThumbnailBackgroundBitmap
{
    [_popupMenuThumbnailBackgroundBitmap release];
    _popupMenuThumbnailBackgroundBitmap = nil;
}

- (void) updateCanvasDisplayMode
{
    _canvasDisplayMode = [_ppDocumentWindowController canvasDisplayMode];

    if (_canvasDisplayMode != kPPLayerDisplayMode_DrawingLayerOnly)
    {
        _canvasDisplayMode = kPPLayerDisplayMode_VisibleLayers;
    }
}

- (void) updateLayerOperationTarget
{
    _layerOperationTarget = [_ppDocument layerOperationTarget];

    if (_layerOperationTarget != kPPLayerOperationTarget_DrawingLayerOnly)
    {
        _layerOperationTarget = kPPLayerOperationTarget_VisibleLayers;
    }
}

- (void) updateLayerControlButtonImages
{
    [self updateCanvasDisplayModeButtonImage];
    [self updateLayerOperationTargetButtonImage];

    _needToUpdateLayerControlButtonImages = NO;
}

- (void) updateCanvasDisplayModeButtonImage
{
    NSImage *buttonImage =
                [[PPLayerControlButtonImagesManager sharedManager]
                                                buttonImageForDisplayMode: _canvasDisplayMode];

    // button's current image may already be buttonImage, so force redraw by clearing the image
    // first
    [_canvasDisplayModeButton setImage: nil];
    [_canvasDisplayModeButton setImage: buttonImage];
}

- (void) updateLayerOperationTargetButtonImage
{
    NSImage *buttonImage =
                [[PPLayerControlButtonImagesManager sharedManager]
                                        buttonImageForOperationTarget: _layerOperationTarget];

    // button's current image may already be buttonImage, so force redraw by clearing the image
    // first
    [_layerOperationTargetButton setImage: nil];
    [_layerOperationTargetButton setImage: buttonImage];
}

- (void) updateDrawingLayerControls
{
    [_drawingLayerThumbnailView handleUpdateToImage];

    [self updateDrawingLayerAttributeControls];

    _needToUpdateDrawingLayerControls = NO;
}

- (void) updateDrawingLayerControlsIfPanelIsVisible
{
    if ([self panelIsVisible])
    {
        [self updateDrawingLayerControls];
    }
    else
    {
        _needToUpdateDrawingLayerControls = YES;
    }
}

- (void) updateDrawingLayerAttributeControls
{
    PPDocumentLayer *drawingLayer;
    bool drawingLayerIsEnabled;
    NSDictionary *drawingLayerTitleAttributes;

    drawingLayer = [_ppDocument drawingLayer];
    drawingLayerIsEnabled = [drawingLayer isEnabled];

    [_drawingLayerEnabledCheckbox setIntValue: drawingLayerIsEnabled];

    drawingLayerTitleAttributes =
            (drawingLayerIsEnabled) ? nil : PPTextAttributesDict_DisabledTitle_PopupButton();

    [_drawingLayerTitleablePopUpButton setTitle: [drawingLayer name]
                                        withTextAttributes: drawingLayerTitleAttributes];

    [self updateDrawingLayerOpacityTextField];

    [_drawingLayerOpacitySlider setFloatValue: [drawingLayer opacity]];
}

- (void) updateDrawingLayerOpacityTextField
{
    float opacity = [[_ppDocument drawingLayer] opacity] * 100.0f;
    NSString *opacityString =
                        [NSString stringWithFormat: kDrawingLayerOpacityFormatString, opacity];

    [_drawingLayerOpacityTextField setStringValue: opacityString];
}

- (void) updateDrawingLayerPopUpButtonMenu
{
    NSMenu *layersMenu;
    int layerCounter;
    PPDocumentLayer *layer;
    NSString *layerName;
        // use PPSDKNativeType_NSMenuItemPtr for menuItem, as -[NSMenu addItemWithTitle:...]
        // could return either (NSMenuItem *) or (id <NSMenuItem>), depending on the SDK
    PPSDKNativeType_NSMenuItemPtr menuItem;

    layersMenu = [[[NSMenu alloc] init] autorelease];

    layerCounter = [_ppDocument numLayers];

    while (layerCounter--)
    {
        layer = [_ppDocument layerAtIndex: layerCounter];

        layerName = [layer name];

        if (!layerName)
        {
            layerName = @"";
        }

        menuItem = [layersMenu addItemWithTitle: layerName
                                action: NULL
                                keyEquivalent: @""];

        [menuItem setImage: [self popupMenuThumbnailImageForLayerImage: [layer image]]];

        if (![layer isEnabled])
        {
            NSAttributedString *attributedTitle;

            attributedTitle =
                [[[NSAttributedString alloc]
                                        initWithString: layerName
                                        attributes:
                                            PPTextAttributesDict_DisabledTitle_PopupMenuItem()]
                                    autorelease];

            [menuItem setAttributedTitle: attributedTitle];
        }
    }

    [_drawingLayerTitleablePopUpButton setMenu: layersMenu];

    [_drawingLayerTitleablePopUpButton
        selectItemAtIndex:
            [self popUpButtonMenuItemIndexForLayerAtIndex: [_ppDocument indexOfDrawingLayer]]];

    _needToUpdateDrawingLayerPopupButtonMenu = NO;
}

- (int) layerIndexForPopUpButtonMenuItemAtIndex: (int) itemIndex
{
    return [_ppDocument numLayers] - itemIndex - 1;
}

- (int) popUpButtonMenuItemIndexForLayerAtIndex: (int) layerIndex
{
    return [_ppDocument numLayers] - layerIndex - 1;
}

- (float) drawingLayerOpacitySliderQuantizedValue
{
    // roundoff slider value to nearest .5% (1/200)
    return roundf(200.0f * [_drawingLayerOpacitySlider floatValue]) / 200.0f;
}

@end
