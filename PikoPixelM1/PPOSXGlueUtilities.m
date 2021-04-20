/*
    PPOSXGlueUtilities.m

    Copyright 2013-2018,2020 Josh Freeman
    http://www.twilightedge.com

    This file is part of PikoPixel for Mac OS X.
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

#ifdef __APPLE__

#import "PPOSXGlueUtilities.h"

#import "PPObjCUtilities.h"


#define kMaxNumStoredSelectors      3


@interface PPOSXGlueUtilsNotificationHandler : NSObject
{
}
@end

#if !PP_SDK_HAS_BACKINGSCALEFACTOR_METHODS

@interface NSScreen (BackingScaleFactorMethodForLegacySDKs)

- (CGFloat) backingScaleFactor;

@end

#endif


static SEL *gStoredSelectors = NULL;
static int gNumStoredSelectors = 0;


static bool AnyScreenHasRetinaResolution(void);
static bool AddSelectorToStoredSelectors(SEL selector);
static void PerformAllStoredSelectorsAndClear(void);
static bool RegisterForNSAppNotification_DidChangeScreenParameters(bool register);


bool PPOSXGlueUtils_PerformNSObjectSelectorOnceWhenAnyDisplayIsRetina(SEL selector)
{
    if (!PP_RUNTIME_CHECK__RUNTIME_SUPPORTS_RETINA_DISPLAY
        || !selector
        || ![NSObject respondsToSelector: selector])
    {
        goto ERROR;
    }

    if (AnyScreenHasRetinaResolution())
    {
        [NSObject performSelector: selector];

        return YES;
    }
    else
    {
        if (!AddSelectorToStoredSelectors(selector))
        {
            goto ERROR;
        }

        RegisterForNSAppNotification_DidChangeScreenParameters(YES);
    }

    return YES;

ERROR:
    return NO;
}

#pragma mark Private functions

static bool AnyScreenHasRetinaResolution(void)
{
    static bool needToCheckBackingScaleFactorSelector = YES,
                backingScaleFactorSelectorIsSupported = NO;
    NSEnumerator *screenEnumerator;
    NSScreen *screen;

    if (needToCheckBackingScaleFactorSelector)
    {
        backingScaleFactorSelectorIsSupported =
            ([NSScreen instancesRespondToSelector: @selector(backingScaleFactor)]) ? YES : NO;

        needToCheckBackingScaleFactorSelector = NO;
    }

    if (!backingScaleFactorSelectorIsSupported)
        return NO;

    screenEnumerator = [[NSScreen screens] objectEnumerator];

    while (screen = [screenEnumerator nextObject])
    {
        if ([screen backingScaleFactor] > 1.0f)
        {
            return YES;
        }
    }

    return NO;
}

static bool AddSelectorToStoredSelectors(SEL selector)
{
    if (!gStoredSelectors)
    {
        gStoredSelectors = (SEL *) malloc (kMaxNumStoredSelectors * sizeof(SEL));
        gNumStoredSelectors = 0;

        if (!gStoredSelectors)
        {
            NSLog(@"ERROR: Out of memory in "
                  "PPOSXGlueUtils_PerformNSObjectSelectorOnceWhenAnyDisplayIsRetina()");

            goto ERROR;
        }
    }

    if (gNumStoredSelectors >= kMaxNumStoredSelectors)
    {
        NSLog(@"ERROR: Selector array is full - unable to store all delayed selector(s) in "
              "PPOSXGlueUtils_PerformNSObjectSelectorOnceWhenAnyDisplayIsRetina(); Need to "
              "increase kMaxNumStoredSelectors to more than (%d) in PPOSXGlueUtilities.m",
              (int) kMaxNumStoredSelectors);

        goto ERROR;
    }

    gStoredSelectors[gNumStoredSelectors++] = selector;

    return YES;

ERROR:
    return NO;
}

static void PerformAllStoredSelectorsAndClear(void)
{
    int selectorIndex;

    if (!gStoredSelectors)
        return;

    // sort the stored selectors alphabetically by name so they're always called in the same
    // order
    PPObjCUtils_AlphabeticallySortSelectorArray(gStoredSelectors, gNumStoredSelectors);

    for (selectorIndex=0; selectorIndex<gNumStoredSelectors; selectorIndex++)
    {
        NSAutoreleasePool *autoreleasePool = [[NSAutoreleasePool alloc] init];
        SEL selector = gStoredSelectors[selectorIndex];

        if (selector && [NSObject respondsToSelector: selector])
        {
            [NSObject performSelector: selector];
        }
        else
        {
            NSLog(@"ERROR: Invalid NSObject selector, %@, passed to "
                  "PPOSXGlueUtils_PerformNSObjectSelectorOnceWhenAnyDisplayIsRetina()",
                  (selector) ? NSStringFromSelector(selector) : @"NULL");
        }

        [autoreleasePool release];
    }

    free(gStoredSelectors);
    gStoredSelectors = NULL;
    gNumStoredSelectors = 0;
}

static bool RegisterForNSAppNotification_DidChangeScreenParameters(bool registerForNotification)
{
    static bool didRegisterForNotification = NO;

    registerForNotification = (registerForNotification) ? YES : NO;

    if (registerForNotification == didRegisterForNotification)
    {
        return YES;
    }

    if (registerForNotification)
    {
        [[NSNotificationCenter defaultCenter]
                                    addObserver: [PPOSXGlueUtilsNotificationHandler class]
                                    selector:
                                @selector(ppHandleNSAppNotification_DidChangeScreenParameters:)
                                    name: NSApplicationDidChangeScreenParametersNotification
                                    object: NSApp];
    }
    else
    {
        [[NSNotificationCenter defaultCenter]
                                    removeObserver: [PPOSXGlueUtilsNotificationHandler class]
                                    name: NSApplicationDidChangeScreenParametersNotification
                                    object: NSApp];
    }

    didRegisterForNotification = registerForNotification;

    return YES;
}

#pragma mark Notification handler class

@implementation PPOSXGlueUtilsNotificationHandler

+ (void) ppHandleNSAppNotification_DidChangeScreenParameters: (NSNotification *) notification
{
    if (AnyScreenHasRetinaResolution())
    {
        PerformAllStoredSelectorsAndClear();

        RegisterForNSAppNotification_DidChangeScreenParameters(NO);
    }
}

@end

#endif  // __APPLE__
