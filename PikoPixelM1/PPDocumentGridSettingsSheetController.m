/*
    PPDocumentGridSettingsSheetController.m

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

#import "PPDocumentGridSettingsSheetController.h"

#import "PPDefines.h"
#import "PPGridPattern.h"
#import "PPGridPatternPresets.h"
#import "PPUserDefaults.h"
#import "PPDocumentEditPatternPresetsSheetController.h"
#import "PPUserDefaultsInitialValues.h"
#import "NSTextField_PPUtilities.h"


#define kDocumentGridSettingsSheetNibName   @"DocumentGridSettingsSheet"

#define kExportPresetsSaveFileName          @"PikoPixel grid patterns"

#define kGridPatternTypeDisplayName         @"Grid"

#define kPresetsMenuItemTag_DefaultPattern                  1
#define kPresetsMenuItemTag_CustomPattern                   2
#define kPresetsMenuItemTag_PatternPresetsInsertionPoint    3
#define kPresetsMenuItemTag_ExportPresets                   4


@interface PPDocumentGridSettingsSheetController (PrivateMethods)

- initWithGridPattern: (PPGridPattern *) gridPattern
    gridVisibility: (bool) shouldDisplayGrid
    delegate: (id) delegate;

- (void) addAsObserverForPPGridPatternPresetsNotifications;
- (void) removeAsObserverForPPGridPatternPresetsNotifications;
- (void) handlePPGridPatternPresetsNotification_UpdatedPresets: (NSNotification *) notification;

- (void) setupMenuForPresetsPopUpButton;

- (void) setGridPattern: (PPGridPattern *) gridPattern
            andGridVisibility: (bool) shouldDisplayGrid;

- (void) loadGridSettingsFromSheetState;
- (void) setupSheetStateWithGridSettings;

- (void) notifyDelegateDidUpdateGridSettings;

@end


#if PP_SDK_REQUIRES_PROTOCOLS_FOR_DELEGATES_AND_DATASOURCES

@interface PPDocumentGridSettingsSheetController (RequiredProtocols) <NSTextFieldDelegate>
@end

#endif  // PP_SDK_REQUIRES_PROTOCOLS_FOR_DELEGATES_AND_DATASOURCES


@implementation PPDocumentGridSettingsSheetController

+ (bool) beginGridSettingsSheetForDocumentWindow: (NSWindow *) window
            gridPattern: (PPGridPattern *) gridPattern
            gridVisibility: (bool) shouldDisplayGrid
            delegate: (id) delegate;
{
    PPDocumentGridSettingsSheetController *controller;

    controller = [[[self alloc] initWithGridPattern: gridPattern
                                gridVisibility: shouldDisplayGrid
                                delegate: delegate]
                            autorelease];

    if (![controller beginSheetModalForWindow: window])
    {
        goto ERROR;
    }

    return YES;

ERROR:
    return NO;
}

- initWithGridPattern: (PPGridPattern *) gridPattern
    gridVisibility: (bool) shouldDisplayGrid
    delegate: (id) delegate;
{
    self = [super initWithNibNamed: kDocumentGridSettingsSheetNibName delegate: delegate];

    if (!self)
        goto ERROR;

    if (!gridPattern)
        goto ERROR;

    _gridPattern = [gridPattern retain];
    _gridVisibility = (shouldDisplayGrid) ? YES : NO;

    [self setupSheetStateWithGridSettings];

    [self setupMenuForPresetsPopUpButton];

    [self addAsObserverForPPGridPatternPresetsNotifications];

    [_guidelinesHorizontalSpacingTextField setDelegate: self];
    [_guidelinesVerticalSpacingTextField setDelegate: self];

    return self;

ERROR:
    [self release];

    return nil;
}

- init
{
    return [self initWithGridPattern: nil gridVisibility: NO delegate: nil];
}

- (void) dealloc
{
    [self removeAsObserverForPPGridPatternPresetsNotifications];

    [_lastCustomGridPattern release];
    [_gridPattern release];

    [super dealloc];
}

#pragma mark Actions

- (IBAction) showGridCheckboxClicked: (id) sender
{
    _gridVisibility = ([_showGridCheckbox intValue]) ? YES : NO;

    [self notifyDelegateDidUpdateGridSettings];
}

- (IBAction) gridSettingChanged: (id) sender
{
    [self loadGridSettingsFromSheetState];

    if ([_presetsPopUpButton indexOfSelectedItem] != _indexOfPresetsMenuItem_CustomPattern)
    {
        [_presetsPopUpButton selectItemAtIndex: _indexOfPresetsMenuItem_CustomPattern];
    }
}

- (IBAction) presetsMenuItemSelected_DefaultPattern: (id) sender
{
    [self setGridPattern: [PPUserDefaults gridPattern]
            andGridVisibility: [PPUserDefaults gridVisibility]];
}

- (IBAction) presetsMenuItemSelected_CustomPattern: (id) sender;
{
    if (!_lastCustomGridPattern)
        return;

    [self setGridPattern: _lastCustomGridPattern
            andGridVisibility: _gridVisibility];
}

- (IBAction) presetsMenuItemSelected_PresetPattern: (id) sender
{
    int indexOfPattern;
    NSArray *presetPatterns;

    if (![sender isKindOfClass: [NSMenuItem class]])
    {
        goto ERROR;
    }

    indexOfPattern = [((NSMenuItem *) sender) tag];

    presetPatterns = [[PPGridPatternPresets sharedPresets] patterns];

    if ((indexOfPattern < 0) || (indexOfPattern >= [presetPatterns count]))
    {
        goto ERROR;
    }

    [self setGridPattern: [presetPatterns objectAtIndex: indexOfPattern]
            andGridVisibility: _gridVisibility];

    return;

ERROR:
    return;
}

- (IBAction) presetsMenuItemSelected_AddCurrentPatternToPresets: (id) sender
{
    [PPDocumentEditPatternPresetsSheetController
                                            beginEditPatternPresetsSheetForWindow: _sheet
                                            patternPresets: [PPGridPatternPresets sharedPresets]
                                            patternTypeDisplayName: kGridPatternTypeDisplayName
                                            currentPattern: _gridPattern
                                            addCurrentPatternAsPreset: YES
                                            delegate: self];
}

- (IBAction) presetsMenuItemSelected_EditPresets: (id) sender
{
    [PPDocumentEditPatternPresetsSheetController
                                            beginEditPatternPresetsSheetForWindow: _sheet
                                            patternPresets: [PPGridPatternPresets sharedPresets]
                                            patternTypeDisplayName: kGridPatternTypeDisplayName
                                            currentPattern: _gridPattern
                                            addCurrentPatternAsPreset: NO
                                            delegate: self];
}

- (IBAction) presetsMenuItemSelected_ExportPresetsToFile: (id) sender
{
    NSSavePanel *savePanel = [NSSavePanel savePanel];

    [savePanel setAllowedFileTypes: [[PPGridPatternPresets sharedPresets] presetsFiletypes]];

    /*[savePanel beginSheetForDirectory: nil
                file: kExportPresetsSaveFileName
                modalForWindow: _sheet
                modalDelegate: self
                didEndSelector: @selector(exportPresetsSavePanelDidEnd:returnCode:contextInfo:)
                contextInfo: nil];*/
    
    //check
    [savePanel beginSheetModalForWindow:nil completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            NSLog(@"OK");
        } else {
            NSLog(@"CLOSE");
        }
    }];
}

