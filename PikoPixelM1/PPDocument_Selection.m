/*
    PPDocument_Selection.m

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
#import "NSBitmapImageRep_PPUtilities.h"
#import "NSColor_PPUtilities.h"
#import "NSBezierPath_PPUtilities.h"
#import "PPGeometry.h"


@interface PPDocument (SelectionPrivateMethods)

- (void) updateSelectionMaskWithBitmap: (NSBitmapImageRep *) bitmap atPoint: (NSPoint) origin;
- (void) updateSelectionMaskWithTIFFData: (NSData *) tiffData atPoint: (NSPoint) origin;
- (void) selectPath: (NSBezierPath *) path
            selectionMode: (PPSelectionMode) selectionMode
            shouldAntialias: (bool) shouldAntialias;
- (bool) validateSelectionMode: (PPSelectionMode *) inOutSelectionMode;
- (bool) selectionMaskIsNotEmpty;
- (void) handleSelectionMaskUpdateInBounds: (NSRect) bounds
            undoBitmap: (NSBitmapImageRep *) undoBitmap;

- (NSString *) actionNameForSelectionMode: (PPSelectionMode) selectionMode;

@end

@implementation PPDocument (Selection)

- (bool) setupSelectionMaskBitmapOfSize: (NSSize) maskSize
{
    if (PPGeometry_IsZeroSize(maskSize))
    {
        goto ERROR;
    }

    if (!_selectionMask
        || !NSEqualSizes([_selectionMask ppSizeInPixels], maskSize))
    {
        NSBitmapImageRep *selectionMask = [NSBitmapImageRep ppMaskBitmapOfSize: maskSize];

        if (!selectionMask)
            goto ERROR;

        [_selectionMask autorelease];   // use autorelease when releasing accessible members
        _selectionMask = [selectionMask retain];
    }
    else
    {
        [_selectionMask ppClearBitmap];
    }

    _selectionBounds = NSZeroRect;
    _hasSelection = NO;

    return YES;

ERROR:
    return NO;
}

- (bool) hasSelection
{
    return _hasSelection;
}

- (NSRect) selectionBounds
{
    return _selectionBounds;
}

- (NSBitmapImageRep *) selectionMask
{
    return _selectionMask;
}

- (void) setSelectionMask: (NSBitmapImageRep *) selectionMask
{
    if (![selectionMask ppIsMaskBitmap]
        || !NSEqualSizes([_selectionMask ppSizeInPixels], [selectionMask ppSizeInPixels]))
    {
        return;
    }

    [self updateSelectionMaskWithBitmap: selectionMask atPoint: NSZeroPoint];
}

- (void) setSelectionMaskAreaWithBitmap: (NSBitmapImageRep *) selectionMask
                                atPoint: (NSPoint) origin
{
    if (![selectionMask ppIsMaskBitmap])
    {
        return;
    }

    [self updateSelectionMaskWithBitmap: selectionMask atPoint: origin];
}

- (void) selectRect: (NSRect) rect
            selectionMode: (PPSelectionMode) selectionMode
{
    rect = PPGeometry_PixelCenteredRect(rect);

    [self selectPath: [NSBezierPath bezierPathWithRect: rect]
            selectionMode: selectionMode
            shouldAntialias: NO];
}

- (void) selectPath: (NSBezierPath *) path
            selectionMode: (PPSelectionMode) selectionMode
{
    [self selectPath: path
            selectionMode: selectionMode
            shouldAntialias: YES];
}

- (void) selectPixelsMatchingColorAtPoint: (NSPoint) point
            colorMatchTolerance: (unsigned) colorMatchTolerance
            pixelMatchingMode: (PPPixelMatchingMode) pixelMatchingMode
            selectionMode: (PPSelectionMode) selectionMode
{
    NSBitmapImageRep *matchMask, *croppedMatchMask, *croppedSelectionMask;
    NSRect matchMaskBounds;
    bool matchMaskShouldIntersectSelectionMask;

    if (![self validateSelectionMode: &selectionMode])
    {
        goto ERROR;
    }

    if ((selectionMode == kPPSelectionMode_Intersect)
            || (selectionMode == kPPSelectionMode_Subtract))
    {
        matchMaskShouldIntersectSelectionMask =
                    (_hasSelection && [_selectionMask ppMaskCoversPoint: point]) ? YES : NO;
    }
    else
    {
        matchMaskShouldIntersectSelectionMask = NO;
    }

    matchMask = [self maskForPixelsMatchingColorAtPoint: point
                        colorMatchTolerance: colorMatchTolerance
                        pixelMatchingMode: pixelMatchingMode
                        shouldIntersectSelectionMask: matchMaskShouldIntersectSelectionMask];

    if (!matchMask)
        goto ERROR;

    matchMaskBounds = [matchMask ppMaskBounds];

    if (NSIsEmptyRect(matchMaskBounds))
    {
        goto ERROR;
    }

    if (selectionMode == kPPSelectionMode_Intersect)
    {
        if (_hasSelection && !matchMaskShouldIntersectSelectionMask)
        {
            // matchMask wasn't intersected with the selection mask during construction by
            // the maskForPixelsMatchingColorAtPoint:... method, so intersect it manually here
            [matchMask ppIntersectMaskWithMaskBitmap: _selectionMask];
        }

        selectionMode = kPPSelectionMode_Replace;
    }

    if (selectionMode == kPPSelectionMode_Replace)
    {
        if (_hasSelection)
        {
            matchMaskBounds = NSUnionRect(matchMaskBounds, _selectionBounds);
        }
    }

    croppedMatchMask = [matchMask ppShallowDuplicateFromBounds: matchMaskBounds];

    if (!croppedMatchMask)
        goto ERROR;

    if (selectionMode == kPPSelectionMode_Subtract)
    {
        croppedSelectionMask = [_selectionMask ppBitmapCroppedToBounds: matchMaskBounds];

        if (!croppedSelectionMask)
            goto ERROR;

        [croppedSelectionMask ppSubtractMaskBitmap: croppedMatchMask];

        croppedMatchMask = croppedSelectionMask;
    }
    else if (selectionMode == kPPSelectionMode_Add)
    {
        croppedSelectionMask = [_selectionMask ppShallowDuplicateFromBounds: matchMaskBounds];

        if (!croppedSelectionMask)
            goto ERROR;

        [croppedMatchMask ppMergeMaskWithMaskBitmap: croppedSelectionMask];
    }

    [self updateSelectionMaskWithBitmap: croppedMatchMask
            atPoint: matchMaskBounds.origin];

    [[self undoManager] setActionName: NSLocalizedString([self actionNameForSelectionMode: selectionMode], nil)];

    return;

ERROR:
    return;
}

- (void) selectAll
{
    [self selectRect: _canvasFrame
            selectionMode: kPPSelectionMode_Add];

    [[self undoManager] setActionName: NSLocalizedString(@"Select All", nil)];
}

- (void) selectVisibleTargetPixels
{
    NSBitmapImageRep *visiblePixelsMask =
                        [[self sourceBitmapForLayerOperationTarget: _layerOperationTarget]
                                                    ppMaskBitmapForVisiblePixelsInImageBitmap];

    if (!visiblePixelsMask)
        return;

    [self setSelectionMask: visiblePixelsMask];

    [[self undoManager] setActionName: NSLocalizedString(@"Select Visible Pixels", nil)];
}

- (void) deselectAll
{
    if (!_hasSelection)
        return;

    [self selectRect: _selectionBounds
            selectionMode: kPPSelectionMode_Subtract];

    [[self undoManager] setActionName: NSLocalizedString(@"Deselect All", nil)];
}

- (void) deselectInvisibleTargetPixels
{
    NSBitmapImageRep *workingMask, *croppedSelectionMask;

    if (!_hasSelection)
        return;

    // crop target bitmap to selection bounds & make a mask of its visible pixels
    workingMask =
        [[[self sourceBitmapForLayerOperationTarget: _layerOperationTarget]
                                        ppShallowDuplicateFromBounds: _selectionBounds]
                                                ppMaskBitmapForVisiblePixelsInImageBitmap];

    if (!workingMask)
        goto ERROR;

    croppedSelectionMask = [_selectionMask ppShallowDuplicateFromBounds: _selectionBounds];

    if (!croppedSelectionMask)
        goto ERROR;

    [workingMask ppIntersectMaskWithMaskBitmap: croppedSelectionMask];

    if ([workingMask ppIsEqualToBitmap: croppedSelectionMask])
    {
        return;
    }

    [self setSelectionMaskAreaWithBitmap: workingMask atPoint: _selectionBounds.origin];

    [[self undoManager] setActionName: NSLocalizedString(@"Deselect Invisible Pixels", nil)];

    return;

ERROR:
    return;
}

- (void) invertSelection
{
    NSUndoManager *undoManager = [self undoManager];

    [undoManager disableUndoRegistration];

    if (!_hasSelection)
    {
        [self selectAll];
    }
    else
    {
        NSBitmapImageRep *invertedSelectionMask = [[_selectionMask copy] autorelease];

        [invertedSelectionMask ppInvertMaskBitmap];

        if (!invertedSelectionMask)
            goto ERROR;

        if ([invertedSelectionMask ppMaskIsNotEmpty])
        {
            [self setSelectionMask: invertedSelectionMask];
        }
        else
        {
            [self deselectAll];
        }
    }

    [undoManager enableUndoRegistration];

    [[undoManager prepareWithInvocationTarget: self] invertSelection];

    if (![undoManager isUndoing] && ![undoManager isRedoing])
    {
        [undoManager setActionName: NSLocalizedString(@"Invert Selection", nil)];
    }

    return;

ERROR:
    [undoManager enableUndoRegistration];

    return;
}

- (void) closeHolesInSelection
{
    NSBitmapImageRep *updatedMask;

    if (!_hasSelection)
        goto ERROR;

    updatedMask = [_selectionMask ppBitmapCroppedToBounds: _selectionBounds];

    if (!updatedMask)
        goto ERROR;

    [updatedMask ppCloseHolesInMaskBitmap];

    [self setSelectionMaskAreaWithBitmap: updatedMask atPoint: _selectionBounds.origin];

    [[self undoManager] setActionName: NSLocalizedString(@"Close Holes in Selection", nil)];

    return;

ERROR:
    return;
}

- (PPDocument *) ppDocumentFromSelection
{
    PPDocument *ppDocument;

    if (!_hasSelection || ![self layerOperationTargetHasEnabledLayer])
    {
        goto ERROR;
    }

    ppDocument = [[[PPDocument alloc] init] autorelease];

    if (!ppDocument)
        goto ERROR;

    [ppDocument loadFromPPDocument: self];
    [ppDocument cropToSelectionBounds];
    [ppDocument removeNontargetLayers];

    [[ppDocument undoManager] removeAllActions];

    return ppDocument;

ERROR:
    return nil;
}

#pragma mark Private methods

- (void) updateSelectionMaskWithBitmap: (NSBitmapImageRep *) bitmap atPoint: (NSPoint) origin
{
    NSRect updateRect;
    NSBitmapImageRep *undoBitmap;

    updateRect.origin = origin;
    updateRect.size = [bitmap ppSizeInPixels];
    updateRect = NSIntersectionRect(updateRect, _canvasFrame);

    if (NSIsEmptyRect(updateRect))
    {
        return;
    }

    undoBitmap = [_selectionMask ppBitmapCroppedToBounds: updateRect];

    [_selectionMask ppCopyFromBitmap: bitmap toPoint: origin];

    [self handleSelectionMaskUpdateInBounds: updateRect undoBitmap: undoBitmap];
}

- (void) updateSelectionMaskWithTIFFData: (NSData *) tiffData atPoint: (NSPoint) origin
{
    if (!tiffData)
        return;

    [self updateSelectionMaskWithBitmap: [NSBitmapImageRep imageRepWithData: tiffData]
            atPoint: origin];
}

- (void) selectPath: (NSBezierPath *) path
            selectionMode: (PPSelectionMode) selectionMode
            shouldAntialias: (bool) shouldAntialias
{
    NSRect pathBounds, updateBounds;
    NSBitmapImageRep *undoBitmap;

    if (![self validateSelectionMode: &selectionMode])
    {
        goto ERROR;
    }

    pathBounds = NSIntersectionRect(PPGeometry_PixelBoundsCoveredByRect([path bounds]),
                                    _canvasFrame);

    if (NSIsEmptyRect(pathBounds))
    {
        goto ERROR;
    }

    if (((selectionMode == kPPSelectionMode_Replace) && _hasSelection)
        || (selectionMode == kPPSelectionMode_Intersect))
    {
        updateBounds = NSUnionRect(pathBounds, _selectionBounds);

        undoBitmap = [_selectionMask ppBitmapCroppedToBounds: updateBounds];

        [_selectionMask ppClearBitmapInBounds: updateBounds];
    }
    else
    {
        updateBounds = pathBounds;

        undoBitmap = [_selectionMask ppBitmapCroppedToBounds: updateBounds];
    }

    [_selectionMask ppSetAsCurrentGraphicsContext];

    if (selectionMode == kPPSelectionMode_Subtract)
    {
        [[NSColor ppMaskBitmapOffColor] set];
    }
    else
    {
        [[NSColor ppMaskBitmapOnColor] set];
    }

    if (shouldAntialias)
    {
        // antialiasing is necessary when filling a non-rectangular path, otherwise the fill
        // will cover a larger area than the stroke (some curve edges will add a pixel);
        // make sure to correct the antialiasing afterwards by thresholding the mask's pixel
        // values to 0 & 255

        [path ppAntialiasedFill];
    }
    else
    {
        [path fill];
    }

    [path stroke];

    [_selectionMask ppRestoreGraphicsContext];

    if (shouldAntialias)
    {
        [_selectionMask ppThresholdMaskBitmapPixelValuesInBounds: pathBounds];
    }

    if (selectionMode == kPPSelectionMode_Intersect)
    {
        NSBitmapImageRep *croppedSelectionMask;

        croppedSelectionMask = [_selectionMask ppShallowDuplicateFromBounds: updateBounds];

        // overwriting (intersecting) croppedSelectionMask also overwrites _selectionMask,
        // since they share bitmapData (ShallowDuplicate)
        [croppedSelectionMask ppIntersectMaskWithMaskBitmap: undoBitmap];
    }

    [self handleSelectionMaskUpdateInBounds: updateBounds
                            undoBitmap: undoBitmap];

    [[self undoManager] setActionName: NSLocalizedString([self actionNameForSelectionMode: selectionMode], nil)];

    return;

ERROR:
    return;
}

- (bool) validateSelectionMode: (PPSelectionMode *) inOutSelectionMode
{
    PPSelectionMode selectionMode;

    if (!inOutSelectionMode)
        goto ERROR;

    selectionMode = *inOutSelectionMode;

    if (!PPSelectionMode_IsValid(selectionMode))
    {
        goto ERROR;
    }

    if (!_hasSelection)
    {
        if ((selectionMode == kPPSelectionMode_Subtract)
            || (selectionMode == kPPSelectionMode_Intersect))
        {
            goto ERROR;
        }

        selectionMode = kPPSelectionMode_Replace;
    }

    *inOutSelectionMode = selectionMode;

    return YES;

ERROR:
    return NO;
}

- (bool) selectionMaskIsNotEmpty
{
    return [_selectionMask ppMaskIsNotEmpty];
}

- (void) handleSelectionMaskUpdateInBounds: (NSRect) bounds
            undoBitmap: (NSBitmapImageRep *) undoBitmap
{
    NSUndoManager *undoManager;

    _hasSelection = [self selectionMaskIsNotEmpty];

    if (_hasSelection)
    {
        _selectionBounds =
                    [_selectionMask ppMaskBoundsInRect: NSUnionRect(_selectionBounds, bounds)];
    }
    else
    {
        _selectionBounds = NSZeroRect;
    }

    [self postNotification_UpdatedSelection];

    undoManager = [self undoManager];

    [[undoManager prepareWithInvocationTarget: self]
                                            updateSelectionMaskWithTIFFData:
                                                            [undoBitmap ppCompressedTIFFData]
                                            atPoint: bounds.origin];

    if (![undoManager isUndoing] && ![undoManager isRedoing])
    {
        [undoManager setActionName: NSLocalizedString(@"Selection", nil)];
    }
}

- (NSString *) actionNameForSelectionMode: (PPSelectionMode) selectionMode
{
    switch (selectionMode)
    {
        case kPPSelectionMode_Add:
        {
            return @"Add to Selection";
        }
        break;

        case kPPSelectionMode_Subtract:
        {
            return @"Subtract from Selection";
        }
        break;

        case kPPSelectionMode_Intersect:
        {
            return @"Intersect Selection";
        }
        break;

        case kPPSelectionMode_Replace:
        default:
        {
            return @"Make Selection";
        }
        break;
    }
}

@end
