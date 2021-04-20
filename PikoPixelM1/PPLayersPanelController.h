/*
    PPLayersPanelController.h

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

#import "PPPanelController.h"
#import "PPDefines.h"
#import "PPLayerDisplayMode.h"
#import "PPDocumentTypes.h"


@class PPLayersTableView, PPLayerBlendingModeButton, PPDocumentWindowController,
        PPLayerOpacitySliderCell;

@interface PPLayersPanelController : PPPanelController
{
    IBOutlet NSButton *_canvasDisplayModeButton;
    IBOutlet NSButton *_layerOperationTargetButton;
    IBOutlet PPLayersTableView *_layersTable;
    IBOutlet PPLayerBlendingModeButton *_layerBlendingModeButton;

    PPDocumentWindowController *_ppDocumentWindowController;

    PPLayerOpacitySliderCell *_trackingOpacitySliderCell;

    NSTrackingRectTag _panelContentViewTrackingRectTag;

    NSImage *_cachedLayerThumbnailImages[kMaxLayersPerDocument];
    NSBitmapImageRep *_layerThumbnailBackgroundBitmap;
    NSSize _layerThumbnailMaxSize;
    NSRect _layerThumbnailSourceRect;
    NSRect _layerThumbnailDestinationRect;
    NSImageInterpolation _layerThumbnailInterpolation;
    int _numCachedLayerThumbnails;

    NSMutableDictionary *_cachedDisabledLayerNameAttrStringsDict;

    PPLayerDisplayMode _canvasDisplayMode;
    PPLayerOperationTarget _layerOperationTarget;

    bool _ignoreNotificationForChangedLayerAttribute;
    bool _mouseIsInsideTrackingRect;
    bool _needToUpdateLayerControlButtonImages;
}

- (IBAction) canvasDisplayModeButtonPressed: (id) sender;
- (IBAction) layerOperationTargetButtonPressed: (id) sender;

- (IBAction) layersTableOpacitySliderMoved: (id) sender;

- (IBAction) addLayerButtonPressed: (id) sender;
- (IBAction) deleteLayerButtonPressed: (id) sender;
- (IBAction) duplicateLayerButtonPressed: (id) sender;

- (IBAction) layerBlendingModeButtonPressed: (id) sender;

- (void) setTrackingOpacitySliderCell: (PPLayerOpacitySliderCell *) trackingOpacitySliderCell;

@end
