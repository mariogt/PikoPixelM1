/*
    PPDocumentSizeSheetController.m

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

#import "PPDocumentSizeSheetController.h"

#import "PPDefines.h"
#import "NSTextField_PPUtilities.h"
#import "PPGeometry.h"
#import "PPImageSizePresets.h"
#import "PPDocumentEditImageSizePresetsSheetController.h"
#import "PPTitleablePopUpButton.h"


#define kDocumentSizeSheetNibName               @"DocumentSizeSheet"

#define kTagOfSizeMenuItem_CustomDimensions     900
#define kTagOfSizeMenuItem_InsertionPoint       1000


static int gLastSelectedWidth = kDefaultCanvasDimension;
static int gLastSelectedHeight = kDefaultCanvasDimension;


@interface PPDocumentSizeSheetController (PrivateMethods)

- initWithDelegate: (id) delegate;

- (void) addAsObserverForPPImageSizePresetsNotifications;
- (void) removeAsObserverForPPImageSizePresetsNotifications;
- (void) handlePPImageSizePresetsNotification_UpdatedPresets: (NSNotification *) notification;

- (void) setupMenuForSizePresetsPopUpButton;

@end


#if PP_SDK_REQUIRES_PROTOCOLS_FOR_DELEGATES_AND_DATASOURCES

@interface PPDocumentSizeSheetController (RequiredProtocols) <NSTextFieldDelegate>
@end

#endif  // PP_SDK_REQUIRES_PROTOCOLS_FOR_DELEGATES_AND_DATASOURCES


@implementation PPDocumentSizeSheetController

+ (bool) beginSizeSheetForDocumentWindow: (NSWindow *) window
            delegate: (id) delegate
{
    PPDocumentSizeSheetController *controller;

    controller = [[[self alloc] initWithDelegate: delegate] autorelease];

    if (![controller beginSheetModalForWindow: window])
    {
        goto ERROR;
    }

    return YES;

ERROR:
    return NO;
}

- initWithDelegate: (id) delegate
{
    self = [super initWithNibNamed: kDocumentSizeSheetNibName delegate: delegate];

    if (!self)
        goto ERROR;

    [_sizePresetsTitleablePopUpButton setDelegate: self];

    _widthTextFieldValue = gLastSelectedWidth;
    [_widthTextField setIntValue: _widthTextFieldValue];
    [_widthTextField setDelegate: self];

    _heightTextFieldValue = gLastSelectedHeight;
    [_heightTextField setIntValue: _heightTextFieldValue];
    [_heightTextField setDelegate: self];

    [self setupMenuForSizePresetsPopUpButton];

    [self addAsObserverForPPImageSizePresetsNotifications];

    return self;

ERROR:
    [self release];

    return nil;
}

- init
{
    return [self initWithDelegate: nil];
}

- (void) dealloc
{
    [_sizePresetsTitleablePopUpButton setDelegate: nil];

    [self removeAsObserverForPPImageSizePresetsNotifications];

    [super dealloc];
}

#pragma mark Actions

- (IBAction) sizePresetsMenuItemSelected_CustomDimensions: (id) sender
{
}

- (IBAction) sizePresetsMenuItemSelected_PresetSize: (id) sender
{
    NSSize presetSize = PPImageSizePresets_SizeForPresetString([sender title]);

    if (PPGeometry_IsZeroSize(presetSize))
    {
        return;
    }

    _widthTextFieldValue = presetSize.width;
    [_widthTextField setIntValue: _widthTextFieldValue];

    _heightTextFieldValue = presetSize.height;
    [_heightTextField setIntValue: _heightTextFieldValue];

    [_widthTextField selectText: self];
}

- (IBAction) sizePresetsMenuItemSelected_EditSizePresets: (id) sender
{
    [PPDocumentEditImageSizePresetsSheetController
                beginEditImageSizePresetsSheetForWindow: _sheet
                delegate: self];
}

#pragma mark PPDocumentSheetController overrides (actions)

- (IBAction) OKButtonPressed: (id) sender
{
    [super OKButtonPressed: sender];

    gLastSelectedWidth = _widthTextFieldValue;
    gLastSelectedHeight = _heightTextFieldValue;
}

#pragma mark PPDocumentSheetController overrides (delegate notifiers)

- (void) notifyDelegateSheetDidFinish
{
    if ([_delegate respondsToSelector:
                        @selector(documentSizeSheetDidFinishWithWidth:andHeight:)])
    {
        [_delegate documentSizeSheetDidFinishWithWidth: _widthTextFieldValue
                                            andHeight: _heightTextFieldValue];
    }
}

- (void) notifyDelegateSheetDidCancel
{
    if ([_delegate respondsToSelector: @selector(documentSizeSheetDidCancel)])
    {
        [_delegate documentSizeSheetDidCancel];
    }
}

#pragma mark PPTitleablePopUpButton delegate methods

- (NSString *) displayTitleForMenuItemWithTitle: (NSString *) itemTitle
                onTitleablePopUpButton: (PPTitleablePopUpButton *) button
{
    return PPImageSizePresets_NameForPresetString(itemTitle);
}

#pragma mark NSTextField delegate methods (width/height textfields)

- (void) controlTextDidChange: (NSNotification *) notification
{
    id notifyingObject = [notification object];

    if (notifyingObject == _widthTextField)
    {
        _widthTextFieldValue = [_widthTextField ppClampIntValueToMax: kMaxCanvasDimension
                                                    min: kMinCanvasDimension
                                                    defaultValue: _widthTextFieldValue];
    }
    else if (notifyingObject == _heightTextField)
    {
        _heightTextFieldValue = [_heightTextField ppClampIntValueToMax: kMaxCanvasDimension
                                                    min: kMinCanvasDimension
                                                    defaultValue: _heightTextFieldValue];
    }

    if ([_sizePresetsTitleablePopUpButton indexOfSelectedItem]
            != _indexOfSizePresetsMenuItem_CustomDimensions)
    {
        [_sizePresetsTitleablePopUpButton
                        selectItemAtIndex: _indexOfSizePresetsMenuItem_CustomDimensions];
    }
}

#pragma mark PPDocumentEditImageSizePresetsSheetController delegate methods

- (void) editImageSizePresetsSheetDidFinish
{
    [self setupMenuForSizePresetsPopUpButton];
}

- (void) editImageSizePresetsSheetDidCancel
{
    [self setupMenuForSizePresetsPopUpButton];
}

#pragma mark PPImageSizePresets notifications

- (void) addAsObserverForPPImageSizePresetsNotifications
{
    [[NSNotificationCenter defaultCenter]
                    addObserver: self
                    selector: @selector(handlePPImageSizePresetsNotification_UpdatedPresets:)
                    name: PPImageSizePresetsNotification_UpdatedPresets
                    object: nil];
}

- (void) removeAsObserverForPPImageSizePresetsNotifications
{
    [[NSNotificationCenter defaultCenter]
                                removeObserver: self
                                name: PPImageSizePresetsNotification_UpdatedPresets
                                object: nil];
}

- (void) handlePPImageSizePresetsNotification_UpdatedPresets: (NSNotification *) notification
{
    [self setupMenuForSizePresetsPopUpButton];
}

#pragma mark Private methods

- (void) setupMenuForSizePresetsPopUpButton
{
    NSMenu *popUpButtonMenu;
    int insertionIndex, indexOfItemToSelect;
    NSSize currentSize, presetSize;
    NSEnumerator *presetEnumerator;
    NSString *presetTitle;
    NSMenuItem *presetItem;

    popUpButtonMenu = [[_defaultSizePresetsMenu copy] autorelease];
    insertionIndex = [popUpButtonMenu indexOfItemWithTag: kTagOfSizeMenuItem_InsertionPoint];
    indexOfItemToSelect = -1;

    currentSize = NSMakeSize(_widthTextFieldValue, _heightTextFieldValue);

    presetEnumerator = [[PPImageSizePresets presetStrings] objectEnumerator];

    while (presetTitle = [presetEnumerator nextObject])
    {
        presetSize = PPImageSizePresets_SizeForPresetString(presetTitle);

        if (!PPGeometry_IsZeroSize(presetSize))
        {
            if (NSEqualSizes(presetSize, currentSize))
            {
                indexOfItemToSelect = insertionIndex;
            }

            presetItem = [[[NSMenuItem alloc]
                                        initWithTitle: presetTitle
                                        action:
                                            @selector(sizePresetsMenuItemSelected_PresetSize:)
                                        keyEquivalent: @""]
                                autorelease];

            [presetItem setTarget: self];

            [popUpButtonMenu insertItem: presetItem atIndex: insertionIndex++];
        }
    }

    _indexOfSizePresetsMenuItem_CustomDimensions =
                    [popUpButtonMenu indexOfItemWithTag: kTagOfSizeMenuItem_CustomDimensions];

    if (indexOfItemToSelect < 0)
    {
        indexOfItemToSelect = _indexOfSizePresetsMenuItem_CustomDimensions;
    }

    [_sizePresetsTitleablePopUpButton setMenu: popUpButtonMenu];
    [_sizePresetsTitleablePopUpButton selectItemAtIndex: indexOfItemToSelect];
}

@end
