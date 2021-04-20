/*
    PPToolbox.m

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

#import "PPToolbox.h"

#import "PPPencilTool.h"
#import "PPEraserTool.h"
#import "PPFillTool.h"
#import "PPLineTool.h"
#import "PPRectTool.h"
#import "PPOvalTool.h"
#import "PPFreehandSelectTool.h"
#import "PPRectSelectTool.h"
#import "PPMagicWandTool.h"
#import "PPColorSamplerTool.h"
#import "PPMoveTool.h"
#import "PPMagnifierTool.h"
#import "PPColorRampTool.h"
#import "PPHotkeys.h"


static NSDictionary *gHotkeyToToolTypeMapping = nil;


@interface PPToolbox (PrivateMethods)

+ (void) addAsObserverForPPHotkeysNotifications;
+ (void) removeAsObserverForPPHotkeysNotifications;
+ (void) handlePPHotkeysNotification_UpdatedHotkeys: (NSNotification *) notification;

+ (bool) setupHotkeyToToolTypeMapping;

@end

@implementation PPToolbox

+ (void) initialize
{
    if ([self class] != [PPToolbox class])
    {
        return;
    }

    [PPHotkeys setupGlobals];

    [self setupHotkeyToToolTypeMapping];

    [self addAsObserverForPPHotkeysNotifications];
}

+ sharedToolbox
{
    static PPToolbox *sharedToolbox = nil;

    if (!sharedToolbox)
    {
        sharedToolbox = [[self alloc] init];
    }

    return sharedToolbox;
}

- init
{
    self = [super init];

    if (!self)
        goto ERROR;

    _tools[kPPToolType_Pencil] = [[PPPencilTool tool] retain];
    _tools[kPPToolType_Eraser] = [[PPEraserTool tool] retain];
    _tools[kPPToolType_Fill] = [[PPFillTool tool] retain];
    _tools[kPPToolType_Line] = [[PPLineTool tool] retain];
    _tools[kPPToolType_Rect] = [[PPRectTool tool] retain];
    _tools[kPPToolType_Oval] = [[PPOvalTool tool] retain];
    _tools[kPPToolType_FreehandSelect] = [[PPFreehandSelectTool tool] retain];
    _tools[kPPToolType_RectSelect] = [[PPRectSelectTool tool] retain];
    _tools[kPPToolType_MagicWand] = [[PPMagicWandTool tool] retain];
    _tools[kPPToolType_ColorSampler] = [[PPColorSamplerTool tool] retain];
    _tools[kPPToolType_Move] = [[PPMoveTool tool] retain];
    _tools[kPPToolType_Magnifier] = [[PPMagnifierTool tool] retain];
    _tools[kPPToolType_ColorRamp] = [[PPColorRampTool tool] retain];

    return self;

ERROR:
    [self release];

    return nil;
}

- (void) dealloc
{
    int i;

    for (i=0; i<kNumPPToolTypes; i++)
    {
        [_tools[i] release];
    }

    [super dealloc];
}

- (PPTool *) toolOfType: (PPToolType) toolType
{
    if (!PPToolType_IsValid(toolType))
    {
        return nil;
    }

    return _tools[toolType];
}

+ (bool) getToolType: (PPToolType *) returnedToolType
            forKey: (NSString *) key
{
    NSNumber *toolTypeNumber;

    if (!returnedToolType)
        goto ERROR;

    toolTypeNumber = [gHotkeyToToolTypeMapping objectForKey: key];

    if (!toolTypeNumber)
        goto ERROR;

    *returnedToolType = [toolTypeNumber intValue];

    return YES;

ERROR:
    return NO;
}

#pragma mark PPHotkeys notifications

+ (void) addAsObserverForPPHotkeysNotifications
{
    [[NSNotificationCenter defaultCenter]
                    addObserver: self
                    selector: @selector(handlePPHotkeysNotification_UpdatedHotkeys:)
                    name: PPHotkeysNotification_UpdatedHotkeys
                    object: nil];
}

+ (void) removeAsObserverForPPHotkeysNotifications
{
    [[NSNotificationCenter defaultCenter] removeObserver: self
                                            name: PPHotkeysNotification_UpdatedHotkeys
                                            object: nil];
}

+ (void) handlePPHotkeysNotification_UpdatedHotkeys: (NSNotification *) notification
{
    [self setupHotkeyToToolTypeMapping];
}

#pragma mark Private methods

+ (bool) setupHotkeyToToolTypeMapping
{
    NSDictionary *hotkeyToToolTypeMapping =
                    [NSDictionary dictionaryWithObjectsAndKeys:

                                        [NSNumber numberWithInt: kPPToolType_Pencil],
                                    gHotkeys[kPPHotkeyType_Tool_Pencil],

                                        [NSNumber numberWithInt: kPPToolType_Eraser],
                                    gHotkeys[kPPHotkeyType_Tool_Eraser],

                                        [NSNumber numberWithInt: kPPToolType_Fill],
                                    gHotkeys[kPPHotkeyType_Tool_Fill],

                                        [NSNumber numberWithInt: kPPToolType_Line],
                                    gHotkeys[kPPHotkeyType_Tool_Line],

                                        [NSNumber numberWithInt: kPPToolType_Rect],
                                    gHotkeys[kPPHotkeyType_Tool_Rect],

                                        [NSNumber numberWithInt: kPPToolType_Oval],
                                    gHotkeys[kPPHotkeyType_Tool_Oval],

                                        [NSNumber numberWithInt: kPPToolType_FreehandSelect],
                                    gHotkeys[kPPHotkeyType_Tool_FreehandSelect],

                                        [NSNumber numberWithInt: kPPToolType_RectSelect],
                                    gHotkeys[kPPHotkeyType_Tool_RectSelect],

                                        [NSNumber numberWithInt: kPPToolType_MagicWand],
                                    gHotkeys[kPPHotkeyType_Tool_MagicWand],

                                        [NSNumber numberWithInt: kPPToolType_ColorSampler],
                                    gHotkeys[kPPHotkeyType_Tool_ColorSampler],

                                        [NSNumber numberWithInt: kPPToolType_Move],
                                    gHotkeys[kPPHotkeyType_Tool_Move],

                                        [NSNumber numberWithInt: kPPToolType_Magnifier],
                                    gHotkeys[kPPHotkeyType_Tool_Magnifier],

                                        nil];

    if (!hotkeyToToolTypeMapping)
        goto ERROR;

    [gHotkeyToToolTypeMapping release];
    gHotkeyToToolTypeMapping = [hotkeyToToolTypeMapping retain];

    return YES;

ERROR:
    return NO;
}

@end
