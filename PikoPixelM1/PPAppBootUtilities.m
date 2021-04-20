/*
    PPAppBootUtilities.m

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

#import "PPAppBootUtilities.h"

#import "PPObjCUtilities.h"


#define kMaxNumStoredSelectors      50


static SEL *gStoredSelectors = NULL;
static int gNumStoredSelectors = 0;
static bool gAppDidFinishLoading = NO,
                gHadBootError_UnableToAllocateMemoryForStoredSelectors = NO,
                gHadBootError_StoredSelectorsArrayTooSmall = NO;


bool PPAppBootUtils_PerformNSObjectSelectorAfterAppLoads(SEL selector)
{
    if (gAppDidFinishLoading)
    {
        [NSObject performSelector: selector];

        return YES;
    }

    if (!gStoredSelectors)
    {
        gStoredSelectors = (SEL *) malloc (kMaxNumStoredSelectors * sizeof(SEL));

        if (!gStoredSelectors)
        {
            gHadBootError_UnableToAllocateMemoryForStoredSelectors = YES;

            goto ERROR;
        }
    }

    if (gNumStoredSelectors >= kMaxNumStoredSelectors)
    {
        gHadBootError_StoredSelectorsArrayTooSmall = YES;

        goto ERROR;
    }

    gStoredSelectors[gNumStoredSelectors++] = selector;

    return YES;

ERROR:
    return NO;
}

void PPAppBootUtils_HandleAppDidFinishLoading(void)
{
    int selectorIndex;

    if (gAppDidFinishLoading)
        return;

    gAppDidFinishLoading = YES;

    if (gHadBootError_UnableToAllocateMemoryForStoredSelectors)
    {
        NSLog(@"ERROR: Out of memory in PPAppUtils_PerformNSObjectSelectorAfterAppLoads()");
    }

    if (gHadBootError_StoredSelectorsArrayTooSmall)
    {
        NSLog(@"ERROR: Selector array is full - unable to store all delayed selector(s) in "
                "PPAppUtils_PerformNSObjectSelectorAfterAppLoads(); Need to increase "
                "kMaxNumStoredSelectors to more than (%d) in PPAppBootUtilities.m",
                (int) kMaxNumStoredSelectors);
    }

    if (!gStoredSelectors)
        return;

    // sort the stored selectors alphabetically by name so they're always called in the same
    // order instead of depending on the undefined order in which +load methods are called
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
                    "PPAppUtils_PerformNSObjectSelectorAfterAppLoads()",
                    (selector) ? NSStringFromSelector(selector) : @"NULL");
        }

        [autoreleasePool release];
    }

    free(gStoredSelectors);
    gStoredSelectors = NULL;
}
