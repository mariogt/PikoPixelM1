/*
    PPExportPanelAccessoryViewController.m

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

#import "PPExportPanelAccessoryViewController.h"

#import "PPDocument.h"
#import "PPTitleablePopUpButton.h"
#import "PPGridPattern.h"
#import "PPBackgroundPattern.h"
#import "NSImage_PPUtilities.h"
#import "NSTextField_PPUtilities.h"
#import "PPGeometry.h"
#import "PPUserDefaults.h"
#import "PPGridPatternPresets.h"
#import "PPBackgroundPatternPresets.h"


#define kExportPanelAccessoryViewNibName                    @"ExportPanelAccessoryView"

#define kMinExportScalingFactor                             1
#define kMaxExportScalingFactor                             (kMaxCanvasZoomFactor + 10.0f)

#define kMarginPaddingForScrollerlessScrollView             2

#define kPatternPopUpMenuItemTitle_CurrentPattern           @"Current Document Pattern"
#define kPatternPopUpMenuItemTitle_DefaultPattern           @"Default Pattern"

#define kGridPopUpButtonTitle_CurrentPattern                @"Grid Pattern"
#define kGridPopUpButtonTitleFormat                         @"Grid: %@"

#define kBackgroundPatternPopUpButtonTitle_CurrentPattern   @"Background Pattern"
#define kBackgroundPatternPopUpButtonTitleFormat            @"Background: %@"


typedef enum
{
    kPatternMenuItemType_Current,
    kPatternMenuItemType_Default,
    kPatternMenuItemType_Preset

} PPPatternMenuItemType;


@interface PPExportPanelAccessoryViewController (PrivateMethods)

- (id) initWithPPDocument: (PPDocument *) ppDocument;

- (void) addAsObserverForNSWindowNotificationsFromPPDocumentWindow;
- (void) removeAsObserverForNSWindowNotificationsFromPPDocumentWindow;
- (void) handlePPDocumentWindowNotification_DidEndSheet: (NSNotification *) notification;

- (void) addAsObserverForNSViewNotificationsFromPreviewClipView;
- (void) removeAsObserverForNSViewNotificationsFromPreviewClipView;
- (void) handlePreviewClipViewNotification_BoundsDidChange: (NSNotification *) notification;

- (void) addAsObserverForPPGridPatternPresetsNotifications;
- (void) removeAsObserverForPPGridPatternPresetsNotifications;
- (void) handlePPGridPatternPresetsNotification_UpdatedPresets: (NSNotification *) notification;

- (void) addAsObserverForPPBackgroundPatternPresetsNotifications;
- (void) removeAsObserverForPPBackgroundPatternPresetsNotifications;
- (void) handlePPBackgroundPatternPresetsNotification_UpdatedPresets:
                                                                (NSNotification *) notification;

- (void) setupMaxScalingFactorForCurrentDocumentSize;

- (void) setupPopUpDefaultMenus;

- (void) setupMenuForGridPopUpButton;
- (void) setupMenuForBackgroundPatternPopUpButton;

- (void) setGridPattern: (PPGridPattern *) gridPattern;

- (void) setBackgroundPattern: (PPBackgroundPattern *) backgroundPattern;

- (void) setSavePanelRequiredFileTypeFromFileFormatPopUp;

- (void) updateBackgroundImageControlsForCurrentDocument;

- (void) updatePreviewImage;
- (void) clearPreviewImage;
- (void) resizePreviewViewForImageWithSize: (NSSize) previewImageSize;
- (void) scrollPreviewToNormalizedCenter;

@end


#if PP_SDK_REQUIRES_PROTOCOLS_FOR_DELEGATES_AND_DATASOURCES

@interface PPExportPanelAccessoryViewController (RequiredProtocols) <NSTextFieldDelegate>
@end

#endif  // PP_SDK_REQUIRES_PROTOCOLS_FOR_DELEGATES_AND_DATASOURCES


@implementation PPExportPanelAccessoryViewController

+ (PPExportPanelAccessoryViewController *) controllerForPPDocument: (PPDocument *) ppDocument
{
    return [[[self alloc] initWithPPDocument: ppDocument] autorelease];
}

- (id) initWithPPDocument: (PPDocument *) ppDocument
{
    self = [super init];

    if (!self)
        goto ERROR;

    if (!ppDocument || PPGeometry_IsZeroSize([ppDocument canvasSize]))
    {
        goto ERROR;
    }
    //check
    //if (![NSBundle loadNibNamed: kExportPanelAccessoryViewNibName owner: self])
    if(![[NSBundle mainBundle] loadNibNamed:kExportPanelAccessoryViewNibName owner:self topLevelObjects:nil])
    {
        goto ERROR;
    }

    _ppDocument = ppDocument;   // unretained to prevent retain loop

    _gridPattern = [[ppDocument gridPattern] retain];
    _backgroundPattern = [[ppDocument backgroundPattern] retain];

    _previewScrollViewInitialFrame = [[_previewImageView enclosingScrollView] frame];
    _previewScrollerWidth =
                _previewScrollViewInitialFrame.size.width
                    - [[[_previewImageView enclosingScrollView] contentView] frame].size.width;
    _previewViewNormalizedCenter = NSMakePoint(0.5f, 0.5f);

    [self addAsObserverForNSViewNotificationsFromPreviewClipView];

    _scalingFactor = kMinExportScalingFactor;
    _maxScalingFactor = kMaxExportScalingFactor;

    [_scalingFactorTextField setIntValue: _scalingFactor];
    [_scalingFactorTextField setDelegate: self];

    [_scalingFactorSlider setMinValue: kMinExportScalingFactor];
    [_scalingFactorSlider setMaxValue: _maxScalingFactor];
    [_scalingFactorSlider setIntValue: _scalingFactor];

    [self setupPopUpDefaultMenus];

    [_gridTitleablePopUpButton setDelegate: self];

    [_backgroundPatternTitleablePopUpButton setDelegate: self];

    return self;

ERROR:
    [self release];

    return nil;
}

- (id) init
{
    return [self initWithPPDocument: nil];
}

- (void) dealloc
{
    [self setupWithSavePanel: nil];

    [self removeAsObserverForNSViewNotificationsFromPreviewClipView];

    [_exportAccessoryView release];

    [_gridPopUpDefaultMenu release];
    [_backgroundPatternPopUpDefaultMenu release];

    [_gridPattern release];
    [_backgroundPattern release];

    [super dealloc];
}

- (void) setupWithSavePanel: (NSSavePanel *) savePanel
{
    if (_savePanel)
    {
        [_savePanel setAccessoryView: nil];

        [_savePanel release];
        _savePanel = nil;

        [self clearPreviewImage];

        [self removeAsObserverForNSWindowNotificationsFromPPDocumentWindow];

        [self removeAsObserverForPPGridPatternPresetsNotifications];
        [self removeAsObserverForPPBackgroundPatternPresetsNotifications];
    }

    if (savePanel)
    {
        _savePanel = [savePanel retain];

        [self setupMaxScalingFactorForCurrentDocumentSize];

        [self updateBackgroundImageControlsForCurrentDocument];

        [self updatePreviewImage];

        [self setupMenuForGridPopUpButton];
        [self setupMenuForBackgroundPatternPopUpButton];

        [_savePanel setAccessoryView: _exportAccessoryView];

        [self setSavePanelRequiredFileTypeFromFileFormatPopUp];

        [self addAsObserverForNSWindowNotificationsFromPPDocumentWindow];

        [self addAsObserverForPPGridPatternPresetsNotifications];
        [self addAsObserverForPPBackgroundPatternPresetsNotifications];
    }
}

- (NSString *) selectedFileTypeName
{
    return [[_fileFormatPopUpButton selectedItem] title];
}

- (NSString *) selectedFileType
{
    return [[_fileFormatPopUpButton selectedItem] toolTip];
}

- (bool) getScalingFactor: (unsigned *) returnedScalingFactor
            gridPattern: (PPGridPattern **) returnedGridPattern
            backgroundPattern: (PPBackgroundPattern **) returnedBackgroundPattern
            backgroundImageFlag: (bool *) returnedBackgroundImageFlag
{
    if (!returnedScalingFactor || !returnedGridPattern || !returnedBackgroundPattern
        || !returnedBackgroundImageFlag)
    {
        goto ERROR;
    }

    *returnedScalingFactor = _scalingFactor;

    *returnedGridPattern = ([_gridCheckbox intValue]) ? _gridPattern : nil;

    *returnedBackgroundPattern = ([_backgroundPatternCheckbox intValue]) ?
                                    _backgroundPattern : nil;

    *returnedBackgroundImageFlag = ([_backgroundImageCheckbox intValue]) ? YES : NO;

    return YES;

ERROR:
    return NO;
}

#pragma mark Actions

- (IBAction) scalingFactorSliderMoved: (id) sender
{
    int sliderValue = [_scalingFactorSlider intValue];

    if (_scalingFactor != sliderValue)
    {
        _scalingFactor = sliderValue;
        [_scalingFactorTextField setIntValue: _scalingFactor];

        [self updatePreviewImage];
    }
}

- (IBAction) canvasSettingCheckboxClicked: (id) sender
{
    [self updatePreviewImage];
}

- (IBAction) gridPopUpMenuItemSelected_CurrentPattern: (id) sender
{
    [self setGridPattern: [_ppDocument gridPattern]];
    _selectedGridMenuItemType = kPatternMenuItemType_Current;
}

- (IBAction) gridPopUpMenuItemSelected_DefaultPattern: (id) sender
{
    [self setGridPattern: [PPUserDefaults gridPattern]];
    _selectedGridMenuItemType = kPatternMenuItemType_Default;
}

- (IBAction) gridPopUpMenuItemSelected_PresetPattern: (id) sender
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

    [self setGridPattern: [presetPatterns objectAtIndex: indexOfPattern]];
    _selectedGridMenuItemType = kPatternMenuItemType_Preset;

    return;

ERROR:
    return;
}

- (IBAction) backgroundPatternPopUpMenuItemSelected_CurrentPattern: (id) sender
{
    [self setBackgroundPattern: [_ppDocument backgroundPattern]];
    _selectedBackgroundPatternMenuItemType = kPatternMenuItemType_Current;
}

- (IBAction) backgroundPatternPopUpMenuItemSelected_DefaultPattern: (id) sender
{
    [self setBackgroundPattern: [PPUserDefaults backgroundPattern]];
    _selectedBackgroundPatternMenuItemType = kPatternMenuItemType_Default;
}

- (IBAction) backgroundPatternPopUpMenuItemSelected_PresetPattern: (id) sender
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

    [self setBackgroundPattern: [presetPatterns objectAtIndex: indexOfPattern]];
    _selectedBackgroundPatternMenuItemType = kPatternMenuItemType_Preset;

    return;

ERROR:
    return;
}

- (IBAction) fileFormatPopupMenuItemSelected: (id) sender
{
    [self setSavePanelRequiredFileTypeFromFileFormatPopUp];
}

#pragma mark NSControl delegate methods (Scaling factor textField)

- (void) controlTextDidChange: (NSNotification *) notification
{
    int newScalingFactor = [_scalingFactorTextField ppClampIntValueToMax: _maxScalingFactor
                                                        min: kMinExportScalingFactor
                                                        defaultValue: _scalingFactor];

    if (newScalingFactor != _scalingFactor)
    {
        _scalingFactor = newScalingFactor;

        [_scalingFactorSlider setIntValue: _scalingFactor];

        [self updatePreviewImage];
    }
}

#pragma mark PPTitleablePopUpButton delegate methods

- (NSString *) displayTitleForMenuItemWithTitle: (NSString *) itemTitle
                onTitleablePopUpButton: (PPTitleablePopUpButton *) button
{
    NSString *displayTitle = itemTitle;
    bool itemTitleIsCurrentPattern =
            ([itemTitle isEqualToString: kPatternPopUpMenuItemTitle_CurrentPattern]) ? YES : NO;

    if (button == _gridTitleablePopUpButton)
    {
        if (itemTitleIsCurrentPattern)
        {
            displayTitle = kGridPopUpButtonTitle_CurrentPattern;
        }
        else
        {
            displayTitle = [NSString stringWithFormat: kGridPopUpButtonTitleFormat, itemTitle];
        }
    }
    else if (button == _backgroundPatternTitleablePopUpButton)
    {
        if (itemTitleIsCurrentPattern)
        {
            displayTitle = kBackgroundPatternPopUpButtonTitle_CurrentPattern;
        }
        else
        {
            displayTitle =
                [NSString stringWithFormat: kBackgroundPatternPopUpButtonTitleFormat, itemTitle];
        }
    }

    return displayTitle;
}

#pragma mark NSWindow notifications (PPDocument window)

- (void) addAsObserverForNSWindowNotificationsFromPPDocumentWindow
{
    NSWindow *window = [_ppDocument ppWindow];

    if (!window)
        return;

    [[NSNotificationCenter defaultCenter]
                                    addObserver: self
                                    selector:
                                        @selector(
                                            handlePPDocumentWindowNotification_DidEndSheet:)
                                    name: NSWindowDidEndSheetNotification
                                    object: window];
}

- (void) removeAsObserverForNSWindowNotificationsFromPPDocumentWindow
{
    [[NSNotificationCenter defaultCenter]
                                    removeObserver: self
                                    name: NSWindowDidEndSheetNotification
                                    object: [_ppDocument ppWindow]];
}

- (void) handlePPDocumentWindowNotification_DidEndSheet: (NSNotification *) notification
{
    [self setupWithSavePanel: nil];
}

#pragma mark NSView notifications (Preview imageview’s clipview)

- (void) addAsObserverForNSViewNotificationsFromPreviewClipView
{
    NSClipView *clipView = [[_previewImageView enclosingScrollView] contentView];

    if (!clipView)
        return;

    [clipView setPostsBoundsChangedNotifications: YES];

    [[NSNotificationCenter defaultCenter]
                                    addObserver: self
                                    selector:
                                        @selector(
                                            handlePreviewClipViewNotification_BoundsDidChange:)
                                    name: NSViewBoundsDidChangeNotification
                                    object: clipView];
}

- (void) removeAsObserverForNSViewNotificationsFromPreviewClipView
{
    NSClipView *clipView = [[_previewImageView enclosingScrollView] contentView];

    [[NSNotificationCenter defaultCenter] removeObserver: self
                                            name: NSViewBoundsDidChangeNotification
                                            object: clipView];
}

- (void) handlePreviewClipViewNotification_BoundsDidChange: (NSNotification *) notification
{
    NSRect documentVisibleRect;

    if (_shouldPreservePreviewNormalizedCenter || PPGeometry_IsZeroSize(_previewImageSize))
    {
        return;
    }

    documentVisibleRect = [[_previewImageView enclosingScrollView] documentVisibleRect];

    _previewViewNormalizedCenter =
        NSMakePoint(((documentVisibleRect.origin.x + documentVisibleRect.size.width / 2.0)
                            / _previewImageSize.width),
                        ((documentVisibleRect.origin.y + documentVisibleRect.size.height / 2.0)
                            / _previewImageSize.height));
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
                                object: [PPGridPatternPresets sharedPresets]];
}

- (void) handlePPGridPatternPresetsNotification_UpdatedPresets: (NSNotification *) notification
{
    [self setupMenuForGridPopUpButton];
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
                                object: [PPBackgroundPatternPresets sharedPresets]];
}

- (void) handlePPBackgroundPatternPresetsNotification_UpdatedPresets:
                                                                (NSNotification *) notification
{
    [self setupMenuForBackgroundPatternPopUpButton];
}

#pragma mark Private methods

- (void) setupMaxScalingFactorForCurrentDocumentSize
{
    NSSize canvasSize;
    int maxScalingFactor;

    canvasSize = [_ppDocument canvasSize];

    if (PPGeometry_IsZeroSize(canvasSize))
    {
        goto ERROR;
    }

    maxScalingFactor =
            MIN(kMaxExportScalingFactor,
                floorf(kMaxCanvasExportDimension / MAX(canvasSize.width, canvasSize.height)));

    if (_maxScalingFactor != maxScalingFactor)
    {
        _maxScalingFactor = maxScalingFactor;

        if (_scalingFactor > _maxScalingFactor)
        {
            _scalingFactor = _maxScalingFactor;

            [_scalingFactorTextField setIntValue: _scalingFactor];
        }

        [_scalingFactorSlider setMaxValue: _maxScalingFactor];
        [_scalingFactorSlider setIntValue: _scalingFactor];
    }

    return;

ERROR:
    return;
}

- (void) setupPopUpDefaultMenus
{
    NSMenuItem *currentPatternMenuItem, *defaultPatternMenuItem;

    // Grid popup button's default menu

    currentPatternMenuItem =
                    [[[NSMenuItem alloc]
                            initWithTitle: NSLocalizedString(kPatternPopUpMenuItemTitle_CurrentPattern, nil)
                            action: @selector(gridPopUpMenuItemSelected_CurrentPattern:)
                            keyEquivalent: @""]
                        autorelease];

    if (!currentPatternMenuItem)
        goto ERROR;

    [currentPatternMenuItem setTarget: self];


    defaultPatternMenuItem =
                    [[[NSMenuItem alloc]
                            initWithTitle: NSLocalizedString(kPatternPopUpMenuItemTitle_DefaultPattern, nil)
                            action: @selector(gridPopUpMenuItemSelected_DefaultPattern:)
                            keyEquivalent: @""]
                        autorelease];

    if (!defaultPatternMenuItem)
        goto ERROR;

    [defaultPatternMenuItem setTarget: self];


    [_gridPopUpDefaultMenu release];
    _gridPopUpDefaultMenu = [[NSMenu alloc] initWithTitle: @""];

    if (!_gridPopUpDefaultMenu)
        goto ERROR;

    [_gridPopUpDefaultMenu setAutoenablesItems: NO];
    [_gridPopUpDefaultMenu addItem: currentPatternMenuItem];
    [_gridPopUpDefaultMenu addItem: defaultPatternMenuItem];

    // Background pattern popup button's default menu

    currentPatternMenuItem =
                    [[[NSMenuItem alloc]
                            initWithTitle: NSLocalizedString(kPatternPopUpMenuItemTitle_CurrentPattern, nil)
                            action:
                                @selector(backgroundPatternPopUpMenuItemSelected_CurrentPattern:)
                            keyEquivalent: @""]
                        autorelease];

    if (!currentPatternMenuItem)
        goto ERROR;

    [currentPatternMenuItem setTarget: self];


    defaultPatternMenuItem =
                    [[[NSMenuItem alloc]
                            initWithTitle: NSLocalizedString(kPatternPopUpMenuItemTitle_DefaultPattern, nil)
                            action:
                                @selector(backgroundPatternPopUpMenuItemSelected_DefaultPattern:)
                            keyEquivalent: @""]
                        autorelease];

    if (!defaultPatternMenuItem)
        goto ERROR;

    [defaultPatternMenuItem setTarget: self];


    [_backgroundPatternPopUpDefaultMenu release];
    _backgroundPatternPopUpDefaultMenu = [[NSMenu alloc] initWithTitle: @""];

    if (!_backgroundPatternPopUpDefaultMenu)
        goto ERROR;

    [_backgroundPatternPopUpDefaultMenu setAutoenablesItems: NO];
    [_backgroundPatternPopUpDefaultMenu addItem: currentPatternMenuItem];
    [_backgroundPatternPopUpDefaultMenu addItem: defaultPatternMenuItem];

    return;

ERROR:
    return;
}

- (void) setupMenuForGridPopUpButton
{
    NSMenu *popUpButtonMenu;
    NSMenuItem *presetItem;
    int indexOfItemToSelect, numPresetPatterns, presetIndex;
    NSArray *presetPatterns;
    PPGridPattern *presetPattern;
    NSString *presetTitle;

    popUpButtonMenu = [[_gridPopUpDefaultMenu copy] autorelease];

    if (!popUpButtonMenu)
        goto ERROR;

    if ((_selectedGridMenuItemType != kPatternMenuItemType_Current)
        && (_selectedGridMenuItemType != kPatternMenuItemType_Default))
    {
        _selectedGridMenuItemType = kPatternMenuItemType_Preset;
    }

    presetPatterns = [[PPGridPatternPresets sharedPresets] patterns];
    numPresetPatterns = [presetPatterns count];

    if (numPresetPatterns > 0)
    {
        [popUpButtonMenu addItem: [NSMenuItem separatorItem]];
    }

    indexOfItemToSelect = -1;

    for (presetIndex=0; presetIndex<numPresetPatterns; presetIndex++)
    {
        presetPattern = [presetPatterns objectAtIndex: presetIndex];

        presetTitle = [presetPattern presetName];

        presetItem =
            [[[NSMenuItem alloc]
                            initWithTitle: (presetTitle) ? presetTitle : @""
                            action: @selector(gridPopUpMenuItemSelected_PresetPattern:)
                            keyEquivalent: @""]
                        autorelease];

        if (presetItem)
        {
            [presetItem setTarget: self];
            [presetItem setTag: presetIndex];

            [popUpButtonMenu addItem: presetItem];

            if ((_selectedGridMenuItemType == kPatternMenuItemType_Preset)
                && (indexOfItemToSelect < 0)
                && [_gridPattern isEqualToGridPattern: presetPattern])
            {
                indexOfItemToSelect = [popUpButtonMenu numberOfItems] - 1;
            }
        }
    }

    if (indexOfItemToSelect < 0)
    {
        if (_selectedGridMenuItemType == kPatternMenuItemType_Preset)
        {
            [self setGridPattern: [_ppDocument gridPattern]];
            _selectedGridMenuItemType = kPatternMenuItemType_Current;
        }

        if (_selectedGridMenuItemType == kPatternMenuItemType_Default)
        {
            [self setGridPattern: [PPUserDefaults gridPattern]];

            indexOfItemToSelect =
                [_gridPopUpDefaultMenu indexOfItemWithTitle:
                                            kPatternPopUpMenuItemTitle_DefaultPattern];
        }
        else    // (_selectedGridMenuItemType == kPatternMenuItemType_Current)
        {
            [self setGridPattern: [_ppDocument gridPattern]];

            indexOfItemToSelect =
                [_gridPopUpDefaultMenu indexOfItemWithTitle:
                                            kPatternPopUpMenuItemTitle_CurrentPattern];
        }
    }

    [_gridTitleablePopUpButton setMenu: popUpButtonMenu];

    [_gridTitleablePopUpButton selectItemAtIndex: indexOfItemToSelect];

    return;

ERROR:
    return;
}

- (void) setupMenuForBackgroundPatternPopUpButton
{
    NSMenu *popUpButtonMenu;
    NSMenuItem *presetItem;
    int indexOfItemToSelect, numPresetPatterns, presetIndex;
    NSArray *presetPatterns;
    PPBackgroundPattern *presetPattern;
    NSString *presetTitle;

    popUpButtonMenu = [[_backgroundPatternPopUpDefaultMenu copy] autorelease];

    if (!popUpButtonMenu)
        goto ERROR;

    if ((_selectedBackgroundPatternMenuItemType != kPatternMenuItemType_Current)
        && (_selectedBackgroundPatternMenuItemType != kPatternMenuItemType_Default))
    {
        _selectedBackgroundPatternMenuItemType = kPatternMenuItemType_Preset;
    }

    presetPatterns = [[PPBackgroundPatternPresets sharedPresets] patterns];
    numPresetPatterns = [presetPatterns count];

    if (numPresetPatterns > 0)
    {
        [popUpButtonMenu addItem: [NSMenuItem separatorItem]];
    }

    indexOfItemToSelect = -1;

    for (presetIndex=0; presetIndex<numPresetPatterns; presetIndex++)
    {
        presetPattern = [presetPatterns objectAtIndex: presetIndex];

        presetTitle = [presetPattern presetName];

        presetItem =
            [[[NSMenuItem alloc]
                            initWithTitle: (presetTitle) ? presetTitle : @""
                            action:
                                @selector(backgroundPatternPopUpMenuItemSelected_PresetPattern:)
                            keyEquivalent: @""]
                        autorelease];

        if (presetItem)
        {
            [presetItem setTarget: self];
            [presetItem setTag: presetIndex];

            [popUpButtonMenu addItem: presetItem];

            if ((_selectedBackgroundPatternMenuItemType == kPatternMenuItemType_Preset)
                && (indexOfItemToSelect < 0)
                && [_backgroundPattern isEqualToBackgroundPattern: presetPattern])
            {
                indexOfItemToSelect = [popUpButtonMenu numberOfItems] - 1;
            }
        }
    }

    if (indexOfItemToSelect < 0)
    {
        if (_selectedBackgroundPatternMenuItemType == kPatternMenuItemType_Preset)
        {
            [self setBackgroundPattern: [_ppDocument backgroundPattern]];
            _selectedBackgroundPatternMenuItemType = kPatternMenuItemType_Current;
        }

        if (_selectedBackgroundPatternMenuItemType == kPatternMenuItemType_Default)
        {
            [self setBackgroundPattern: [PPUserDefaults backgroundPattern]];

            indexOfItemToSelect =
                [_backgroundPatternPopUpDefaultMenu
                            indexOfItemWithTitle: kPatternPopUpMenuItemTitle_DefaultPattern];
        }
        else    // (_selectedBackgroundPatternMenuItemType == kPatternMenuItemType_Current)
        {
            [self setBackgroundPattern: [_ppDocument backgroundPattern]];

            indexOfItemToSelect =
                [_backgroundPatternPopUpDefaultMenu
                            indexOfItemWithTitle: kPatternPopUpMenuItemTitle_CurrentPattern];
        }
    }

    [_backgroundPatternTitleablePopUpButton setMenu: popUpButtonMenu];

    [_backgroundPatternTitleablePopUpButton selectItemAtIndex: indexOfItemToSelect];

    return;

ERROR:
    return;
}

- (void) setGridPattern: (PPGridPattern *) gridPattern
{
    if (!gridPattern || [_gridPattern isEqualToGridPattern: gridPattern])
    {
        return;
    }

    [_gridPattern release];
    _gridPattern = [gridPattern retain];

    [self updatePreviewImage];
}

- (void) setBackgroundPattern: (PPBackgroundPattern *) backgroundPattern
{
    if (!backgroundPattern || [_backgroundPattern isEqualToBackgroundPattern: backgroundPattern])
    {
        return;
    }

    [_backgroundPattern release];
    _backgroundPattern = [backgroundPattern retain];

    [self updatePreviewImage];
}

- (void) setSavePanelRequiredFileTypeFromFileFormatPopUp
{
    NSString *selectedFileType;
    NSArray *allowedFileTypes = nil;

    selectedFileType = [self selectedFileType];

    if ([selectedFileType length])
    {
        allowedFileTypes = [NSArray arrayWithObject: selectedFileType];
    }

    [_savePanel setAllowedFileTypes: allowedFileTypes];
}

- (void) updateBackgroundImageControlsForCurrentDocument
{
    bool documentHasBackgroundImage = ([_ppDocument backgroundImage]) ? YES : NO;
    NSColor *textFieldColor = (documentHasBackgroundImage) ?
                                [NSColor controlTextColor] : [NSColor disabledControlTextColor];

    [_backgroundImageCheckbox setEnabled: documentHasBackgroundImage];

    if (!documentHasBackgroundImage)
    {
        [_backgroundImageCheckbox setIntValue: 0];
    }

    [_backgroundImageTextField setTextColor: textFieldColor];
}

- (void) updatePreviewImage
{
    NSAutoreleasePool *autoreleasePool;
    NSBitmapImageRep *previewBitmap;
    NSImage *previewImage;
    NSSize previewImageSize;

    // use a local autorelease pool to make sure old images & bitmaps get dealloc'd during
    // slider tracking
    autoreleasePool = [[NSAutoreleasePool alloc] init];

    previewBitmap = [_ppDocument mergedVisibleLayersBitmapUsingExportPanelSettings];
    previewImage = [NSImage ppImageWithBitmap: previewBitmap];
    previewImageSize = (previewImage) ? [previewImage size] : NSZeroSize;

    if (!NSEqualSizes(previewImageSize, _previewImageSize))
    {
        [_exportSizeTextField setStringValue: [NSString stringWithFormat: @"%dx%d",
                                                                (int) previewImageSize.width,
                                                                (int) previewImageSize.height]];

        [self resizePreviewViewForImageWithSize: previewImageSize];
    }

    [_previewImageView setImage: previewImage];

    [autoreleasePool release];
}

- (void) clearPreviewImage
{
    [_previewImageView setImage: nil];
}

- (void) resizePreviewViewForImageWithSize: (NSSize) previewImageSize
{
    NSScrollView *previewScrollView;
    NSSize contentViewSize;
    NSRect newPreviewScrollViewFrame;
    int viewMarginPadding;

    _shouldPreservePreviewNormalizedCenter = YES;

    previewScrollView = [_previewImageView enclosingScrollView];

    [_previewImageView setFrameSize: previewImageSize];
    [previewScrollView setFrame: _previewScrollViewInitialFrame];

    contentViewSize = [[previewScrollView contentView] frame].size;

    newPreviewScrollViewFrame = _previewScrollViewInitialFrame;

    if (previewImageSize.width < contentViewSize.width)
    {
        if (previewImageSize.height > contentViewSize.height)
        {
            viewMarginPadding = _previewScrollerWidth;
        }
        else
        {
            viewMarginPadding = kMarginPaddingForScrollerlessScrollView;
        }

        newPreviewScrollViewFrame.size.width = previewImageSize.width + viewMarginPadding;
    }

    if (previewImageSize.height < contentViewSize.height)
    {
        if (previewImageSize.width > contentViewSize.width)
        {
            viewMarginPadding = _previewScrollerWidth;
        }
        else
        {
            viewMarginPadding = kMarginPaddingForScrollerlessScrollView;
        }

        newPreviewScrollViewFrame.size.height = previewImageSize.height + viewMarginPadding;
    }

    newPreviewScrollViewFrame =
        PPGeometry_CenterRectInRect(newPreviewScrollViewFrame, _previewScrollViewInitialFrame);

    [previewScrollView setFrame: newPreviewScrollViewFrame];

    // Changing scrollview frame causes drawing artifacts (10.4) - fix by redrawing superview
    [[previewScrollView superview] setNeedsDisplayInRect: _previewScrollViewInitialFrame];

    _previewImageSize = previewImageSize;

    [self scrollPreviewToNormalizedCenter];

    _shouldPreservePreviewNormalizedCenter = NO;
}

- (void) scrollPreviewToNormalizedCenter
{
    NSSize clipViewSize = [[[_previewImageView enclosingScrollView] contentView] bounds].size;
    NSPoint centerPoint = NSMakePoint(_previewViewNormalizedCenter.x * _previewImageSize.width
                                        - clipViewSize.width / 2.0f,
                                    _previewViewNormalizedCenter.y * _previewImageSize.height
                                        - clipViewSize.height / 2.0f);

    [_previewImageView scrollPoint: centerPoint];
}

@end
