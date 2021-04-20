/*
    PPLayerControlsPopupPanelController.h

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

#import "PPPopupPanelController.h"
#import "PPLayerDisplayMode.h"
#import "PPDocumentTypes.h"


@class PPThumbnailImageView, PPTitleablePopUpButton, PPDocumentWindowController;

@interface PPLayerControlsPopupPanelController : PPPopupPanelController
{
    IBOutlet NSButton *_canvasDisplayModeButton;
    IBOutlet NSButton *_layerOperationTargetButton;

    IBOutlet NSButton *_drawingLayerEnabledCheckbox;
    IBOutlet PPThumbnailImageView *_drawingLayerThumbnailView;
    IBOutlet PPTitleablePopUpButton *_drawingLayerTitleablePopUpButton;
    IBOutlet NSTextField *_drawingLayerOpacityTextField;
    IBOutlet NSSlider *_drawingLayerOpacitySlider;

    IBOutlet NSTextField *_backgroundFillTextField;

    PPDocumentWindowController *_ppDocumentWindowController;

    PPLayerDisplayMode _canvasDisplayMode;
    PPLayerOperationTarget _layerOperationTarget;

    NSBitmapImageRep *_popupMenuThumbnailBackgroundBitmap;
    NSRect _popupMenuThumbnailDrawSourceRect;
    NSRect _popupMenuThumbnailDrawDestinationRect;
    NSImageInterpolation _popupMenuThumbnailInterpolation;

    float _drawingLayerInitialOpacity;

    bool _needToUpdateLayerControlButtonImages;
    bool _needToUpdateDrawingLayerControls;
    bool _needToUpdateDrawingLayerPopupButtonMenu;
    bool _isTrackingOpacitySlider;
    bool _ignoreNotificationForChangedLayerAttribute;
}

- (IBAction) canvasDisplayModeButtonPressed: (id) sender;
- (IBAction) layerOperationTargetButtonPressed: (id) sender;
- (IBAction) drawingLayerEnabledCheckboxClicked: (id) sender;
- (IBAction) drawingLayerPopupMenuItemSelected: (id) sender;
- (IBAction) drawingLayerOpacitySliderMoved: (id) sender;

@end
