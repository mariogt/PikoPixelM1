/*
    PPScreencastPopupPanelController.m

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

#import "PPOptional.h"
#if PP_OPTIONAL__BUILD_WITH_SCREENCASTING

#import "PPScreencastPopupPanelController.h"

#import "PPUIColors_Panels.h"


#define kScreencastPopupPanelNibName        @"ScreencastPopupPanel"

#define kScreencastPopupPanelBottomMargin   17.0f


@interface PPScreencastPopupPanelController (PrivateMethods)

- (void) setupPanelPosition;
- (void) increasePanelWindowLevel;

@end

@implementation PPScreencastPopupPanelController

- initWithWindowNibName: (NSString *) windowNibName
{
    self = [super initWithWindowNibName: windowNibName];

    if (!self)
        goto ERROR;

    if (!PP_RUNTIME_CHECK_OPTIONAL__RUNTIME_SUPPORTS_SCREENCASTING)
    {
        goto ERROR;
    }

    return self;

ERROR:
    [self release];

    return nil;
}

- (void) setStateString: (NSString *) stateString
{
    // method may be called before window's loaded, so check _panelDidLoad

    if (stateString)
    {
        if (!_panelDidLoad)
        {
            [self window];  // force load
        }

        [_stateTextField setStringValue: stateString];

        [[self window] orderFront: self];
    }
    else
    {
        if (!_panelDidLoad)
        {
            return;
        }

        [[self window] orderOut: self];

        [_stateTextField setStringValue: @""];
    }
}

#pragma mark NSWindowController overrides

- (void) windowDidLoad
{
    [super windowDidLoad];

    [self setupPanelPosition];

    [self increasePanelWindowLevel];    // make sure popup stays in front of other popups
}

#pragma mark PPPopupPanelController overrides

+ (NSString *) panelNibName
{
    return kScreencastPopupPanelNibName;
}

- (NSColor *) backgroundColorForPopupPanel
{
    return kUIColor_ScreencastPopupPanel_Background;
}

#pragma mark Private methods

- (void) setupPanelPosition
{
    NSScreen *mainScreen;
    NSRect screenFrame, screenVisibleFrame, panelFrame;
    NSWindow *panel;
    NSPoint panelOrigin;

    mainScreen = [NSScreen mainScreen];

    screenFrame = [mainScreen frame];
    screenVisibleFrame = [mainScreen visibleFrame];

    panel = [self window];

    panelFrame = [panel frame];

    panelOrigin.x =
        roundf(screenFrame.origin.x + ((screenFrame.size.width - panelFrame.size.width) / 2.0f));

    panelOrigin.y =
        roundf(screenVisibleFrame.origin.y + kScreencastPopupPanelBottomMargin);

    [panel setFrameOrigin: panelOrigin];
}

- (void) increasePanelWindowLevel
{
    NSWindow *panel = [self window];

    [panel setLevel: [panel level] + 1];
}

@end

#endif  // PP_OPTIONAL__BUILD_WITH_SCREENCASTING
