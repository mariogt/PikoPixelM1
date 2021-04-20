/*
    PPPopupPanelsController.m

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

#import "PPPopupPanelsController.h"

#import "PPNavigatorPopupPanelController.h"
#import "PPToolsPopupPanelController.h"
#import "PPColorPickerPopupPanelController.h"
#import "PPSamplerImagePopupPanelController.h"
#import "PPLayerControlsPopupPanelController.h"
#import "PPHotkeys.h"


static NSDictionary *gHotkeyToPopupPanelTypeMapping = nil;

static NSArray *PopupControllersArray(void);


@interface PPPopupPanelsController (PrivateMethods)

+ (void) addAsObserverForPPHotkeysNotifications;
+ (void) removeAsObserverForPPHotkeysNotifications;
+ (void) handlePPHotkeysNotification_UpdatedHotkeys: (NSNotification *) notification;

+ (bool) setupHotkeyToPopupPanelTypeMapping;

- (PPPopupPanelController *) popupPanelControllerForActivePopupType;

- (void) setVisibilityAllowedForAllPopups;

@end

@implementation PPPopupPanelsController

+ (void) initialize
{
    if ([self class] != [PPPopupPanelsController class])
    {
        return;
    }

    [PPHotkeys setupGlobals];

    [self setupHotkeyToPopupPanelTypeMapping];

    [self addAsObserverForPPHotkeysNotifications];
}

+ sharedController
{
    static PPPopupPanelsController *sharedController = nil;

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

    _popupControllers = [PopupControllersArray() retain];

    if (!_popupControllers)
        goto ERROR;

    [self setVisibilityAllowedForAllPopups];

    _activePopupPanelType = kPPPopupPanelType_None;

    return self;

ERROR:
    [self release];

    return nil;
}

- (void) dealloc
{
    [_popupControllers release];

    [super dealloc];
}

- (void) setPPDocument: (PPDocument *) document
{
    if (_activePopupPanelType != kPPPopupPanelType_None)
    {
        [self setActivePopupPanel: kPPPopupPanelType_None];
    }

    [_popupControllers makeObjectsPerformSelector: @selector(setPPDocument:)
                        withObject: document];
}

- (void) setActivePopupPanel: (PPPopupPanelType) popupPanelType
{
    if (!PPPopupPanelType_IsValid(popupPanelType))
    {
        popupPanelType = kPPPopupPanelType_None;
    }

    if (popupPanelType == _activePopupPanelType)
    {
        return;
    }

    [[self popupPanelControllerForActivePopupType] setPanelEnabled: NO];

    _activePopupPanelType = popupPanelType;

    if (_activePopupPanelType == kPPPopupPanelType_None)
    {
        return;
    }

    if (_useLastPopupPanelOriginForNextActivePopup)
    {
        [[self popupPanelControllerForActivePopupType]
                                                enablePanelAtOrigin: _lastPopupPanelOrigin];

        _useLastPopupPanelOriginForNextActivePopup = NO;
    }
    else
    {
        [[self popupPanelControllerForActivePopupType] setPanelEnabled: YES];
    }
}

- (bool) hasActivePopupPanel
{
    return (_activePopupPanelType != kPPPopupPanelType_None) ? YES : NO;
}

- (bool) mouseIsInsideActivePopupPanel
{
    NSWindow *panel;

    if (![self hasActivePopupPanel])
    {
        return NO;
    }

    panel = [[self popupPanelControllerForActivePopupType] window];

    return ([panel isVisible]
                && NSMouseInRect([NSEvent mouseLocation], [panel frame], NO))
            ? YES : NO;
}

- (bool) getPopupPanelType: (PPPopupPanelType *) returnedPopupPanelType
            forKey: (NSString *) key
{
    NSNumber *popupPanelTypeNumber;

    if (!returnedPopupPanelType || ([key length] != 1))
    {
        goto ERROR;
    }

    popupPanelTypeNumber = [gHotkeyToPopupPanelTypeMapping objectForKey: key];

    if (!popupPanelTypeNumber)
        goto ERROR;

    *returnedPopupPanelType = (PPPopupPanelType) [popupPanelTypeNumber intValue];

    return YES;

ERROR:
    return NO;
}

- (bool) handleActionKey: (NSString *) key
{
    if (![self hasActivePopupPanel])
    {
        return NO;
    }

    return [[self popupPanelControllerForActivePopupType] handleActionKey: key];
}

- (void) handleDirectionCommand: (PPDirectionType) directionType
{
    [[self popupPanelControllerForActivePopupType] handleDirectionCommand: directionType];
}

- (void) positionNextActivePopupAtCurrentPopupOrigin
{
    if (![self hasActivePopupPanel])
    {
        return;
    }

    _lastPopupPanelOrigin = [[self popupPanelControllerForActivePopupType] panelOrigin];
    _useLastPopupPanelOriginForNextActivePopup = YES;
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
    [self setupHotkeyToPopupPanelTypeMapping];
}

#pragma mark Private methods

+ (bool) setupHotkeyToPopupPanelTypeMapping
{
    NSDictionary *hotkeyToPopupPanelTypeMapping =
                    [NSDictionary dictionaryWithObjectsAndKeys:

                                    [NSNumber numberWithInt: kPPPopupPanelType_Navigator],
                                gHotkeys[kPPHotkeyType_PopupPanel_Navigator],

                                    [NSNumber numberWithInt: kPPPopupPanelType_Navigator],
                                gHotkeys[kPPHotkeyType_PopupPanel_NavigatorAlternate],


                                    [NSNumber numberWithInt: kPPPopupPanelType_Tools],
                                gHotkeys[kPPHotkeyType_PopupPanel_Tools],

                                    [NSNumber numberWithInt: kPPPopupPanelType_Tools],
                                gHotkeys[kPPHotkeyType_PopupPanel_ToolsAlternate],


                                    [NSNumber numberWithInt: kPPPopupPanelType_ColorPicker],
                                gHotkeys[kPPHotkeyType_PopupPanel_ColorPicker],

                                    [NSNumber numberWithInt: kPPPopupPanelType_ColorPicker],
                                gHotkeys[kPPHotkeyType_PopupPanel_ColorPickerAlternate],


                                    // no direct mapping for color sampler image popup
                                    [NSNumber numberWithInt: kPPPopupPanelType_SamplerImage],
                                @"no hotkey",

                                    [NSNumber numberWithInt: kPPPopupPanelType_SamplerImage],
                                @"no hotkey alternate",


                                    [NSNumber numberWithInt: kPPPopupPanelType_LayerControls],
                                gHotkeys[kPPHotkeyType_PopupPanel_LayerControls],

                                    [NSNumber numberWithInt: kPPPopupPanelType_LayerControls],
                                gHotkeys[kPPHotkeyType_PopupPanel_LayerControlsAlternate],

                                    nil];

    if ([hotkeyToPopupPanelTypeMapping count] != (2 * kNumPPPopupPanelTypes))
    {
        goto ERROR;
    }

    [gHotkeyToPopupPanelTypeMapping release];
    gHotkeyToPopupPanelTypeMapping = [hotkeyToPopupPanelTypeMapping retain];

    return YES;

ERROR:
    return NO;
}

- (PPPopupPanelController *) popupPanelControllerForActivePopupType
{
    if (!PPPopupPanelType_IsValid(_activePopupPanelType))
    {
        return nil;
    }

    return [_popupControllers objectAtIndex: _activePopupPanelType];
}

- (void) setVisibilityAllowedForAllPopups
{
    NSEnumerator *popupControllerEnumerator;
    PPPopupPanelController *popupController;

    popupControllerEnumerator = [_popupControllers objectEnumerator];

    while (popupController = [popupControllerEnumerator nextObject])
    {
        [popupController setPanelVisibilityAllowed: YES];
    }
}

@end

#pragma mark Private functions

static NSArray *PopupControllersArray(void)
{
    NSArray *popupControllers;

    popupControllers = [NSArray arrayWithObjects:
                                            // Must match order of PPPopupPanelType enum:
                                            [PPNavigatorPopupPanelController controller],
                                            [PPToolsPopupPanelController controller],
                                            [PPColorPickerPopupPanelController controller],
                                            [PPSamplerImagePopupPanelController controller],
                                            [PPLayerControlsPopupPanelController controller],

                                            nil];

    if ([popupControllers count] != kNumPPPopupPanelTypes)
    {
        goto ERROR;
    }

    return popupControllers;

ERROR:
    return nil;
}
