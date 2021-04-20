/*
    PPLayerControlButtonImagesManager.h

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

#import <Cocoa/Cocoa.h>
#import "PPDocumentTypes.h"
#import "PPLayerDisplayMode.h"


@class PPDocument, PPCompositeThumbnail;

@interface PPLayerControlButtonImagesManager : NSObject
{
    IBOutlet NSView *_displayModeDrawLayerView;
    IBOutlet NSView *_displayModeDrawLayerThumbnailView;

    IBOutlet NSView *_displayModeEnabledLayersView;
    IBOutlet NSView *_displayModeEnabledLayersThumbnailView;

    IBOutlet NSView *_operationTargetDrawLayerView;
    IBOutlet NSView *_operationTargetDrawLayerThumbnailView;

    IBOutlet NSView *_operationTargetEnabledLayersView;
    IBOutlet NSView *_operationTargetEnabledLayersThumbnailView;

    PPDocument *_ppDocument;

    NSSize _thumbnailFramesize;
    NSRect _thumbnailDrawSourceBounds;
    NSRect _thumbnailDrawDestinationBounds;
    NSImageInterpolation _thumbnailInterpolation;

    NSBitmapImageRep *_thumbnailBackgroundBitmap;
    NSBitmapImageRep *_drawLayerThumbnailBitmap;
    NSBitmapImageRep *_enabledLayersThumbnailBitmap;

    PPCompositeThumbnail *_displayModeDrawLayerCompositeThumbnail;
    PPCompositeThumbnail *_displayModeEnabledLayersCompositeThumbnail;
    PPCompositeThumbnail *_operationTargetDrawLayerCompositeThumbnail;
    PPCompositeThumbnail *_operationTargetEnabledLayersCompositeThumbnail;

    bool _thumbnailBackgroundBitmapIsDirty;
    bool _enabledLayersThumbnailsAreDirty;
    bool _drawLayerThumbnailsAreDirty;
}

+ sharedManager;

- (void) setPPDocument: (PPDocument *) ppDocument;

- (NSImage *) buttonImageForDisplayMode: (PPLayerDisplayMode) displayMode;
- (NSImage *) buttonImageForOperationTarget: (PPLayerOperationTarget) operationTarget;

@end

extern NSString *PPLayerControlButtonImagesManagerNotification_ChangedDrawLayerImages;
extern NSString *PPLayerControlButtonImagesManagerNotification_ChangedEnabledLayersImages;

