/*
    PPDocument.m

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

#import "PPDocumentWindowController.h"
#import "PPDocumentLayer.h"
#import "PPBackgroundPattern.h"
#import "PPGridPattern.h"
#import "NSImage_PPUtilities.h"
#import "NSBitmapImageRep_PPUtilities.h"
#import "PPUserDefaults.h"
#import "PPExportPanelAccessoryViewController.h"
#import "PPDocumentWindowController.h"
#import "PPGeometry.h"
#import "NSColor_PPUtilities.h"


#define kDocumentCodingVersion_Current                  kDocumentCodingVersion_1

// Coding Version 1
// - Background image is now encoded as compressed data (NSData) instead of an NSImage object
// - Grid pattern settings are now stored as an object (PPGridPattern)
// - Added Layer Blending Mode (v1.0 beta8)
#define kDocumentCodingVersion_1                        1
#define kDocumentCodingKey_CodingVersion                @"CodingVersion"
#define kDocumentCodingKey_CanvasFrame                  @"CanvasFrame"
#define kDocumentCodingKey_Layers                       @"Layers"
#define kDocumentCodingKey_LayerBlendingMode            @"LayerBlendingMode"
#define kDocumentCodingKey_IndexOfDrawingLayer          @"IndexOfDrawingLayer"
#define kDocumentCodingKey_FillColor                    @"FillColor"
#define kDocumentCodingKey_SelectionMaskData            @"SelectionMaskData"
#define kDocumentCodingKey_BackgroundPattern            @"BackgroundPattern"
#define kDocumentCodingKey_BackgroundImageData          @"BackgroundImageData"
#define kDocumentCodingKey_BackgroundImageVisibility    @"BackgroundImageVisibility"
#define kDocumentCodingKey_BackgroundImageSmoothing     @"BackgroundImageSmoothing"
#define kDocumentCodingKey_GridPattern                  @"GridPattern"
#define kDocumentCodingKey_GridVisibility               @"GridVisibility"
#define kDocumentCodingKey_SamplerImages                @"SamplerImages"
#define kDocumentCodingKey_NonnativeFileType            @"NonnativeFileType"

// Coding Version 0
// Used in PikoPixel 1.0 beta4 & earlier
#define kDocumentCodingVersion_0                        0
#define kDocumentCodingKey_v0_BackgroundImage           @"BackgroundImage"
#define kDocumentCodingKey_v0_GridType                  @"GridType"
#define kDocumentCodingKey_v0_GridColor                 @"GridColor"


#define kDefaultFillColor                               [[NSColor blackColor] ppSRGBColor]

#define kDefaultBackgroundImageVisibility               YES
#define kDefaultBackgroundImageSmoothing                NO


@interface PPDocument (PrivateMethods)

- (bool) setupCanvasBitmapsAndImagesOfSize: (NSSize) canvasSize;

@end

@implementation PPDocument

- (id) init
{
    self = [super init];

    if (!self)
        goto ERROR;

    _layers = [[NSMutableArray array] retain];
    _samplerImages = [[NSMutableArray array] retain];

    if (!_layers || !_samplerImages)
    {
        goto ERROR;
    }

    _indexOfDrawingLayer = -1;
    _activeToolType = -1; // setActiveToolType: doesn't set _activeTool unless value changes

    [self setSelectedToolType: kPPToolType_Pencil];
    [self setActiveToolType: kPPToolType_Pencil];

    [self setFillColor: kDefaultFillColor];

    [self setBackgroundPattern: [PPUserDefaults backgroundPattern]
            backgroundImage: nil
            shouldDisplayBackgroundImage: kDefaultBackgroundImageVisibility
            shouldSmoothenBackgroundImage: kDefaultBackgroundImageSmoothing];

    [self setGridPattern: [PPUserDefaults gridPattern]
            shouldDisplayGrid: [PPUserDefaults gridVisibility]];

    [self setupSamplerImageIndexes];

    [[self undoManager] removeAllActions];

    return self;

ERROR:
    [self release];

    return nil;
}

- (void) dealloc
{
    if (_isPerformingInteractiveMove)
    {
        [self finishInteractiveMove];
    }

    [self removeAllLayers]; // also removes all objects in _cached(Over|Under)layersImageObjects

    [_layers release];

    [_drawingLayer release];
    [_drawingLayerBitmap release];
    [_drawingLayerImage release];

    [_dissolvedDrawingLayerBitmap release];
    [_dissolvedDrawingLayerThumbnailImage release];

    [_mergedVisibleLayersBitmap release];
    [_mergedVisibleLayersThumbnailImage release];

    [_mergedVisibleLayersLinearBitmap release];

    [_drawingMask release];

    [_drawingUndoBitmap release];

    [_selectionMask release];

    [_interactiveEraseMask release];

    // _activeTool not retained

    [_fillColor release];
    [_fillColor_sRGB release];

    [_backgroundPattern release];
    [_backgroundImage release];
    [_compressedBackgroundImageData release];

    [_gridPattern release];

    [_samplerImages release];

    [_exportPanelViewController release];

    [super dealloc];
}

- (bool) setupNewPPDocumentWithCanvasSize: (NSSize) canvasSize
{
    PPDocumentLayer *layer;

    layer = [PPDocumentLayer layerWithSize: canvasSize andName: @"Main Layer"];

    if (!layer)
        goto ERROR;

    if (![self setLayers: [NSArray arrayWithObject: layer]])
    {
        goto ERROR;
    }

    [[self undoManager] removeAllActions];

    return YES;

ERROR:
    return NO;
}

- (bool) loadFromPPDocument: (PPDocument *) ppDocument
{
    if (!ppDocument)
        goto ERROR;

    if (NSIsEmptyRect(ppDocument->_canvasFrame)
        || ![ppDocument->_layers count])
    {
        goto ERROR;
    }

    if (![self setLayers: ppDocument->_layers])
    {
        goto ERROR;
    }

    [self setLayerBlendingMode: ppDocument->_layerBlendingMode];

    [self setSelectionMask: ppDocument->_selectionMask];

    [self selectDrawingLayerAtIndex: ppDocument->_indexOfDrawingLayer];

    [self setFillColor: ppDocument->_fillColor];

    [self setBackgroundPattern: ppDocument->_backgroundPattern
            backgroundImage: ppDocument->_backgroundImage
            shouldDisplayBackgroundImage: ppDocument->_shouldDisplayBackgroundImage
            shouldSmoothenBackgroundImage: ppDocument->_shouldSmoothenBackgroundImage];

    if (ppDocument->_compressedBackgroundImageData)
    {
        _compressedBackgroundImageData = [ppDocument->_compressedBackgroundImageData retain];
    }

    [self setGridPattern: ppDocument->_gridPattern
            shouldDisplayGrid: ppDocument->_shouldDisplayGrid];

    [self setSamplerImages: ppDocument->_samplerImages];

    [self setLayerOperationTarget: ppDocument->_layerOperationTarget];

    [self setFileType: [ppDocument fileType]];

    [[self undoManager] removeAllActions];

    return YES;

ERROR:
    return NO;
}

- (bool) loadFromImageBitmap: (NSBitmapImageRep *) bitmap
            withFileType: (NSString *) fileType
{
    NSSize canvasSize;
    PPDocumentLayer *layer;

    if (![bitmap ppIsImageBitmap])
    {
        goto ERROR;
    }

    canvasSize = [bitmap ppSizeInPixels];

    if (PPGeometry_SizeExceedsDimension(canvasSize, kMaxCanvasDimension))
    {
        goto ERROR;
    }

    layer = [PPDocumentLayer layerWithSize: canvasSize
                                name: @"Main Layer"
                                tiffData: [bitmap TIFFRepresentation]];

    if (!layer)
        goto ERROR;

    if (![self setLayers: [NSArray arrayWithObject: layer]])
    {
        goto ERROR;
    }

    [self selectDrawingLayerAtIndex: 0];

    [self setFillColor: kDefaultFillColor];

    [self setBackgroundPattern: [PPUserDefaults backgroundPattern]
            backgroundImage: nil
            shouldDisplayBackgroundImage: kDefaultBackgroundImageVisibility
            shouldSmoothenBackgroundImage: kDefaultBackgroundImageSmoothing];

    [self setGridPattern: [PPUserDefaults gridPattern]
            shouldDisplayGrid: [PPUserDefaults gridVisibility]];

    [self setSamplerImages: nil];

    [self setLayerOperationTarget: 0];

    [self setFileType: fileType];

    [[self undoManager] removeAllActions];

    return YES;

ERROR:
    return NO;
}

- (bool) needToSetCanvasSize
{
    return (NSIsEmptyRect(_canvasFrame)) ? YES : NO;
}

- (NSSize) canvasSize
{
    return _canvasFrame.size;
}

- (bool) resizeCanvasForCurrentLayers
{
    PPDocumentLayer *bottomLayer;
    NSSize newCanvasSize;

    if (![_layers count])
    {
        goto ERROR;
    }

    bottomLayer = [_layers objectAtIndex: 0];

    if (!bottomLayer)
        goto ERROR;

    newCanvasSize = [bottomLayer size];

    if ((newCanvasSize.width < kMinCanvasDimension)
        || (newCanvasSize.width > kMaxCanvasDimension)
        || (newCanvasSize.height < kMinCanvasDimension)
        || (newCanvasSize.height > kMaxCanvasDimension))
    {
        goto ERROR;
    }

    if (![self setupCanvasBitmapsAndImagesOfSize: newCanvasSize])
    {
        goto ERROR;
    }

    _canvasFrame.size = newCanvasSize;

    return YES;

ERROR:
    return NO;
}

- (NSBitmapImageRep *) mergedVisibleLayersBitmap
{
    return _mergedVisibleLayersBitmap;
}

- (NSImage *) mergedVisibleLayersThumbnailImage
{
    return _mergedVisibleLayersThumbnailImage;
}

- (NSBitmapImageRep *) drawingLayerBitmap
{
    return _drawingLayerBitmap;
}

- (NSImage *) drawingLayerThumbnailImage
{
    return _drawingLayerImage;
}

- (NSBitmapImageRep *) dissolvedDrawingLayerBitmap
{
    return _dissolvedDrawingLayerBitmap;
}

- (NSImage *) dissolvedDrawingLayerThumbnailImage
{
    return _dissolvedDrawingLayerThumbnailImage;
}

- (NSBitmapImageRep *) mergedVisibleLayersBitmapUsingExportPanelSettings
{
    unsigned scalingFactor;
    PPGridPattern *gridPattern = nil;
    PPBackgroundPattern *backgroundPattern = nil;
    bool shouldDrawGrid, shouldDrawBackgroundPattern, shouldDrawBackgroundImage;
    NSBitmapImageRep *exportBitmap;

    if (![_exportPanelViewController getScalingFactor: &scalingFactor
                                        gridPattern: &gridPattern
                                        backgroundPattern: &backgroundPattern
                                        backgroundImageFlag: &shouldDrawBackgroundImage])
    {
        goto ERROR;
    }

    shouldDrawGrid = (gridPattern != nil) ? YES : NO;
    shouldDrawBackgroundPattern = (backgroundPattern != nil) ? YES : NO;

    if ((scalingFactor == 1) && (!shouldDrawGrid))
    {
        exportBitmap = _mergedVisibleLayersBitmap;
    }
    else
    {
        exportBitmap = [_mergedVisibleLayersBitmap ppImageBitmapScaledByFactor: scalingFactor
                                                    shouldDrawGrid: shouldDrawGrid
                                                    gridType: [gridPattern pixelGridType]
                                                    gridColor: [gridPattern pixelGridColor]];

        if (!exportBitmap)
            goto ERROR;

        if (shouldDrawGrid && [gridPattern shouldDisplayGuidelines])
        {
            [exportBitmap ppDrawImageGuidelinesInBounds: [exportBitmap ppFrameInPixels]
                            topLeftPhase: NSZeroPoint
                            unscaledSpacingSize: [gridPattern guidelineSpacingSize]
                            scalingFactor: scalingFactor
                            guidelinePixelValue:
                                    [[gridPattern guidelineColor] ppImageBitmapPixelValue]];
        }
    }

    if (shouldDrawBackgroundPattern || (shouldDrawBackgroundImage && _backgroundImage))
    {
        NSColor *backgroundColor =
                    (shouldDrawBackgroundPattern) ? [backgroundPattern patternFillColor] : nil;
        NSImage *backgroundImage = (shouldDrawBackgroundImage) ? _backgroundImage : nil;
        NSImageInterpolation backgroundImageInterpolation =
                                    (_shouldSmoothenBackgroundImage) ?
                                            NSImageInterpolationLow : NSImageInterpolationNone;

        exportBitmap =
                [exportBitmap ppImageBitmapCompositedWithBackgroundColor: backgroundColor
                                andBackgroundImage: backgroundImage
                                backgroundImageInterpolation: backgroundImageInterpolation];

        if (!exportBitmap)
            goto ERROR;
    }

    return exportBitmap;

ERROR:
    return _mergedVisibleLayersBitmap;
}

- (PPDocumentWindowController *) ppDocumentWindowController
{
    NSArray *windowControllers;
    PPDocumentWindowController *windowController;

    windowControllers = [self windowControllers];

    if (![windowControllers count])
    {
        return nil;
    }

    windowController = [windowControllers objectAtIndex: 0];

    if (![windowController isKindOfClass: [PPDocumentWindowController class]])
    {
        return nil;
    }

    return windowController;
}

- (void) setupCompressedBackgroundImageData
{
    if (!_backgroundImage)
    {
        if (_compressedBackgroundImageData)
        {
            [self destroyCompressedBackgroundImageData];
        }

        return;
    }

    if (!_compressedBackgroundImageData)
    {
        _compressedBackgroundImageData = [[_backgroundImage ppCompressedBitmapData] retain];
    }
}

- (void) destroyCompressedBackgroundImageData
{
    if (!_compressedBackgroundImageData)
        return;

    [_compressedBackgroundImageData autorelease];
    _compressedBackgroundImageData = nil;
}

- (bool) sourceBitmapHasAnimationFrames
{
    return _sourceBitmapHasAnimationFrames;
}

#pragma mark NSDocument overrides

- (void) makeWindowControllers
{
    [self addWindowController: [PPDocumentWindowController controller]];
}

#pragma mark NSCoding protocol

- (id) initWithCoder: (NSCoder *) aDecoder
{
    int codingVersion;
    NSRect canvasFrame;
    NSArray *layers;
    NSImage *backgroundImage = nil;
    PPGridPattern *gridPattern = nil;
    NSData *backgroundImageData = nil;

    self = [self init];

    if (!self)
        goto ERROR;

    codingVersion = [aDecoder decodeIntForKey: kDocumentCodingKey_CodingVersion];

    canvasFrame = [aDecoder decodeRectForKey: kDocumentCodingKey_CanvasFrame];
    layers = [aDecoder decodeObjectForKey: kDocumentCodingKey_Layers];

    if (NSIsEmptyRect(canvasFrame) || ![layers count])
    {
        goto ERROR;
    }

    if (![self setLayers: layers])
    {
        goto ERROR;
    }

    if ([aDecoder containsValueForKey: kDocumentCodingKey_LayerBlendingMode])
    {
        [self setLayerBlendingMode:
                            [aDecoder decodeIntForKey: kDocumentCodingKey_LayerBlendingMode]];
    }

    [self selectDrawingLayerAtIndex:
                            [aDecoder decodeIntForKey: kDocumentCodingKey_IndexOfDrawingLayer]];

    if ([aDecoder containsValueForKey: kDocumentCodingKey_SelectionMaskData])
    {
        NSData *selectionMaskData =
                        [aDecoder decodeObjectForKey: kDocumentCodingKey_SelectionMaskData];

        if (selectionMaskData)
        {
            [self setSelectionMask: [NSBitmapImageRep imageRepWithData: selectionMaskData]];
        }
    }

    [self setFillColor: [aDecoder decodeObjectForKey: kDocumentCodingKey_FillColor]];

    if (codingVersion == kDocumentCodingVersion_0)
    {
        // Coding version 0

        //      Background image encoded as NSImage

        backgroundImage = [aDecoder decodeObjectForKey: kDocumentCodingKey_v0_BackgroundImage];

        //      Grid pattern settings encoded separately

        gridPattern =
            [PPGridPattern gridPatternWithPixelGridType:
                                [aDecoder decodeIntForKey: kDocumentCodingKey_v0_GridType]
                            pixelGridColor:
                                [aDecoder decodeObjectForKey: kDocumentCodingKey_v0_GridColor]];
    }
    else
    {
        // Coding version 1

        //      Background image encoded as NSData

        backgroundImageData =
                        [aDecoder decodeObjectForKey: kDocumentCodingKey_BackgroundImageData];

        if (backgroundImageData)
        {
            backgroundImage =
                [NSImage ppImageWithBitmap:
                                    [NSBitmapImageRep imageRepWithData: backgroundImageData]];
        }

        //      Grid pattern settings encoded as object (PPGridPattern)

        gridPattern = [aDecoder decodeObjectForKey: kDocumentCodingKey_GridPattern];
    }

    [self setBackgroundPattern:
                        [aDecoder decodeObjectForKey: kDocumentCodingKey_BackgroundPattern]
            backgroundImage: backgroundImage
            shouldDisplayBackgroundImage:
                    [aDecoder decodeBoolForKey: kDocumentCodingKey_BackgroundImageVisibility]
            shouldSmoothenBackgroundImage:
                    [aDecoder decodeBoolForKey: kDocumentCodingKey_BackgroundImageSmoothing]];

    if (_backgroundImage)
    {
        if (backgroundImageData)
        {
            _compressedBackgroundImageData = [backgroundImageData retain];
        }
        else
        {
            [self setupCompressedBackgroundImageData];
        }
    }

    [self setGridPattern: gridPattern
            shouldDisplayGrid: [aDecoder decodeBoolForKey: kDocumentCodingKey_GridVisibility]];

    if ([aDecoder containsValueForKey: kDocumentCodingKey_SamplerImages])
    {
        NSArray *samplerImages =
                            [aDecoder decodeObjectForKey: kDocumentCodingKey_SamplerImages];

        if (samplerImages)
        {
            [self setSamplerImages: samplerImages];
        }
    }

    if ([aDecoder containsValueForKey: kDocumentCodingKey_NonnativeFileType])
    {
        [self setFileType: [aDecoder decodeObjectForKey: kDocumentCodingKey_NonnativeFileType]];
    }

    [[self undoManager] removeAllActions];

    return self;

ERROR:
    [self release];

    return nil;
}

- (void) encodeWithCoder: (NSCoder *) coder
{
    [coder encodeInt: kDocumentCodingVersion_Current forKey: kDocumentCodingKey_CodingVersion];

    [coder encodeRect: _canvasFrame forKey: kDocumentCodingKey_CanvasFrame];
    [coder encodeObject: _layers forKey: kDocumentCodingKey_Layers];
    [coder encodeInt: _indexOfDrawingLayer forKey: kDocumentCodingKey_IndexOfDrawingLayer];

    if (_layerBlendingMode != kPPLayerBlendingMode_Standard)
    {
        [coder encodeInt: _layerBlendingMode forKey: kDocumentCodingKey_LayerBlendingMode];
    }

    if (_hasSelection)
    {
        [coder encodeObject: [_selectionMask ppCompressedTIFFData]
                forKey: kDocumentCodingKey_SelectionMaskData];
    }

    [coder encodeObject: _fillColor_sRGB forKey: kDocumentCodingKey_FillColor];
    [coder encodeObject: _backgroundPattern forKey: kDocumentCodingKey_BackgroundPattern];

    if (_backgroundImage)
    {
        if (!_compressedBackgroundImageData)
        {
            [self setupCompressedBackgroundImageData];
        }

        [coder encodeObject: _compressedBackgroundImageData
                forKey: kDocumentCodingKey_BackgroundImageData];
    }

    [coder encodeBool: _shouldDisplayBackgroundImage
                forKey: kDocumentCodingKey_BackgroundImageVisibility];
    [coder encodeBool: _shouldSmoothenBackgroundImage
                forKey: kDocumentCodingKey_BackgroundImageSmoothing];
    [coder encodeObject: _gridPattern forKey: kDocumentCodingKey_GridPattern];
    [coder encodeBool: _shouldDisplayGrid forKey: kDocumentCodingKey_GridVisibility];

    if (_numSamplerImages > 0)
    {
        [coder encodeObject: _samplerImages forKey: kDocumentCodingKey_SamplerImages];
    }

    // preserve nonnative filetype name when autosaving

    if (_saveFormat == kPPDocumentSaveFormat_Autosave)
    {
        NSString *fileType = [self fileType];

        if (fileType && ![fileType isEqualToString: kNativeFileFormatTypeName])
        {
            [coder encodeObject: fileType forKey: kDocumentCodingKey_NonnativeFileType];
        }
    }
}

#pragma mark Private methods

- (bool) setupCanvasBitmapsAndImagesOfSize: (NSSize) canvasSize
{
    NSBitmapImageRep *oldMergedVisibleLayersLinearBitmap, *mergedVisibleLayersBitmap,
                        *dissolvedDrawingLayerBitmap, *drawingMask, *drawingUndoBitmap,
                        *interactiveEraseMask;
    NSImage *mergedVisibleLayersThumbnailImage, *dissolvedDrawingLayerThumbnailImage;

    // setupLayerBlendingBitmapOfSize: method may change the value of
    // _mergedVisibleLayersLinearBitmap - remember the old value, so it can be restored in case
    // of an error later
    oldMergedVisibleLayersLinearBitmap = [[_mergedVisibleLayersLinearBitmap retain] autorelease];

    if (![self setupLayerBlendingBitmapOfSize: canvasSize])
    {
        goto ERROR;
    }

    if (!_mergedVisibleLayersBitmap
        || !NSEqualSizes([_mergedVisibleLayersBitmap ppSizeInPixels], canvasSize))
    {
        mergedVisibleLayersBitmap = [NSBitmapImageRep ppImageBitmapOfSize: canvasSize];
        mergedVisibleLayersThumbnailImage =
                                    [NSImage ppImageWithBitmap: mergedVisibleLayersBitmap];

        dissolvedDrawingLayerBitmap = [NSBitmapImageRep ppImageBitmapOfSize: canvasSize];
        dissolvedDrawingLayerThumbnailImage =
                                    [NSImage ppImageWithBitmap: dissolvedDrawingLayerBitmap];

        drawingMask = [NSBitmapImageRep ppMaskBitmapOfSize: canvasSize];

        drawingUndoBitmap = [NSBitmapImageRep ppImageBitmapOfSize: canvasSize];

        interactiveEraseMask = [NSBitmapImageRep ppMaskBitmapOfSize: canvasSize];

        if (!mergedVisibleLayersBitmap || !mergedVisibleLayersThumbnailImage
            || !dissolvedDrawingLayerBitmap || !dissolvedDrawingLayerThumbnailImage
            || !drawingMask || !drawingUndoBitmap || !interactiveEraseMask)
        {
            goto ERROR;
        }

        // set up the selection mask as the last error check, because the
        // setupSelectionMaskBitmapOfSize: method also sets the values of other instance
        // members, which would need to be restored if an error happened later on
        if (![self setupSelectionMaskBitmapOfSize: canvasSize])
        {
            goto ERROR;
        }

        [_mergedVisibleLayersBitmap autorelease];
        _mergedVisibleLayersBitmap = [mergedVisibleLayersBitmap retain];

        [_mergedVisibleLayersThumbnailImage autorelease];
        _mergedVisibleLayersThumbnailImage = [mergedVisibleLayersThumbnailImage retain];

        [_dissolvedDrawingLayerBitmap autorelease];
        _dissolvedDrawingLayerBitmap = [dissolvedDrawingLayerBitmap retain];

        [_dissolvedDrawingLayerThumbnailImage autorelease];
        _dissolvedDrawingLayerThumbnailImage = [dissolvedDrawingLayerThumbnailImage retain];

        [_drawingMask autorelease];
        _drawingMask = [drawingMask retain];

        [_drawingUndoBitmap autorelease];
        _drawingUndoBitmap = [drawingUndoBitmap retain];

        [_interactiveEraseMask autorelease];
        _interactiveEraseMask = [interactiveEraseMask retain];
    }
    else
    {
        if (![self setupSelectionMaskBitmapOfSize: canvasSize])
        {
            goto ERROR;
        }

        [_mergedVisibleLayersBitmap ppClearBitmap];
        [_mergedVisibleLayersThumbnailImage recache];

        [_dissolvedDrawingLayerBitmap ppClearBitmap];
        [_dissolvedDrawingLayerThumbnailImage recache];

        [_drawingMask ppClearBitmap];

        [_drawingUndoBitmap ppClearBitmap];

        [_interactiveEraseMask ppClearBitmap];
    }

    return YES;

ERROR:
    // restore the old value of _mergedVisibleLayersLinearBitmap if it was changed (by the call
    // to setupLayerBlendingBitmapOfSize:)
    if (_mergedVisibleLayersLinearBitmap != oldMergedVisibleLayersLinearBitmap)
    {
        [_mergedVisibleLayersLinearBitmap autorelease];
        _mergedVisibleLayersLinearBitmap = [oldMergedVisibleLayersLinearBitmap retain];
    }

    return NO;
}

@end
