/*
    PPDocument_Notifications.h

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

#import "PPDocument.h"


@interface PPDocument (Notifications)

- (void) postNotification_UpdatedMergedVisibleAreaInRect: (NSRect) updateRect;

- (void) postNotification_UpdatedDrawingLayerAreaInRect: (NSRect) updateRect;

- (void) postNotification_UpdatedMergedVisibleThumbnailImage;

- (void) postNotification_UpdatedDrawingLayerThumbnailImage;

- (void) postNotification_UpdatedSelection;

- (void) postNotification_SwitchedDrawingLayer;

- (void) postNotification_ReorderedLayers;

- (void) postNotification_PerformedMultilayerOperation;

- (void) postNotification_ChangedAttributeOfLayerAtIndex: (int) layerIndex;

- (void) postNotification_SwitchedLayerOperationTarget;

- (void) postNotification_SwitchedLayerBlendingMode;

- (void) postNotification_SwitchedSelectedTool;

- (void) postNotification_SwitchedActiveTool;

- (void) postNotification_ChangedFillColor;

- (void) postNotification_UpdatedBackgroundSettings;

- (void) postNotification_UpdatedGridSettings;

- (void) postNotification_ReloadedDocument;

- (void) postNotification_UpdatedSamplerImages;

- (void) postNotification_SwitchedActiveSamplerImageForPanelType:
                                                        (PPSamplerImagePanelType) panelType;

@end
