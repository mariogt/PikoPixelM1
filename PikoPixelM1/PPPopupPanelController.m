/*
    PPPopupPanelController.m

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

#import "PPPopupPanelController.h"

#import "PPGeometry.h"
#import "PPUIColors_Panels.h"
#import "PPDocument.h"
#import "PPDocumentWindowController.h"
#import "PPCanvasView.h"


static NSScreen *ScreenContainingDisplayLocation(NSPoint displayLocation);


@interface PPPopupPanelController (PrivateMethods)

- (void) setPanelOrigin: (NSPoint) origin;

- (NSPoint) originPointForCenteringPanelAtCurrentMousePoint;

@end

@implementation PPPopupPanelController

- (NSColor *) backgroundColorForPopupPanel
{
    return kUIColor_DefaultPopupPanelBackground;
}

- (bool) handleActionKey: (NSString *) key
{
    return NO;
}

- (void) handleDirectionCommand: (PPDirectionType) directionType
{
}

- (NSPoint) panelOrigin
{
    return [[self window] frame].origin;
}

- (void) enablePanelAtOrigin: (NSPoint) origin
{
    _panelOriginLockPoint = origin;
    _hasPanelOriginLockPoint = YES;

    [self setPanelEnabled: YES];

    _hasPanelOriginLockPoint = NO;
}

#pragma mark PPPanelController overrides

- (bool) shouldStorePanelStateInUserDefaults
{
    return NO;
}

- (void) setupPanelForCurrentPPDocument
{
    // empty method - prevent passthrough to parent implementation (no need for super's setup,
    // which just updates the visiblity)
}

- (void) setupPanelBeforeMakingVisible
{
    NSPoint panelOrigin;

    [super setupPanelBeforeMakingVisible];

    panelOrigin =
        (_hasPanelOriginLockPoint) ?
                _panelOriginLockPoint : [self originPointForCenteringPanelAtCurrentMousePoint];

    [self setPanelOrigin: panelOrigin];
}

#pragma mark NSWindowController overrides

- (void) scrollWheel: (NSEvent *) theEvent
{
    [[[_ppDocument ppDocumentWindowController] canvasView] scrollWheel: theEvent];
}

#pragma mark Private methods

- (void) setPanelOrigin: (NSPoint) origin
{
    NSWindow *panel;
    NSRect newWindowFrame;
    NSPoint anchorPoint;
    NSScreen *panelScreen;

    panel = [self window];

    newWindowFrame = [panel frame];
    newWindowFrame.origin = PPGeometry_PointClippedToIntegerValues(origin);

    anchorPoint = (_hasPanelOriginLockPoint) ?
                        newWindowFrame.origin : PPGeometry_CenterOfRect(newWindowFrame);

    panelScreen = [NSScreen mainScreen];

    if (!NSPointInRect(anchorPoint, [panelScreen frame]))
    {
        panelScreen = ScreenContainingDisplayLocation(anchorPoint);
    }

    origin = PPGeometry_OriginPointForConfiningRectInsideRect(newWindowFrame,
                                                                [panelScreen visibleFrame]);

    [panel setFrameOrigin: origin];
}

- (NSPoint) originPointForCenteringPanelAtCurrentMousePoint
{
    return PPGeometry_OriginPointForCenteringRectAtPoint([[self window] frame],
                                                            [NSEvent mouseLocation]);
}

@end

#pragma mark Private functions

static NSScreen *ScreenContainingDisplayLocation(NSPoint displayLocation)
{
    NSEnumerator *screenEnumerator;
    NSScreen *screen;

    screenEnumerator = [[NSScreen screens] objectEnumerator];

    while (screen = [screenEnumerator nextObject])
    {
        if (NSPointInRect(displayLocation, [screen frame]))
        {
            return screen;
        }
    }

    return [NSScreen mainScreen];
}
