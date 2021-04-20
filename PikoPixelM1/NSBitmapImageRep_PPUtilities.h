/*
    NSBitmapImageRep_PPUtilities.h

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
#import "NSImageRep_PPUtilities.h"
#import "PPBitmapPixelTypes.h"
#import "PPGridType.h"


@interface NSBitmapImageRep (PPUtilities)

- (bool) ppIsEqualToBitmap: (NSBitmapImageRep *) comparisonBitmap;

- (bool) ppImportedBitmapHasAnimationFrames;

- (NSData *) ppCompressedTIFFData;
- (NSData *) ppCompressedTIFFDataFromBounds: (NSRect) bounds;

- (NSData *) ppCompressedPNGData;

- (void) ppSetAsCurrentGraphicsContext;
- (void) ppRestoreGraphicsContext;

- (void) ppClearBitmap;
- (void) ppClearBitmapInBounds: (NSRect) bounds;

- (void) ppCopyFromBitmap: (NSBitmapImageRep *) sourceBitmap
            toPoint: (NSPoint) targetPoint;

- (void) ppCopyFromBitmap: (NSBitmapImageRep *) sourceBitmap
            inRect: (NSRect) sourceRect
            toPoint: (NSPoint) targetPoint;

- (void) ppCenteredCopyFromBitmap: (NSBitmapImageRep *) sourceBitmap;

- (NSBitmapImageRep *) ppBitmapCroppedToBounds: (NSRect) croppingBounds;

//  ppShallowDuplicateFromBounds: returns an autoreleased copy that uses the same bitmapData
// pointer as the original (depending on croppingBounds, it may be offset).
//  It's faster than ppBitmapCroppedToBounds:, which allocates a new buffer and copies the
// bitmapData. It should generally be used where the copy is just for reading, as writing to
// the copy's bitmapData will overwrite the original's. The copy should not outlive the
// original, as the copy's bitmapData pointer will become invalid when the original is
// deallocated.
- (NSBitmapImageRep *) ppShallowDuplicateFromBounds: (NSRect) croppingBounds;

- (NSBitmapImageRep *) ppBitmapResizedToSize: (NSSize) newSize shouldScale: (bool) shouldScale;

- (NSBitmapImageRep *) ppBitmapMirroredHorizontally;
- (NSBitmapImageRep *) ppBitmapMirroredVertically;

- (NSBitmapImageRep *) ppBitmapRotated90Clockwise;
- (NSBitmapImageRep *) ppBitmapRotated90Counterclockwise;
- (NSBitmapImageRep *) ppBitmapRotated180;

@end

@interface NSBitmapImageRep (PPUtilities_ImageBitmaps)

+ (NSBitmapImageRep *) ppImageBitmapOfSize: (NSSize) size;

+ (NSBitmapImageRep *) ppImageBitmapWithImportedData: (NSData *) importedData;

+ (NSBitmapImageRep *) ppImageBitmapFromImageResource: (NSString *) imageName;

- (bool) ppIsImageBitmap;
- (bool) ppIsImageBitmapAndSameSizeAsMaskBitmap: (NSBitmapImageRep *) maskBitmap;

- (NSColor *) ppImageColorAtPoint: (NSPoint) point;

- (bool) ppImageBitmapHasTransparentPixels;

- (void) ppMaskedFillUsingMask: (NSBitmapImageRep *) maskBitmap
            inBounds: (NSRect) fillBounds
            fillPixelValue: (PPImageBitmapPixel) fillPixelValue;

- (void) ppMaskedEraseUsingMask: (NSBitmapImageRep *) maskBitmap;

- (void) ppMaskedEraseUsingMask: (NSBitmapImageRep *) maskBitmap
            inBounds: (NSRect) eraseBounds;

- (void) ppMaskedCopyFromImageBitmap: (NSBitmapImageRep *) sourceBitmap
            usingMask: (NSBitmapImageRep *) maskBitmap;

- (void) ppMaskedCopyFromImageBitmap: (NSBitmapImageRep *) sourceBitmap
            usingMask: (NSBitmapImageRep *) maskBitmap
            inBounds: (NSRect) copyBounds;

- (void) ppMaskedCopyFromImageBitmap:(NSBitmapImageRep *) sourceBitmap
            usingMask: (NSBitmapImageRep *) maskBitmap
            toPoint: (NSPoint) targetPoint;

- (void) ppScaledCopyFromImageBitmap: (NSBitmapImageRep *) sourceBitmap
            inRect: (NSRect) sourceRect
            toPoint: (NSPoint) destinationPoint
            scalingFactor: (unsigned) scalingFactor;

- (void) ppScaledCopyFromImageBitmap: (NSBitmapImageRep *) sourceBitmap
            inRect: (NSRect) sourceRect
            toPoint: (NSPoint) destinationPoint
            scalingFactor: (unsigned) scalingFactor
            gridType: (PPGridType) gridType
            gridPixelValue: (PPImageBitmapPixel) gridPixelValue;

- (NSBitmapImageRep *) ppImageBitmapWithMaxDimension: (float) maxDimension;

- (NSBitmapImageRep *) ppImageBitmapCompositedWithBackgroundColor: (NSColor *) backgroundColor
                        andBackgroundImage: (NSImage *) backgroundImage
                        backgroundImageInterpolation:
                                        (NSImageInterpolation) backgroundImageInterpolation;

- (NSBitmapImageRep *) ppImageBitmapDissolvedToOpacity: (float) opacity;
- (NSBitmapImageRep *) ppImageBitmapMaskedWithMask: (NSBitmapImageRep *) maskBitmap;

- (NSBitmapImageRep *) ppImageBitmapScaledByFactor: (unsigned) scalingFactor
                        shouldDrawGrid: (bool) shouldDrawGrid
                        gridType: (PPGridType) gridType
                        gridColor: (NSColor *) gridColor;

- (NSBitmapImageRep *) ppMaskBitmapForVisiblePixelsInImageBitmap;

- (void) ppDrawImageGuidelinesInBounds: (NSRect) drawBounds
            topLeftPhase: (NSPoint) topLeftPhase
            unscaledSpacingSize: (NSSize) unscaledSpacingSize
            scalingFactor: (unsigned) scalingFactor
            guidelinePixelValue: (PPImageBitmapPixel) guidelinePixelValue;

@end

@interface NSBitmapImageRep (PPUtilities_LinearRGB16Bitmaps)

+ (NSBitmapImageRep *) ppLinearRGB16BitmapOfSize: (NSSize) size;

- (NSBitmapImageRep *) ppLinearRGB16BitmapFromImageBitmap;
- (NSBitmapImageRep *) ppImageBitmapFromLinearRGB16Bitmap;

- (bool) ppIsLinearRGB16Bitmap;

- (void) ppLinearCopyFromImageBitmap: (NSBitmapImageRep *) sourceBitmap
            inBounds: (NSRect) bounds;

- (void) ppLinearCopyToImageBitmap: (NSBitmapImageRep *) destinationBitmap
            inBounds: (NSRect) bounds;

- (void) ppLinearBlendFromLinearBitmapUnderneath: (NSBitmapImageRep *) sourceBitmap
            sourceOpacity: (float) sourceOpacity
            inBounds: (NSRect) blendingBounds;

- (void) ppLinearCopyFromLinearBitmap: (NSBitmapImageRep *) sourceBitmap
            opacity: (float) opacity
            inBounds: (NSRect) copyBounds;

@end

@interface NSBitmapImageRep (PPUtilities_MaskBitmaps)

+ (NSBitmapImageRep *) ppMaskBitmapOfSize: (NSSize) size;

- (bool) ppIsMaskBitmap;

- (NSRect) ppMaskBounds;
- (NSRect) ppMaskBoundsInRect: (NSRect) bounds;

- (bool) ppMaskIsNotEmpty;
- (bool) ppMaskCoversAllPixels;
- (bool) ppMaskCoversPoint: (NSPoint) point;

- (void) ppMaskPixelsInBounds: (NSRect) bounds;

- (void) ppIntersectMaskWithMaskBitmap: (NSBitmapImageRep *) maskBitmap;

- (void) ppIntersectMaskWithMaskBitmap: (NSBitmapImageRep *) maskBitmap
            inBounds: (NSRect) intersectBounds;

- (void) ppSubtractMaskBitmap: (NSBitmapImageRep *) maskBitmap;

- (void) ppSubtractMaskBitmap: (NSBitmapImageRep *) maskBitmap
            inBounds: (NSRect) subtractBounds;

- (void) ppMergeMaskWithMaskBitmap: (NSBitmapImageRep *) maskBitmap;

- (void) ppMergeMaskWithMaskBitmap: (NSBitmapImageRep *) maskBitmap
            inBounds: (NSRect) mergeBounds;

- (void) ppInvertMaskBitmap;

- (void) ppCloseHolesInMaskBitmap;

- (void) ppThresholdMaskBitmapPixelValues;

- (void) ppThresholdMaskBitmapPixelValuesInBounds: (NSRect) bounds;

@end

@interface NSBitmapImageRep (PPUtilities_PatternBitmaps)

+ (NSBitmapImageRep *) ppCheckerboardPatternBitmapWithBoxDimension: (float) boxDimension
                            color1: (NSColor *) color1
                            color2: (NSColor *) color2;

+ (NSBitmapImageRep *) ppDiagonalCheckerboardPatternBitmapWithBoxDimension:
                                                                    (float) boxDimension
                            color1: (NSColor *) color1
                            color2: (NSColor *) color2;

+ (NSBitmapImageRep *) ppIsometricCheckerboardPatternBitmapWithBoxDimension:
                                                                    (float) boxDimension
                            color1: (NSColor *) color1
                            color2: (NSColor *) color2;

+ (NSBitmapImageRep *) ppDiagonalLinePatternBitmapWithLineWidth: (float) lineWidth
                            color1: (NSColor *) color1
                            color2: (NSColor *) color2;

+ (NSBitmapImageRep *) ppIsometricLinePatternBitmapWithLineWidth: (float) lineWidth
                            color1: (NSColor *) color1
                            color2: (NSColor *) color2;

+ (NSBitmapImageRep *) ppHorizontalGradientPatternBitmapWithWidth: (unsigned) width
                            leftColor: (NSColor *) leftColor
                            rightColor: (NSColor *) rightColor;

+ (NSBitmapImageRep *) ppVerticalGradientPatternBitmapWithHeight: (unsigned) height
                            topColor: (NSColor *) topColor
                            bottomColor: (NSColor *) bottomColor;

+ (NSBitmapImageRep *) ppCenteredVerticalGradientPatternBitmapWithHeight: (unsigned) height
                            innerColor: (NSColor *) innerColor
                            outerColor: (NSColor *) outerColor;

+ (NSBitmapImageRep *) ppFillOverlayPatternBitmapWithSize: (float) patternSize
                            fillColor: (NSColor *) fillColor;

@end

@interface NSBitmapImageRep (PPUtilities_ColorMasking)

- (void) ppMaskNeighboringPixelsMatchingColorAtPoint: (NSPoint) point
            inImageBitmap: (NSBitmapImageRep *) sourceBitmap
            colorMatchTolerance: (unsigned) colorMatchTolerance
            selectionMask: (NSBitmapImageRep *) selectionMask
            selectionMaskBounds: (NSRect) selectionMaskBounds
            matchDiagonally: (bool) matchDiagonally;

- (void) ppMaskAllPixelsMatchingColorAtPoint: (NSPoint) point
            inImageBitmap: (NSBitmapImageRep *) sourceBitmap
            colorMatchTolerance: (unsigned) colorMatchTolerance
            selectionMask: (NSBitmapImageRep *) selectionMask
            selectionMaskBounds: (NSRect) selectionMaskBounds;

- (void) ppMaskVisiblePixelsInImageBitmap: (NSBitmapImageRep *) sourceBitmap
            selectionMask: (NSBitmapImageRep *) selectionMask;

@end
