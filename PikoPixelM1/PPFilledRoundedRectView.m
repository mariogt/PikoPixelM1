/*
    PPFilledRoundedRectView.m

    Copyright 2013-2018,2020 Josh Freeman
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

#import "PPFilledRoundedRectView.h"

#import "NSBitmapImageRep_PPUtilities.h"
#import "NSImage_PPUtilities.h"


// distance from the shape's corner edge to begin the curve for the rounded corner
#define kRoundedBackgroundShapeCurve_StartingDistanceFromEdge                15

// distance from the beginning of the curve to place the curve's control point
// (higher -> corner is sharper, lower -> corner is more round)
#define kRoundedBackgroundShapeCurve_ControlPointDistanceFromCurveStart      10

// for convenience when placing the control point, distance from the control point to the edge
#define kRoundedBackgroundShapeCurve_ControlPointDistanceFromEdge                   \
            (kRoundedBackgroundShapeCurve_StartingDistanceFromEdge                  \
                - kRoundedBackgroundShapeCurve_ControlPointDistanceFromCurveStart)

static NSBezierPath *RoundedRectPathOfSize(NSSize shapeSize);


@interface PPFilledRoundedRectView (PrivateMethods)

- (void) setupFilledRoundedRectImage;

@end

@implementation PPFilledRoundedRectView

+ viewWithFrame: (NSRect) frame andColor: (NSColor *) color
{
    return [[[self alloc] initWithFrame: frame andColor: color] autorelease];
}

- initWithFrame: (NSRect) frame andColor: (NSColor *) color
{
    self = [super initWithFrame: frame];

    if (!self)
        goto ERROR;

    if (!color)
    {
        color = [NSColor blackColor];
    }

    _color = [color retain];

    [self setAutoresizingMask: (NSViewWidthSizable | NSViewHeightSizable)];

    [self setupFilledRoundedRectImage];

    return self;

ERROR:
    [self release];

    return nil;
}

- initWithFrame: (NSRect) frame
{
    return [self initWithFrame: frame andColor: nil];
}

- (void) dealloc
{
    [_color release];

    [super dealloc];
}

#pragma mark NSView overrides

- (void) setFrameSize: (NSSize) newSize
{
    [super setFrameSize: newSize];

    [self setupFilledRoundedRectImage];
}

#pragma mark Private methods

- (void) setupFilledRoundedRectImage
{
    NSSize backgroundImageSize;
    NSBitmapImageRep *backgroundBitmap;
    NSImage *backgroundImage;

    backgroundImageSize = [self frame].size;

    backgroundBitmap = [NSBitmapImageRep ppImageBitmapOfSize: backgroundImageSize];

    if (!backgroundBitmap)
        goto ERROR;

    [backgroundBitmap ppSetAsCurrentGraphicsContext];

    [_color set];
    [RoundedRectPathOfSize(backgroundImageSize) fill];

    [backgroundBitmap ppRestoreGraphicsContext];

    backgroundImage = [NSImage ppImageWithBitmap: backgroundBitmap];

    if (!backgroundImage)
        goto ERROR;

    [self setImage: backgroundImage];

    return;

ERROR:
    return;
}

@end

#pragma mark Private functions

static NSBezierPath *RoundedRectPathOfSize(NSSize shapeSize)
{
    NSBezierPath *shape;
    float leftEdge, rightEdge, bottomEdge, topEdge;

    shape = [[[NSBezierPath alloc] init] autorelease];

    if (!shape)
        goto ERROR;

    leftEdge = 0.5f;
    bottomEdge = 0.5f;
    rightEdge = ceilf(shapeSize.width) - 0.5f;
    topEdge = ceilf(shapeSize.height) - 0.5f;

    [shape moveToPoint:
                    NSMakePoint(leftEdge
                                    + kRoundedBackgroundShapeCurve_StartingDistanceFromEdge,
                                bottomEdge)];

    [shape curveToPoint:
                    NSMakePoint(leftEdge,
                                bottomEdge
                                    + kRoundedBackgroundShapeCurve_StartingDistanceFromEdge)
                controlPoint1:
                    NSMakePoint(leftEdge
                                    + kRoundedBackgroundShapeCurve_ControlPointDistanceFromEdge,
                                bottomEdge)
                controlPoint2:
                    NSMakePoint(leftEdge,
                                bottomEdge
                                + kRoundedBackgroundShapeCurve_ControlPointDistanceFromEdge)];

    [shape lineToPoint:
                    NSMakePoint(leftEdge,
                                topEdge
                                    - kRoundedBackgroundShapeCurve_StartingDistanceFromEdge)];

    [shape curveToPoint:
                    NSMakePoint(leftEdge
                                    + kRoundedBackgroundShapeCurve_StartingDistanceFromEdge,
                                topEdge)
                controlPoint1:
                    NSMakePoint(leftEdge,
                                topEdge
                                    - kRoundedBackgroundShapeCurve_ControlPointDistanceFromEdge)
                controlPoint2:
                    NSMakePoint(leftEdge
                                    + kRoundedBackgroundShapeCurve_ControlPointDistanceFromEdge,
                                topEdge)];

    [shape lineToPoint:
                    NSMakePoint(rightEdge
                                    - kRoundedBackgroundShapeCurve_StartingDistanceFromEdge,
                                topEdge)];

    [shape curveToPoint:
                    NSMakePoint(rightEdge,
                                topEdge - kRoundedBackgroundShapeCurve_StartingDistanceFromEdge)
                controlPoint1:
                    NSMakePoint(rightEdge
                                    - kRoundedBackgroundShapeCurve_ControlPointDistanceFromEdge,
                                topEdge)
                controlPoint2:
                    NSMakePoint(rightEdge,
                                topEdge
                                - kRoundedBackgroundShapeCurve_ControlPointDistanceFromEdge)];

    [shape lineToPoint:
                    NSMakePoint(rightEdge,
                                bottomEdge
                                    + kRoundedBackgroundShapeCurve_StartingDistanceFromEdge)];

    [shape curveToPoint:
                    NSMakePoint(rightEdge
                                    - kRoundedBackgroundShapeCurve_StartingDistanceFromEdge,
                                bottomEdge)
                controlPoint1:
                    NSMakePoint(rightEdge,
                                bottomEdge
                                    + kRoundedBackgroundShapeCurve_ControlPointDistanceFromEdge)
                controlPoint2:
                    NSMakePoint(rightEdge
                                    - kRoundedBackgroundShapeCurve_ControlPointDistanceFromEdge,
                                bottomEdge)];

    [shape closePath];

    return shape;

ERROR:
    return nil;
}
