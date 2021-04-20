/*
    PPCanvasView_Autoscrolling.m

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

#import "NSObject_PPUtilities.h"


#define kAutoscrollTimeInterval         0.1f


@interface PPCanvasView (AutoscrollingPrivateMethods)

- (void) startAutoscrollRepeatTimer;
- (void) stopAutoscrollRepeatTimer;
- (void) autoscrollRepeatTimerFired: (NSTimer *) timer;

@end

@implementation PPCanvasView (Autoscrolling)

- (void) enableAutoscrolling: (bool) shouldEnableAutoscrolling
{
    _autoscrollingIsEnabled = (shouldEnableAutoscrolling) ? YES : NO;
}

- (bool) isAutoscrolling
{
    return _isAutoscrolling;
}

- (void) autoscrollHandleMouseDraggedEvent: (NSEvent *) event
{
    if ([event type] != NSLeftMouseDragged)
    {
        return;
    }

    if (_autoscrollMouseDraggedEvent)
    {
        if ([_autoscrollMouseDraggedEvent isEqual: event])
        {
            return;
        }

        [_autoscrollMouseDraggedEvent release];
        _autoscrollMouseDraggedEvent = nil;
    }
    else
    {
        [self startAutoscrollRepeatTimer];
    }

    _autoscrollMouseDraggedEvent = [event retain];
}

- (void) autoscrollStop
{
    _isAutoscrolling = NO;

    if (_autoscrollMouseDraggedEvent)
    {
        [_autoscrollMouseDraggedEvent release];
        _autoscrollMouseDraggedEvent = nil;
    }

    if (_autoscrollRepeatTimer)
    {
        [self stopAutoscrollRepeatTimer];
    }

    [self updateBackgroundImageSmoothingForScrollingEnd];
}

#pragma mark Autoscroll repeat timer

- (void) startAutoscrollRepeatTimer
{
    if (_autoscrollRepeatTimer)
    {
        [self stopAutoscrollRepeatTimer];
    }

    _autoscrollRepeatTimer = [[NSTimer scheduledTimerWithTimeInterval: kAutoscrollTimeInterval
                                        target: self
                                        selector: @selector(autoscrollRepeatTimerFired:)
                                        userInfo: nil
                                        repeats: YES]
                                    retain];
}

- (void) stopAutoscrollRepeatTimer
{
    if (!_autoscrollRepeatTimer)
        return;

    [_autoscrollRepeatTimer invalidate];
    [_autoscrollRepeatTimer autorelease];
    _autoscrollRepeatTimer = nil;
}

- (void) autoscrollRepeatTimerFired: (NSTimer *) timer
{
    if (!_autoscrollMouseDraggedEvent)
        return;

    if ([self autoscroll: _autoscrollMouseDraggedEvent])
    {
        _isAutoscrolling = YES;

        [self disableBackgroundImageSmoothingForScrollingBegin];

        [self mouseDragged: _autoscrollMouseDraggedEvent];
    }
    else
    {
        [self autoscrollStop];
    }
}

@end
