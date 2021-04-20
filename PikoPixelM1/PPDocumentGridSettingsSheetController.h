/*
    PPDocumentGridSettingsSheetController.h

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


@class PPGridPattern;

@interface PPDocumentGridSettingsSheetController : PPDocumentSheetController
{
    IBOutlet NSButton *_showGridCheckbox;
    IBOutlet NSSegmentedControl *_gridTypeSegmentedControl;
    IBOutlet NSColorWell *_gridColorWell;

    IBOutlet NSButton *_showGuidelinesCheckbox;
    IBOutlet NSTextField *_guidelinesHorizontalSpacingTextField;
    IBOutlet NSTextField *_guidelinesVerticalSpacingTextField;
    IBOutlet NSColorWell *_guidelinesColorWell;

    IBOutlet NSMenu *_defaultPresetsMenu;
    IBOutlet NSPopUpButton *_presetsPopUpButton;

    PPGridPattern *_gridPattern;
    PPGridPattern *_lastCustomGridPattern;

    int _indexOfPresetsMenuItem_DefaultPattern;
    int _indexOfPresetsMenuItem_CustomPattern;
    int _indexOfPresetsMenuItem_FirstPatternPreset;

    bool _gridVisibility;
}

+ (bool) beginGridSettingsSheetForDocumentWindow: (NSWindow *) window
            gridPattern: (PPGridPattern *) gridPattern
            gridVisibility: (bool) shouldDisplayGrid
            delegate: (id) delegate;

- (IBAction) showGridCheckboxClicked: (id) sender;

- (IBAction) gridSettingChanged: (id) sender;

- (IBAction) presetsMenuItemSelected_DefaultPattern: (id) sender;
- (IBAction) presetsMenuItemSelected_CustomPattern: (id) sender;

- (IBAction) presetsMenuItemSelected_PresetPattern: (id) sender;

- (IBAction) presetsMenuItemSelected_AddCurrentPatternToPresets: (id) sender;
- (IBAction) presetsMenuItemSelected_EditPresets: (id) sender;

- (IBAction) presetsMenuItemSelected_ExportPresetsToFile: (id) sender;
- (IBAction) presetsMenuItemSelected_ImportPresetsFromFile: (id) sender;

- (IBAction) presetsMenuItemSelected_SavePatternAsDefault: (id) sender;
- (IBAction) presetsMenuItemSelected_RestoreOriginalDefault: (id) sender;

@end

@interface NSObject (PPDocumentGridSettingsSheetDelegateMethods)

- (void) gridSettingsSheetDidUpdateGridPattern: (PPGridPattern *) gridPattern
                                andVisibility: (bool) shouldDisplayGrid;

- (void) gridSettingsSheetDidFinishWithGridPattern: (PPGridPattern *) gridPattern
                                andVisibility: (bool) shouldDisplayGrid;

- (void) gridSettingsSheetDidCancel;

@end
