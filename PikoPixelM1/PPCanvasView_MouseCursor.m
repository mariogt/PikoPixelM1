/*
    PPCanvasView_MouseCursor.m

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

#import "PPCursorManager.h"
#import "PPPanelsController.h"
#import "PPPopupPanelsController.h"


@implementation PPCanvasView (MouseCursor)

- (void) setToolCursor: (NSCursor *) toolCursor
{
    if (_toolCursor != toolCursor)
    {
        [_toolCursor release];
        _toolCursor = [toolCursor retain];
    }

    [self updateCursor];
}

- (void) updateCursor
{
    NSCursor *cursor = nil;

    if (![[self window] isKeyWindow])
    {
        return;
    }

    if ((_mouseIsInsideVisibleCanvasTrackingRect && !_isScrolling)
        || _isDraggingTool)
    {
        cursor = _toolCursor;
    }

    [[PPCursorManager sharedManager] setCursor: cursor
                                        atLevel: kPPCursorLevel_CanvasView
                                        isDraggingMouse: _isDraggingTool];
}

- (void) updateCursorForWindowPoint: (NSPoint) windowPoint
{
    _mouseIsInsideVisibleCanvasTrackingRect =
        ([self windowPointIsInsideVisibleCanvas: windowPoint]
            && ![[PPPopupPanelsController sharedController] mouseIsInsideActivePopupPanel]
            && ![[PPPanelsController sharedController] mouseIsInsideVisiblePanel])
        ? YES : NO;

    [self updateCursor];
}

- (void) updateCursorForCurrentMouseLocation
{
    [self updateCursorForWindowPoint: [[self window] mouseLocationOutsideOfEventStream]];
}

@end
