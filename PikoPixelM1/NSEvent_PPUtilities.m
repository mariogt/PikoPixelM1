/*
    NSEvent_PPUtilities.m

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

#import "NSEvent_PPUtilities.h"


@implementation NSEvent (PPUtilities)

- (NSPoint) ppMouseDragDeltaPointByMergingWithEnqueuedMouseDraggedEvents
{
    NSPoint mouseDragAmount;
    NSEvent *mouseEvent;

    if ([self type] != NSLeftMouseDragged)
    {
        goto ERROR;
    }

    mouseDragAmount = NSZeroPoint;
    mouseEvent = self;

    while (mouseEvent)
    {
        mouseDragAmount.x += [mouseEvent deltaX];

#   if PP_DEPLOYMENT_TARGET_NSEVENT_DELTAY_RETURNS_FLIPPED_COORDINATE
        mouseDragAmount.y -= [mouseEvent deltaY];     // flipped - change sign
#   else
        mouseDragAmount.y += [mouseEvent deltaY];     // not flipped
#   endif

        mouseEvent = [NSApp nextEventMatchingMask: NSLeftMouseDraggedMask | NSLeftMouseUpMask
                            untilDate: nil
                            inMode: NSEventTrackingRunLoopMode
                            dequeue: YES];

        if ([mouseEvent type] == NSLeftMouseUp)
        {
            [NSApp postEvent: mouseEvent atStart: YES];

            mouseEvent = nil;
        }
    }

    return mouseDragAmount;

ERROR:
    return NSZeroPoint;
}

- (NSEvent *) ppLatestMouseDraggedEventFromEventQueue
{
    NSEvent *dequeuedEvent, *lastMouseDraggedEvent;

    if ([self type] != NSLeftMouseDragged)
    {
        goto ERROR;
    }

    dequeuedEvent = lastMouseDraggedEvent = self;

    while (dequeuedEvent)
    {
        lastMouseDraggedEvent = dequeuedEvent;

        dequeuedEvent =
                [NSApp nextEventMatchingMask: NSLeftMouseDraggedMask | NSLeftMouseUpMask
                        untilDate: nil
                        inMode: NSEventTrackingRunLoopMode
                        dequeue: YES];

        if ([dequeuedEvent type] == NSLeftMouseUp)
        {
            [NSApp postEvent: dequeuedEvent atStart: YES];

            dequeuedEvent = nil;
        }
    }

    return lastMouseDraggedEvent;

ERROR:
    return self;
}

@end
