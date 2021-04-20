/*
    PPPresettablePatternView.m

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

#import "PPPresettablePatternView.h"

#import "NSBitmapImageRep_PPUtilities.h"


@interface PPPresettablePatternView (PrivateMethods)

- (void) updatePatternBitmap;

@end

@implementation PPPresettablePatternView

- (id) initWithFrame: (NSRect) frameRect
{
    self = [super initWithFrame: frameRect];

    if (!self)
        goto ERROR;

    _patternBitmap = [[NSBitmapImageRep ppImageBitmapOfSize: [self bounds].size] retain];

    if (!_patternBitmap)
        goto ERROR;

    _patternBitmapFrame = [_patternBitmap ppFrameInPixels];

    [self updatePatternBitmap];

    return self;

ERROR:
    [self release];

    return nil;
}

- (void) dealloc
{
    [_pattern release];

    [_patternBitmap release];

    [super dealloc];
}

- (void) setPresettablePattern: (id <PPPresettablePattern>) pattern
{
    if (![pattern conformsToProtocol: @protocol(PPPresettablePattern)])
    {
        pattern = nil;
    }

    if ((_pattern == pattern)
        || [_pattern isEqualToPresettablePattern: pattern])
    {
        return;
    }

    [_pattern release];
    _pattern = [pattern retain];

    [self updatePatternBitmap];
}

#pragma mark NSView overrides

- (void) drawRect: (NSRect) dirtyRect
{
    [_patternBitmap drawAtPoint: NSZeroPoint];
}

#pragma mark Private methods

- (void) updatePatternBitmap
{
    NSColor *patternColor =
                [_pattern patternColorForPresettablePatternViewOfSize: _patternBitmapFrame.size];

    if (!patternColor)
    {
        patternColor = [NSColor whiteColor];
    }

    [_patternBitmap ppSetAsCurrentGraphicsContext];

    [patternColor set];
    NSRectFill(_patternBitmapFrame);

    [_patternBitmap ppRestoreGraphicsContext];

    [self setNeedsDisplay: YES];
}

@end
