/*
    PPBackgroundPattern.h

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
#import "PPBackgroundPatternType.h"
#import "PPPresettablePatternProtocol.h"


@interface PPBackgroundPattern : NSObject <NSCoding, NSCopying, PPPresettablePattern>
{
    PPBackgroundPatternType _patternType;
    int _patternSize;
    NSColor *_color1;
    NSColor *_color2;
    NSColor *_patternFillColor;

    NSString *_presetName;
}

+ backgroundPatternOfType: (PPBackgroundPatternType) patternType
    patternSize: (int) patternSize
    color1: (NSColor *) color1
    color2: (NSColor *) color2;

- initWithPatternType: (PPBackgroundPatternType) patternType
    patternSize: (int) patternSize
    color1: (NSColor *) color1
    color2: (NSColor *) color2;

- (PPBackgroundPatternType) patternType;
- (int) patternSize;
- (NSColor *) color1;
- (NSColor *) color2;

- (NSColor *) patternFillColor;

- (bool) isEqualToBackgroundPattern: (PPBackgroundPattern *) otherPattern;

- (PPBackgroundPattern *) backgroundPatternScaledByFactor: (float) scalingFactor;

- (NSData *) archivedData;
+ (PPBackgroundPattern *) backgroundPatternWithArchivedData: (NSData *) archivedData;

@end
