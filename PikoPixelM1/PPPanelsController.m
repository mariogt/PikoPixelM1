/*
    PPPanelsController.m

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

#import "PPPanelsController.h"

#import "PPToolsPanelController.h"
#import "PPLayersPanelController.h"
#import "PPPreviewPanelController.h"
#import "PPSamplerImagePanelController.h"
#import "PPToolModifierTipsPanelController.h"
#import "NSObject_PPUtilities.h"
#import "PPDocumentWindow.h"


static NSArray *PanelControllersArray(void);


@interface PPPanelsController (PrivateMethods)

- (void) addAsObserverForNSWindowNotifications;
- (void) removeAsObserverForNSWindowNotifications;
- (void) handleNSWindowNotification_DidBecomeKey: (NSNotification *) notification;
- (void) handleNSWindowNotification_DidBecomeMain: (NSNotification *) notification;
- (void) handleNSWindowNotification_DidResignMain: (NSNotification *) notification;
- (void) handleNSWindowNotification_WillBeginSheet: (NSNotification *) notification;
- (void) handleNSWindowNotification_DidEndSheet: (NSNotification *) notification;

- (void) resetToggledActivePanels;

- (void) setPanelsVisibilityAllowed: (bool) panelsVisibilityAllowed;

- (void) updatePanelsVisibilityAllowedForWindow: (NSWindow *) window;
- (void) updatePanelsVisibilityAllowed;

@end

@implementation PPPanelsController

+ sharedController
{
    static PPPanelsController *sharedController = nil;

    if (!sharedController)
    {
        sharedController = [[self alloc] init];
    }

    return sharedController;
}

- init
{
    self = [super init];

    if (!self)
        goto ERROR;

    _panelControllers = [PanelControllersArray() retain];

    if (!_panelControllers)
        goto ERROR;

    [self addAsObserverForNSWindowNotifications];

    return self;

ERROR:
    [self release];

    return nil;
}

- (void) dealloc
{
    [self removeAsObserverForNSWindowNotifications];

    [_panelControllers release];

    [super dealloc];
}

- (void) setPPDocument: (PPDocument *) ppDocument
{
    [_panelControllers makeObjectsPerformSelector: @selector(setPPDocument:)
                            withObject: ppDocument];
}

- (void) toggleEnabledStateForPanelOfType: (PPPanelType) panelType;
{
    PPPanelController *panelController;

    if (!PPPanelType_IsValid(panelType))
    {
        return;
    }

    panelController = (PPPanelController *) [_panelControllers objectAtIndex: panelType];

    [panelController togglePanelEnabledState];
}

- (bool) panelOfTypeIsVisible: (PPPanelType) panelType
{
    PPPanelController *panelController;

    if (!PPPanelType_IsValid(panelType))
    {
        return NO;
    }

    panelController = (PPPanelController *) [_panelControllers objectAtIndex: panelType];

    return [panelController panelIsVisible];
}

- (void) toggleEnabledStateForActivePanels
{
    int i;
    PPPanelController *panelController;
    bool didTogglePanels = NO;

    for (i=0; i<kNumPPPanelTypes; i++)
    {
        panelController = (PPPanelController *) [_panelControllers objectAtIndex: i];

        if ([panelController panelIsVisible])
        {
            [panelController togglePanelEnabledState];

            if (!didTogglePanels)
            {
                [self resetToggledActivePanels];

                didTogglePanels = YES;
            }

            _toggledActivePanels[i] = YES;
        }
    }

    if (didTogglePanels)
        return;

    for (i=0; i<kNumPPPanelTypes; i++)
    {
        if (_toggledActivePanels[i])
        {
            panelController = (PPPanelController *) [_panelControllers objectAtIndex: i];

            [panelController togglePanelEnabledState];

            didTogglePanels = YES;
        }
    }

    if (didTogglePanels)
        return;

    [_panelControllers makeObjectsPerformSelector: @selector(togglePanelEnabledState)];
}

- (bool) mouseIsInsideVisiblePanel
{
    NSPoint mouseLocation;
    int i;

    if (!_panelsVisibilityAllowed)
    {
        return NO;
    }

    mouseLocation = [NSEvent mouseLocation];

    for (i=0; i<kNumPPPanelTypes; i++)
    {
        if ([((PPPanelController *) [_panelControllers objectAtIndex: i])
                                            mouseLocationIsInsideVisiblePanel: mouseLocation])
        {
            return YES;
        }
    }

    return NO;
}

#pragma mark NSWindow notifications

- (void) addAsObserverForNSWindowNotifications
{
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];

    [notificationCenter addObserver: self
                        selector: @selector(handleNSWindowNotification_DidBecomeKey:)
                        name: NSWindowDidBecomeKeyNotification
                        object: nil];

    [notificationCenter addObserver: self
                        selector: @selector(handleNSWindowNotification_DidBecomeMain:)
                        name: NSWindowDidBecomeMainNotification
                        object: nil];

    [notificationCenter addObserver: self
                        selector: @selector(handleNSWindowNotification_DidResignMain:)
                        name: NSWindowDidResignMainNotification
                        object: nil];

    [notificationCenter addObserver: self
                        selector: @selector(handleNSWindowNotification_WillBeginSheet:)
                        name: NSWindowWillBeginSheetNotification
                        object: nil];

    [notificationCenter addObserver: self
                        selector: @selector(handleNSWindowNotification_DidEndSheet:)
                        name: NSWindowDidEndSheetNotification
                        object: nil];
}

- (void) removeAsObserverForNSWindowNotifications
{
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];

    [notificationCenter removeObserver: self
                        name: NSWindowDidBecomeKeyNotification
                        object: nil];

    [notificationCenter removeObserver: self
                        name: NSWindowDidBecomeMainNotification
                        object: nil];

    [notificationCenter removeObserver: self
                        name: NSWindowDidResignMainNotification
                        object: nil];

    [notificationCenter removeObserver: self
                        name: NSWindowWillBeginSheetNotification
                        object: nil];

    [notificationCenter removeObserver: self
                        name: NSWindowDidEndSheetNotification
                        object: nil];
}

- (void) handleNSWindowNotification_DidBecomeKey: (NSNotification *) notification
{
    if ([[notification object] isKindOfClass: [NSOpenPanel class]])
    {
        [self setPanelsVisibilityAllowed: NO];
    }
    else
    {
        [self ppPerformSelectorAtomicallyFromNewStackFrame:
                                                @selector(updatePanelsVisibilityAllowed)];
    }
}

- (void) handleNSWindowNotification_DidBecomeMain: (NSNotification *) notification
{
    [self updatePanelsVisibilityAllowedForWindow: [notification object]];
}

- (void) handleNSWindowNotification_DidResignMain: (NSNotification *) notification
{
    [self ppPerformSelectorAtomicallyFromNewStackFrame:
                                                @selector(updatePanelsVisibilityAllowed)];
}

- (void) handleNSWindowNotification_WillBeginSheet: (NSNotification *) notification
{
    NSWindow *window = [notification object];

    if (window == [NSApp mainWindow])
    {
        [self setPanelsVisibilityAllowed: NO];
    }
}

- (void) handleNSWindowNotification_DidEndSheet: (NSNotification *) notification
{
    NSWindow *window = [notification object];

    if ((window == [NSApp mainWindow]) && ([window class] == [PPDocumentWindow class]))
    {
        [self setPanelsVisibilityAllowed: YES];
    }
}

#pragma mark Private methods

- (void) resetToggledActivePanels
{
    memset(_toggledActivePanels, 0, sizeof(_toggledActivePanels));
}

- (void) setPanelsVisibilityAllowed: (bool) panelsVisibilityAllowed
{
    NSEnumerator *panelControllersEnumerator;
    PPPanelController *panelController;

    panelsVisibilityAllowed = (panelsVisibilityAllowed) ? YES : NO;

    if (_panelsVisibilityAllowed == panelsVisibilityAllowed)
    {
        return;
    }

    _panelsVisibilityAllowed = panelsVisibilityAllowed;

    panelControllersEnumerator = [_panelControllers objectEnumerator];

    while (panelController = [panelControllersEnumerator nextObject])
    {
        [panelController setPanelVisibilityAllowed: _panelsVisibilityAllowed];
    }
}

- (void) updatePanelsVisibilityAllowedForWindow: (NSWindow *) window
{
    bool panelsVisibilityAllowed = NO;

    if (([window class] == [PPDocumentWindow class]) && ![window attachedSheet])
    {
        panelsVisibilityAllowed = YES;
    }

    [self setPanelsVisibilityAllowed: panelsVisibilityAllowed];
}

- (void) updatePanelsVisibilityAllowed
{
    [self updatePanelsVisibilityAllowedForWindow: [NSApp mainWindow]];
}

@end

#pragma mark Private functions

static NSArray *PanelControllersArray(void)
{
    NSArray *panelControllers;

    panelControllers = [NSArray arrayWithObjects:
                                            // Must be in same order as PPPanelType enum
                                            [PPToolsPanelController controller],
                                            [PPLayersPanelController controller],
                                            [PPPreviewPanelController controller],
                                            [PPSamplerImagePanelController controller],
                                            [PPToolModifierTipsPanelController controller],

                                            nil];

    if ([panelControllers count] != kNumPPPanelTypes)
    {
        goto ERROR;
    }

    return panelControllers;

ERROR:
    return nil;
}
