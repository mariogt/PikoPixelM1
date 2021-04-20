/*
    PPDocumentLayer.h

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

#import <Cocoa/Cocoa.h>


@interface PPDocumentLayer : NSObject <NSCoding, NSCopying>
{
    id _delegate;

    NSString *_name;
    NSBitmapImageRep *_bitmap;
    NSImage *_image;

    NSSize _size;

    float _opacity;
    float _lastOpacity;

    NSBitmapImageRep *_linearBlendingBitmap;

    bool _isEnabled;
}

+ layerWithSize: (NSSize) size
        andName: (NSString *) name;

+ layerWithSize: (NSSize) size
        name: (NSString *) name
        tiffData: (NSData *) tiffData;

- initWithSize: (NSSize) size
    name: (NSString *) name
    tiffData: (NSData *) tiffData
    opacity: (float) opacity
    isEnabled: (bool) isEnabled;

- (NSBitmapImageRep *) bitmap;
- (NSImage *) image;

- (void) handleUpdateToBitmapInRect: (NSRect) updateRect;

- (bool) isEnabled;
- (void) setEnabled: (bool) enabled;

- (NSString *) name;
- (void) setName: (NSString *) name;

- (float) opacity;
- (void) setOpacity: (float) opacity;
- (void) setOpacityWithoutRegisteringUndo: (float) opacity;

- (void) increaseOpacity;
- (bool) canIncreaseOpacity;

- (void) decreaseOpacity;
- (bool) canDecreaseOpacity;

- (NSSize) size;

- (PPDocumentLayer *) layerResizedToSize: (NSSize) newSize shouldScale: (bool) shouldScale;

- (PPDocumentLayer *) layerCroppedToBounds: (NSRect) croppingBounds;

- (bool) enableLinearBlendingBitmap: (bool) enableLinearBlendingBitmap;
- (NSBitmapImageRep *) linearBlendingBitmap;

- (id) delegate;
- (void) setDelegate: (id) delegate;

@end

@interface NSObject (PPDocumentLayerDelegateMethods)

- (void) layer: (PPDocumentLayer *) layer
            changedNameFromOldValue: (NSString *) oldName;

- (void) layer: (PPDocumentLayer *) layer
            changedEnabledFlagFromOldValue: (bool) oldEnabledFlag;

- (void) layer: (PPDocumentLayer *) layer
            changedOpacityFromOldValue: (float) oldOpacity
            shouldRegisterUndo: (bool) shouldRegisterUndo;

@end
