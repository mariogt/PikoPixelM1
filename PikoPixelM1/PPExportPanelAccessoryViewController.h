/*
    PPExportPanelAccessoryViewController.h

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

#import <Cocoa/Cocoa.h>


@class PPDocument, PPTitleablePopUpButton, PPGridPattern, PPBackgroundPattern;

@interface PPExportPanelAccessoryViewController : NSObject
{
    IBOutlet NSView *_exportAccessoryView;

    IBOutlet NSImageView *_previewImageView;
    IBOutlet NSTextField *_exportSizeTextField;
    IBOutlet NSTextField *_scalingFactorTextField;
    IBOutlet NSSlider *_scalingFactorSlider;
    IBOutlet NSButton *_gridCheckbox;
    IBOutlet PPTitleablePopUpButton *_gridTitleablePopUpButton;
    IBOutlet NSButton *_backgroundPatternCheckbox;
    IBOutlet PPTitleablePopUpButton *_backgroundPatternTitleablePopUpButton;
    IBOutlet NSButton *_backgroundImageCheckbox;
    IBOutlet NSTextField *_backgroundImageTextField;
    IBOutlet NSPopUpButton *_fileFormatPopUpButton;

    NSSavePanel *_savePanel;
    PPDocument *_ppDocument;

    NSRect _previewScrollViewInitialFrame;
    float _previewScrollerWidth;
    NSSize _previewImageSize;
    NSPoint _previewViewNormalizedCenter;

    int _scalingFactor;
    int _maxScalingFactor;

    NSMenu *_gridPopUpDefaultMenu;
    int _selectedGridMenuItemType;

    NSMenu *_backgroundPatternPopUpDefaultMenu;
    int _selectedBackgroundPatternMenuItemType;

    PPGridPattern *_gridPattern;
    PPBackgroundPattern *_backgroundPattern;

    bool _shouldPreservePreviewNormalizedCenter;
}

+ (PPExportPanelAccessoryViewController *) controllerForPPDocument: (PPDocument *) ppDocument;

- (void) setupWithSavePanel: (NSSavePanel *) savePanel;

- (NSString *) selectedFileTypeName;
- (NSString *) selectedFileType;

- (bool) getScalingFactor: (unsigned *) returnedScalingFactor
            gridPattern: (PPGridPattern **) returnedGridPattern
            backgroundPattern: (PPBackgroundPattern **) returnedBackgroundPattern
            backgroundImageFlag: (bool *) returnedBackgroundImageFlag;


- (IBAction) scalingFactorSliderMoved: (id) sender;

- (IBAction) canvasSettingCheckboxClicked: (id) sender;

- (IBAction) gridPopUpMenuItemSelected_CurrentPattern: (id) sender;
- (IBAction) gridPopUpMenuItemSelected_DefaultPattern: (id) sender;
- (IBAction) gridPopUpMenuItemSelected_PresetPattern: (id) sender;

- (IBAction) backgroundPatternPopUpMenuItemSelected_CurrentPattern: (id) sender;
- (IBAction) backgroundPatternPopUpMenuItemSelected_DefaultPattern: (id) sender;
- (IBAction) backgroundPatternPopUpMenuItemSelected_PresetPattern: (id) sender;

- (IBAction) fileFormatPopupMenuItemSelected: (id) sender;

@end
