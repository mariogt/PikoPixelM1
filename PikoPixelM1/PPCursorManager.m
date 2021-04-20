/*
    PPCursorManager.m

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

#import "PPCursorManager.h"

#import "NSObject_PPUtilities.h"
#import "PPGeometry.h"


#define kDefaultCursor              [NSCursor arrowCursor]

#define kCursorRefreshDelay_Canvas  (0.0)
#define kCursorRefreshDelay_Panel   (0.005)


static bool gRuntimeOverridesCursorWhenDraggingOverResizableWindowEdges = NO;


@interface PPCursorManager (PrivateMethods)

- (void) refreshCursorAfterDelay;

- (void) disableResizingOfCurrentDocumentWindow: (bool) disableResizing;

@end

@implementation PPCursorManager

+ (void) load
{
    gRuntimeOverridesCursorWhenDraggingOverResizableWindowEdges =
        (PP_RUNTIME_CHECK__RUNTIME_OVERRIDES_CURSOR_WHEN_DRAGGING_OVER_RESIZABLE_WINDOW_EDGES) ?
            YES : NO;
}

- init
{
    self = [super init];

    if (!self)
        goto ERROR;

    _defaultCursor = [kDefaultCursor retain];
    _currentCursor = _defaultCursor;

    return self;

ERROR:
    [self release];

    return nil;
}

- (void) dealloc
{
    int i;

    for (i=0; i<kNumPPCursorLevels; i++)
    {
        [_cursors[i] release];
    }

    [_defaultCursor release];

    [self setCurrentDocumentWindow: nil];

    [super dealloc];
}

+ (PPCursorManager *) sharedManager
{
    static PPCursorManager *sharedManager = nil;

    if (!sharedManager)
    {
        sharedManager = [[PPCursorManager alloc] init];
    }

    return sharedManager;
}

- (void) setCursor: (NSCursor *) cursor
            atLevel: (PPCursorLevel) cursorLevel
            isDraggingMouse: (bool) isDraggingMouse
{
    int cursorIndex;
    NSCursor *newCursor;
    bool needToUpdateDraggingMouse = NO, needToUpdateCursorLevel = NO, shouldSetCursor = NO;

//NSLog(@"Set cursor at level %d: (%d) isDragging: %d", (int) cursorLevel, (int) cursor, isDraggingMouse);

    if (!PPCursorLevel_IsValid(cursorLevel))
    {
        goto ERROR;
    }

    if (_isDraggingMouse)
    {
        if (!isDraggingMouse && (cursorLevel == _currentCursorLevel))
        {
            // stopped dragging mouse
            needToUpdateDraggingMouse = YES;
            needToUpdateCursorLevel = YES;
        }
    }
    else
    {
        if (isDraggingMouse)
        {
            // started dragging mouse
            needToUpdateDraggingMouse = YES;
            _currentCursorLevel = cursorLevel;
        }
    }

    if (needToUpdateDraggingMouse)
    {
        _isDraggingMouse = (isDraggingMouse) ? YES : NO;

        if (gRuntimeOverridesCursorWhenDraggingOverResizableWindowEdges)
        {
            [self disableResizingOfCurrentDocumentWindow: _isDraggingMouse];
        }

        shouldSetCursor = YES;
    }

    cursorIndex = (int) cursorLevel;

    if (_cursors[cursorIndex] != cursor)
    {
        [_cursors[cursorIndex] autorelease];
        _cursors[cursorIndex] = [cursor retain];

        if (!_isDraggingMouse)
        {
            needToUpdateCursorLevel = YES;
        }
    }

    if (needToUpdateCursorLevel)
    {
        cursorIndex = kNumPPCursorLevels - 1;

        while ((cursorIndex > 0) && (!_cursors[cursorIndex]))
        {
            cursorIndex--;
        }

        if (cursorIndex != (int) _currentCursorLevel)
        {
            _currentCursorLevel = (PPCursorLevel) cursorIndex;
        }
    }

    newCursor = _cursors[(int) _currentCursorLevel];

    if (!newCursor)
    {
        newCursor = _defaultCursor;
    }

    if (_currentCursor != newCursor)
    {
        _currentCursor = newCursor;
        shouldSetCursor = YES;
    }
    else if (_currentCursor != [NSCursor currentCursor])
    {
//NSLog(@"INCORRECT CURSOR SET: %d", (int) [NSCursor currentCursor]);
        shouldSetCursor = YES;
    }

    if (shouldSetCursor)
    {
        [_currentCursor set];

        // make sure cursor sticks:
        [self refreshCursorAfterDelay];
    }

    return;

ERROR:
    return;
}

- (void) refreshCursorIfNeeded
{
    if (_currentCursor != [NSCursor currentCursor])
    {
        [_currentCursor set];
    }
}

- (void) setCurrentDocumentWindow: (NSWindow *) documentWindow
{
    if (_currentDocumentWindow == documentWindow)
    {
        return;
    }

    if (_currentDocumentWindow)
    {
        if (gRuntimeOverridesCursorWhenDraggingOverResizableWindowEdges)
        {
            [self disableResizingOfCurrentDocumentWindow: NO];
        }

        [_currentDocumentWindow release];
        _currentDocumentWindow = nil;
    }

    if (documentWindow)
    {
        _currentDocumentWindow = [documentWindow retain];

        [_currentDocumentWindow disableCursorRects];
    }
    else
    {
        [self setCursor: nil atLevel: kPPCursorLevel_CanvasView isDraggingMouse: NO];
    }
}

- (void) clearCurrentDocumentWindow: (NSWindow *) documentWindow
{
    if (!documentWindow || (_currentDocumentWindow == documentWindow))
    {
        [self setCurrentDocumentWindow: nil];
    }
}

#pragma mark Private methods

- (void) refreshCursorAfterDelay
{
    NSTimeInterval cursorRefreshDelay =
                    (_currentCursorLevel == kPPCursorLevel_CanvasView) ?
                        kCursorRefreshDelay_Canvas : kCursorRefreshDelay_Panel;

    [self ppPerformSelectorAtomically: @selector(refreshCursorIfNeeded)
            afterDelay: cursorRefreshDelay];
}

- (void) disableResizingOfCurrentDocumentWindow: (bool) disableResizing
{
    static NSSize minWindowSize = {0,0}, maxWindowSize = {0,0};

    if (!_currentDocumentWindow)
        return;

    if (disableResizing)
    {
        NSSize currentSize;

        if (PPGeometry_IsZeroSize(minWindowSize))
        {
            minWindowSize = [_currentDocumentWindow minSize];
            maxWindowSize = [_currentDocumentWindow maxSize];
        }

        currentSize = [_currentDocumentWindow frame].size;
        [_currentDocumentWindow setMinSize: currentSize];
        [_currentDocumentWindow setMaxSize: currentSize];
    }
    else    // enable resizing
    {
        if (!PPGeometry_IsZeroSize(minWindowSize))
        {
            [_currentDocumentWindow setMinSize: minWindowSize];
            [_currentDocumentWindow setMaxSize: maxWindowSize];
        }
    }
}

@end
