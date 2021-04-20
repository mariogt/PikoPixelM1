/*
    PPPopupPanel.m

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

#import "PPPopupPanel.h"

#import "PPPopupPanelController.h"
#import "PPFilledRoundedRectView.h"
#import "PPUIColors_Panels.h"


@interface PPPopupPanel (PrivateMethods)

- (void) setupRoundedRectBackgroundView;
- (NSColor *) backgroundColorForPopupPanelFromController;

@end

@implementation PPPopupPanel

#pragma mark NSPanel overrides

- (id) initWithContentRect: (NSRect) contentRect
        styleMask: (PPSDKNativeType_NSWindowStyleMask) styleMask
        backing: (NSBackingStoreType) bufferingType
        defer: (BOOL) deferCreation
{
    self = [super initWithContentRect: contentRect
                    styleMask: NSBorderlessWindowMask
                    backing: bufferingType
                    defer: deferCreation];

    if (!self)
        goto ERROR;

    [self setBackgroundColor: [NSColor clearColor]];
    [self setFloatingPanel: YES];
    [self setOpaque: NO];
    [self setHasShadow: NO];

    return self;

ERROR:
    [self release];

    return nil;
}

- (void) awakeFromNib
{
    // check before calling [super awakeFromNib] - before 10.6, some classes didn't implement it
    if ([[PPPopupPanel superclass] instancesRespondToSelector: @selector(awakeFromNib)])
    {
        [super awakeFromNib];
    }

    [self setupRoundedRectBackgroundView];

    [self orderOut: nil];
}

#pragma mark Private methods

- (void) setupRoundedRectBackgroundView
{
    NSView *contentView;
    PPFilledRoundedRectView *roundedRectBackgroundView;

    contentView = [self contentView];

    roundedRectBackgroundView =
        [PPFilledRoundedRectView viewWithFrame: [contentView bounds]
                                andColor: [self backgroundColorForPopupPanelFromController]];

    if (!roundedRectBackgroundView)
        goto ERROR;

    [contentView addSubview: roundedRectBackgroundView
                    positioned: NSWindowBelow
                    relativeTo: nil];

    [contentView setAutoresizesSubviews: YES];

    return;

ERROR:
    return;
}

- (NSColor *) backgroundColorForPopupPanelFromController
{
    PPPopupPanelController *controller;

    controller = [self windowController];

    if (![controller isKindOfClass: [PPPopupPanelController class]])
    {
        return kUIColor_DefaultPopupPanelBackground;
    }

    return [controller backgroundColorForPopupPanel];
}

@end
