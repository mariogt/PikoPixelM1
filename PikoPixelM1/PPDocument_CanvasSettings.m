/*
    PPDocument_CanvasSettings.m

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
#import "PPBackgroundPattern.h"
#import "PPGridPattern.h"
#import "NSColor_PPUtilities.h"
#import "PPUserDefaults.h"
#import "PPGeometry.h"


@implementation PPDocument (CanvasSettings)

- (void) setBackgroundPattern: (PPBackgroundPattern *) backgroundPattern
            backgroundImage: (NSImage *) backgroundImage
            shouldDisplayBackgroundImage: (bool) shouldDisplayBackgroundImage
            shouldSmoothenBackgroundImage: (bool) shouldSmoothenBackgroundImage
{
    bool didUpdateBackgroundSettings, oldShouldDisplayBackgroundImage,
            oldShouldSmoothenBackgroundImage;
    PPBackgroundPattern *oldBackgroundPattern;
    NSImage *oldBackgroundImage;
    NSUndoManager *undoManager;

    shouldDisplayBackgroundImage = (shouldDisplayBackgroundImage) ? YES : NO;
    shouldSmoothenBackgroundImage = (shouldSmoothenBackgroundImage) ? YES : NO;

    didUpdateBackgroundSettings = NO;

    oldBackgroundPattern = [[_backgroundPattern retain] autorelease];
    oldBackgroundImage = [[_backgroundImage retain] autorelease];
    oldShouldDisplayBackgroundImage = _shouldDisplayBackgroundImage;
    oldShouldSmoothenBackgroundImage = _shouldSmoothenBackgroundImage;

    if (backgroundPattern
        && ![_backgroundPattern isEqualToBackgroundPattern: backgroundPattern])
    {
        [_backgroundPattern release];
        _backgroundPattern = [backgroundPattern retain];

        didUpdateBackgroundSettings = YES;
    }

    if (backgroundImage != _backgroundImage)
    {
        [_backgroundImage release];
        _backgroundImage = [backgroundImage retain];

        [self destroyCompressedBackgroundImageData];

        didUpdateBackgroundSettings = YES;
    }

    if (_shouldDisplayBackgroundImage != shouldDisplayBackgroundImage)
    {
        _shouldDisplayBackgroundImage = shouldDisplayBackgroundImage;

        didUpdateBackgroundSettings = YES;
    }

    if (_shouldSmoothenBackgroundImage != shouldSmoothenBackgroundImage)
    {
        _shouldSmoothenBackgroundImage = shouldSmoothenBackgroundImage;

        didUpdateBackgroundSettings = YES;
    }

    if (!didUpdateBackgroundSettings)
        return;

    undoManager = [self undoManager];

    if (oldBackgroundImage
        && (oldBackgroundImage != _backgroundImage))
    {
        [[undoManager prepareWithInvocationTarget: self] setupCompressedBackgroundImageData];
    }

    [[undoManager prepareWithInvocationTarget: self]
                                                setBackgroundPattern: oldBackgroundPattern
                                                backgroundImage: oldBackgroundImage
                                                shouldDisplayBackgroundImage:
                                                            oldShouldDisplayBackgroundImage
                                                shouldSmoothenBackgroundImage:
                                                            oldShouldSmoothenBackgroundImage];

    if (![undoManager isUndoing] && ![undoManager isRedoing])
    {
        [undoManager setActionName: NSLocalizedString(@"Change Canvas Background Settings", nil)];
    }

    [self postNotification_UpdatedBackgroundSettings];
}

- (PPBackgroundPattern *) backgroundPattern
{
    return _backgroundPattern;
}

- (NSColor *) backgroundPatternAsColor
{
    return [_backgroundPattern patternFillColor];
}

- (NSImage *) backgroundImage
{
    return _backgroundImage;
}

- (bool) shouldDisplayBackgroundImage
{
    return _shouldDisplayBackgroundImage;
}

- (bool) shouldSmoothenBackgroundImage
{
    return _shouldSmoothenBackgroundImage;
}

- (void) toggleBackgroundImageVisibility
{
    [self setBackgroundPattern: _backgroundPattern
            backgroundImage: _backgroundImage
            shouldDisplayBackgroundImage: (_shouldDisplayBackgroundImage) ? NO : YES
            shouldSmoothenBackgroundImage: _shouldSmoothenBackgroundImage];

    [[self undoManager]
            setActionName: (_shouldDisplayBackgroundImage) ? NSLocalizedString(@"Show Canvas Background Image", nil)
                                                            : NSLocalizedString(@"Hide Canvas Background Image", nil)];
}

- (void) toggleBackgroundImageSmoothing
{
    [self setBackgroundPattern: _backgroundPattern
            backgroundImage: _backgroundImage
            shouldDisplayBackgroundImage: _shouldDisplayBackgroundImage
            shouldSmoothenBackgroundImage: (_shouldSmoothenBackgroundImage) ? NO : YES];

    [[self undoManager]
            setActionName: (_shouldSmoothenBackgroundImage) ?
     NSLocalizedString(@"Enable Background Image Smoothing", nil) :
     NSLocalizedString(@"Disable Background Image Smoothing", nil)];
}

- (void) setGridPattern: (PPGridPattern *) gridPattern
            shouldDisplayGrid: (bool) shouldDisplayGrid
{
    bool didUpdateGridSettings, oldShouldDisplayGrid;
    PPGridPattern *oldGridPattern;
    NSUndoManager *undoManager;

    if (!gridPattern)
    {
        gridPattern = [PPUserDefaults gridPattern];
    }

    shouldDisplayGrid = (shouldDisplayGrid) ? YES : NO;

    didUpdateGridSettings = NO;

    oldGridPattern = [[_gridPattern retain] autorelease];
    oldShouldDisplayGrid = _shouldDisplayGrid;

    if (![_gridPattern isEqualToGridPattern: gridPattern])
    {
        [_gridPattern release];
        _gridPattern = [gridPattern retain];

        didUpdateGridSettings = YES;
    }

    if (_shouldDisplayGrid != shouldDisplayGrid)
    {
        _shouldDisplayGrid = shouldDisplayGrid;

        didUpdateGridSettings = YES;
    }

    if (!didUpdateGridSettings)
        return;

    undoManager = [self undoManager];
    [[undoManager prepareWithInvocationTarget: self] setGridPattern: oldGridPattern
                                                        shouldDisplayGrid: oldShouldDisplayGrid];

    if (![undoManager isUndoing] && ![undoManager isRedoing])
    {
        [undoManager setActionName: NSLocalizedString(@"Change Canvas Grid Settings", nil)];
    }

    [self postNotification_UpdatedGridSettings];
}

- (PPGridPattern *) gridPattern
{
    return _gridPattern;
}

- (bool) shouldDisplayGrid
{
    return _shouldDisplayGrid;
}

- (void) toggleGridVisibility
{
    [self setGridPattern: _gridPattern
            shouldDisplayGrid: (_shouldDisplayGrid) ? NO : YES];

    [[self undoManager]
            setActionName: (_shouldDisplayGrid) ? NSLocalizedString(@"Show Canvas Grid", nil) : NSLocalizedString(@"Hide Canvas Grid", nil)];
}

- (PPGridType) pixelGridPatternType
{
    return [_gridPattern pixelGridType];
}

- (void) togglePixelGridPatternType
{
    PPGridPattern *toggledGridPattern;

    if (!_shouldDisplayGrid)
        return;

    toggledGridPattern = [_gridPattern gridPatternByTogglingPixelGridType];

    if (!toggledGridPattern)
        goto ERROR;

    [self setGridPattern: toggledGridPattern
            shouldDisplayGrid: _shouldDisplayGrid];

    [[self undoManager] setActionName: NSLocalizedString(@"Switch Canvas Grid Type", nil)];

    return;

ERROR:
    return;
}

- (bool) gridPatternShouldDisplayGuidelines
{
    return [_gridPattern shouldDisplayGuidelines];
}

- (void) toggleGridGuidelinesVisibility
{
    PPGridPattern *toggledGridPattern;

    if (!_shouldDisplayGrid)
        return;

    toggledGridPattern = [_gridPattern gridPatternByTogglingGuidelinesVisibility];

    if (!toggledGridPattern)
        goto ERROR;

    [self setGridPattern: toggledGridPattern
            shouldDisplayGrid: _shouldDisplayGrid];

    [[self undoManager]
            setActionName: ([self gridPatternShouldDisplayGuidelines]) ?
     NSLocalizedString(@"Show Canvas Grid Guidelines", nil) : NSLocalizedString(@"Hide Canvas Grid Guidelines", nil)];

    return;

ERROR:
    return;
}

- (bool) shouldDisplayGridAndGridGuidelines
{
    return (_shouldDisplayGrid && [_gridPattern shouldDisplayGuidelines]) ? YES : NO;
}

- (NSRect) gridGuidelineBoundsCoveredByRect: (NSRect) rect
{
    return PPGeometry_GridBoundsCoveredByRectOnCanvasOfSizeWithGridOfSpacingSize(
                                                            rect,
                                                            _canvasFrame.size,
                                                            [_gridPattern guidelineSpacingSize]);
}

- (bool) hasCustomCanvasSettings
{
    return (_backgroundImage
            || ![_backgroundPattern isEqualToBackgroundPattern:
                                                        [PPUserDefaults backgroundPattern]]
            || ![_gridPattern isEqualToGridPattern: [PPUserDefaults gridPattern]]) ? YES : NO;
}

@end