- (IBAction) presetsMenuItemSelected_ImportPresetsFromFile: (id) sender
{
    /*[[NSOpenPanel openPanel] beginSheetForDirectory: nil
                                file: nil
                                types: [[PPGridPatternPresets sharedPresets] presetsFiletypes]
                                modalForWindow: _sheet
                                modalDelegate: self
                                didEndSelector: @selector(importPresetsOpenPanelDidEnd:
                                                            returnCode:contextInfo:)
                                contextInfo: nil];*/
    
    //check
    [[NSOpenPanel openPanel] beginSheetModalForWindow:nil completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            NSLog(@"OK");
        } else {
            NSLog(@"CLOSE");
        }
    }];
}

- (IBAction) presetsMenuItemSelected_SavePatternAsDefault: (id) sender
{
    [PPUserDefaults setGridPattern: _gridPattern
                    andGridVisibility: _gridVisibility];

    if ([_gridPattern isEqualToGridPattern: [PPUserDefaults gridPattern]])
    {
        [_presetsPopUpButton selectItemAtIndex: _indexOfPresetsMenuItem_DefaultPattern];
    }
}

- (IBAction) presetsMenuItemSelected_RestoreOriginalDefault: (id) sender
{
    [PPUserDefaults setGridPattern: kUserDefaultsInitialValue_GridPattern
                    andGridVisibility: kUserDefaultsInitialValue_GridVisibility];

    [self setGridPattern: [PPUserDefaults gridPattern]
            andGridVisibility: [PPUserDefaults gridVisibility]];

    [_presetsPopUpButton selectItemAtIndex: _indexOfPresetsMenuItem_DefaultPattern];
}

