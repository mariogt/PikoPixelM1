/*
    PPOptional_Screencasting.m

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

#import "PPAppBootUtilities.h"
#import "PPScreencastController.h"
#import "NSObject_PPUtilities.h"
#import "PPApplication.h"


#define kScreencastingMenuItemTitle         @"Enable Screencast Popup Panel"


static bool gScreencastingIsEnabled = NO;
static PPScreencastController *gScreencastController = nil;


@interface PPApplication (PPOptional_Screencasting)

- (void) ppMenuItemSelected_EnableScreencasting: (id) sender;

- (void) ppScreencasting_InstallPatches: (bool) installPatches;

@end

@implementation NSObject (PPOptional_Screencasting)

+ (void) load
{
    macroPerformNSObjectSelectorAfterAppLoads(ppOptional_Screencasting_SetupMenuItem);
}

+ (void) ppOptional_Screencasting_SetupMenuItem
{
    NSMenu *panelMenu;
    NSMenuItem *screencastingItem;
        // use PPSDKNativeType_NSMenuItemPtr for separatorItem, as -[NSMenu separatorItem]
        // could return either (NSMenuItem *) or (id <NSMenuItem>), depending on the SDK
    PPSDKNativeType_NSMenuItemPtr separatorItem;

    if (!PP_RUNTIME_CHECK_OPTIONAL__RUNTIME_SUPPORTS_SCREENCASTING)
    {
        return;
    }

    panelMenu = [[[NSApp mainMenu] itemWithTitle: @"Panel"] submenu];

    screencastingItem =
            [[[NSMenuItem alloc] initWithTitle: NSLocalizedString(kScreencastingMenuItemTitle, nil)
                                    action: @selector(ppMenuItemSelected_EnableScreencasting:)
                                    keyEquivalent: @""]
                            autorelease];

    [screencastingItem setTarget: NSApp];

    separatorItem = [NSMenuItem separatorItem];

    if (!panelMenu || !screencastingItem || !separatorItem)
    {
        goto ERROR;
    }

    [panelMenu addItem: separatorItem];
    [panelMenu addItem: screencastingItem];

    return;

ERROR:
    return;
}

@end

@implementation PPApplication (PPOptional_Screencasting)

- (void) ppMenuItemSelected_EnableScreencasting: (id) sender
{
    // setup screencast controller

    if (!gScreencastController)
    {
        gScreencastController = [[PPScreencastController sharedController] retain];

        if (!gScreencastController)
            goto ERROR;
    }

    // toggle screencasting

    gScreencastingIsEnabled = (gScreencastingIsEnabled) ? NO : YES;

    [self ppScreencasting_InstallPatches: gScreencastingIsEnabled];

    [gScreencastController setEnabled: gScreencastingIsEnabled];

    // update menu item state

    if ([sender isKindOfClass: [NSMenuItem class]])
    {
        [((NSMenuItem *) sender) setState: (gScreencastingIsEnabled) ? NSOnState : NSOffState];
    }

    return;

ERROR:
    return;
}

- (void) ppScreencasting_InstallPatches: (bool) installPatches
{
    static bool screencastPatchesAreInstalled = NO;

    installPatches = (installPatches) ? YES : NO;

    if ((screencastPatchesAreInstalled != installPatches)
        && macroSwizzleInstanceMethod(
                            PPApplication,
                            nextEventMatchingMask:untilDate:inMode:dequeue:,
                            ppPatch_SCasting_NextEventMatchingMask:untilDate:inMode:dequeue:))
    {
        screencastPatchesAreInstalled = installPatches;
    }
}

- (NSEvent *) ppPatch_SCasting_NextEventMatchingMask: (NSUInteger) mask
                untilDate: (NSDate *) expiration
                inMode: (NSString *) mode
                dequeue: (BOOL) dequeue
{
    NSEvent *event = [self ppPatch_SCasting_NextEventMatchingMask: mask
                            untilDate: expiration
                            inMode: mode
                            dequeue: dequeue];

    if (gScreencastingIsEnabled
        && event
        && dequeue
        && (NSEventMaskFromType([event type]) & kScreencastEventsMask))
    {
        [gScreencastController handleEvent: event];
    }

    return event;
}

@end

#endif  // PP_OPTIONAL__BUILD_WITH_SCREENCASTING
