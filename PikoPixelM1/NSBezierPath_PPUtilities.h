/*
    NSBezierPath_PPUtilities.h

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


@interface NSBezierPath (PPUtilities)

- (void) ppAppendSinglePixelLineAtPoint: (NSPoint) point;
- (void) ppAppendLineFromPixelAtPoint: (NSPoint) startPoint toPixelAtPoint: (NSPoint) endPoint;

- (void) ppLineToPixelAtPoint: (NSPoint) point;

- (void) ppSetLastLineEndPointToPixelAtPoint: (NSPoint) point;

- (void) ppAppendZeroLengthLineAtLastLineEndPoint;

- (bool) ppRemoveLastLineStartPointAndGetPreviousStartPoint: (NSPoint *) returnedStartPoint;

- (void) ppAppendPixelColumnSeparatorLinesInBounds: (NSRect) bounds;
- (void) ppAppendPixelRowSeparatorLinesInBounds: (NSRect) bounds;

- (void) ppAntialiasedFill;

+ (NSBezierPath *) ppPixelatedBezierPathWithOvalInRect: (NSRect) rect;

@end

@interface NSBezierPath (PPUtilities_MaskBitmapPaths)

+ (void) ppAppendOutlinePathsForMaskBitmap: (NSBitmapImageRep *) maskBitmap
            inBounds: (NSRect) bounds
            toTopRightBezierPath: (NSBezierPath *) topRightPath
            andBottomLeftBezierPath: (NSBezierPath *) bottomLeftPath;

- (void) ppAppendOutlinePathForMaskBitmap: (NSBitmapImageRep *) maskBitmap
            inBounds: (NSRect) bounds;

- (void) ppAppendRightEdgePathForMaskBitmap: (NSBitmapImageRep *) maskBitmap;
- (void) ppAppendBottomEdgePathForMaskBitmap: (NSBitmapImageRep *) maskBitmap;

- (void) ppAppendFillPathForMaskBitmap: (NSBitmapImageRep *) maskBitmap
            inBounds: (NSRect) bounds;

- (void) ppAppendXMarksForUnmaskedPixelsInMaskBitmap: (NSBitmapImageRep *) maskBitmap
            inBounds: (NSRect) bounds;

@end
