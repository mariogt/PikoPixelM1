/*
    PPDocumentEditImageSizePresetsSheetController.m

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

#import "PPDocumentEditImageSizePresetsSheetController.h"

#import "PPImageSizePresets.h"
#import "NSTextField_PPUtilities.h"
#import "PPDefines.h"


#define kDocumentEditImageSizePresetsSheetNibName   @"DocumentEditSizePresetsSheet"

#define kSizePresetsTableDraggedDataType            @"SizePresetsTableDraggedDataType"

#define kNewPresetName                              @"New Preset"
#define kNewPresetSize                              NSMakeSize(64, 64)


@interface PPDocumentEditImageSizePresetsSheetController (PrivateMethods)

- initWithDelegate: (id) delegate;

- (void) addAsObserverForPPImageSizePresetsNotifications;
- (void) removeAsObserverForPPImageSizePresetsNotifications;
- (void) handlePPImageSizePresetsNotification_UpdatedPresets: (NSNotification *) notification;

- (bool) setupPresetStringArraysWithPresetStrings: (NSArray *) presetStrings;
- (void) destroyPresetStringArrays;

- (void) selectPresetsTableRow: (unsigned) row;

- (void) updateSizeFieldsForCurrentPresetsTableSelection;

- (void) savePresetsTableEditing;

- (void) updateSheetForChangedPresets;

- (void) addNewPreset;
- (void) deleteCurrentPreset;

@end


#if PP_SDK_REQUIRES_PROTOCOLS_FOR_DELEGATES_AND_DATASOURCES

@interface PPDocumentEditImageSizePresetsSheetController (RequiredProtocols)
                            <NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate>
@end

#endif  // PP_SDK_REQUIRES_PROTOCOLS_FOR_DELEGATES_AND_DATASOURCES


@implementation PPDocumentEditImageSizePresetsSheetController

+ (bool) beginEditImageSizePresetsSheetForWindow: (NSWindow *) window
            delegate: (id) delegate
{
    PPDocumentEditImageSizePresetsSheetController *controller;

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
    self = [super initWithNibNamed: kDocumentEditImageSizePresetsSheetNibName
                    delegate: delegate];

    if (!self)
        goto ERROR;

    if (![self setupPresetStringArraysWithPresetStrings: [PPImageSizePresets presetStrings]])
    {
        goto ERROR;
    }

    [_presetsTable setDataSource: self];
    [_presetsTable setDelegate: self];
    [_presetsTable registerForDraggedTypes:
                                [NSArray arrayWithObject: kSizePresetsTableDraggedDataType]];

    [_widthTextField setDelegate: self];
    [_heightTextField setDelegate: self];

    if ([_presetNameOnlyStrings count])
    {
        [self selectPresetsTableRow: 0];
    }
    else
    {
        [self addNewPreset];
    }

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
    [self removeAsObserverForPPImageSizePresetsNotifications];

    [self destroyPresetStringArrays];

    [super dealloc];
}

#pragma mark Actions

- (IBAction) addPresetButtonPressed: (id) sender
{
    [self addNewPreset];
}

- (IBAction) deletePresetButtonPressed: (id) sender
{
    [self deleteCurrentPreset];
}

- (IBAction) defaultListButtonPressed: (id) sender
{
    [self setupPresetStringArraysWithPresetStrings:
                                            [PPImageSizePresets appDefaultPresetStrings]];

    [self updateSheetForChangedPresets];
    [self selectPresetsTableRow: 0];
}

#pragma mark PPDocumentSheetController overrides (actions)

- (IBAction) OKButtonPressed: (id) sender
{
    [self removeAsObserverForPPImageSizePresetsNotifications];

    [self savePresetsTableEditing];

    [PPImageSizePresets setPresetStrings: _presetNameAndSizeStrings];

    [super OKButtonPressed: sender];
}

#pragma mark PPDocumentSheetController overrides (delegate notifiers)

- (void) notifyDelegateSheetDidFinish
{
    if ([_delegate respondsToSelector: @selector(editImageSizePresetsSheetDidFinish)])
    {
        [_delegate editImageSizePresetsSheetDidFinish];
    }
}

- (void) notifyDelegateSheetDidCancel
{
    if ([_delegate respondsToSelector: @selector(editImageSizePresetsSheetDidCancel)])
    {
        [_delegate editImageSizePresetsSheetDidCancel];
    }
}

#pragma mark NSTableView data source (Presets table)

- (NSInteger) numberOfRowsInTableView: (NSTableView *) aTableView
{
    return [_presetNameOnlyStrings count];
}

- (id) tableView: (NSTableView *) tableView
        objectValueForTableColumn: (NSTableColumn *) tableColumn
        row: (NSInteger) row
{
    if (tableView != _presetsTable)
    {
        return nil;
    }

    return [_presetNameOnlyStrings objectAtIndex: row];
}

- (void) tableView: (NSTableView *) tableView
            setObjectValue: (id) object
            forTableColumn: (NSTableColumn *) tableColumn
            row: (NSInteger) row
{
    NSString *nameOnlyString, *nameAndSizeString;

    if (tableView != _presetsTable)
    {
        return;
    }

    nameOnlyString = object;
    nameAndSizeString =
        PPImageSizePresets_PresetStringForNameAndSize(nameOnlyString,
                                    PPImageSizePresets_SizeForPresetString(
                                            [_presetNameAndSizeStrings objectAtIndex: row]));

    if (!nameAndSizeString)
        return;

    [_presetNameAndSizeStrings replaceObjectAtIndex: row withObject: nameAndSizeString];
    [_presetNameOnlyStrings replaceObjectAtIndex: row withObject: nameOnlyString];
}

- (BOOL) tableView: (NSTableView *) tableView
            writeRowsWithIndexes: (NSIndexSet *) rowIndexes
            toPasteboard: (NSPasteboard*) pasteboard
{
    NSData *pasteboardData;

    pasteboardData = [NSKeyedArchiver archivedDataWithRootObject: rowIndexes];

    [pasteboard declareTypes: [NSArray arrayWithObject: kSizePresetsTableDraggedDataType]
                owner: self];

    [pasteboard setData: pasteboardData forType: kSizePresetsTableDraggedDataType];

    return YES;
}

- (NSDragOperation) tableView: (NSTableView*) tableView
                        validateDrop: (id <NSDraggingInfo>) info
                        proposedRow: (NSInteger) newRow
                        proposedDropOperation: (NSTableViewDropOperation) op
{
    NSPasteboard *pasteboard;
    NSData *pasteboardData;
    NSIndexSet *rowIndexes;
    unsigned int selectedRow;

    pasteboard = [info draggingPasteboard];
    pasteboardData = [pasteboard dataForType: kSizePresetsTableDraggedDataType];
    rowIndexes = [NSKeyedUnarchiver unarchiveObjectWithData: pasteboardData];
    selectedRow = [rowIndexes firstIndex];

    if ((op == NSTableViewDropAbove) && (selectedRow != newRow) && (selectedRow != (newRow-1)))
    {
        return NSDragOperationEvery;
    }
    else
    {
        return NSDragOperationNone;
    }
}

- (BOOL) tableView: (NSTableView *) aTableView
            acceptDrop: (id <NSDraggingInfo>) info
            row: (NSInteger) destinationTableRow
            dropOperation: (NSTableViewDropOperation) operation
{
    NSPasteboard *pboard;
    NSData *rowData;
    NSIndexSet *rowIndexes;
    int sourceTableRow;
    NSString *nameOnlyString, *nameAndSizeString;

    pboard = [info draggingPasteboard];
    rowData = [pboard dataForType: kSizePresetsTableDraggedDataType];
    rowIndexes = [NSKeyedUnarchiver unarchiveObjectWithData: rowData];
    sourceTableRow = [rowIndexes firstIndex];

    if (destinationTableRow > sourceTableRow)
    {
        destinationTableRow--;
    }

    nameOnlyString =
            [[[_presetNameOnlyStrings objectAtIndex: sourceTableRow] retain] autorelease];

    nameAndSizeString =
            [[[_presetNameAndSizeStrings objectAtIndex: sourceTableRow] retain] autorelease];

    [_presetNameOnlyStrings removeObjectAtIndex: sourceTableRow];
    [_presetNameAndSizeStrings removeObjectAtIndex: sourceTableRow];

    [_presetNameOnlyStrings insertObject: nameOnlyString atIndex: destinationTableRow];
    [_presetNameAndSizeStrings insertObject: nameAndSizeString atIndex: destinationTableRow];

    [_presetsTable reloadData];
    [self selectPresetsTableRow: destinationTableRow];

    return YES;
}

- (void) tableViewSelectionDidChange: (NSNotification *) notification
{
    if ([_presetsTable numberOfSelectedRows] > 1)
    {
        [self selectPresetsTableRow: [_presetsTable selectedRow]];
    }
    else
    {
        [self updateSizeFieldsForCurrentPresetsTableSelection];
    }
}

#pragma mark NSControl delegate methods (width/height textfields)

- (void) controlTextDidChange: (NSNotification *) notification
{
    id notifyingObject;
    int newFieldValue;
    bool needToUpdatePresetString = NO;

    notifyingObject = [notification object];

    if (notifyingObject == _widthTextField)
    {
        newFieldValue = [_widthTextField ppClampIntValueToMax: kMaxCanvasDimension
                                            min: kMinCanvasDimension
                                            defaultValue: _widthTextFieldValue];

        if (_widthTextFieldValue != newFieldValue)
        {
            _widthTextFieldValue = newFieldValue;
            needToUpdatePresetString = YES;
        }
    }
    else if (notifyingObject == _heightTextField)
    {
        newFieldValue = [_heightTextField ppClampIntValueToMax: kMaxCanvasDimension
                                            min: kMinCanvasDimension
                                            defaultValue: _heightTextFieldValue];

        if (_heightTextFieldValue != newFieldValue)
        {
            _heightTextFieldValue = newFieldValue;
            needToUpdatePresetString = YES;
        }
    }

    if (needToUpdatePresetString)
    {
        int selectedPresetIndex;
        NSString *nameAndSizeString;

        selectedPresetIndex = [_presetsTable selectedRow];

        nameAndSizeString =
            PPImageSizePresets_PresetStringForNameAndSize(
                                [_presetNameOnlyStrings objectAtIndex: selectedPresetIndex],
                                NSMakeSize(_widthTextFieldValue, _heightTextFieldValue));

        if (nameAndSizeString)
        {
            [_presetNameAndSizeStrings replaceObjectAtIndex: selectedPresetIndex
                                        withObject: nameAndSizeString];
        }
    }
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
    if ([_presetsTable editedRow] >= 0)
    {
        [_presetsTable abortEditing];
    }

    [self setupPresetStringArraysWithPresetStrings: [PPImageSizePresets presetStrings]];

    [self updateSheetForChangedPresets];

    [self selectPresetsTableRow: 0];
}

#pragma mark Private methods

- (bool) setupPresetStringArraysWithPresetStrings: (NSArray *) presetStrings
{
    [self destroyPresetStringArrays];

    _presetNameAndSizeStrings = [[NSMutableArray array] retain];
    _presetNameOnlyStrings = [[NSMutableArray array] retain];

    if (!_presetNameAndSizeStrings || !_presetNameOnlyStrings)
    {
        goto ERROR;
    }

    if ([presetStrings count])
    {
        NSEnumerator *presetsEnumerator;
        NSString *nameAndSizeString, *nameOnlyString;

        presetsEnumerator = [presetStrings objectEnumerator];

        while (nameAndSizeString = [presetsEnumerator nextObject])
        {
            nameOnlyString = PPImageSizePresets_NameForPresetString(nameAndSizeString);

            if (nameOnlyString)
            {
                [_presetNameAndSizeStrings addObject: nameAndSizeString];
                [_presetNameOnlyStrings addObject: nameOnlyString];
            }
        }
    }

    if (![_presetNameOnlyStrings count])
    {
        [self addNewPreset];
    }

    return YES;

ERROR:
    [self destroyPresetStringArrays];

    return NO;
}

- (void) destroyPresetStringArrays
{
    [_presetNameAndSizeStrings release];
    _presetNameAndSizeStrings = nil;

    [_presetNameOnlyStrings release];
    _presetNameOnlyStrings = nil;
}

- (void) selectPresetsTableRow: (unsigned) row
{
    if (row < [_presetNameOnlyStrings count])
    {
        [_presetsTable selectRowIndexes: [NSIndexSet indexSetWithIndex: row]
                        byExtendingSelection: NO];
    }
    else
    {
        [_presetsTable deselectAll: self];
    }

    [self updateSizeFieldsForCurrentPresetsTableSelection];
}

- (void) updateSizeFieldsForCurrentPresetsTableSelection
{
    int currentSelectionIndex;
    NSSize currentPresetSize = NSZeroSize;

    currentSelectionIndex = [_presetsTable selectedRow];

    if ((currentSelectionIndex >= 0)
        && (currentSelectionIndex < [_presetNameAndSizeStrings count]))
    {
        currentPresetSize =
            PPImageSizePresets_SizeForPresetString(
                            [_presetNameAndSizeStrings objectAtIndex: currentSelectionIndex]);
    }

    _widthTextFieldValue = currentPresetSize.width;
    [_widthTextField setIntValue: _widthTextFieldValue];

    _heightTextFieldValue = currentPresetSize.height;
    [_heightTextField setIntValue: _heightTextFieldValue];

    [_widthTextField selectText: self];
}

- (void) savePresetsTableEditing
{
    int editedRow;
    NSString *nameOnlyString, *nameAndSizeString;

    editedRow = [_presetsTable editedRow];

    if ((editedRow < 0) || (editedRow >= [_presetNameOnlyStrings count]))
    {
        return;
    }

    nameOnlyString = [[_presetsTable currentEditor] string];
    nameAndSizeString =
        PPImageSizePresets_PresetStringForNameAndSize(
                                nameOnlyString,
                                PPImageSizePresets_SizeForPresetString(
                                        [_presetNameAndSizeStrings objectAtIndex: editedRow]));

    if (!nameAndSizeString)
        return;

    [_presetNameAndSizeStrings replaceObjectAtIndex: editedRow withObject: nameAndSizeString];
    [_presetNameOnlyStrings replaceObjectAtIndex: editedRow withObject: nameOnlyString];
}

- (void) updateSheetForChangedPresets
{
    [_presetsTable reloadData];
    [self updateSizeFieldsForCurrentPresetsTableSelection];
}

- (void) addNewPreset
{
    NSString *nameOnlyString, *nameAndSizeString;
    int insertionIndex;

    nameOnlyString = kNewPresetName;
    nameAndSizeString =
                PPImageSizePresets_PresetStringForNameAndSize(nameOnlyString, kNewPresetSize);

    if (!nameOnlyString || !nameAndSizeString)
    {
        return;
    }

    insertionIndex = [_presetsTable selectedRow];

    if (insertionIndex < 0)
    {
        insertionIndex = 0;
    }

    [_presetNameAndSizeStrings insertObject: nameAndSizeString atIndex: insertionIndex];
    [_presetNameOnlyStrings insertObject: nameOnlyString atIndex: insertionIndex];

    [self updateSheetForChangedPresets];

    [_presetsTable editColumn: 0 row: insertionIndex withEvent: nil select: YES];
}

- (void) deleteCurrentPreset
{
    int deletionIndex, numPresets;

    deletionIndex = [_presetsTable selectedRow];

    if (deletionIndex < 0)
    {
        return;
    }

    if ([_presetsTable editedRow] >= 0)
    {
        [_presetsTable abortEditing];
    }

    [_presetNameAndSizeStrings removeObjectAtIndex: deletionIndex];
    [_presetNameOnlyStrings removeObjectAtIndex: deletionIndex];

    [self updateSheetForChangedPresets];

    numPresets = [_presetNameOnlyStrings count];

    if (!numPresets)
    {
        [self addNewPreset];
    }
    else if (deletionIndex >= numPresets)
    {
        [self selectPresetsTableRow: numPresets-1];
    }
}

@end
