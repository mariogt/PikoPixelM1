/*
    PPMiniColorWell.m

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

#import "PPMiniColorWell.h"

#import "PPGeometry.h"


@interface PPMiniColorWell (PrivateMethods)

- (void) drawTransparencyBackgroundInBounds: (NSRect) bounds;

@end

@implementation PPMiniColorWell

- (void) dealloc
{
    [_fillColor release];
    [_outlineColor release];

    [super dealloc];
}

- (void) setColor: (NSColor *) color
{
    if (_fillColor == color)
    {
        return;
    }

    [_fillColor release];
    _fillColor = [color retain];

    _fillColorIsOpaque = ([color alphaComponent] >= 1.0f) ? YES : NO;

    [self setNeedsDisplay: YES];
}

- (void) setOutlineColor: (NSColor *) color
{
    if (_outlineColor == color)
    {
        return;
    }

    [_outlineColor release];
    _outlineColor = [color retain];

    [self setNeedsDisplay: YES];
}

#pragma mark NSView overrides

- (void) drawRect: (NSRect) rect
{
    NSRect viewDrawBounds = PPGeometry_PixelCenteredRect([self bounds]);

    if (_fillColor)
    {
        if (!_fillColorIsOpaque)
        {
            [self drawTransparencyBackgroundInBounds: viewDrawBounds];
        }

        [_fillColor set];
        [NSBezierPath fillRect: viewDrawBounds];
    }

    if (_outlineColor)
    {
        [_outlineColor set];
        [NSBezierPath strokeRect: viewDrawBounds];

        if (!_fillColor)
        {
            NSBezierPath *xPath = [NSBezierPath bezierPath];

            [xPath moveToPoint: viewDrawBounds.origin];
            [xPath lineToPoint: NSMakePoint(viewDrawBounds.origin.x + viewDrawBounds.size.width,
                                        viewDrawBounds.origin.y + viewDrawBounds.size.height)];

            [xPath moveToPoint: NSMakePoint(viewDrawBounds.origin.x,
                                        viewDrawBounds.origin.y + viewDrawBounds.size.height)];
            [xPath lineToPoint: NSMakePoint(viewDrawBounds.origin.x + viewDrawBounds.size.width,
                                        viewDrawBounds.origin.y)];

            [xPath stroke];
        }
    }
}

#pragma mark Private methods

- (void) drawTransparencyBackgroundInBounds: (NSRect) bounds
{
    NSBezierPath *trianglePath = [NSBezierPath bezierPath];

    [trianglePath moveToPoint: bounds.origin];
    [trianglePath lineToPoint: NSMakePoint(bounds.origin.x + bounds.size.width,
                                            bounds.origin.y + bounds.size.height)];
    [trianglePath lineToPoint: NSMakePoint(bounds.origin.x + bounds.size.width,
                                            bounds.origin.y)];
    [trianglePath closePath];

    [[NSColor blackColor] set];
    NSRectFill(bounds);

    [[NSColor whiteColor] set];
    [trianglePath fill];
}

@end
