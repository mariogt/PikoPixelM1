/*
    PPDocument_Layers.m

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

#import "PPDocument_Notifications.h"
#import "PPDocumentLayer.h"
#import "PPGeometry.h"
#import "NSImage_PPUtilities.h"
#import "NSBitmapImageRep_PPUtilities.h"
#import "PPAppBootUtilities.h"


static NSObject *gEmptyImageObject = nil;
static NSBitmapImageRep *gEmptyBitmap = nil;


@interface PPDocument (LayersPrivateMethods)

- (bool) hasLayerAtIndex: (int) index;
- (bool) isValidLayerInsertionIndex: (int) index;
- (int) indexOfLayer: (PPDocumentLayer *) layer;

- (bool) setupLayerForCurrentBlendingMode: (PPDocumentLayer *) layer;
- (bool) setupAllLayersForCurrentBlendingMode;

- (void) invalidateAllRelativeCachedLayerImagesForIndex: (int) index;
- (void) invalidateCachedLayerImagesAtIndex: (int) index;
- (void) invalidateImageObjectsInCache: (NSObject **) cachedImageObjectsArray
            fromIndex: (int) startIndex
            toIndex: (int) endIndex;
- (void) removeAllCachedLayersImages;

- (NSObject *) cachedOverlayersImageObjectForIndex: (int) index;
- (NSObject *) cachedUnderlayersImageObjectForIndex: (int) index;

- (NSObject *) mergedLayersImageObjectFromIndex: (int) firstIndex
                toIndex: (int) lastIndex;

- (NSBitmapImageRep *) mergedLayersBitmapFromIndex: (int) firstIndex
                        toIndex: (int) lastIndex;

- (void) updateMergedVisibleLayersBitmapInRect: (NSRect) rect
            indexOfUpdatedLayer: (int) indexOfUpdatedLayer;

- (NSString *) uniqueLayerNameWithRoot: (NSString *) rootName;
- (NSString *) duplicateNameForLayerName: (NSString *) layerName;

- (void) setupDrawingLayerWithLayerAtIndex: (int) newDrawingLayerIndex
            andPostNotification: (bool) shouldPostNotification;

- (void) setupDrawingLayerWithLayerAtIndex: (int) newDrawingLayerIndex;

- (void) setupDrawingLayerMembers;

- (void) mergeDrawingLayerWithNextLayerInDirection: (PPDirectionType) directionType;

- (bool) handleUpdateToLayer: (PPDocumentLayer *) layer;
- (void) handleUpdateToDrawingLayerInRect: (NSRect) updateRect;

- (void) updateDissolvedDrawingLayerBitmapInRect: (NSRect) updateRect;

- (void) insertArchivedLayer: (NSData *) archivedLayer
            atIndex: (int) index
            andSetAsDrawingLayer: (bool) shouldSetAsDrawingLayer;

- (bool) setLayersWithArchivedLayersData: (NSData *) archivedLayersData;

- (void) setName: (NSString *) name forLayerAtIndex: (int) index;
- (void) setEnabledFlag: (bool) isEnabled forLayerAtIndex: (int) index;
- (void) setOpacity: (float) opacity forLayerAtIndex: (int) index;

- (void) copyTIFFData: (NSData *) tiffData
            toLayerAtIndex: (int) index
            atPoint: (NSPoint) origin;

- (void) recacheMergedVisibleLayersThumbnailImageInBounds: (NSRect) bounds;
- (void) recacheDissolvedDrawingLayerThumbnailImageInBounds: (NSRect) bounds;

@end

@implementation NSObject (PPDocument_Layers)

+ (void) ppDocument_Layers_SetupGlobals
{
    gEmptyImageObject = [[NSNull null] retain];

    gEmptyBitmap = [[NSBitmapImageRep ppMaskBitmapOfSize: NSMakeSize(1,1)] retain];
}

+ (void) load
{
    macroPerformNSObjectSelectorAfterAppLoads(ppDocument_Layers_SetupGlobals);
}

@end

@implementation PPDocument (Layers)

- (int) numLayers
{
    return _numLayers;
}

- (PPDocumentLayer *) layerAtIndex: (int) index
{
    if (![self hasLayerAtIndex: index])
    {
        return nil;
    }

    return (PPDocumentLayer *) [_layers objectAtIndex: index];
}

- (void) createNewLayer
{
    NSString *newLayerName;
    PPDocumentLayer *newLayer;
    int insertionIndex;

    if (!_numLayers)
    {
        newLayerName = @"Main Layer";
        insertionIndex = 0;
    }
    else
    {
        newLayerName = [self uniqueLayerNameWithRoot: @"New Layer"];
        insertionIndex = _indexOfDrawingLayer + 1;
    }

    newLayer = [PPDocumentLayer layerWithSize: _canvasFrame.size andName: newLayerName];

    if (!newLayer)
        goto ERROR;

    [self insertLayer: newLayer atIndex: insertionIndex andSetAsDrawingLayer: YES];

    [[self undoManager] setActionName: NSLocalizedString(@"Add Layer", nil)];

    return;

ERROR:
    return;
}

- (void) insertLayer: (PPDocumentLayer *) layer
            atIndex: (int) index
            andSetAsDrawingLayer: (bool) shouldSetAsDrawingLayer
{
    int oldDrawingLayerIndex;
    NSUndoManager *undoManager;

    if (!layer || ![self isValidLayerInsertionIndex: index])
    {
        return;
    }

    // manually invalidate relevant cached images that won't be invalidated later by
    // invalidateAllRelativeCachedLayerImagesForIndex: (called by handleUpdateToLayerAtIndex:)

    [self invalidateImageObjectsInCache: _cachedOverlayersImageObjects
            fromIndex: index
            toIndex: _numLayers - 1];

    [layer setDelegate: self];

    [self setupLayerForCurrentBlendingMode: layer];

    [_layers insertObject: layer atIndex: index];
    _numLayers = [_layers count];

    oldDrawingLayerIndex = _indexOfDrawingLayer;

    if (shouldSetAsDrawingLayer)
    {
        [self setupDrawingLayerWithLayerAtIndex: index andPostNotification: NO];
    }
    else if (_indexOfDrawingLayer >= index)
    {
        _indexOfDrawingLayer++;
    }

    [self handleUpdateToLayerAtIndex: index inRect: _canvasFrame];

    undoManager = [self undoManager];

    if (shouldSetAsDrawingLayer)
    {
        [[undoManager prepareWithInvocationTarget: self]
                                    setupDrawingLayerWithLayerAtIndex: oldDrawingLayerIndex];
    }

    [[undoManager prepareWithInvocationTarget: self] removeLayerAtIndex: index];

    if (![undoManager isUndoing] && ![undoManager isRedoing])
    {
        [undoManager setActionName: NSLocalizedString(@"Insert Layer", nil)];
    }

    [self postNotification_ReorderedLayers];
}

- (void) removeLayerAtIndex: (int) index
{
    int topLayerIndex;
    PPDocumentLayer *layer;
    NSData *archivedLayer = nil;
    bool needToSetDrawingLayer = NO;
    NSUndoManager *undoManager;

    if (![self hasLayerAtIndex: index])
    {
        return;
    }

    // manually invalidate relevant cached images that won't be invalidated later by
    // invalidateAllRelativeCachedLayerImagesForIndex: (called by handleUpdateToLayerAtIndex:)

    topLayerIndex = _numLayers - 1;
    [self invalidateCachedLayerImagesAtIndex: topLayerIndex];
    [self invalidateImageObjectsInCache: _cachedOverlayersImageObjects
            fromIndex: index
            toIndex: topLayerIndex];

    layer = [_layers objectAtIndex: index];
    [layer setDelegate: nil];

    archivedLayer = [NSKeyedArchiver archivedDataWithRootObject: layer];

    [_layers removeObjectAtIndex: index];
    _numLayers = [_layers count];

    if (index == _indexOfDrawingLayer)
    {
        needToSetDrawingLayer = YES;
    }

    undoManager = [self undoManager];

    // need to register insertArchivedLayer:... undo invocation before the call to
    // createNewLayer, because createNewLayer registers an undo invocation for
    // removeLayerAtIndex: (which might cause layer ordering & draw layer index issues on
    // undo if the old removed layer is inserted before the newly-created layer is removed)

    [[undoManager prepareWithInvocationTarget: self]
                                                insertArchivedLayer: archivedLayer
                                                atIndex: index
                                                andSetAsDrawingLayer: needToSetDrawingLayer];

    if (!_numLayers)
    {
        if (![undoManager isUndoing] && ![undoManager isRedoing])
        {
            [self createNewLayer];
        }
    }
    else if (needToSetDrawingLayer)
    {
        index = _indexOfDrawingLayer;

        if (index > 0)
        {
            index--;

            [self invalidateImageObjectsInCache: _cachedOverlayersImageObjects
                    fromIndex: index
                    toIndex: index];
        }

        [self setupDrawingLayerWithLayerAtIndex: index andPostNotification: NO];
    }
    else if (_indexOfDrawingLayer > index)
    {
        _indexOfDrawingLayer--;
    }

    if (index >= _numLayers)
    {
        index--;
    }

    [self handleUpdateToLayerAtIndex: index inRect: _canvasFrame];

    if (![undoManager isUndoing] && ![undoManager isRedoing])
    {
        [undoManager setActionName: NSLocalizedString(@"Delete Layer", nil)];
    }

    [self postNotification_ReorderedLayers];
}

- (void) moveLayerAtIndex: (int) oldIndex
            toIndex: (int) newIndex
{
    PPDocumentLayer *layer;
    NSUndoManager *undoManager;

    if (![self hasLayerAtIndex: oldIndex]
        || ![self hasLayerAtIndex: newIndex]
        || (oldIndex == newIndex))
    {
        return;
    }

    // manually invalidate relevant cached images that won't be invalidated later by
    // invalidateAllRelativeCachedLayerImagesForIndex: (called by
    // handleUpdateToLayerAtIndex: newIndex)

    if (oldIndex < newIndex)
    {
        [self invalidateImageObjectsInCache: _cachedUnderlayersImageObjects
                fromIndex: oldIndex + 1
                toIndex: newIndex];
    }
    else
    {
        [self invalidateImageObjectsInCache: _cachedOverlayersImageObjects
                fromIndex: newIndex
                toIndex: oldIndex - 1];
    }

    layer = [[[_layers objectAtIndex: oldIndex] retain] autorelease];

    [_layers removeObjectAtIndex: oldIndex];
    [_layers insertObject: layer atIndex: newIndex];

    _indexOfDrawingLayer = [_layers indexOfObject: _drawingLayer];

    undoManager = [self undoManager];
    [[undoManager prepareWithInvocationTarget: self] moveLayerAtIndex: newIndex
                                                                toIndex: oldIndex];

    if (![undoManager isUndoing] && ![undoManager isRedoing])
    {
        [undoManager setActionName: NSLocalizedString(@"Reorder Layers", nil)];
    }

    [self handleUpdateToLayerAtIndex: newIndex inRect: _canvasFrame];

    [self postNotification_ReorderedLayers];
}

- (void) duplicateLayerAtIndex: (int) index
{
    PPDocumentLayer *dupeLayer;
    NSString *dupeLayerName;

    if (![self hasLayerAtIndex: index])
    {
        return;
    }

    dupeLayer = [[[_layers objectAtIndex: index] copy] autorelease];

    if (!dupeLayer)
        goto ERROR;

    dupeLayerName = [self duplicateNameForLayerName: [dupeLayer name]];

    [dupeLayer setName: dupeLayerName];

    [self insertLayer: dupeLayer atIndex: index + 1 andSetAsDrawingLayer: YES];

    [[self undoManager] setActionName: NSLocalizedString(@"Duplicate Layer", nil)];

    return;

ERROR:
    return;
}

- (void) removeAllLayers
{
    [self removeAllCachedLayersImages];

    [_layers makeObjectsPerformSelector: @selector(setDelegate:) withObject: nil];
    [_layers removeAllObjects];

    _numLayers = 0;
    _indexOfDrawingLayer = -1;

    [self setupDrawingLayerMembers];
}

- (void) removeNontargetLayers
{
    NSMutableArray *targetLayers;
    int i;
    NSBitmapImageRep *selectionMask = nil;

    targetLayers = [NSMutableArray array];

    if (!targetLayers)
        goto ERROR;

    [self setupTargetLayerIndexesForOperationTarget: _layerOperationTarget];

    // don't allow all layers to be removed (must be at least one target layer remaining)
    if (!_numTargetLayerIndexes)
        goto ERROR;

    for (i=0; i<_numTargetLayerIndexes; i++)
    {
        [targetLayers addObject: [_layers objectAtIndex: _targetLayerIndexes[i]]];
    }

    if (_hasSelection)
    {
        selectionMask = [[_selectionMask copy] autorelease];
    }

    [self setLayers: targetLayers];

    if (selectionMask)
    {
        [self setSelectionMask: selectionMask];
    }

    [[self undoManager] setActionName: NSLocalizedString(@"Remove Nontarget Layers", nil)];

    return;

ERROR:
    return;
}

- (bool) setLayers: (NSArray *) newLayers
{
    NSData *archivedOldLayers;
    unsigned oldIndexOfDrawingLayer, newIndexOfDrawingLayer;
    NSUndoManager *undoManager;

    if (!newLayers || ![newLayers count])
    {
        goto ERROR;
    }

    // use copies of the new layers, not the originals
    newLayers = [[[NSArray alloc] initWithArray: newLayers copyItems: YES] autorelease];

    if (!newLayers)
        goto ERROR;

    archivedOldLayers = [NSKeyedArchiver archivedDataWithRootObject: _layers];
    oldIndexOfDrawingLayer = _indexOfDrawingLayer;

    if (_hasSelection)
    {
        [self deselectAll]; // stores old selection in undo stack
    }

    [self removeAllLayers];

    [_layers setArray: newLayers];

    [_layers makeObjectsPerformSelector: @selector(setDelegate:) withObject: self];

    _numLayers = [_layers count];

    if (![self resizeCanvasForCurrentLayers])
    {
        goto ERROR;
    }

    [self setupAllLayersForCurrentBlendingMode];

    newIndexOfDrawingLayer = oldIndexOfDrawingLayer;

    if (![self hasLayerAtIndex: newIndexOfDrawingLayer])
    {
        newIndexOfDrawingLayer = 0;
    }

    [self setupDrawingLayerWithLayerAtIndex: newIndexOfDrawingLayer andPostNotification: NO];

    [self handleUpdateToLayerAtIndex: _indexOfDrawingLayer inRect: _canvasFrame];

    undoManager = [self undoManager];

    [[undoManager prepareWithInvocationTarget: self]
                                    setupDrawingLayerWithLayerAtIndex: oldIndexOfDrawingLayer];

    [[undoManager prepareWithInvocationTarget: self]
                                    setLayersWithArchivedLayersData: archivedOldLayers];

    [self postNotification_ReloadedDocument];

    return YES;

ERROR:
    return NO;
}

- (void) selectDrawingLayerAtIndex: (int) newDrawingLayerIndex
{
    int oldIndexOfDrawingLayer;
    NSUndoManager *undoManager;

    if (![self hasLayerAtIndex: newDrawingLayerIndex]
        || (newDrawingLayerIndex == _indexOfDrawingLayer))
    {
        return;
    }

    oldIndexOfDrawingLayer = _indexOfDrawingLayer;

    [self setupDrawingLayerWithLayerAtIndex: newDrawingLayerIndex];

    undoManager = [self undoManager];
    [[undoManager prepareWithInvocationTarget: self]
                                            selectDrawingLayerAtIndex: oldIndexOfDrawingLayer];

    if (![undoManager isUndoing] && ![undoManager isRedoing])
    {
        [undoManager setActionName: NSLocalizedString(@"Switch Drawing Layer", nil)];
    }
}

- (int) indexOfDrawingLayer
{
    return _indexOfDrawingLayer;
}

- (PPDocumentLayer *) drawingLayer
{
    return _drawingLayer;
}

- (void) beginMultilayerOperation
{
    _disallowUpdatesToMergedBitmap = YES;

    [[[self undoManager] prepareWithInvocationTarget: self] finishMultilayerOperation];
}

- (void) finishMultilayerOperation
{
    _disallowUpdatesToMergedBitmap = NO;

    [self removeAllCachedLayersImages];
    [self handleUpdateToLayerAtIndex: _indexOfDrawingLayer inRect: _canvasFrame];

    [[[self undoManager] prepareWithInvocationTarget: self] beginMultilayerOperation];

    [self postNotification_PerformedMultilayerOperation];
}

- (void) moveDrawingLayerUp
{
    if ((_indexOfDrawingLayer >= (_numLayers - 1)) || (_indexOfDrawingLayer < 0))
    {
        return;
    }

    [self moveLayerAtIndex: _indexOfDrawingLayer toIndex: _indexOfDrawingLayer+1];

    [[self undoManager] setActionName: NSLocalizedString(@"Move Layer Up", nil)];
}

- (void) moveDrawingLayerDown
{
    if (_indexOfDrawingLayer < 1)
    {
        return;
    }

    [self moveLayerAtIndex: _indexOfDrawingLayer toIndex: _indexOfDrawingLayer-1];

    [[self undoManager] setActionName: NSLocalizedString(@"Move Layer Down", nil)];
}

- (void) mergeDrawingLayerUp
{
    [self mergeDrawingLayerWithNextLayerInDirection: kPPDirectionType_Up];
}

- (void) mergeDrawingLayerDown
{
    [self mergeDrawingLayerWithNextLayerInDirection: kPPDirectionType_Down];
}

- (void) mergeAllLayers
{
    PPDocumentLayer *mergedLayer;
    NSBitmapImageRep *selectionMask = nil;

    mergedLayer = [[_drawingLayer copy] autorelease];

    if (!mergedLayer)
        goto ERROR;

    [[mergedLayer bitmap] ppCopyFromBitmap: _mergedVisibleLayersBitmap
                            toPoint: NSZeroPoint];

    [mergedLayer handleUpdateToBitmapInRect: _canvasFrame];

    [mergedLayer setOpacity: 1.0f];
    [mergedLayer setEnabled: YES];

    if (_hasSelection)
    {
        selectionMask = [[_selectionMask copy] autorelease];
    }

    [self setLayers: [NSArray arrayWithObject: mergedLayer]];

    if (selectionMask)
    {
        [self setSelectionMask: selectionMask];
    }

    [[self undoManager] setActionName: NSLocalizedString(@"Merge All Layers", nil)];

    return;

ERROR:
    return;
}

- (void) setEnabledFlagForAllLayers: (bool) isEnabled
{
    int i;

    isEnabled = (isEnabled) ? YES : NO;

    [self beginMultilayerOperation];

    for (i=0; i<_numLayers; i++)
    {
        [(PPDocumentLayer *) [_layers objectAtIndex: i] setEnabled: isEnabled];
    }

    [self finishMultilayerOperation];

    [[self undoManager]
                setActionName: (isEnabled) ? NSLocalizedString(@"Enable All Layers", nil) : NSLocalizedString(@"Disable All Layers", nil)];
}

- (PPLayerBlendingMode) layerBlendingMode
{
    return _layerBlendingMode;
}

- (void) setLayerBlendingMode: (PPLayerBlendingMode) layerBlendingMode
{
    PPLayerBlendingMode oldLayerBlendingMode;
    NSUndoManager *undoManager;

    if (!PPLayerBlendingMode_IsValid(layerBlendingMode)
        || (layerBlendingMode == _layerBlendingMode))
    {
        return;
    }

    [self removeAllCachedLayersImages];

    oldLayerBlendingMode = _layerBlendingMode;

    _layerBlendingMode = layerBlendingMode;

    if (![self setupAllLayersForCurrentBlendingMode]
        || ![self setupLayerBlendingBitmapOfSize: _canvasFrame.size])
    {
        // if setup fails (can only fail in Linear mode), recover by forcing to Standard mode

        _layerBlendingMode = kPPLayerBlendingMode_Standard;

        [self setupAllLayersForCurrentBlendingMode];
        [self setupLayerBlendingBitmapOfSize: _canvasFrame.size];
    }

    [self updateMergedVisibleLayersBitmapInRect: _canvasFrame
            indexOfUpdatedLayer: _indexOfDrawingLayer];

    undoManager = [self undoManager];
    [[undoManager prepareWithInvocationTarget: self] setLayerBlendingMode: oldLayerBlendingMode];

    if (![undoManager isUndoing] && ![undoManager isRedoing])
    {
        [undoManager setActionName: NSLocalizedString(@"Switch Layer Blending Mode", nil)];
    }

    [self postNotification_SwitchedLayerBlendingMode];

    [self postNotification_UpdatedMergedVisibleAreaInRect: _canvasFrame];

    if (!_disallowThumbnailImageUpdateNotifications)
    {
        [self postNotification_UpdatedMergedVisibleThumbnailImage];
    }
}

- (void) toggleLayerBlendingMode
{
    PPLayerBlendingMode newLayerBlendingMode = _layerBlendingMode + 1;

    if (!PPLayerBlendingMode_IsValid(newLayerBlendingMode))
    {
        newLayerBlendingMode = 0;
    }

    [self setLayerBlendingMode: newLayerBlendingMode];
}

- (bool) setupLayerBlendingBitmapOfSize: (NSSize) bitmapSize
{
    if (PPGeometry_IsZeroSize(bitmapSize))
    {
        goto ERROR;
    }

    if (_layerBlendingMode == kPPLayerBlendingMode_Linear)
    {
        if (!_mergedVisibleLayersLinearBitmap
            || !NSEqualSizes([_mergedVisibleLayersLinearBitmap ppSizeInPixels], bitmapSize))
        {
            NSBitmapImageRep *mergedVisibleLayersLinearBitmap =
                                    [NSBitmapImageRep ppLinearRGB16BitmapOfSize: bitmapSize];

            if (!mergedVisibleLayersLinearBitmap)
                goto ERROR;

            [_mergedVisibleLayersLinearBitmap release];
            _mergedVisibleLayersLinearBitmap = [mergedVisibleLayersLinearBitmap retain];
        }
        else
        {
            [_mergedVisibleLayersLinearBitmap ppClearBitmap];
        }
    }
    else    // kPPLayerBlendingMode_Standard: no linear bitmap needed
    {
        if (_mergedVisibleLayersLinearBitmap)
        {
            [_mergedVisibleLayersLinearBitmap release];
            _mergedVisibleLayersLinearBitmap = nil;
        }
    }

    return YES;

ERROR:
    return NO;
}

- (void) copyImageBitmap: (NSBitmapImageRep *) bitmap
            toLayerAtIndex: (int) index
            atPoint: (NSPoint) origin
{
    PPDocumentLayer *layer;
    NSSize bitmapSize;
    NSRect updateRect;
    NSBitmapImageRep *layerBitmap;
    NSData *undoBitmapTIFFData;

    if (index == _indexOfDrawingLayer)
    {
        [self copyImageBitmapToDrawingLayer: bitmap atPoint: origin];
        return;
    }

    if (![bitmap ppIsImageBitmap])
    {
        goto ERROR;
    }

    layer = [self layerAtIndex: index];

    if (!layer)
        goto ERROR;

    origin = PPGeometry_PointClippedToIntegerValues(origin);
    bitmapSize = [bitmap ppSizeInPixels];

    updateRect.origin = origin;
    updateRect.size = bitmapSize;

    updateRect = NSIntersectionRect(updateRect, _canvasFrame);

    if (NSIsEmptyRect(updateRect))
    {
        goto ERROR;
    }

    if (!NSEqualSizes(updateRect.size, bitmapSize))
    {
        NSRect croppingBounds;

        croppingBounds.origin = NSMakePoint(updateRect.origin.x - origin.x,
                                            updateRect.origin.y - origin.y);

        croppingBounds.size = updateRect.size;

        bitmap = [bitmap ppShallowDuplicateFromBounds: croppingBounds];

        if (!bitmap)
            goto ERROR;
    }

    layerBitmap = [layer bitmap];

    undoBitmapTIFFData = [layerBitmap ppCompressedTIFFDataFromBounds: updateRect];

    if (!undoBitmapTIFFData)
        goto ERROR;

    [layerBitmap ppCopyFromBitmap: bitmap toPoint: updateRect.origin];
    [layer handleUpdateToBitmapInRect: updateRect];

    [self handleUpdateToLayerAtIndex: index inRect: updateRect];

    [[[self undoManager] prepareWithInvocationTarget: self] copyTIFFData: undoBitmapTIFFData
                                                                toLayerAtIndex: index
                                                                atPoint: updateRect.origin];

    return;

ERROR:
    return;
}

- (void) handleUpdateToLayerAtIndex: (int) index inRect: (NSRect) updateRect
{
    if (![self hasLayerAtIndex: index] || _disallowUpdatesToMergedBitmap)
    {
        return;
    }

    updateRect = NSIntersectionRect(updateRect, _canvasFrame);

    if (NSIsEmptyRect(updateRect))
    {
        return;
    }

    [self invalidateAllRelativeCachedLayerImagesForIndex: index];

    [self updateMergedVisibleLayersBitmapInRect: updateRect
            indexOfUpdatedLayer: index];

    if (index == _indexOfDrawingLayer)
    {
        [self handleUpdateToDrawingLayerInRect: updateRect];
    }

    [self postNotification_UpdatedMergedVisibleAreaInRect: updateRect];

    if (!_disallowThumbnailImageUpdateNotifications)
    {
        [self postNotification_UpdatedMergedVisibleThumbnailImage];
    }
}

#pragma mark PPDocumentLayer delegate methods

- (void) layer: (PPDocumentLayer *) layer
            changedNameFromOldValue: (NSString *) oldName
{
    int layerIndex;
    NSUndoManager *undoManager;

    layerIndex = [self indexOfLayer: layer];

    if (layerIndex < 0)
    {
        return;
    }

    undoManager = [self undoManager];
    [[undoManager prepareWithInvocationTarget: self] setName: oldName
                                                        forLayerAtIndex: layerIndex];

    if (![undoManager isUndoing] && ![undoManager isRedoing])
    {
        [undoManager setActionName: NSLocalizedString(@"Rename Layer", nil)];
    }

    [self postNotification_ChangedAttributeOfLayerAtIndex: layerIndex];
}

- (void) layer: (PPDocumentLayer *) layer
            changedEnabledFlagFromOldValue: (bool) oldEnabledFlag
{
    int layerIndex;
    NSUndoManager *undoManager;

    if (![self handleUpdateToLayer: layer])
    {
        return;
    }

    layerIndex = [self indexOfLayer: layer];

    undoManager = [self undoManager];
    [[undoManager prepareWithInvocationTarget: self] setEnabledFlag: oldEnabledFlag
                                                        forLayerAtIndex: layerIndex];

    if (![undoManager isUndoing] && ![undoManager isRedoing])
    {
        [undoManager setActionName: [layer isEnabled] ? NSLocalizedString(@"Enable Layer", nil) : NSLocalizedString(@"Disable Layer", nil)];
    }

    [self postNotification_ChangedAttributeOfLayerAtIndex: layerIndex];
}

- (void) layer: (PPDocumentLayer *) layer
            changedOpacityFromOldValue: (float) oldOpacity
            shouldRegisterUndo: (bool) shouldRegisterUndo
{
    int layerIndex;

    if (![self handleUpdateToLayer: layer])
    {
        return;
    }

    layerIndex = [self indexOfLayer: layer];

    if (shouldRegisterUndo)
    {
        NSUndoManager *undoManager = [self undoManager];

        [[undoManager prepareWithInvocationTarget: self] setOpacity: oldOpacity
                                                            forLayerAtIndex: layerIndex];

        if (![undoManager isUndoing] && ![undoManager isRedoing])
        {
            NSString *actionName;

            actionName = ([layer opacity] > oldOpacity) ? @"Increase" : @"Decrease";
            actionName = [actionName stringByAppendingString: @" Layer Opacity"];

            if (!actionName)
            {
                actionName = @"Change Layer Opacity";
            }

            [[self undoManager] setActionName: NSLocalizedString(actionName, nil)];
        }
    }

    [self postNotification_ChangedAttributeOfLayerAtIndex: layerIndex];
}

#pragma mark Private methods

- (bool) hasLayerAtIndex: (int) index
{
    return ((index >= 0) && (index < _numLayers)) ? YES : NO;
}

- (bool) isValidLayerInsertionIndex: (int) index
{
    return ((index >= 0)
            && (index <= _numLayers)
            && (_numLayers < kMaxLayersPerDocument)) ? YES : NO;
}

- (int) indexOfLayer: (PPDocumentLayer *) layer
{
    NSUInteger indexOfLayer;

    indexOfLayer = [_layers indexOfObject: layer];

    if (indexOfLayer == NSNotFound)
    {
        return -1;
    }

    return (int) indexOfLayer;
}

- (bool) setupLayerForCurrentBlendingMode: (PPDocumentLayer *) layer
{
    bool shouldEnableLinearBitmap;

    if (!layer)
        goto ERROR;

    shouldEnableLinearBitmap = (_layerBlendingMode == kPPLayerBlendingMode_Linear) ? YES : NO;

    if (![layer enableLinearBlendingBitmap: shouldEnableLinearBitmap])
    {
        goto ERROR;
    }

    return YES;

ERROR:
    return NO;
}

- (bool) setupAllLayersForCurrentBlendingMode
{
    NSEnumerator *layerEnumerator;
    PPDocumentLayer *layer;

    layerEnumerator = [_layers objectEnumerator];

    while (layer = [layerEnumerator nextObject])
    {
        if (![self setupLayerForCurrentBlendingMode: layer])
        {
            goto ERROR;
        }
    }

    return YES;

ERROR:
    return NO;
}

- (void) invalidateAllRelativeCachedLayerImagesForIndex: (int) index
{
    if (![self hasLayerAtIndex: index])
    {
        return;
    }

    [self invalidateImageObjectsInCache: _cachedOverlayersImageObjects
            fromIndex: 0
            toIndex: index - 1];

    [self invalidateImageObjectsInCache: _cachedUnderlayersImageObjects
            fromIndex: index + 1
            toIndex: _numLayers - 1];
}

- (void) invalidateCachedLayerImagesAtIndex: (int) index
{
    if (![self hasLayerAtIndex: index])
    {
        return;
    }

    [self invalidateImageObjectsInCache: _cachedOverlayersImageObjects
            fromIndex: index
            toIndex: index];

    [self invalidateImageObjectsInCache: _cachedUnderlayersImageObjects
            fromIndex: index
            toIndex: index];
}

- (void) invalidateImageObjectsInCache: (NSObject **) cachedImageObjectsArray
            fromIndex: (int) startIndex
            toIndex: (int) endIndex
{
    int i;

    if (!cachedImageObjectsArray)
        goto ERROR;

    if (startIndex < 0)
    {
        startIndex = 0;
    }

    if (endIndex >= _numLayers)
    {
        endIndex = _numLayers - 1;
    }

    if (startIndex > endIndex)
    {
        goto ERROR;
    }

    for (i=startIndex; i<=endIndex; i++)
    {
        if (cachedImageObjectsArray[i])
        {
            [cachedImageObjectsArray[i] release];
            cachedImageObjectsArray[i] = nil;
        }
    }

    return;

ERROR:
    return;
}

- (void) removeAllCachedLayersImages
{
    [self invalidateImageObjectsInCache: _cachedOverlayersImageObjects
            fromIndex: 0
            toIndex: _numLayers - 1];

    [self invalidateImageObjectsInCache: _cachedUnderlayersImageObjects
            fromIndex: 0
            toIndex: _numLayers - 1];
}

- (NSObject *) cachedOverlayersImageObjectForIndex: (int) index
{
    if ((index >= (_numLayers - 1)) || ![self hasLayerAtIndex: index])
    {
        return nil;
    }

    if (!_cachedOverlayersImageObjects[index])
    {
        _cachedOverlayersImageObjects[index] =
            [[self mergedLayersImageObjectFromIndex: index + 1 toIndex: _numLayers - 1] retain];
    }

    return _cachedOverlayersImageObjects[index];
}

- (NSObject *) cachedUnderlayersImageObjectForIndex: (int) index
{
    if ((index < 1) || ![self hasLayerAtIndex: index])
    {
        return nil;
    }

    if (!_cachedUnderlayersImageObjects[index])
    {
        _cachedUnderlayersImageObjects[index] =
            [[self mergedLayersImageObjectFromIndex: 0 toIndex: index - 1] retain];
    }

    return _cachedUnderlayersImageObjects[index];
}

- (NSObject *) mergedLayersImageObjectFromIndex: (int) firstIndex
                toIndex: (int) lastIndex
{
    NSBitmapImageRep *mergedLayersBitmap;
    NSObject *imageObject = nil;

    mergedLayersBitmap = [self mergedLayersBitmapFromIndex: firstIndex toIndex: lastIndex];

    if (!mergedLayersBitmap)
        goto ERROR;

    if (mergedLayersBitmap == gEmptyBitmap)
    {
        // Empty bitmap: return empty image-object
        imageObject = gEmptyImageObject;
    }
    else if (_layerBlendingMode == kPPLayerBlendingMode_Linear)
    {
        // Linear blending: image-objects are NSBitmapImageReps (LinearRGB16)
        imageObject = mergedLayersBitmap;
    }
    else
    {
        // Standard blending: image-objects are NSImages
        imageObject = [NSImage ppImageWithBitmap: mergedLayersBitmap];
    }

    if (!imageObject)
        goto ERROR;

    return imageObject;

ERROR:
    return nil;
}

- (NSBitmapImageRep *) mergedLayersBitmapFromIndex: (int) firstIndex
                        toIndex: (int) lastIndex
{
    NSBitmapImageRep *mergedLayersBitmap = nil;
    int index;
    PPDocumentLayer *layer;
    float layerOpacity;

    if (firstIndex < 0)
    {
        firstIndex = 0;
    }

    if (lastIndex >= [_layers count])
    {
        lastIndex = [_layers count] - 1;
    }

    if (firstIndex > lastIndex)
    {
        goto ERROR;
    }

    if (_layerBlendingMode == kPPLayerBlendingMode_Linear)
    {
        // Linear blending - generate LinearRGB16 bitmap, merge using PikoPixel's LinearRGB16
        // methods

        for (index=lastIndex; index>=firstIndex; index--)
        {
            layer = [self layerAtIndex: index];
            layerOpacity = [layer opacity];

            if ([layer isEnabled] && (layerOpacity > 0.0f))
            {
                if (!mergedLayersBitmap)
                {
                     mergedLayersBitmap =
                                [NSBitmapImageRep ppLinearRGB16BitmapOfSize: _canvasFrame.size];

                    if (!mergedLayersBitmap)
                        goto ERROR;

                    // merge the first layer using linear-copy (faster than linear-blend)

                    [mergedLayersBitmap ppLinearCopyFromLinearBitmap:
                                                                [layer linearBlendingBitmap]
                                            opacity: layerOpacity
                                            inBounds: _canvasFrame];
                }
                else
                {
                    [mergedLayersBitmap ppLinearBlendFromLinearBitmapUnderneath:
                                                                [layer linearBlendingBitmap]
                                            sourceOpacity: layerOpacity
                                            inBounds: _canvasFrame];
                }
            }
        }
    }
    else
    {
        // Standard blending - generate standard Image bitmap (sRGB), merge using native Cocoa
        // methods

        NSCompositingOperation compositingOperation;

        for (index=firstIndex; index<=lastIndex; index++)
        {
            layer = [self layerAtIndex: index];
            layerOpacity = [layer opacity];

            if ([layer isEnabled] && (layerOpacity > 0.0f))
            {
                if (!mergedLayersBitmap)
                {
                    mergedLayersBitmap =
                                    [NSBitmapImageRep ppImageBitmapOfSize: _canvasFrame.size];

                    if (!mergedLayersBitmap)
                        goto ERROR;

                    [mergedLayersBitmap ppSetAsCurrentGraphicsContext];

                    // merge the first layer using NSCompositeCopy (faster than
                    // NSCompositeSourceOver)

                    compositingOperation = NSCompositeCopy;
                }
                else
                {
                    compositingOperation = NSCompositeSourceOver;
                }

                [[layer image] drawInRect: _canvasFrame
                                fromRect: _canvasFrame
                                operation: compositingOperation
                                fraction: layerOpacity];
            }
        }

        if (mergedLayersBitmap)
        {
            [mergedLayersBitmap ppRestoreGraphicsContext];
        }
    }

    if (!mergedLayersBitmap)
    {
        // No layers were merged - return empty bitmap (different from returning nil, which
        // signifies an error)
        return gEmptyBitmap;
    }

    return mergedLayersBitmap;

ERROR:
    return nil;
}

- (void) updateMergedVisibleLayersBitmapInRect: (NSRect) rect
            indexOfUpdatedLayer: (int) indexOfUpdatedLayer
{
    NSObject *imageObject, *imageObjectsToMerge[3];
    int numImageObjectsToMerge = 0, imageIndexOfUpdatedLayer = -1, imageIndex;
    PPDocumentLayer *updatedLayer;
    float opacityOfUpdatedLayer, mergingOpacity;
    bool performedInitialMerge = NO;

    if (NSIsEmptyRect(rect)
        || ![self hasLayerAtIndex: indexOfUpdatedLayer])
    {
        return;
    }

    // Collect image-objects for merge:

    // 1) Underlayers image (merged layers below updated layer)

    imageObject = [self cachedUnderlayersImageObjectForIndex: indexOfUpdatedLayer];

    if (imageObject && (imageObject != gEmptyImageObject))
    {
        imageObjectsToMerge[numImageObjectsToMerge++] = imageObject;
    }

    // 2) Updated-layer image

    updatedLayer = [_layers objectAtIndex: indexOfUpdatedLayer];
    opacityOfUpdatedLayer = [updatedLayer opacity];

    if ([updatedLayer isEnabled] && (opacityOfUpdatedLayer > 0.0f))
    {
        // Linear blending: image-objects are NSBitmapImageReps (LinearRGB16)
        // Standard blending: image-objects are NSImages

        imageObject =
            (_layerBlendingMode == kPPLayerBlendingMode_Linear) ?
                (NSObject *) [updatedLayer linearBlendingBitmap] :
                (NSObject *) [updatedLayer image];

        // Don't need to check that (imageObject != gEmptyImageObject), since gEmptyImageObject
        // is local & won't be returned by PPDocumentLayer methods

        if (imageObject)
        {
            imageIndexOfUpdatedLayer = numImageObjectsToMerge;

            imageObjectsToMerge[numImageObjectsToMerge++] = imageObject;
        }
    }

    // 3) Overlayers image (merged layers above updated layer)

    imageObject = [self cachedOverlayersImageObjectForIndex: indexOfUpdatedLayer];

    if (imageObject && (imageObject != gEmptyImageObject))
    {
        imageObjectsToMerge[numImageObjectsToMerge++] = imageObject;
    }

    // Merge collected image-objects:

    if (_layerBlendingMode == kPPLayerBlendingMode_Linear)
    {
        // Linear blending - image-objects are NSBitmapImageReps (LinearRGB16); merge using
        // PikoPixel's LinearRGB16 bitmap methods

        NSBitmapImageRep *mergingBitmap;

        for (imageIndex=numImageObjectsToMerge-1; imageIndex>=0; imageIndex--)
        {
            mergingBitmap = (NSBitmapImageRep *) imageObjectsToMerge[imageIndex];

            mergingOpacity =
                (imageIndex == imageIndexOfUpdatedLayer) ? opacityOfUpdatedLayer : 1.0f;

            if (!performedInitialMerge)
            {
                // merge the first bitmap using linear-copy (faster than linear-blend)

                [_mergedVisibleLayersLinearBitmap ppLinearCopyFromLinearBitmap: mergingBitmap
                                                    opacity: mergingOpacity
                                                    inBounds: rect];

                performedInitialMerge = YES;
            }
            else
            {
                [_mergedVisibleLayersLinearBitmap ppLinearBlendFromLinearBitmapUnderneath:
                                                                                mergingBitmap
                                                    sourceOpacity: mergingOpacity
                                                    inBounds: rect];
            }
        }

        if (!performedInitialMerge)
        {
            // nothing was merged to the updated area, so clear it manually
            [_mergedVisibleLayersLinearBitmap ppClearBitmapInBounds: rect];
        }

        [_mergedVisibleLayersLinearBitmap ppLinearCopyToImageBitmap: _mergedVisibleLayersBitmap
                                            inBounds: rect];
    }
    else
    {
        // Standard blending - image-objects are NSImages; merge using native Cocoa methods

        NSImage *mergingImage;
        NSCompositingOperation compositingOperation;

        for (imageIndex=0; imageIndex<numImageObjectsToMerge; imageIndex++)
        {
            mergingImage = (NSImage *) imageObjectsToMerge[imageIndex];

            mergingOpacity =
                (imageIndex == imageIndexOfUpdatedLayer) ? opacityOfUpdatedLayer : 1.0f;

            if (!performedInitialMerge)
            {
                [_mergedVisibleLayersBitmap ppSetAsCurrentGraphicsContext];

                // merge the first image using NSCompositeCopy (faster than
                // NSCompositeSourceOver)

                compositingOperation = NSCompositeCopy;
                performedInitialMerge = YES;
            }
            else
            {
                compositingOperation = NSCompositeSourceOver;
            }

            [mergingImage drawInRect: rect
                            fromRect: rect
                            operation: compositingOperation
                            fraction: mergingOpacity];
        }

        if (performedInitialMerge)
        {
            [_mergedVisibleLayersBitmap ppRestoreGraphicsContext];
        }
        else
        {
            // nothing was merged to the updated area, so clear it manually
            [_mergedVisibleLayersBitmap ppClearBitmapInBounds: rect];
        }
    }

    _mergedVisibleBitmapHasEnabledLayer = (numImageObjectsToMerge > 0) ? YES : NO;

    [self recacheMergedVisibleLayersThumbnailImageInBounds: rect];
}

- (NSString *) uniqueLayerNameWithRoot: (NSString *) rootName
{
    int rootNameLength;
    NSMutableSet *prefixMatches;
    NSEnumerator *enumerator;
    PPDocumentLayer *layer;
    NSString *layerName, *testName;
    int suffixValue;

    if (![rootName length])
    {
        rootName = @"";
    }

    rootNameLength = [rootName length];

    prefixMatches = [NSMutableSet set];

    enumerator = [_layers objectEnumerator];

    while (layer = [enumerator nextObject])
    {
        layerName = [layer name];

        if (([layerName length] >= rootNameLength)
            && [layerName hasPrefix: rootName])
        {
            [prefixMatches addObject: layerName];
        }
    }

    if (![prefixMatches count])
    {
        return rootName;
    }

    suffixValue = 1;
    testName = [NSString stringWithFormat: @"%@ %02d", rootName, suffixValue];

    while ([prefixMatches containsObject: testName])
    {
        suffixValue++;
        testName = [NSString stringWithFormat: @"%@ %02d", rootName, suffixValue];
    }

    return testName;
}

- (NSString *) duplicateNameForLayerName: (NSString *) layerName
{
    if (![layerName hasSuffix: @" copy"])
    {
        layerName = [layerName stringByAppendingString: @" copy"];
    }

    return [self uniqueLayerNameWithRoot: layerName];
}

- (void) setupDrawingLayerWithLayerAtIndex: (int) newDrawingLayerIndex
            andPostNotification: (bool) shouldPostNotification
{
    if (![self hasLayerAtIndex: newDrawingLayerIndex])
    {
        newDrawingLayerIndex = -1;
    }

    _indexOfDrawingLayer = newDrawingLayerIndex;

    [self setupDrawingLayerMembers];

    [self handleUpdateToDrawingLayerInRect: _canvasFrame];

    if (shouldPostNotification)
    {
        [self postNotification_SwitchedDrawingLayer];
    }
}

- (void) setupDrawingLayerWithLayerAtIndex: (int) newDrawingLayerIndex
{
    [self setupDrawingLayerWithLayerAtIndex: newDrawingLayerIndex andPostNotification: YES];
}

- (void) setupDrawingLayerMembers
{
    [_drawingLayerImage release];
    _drawingLayerImage = nil;

    [_drawingLayerBitmap release];
    _drawingLayerBitmap = nil;

    [_drawingLayer release];
    _drawingLayer = nil;

    if ([self hasLayerAtIndex: _indexOfDrawingLayer])
    {
        _drawingLayer = [[_layers objectAtIndex: _indexOfDrawingLayer] retain];
        _drawingLayerBitmap = [[_drawingLayer bitmap] retain];
        _drawingLayerImage = [[_drawingLayer image] retain];

        [_drawingUndoBitmap ppCopyFromBitmap: _drawingLayerBitmap toPoint: NSZeroPoint];
    }
    else
    {
        [_drawingUndoBitmap ppClearBitmap];
    }
}

- (void) mergeDrawingLayerWithNextLayerInDirection: (PPDirectionType) directionType
{
    int indexOfMergingLayer;
    NSBitmapImageRep *mergedLayersBitmap;
    NSString *actionName;
    bool shouldEnableMergedDrawLayer = YES;

    if (![self hasLayerAtIndex: _indexOfDrawingLayer])
    {
        goto ERROR;
    }

    if (directionType == kPPDirectionType_Up)
    {
        indexOfMergingLayer = _indexOfDrawingLayer + 1;

        if (![self hasLayerAtIndex: indexOfMergingLayer])
        {
            goto ERROR;
        }

        mergedLayersBitmap = [self mergedLayersBitmapFromIndex: _indexOfDrawingLayer
                                    toIndex: indexOfMergingLayer];

        actionName = @"Merge with Layer Above";
    }
    else if (directionType == kPPDirectionType_Down)
    {
        indexOfMergingLayer = _indexOfDrawingLayer - 1;

        if (![self hasLayerAtIndex: indexOfMergingLayer])
        {
            goto ERROR;
        }

        mergedLayersBitmap = [self mergedLayersBitmapFromIndex: indexOfMergingLayer
                                    toIndex: _indexOfDrawingLayer];

        actionName = @"Merge with Layer Below";
    }
    else
    {
        // only allow up or down directions
        goto ERROR;
    }

    if (mergedLayersBitmap == gEmptyBitmap)
    {
        mergedLayersBitmap = [NSBitmapImageRep ppImageBitmapOfSize: _canvasFrame.size];
        shouldEnableMergedDrawLayer = NO;
    }
    else if ([mergedLayersBitmap ppIsLinearRGB16Bitmap])
    {
        mergedLayersBitmap = [mergedLayersBitmap ppImageBitmapFromLinearRGB16Bitmap];
    }

    if (!mergedLayersBitmap)
        goto ERROR;

    [self copyImageBitmapToDrawingLayer: mergedLayersBitmap atPoint: NSZeroPoint];

    [_drawingLayer setOpacity: 1.0f];
    [_drawingLayer setEnabled: shouldEnableMergedDrawLayer];

    [self removeLayerAtIndex: indexOfMergingLayer];

    [[self undoManager] setActionName: NSLocalizedString(actionName, nil)];

    return;

ERROR:
    return;
}

- (bool) handleUpdateToLayer: (PPDocumentLayer *) layer
{
    int indexOfChangedLayer;

    indexOfChangedLayer = [_layers indexOfObject: layer];

    if (![self hasLayerAtIndex: indexOfChangedLayer])
    {
        return NO;
    }

    [self handleUpdateToLayerAtIndex: indexOfChangedLayer inRect: _canvasFrame];

    return YES;
}

- (void) handleUpdateToDrawingLayerInRect: (NSRect) updateRect
{
    [self updateDissolvedDrawingLayerBitmapInRect: updateRect];

    [self postNotification_UpdatedDrawingLayerAreaInRect: updateRect];

    if (!_disallowThumbnailImageUpdateNotifications)
    {
        [self postNotification_UpdatedDrawingLayerThumbnailImage];
    }
}

- (void) updateDissolvedDrawingLayerBitmapInRect: (NSRect) updateRect
{
    float drawingLayerOpacity = [_drawingLayer opacity];

    if ([_drawingLayer isEnabled] && (drawingLayerOpacity > 0))
    {
        [_dissolvedDrawingLayerBitmap ppSetAsCurrentGraphicsContext];

        [_drawingLayerImage drawInRect: updateRect
                            fromRect: updateRect
                            operation: NSCompositeCopy
                            fraction: drawingLayerOpacity];

        [_dissolvedDrawingLayerBitmap ppRestoreGraphicsContext];
    }
    else
    {
        [_dissolvedDrawingLayerBitmap ppClearBitmapInBounds: updateRect];
    }

    [self recacheDissolvedDrawingLayerThumbnailImageInBounds: updateRect];
}

- (void) insertArchivedLayer: (NSData *) archivedLayer
            atIndex: (int) index
            andSetAsDrawingLayer: (bool) shouldSetAsDrawingLayer
{
    PPDocumentLayer *layer;

    if (!archivedLayer)
        goto ERROR;

    layer = [NSKeyedUnarchiver unarchiveObjectWithData: archivedLayer];

    if (!layer || ![layer isKindOfClass: [PPDocumentLayer class]])
    {
        goto ERROR;
    }

    [self insertLayer: layer atIndex: index andSetAsDrawingLayer: shouldSetAsDrawingLayer];

    return;

ERROR:
    return;
}

- (bool) setLayersWithArchivedLayersData: (NSData *) archivedLayersData
{
    NSArray *layers;

    if (!archivedLayersData)
        goto ERROR;

    layers = [NSKeyedUnarchiver unarchiveObjectWithData: archivedLayersData];

    if (!layers || ![layers isKindOfClass: [NSArray class]])
    {
        goto ERROR;
    }

    return [self setLayers: layers];

ERROR:
    return NO;
}

- (void) setName: (NSString *) name forLayerAtIndex: (int) index
{
    [[self layerAtIndex: index] setName: name];
}

- (void) setEnabledFlag: (bool) isEnabled forLayerAtIndex: (int) index
{
    [[self layerAtIndex: index] setEnabled: isEnabled];
}

- (void) setOpacity: (float) opacity forLayerAtIndex: (int) index
{
    [[self layerAtIndex: index] setOpacity: opacity];
}

- (void) copyTIFFData: (NSData *) tiffData
            toLayerAtIndex: (int) index
            atPoint: (NSPoint) origin
{
    [self copyImageBitmap: [NSBitmapImageRep imageRepWithData: tiffData]
            toLayerAtIndex: index
            atPoint: origin];
}

// recacheMergedVisibleLayersThumbnailImageInBounds:
// & recacheDissolvedDrawingLayerThumbnailImageInBounds: methods are patch targets on GNUstep
// (PPGNUstepGlue_ImageRecacheSpeedups)

- (void) recacheMergedVisibleLayersThumbnailImageInBounds: (NSRect) bounds
{
    [_mergedVisibleLayersThumbnailImage recache];
}

- (void) recacheDissolvedDrawingLayerThumbnailImageInBounds: (NSRect) bounds
{
    [_dissolvedDrawingLayerThumbnailImage recache];
}

@end
