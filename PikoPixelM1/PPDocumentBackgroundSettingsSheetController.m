/*
    PPDocumentBackgroundSettingsSheetController.m

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

#import "PPDocumentBackgroundSettingsSheetController.h"

#import "PPDefines.h"
#import "NSColor_PPUtilities.h"
#import "PPUserDefaults.h"
#import "PPBackgroundPattern.h"
#import "PPBackgroundPatternPresets.h"
#import "PPDocumentEditPatternPresetsSheetController.h"
#import "PPUserDefaultsInitialValues.h"
#import "NSImage_PPUtilities.h"
#import "NSPasteboard_PPUtilities.h"


#define kPatternPresetsMenuItemTag_DefaultPattern                   1
#define kPatternPresetsMenuItemTag_CustomPattern                    2
#define kPatternPresetsMenuItemTag_PatternPresetsInsertionPoint     3
#define kPatternPresetsMenuItemTag_ExportPresets                    4


#define kDocumentBackgroundSettingsSheetNibName     @"DocumentBackgroundSettingsSheet"

#define kExportPresetsSaveFileName                  @"PikoPixel patterns"

#define kBackgroundPatternTypeDisplayName           @"Background"


#define kUIColor_ActivePatternTypeCellGradientInnerColor    \
            [NSColor ppSRGBColorWithRed: 0.62f green: 0.78f blue: 0.96f alpha: 1.0f]

#define kUIColor_ActivePatternTypeCellGradientOuterColor    \
            [NSColor ppSRGBColorWithRed: 0.87f green: 0.99f blue: 1.0f alpha: 1.0f]

#define kUIColor_InactivePatternTypeCellGradientInnerColor  \
            [NSColor ppSRGBColorWithWhite: 0.90f alpha: 1.0f]

#define kUIColor_InactivePatternTypeCellGradientOuterColor  \
            [NSColor ppSRGBColorWithWhite: 0.97f alpha: 1.0f]


@interface PPDocumentBackgroundSettingsSheetController (PrivateMethods)

- initWithBackgroundPattern: (PPBackgroundPattern *) backgroundPattern
    backgroundImage: (NSImage *) backgroundImage
    backgroundImageVisibility: (bool) shouldDisplayBackgroundImage
    backgroundImageSmoothing: (bool) shouldSmoothenBackgroundImage
    delegate: (id) delegate;

- (void) addAsObserverForPPBackgroundPatternPresetsNotifications;
- (void) removeAsObserverForPPBackgroundPatternPresetsNotifications;
- (void) handlePPBackgroundPatternPresetsNotification_UpdatedPresets:
                                                                (NSNotification *) notification;

- (void) setupMenuForPatternPresetsPopUpButton;

- (void) setBackgroundPattern: (PPBackgroundPattern *) backgroundPattern
            andSetupSheet: (bool) shouldSetupSheet;

- (void) setupSheetWithCurrentBackgroundPattern;
- (void) loadBackgroundPatternFromSheet;

- (PPBackgroundPattern *) backgroundPatternFromSheet;

- (void) setBackgroundImage: (NSImage *) image;

- (void) updateEnabledStatesOfBackgroundImageControls;

- (void) notifyDelegateDidUpdatePattern;
- (void) notifyDelegateDidUpdateImage;
- (void) notifyDelegateDidUpdateImageVisibility;
- (void) notifyDelegateDidUpdateImageSmoothing;

@end

@implementation PPDocumentBackgroundSettingsSheetController

+ (bool) beginBackgroundSettingsSheetForDocumentWindow: (NSWindow *) window
            backgroundPattern: (PPBackgroundPattern *) backgroundPattern
            backgroundImage: (NSImage *) backgroundImage
            backgroundImageVisibility: (bool) shouldDisplayBackgroundImage
            backgroundImageSmoothing: (bool) shouldSmoothenBackgroundImage
            delegate: (id) delegate
{
    PPDocumentBackgroundSettingsSheetController *controller;

    controller = [[[self alloc] initWithBackgroundPattern: backgroundPattern
                                backgroundImage: backgroundImage
                                backgroundImageVisibility: shouldDisplayBackgroundImage
                                backgroundImageSmoothing: shouldSmoothenBackgroundImage
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

- initWithBackgroundPattern: (PPBackgroundPattern *) backgroundPattern
    backgroundImage: (NSImage *) backgroundImage
    backgroundImageVisibility: (bool) shouldDisplayBackgroundImage
    backgroundImageSmoothing: (bool) shouldSmoothenBackgroundImage
    delegate: (id) delegate
{
    unsigned gradientHeight;

    self = [super initWithNibNamed: kDocumentBackgroundSettingsSheetNibName
                    delegate: delegate];

    if (!self)
        goto ERROR;

    if (!backgroundPattern)
        goto ERROR;

    gradientHeight = [_patternTypeMatrix cellSize].height;

    _activePatternTypeCellColor =
        [[NSColor ppCenteredVerticalGradientPatternColorWithHeight: gradientHeight
                            innerColor: kUIColor_ActivePatternTypeCellGradientInnerColor
                            outerColor: kUIColor_ActivePatternTypeCellGradientOuterColor]
                retain];

    _inactivePatternTypeCellColor =
        [[NSColor ppCenteredVerticalGradientPatternColorWithHeight: gradientHeight
                            innerColor: kUIColor_InactivePatternTypeCellGradientInnerColor
                            outerColor: kUIColor_InactivePatternTypeCellGradientOuterColor]
                retain];

    if (!_activePatternTypeCellColor || !_inactivePatternTypeCellColor)
    {
        goto ERROR;
    }

    [[_patternTypeMatrix cells] makeObjectsPerformSelector: @selector(setBackgroundColor:)
                                withObject: _inactivePatternTypeCellColor];

    [_patternSizeSlider setMinValue: kMinBackgroundPatternSize];
    [_patternSizeSlider setMaxValue: kMaxBackgroundPatternSize];

    [self setBackgroundPattern: backgroundPattern andSetupSheet: YES];

    [self setupMenuForPatternPresetsPopUpButton];

    [_backgroundImageView setImage: backgroundImage];
    [_showImageCheckbox setIntValue: shouldDisplayBackgroundImage];
    [_imageSmoothingCheckbox setIntValue: shouldSmoothenBackgroundImage];

    [self updateEnabledStatesOfBackgroundImageControls];

    [self addAsObserverForPPBackgroundPatternPresetsNotifications];

    return self;

ERROR:
    [self release];

    return nil;
}

- init
{
    return [self initWithBackgroundPattern: nil
                    backgroundImage: nil
                    backgroundImageVisibility: NO
                    backgroundImageSmoothing: NO
                    delegate: nil];
}

- (void) dealloc
{
    [self removeAsObserverForPPBackgroundPatternPresetsNotifications];

    [_lastCustomBackgroundPattern release];
    [_backgroundPattern release];

    [_activePatternTypeCellColor release];
    [_inactivePatternTypeCellColor release];

    [super dealloc];
}

#pragma mark Actions

- (IBAction) patternSettingChanged: (id) sender
{
    [self loadBackgroundPatternFromSheet];

    if (sender == _patternTypeMatrix)
    {
        [self setupSheetWithCurrentBackgroundPattern];
    }

    if ([_patternPresetsPopUpButton indexOfSelectedItem]
            != _indexOfPatternPresetsMenuItem_CustomPattern)
    {
        [_patternPresetsPopUpButton selectItemAtIndex:
                                            _indexOfPatternPresetsMenuItem_CustomPattern];
    }
}

- (IBAction) patternPresetsMenuItemSelected_DefaultPattern: (id) sender
{
    [self setBackgroundPattern: [PPUserDefaults backgroundPattern] andSetupSheet: YES];
}

- (IBAction) patternPresetsMenuItemSelected_CustomPattern: (id) sender
{
    if (!_lastCustomBackgroundPattern)
        return;

    [self setBackgroundPattern: _lastCustomBackgroundPattern andSetupSheet: YES];
}

- (IBAction) patternPresetsMenuItemSelected_PresetPattern: (id) sender
{
    int indexOfPattern;
    NSArray *presetPatterns;

    if (![sender isKindOfClass: [NSMenuItem class]])
    {
        goto ERROR;
    }

    indexOfPattern = [((NSMenuItem *) sender) tag];

    presetPatterns = [[PPBackgroundPatternPresets sharedPresets] patterns];

    if ((indexOfPattern < 0) || (indexOfPattern >= [presetPatterns count]))
    {
        goto ERROR;
    }

    [self setBackgroundPattern: [presetPatterns objectAtIndex: indexOfPattern]
            andSetupSheet: YES];

    return;

ERROR:
    return;
}

- (IBAction) patternPresetsMenuItemSelected_AddCurrentPatternToPresets: (id) sender
{
    [PPDocumentEditPatternPresetsSheetController
                                            beginEditPatternPresetsSheetForWindow: _sheet
                                            patternPresets:
                                                    [PPBackgroundPatternPresets sharedPresets]
                                            patternTypeDisplayName:
                                                    kBackgroundPatternTypeDisplayName
                                            currentPattern: [self backgroundPatternFromSheet]
                                            addCurrentPatternAsPreset: YES
                                            delegate: self];
}

- (IBAction) patternPresetsMenuItemSelected_EditPresets: (id) sender
{
    [PPDocumentEditPatternPresetsSheetController
                                            beginEditPatternPresetsSheetForWindow: _sheet
                                            patternPresets:
                                                    [PPBackgroundPatternPresets sharedPresets]
                                            patternTypeDisplayName:
                                                    kBackgroundPatternTypeDisplayName
                                            currentPattern: [self backgroundPatternFromSheet]
                                            addCurrentPatternAsPreset: NO
                                            delegate: self];
}

- (IBAction) patternPresetsMenuItemSelected_ExportPresetsToFile: (id) sender
{
    NSSavePanel *savePanel = [NSSavePanel savePanel];

    [savePanel setAllowedFileTypes:
                                [[PPBackgroundPatternPresets sharedPresets] presetsFiletypes]];

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

- (IBAction) patternPresetsMenuItemSelected_ImportPresetsFromFile: (id) sender
{
    /*[[NSOpenPanel openPanel]
                        beginSheetForDirectory: nil
                        file: nil
                        types: [[PPBackgroundPatternPresets sharedPresets] presetsFiletypes]
                        modalForWindow: _sheet
                        modalDelegate: self
                        didEndSelector: @selector(importPresetsOpenPanelDidEnd:returnCode:
                                                    contextInfo:)
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

- (IBAction) patternPresetsMenuItemSelected_SavePatternAsDefault: (id) sender
{
    [PPUserDefaults setBackgroundPattern: _backgroundPattern];

    if ([_backgroundPattern isEqualToBackgroundPattern: [PPUserDefaults backgroundPattern]])
    {
        [_patternPresetsPopUpButton selectItemAtIndex:
                                            _indexOfPatternPresetsMenuItem_DefaultPattern];
    }
}

- (IBAction) patternPresetsMenuItemSelected_RestoreOriginalDefault: (id) sender
{
    [PPUserDefaults setBackgroundPattern: kUserDefaultsInitialValue_BackgroundPattern];
    [self setBackgroundPattern: [PPUserDefaults backgroundPattern] andSetupSheet: YES];

    [_patternPresetsPopUpButton selectItemAtIndex:
                                            _indexOfPatternPresetsMenuItem_DefaultPattern];
}

- (IBAction) backgroundImageViewUpdated: (id) sender
{
    [self updateEnabledStatesOfBackgroundImageControls];

    [self notifyDelegateDidUpdateImage];
}

- (IBAction) showImageCheckboxClicked: (id) sender
{
    [self updateEnabledStatesOfBackgroundImageControls];

    [self notifyDelegateDidUpdateImageVisibility];
}

- (IBAction) imageSmoothingCheckboxClicked: (id) sender
{
    [self notifyDelegateDidUpdateImageSmoothing];
}

- (IBAction) setImageToFileButtonPressed: (id) sender
{
    /*[[NSOpenPanel openPanel] beginSheetForDirectory: nil
                                file: nil
                                types: [NSImage imageTypes]
                                modalForWindow: _sheet
                                modalDelegate: self
                                didEndSelector:
                                    @selector(backgroundImageOpenPanelDidEnd:
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

- (IBAction) setImageToPasteboardButtonPressed: (id) sender
{
    NSBitmapImageRep *imageBitmap;
    NSImage *image;

    if (![NSPasteboard ppGetImageBitmap: &imageBitmap])
    {
        goto ERROR;
    }

    image = [NSImage ppImageWithBitmap: imageBitmap];

    if (!image)
        goto ERROR;

    [self setBackgroundImage: image];

    return;

ERROR:
    return;
}

- (IBAction) copyImageToPasteboardButtonPressed: (id) sender
{
    NSImage *backgroundImage = [_backgroundImageView image];

    if (!backgroundImage)
        return;

    [NSPasteboard ppSetImageBitmap: [backgroundImage ppBitmap]];
}

- (IBAction) removeImageButtonPressed: (id) sender
{
    [self setBackgroundImage: nil];
}

#pragma mark PPDocumentSheetController overrides

- (void) endSheet
{
    if ([_patternColor1Well isActive])
    {
        [_patternColor1Well deactivate];
    }

    if ([_patternColor2Well isActive])
    {
        [_patternColor2Well deactivate];
    }

    [super endSheet];
}

#pragma mark PPDocumentSheetController overrides (delegate notifiers)

- (void) notifyDelegateSheetDidFinish
{
    if ([_delegate respondsToSelector:
                            @selector(backgroundSettingsSheetDidFinishWithBackgroundPattern:
                                        backgroundImage:shouldDisplayImage:
                                        shouldSmoothenImage:)])
    {
        [_delegate backgroundSettingsSheetDidFinishWithBackgroundPattern: _backgroundPattern
                        backgroundImage: [_backgroundImageView image]
                        shouldDisplayImage: ([_showImageCheckbox intValue]) ? YES : NO
                        shouldSmoothenImage: ([_imageSmoothingCheckbox intValue]) ? YES : NO];
    }
}

- (void) notifyDelegateSheetDidCancel
{
    if ([_delegate respondsToSelector: @selector(backgroundSettingsSheetDidCancel)])
    {
        [_delegate backgroundSettingsSheetDidCancel];
    }
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
            [[PPBackgroundPatternPresets sharedPresets]
                                            savePatternsToPresetsFile: [presetsFileURL path]];
        }
    }

    [self setupMenuForPatternPresetsPopUpButton];
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
            [[PPBackgroundPatternPresets sharedPresets]
                                            addPatternsFromPresetsFile: [presetsFileURL path]];
        }
    }

    [self setupMenuForPatternPresetsPopUpButton];
}

#pragma mark NSOpenPanel delegate (background image)

- (void) backgroundImageOpenPanelDidEnd: (NSOpenPanel *) panel
                returnCode: (int) returnCode
                contextInfo: (void  *) contextInfo
{
    [panel orderOut: self];

    if (returnCode == NSModalResponseOK)
    {
        NSURL *imageURL;
        NSImage *image = nil;

        imageURL = [[panel URLs] objectAtIndex: 0];

        if (imageURL)
        {
            image = [[[NSImage alloc] initWithContentsOfURL: imageURL] autorelease];
        }

        [self setBackgroundImage: image];
    }
}

#pragma mark PPDocumentEditPatternPresetsSheetController delegate methods

- (void) editPatternPresetsSheetDidFinish
{
    [self setupMenuForPatternPresetsPopUpButton];
}

- (void) editPatternPresetsSheetDidCancel
{
    [self setupMenuForPatternPresetsPopUpButton];
}

#pragma mark PPBackgroundPatternPresets notifications

- (void) addAsObserverForPPBackgroundPatternPresetsNotifications
{
    PPBackgroundPatternPresets *backgroundPatternPresets =
                                                    [PPBackgroundPatternPresets sharedPresets];

    if (!backgroundPatternPresets)
        goto ERROR;

    [[NSNotificationCenter defaultCenter]
                    addObserver: self
                    selector:
                        @selector(handlePPBackgroundPatternPresetsNotification_UpdatedPresets:)
                    name: PPPatternPresetsNotification_UpdatedPresets
                    object: backgroundPatternPresets];

    return;

ERROR:
    return;
}

- (void) removeAsObserverForPPBackgroundPatternPresetsNotifications
{
    [[NSNotificationCenter defaultCenter]
                                removeObserver: self
                                name: PPPatternPresetsNotification_UpdatedPresets
                                object: nil];
}

- (void) handlePPBackgroundPatternPresetsNotification_UpdatedPresets:
                                                                (NSNotification *) notification
{
    [self setupMenuForPatternPresetsPopUpButton];
}

#pragma mark Private methods

- (void) setupMenuForPatternPresetsPopUpButton
{
    NSMenu *popUpButtonMenu;
    int insertionIndex, indexOfItemToSelect, numPresetPatterns, presetIndex;
    NSArray *presetPatterns;
    PPBackgroundPattern *presetPattern;
    NSString *presetTitle;
    NSMenuItem *presetItem;
    bool needToInsertMenuSeparator = NO;

    popUpButtonMenu = [[_defaultPatternPresetsMenu copy] autorelease];

    presetPatterns = [[PPBackgroundPatternPresets sharedPresets] patterns];
    numPresetPatterns = [presetPatterns count];

    if (!numPresetPatterns)
    {
        // use PPSDKNativeType_NSMenuItemPtr for exportPresetsItem, as -[NSMenu itemWithTag:]
        // could return either (NSMenuItem *) or (id <NSMenuItem>), depending on the SDK
        PPSDKNativeType_NSMenuItemPtr exportPresetsItem =
                        [popUpButtonMenu itemWithTag: kPatternPresetsMenuItemTag_ExportPresets];

        [popUpButtonMenu removeItem: exportPresetsItem];
    }

    insertionIndex = _indexOfPatternPresetsMenuItem_FirstPatternPreset =
        [popUpButtonMenu indexOfItemWithTag:
                                    kPatternPresetsMenuItemTag_PatternPresetsInsertionPoint];

    indexOfItemToSelect = -1;

    for (presetIndex=0; presetIndex<numPresetPatterns; presetIndex++)
    {
        presetPattern = [presetPatterns objectAtIndex: presetIndex];

        if ((indexOfItemToSelect < 0)
            && [_backgroundPattern isEqualToBackgroundPattern: presetPattern])
        {
            indexOfItemToSelect = insertionIndex;
        }

        presetTitle = [presetPattern presetName];

        presetItem = [[[NSMenuItem alloc]
                                    initWithTitle: (presetTitle) ? presetTitle : @""
                                    action:
                                        @selector(patternPresetsMenuItemSelected_PresetPattern:)
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

    _indexOfPatternPresetsMenuItem_DefaultPattern =
            [popUpButtonMenu indexOfItemWithTag: kPatternPresetsMenuItemTag_DefaultPattern];

    _indexOfPatternPresetsMenuItem_CustomPattern =
            [popUpButtonMenu indexOfItemWithTag: kPatternPresetsMenuItemTag_CustomPattern];

    if ([_backgroundPattern isEqualToBackgroundPattern: [PPUserDefaults backgroundPattern]])
    {
        indexOfItemToSelect = _indexOfPatternPresetsMenuItem_DefaultPattern;
    }

    if (indexOfItemToSelect < 0)
    {
        indexOfItemToSelect = _indexOfPatternPresetsMenuItem_CustomPattern;

        if (!_lastCustomBackgroundPattern)
        {
            _lastCustomBackgroundPattern = [_backgroundPattern retain];
        }
    }

    [_patternPresetsPopUpButton setMenu: popUpButtonMenu];

    [_patternPresetsPopUpButton selectItemAtIndex: indexOfItemToSelect];
}

- (void) setBackgroundPattern: (PPBackgroundPattern *) backgroundPattern
            andSetupSheet: (bool) shouldSetupSheet
{
    if (!backgroundPattern
        || [_backgroundPattern isEqualToBackgroundPattern: backgroundPattern])
    {
        return;
    }

    [_backgroundPattern release];
    _backgroundPattern = [backgroundPattern retain];

    if (shouldSetupSheet)
    {
        [self setupSheetWithCurrentBackgroundPattern];
    }

    [_patternDisplayField setBackgroundColor: [_backgroundPattern patternFillColor]];

    [self notifyDelegateDidUpdatePattern];
}

- (void) setupSheetWithCurrentBackgroundPattern
{
    NSButtonCell *lastActivePatternTypeCell, *activePatternTypeCell;

    lastActivePatternTypeCell =
                        [_patternTypeMatrix cellWithTag: _tagOfActivePatternTypeMatrixCell];
    [lastActivePatternTypeCell setBackgroundColor: _inactivePatternTypeCellColor];

    _tagOfActivePatternTypeMatrixCell = [_backgroundPattern patternType];
    activePatternTypeCell = [_patternTypeMatrix cellWithTag: _tagOfActivePatternTypeMatrixCell];
    [_patternTypeMatrix selectCell: activePatternTypeCell];
    [activePatternTypeCell setBackgroundColor: _activePatternTypeCellColor];

    [_patternSizeSlider setFloatValue: [_backgroundPattern patternSize]];

    [_patternColor1Well setColor: [_backgroundPattern color1]];
    [_patternColor2Well setColor: [_backgroundPattern color2]];
}

- (void) loadBackgroundPatternFromSheet
{
    PPBackgroundPattern *backgroundPattern;

    backgroundPattern = [self backgroundPatternFromSheet];

    if (!backgroundPattern)
        return;

    [self setBackgroundPattern: backgroundPattern andSetupSheet: NO];

    [_lastCustomBackgroundPattern release];
    _lastCustomBackgroundPattern = [backgroundPattern retain];
}

- (PPBackgroundPattern *) backgroundPatternFromSheet
{
    return [PPBackgroundPattern backgroundPatternOfType: [[_patternTypeMatrix selectedCell] tag]
                                patternSize: [_patternSizeSlider floatValue]
                                color1: [_patternColor1Well color]
                                color2: [_patternColor2Well color]];
}

- (void) setBackgroundImage: (NSImage *) image
{
    [_backgroundImageView setImage: image];

    [self updateEnabledStatesOfBackgroundImageControls];

    [self notifyDelegateDidUpdateImage];
}

- (void) updateEnabledStatesOfBackgroundImageControls
{
    bool hasBackgroundImage = ([_backgroundImageView image]) ? YES : NO;

    [_showImageCheckbox setEnabled: hasBackgroundImage];
    [_imageSmoothingCheckbox setEnabled:
                                    (hasBackgroundImage && [_showImageCheckbox intValue]) ?
                                        YES : NO];

    [_copyImageToPasteboardButton setEnabled: hasBackgroundImage];
    [_removeImageButton setEnabled: hasBackgroundImage];
}

#pragma mark Delegate notifiers

- (void) notifyDelegateDidUpdatePattern
{
    if ([_delegate respondsToSelector: @selector(backgroundSettingsSheetDidUpdatePattern:)])
    {
        [_delegate backgroundSettingsSheetDidUpdatePattern: _backgroundPattern];
    }
}

- (void) notifyDelegateDidUpdateImage
{
    if ([_delegate respondsToSelector: @selector(backgroundSettingsSheetDidUpdateImage:)])
    {
        [_delegate backgroundSettingsSheetDidUpdateImage: [_backgroundImageView image]];
    }
}

- (void) notifyDelegateDidUpdateImageVisibility
{
    if ([_delegate respondsToSelector:
                                @selector(backgroundSettingsSheetDidUpdateImageVisibility:)])
    {
        [_delegate backgroundSettingsSheetDidUpdateImageVisibility:
                                                ([_showImageCheckbox intValue]) ? YES : NO];
    }
}

- (void) notifyDelegateDidUpdateImageSmoothing
{
    if ([_delegate respondsToSelector:
                                @selector(backgroundSettingsSheetDidUpdateImageSmoothing:)])
    {
        [_delegate backgroundSettingsSheetDidUpdateImageSmoothing:
                                            ([_imageSmoothingCheckbox intValue]) ? YES : NO];
    }
}

@end
