/*
    PPLayerOpacitySliderCell.m

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

#import "PPLayerOpacitySliderCell.h"

#import "PPLayersPanelController.h"


@implementation PPLayerOpacitySliderCell

- (BOOL) isContinuous
{
    return YES;
}

- (BOOL) startTrackingAt: (NSPoint) startPoint inView: (NSView *) controlView
{
    bool startedTracking = [super startTrackingAt: startPoint inView: controlView];

    if (startedTracking)
    {
        [((PPLayersPanelController *) [self target]) setTrackingOpacitySliderCell: self];
    }

    return startedTracking;
}

- (void) stopTracking: (NSPoint) lastPoint
            at: (NSPoint) stopPoint
            inView: (NSView *) controlView
            mouseIsUp: (BOOL) flag
{
    [super stopTracking: lastPoint at: stopPoint inView: controlView mouseIsUp: flag];

    [((PPLayersPanelController *) [self target]) setTrackingOpacitySliderCell: nil];
}

@end
