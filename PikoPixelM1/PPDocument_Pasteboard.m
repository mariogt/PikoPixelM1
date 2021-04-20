/*
    PPDocument_Pasteboard.m

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

#import "PPGeometry.h"
#import "PPDocumentLayer.h"
#import "NSBitmapImageRep_PPUtilities.h"
#import "NSPasteboard_PPUtilities.h"


@interface PPDocument (PasteboardPrivateMethods)

- (bool) getPasteboardImageBitmap: (NSBitmapImageRep **) returnedImageBitmap
            maskBitmap: (NSBitmapImageRep **) returnedMaskBitmap
            boundsOnCanvas: (NSRect *) returnedBoundsOnCanvas
            opacity: (float *) returnedOpacity;

- (bool) cropImageBitmapToCanvasFrame: (NSBitmapImageRep **) inOutImageBitmap
            withMaskBitmap: (NSBitmapImageRep **) inOutMaskBitmap
            andAdjustBoundsOnCanvas: (NSRect *) inOutBoundsOnCanvas;

@end

@implementation PPDocument (Pasteboard)

- (bool) canReadFromPasteboard
{
    return [NSPasteboard ppPasteboardHasBitmap];
}

- (bool) canWriteToPasteboard
{
    return _hasSelection;
}

- (void) copySelectionToPasteboardFromTarget: (PPLayerOperationTarget) operationTarget
{
    NSBitmapImageRep *targetBitmap, *croppedTargetBitmap, *croppedMask;
    float selectionOpacity;

    if (!_hasSelection)
        goto ERROR;

    if (operationTarget == kPPLayerOperationTarget_DrawingLayerOnly)
    {
        targetBitmap = _drawingLayerBitmap;
        selectionOpacity = [_drawingLayer opacity];
    }
    else
    {
        targetBitmap = _mergedVisibleLayersBitmap;
        selectionOpacity = 1.0f;
    }

    croppedTargetBitmap = [targetBitmap ppBitmapCroppedToBounds: _selectionBounds];
    croppedMask = [_selectionMask ppBitmapCroppedToBounds: _selectionBounds];

    if (!croppedTargetBitmap || !croppedMask)
    {
        goto ERROR;
    }

    [NSPasteboard ppSetImageBitmap: croppedTargetBitmap
                    maskBitmap: croppedMask
                    bitmapOrigin: _selectionBounds.origin
                    canvasSize: _canvasFrame.size
                    andOpacity: selectionOpacity];

    return;

ERROR:
    return;
}

- (void) cutSelectionToPasteboardFromTarget: (PPLayerOperationTarget) operationTarget
{
    [self copySelectionToPasteboardFromTarget: operationTarget];

    [self noninteractiveEraseSelectedAreaInTarget: operationTarget
            andClearSelectionMask: YES];
}

- (void) pasteNewLayerFromPasteboard
{
    NSBitmapImageRep *pasteboardImageBitmap;
    NSRect pasteboardBoundsOnCanvas;
    float pasteboardOpacity;
    PPDocumentLayer *layer;

    if (![self getPasteboardImageBitmap: &pasteboardImageBitmap
                maskBitmap: NULL
                boundsOnCanvas: &pasteboardBoundsOnCanvas
                opacity: &pasteboardOpacity])
    {
        goto ERROR;
    }

    layer = [PPDocumentLayer layerWithSize: _canvasFrame.size andName: @"Pasted Layer"];

    if (!layer)
        return;

    [[layer bitmap] ppCopyFromBitmap: pasteboardImageBitmap
                    toPoint: pasteboardBoundsOnCanvas.origin];

    [layer handleUpdateToBitmapInRect: pasteboardBoundsOnCanvas];

    [layer setOpacity: pasteboardOpacity];

    [self insertLayer: layer atIndex: _indexOfDrawingLayer + 1 andSetAsDrawingLayer: YES];

    [[self undoManager] setActionName: NSLocalizedString(@"Paste as New Layer", nil)];

    return;

ERROR:
    return;
}

- (void) pasteIntoDrawingLayerFromPasteboard
{
    NSBitmapImageRep *pasteboardImageBitmap, *pasteboardMaskBitmap, *updateBitmap;
    NSRect pasteboardBoundsOnCanvas;

    if (![self getPasteboardImageBitmap: &pasteboardImageBitmap
                maskBitmap: &pasteboardMaskBitmap
                boundsOnCanvas: &pasteboardBoundsOnCanvas
                opacity: NULL])
    {
        goto ERROR;
    }

    // returned pasteboardMaskBitmap can be nil
    if (!pasteboardMaskBitmap)
    {
        pasteboardMaskBitmap =
                        [pasteboardImageBitmap ppMaskBitmapForVisiblePixelsInImageBitmap];

        if (!pasteboardMaskBitmap)
            goto ERROR;
    }

    updateBitmap = [_drawingLayerBitmap ppBitmapCroppedToBounds: pasteboardBoundsOnCanvas];

    if (!updateBitmap)
        goto ERROR;

    [updateBitmap ppMaskedCopyFromImageBitmap: pasteboardImageBitmap
                    usingMask: pasteboardMaskBitmap];

    [self copyImageBitmapToDrawingLayer: updateBitmap atPoint: pasteboardBoundsOnCanvas.origin];

    if (_hasSelection)
    {
        [self deselectAll];
    }

    [self setSelectionMaskAreaWithBitmap: pasteboardMaskBitmap
            atPoint: pasteboardBoundsOnCanvas.origin];

    [[self undoManager] setActionName: NSLocalizedString(@"Paste into Draw Layer", nil)];

    return;

ERROR:
    return;
}

+ (PPDocument *) ppDocumentFromPasteboard
{
    NSBitmapImageRep *imageBitmap, *maskBitmap;
    float opacity;
    PPDocumentLayer *layer;
    NSArray *layersArray;
    PPDocument *ppDocument;

    if (![NSPasteboard ppGetImageBitmap: &imageBitmap
                        maskBitmap: &maskBitmap
                        bitmapOrigin: NULL
                        canvasSize: NULL
                        andOpacity: &opacity])
    {
        goto ERROR;
    }

    layer = [[[PPDocumentLayer alloc] initWithSize: [imageBitmap ppSizeInPixels]
                                        name: @"Main Layer"
                                        tiffData: [imageBitmap TIFFRepresentation]
                                        opacity: opacity
                                        isEnabled: YES]
                                autorelease];

    if (!layer)
        goto ERROR;

    layersArray = [NSArray arrayWithObject: layer];

    if (!layersArray)
        goto ERROR;

    ppDocument = [[[PPDocument alloc] init] autorelease];

    if (!ppDocument)
        goto ERROR;

    [ppDocument setLayers: layersArray];

    if (maskBitmap)
    {
        [ppDocument setSelectionMask: maskBitmap];
    }

    [[ppDocument undoManager] removeAllActions];

    return ppDocument;

ERROR:
    return nil;
}

#pragma mark Private methods

- (bool) getPasteboardImageBitmap: (NSBitmapImageRep **) returnedImageBitmap
            maskBitmap: (NSBitmapImageRep **) returnedMaskBitmap
            boundsOnCanvas: (NSRect *) returnedBoundsOnCanvas
            opacity: (float *) returnedOpacity
{
    NSBitmapImageRep *imageBitmap;
    NSPoint bitmapOrigin;
    NSSize bitmapCanvasSize;

    if (![NSPasteboard ppGetImageBitmap: &imageBitmap
                        maskBitmap: returnedMaskBitmap
                        bitmapOrigin: &bitmapOrigin
                        canvasSize: &bitmapCanvasSize
                        andOpacity: returnedOpacity])
    {
        goto ERROR;
    }

    if (returnedBoundsOnCanvas)
    {
        NSRect boundsOnCanvas;

        boundsOnCanvas.origin = bitmapOrigin;
        boundsOnCanvas.size = [imageBitmap ppSizeInPixels];

        if (!NSEqualSizes(bitmapCanvasSize, _canvasFrame.size))
        {
            boundsOnCanvas = PPGeometry_CenterRectInRect(boundsOnCanvas, _canvasFrame);
        }

        if (![self cropImageBitmapToCanvasFrame: &imageBitmap
                    withMaskBitmap: returnedMaskBitmap
                    andAdjustBoundsOnCanvas: &boundsOnCanvas])
        {
            goto ERROR;
        }

        *returnedBoundsOnCanvas = boundsOnCanvas;
    }

    if (returnedImageBitmap)
    {
        *returnedImageBitmap = imageBitmap;
    }

    return YES;

ERROR:
    return NO;
}

- (bool) cropImageBitmapToCanvasFrame: (NSBitmapImageRep **) inOutImageBitmap
            withMaskBitmap: (NSBitmapImageRep **) inOutMaskBitmap
            andAdjustBoundsOnCanvas: (NSRect *) inOutBoundsOnCanvas
{
    NSBitmapImageRep *imageBitmap, *newImageBitmap;
    NSRect boundsOnCanvas, newBoundsOnCanvas, croppingBounds;

    if (!inOutImageBitmap || !inOutBoundsOnCanvas)
    {
        goto ERROR;
    }

    imageBitmap = *inOutImageBitmap;
    boundsOnCanvas = *inOutBoundsOnCanvas;

    if (!imageBitmap || NSIsEmptyRect(boundsOnCanvas))
    {
        goto ERROR;
    }

    if (NSContainsRect(_canvasFrame, boundsOnCanvas))
    {
        return YES;
    }

    newBoundsOnCanvas = NSIntersectionRect(_canvasFrame, boundsOnCanvas);

    if (NSIsEmptyRect(newBoundsOnCanvas))
    {
        goto ERROR;
    }

    croppingBounds.size = newBoundsOnCanvas.size;
    croppingBounds.origin =
                PPGeometry_PointDifference(newBoundsOnCanvas.origin, boundsOnCanvas.origin);

    newImageBitmap = [imageBitmap ppBitmapCroppedToBounds: croppingBounds];

    if (!newImageBitmap)
        goto ERROR;

    if (inOutMaskBitmap)
    {
        NSBitmapImageRep *maskBitmap = *inOutMaskBitmap;

        if (maskBitmap)
        {
            maskBitmap = [maskBitmap ppBitmapCroppedToBounds: croppingBounds];

            if (!maskBitmap)
                goto ERROR;

            *inOutMaskBitmap = maskBitmap;
        }
    }

    *inOutImageBitmap = newImageBitmap;
    *inOutBoundsOnCanvas = newBoundsOnCanvas;

    return YES;

ERROR:
    return NO;
}

@end
