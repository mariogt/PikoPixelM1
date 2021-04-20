/*
    PPPanelController.h

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

#import <Cocoa/Cocoa.h>
#import "PPFramePinningType.h"


@class PPDocument;

@interface PPPanelController : NSWindowController
{
    PPDocument *_ppDocument;

    bool _panelDidLoad;
    bool _allowPanelVisibility;
    bool _panelIsEnabled;
    bool _shouldStorePanelStateInUserDefaults;
}

+ controller;

// designated initializer; don't use the other initializers inherited from NSWindowController
- initWithWindowNibName: (NSString *) windowNibName;

+ (NSString *) panelNibName;    // subclasses must override

- (void) setPPDocument: (PPDocument *) ppDocument;

- (void) setPanelVisibilityAllowed: (bool) allowPanelVisibility;

- (void) setPanelEnabled: (bool) enabledPanel;
- (void) togglePanelEnabledState;

- (bool) panelIsVisible;

- (bool) mouseLocationIsInsideVisiblePanel: (NSPoint) mouseLocation;

- (void) addAsObserverForPPDocumentNotifications;
- (void) removeAsObserverForPPDocumentNotifications;

- (bool) allowPanelToBecomeKey;                 // Default: NO
- (bool) shouldStorePanelStateInUserDefaults;   // Default: YES
- (bool) defaultPanelEnabledState;              // Default: NO

- (PPFramePinningType) pinningTypeForDefaultWindowFrame;

- (void) setupPanelForCurrentPPDocument;
- (void) setupPanelBeforeMakingVisible;
- (void) setupPanelAfterVisibilityChange;

@end