#pragma mark PPDocumentSheetController overrides

- (void) endSheet
{
    if ([_gridColorWell isActive])
    {
        [_gridColorWell deactivate];
    }

    if ([_guidelinesColorWell isActive])
    {
        [_guidelinesColorWell deactivate];
    }

    [super endSheet];
}

#pragma mark PPDocumentSheetController overrides (delegate notifiers)

- (void) notifyDelegateSheetDidFinish
{
    if ([_delegate respondsToSelector:
                        @selector(gridSettingsSheetDidFinishWithGridPattern:andVisibility:)])
    {
        [_delegate gridSettingsSheetDidFinishWithGridPattern: _gridPattern
                    andVisibility: _gridVisibility];
    }
}

- (void) notifyDelegateSheetDidCancel
{
    if ([_delegate respondsToSelector: @selector(gridSettingsSheetDidCancel)])
    {
        [_delegate gridSettingsSheetDidCancel];
    }
}

#pragma mark NSTextField delegate methods (guidelines horizontal/vertical spacing textfields)

- (void) controlTextDidChange: (NSNotification *) notification
{
    NSTextField *textField;
    int oldSpacingValue, newSpacingValue;

    textField = [notification object];

    if (textField == _guidelinesHorizontalSpacingTextField)
    {
        oldSpacingValue = [_gridPattern guidelineSpacingSize].width;
    }
    else if (textField == _guidelinesVerticalSpacingTextField)
    {
        oldSpacingValue = [_gridPattern guidelineSpacingSize].height;
    }
    else
    {
        goto ERROR;
    }

    newSpacingValue = [textField ppClampIntValueToMax: kMaxGridGuidelineSpacing
                                    min: kMinGridGuidelineSpacing
                                    defaultValue: oldSpacingValue];

    if (newSpacingValue != oldSpacingValue)
    {
        [self gridSettingChanged: self];
    }

    return;

ERROR:
    return;
}

#pragma mark NSSavePanel delegate (export presets)

- (void) exportPresetsSavePanelDidEnd: (NSSavePanel *) panel
                returnCode: (int) returnCode
                contextInfo: (void  *) contextInfo
{
    [panel orderOut: self];

    if (returnCode == NSModalResponseOK)
    {
        NSURL *presetsFileURL = [panel URL];

        if ([presetsFileURL isFileURL])
        {
            [[PPGridPatternPresets sharedPresets]
                                        savePatternsToPresetsFile: [presetsFileURL path]];
        }
    }

    [self setupMenuForPresetsPopUpButton];
}

#pragma mark NSOpenPanel delegate (import presets)

