/*
    PPResizeControl.m

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

#import "PPResizeControl.h"

#import "PPGeometry.h"


@interface PPResizeControl (PrivateMethods)

- (void) notifyDelegateDidBeginResizing;
- (void) notifyDelegateDidFinishResizing;

@end

@implementation PPResizeControl

- (void) setDelegate: (id) delegate
{
    _delegate = delegate;
}

- (id) delegate
{
    return _delegate;
}

#pragma mark NSImageView overrides

- (void) mouseDown: (NSEvent *) theEvent
{
    NSWindow *window;
    NSRect windowFrame;

    window = [self window];
    windowFrame = [window frame];

    _mouseDownLocation = [theEvent locationInWindow];
    _mouseDownLocation.y += windowFrame.origin.y;

    _initialWindowTopLeftPoint =
            NSMakePoint(windowFrame.origin.x, windowFrame.origin.y + windowFrame.size.height);

    _initialWindowSize = windowFrame.size;

    _windowDelegate = [window delegate];

    if (![_windowDelegate respondsToSelector: @selector(windowWillResize:toSize:)])
    {
        _windowDelegate = nil;
    }

    [self notifyDelegateDidBeginResizing];
}

- (void) mouseDragged: (NSEvent *) theEvent
{
    NSWindow *window;
    NSRect windowFrame, newWindowFrame;
    NSPoint currentMouseLocation, mouseOffset;

    window = [self window];

    windowFrame = [window frame];

    currentMouseLocation = [theEvent locationInWindow];
    currentMouseLocation.y += windowFrame.origin.y;

    mouseOffset = NSMakePoint(currentMouseLocation.x - _mouseDownLocation.x,
                                currentMouseLocation.y - _mouseDownLocation.y);

    newWindowFrame.size = NSMakeSize(_initialWindowSize.width + mouseOffset.x,
                                        _initialWindowSize.height - mouseOffset.y);

    newWindowFrame.size = [_windowDelegate windowWillResize: window
                                            toSize: newWindowFrame.size];

    if (PPGeometry_IsZeroSize(newWindowFrame.size))
    {
        goto ERROR;
    }

    newWindowFrame.origin = NSMakePoint(_initialWindowTopLeftPoint.x,
                                    _initialWindowTopLeftPoint.y - newWindowFrame.size.height);

    [window setFrame: newWindowFrame display: YES];

    return;

ERROR:
    return;
}

- (void) mouseUp: (NSEvent *) theEvent
{
    [self notifyDelegateDidFinishResizing];
}

#pragma mark Delegate notifiers

- (void) notifyDelegateDidBeginResizing
{
    if ([_delegate respondsToSelector: @selector(ppResizeControlDidBeginResizing:)])
    {
        [_delegate ppResizeControlDidBeginResizing: self];
    }
}

- (void) notifyDelegateDidFinishResizing
{
    if ([_delegate respondsToSelector: @selector(ppResizeControlDidFinishResizing:)])
    {
        [_delegate ppResizeControlDidFinishResizing: self];
    }
}

@end
