/*
    PPDocumentBackgroundSettingsSheetController.h

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

#import "PPDocumentSheetController.h"


@class PPBackgroundPattern;

@interface PPDocumentBackgroundSettingsSheetController : PPDocumentSheetController
{
    IBOutlet NSTextField *_patternDisplayField;
    IBOutlet NSMatrix *_patternTypeMatrix;
    IBOutlet NSColorWell *_patternColor1Well;
    IBOutlet NSColorWell *_patternColor2Well;
    IBOutlet NSSlider *_patternSizeSlider;

    IBOutlet NSMenu *_defaultPatternPresetsMenu;
    IBOutlet NSPopUpButton *_patternPresetsPopUpButton;

    IBOutlet NSImageView *_backgroundImageView;
    IBOutlet NSButton *_showImageCheckbox;
    IBOutlet NSButton *_imageSmoothingCheckbox;
    IBOutlet NSButton *_copyImageToPasteboardButton;
    IBOutlet NSButton *_removeImageButton;

    PPBackgroundPattern *_backgroundPattern;
    PPBackgroundPattern *_lastCustomBackgroundPattern;

    NSColor *_activePatternTypeCellColor;
    NSColor *_inactivePatternTypeCellColor;

    int _tagOfActivePatternTypeMatrixCell;

    int _indexOfPatternPresetsMenuItem_DefaultPattern;
    int _indexOfPatternPresetsMenuItem_CustomPattern;
    int _indexOfPatternPresetsMenuItem_FirstPatternPreset;
}

+ (bool) beginBackgroundSettingsSheetForDocumentWindow: (NSWindow *) window
            backgroundPattern: (PPBackgroundPattern *) backgroundPattern
            backgroundImage: (NSImage *) backgroundImage
            backgroundImageVisibility: (bool) shouldDisplayBackgroundImage
            backgroundImageSmoothing: (bool) shouldSmoothenBackgroundImage
            delegate: (id) delegate;

- (IBAction) patternSettingChanged: (id) sender;

- (IBAction) patternPresetsMenuItemSelected_DefaultPattern: (id) sender;
- (IBAction) patternPresetsMenuItemSelected_CustomPattern: (id) sender;

- (IBAction) patternPresetsMenuItemSelected_PresetPattern: (id) sender;

- (IBAction) patternPresetsMenuItemSelected_AddCurrentPatternToPresets: (id) sender;
- (IBAction) patternPresetsMenuItemSelected_EditPresets: (id) sender;

- (IBAction) patternPresetsMenuItemSelected_ExportPresetsToFile: (id) sender;
- (IBAction) patternPresetsMenuItemSelected_ImportPresetsFromFile: (id) sender;

- (IBAction) patternPresetsMenuItemSelected_SavePatternAsDefault: (id) sender;
- (IBAction) patternPresetsMenuItemSelected_RestoreOriginalDefault: (id) sender;

- (IBAction) backgroundImageViewUpdated: (id) sender;
- (IBAction) showImageCheckboxClicked: (id) sender;
- (IBAction) imageSmoothingCheckboxClicked: (id) sender;
- (IBAction) setImageToFileButtonPressed: (id) sender;
- (IBAction) setImageToPasteboardButtonPressed: (id) sender;
- (IBAction) copyImageToPasteboardButtonPressed: (id) sender;
- (IBAction) removeImageButtonPressed: (id) sender;

@end

@interface NSObject (PPDocumentBackgroundSettingsSheetDelegateMethods)

- (void) backgroundSettingsSheetDidUpdatePattern: (PPBackgroundPattern *) backgroundPattern;

- (void) backgroundSettingsSheetDidUpdateImage: (NSImage *) backgroundImage;

- (void) backgroundSettingsSheetDidUpdateImageVisibility: (bool) shouldDisplayImage;

- (void) backgroundSettingsSheetDidUpdateImageSmoothing: (bool) shouldSmoothenImage;

- (void) backgroundSettingsSheetDidFinishWithBackgroundPattern:
                                                    (PPBackgroundPattern *) backgroundPattern
            backgroundImage: (NSImage *) backgroundImage
            shouldDisplayImage: (bool) shouldDisplayImage
            shouldSmoothenImage: (bool) shouldSmoothenImage;

- (void) backgroundSettingsSheetDidCancel;

@end