- (void) importPresetsOpenPanelDidEnd: (NSOpenPanel *) panel
                returnCode: (int) returnCode
                contextInfo: (void  *) contextInfo
{
    [panel orderOut: self];

    if (returnCode == NSModalResponseOK)
    {
        NSURL *presetsFileURL = [[panel URLs] objectAtIndex: 0];

        if ([presetsFileURL isFileURL])
        {
            [[PPGridPatternPresets sharedPresets]
                                        addPatternsFromPresetsFile: [presetsFileURL path]];
        }
    }

    [self setupMenuForPresetsPopUpButton];
}

#pragma mark PPDocumentEditPatternPresetsSheetController delegate methods

- (void) editPatternPresetsSheetDidFinish
{
    [self setupMenuForPresetsPopUpButton];
}

- (void) editPatternPresetsSheetDidCancel
{
    [self setupMenuForPresetsPopUpButton];
}

#pragma mark PPGridPatternPresets notifications

- (void) addAsObserverForPPGridPatternPresetsNotifications
{
    PPGridPatternPresets *gridPatternPresets = [PPGridPatternPresets sharedPresets];

    if (!gridPatternPresets)
        goto ERROR;

    [[NSNotificationCenter defaultCenter]
                    addObserver: self
                    selector: @selector(handlePPGridPatternPresetsNotification_UpdatedPresets:)
                    name: PPPatternPresetsNotification_UpdatedPresets
                    object: gridPatternPresets];

    return;

ERROR:
    return;
}

- (void) removeAsObserverForPPGridPatternPresetsNotifications
{
    [[NSNotificationCenter defaultCenter]
                                removeObserver: self
                                name: PPPatternPresetsNotification_UpdatedPresets
                                object: nil];
}

- (void) handlePPGridPatternPresetsNotification_UpdatedPresets: (NSNotification *) notification
{
    [self setupMenuForPresetsPopUpButton];
}

#pragma mark Private methods

- (void) setupMenuForPresetsPopUpButton
{
    NSMenu *popUpButtonMenu;
    int insertionIndex, indexOfItemToSelect, numPresetPatterns, presetIndex;
    NSArray *presetPatterns;
    PPGridPattern *presetPattern;
    NSString *presetTitle;
    NSMenuItem *presetItem;
    bool needToInsertMenuSeparator = NO;

    popUpButtonMenu = [[_defaultPresetsMenu copy] autorelease];

    presetPatterns = [[PPGridPatternPresets sharedPresets] patterns];
    numPresetPatterns = [presetPatterns count];

    if (!numPresetPatterns)
    {
        // use PPSDKNativeType_NSMenuItemPtr for exportPresetsItem, as -[NSMenu itemWithTag:]
        // could return either (NSMenuItem *) or (id <NSMenuItem>), depending on the SDK
        PPSDKNativeType_NSMenuItemPtr exportPresetsItem =
                        [popUpButtonMenu itemWithTag: kPresetsMenuItemTag_ExportPresets];

        [popUpButtonMenu removeItem: exportPresetsItem];
    }

    insertionIndex = _indexOfPresetsMenuItem_FirstPatternPreset =
        [popUpButtonMenu indexOfItemWithTag: kPresetsMenuItemTag_PatternPresetsInsertionPoint];

    indexOfItemToSelect = -1;

    for (presetIndex=0; presetIndex<numPresetPatterns; presetIndex++)
    {
        presetPattern = [presetPatterns objectAtIndex: presetIndex];

        if ((indexOfItemToSelect < 0)
            && [_gridPattern isEqualToGridPattern: presetPattern])
        {
            indexOfItemToSelect = insertionIndex;
        }

        presetTitle = [presetPattern presetName];

        presetItem = [[[NSMenuItem alloc]
                                    initWithTitle: (presetTitle) ? presetTitle : @""
                                    action: @selector(presetsMenuItemSelected_PresetPattern:)
                                    keyEquivalent: @""]
                            autorelease];

        if (presetItem)
        {
            [presetItem setTarget: self];
            [presetItem setTag: presetIndex];

            [popUpButtonMenu insertItem: presetItem atIndex: insertionIndex++];

            needToInsertMenuSeparator = YES;
        }
    }

    if (needToInsertMenuSeparator)
    {
        [popUpButtonMenu insertItem: [NSMenuItem separatorItem] atIndex: insertionIndex];
    }

    _indexOfPresetsMenuItem_DefaultPattern =
            [popUpButtonMenu indexOfItemWithTag: kPresetsMenuItemTag_DefaultPattern];

    _indexOfPresetsMenuItem_CustomPattern =
            [popUpButtonMenu indexOfItemWithTag: kPresetsMenuItemTag_CustomPattern];

    if ([_gridPattern isEqualToGridPattern: [PPUserDefaults gridPattern]])
    {
        indexOfItemToSelect = _indexOfPresetsMenuItem_DefaultPattern;
    }

    if (indexOfItemToSelect < 0)
    {
        indexOfItemToSelect = _indexOfPresetsMenuItem_CustomPattern;

        if (!_lastCustomGridPattern)
        {
            _lastCustomGridPattern = [_gridPattern retain];
        }
    }

    [_presetsPopUpButton setMenu: popUpButtonMenu];

    [_presetsPopUpButton selectItemAtIndex: indexOfItemToSelect];
}

