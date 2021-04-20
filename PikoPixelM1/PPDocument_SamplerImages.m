/*
    PPDocument_SamplerImages.m

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

#import "PPDocumentSamplerImage.h"
#import "PPDocument_Notifications.h"
#import "NSObject_PPUtilities.h"


#define kSamplerImageChangeTypeMask_Add         (1 << 0)
#define kSamplerImageChangeTypeMask_Remove      (1 << 1)
#define kSamplerImageChangeTypeMask_Move        (1 << 2)


@interface PPDocument (SamplerImagesPrivateMethods)

- (void) setSamplerImagesWithArchivedSamplerImagesData: (NSData *) archivedSamplerImagesData;

- (bool) hasSamplerImageAtIndex: (int) index;

- (void) insertSamplerImage: (PPDocumentSamplerImage *) samplerImage
            atIndex: (int) index;
- (void) insertArchivedSamplerImage: (NSData *) archivedSamplerImageData
            atIndex: (int) index;
- (void) moveSamplerImageAtIndex: (int) oldIndex
            toIndex: (int) newIndex;
- (void) removeSamplerImageAtIndex: (int) index;
- (void) removeAllSamplerImages;

- (void) resetActiveSamplerImageIndexes;

- (void) setActionNameForChangeTypesMask: (unsigned) changeTypesMask
            numImagesChanged: (unsigned) numImagesChanged;

@end

@implementation PPDocument (SamplerImages)

- (void) setupSamplerImageIndexes
{
    _samplerImageMinIndexValues[(int) kPPSamplerImagePanelType_PopupPanel] = -1;

    [self resetActiveSamplerImageIndexes];
}

- (int) numSamplerImages
{
    return _numSamplerImages;
}

- (NSArray *) samplerImages
{
    return _samplerImages;
}

- (void) setSamplerImages: (NSArray *) newSamplerImages
{
    unsigned changeTypesMask = 0, numImagesChanged = 0;
    NSUInteger numNewSamplerImages, index, oldIndex;
    PPDocumentSamplerImage *newSamplerImage;

    numNewSamplerImages = [newSamplerImages count];

    if (numNewSamplerImages > 0)
    {
        if (_numSamplerImages > 0)
        {
            // disallow duplicate sampler images
            if ([[NSSet setWithArray: newSamplerImages] count] != numNewSamplerImages)
            {
                goto ERROR;
            }

            for (index=0; index<numNewSamplerImages; index++)
            {
                newSamplerImage = [newSamplerImages objectAtIndex: index];

                oldIndex = [_samplerImages indexOfObject: newSamplerImage];

                if (oldIndex != NSNotFound)
                {
                    if (oldIndex != index)
                    {
                        [self moveSamplerImageAtIndex: oldIndex toIndex: index];

                        changeTypesMask |= kSamplerImageChangeTypeMask_Move;
                        numImagesChanged++;
                    }
                }
                else
                {
                    [self insertSamplerImage: newSamplerImage atIndex: index];

                    changeTypesMask |= kSamplerImageChangeTypeMask_Add;
                    numImagesChanged++;
                }
            }

            while (index < _numSamplerImages)
            {
                [self removeSamplerImageAtIndex: index];    // decrements _numSamplerImages

                changeTypesMask |= kSamplerImageChangeTypeMask_Remove;
                numImagesChanged++;
            }
        }
        else    // !(_numSamplerImages > 0)
        {
            for (index=0; index<numNewSamplerImages; index++)
            {
                newSamplerImage = [newSamplerImages objectAtIndex: index];

                [self insertSamplerImage: newSamplerImage atIndex: index];
            }

            changeTypesMask |= kSamplerImageChangeTypeMask_Add;
            numImagesChanged += numNewSamplerImages;

            [self resetActiveSamplerImageIndexes];
        }
    }
    else    // !(numNewSamplerImages > 0)
    {
        changeTypesMask |= kSamplerImageChangeTypeMask_Remove;
        numImagesChanged = _numSamplerImages;

        [self removeAllSamplerImages];
    }

    [self setActionNameForChangeTypesMask: changeTypesMask numImagesChanged: numImagesChanged];

    return;

ERROR:
    return;
}

- (PPDocumentSamplerImage *) activeSamplerImageForPanelType:
                                                    (PPSamplerImagePanelType) samplerPanelType
{
    int samplerImageIndex;

    if (!PPSamplerImagePanelType_IsValid(samplerPanelType))
    {
        goto ERROR;
    }

    samplerImageIndex = _activeSamplerImageIndexes[(int) samplerPanelType];

    if (![self hasSamplerImageAtIndex: samplerImageIndex])
    {
        goto ERROR;
    }

    return [_samplerImages objectAtIndex: samplerImageIndex];

ERROR:
    return nil;
}

- (void) activateNextSamplerImageForPanelType: (PPSamplerImagePanelType) samplerPanelType
{
    int panelIndex, oldIndexValue;

    if (!PPSamplerImagePanelType_IsValid(samplerPanelType))
    {
        goto ERROR;
    }

    panelIndex = (int) samplerPanelType;
    oldIndexValue = _activeSamplerImageIndexes[panelIndex]++;

    if (_activeSamplerImageIndexes[panelIndex] >= _numSamplerImages)
    {
        _activeSamplerImageIndexes[panelIndex] = _samplerImageMinIndexValues[panelIndex];
    }

    if (_activeSamplerImageIndexes[panelIndex] != oldIndexValue)
    {
        [self postNotification_SwitchedActiveSamplerImageForPanelType: samplerPanelType];
    }

    return;

ERROR:
    return;
}

- (void) activatePreviousSamplerImageForPanelType: (PPSamplerImagePanelType) samplerPanelType
{
    int panelIndex, oldIndexValue;

    if (!PPSamplerImagePanelType_IsValid(samplerPanelType))
    {
        goto ERROR;
    }

    panelIndex = (int) samplerPanelType;
    oldIndexValue = _activeSamplerImageIndexes[samplerPanelType]--;

    if (_activeSamplerImageIndexes[panelIndex] < _samplerImageMinIndexValues[panelIndex])
    {
        _activeSamplerImageIndexes[panelIndex] = _numSamplerImages - 1;
    }

    if (_activeSamplerImageIndexes[panelIndex] != oldIndexValue)
    {
        [self postNotification_SwitchedActiveSamplerImageForPanelType: samplerPanelType];
    }

    return;

ERROR:
    return;
}

- (bool) hasActiveSamplerImageForPanelType: (PPSamplerImagePanelType) samplerPanelType
{
    if (!PPSamplerImagePanelType_IsValid(samplerPanelType))
    {
        goto ERROR;
    }

    return [self hasSamplerImageAtIndex: _activeSamplerImageIndexes[(int) samplerPanelType]];

ERROR:
    return NO;
}

- (bool) shouldEnableSamplerImagePanel
{
    return _shouldEnableSamplerImagePanel;
}

- (void) setShouldEnableSamplerImagePanel: (bool) shouldEnableSamplerImagePanel
{
    _shouldEnableSamplerImagePanel = (shouldEnableSamplerImagePanel) ? YES : NO;
}

#pragma mark Private methods

- (void) setSamplerImagesWithArchivedSamplerImagesData: (NSData *) archivedSamplerImagesData
{
    NSArray *samplerImages = nil;

    if (archivedSamplerImagesData)
    {
        samplerImages = [NSKeyedUnarchiver unarchiveObjectWithData: archivedSamplerImagesData];
    }

    [self setSamplerImages: samplerImages];
}

- (bool) hasSamplerImageAtIndex: (int) index
{
    return ((index >= 0) && (index < _numSamplerImages)) ? YES : NO;
}

- (void) insertSamplerImage: (PPDocumentSamplerImage *) samplerImage
            atIndex: (int) index;
{
    int panelType;
    bool didSwitchActiveImageForPanel = NO;

    if (!samplerImage
        || ((index != _numSamplerImages) && ![self hasSamplerImageAtIndex: index])
        || ([_samplerImages indexOfObject: samplerImage] != NSNotFound))
    {
        goto ERROR;
    }

    if (_numSamplerImages)
    {
        for (panelType=0; panelType<kNumPPSamplerImagePanelTypes; panelType++)
        {
            if ((_activeSamplerImageIndexes[panelType] >= index)
                && (index < _numSamplerImages))
            {
                _activeSamplerImageIndexes[panelType]++;
            }
        }
    }
    else    // !(_numSamplerImages)
    {
        didSwitchActiveImageForPanel = YES;
    }

    [_samplerImages insertObject: samplerImage atIndex: index];
    _numSamplerImages = [_samplerImages count];

    [[[self undoManager] prepareWithInvocationTarget: self] removeSamplerImageAtIndex: index];

    if (didSwitchActiveImageForPanel)
    {
        [self postNotification_SwitchedActiveSamplerImageForPanelType:
                                                                kPPSamplerImagePanelType_Panel];
    }

    [self ppPerformSelectorAtomicallyFromNewStackFrame:
                                            @selector(postNotification_UpdatedSamplerImages)];

    return;

ERROR:
    return;
}

- (void) insertArchivedSamplerImage: (NSData *) archivedSamplerImageData
            atIndex: (int) index
{
    PPDocumentSamplerImage *samplerImage;

    if (!archivedSamplerImageData)
        goto ERROR;

    samplerImage = [NSKeyedUnarchiver unarchiveObjectWithData: archivedSamplerImageData];

    if (![samplerImage isKindOfClass: [PPDocumentSamplerImage class]])
    {
        goto ERROR;
    }

    [self insertSamplerImage: samplerImage atIndex: index];

    return;

ERROR:
    return;
}

- (void) moveSamplerImageAtIndex: (int) oldIndex
            toIndex: (int) newIndex
{
    PPDocumentSamplerImage *samplerImage;
    int minIndex, maxIndex, indexOffset, panelType;

    if (![self hasSamplerImageAtIndex: oldIndex]
        || ![self hasSamplerImageAtIndex: newIndex]
        || (oldIndex == newIndex))
    {
        goto ERROR;
    }

    samplerImage = [[[_samplerImages objectAtIndex: oldIndex] retain] autorelease];

    [_samplerImages removeObjectAtIndex: oldIndex];
    [_samplerImages insertObject: samplerImage atIndex: newIndex];

    if (oldIndex < newIndex)
    {
        minIndex = oldIndex;
        maxIndex = newIndex;
        indexOffset = -1;
    }
    else
    {
        minIndex = newIndex;
        maxIndex = oldIndex;
        indexOffset = 1;
    }

    for (panelType=0; panelType<kNumPPSamplerImagePanelTypes; panelType++)
    {
        if (_activeSamplerImageIndexes[panelType] == oldIndex)
        {
            _activeSamplerImageIndexes[panelType] = newIndex;
        }
        else if ((_activeSamplerImageIndexes[panelType] >= minIndex)
                    && (_activeSamplerImageIndexes[panelType] <= maxIndex))
        {
            _activeSamplerImageIndexes[panelType] += indexOffset;
        }
    }

    [[[self undoManager] prepareWithInvocationTarget: self] moveSamplerImageAtIndex: newIndex
                                                            toIndex: oldIndex];

    [self ppPerformSelectorAtomicallyFromNewStackFrame:
                                            @selector(postNotification_UpdatedSamplerImages)];

    return;

ERROR:
    return;
}

- (void) removeSamplerImageAtIndex: (int) index
{
    NSData *oldSamplerImageData;
    int panelType;
    bool didSwitchActiveSamplerImageForPanelType[kNumPPSamplerImagePanelTypes];

    if (![self hasSamplerImageAtIndex: index])
    {
        goto ERROR;
    }

    oldSamplerImageData =
        [NSKeyedArchiver archivedDataWithRootObject: [_samplerImages objectAtIndex: index]];

    [_samplerImages removeObjectAtIndex: index];
    _numSamplerImages = [_samplerImages count];

    for (panelType=0; panelType<kNumPPSamplerImagePanelTypes; panelType++)
    {
        didSwitchActiveSamplerImageForPanelType[panelType] = NO;

        if (_activeSamplerImageIndexes[panelType] > index)
        {
            _activeSamplerImageIndexes[panelType]--;
        }
        else if (_activeSamplerImageIndexes[panelType] == index)
        {
            if (index >= _numSamplerImages)
            {
                _activeSamplerImageIndexes[panelType] = _samplerImageMinIndexValues[panelType];
            }

            didSwitchActiveSamplerImageForPanelType[panelType] = YES;
        }
    }

    [[[self undoManager] prepareWithInvocationTarget: self]
                                            insertArchivedSamplerImage: oldSamplerImageData
                                            atIndex: index];

    for (panelType=0; panelType<kNumPPSamplerImagePanelTypes; panelType++)
    {
        if (didSwitchActiveSamplerImageForPanelType[panelType])
        {
            [self postNotification_SwitchedActiveSamplerImageForPanelType: panelType];
        }
    }

    [self ppPerformSelectorAtomicallyFromNewStackFrame:
                                            @selector(postNotification_UpdatedSamplerImages)];

    return;

ERROR:
    return;
}

- (void) removeAllSamplerImages
{
    NSData *oldSamplerImagesData;
    int panelType;
    bool hadActiveSamplerImageForPanelType[kNumPPSamplerImagePanelTypes];

    if (!_numSamplerImages)
        return;

    oldSamplerImagesData = [NSKeyedArchiver archivedDataWithRootObject: _samplerImages];

    for (panelType=0; panelType<kNumPPSamplerImagePanelTypes; panelType++)
    {
        hadActiveSamplerImageForPanelType[panelType] =
                        [self hasSamplerImageAtIndex: _activeSamplerImageIndexes[panelType]];
    }

    [_samplerImages removeAllObjects];
    _numSamplerImages = [_samplerImages count];

    [self resetActiveSamplerImageIndexes];

    [[[self undoManager]
                    prepareWithInvocationTarget: self]
                        setSamplerImagesWithArchivedSamplerImagesData: oldSamplerImagesData];

    for (panelType=0; panelType<kNumPPSamplerImagePanelTypes; panelType++)
    {
        if (hadActiveSamplerImageForPanelType[panelType])
        {
            [self postNotification_SwitchedActiveSamplerImageForPanelType: panelType];
        }
    }

    [self ppPerformSelectorAtomicallyFromNewStackFrame:
                                            @selector(postNotification_UpdatedSamplerImages)];
}

- (void) resetActiveSamplerImageIndexes
{
    memcpy(_activeSamplerImageIndexes, _samplerImageMinIndexValues,
            sizeof(_activeSamplerImageIndexes));
}

- (void) setActionNameForChangeTypesMask: (unsigned) changeTypesMask
            numImagesChanged: (unsigned) numImagesChanged
{
    NSString *changeDescription, *actionName;
    bool didChangeMultipleImages;

    if (!numImagesChanged)
        return;

    didChangeMultipleImages = (numImagesChanged > 1) ? YES : NO;

    switch (changeTypesMask)
    {
        case kSamplerImageChangeTypeMask_Add:
        {
            changeDescription = @"Add";
        }
        break;

        case kSamplerImageChangeTypeMask_Remove:
        {
            changeDescription = @"Remove";
        }
        break;

        case kSamplerImageChangeTypeMask_Move:
        {
            changeDescription = @"Reorder";
            didChangeMultipleImages = YES;
        }
        break;

        default:
        {
            changeDescription = @"Edit";
        }
        break;
    }

    actionName = [NSString stringWithFormat: @"%@ Sampler %@", changeDescription,
                                            (didChangeMultipleImages) ? @"Images" : @"Image"];

    [[self undoManager] setActionName: actionName];
}

@end
