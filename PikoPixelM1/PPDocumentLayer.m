/*
    PPDocumentLayer.m

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

#import "PPDocumentLayer.h"

#import "NSImage_PPUtilities.h"
#import "NSBitmapImageRep_PPUtilities.h"
#import "PPGeometry.h"
#import "PPDefines.h"


#define kDrawingLayerCodingKey_Size         @"Size"
#define kDrawingLayerCodingKey_Name         @"Name"
#define kDrawingLayerCodingKey_TIFFData     @"TIFFData"
#define kDrawingLayerCodingKey_Opacity      @"Opacity"
#define kDrawingLayerCodingKey_IsEnabled    @"IsEnabled"

#define kOpacityStepSize                    0.1f


@interface PPDocumentLayer (PrivateMethods)

- (void) setOpacity: (float) opacity andRegisterUndo: (bool) shouldRegisterUndo;

- (void) notifyDelegateDidChangeNameFromOldValue: (NSString *) oldName;
- (void) notifyDelegateDidChangeEnabledFlagFromOldValue: (bool) oldEnabledFlag;
- (void) notifyDelegateDidChangeOpacityAndShouldRegisterUndo: (bool) shouldRegisterUndo;

@end

@implementation PPDocumentLayer

+ layerWithSize: (NSSize) size
        andName: (NSString *) name
{
    return [[[self alloc] initWithSize: size
                            name: name
                            tiffData: nil
                            opacity: 1.0f
                            isEnabled: YES]
                    autorelease];
}

+ layerWithSize: (NSSize) size
        name: (NSString *) name
        tiffData: (NSData *) tiffData
{
    return [[[self alloc] initWithSize: size
                            name: name
                            tiffData: tiffData
                            opacity: 1.0f
                            isEnabled: YES]
                    autorelease];
}

- initWithSize: (NSSize) size
    name: (NSString *) name
    tiffData: (NSData *) tiffData
    opacity: (float) opacity
    isEnabled: (bool) isEnabled
{
    self = [super init];

    if (!self)
        goto ERROR;

    if (![name length])
    {
        goto ERROR;
    }

    size = PPGeometry_SizeClippedToIntegerValues(size);

    if ((size.width < kMinCanvasDimension)
        || (size.width > kMaxCanvasDimension)
        || (size.height < kMinCanvasDimension)
        || (size.height > kMaxCanvasDimension))
    {
        goto ERROR;
    }

    _size = size;

    _name = [name copy];
    _bitmap = [[NSBitmapImageRep ppImageBitmapOfSize: size] retain];
    _image = [[NSImage ppImageWithBitmap: _bitmap] retain];

    if (!_name || !_bitmap || !_image)
    {
        goto ERROR;
    }

    if (tiffData)
    {
        [_bitmap ppCenteredCopyFromBitmap:
                                [NSBitmapImageRep ppImageBitmapWithImportedData: tiffData]];
    }

    if (opacity > 1.0f)
    {
        opacity = 1.0f;
    }
    else if (opacity < 0.0f)
    {
        opacity = 0.0f;
    }

    _opacity = _lastOpacity = opacity;
    _isEnabled = (isEnabled) ? YES : NO;

    return self;

ERROR:
    [self release];

    return nil;
}

- init
{
    return [self initWithSize: NSZeroSize name: nil tiffData: nil opacity: 1.0f isEnabled: YES];
}

- (void) dealloc
{
    [_name release];
    [_bitmap release];
    [_image release];

    [_linearBlendingBitmap release];

    [super dealloc];
}

- (NSBitmapImageRep *) bitmap
{
    return _bitmap;
}

- (NSImage *) image
{
    return _image;
}

// handleUpdateToBitmapInRect: method is a patch target on GNUstep
// (PPGNUstepGlue_ImageRecacheSpeedups)

- (void) handleUpdateToBitmapInRect: (NSRect) updateRect
{
    [_image recache];

    if (_linearBlendingBitmap)
    {
        [_linearBlendingBitmap ppLinearCopyFromImageBitmap: _bitmap inBounds: updateRect];
    }
}

- (bool) isEnabled
{
    return _isEnabled;
}

- (void) setEnabled: (bool) enabled
{
    if (enabled == _isEnabled)
    {
        return;
    }

    _isEnabled = (enabled) ? YES : NO;

    [self notifyDelegateDidChangeEnabledFlagFromOldValue: enabled ? NO : YES];
}

- (NSString *) name
{
    return _name;
}

- (void) setName: (NSString *) name
{
    NSString *oldName;

    name = [[name copy] autorelease];

    if (!name)
    {
        name = @"";
    }

    if ((_name == name) || [_name isEqualToString: name])
    {
        return;
    }

    oldName = [[_name retain] autorelease];

    [_name release];
    _name = [name retain];

    [self notifyDelegateDidChangeNameFromOldValue: oldName];
}

- (float) opacity
{
    return _opacity;
}

- (void) setOpacity: (float) opacity
{
    [self setOpacity: opacity andRegisterUndo: YES];
}

- (void) setOpacityWithoutRegisteringUndo: (float) opacity
{
    [self setOpacity: opacity andRegisterUndo: NO];
}

- (void) increaseOpacity
{
    if (![self canIncreaseOpacity])
    {
        return;
    }

    [self setOpacity: _opacity + kOpacityStepSize];
}

- (bool) canIncreaseOpacity
{
    return (_opacity < 1.0f) ? YES : NO;
}

- (void) decreaseOpacity
{
    if (![self canDecreaseOpacity])
    {
        return;
    }

    [self setOpacity: _opacity - kOpacityStepSize];
}

- (bool) canDecreaseOpacity
{
    return (_opacity > 0.0f) ? YES : NO;
}

- (NSSize) size
{
    return _size;
}

- (PPDocumentLayer *) layerResizedToSize: (NSSize) newSize shouldScale: (bool) shouldScale
{
    NSBitmapImageRep *resizedBitmap;
    NSData *resizedBitmapData;
    PPDocumentLayer *resizedLayer;

    newSize = PPGeometry_SizeClippedToIntegerValues(newSize);

    resizedBitmap = [_bitmap ppBitmapResizedToSize: newSize shouldScale: shouldScale];

    if (!resizedBitmap)
        goto ERROR;

    resizedBitmapData = [resizedBitmap TIFFRepresentation];

    if (!resizedBitmapData)
        goto ERROR;

    resizedLayer = [[[PPDocumentLayer alloc] initWithSize: newSize
                                                name: _name
                                                tiffData: resizedBitmapData
                                                opacity: _opacity
                                                isEnabled: _isEnabled]
                                        autorelease];

    return resizedLayer;

ERROR:
    return nil;
}

- (PPDocumentLayer *) layerCroppedToBounds: (NSRect) croppingBounds
{
    NSData *croppedBitmapTIFFData;
    PPDocumentLayer *croppedLayer;

    croppingBounds = NSIntersectionRect(PPGeometry_PixelBoundsCoveredByRect(croppingBounds),
                                        [_bitmap ppFrameInPixels]);

    if (NSIsEmptyRect(croppingBounds))
    {
        goto ERROR;
    }

    croppedBitmapTIFFData = [_bitmap ppCompressedTIFFDataFromBounds: croppingBounds];

    if (!croppedBitmapTIFFData)
        goto ERROR;

    croppedLayer = [[[PPDocumentLayer alloc] initWithSize: croppingBounds.size
                                                name: _name
                                                tiffData: croppedBitmapTIFFData
                                                opacity: _opacity
                                                isEnabled: _isEnabled]
                                        autorelease];

    return croppedLayer;

ERROR:
    return nil;
}

- (bool) enableLinearBlendingBitmap: (bool) enableLinearBlendingBitmap
{
    if (enableLinearBlendingBitmap)
    {
        if (!_linearBlendingBitmap)
        {
            _linearBlendingBitmap = [[_bitmap ppLinearRGB16BitmapFromImageBitmap] retain];
        }

        return (_linearBlendingBitmap) ? YES : NO;
    }
    else    // (!enableLinearBlendingBitmap)
    {
        if (_linearBlendingBitmap)
        {
            [_linearBlendingBitmap release];
            _linearBlendingBitmap = nil;
        }

        return YES;
    }
}

- (NSBitmapImageRep *) linearBlendingBitmap
{
    return _linearBlendingBitmap;
}

- (id) delegate
{
    return _delegate;
}

- (void) setDelegate: (id) delegate
{
    _delegate = delegate;
}

#pragma mark NSCoding protocol

- (id) initWithCoder: (NSCoder *) aDecoder
{
    return [self initWithSize: [aDecoder decodeSizeForKey: kDrawingLayerCodingKey_Size]
                    name: [aDecoder decodeObjectForKey: kDrawingLayerCodingKey_Name]
                    tiffData: [aDecoder decodeObjectForKey: kDrawingLayerCodingKey_TIFFData]
                    opacity: [aDecoder decodeFloatForKey: kDrawingLayerCodingKey_Opacity]
                    isEnabled: [aDecoder decodeBoolForKey: kDrawingLayerCodingKey_IsEnabled]];
}

- (void) encodeWithCoder: (NSCoder *) coder
{
    [coder encodeSize: _size forKey: kDrawingLayerCodingKey_Size];
    [coder encodeObject: _name forKey: kDrawingLayerCodingKey_Name];

    [coder encodeObject: [_bitmap ppCompressedTIFFData]
            forKey: kDrawingLayerCodingKey_TIFFData];

    [coder encodeFloat: _opacity forKey: kDrawingLayerCodingKey_Opacity];
    [coder encodeBool: _isEnabled forKey: kDrawingLayerCodingKey_IsEnabled];
}

#pragma mark NSCopying protocol

- (id) copyWithZone: (NSZone *) zone
{
    PPDocumentLayer *layerCopy;
    bool needToCopyLayerBitmapData = YES;

    layerCopy = [[[self class] allocWithZone: zone] initWithSize: _size
                                                    name: _name
                                                    tiffData: nil
                                                    opacity: _opacity
                                                    isEnabled: _isEnabled];

    if (!layerCopy)
        goto ERROR;

    layerCopy->_delegate = _delegate;

    if (zone && (zone != NSDefaultMallocZone()))
    {
        if ([layerCopy->_name zone] != zone)
        {
            NSString *zonedName = [[_name copyWithZone: zone] autorelease];

            if (zonedName)
            {
                [layerCopy->_name release];
                layerCopy->_name = [zonedName retain];
            }
        }

        if (([layerCopy->_bitmap zone] != zone)
            || ([layerCopy->_image zone] != zone))
        {
            NSBitmapImageRep *zonedBitmap = [[_bitmap copyWithZone: zone] autorelease];
            NSImage *zonedImage =
                            [[[NSImage allocWithZone: zone] initWithSize: _size] autorelease];

            if (zonedBitmap && zonedImage)
            {
                [zonedImage addRepresentation: zonedBitmap];

                [layerCopy->_bitmap release];
                layerCopy->_bitmap = [zonedBitmap retain];

                [layerCopy->_image release];
                layerCopy->_image = [zonedImage retain];

                needToCopyLayerBitmapData = NO;
            }
        }
    }

    if (needToCopyLayerBitmapData)
    {
        [layerCopy->_bitmap ppCopyFromBitmap: _bitmap toPoint: NSZeroPoint];
        [layerCopy handleUpdateToBitmapInRect: PPGeometry_OriginRectOfSize(_size)];
    }

    // Don't need to enable _linearBlendingBitmap in the copy - the linear bitmap will be
    // enabled automatically if the copy's added to a PPDocument that's in linear blending mode,
    // otherwise, the linear bitmap's currently unused in unattached layers.

    return layerCopy;

ERROR:
    return nil;
}

#pragma mark Private methods

- (void) setOpacity: (float) opacity andRegisterUndo: (bool) shouldRegisterUndo
{
    if (opacity > 1.0f)
    {
        opacity = 1.0f;
    }
    else if (opacity < 0.0f)
    {
        opacity = 0.0f;
    }

    if (!shouldRegisterUndo && (_opacity == opacity))
    {
        return;
    }

    _opacity = opacity;

    [self notifyDelegateDidChangeOpacityAndShouldRegisterUndo: shouldRegisterUndo];

    if (shouldRegisterUndo)
    {
        _lastOpacity = _opacity;
    }
}

#pragma mark Delegate notifiers

- (void) notifyDelegateDidChangeNameFromOldValue: (NSString *) oldName
{
    if ([_delegate respondsToSelector: @selector(layer:changedNameFromOldValue:)])
    {
        [_delegate layer: self changedNameFromOldValue: oldName];
    }
}

- (void) notifyDelegateDidChangeEnabledFlagFromOldValue: (bool) oldEnabledFlag
{
    if ([_delegate respondsToSelector: @selector(layer:changedEnabledFlagFromOldValue:)])
    {
        [_delegate layer: self changedEnabledFlagFromOldValue: oldEnabledFlag];
    }
}

- (void) notifyDelegateDidChangeOpacityAndShouldRegisterUndo: (bool) shouldRegisterUndo
{
    if ([_delegate respondsToSelector: @selector(layer:changedOpacityFromOldValue:
                                                    shouldRegisterUndo:)])
    {
        [_delegate layer: self
                    changedOpacityFromOldValue: _lastOpacity
                    shouldRegisterUndo: shouldRegisterUndo];
    }
}

@end
