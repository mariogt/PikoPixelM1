/*
    PPCanvasView_MatchToolToleranceIndicator.m

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

#import "PPCanvasView.h"

#import "PPDefines.h"
#import "PPGeometry.h"
#import "PPSRGBUtilities.h"


#define kUIColor_MatchToolToleranceIndicatorLine        \
            [NSColor ppSRGBColorWithWhite: 0.0f alpha: 0.8f]

#define kUIColor_MatchToolToleranceIndicatorLineHalo    \
            [NSColor ppSRGBColorWithWhite: 1.0f alpha: 0.75f]

#define kIndicatorLineWidth             (0.0f)
#define kIndicatorLineHaloWidth         (3.0f)

#define kIndicatorCenterXLegLength      (3.0f)


static NSColor *gIndicatorLineColor = nil, *gIndicatorLineHaloColor = nil;


@interface PPCanvasView (MatchToolToleranceIndicatorPrivateMethods)

- (void) setupMatchToolToleranceIndicatorPathAndDisplayBounds;

@end

@implementation PPCanvasView (MatchToolToleranceIndicator)

+ (void) initializeMatchToolToleranceIndicator
{
    if (!gIndicatorLineColor)
    {
        gIndicatorLineColor = [kUIColor_MatchToolToleranceIndicatorLine retain];
    }

    if (!gIndicatorLineHaloColor)
    {
        gIndicatorLineHaloColor = [kUIColor_MatchToolToleranceIndicatorLineHalo retain];
    }
}

- (bool) initMatchToolToleranceIndicatorMembers
{
    return YES;
}

- (void) deallocMatchToolToleranceIndicatorMembers
{
    [_matchToolToleranceIndicatorPath release];
    _matchToolToleranceIndicatorPath = nil;
}

- (void) showMatchToolToleranceIndicatorAtViewPoint: (NSPoint) viewPoint
{
    _matchToolToleranceIndicatorOrigin = PPGeometry_PixelCenteredPoint(viewPoint);

    _matchToolToleranceIndicatorRadius = 0;

    if (_matchToolToleranceIndicatorPath)
    {
        [_matchToolToleranceIndicatorPath release];
        _matchToolToleranceIndicatorPath = nil;
    }

    _matchToolToleranceIndicatorDisplayBounds = NSZeroRect;

    _shouldDisplayMatchToolToleranceIndicator = YES;
}

- (void) hideMatchToolToleranceIndicator
{
    _shouldDisplayMatchToolToleranceIndicator = NO;

    [self setNeedsDisplayInRect: _matchToolToleranceIndicatorDisplayBounds];

    [_matchToolToleranceIndicatorPath release];
    _matchToolToleranceIndicatorPath = nil;

    _matchToolToleranceIndicatorDisplayBounds = NSZeroRect;
}

- (void) setMatchToolToleranceIndicatorRadius: (unsigned) radius
{
    NSRect oldDisplayBounds;

    if (radius > kMatchToolToleranceIndicator_MaxRadius)
    {
        radius = kMatchToolToleranceIndicator_MaxRadius;
    }

    if (_matchToolToleranceIndicatorRadius == radius)
    {
        return;
    }

    _matchToolToleranceIndicatorRadius = radius;

    oldDisplayBounds = _matchToolToleranceIndicatorDisplayBounds;

    [self setupMatchToolToleranceIndicatorPathAndDisplayBounds];

    [self setNeedsDisplayInRect:
                    NSUnionRect(oldDisplayBounds, _matchToolToleranceIndicatorDisplayBounds)];
}

- (void) drawMatchToolToleranceIndicator
{
    NSGraphicsContext *currentContext;
    bool oldShouldAntialias;

    if (!_shouldDisplayMatchToolToleranceIndicator)
        return;

    currentContext = [NSGraphicsContext currentContext];

    oldShouldAntialias = [currentContext shouldAntialias];
    [currentContext setShouldAntialias: YES];

    [_matchToolToleranceIndicatorPath setLineWidth: kIndicatorLineHaloWidth];
    [gIndicatorLineHaloColor set];
    [_matchToolToleranceIndicatorPath stroke];

    [_matchToolToleranceIndicatorPath setLineWidth: kIndicatorLineWidth];
    [gIndicatorLineColor set];
    [_matchToolToleranceIndicatorPath stroke];

    [currentContext setShouldAntialias: oldShouldAntialias];
}

#pragma mark Private methods

- (void) setupMatchToolToleranceIndicatorPathAndDisplayBounds
{
    NSPoint centerPoint;
    NSRect circleBounds;
    float circleRadius, circleDiameter;
    NSBezierPath *path;

    centerPoint = _matchToolToleranceIndicatorOrigin;

    // circle
    circleRadius = (float) _matchToolToleranceIndicatorRadius;
    circleBounds.origin = NSMakePoint(centerPoint.x - circleRadius,
                                      centerPoint.y - circleRadius);

    circleDiameter = 2.0f * circleRadius;
    circleBounds.size = NSMakeSize(circleDiameter, circleDiameter);

    path = [NSBezierPath bezierPathWithOvalInRect: circleBounds];

    // center X
    [path moveToPoint: NSMakePoint(centerPoint.x - kIndicatorCenterXLegLength,
                                    centerPoint.y - kIndicatorCenterXLegLength)];

    [path lineToPoint: NSMakePoint(centerPoint.x + kIndicatorCenterXLegLength,
                                    centerPoint.y + kIndicatorCenterXLegLength)];

    [path moveToPoint: NSMakePoint(centerPoint.x - kIndicatorCenterXLegLength,
                                    centerPoint.y + kIndicatorCenterXLegLength)];

    [path lineToPoint: NSMakePoint(centerPoint.x + kIndicatorCenterXLegLength,
                                    centerPoint.y - kIndicatorCenterXLegLength)];

    [_matchToolToleranceIndicatorPath release];
    _matchToolToleranceIndicatorPath = [path retain];

    _matchToolToleranceIndicatorDisplayBounds =
            PPGeometry_PixelBoundsCoveredByRect(NSInsetRect([path bounds],
                                                            -(kIndicatorLineHaloWidth/2.0f),
                                                            -(kIndicatorLineHaloWidth/2.0f)));
}

@end
