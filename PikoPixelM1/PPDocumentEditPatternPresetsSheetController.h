/*
    PPDocumentEditPatternPresetsSheetController.h

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

#import "PPPresettablePatternProtocol.h"


@class PPPresettablePatternView, PPPatternPresets;

@interface PPDocumentEditPatternPresetsSheetController : PPDocumentSheetController
{
    IBOutlet NSTextField *_sheetTitleField;

    IBOutlet NSTableView *_editablePatternsTable;

    IBOutlet PPPresettablePatternView *_patternView;

    IBOutlet NSButton *_removePresetButton;
    IBOutlet NSButton *_removeAllPresetsButton;

    PPPatternPresets *_patternPresets;

    NSMutableArray *_editablePatterns;

    id <PPPresettablePattern> _currentPattern;

    NSString *_editablePatternsTableDraggedDataType;
}

+ (bool) beginEditPatternPresetsSheetForWindow: (NSWindow *) window
            patternPresets: (PPPatternPresets *) patternPresets
            patternTypeDisplayName: (NSString *) patternTypeDisplayName
            currentPattern: (id <PPPresettablePattern>) currentPattern
            addCurrentPatternAsPreset: (bool) addCurrentPatternAsPreset
            delegate: (id) delegate;

- (IBAction) addCurrentPatternAsPresetButtonPressed: (id) sender;
- (IBAction) removePresetButtonPressed: (id) sender;
- (IBAction) removeAllPresetsButtonPressed: (id) sender;

@end

@interface NSObject (PPDocumentEditPatternPresetsSheetController)

- (void) editPatternPresetsSheetDidFinish;
- (void) editPatternPresetsSheetDidCancel;

@end