- (void) setGridPattern: (PPGridPattern *) gridPattern
            andGridVisibility: (bool) shouldDisplayGrid
{
    if (!gridPattern)
        goto ERROR;

    [_gridPattern autorelease];
    _gridPattern = [gridPattern retain];

    _gridVisibility = (shouldDisplayGrid) ? YES : NO;

    [self setupSheetStateWithGridSettings];

    [self notifyDelegateDidUpdateGridSettings];

    return;

ERROR:
    return;
}

- (void) loadGridSettingsFromSheetState
{
    PPGridPattern *gridPattern;

    gridPattern = [PPGridPattern gridPatternWithPixelGridType:
                                        [_gridTypeSegmentedControl selectedSegment]
                                    pixelGridColor: [_gridColorWell color]
                                    guidelineSpacingSize:
                                        NSMakeSize(
                                            [_guidelinesHorizontalSpacingTextField intValue],
                                            [_guidelinesVerticalSpacingTextField intValue])
                                    guidelineColor: [_guidelinesColorWell color]
                                    shouldDisplayGuidelines:
                                        ([_showGuidelinesCheckbox intValue]) ? YES : NO];

    _gridVisibility = ([_showGridCheckbox intValue]) ? YES : NO;

    [_gridPattern release];
    _gridPattern = [gridPattern retain];

    [_lastCustomGridPattern release];
    _lastCustomGridPattern = [gridPattern retain];

    [self notifyDelegateDidUpdateGridSettings];
}

- (void) setupSheetStateWithGridSettings
{
    NSSize guidelineSpacingSize = [_gridPattern guidelineSpacingSize];

    [_showGridCheckbox setIntValue: _gridVisibility];

    [_gridTypeSegmentedControl setSelectedSegment: [_gridPattern pixelGridType]];

    [_gridColorWell setColor: [_gridPattern pixelGridColor]];

    [_showGuidelinesCheckbox setIntValue: [_gridPattern shouldDisplayGuidelines]];

    [_guidelinesHorizontalSpacingTextField setIntValue: (int) guidelineSpacingSize.width];

    [_guidelinesVerticalSpacingTextField setIntValue: (int) guidelineSpacingSize.height];

    [_guidelinesColorWell setColor: [_gridPattern guidelineColor]];
}

#pragma mark Delegate notifiers

- (void) notifyDelegateDidUpdateGridSettings
{
    if ([_delegate respondsToSelector:
                        @selector(gridSettingsSheetDidUpdateGridPattern:andVisibility:)])
    {
        [_delegate gridSettingsSheetDidUpdateGridPattern: _gridPattern
                    andVisibility: _gridVisibility];
    }
}

@end
