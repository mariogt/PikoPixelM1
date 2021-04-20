/*
    PPDocument_Notifications.m

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

#import "PPDocument_Notifications.h"


NSString *PPDocumentNotification_UpdatedMergedVisibleArea =
                                            @"PPDocumentNotification_UpdatedMergedVisibleArea";

NSString *PPDocumentNotification_UpdatedDrawingLayerArea =
                                            @"PPDocumentNotification_UpdatedDrawingLayerArea";

NSString *PPDocumentNotification_UpdatedMergedVisibleThumbnailImage =
                                @"PPDocumentNotification_UpdatedMergedVisibleThumbnailImage";

NSString *PPDocumentNotification_UpdatedDrawingLayerThumbnailImage =
                                @"PPDocumentNotification_UpdatedDrawingLayerThumbnailImage";

NSString *PPDocumentNotification_UpdatedSelection = @"PPDocumentNotification_UpdatedSelection";

NSString *PPDocumentNotification_SwitchedDrawingLayer =
                                                @"PPDocumentNotification_SwitchedDrawingLayer";

NSString *PPDocumentNotification_ReorderedLayers = @"PPDocumentNotification_ReorderedLayers";

NSString *PPDocumentNotification_PerformedMultilayerOperation =
                                        @"PPDocumentNotification_PerformedMultilayerOperation";

NSString *PPDocumentNotification_ChangedLayerAttribute =
                                            @"PPDocumentNotification_ChangedLayerAttribute";

NSString *PPDocumentNotification_SwitchedLayerOperationTarget =
                                        @"PPDocumentNotification_SwitchedLayerOperationTarget";

NSString *PPDocumentNotification_SwitchedLayerBlendingMode =
                                            @"PPDocumentNotification_SwitchedLayerBlendingMode";

NSString *PPDocumentNotification_SwitchedSelectedTool =
                                            @"PPDocumentNotification_SwitchedSelectedTool";

NSString *PPDocumentNotification_SwitchedActiveTool =
                                            @"PPDocumentNotification_SwitchedActiveTool";

NSString *PPDocumentNotification_ChangedFillColor = @"PPDocumentNotification_ChangedFillColor";

NSString *PPDocumentNotification_UpdatedBackgroundSettings =
                                            @"PPDocumentNotification_UpdatedBackgroundSettings";

NSString *PPDocumentNotification_UpdatedGridSettings =
                                            @"PPDocumentNotification_UpdatedGridSettings";

NSString *PPDocumentNotification_ReloadedDocument = @"PPDocumentNotification_ReloadedDocument";

NSString *PPDocumentNotification_UpdatedSamplerImages =
                                            @"PPDocumentNotification_UpdatedSamplerImages";

NSString *PPDocumentNotification_SwitchedActiveSamplerImage =
                                        @"PPDocumentNotification_SwitchedActiveSamplerImage";


NSString *PPDocumentNotification_UserInfoKey_UpdateAreaRect =
                                        @"PPDocumentNotification_UserInfoKey_UpdateAreaRect";

NSString *PPDocumentNotification_UserInfoKey_IndexOfChangedLayer =
                                    @"PPDocumentNotification_UserInfoKey_IndexOfChangedLayer";

NSString *PPDocumentNotification_UserInfoKey_SamplerImagePanelType =
                                    @"PPDocumentNotification_UserInfoKey_SamplerImagePanelType";


@implementation PPDocument (Notifications)

- (void) postNotification_UpdatedMergedVisibleAreaInRect: (NSRect) updateRect
{
    NSDictionary *userInfo;

    userInfo = [NSDictionary dictionaryWithObject: [NSValue valueWithRect: updateRect]
                                forKey: PPDocumentNotification_UserInfoKey_UpdateAreaRect];

    [[NSNotificationCenter defaultCenter]
                                postNotificationName:
                                                PPDocumentNotification_UpdatedMergedVisibleArea
                                object: self
                                userInfo: userInfo];
}

- (void) postNotification_UpdatedDrawingLayerAreaInRect: (NSRect) updateRect
{
    NSDictionary *userInfo;

    userInfo = [NSDictionary dictionaryWithObject: [NSValue valueWithRect: updateRect]
                                forKey: PPDocumentNotification_UserInfoKey_UpdateAreaRect];

    [[NSNotificationCenter defaultCenter]
                                postNotificationName:
                                                PPDocumentNotification_UpdatedDrawingLayerArea
                                object: self
                                userInfo: userInfo];
}

- (void) postNotification_UpdatedMergedVisibleThumbnailImage
{
    if (_disallowThumbnailImageUpdateNotifications)
        return;

    [[NSNotificationCenter defaultCenter]
                                postNotificationName:
                                    PPDocumentNotification_UpdatedMergedVisibleThumbnailImage
                                object: self];
}

- (void) postNotification_UpdatedDrawingLayerThumbnailImage
{
    if (_disallowThumbnailImageUpdateNotifications)
        return;

    [[NSNotificationCenter defaultCenter]
                                postNotificationName:
                                    PPDocumentNotification_UpdatedDrawingLayerThumbnailImage
                                object: self];
}

- (void) postNotification_UpdatedSelection
{
    [[NSNotificationCenter defaultCenter]
                                postNotificationName: PPDocumentNotification_UpdatedSelection
                                object: self];
}

- (void) postNotification_SwitchedDrawingLayer
{
    [[NSNotificationCenter defaultCenter]
                                postNotificationName:
                                                PPDocumentNotification_SwitchedDrawingLayer
                                object: self];
}

- (void) postNotification_ReorderedLayers
{
    [[NSNotificationCenter defaultCenter]
                                postNotificationName: PPDocumentNotification_ReorderedLayers
                                object: self];
}

- (void) postNotification_PerformedMultilayerOperation
{
    [[NSNotificationCenter defaultCenter]
                                postNotificationName:
                                        PPDocumentNotification_PerformedMultilayerOperation
                                object: self];
}

- (void) postNotification_ChangedAttributeOfLayerAtIndex: (int) layerIndex
{
    NSDictionary *userInfo;

    userInfo = [NSDictionary dictionaryWithObject: [NSNumber numberWithInt: layerIndex]
                                forKey: PPDocumentNotification_UserInfoKey_IndexOfChangedLayer];

    [[NSNotificationCenter defaultCenter]
                                postNotificationName:
                                                PPDocumentNotification_ChangedLayerAttribute
                                object: self
                                userInfo: userInfo];
}

- (void) postNotification_SwitchedLayerOperationTarget
{
    [[NSNotificationCenter defaultCenter]
                                postNotificationName:
                                            PPDocumentNotification_SwitchedLayerOperationTarget
                                object: self];
}

- (void) postNotification_SwitchedLayerBlendingMode
{
    [[NSNotificationCenter defaultCenter]
                                postNotificationName:
                                            PPDocumentNotification_SwitchedLayerBlendingMode
                                object: self];
}

- (void) postNotification_SwitchedSelectedTool
{
    [[NSNotificationCenter defaultCenter]
                                postNotificationName:
                                                PPDocumentNotification_SwitchedSelectedTool
                                object: self];
}

- (void) postNotification_SwitchedActiveTool
{
    [[NSNotificationCenter defaultCenter]
                                postNotificationName: PPDocumentNotification_SwitchedActiveTool
                                object: self];
}

- (void) postNotification_ChangedFillColor
{
    [[NSNotificationCenter defaultCenter]
                                postNotificationName: PPDocumentNotification_ChangedFillColor
                                object: self];
}

- (void) postNotification_UpdatedBackgroundSettings
{
    [[NSNotificationCenter defaultCenter]
                                postNotificationName:
                                            PPDocumentNotification_UpdatedBackgroundSettings
                                object: self];
}

- (void) postNotification_UpdatedGridSettings
{
    [[NSNotificationCenter defaultCenter]
                                postNotificationName:
                                                PPDocumentNotification_UpdatedGridSettings
                                object: self];
}

- (void) postNotification_ReloadedDocument
{
    [[NSNotificationCenter defaultCenter]
                                postNotificationName: PPDocumentNotification_ReloadedDocument
                                object: self];
}

- (void) postNotification_UpdatedSamplerImages
{
    [[NSNotificationCenter defaultCenter]
                                postNotificationName:
                                                PPDocumentNotification_UpdatedSamplerImages
                                object: self];
}

- (void) postNotification_SwitchedActiveSamplerImageForPanelType:
                                                        (PPSamplerImagePanelType) panelType
{
    NSDictionary *userInfo;

    userInfo =
            [NSDictionary dictionaryWithObject: [NSNumber numberWithInt: panelType]
                            forKey: PPDocumentNotification_UserInfoKey_SamplerImagePanelType];

    [[NSNotificationCenter defaultCenter]
                                postNotificationName:
                                            PPDocumentNotification_SwitchedActiveSamplerImage
                                object: self
                                userInfo: userInfo];
}

@end
