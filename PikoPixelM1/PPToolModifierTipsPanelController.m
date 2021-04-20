/*
    PPToolModifierTipsPanelController.m

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

#import "PPToolModifierTipsPanelController.h"

#import "PPDocument.h"
#import "PPToolModifierTipsText.h"
#import "PPPanelDefaultFramePinnings.h"


#define kToolModifierTipsPanelNibName   @"ToolModifierTipsPanel"

#define kMarginForTextFields            (8.0f)


@interface PPToolModifierTipsPanelController (PrivateMethods)

- (void) handlePPDocumentNotification_SwitchedSelectedTool: (NSNotification *) notification;
- (void) handlePPDocumentNotification_SwitchedActiveTool: (NSNotification *) notification;

- (void) updateTypeModifierTextFields;
- (void) updateActionModifierTextFields;

@end

@implementation PPToolModifierTipsPanelController

#pragma mark NSWindowController overrides

- (void) windowDidLoad
{
    float maxTextWidth_ModifierDescriptions, maxTextWidth_ModifierKeyNames,
            maxTextHeight_TypeModifiers, maxTextHeight_ActionModifiers;
    NSRect typeModifierToolNamesFrame, typeModifierKeysFrame, actionModifierDescriptionsFrame,
            actionModifierKeysFrame;
    NSSize contentSize;

    if (![PPToolModifierTipsText
                        getMaxTextWidthForModifierDescriptions:
                                                    &maxTextWidth_ModifierDescriptions
                        maxTextWidthForModifierKeyNames: &maxTextWidth_ModifierKeyNames
                        maxTextHeightForTypeModifiersText: &maxTextHeight_TypeModifiers
                        maxTextHeightForActionModifiersText: &maxTextHeight_ActionModifiers])
    {
        goto ERROR;
    }

    actionModifierDescriptionsFrame =
        NSMakeRect(kMarginForTextFields,
                    kMarginForTextFields,
                    maxTextWidth_ModifierDescriptions + kMarginForTextFields,
                    maxTextHeight_ActionModifiers);

    actionModifierKeysFrame =
        NSMakeRect(NSMaxX(actionModifierDescriptionsFrame),
                    kMarginForTextFields,
                    maxTextWidth_ModifierKeyNames + kMarginForTextFields,
                    maxTextHeight_ActionModifiers);

    typeModifierToolNamesFrame =
        NSMakeRect(kMarginForTextFields,
                    NSMaxY(actionModifierDescriptionsFrame) + kMarginForTextFields,
                    maxTextWidth_ModifierDescriptions + kMarginForTextFields,
                    maxTextHeight_TypeModifiers);

    typeModifierKeysFrame =
        NSMakeRect(NSMaxX(typeModifierToolNamesFrame),
                    NSMaxY(actionModifierKeysFrame) + kMarginForTextFields,
                    maxTextWidth_ModifierKeyNames + kMarginForTextFields,
                    maxTextHeight_TypeModifiers);

    contentSize = NSMakeSize(NSMaxX(typeModifierKeysFrame),
                                NSMaxY(typeModifierKeysFrame) + kMarginForTextFields);

    [_typeModifierToolNamesTextField setFrame: typeModifierToolNamesFrame];
    [_typeModifierKeysTextField setFrame: typeModifierKeysFrame];
    [_actionModifierDescriptionsTextField setFrame: actionModifierDescriptionsFrame];
    [_actionModifierKeysTextField setFrame: actionModifierKeysFrame];

    [[self window] setContentSize: contentSize];

    // [super windowDidLoad] may show the panel, so call as late as possible
    [super windowDidLoad];

    return;

ERROR:
    [super windowDidLoad];
}

#pragma mark PPPanelController overrides

+ (NSString *) panelNibName
{
    return kToolModifierTipsPanelNibName;
}

- (void) addAsObserverForPPDocumentNotifications
{
    if (!_ppDocument)
        return;

    [[NSNotificationCenter defaultCenter]
                    addObserver: self
                    selector: @selector(handlePPDocumentNotification_SwitchedSelectedTool:)
                    name: PPDocumentNotification_SwitchedSelectedTool
                    object: _ppDocument];

    [[NSNotificationCenter defaultCenter]
                    addObserver: self
                    selector: @selector(handlePPDocumentNotification_SwitchedActiveTool:)
                    name: PPDocumentNotification_SwitchedActiveTool
                    object: _ppDocument];
}

- (void) removeAsObserverForPPDocumentNotifications
{
    [[NSNotificationCenter defaultCenter] removeObserver: self
                                            name: PPDocumentNotification_SwitchedSelectedTool
                                            object: _ppDocument];

    [[NSNotificationCenter defaultCenter] removeObserver: self
                                            name: PPDocumentNotification_SwitchedActiveTool
                                            object: _ppDocument];
}

- (bool) defaultPanelEnabledState
{
    return YES;
}

- (PPFramePinningType) pinningTypeForDefaultWindowFrame
{
    return kPPPanelDefaultFramePinning_ToolModifierTips;
}

- (void) setupPanelForCurrentPPDocument
{
    [self updateTypeModifierTextFields];
    [self updateActionModifierTextFields];

    // [super setupPanelForCurrentPPDocument] may show the panel, so call as late as possible
    [super setupPanelForCurrentPPDocument];
}

#pragma mark PPDocument notifications

- (void) handlePPDocumentNotification_SwitchedSelectedTool: (NSNotification *) notification
{
    [self updateTypeModifierTextFields];
}

- (void) handlePPDocumentNotification_SwitchedActiveTool: (NSNotification *) notification
{
    [self updateActionModifierTextFields];
}

#pragma mark Private methods

- (void) updateTypeModifierTextFields
{
    NSAttributedString *typeModifierDescriptions, *typeModifierKeyNames;

    if (![PPToolModifierTipsText getTypeModifierDescriptions: &typeModifierDescriptions
                                    andTypeModifierKeyNames: &typeModifierKeyNames
                                    forToolType: [_ppDocument selectedToolType]])
    {
        goto ERROR;
    }

    [_typeModifierToolNamesTextField setAttributedStringValue: typeModifierDescriptions];
    [_typeModifierKeysTextField setAttributedStringValue: typeModifierKeyNames];

    return;

ERROR:
    return;
}

- (void) updateActionModifierTextFields
{
    NSAttributedString *actionModifierDescriptions, *actionModifierKeyNames;

    if (![PPToolModifierTipsText getActionModifierDescriptions: &actionModifierDescriptions
                                    andActionModifierKeyNames: &actionModifierKeyNames
                                    forToolType: [_ppDocument activeToolType]])
    {
        goto ERROR;
    }

    [_actionModifierDescriptionsTextField setAttributedStringValue: actionModifierDescriptions];
    [_actionModifierKeysTextField setAttributedStringValue: actionModifierKeyNames];

    return;

ERROR:
    return;
}

@end
