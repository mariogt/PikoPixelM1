/*
    PPGridPattern.h

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
#import "PPGridType.h"
#import "PPPresettablePatternProtocol.h"


@interface PPGridPattern : NSObject <NSCoding, NSCopying, PPPresettablePattern>
{
    PPGridType _pixelGridType;
    NSColor *_pixelGridColor;

    NSSize _guidelineSpacingSize;
    NSColor *_guidelineColor;

    NSString *_presetName;

    bool _shouldDisplayGuidelines;
}

+ gridPatternWithPixelGridType: (PPGridType) pixelGridType
    pixelGridColor: (NSColor *) pixelGridColor
    guidelineSpacingSize: (NSSize) guidelineSpacingSize
    guidelineColor: (NSColor *) guidelineColor
    shouldDisplayGuidelines: (bool) shouldDisplayGuidelines;

+ gridPatternWithPixelGridType: (PPGridType) pixelGridType
    pixelGridColor: (NSColor *) pixelGridColor;

- initWithPixelGridType: (PPGridType) pixelGridType
    pixelGridColor: (NSColor *) pixelGridColor
    guidelineSpacingSize: (NSSize) guidelineSpacingSize
    guidelineColor: (NSColor *) guidelineColor
    shouldDisplayGuidelines: (bool) shouldDisplayGuidelines;

- (PPGridType) pixelGridType;
- (NSColor *) pixelGridColor;

- (NSSize) guidelineSpacingSize;
- (NSColor *) guidelineColor;
- (bool) shouldDisplayGuidelines;

- (bool) isEqualToGridPattern: (PPGridPattern *) otherPattern;

- (PPGridPattern *) gridPatternByTogglingPixelGridType;
- (PPGridPattern *) gridPatternByTogglingGuidelinesVisibility;
- (PPGridPattern *) gridPatternByEnablingGuidelinesVisibility;

- (NSData *) archivedData;
+ (PPGridPattern *) gridPatternWithArchivedData: (NSData *) archivedData;

@end
