/*
    PPDocumentEditPatternPresetsSheetController.m

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

#import "PPDocumentEditPatternPresetsSheetController.h"

#import "PPPresettablePatternView.h"
#import "PPPatternPresets.h"
#import "NSMutableArray_PPUtilities.h"


#define kDocumentEditPatternPresetsSheetNibName     @"DocumentEditPatternPresetsSheet"

#define kPresetsTableDraggedDataTypeFormatString    @"EditPresetsTableDraggedDataType_%@"

#define kSheetTitleFormatString                     @"Edit %@ Pattern Presets"

#define kNewPresetName                              @"Untitled Preset"

#define kEmptyPatternDisplayColor                   [NSColor lightGrayColor]


@interface PPDocumentEditPatternPresetsSheetController (PrivateMethods)

- initWithPatternPresets: (PPPatternPresets *) patternPresets
    patternTypeDisplayName: (NSString *) patternTypeDisplayName
    currentPattern: (id <PPPresettablePattern>) currentPattern
    delegate: (id) delegate;

- (void) addAsObserverForPPPatternPresetsNotifications;
- (void) removeAsObserverForPPPatternPresetsNotifications;
- (void) handlePPPatternPresetsNotification_UpdatedPresets: (NSNotification *) notification;

- (void) loadEditablePatternsFromPresets;

- (void) selectPatternsTableRow: (unsigned) row;

- (void) updatePatternViewForCurrentPatternsTableSelection;

- (void) savePatternsTableEditing;

- (void) updateRemoveButtonsEnabledStates;

- (void) setupSheetStateWithEditablePatterns;

- (int) indexOfEditablePattern: (id <PPPresettablePattern>) pattern;

- (void) addCurrentPatternToEditablePatterns;
- (void) removeSelectedPatternFromEditablePatterns;
- (void) removeAllEditablePatterns;

@end


#if PP_SDK_REQUIRES_PROTOCOLS_FOR_DELEGATES_AND_DATASOURCES

@interface PPDocumentEditPatternPresetsSheetController (RequiredProtocols)
                                                <NSTableViewDataSource, NSTableViewDelegate>
@end

#endif  // PP_SDK_REQUIRES_PROTOCOLS_FOR_DELEGATES_AND_DATASOURCES


@implementation PPDocumentEditPatternPresetsSheetController

+ (bool) beginEditPatternPresetsSheetForWindow: (NSWindow *) window
            patternPresets: (PPPatternPresets *) patternPresets
            patternTypeDisplayName: (NSString *) patternTypeDisplayName
            currentPattern: (id <PPPresettablePattern>) currentPattern
            addCurrentPatternAsPreset: (bool) addCurrentPatternAsPreset
            delegate: (id) delegate
{
    PPDocumentEditPatternPresetsSheetController *controller;

    controller = [[[self alloc] initWithPatternPresets: patternPresets
                                patternTypeDisplayName: patternTypeDisplayName
                                currentPattern: currentPattern
                                delegate: delegate]
                            autorelease];

    if (![controller beginSheetModalForWindow: window])
    {
        goto ERROR;
    }

    if (addCurrentPatternAsPreset)
    {
        [controller addCurrentPatternToEditablePatterns];
    }

    return YES;

ERROR:
    return NO;
}

- initWithPatternPresets: (PPPatternPresets *) patternPresets
    patternTypeDisplayName: (NSString *) patternTypeDisplayName
    currentPattern: (id <PPPresettablePattern>) currentPattern
    delegate: (id) delegate
{
    self = [super initWithNibNamed: kDocumentEditPatternPresetsSheetNibName
                    delegate: delegate];

    if (!self)
        goto ERROR;

    if (!patternPresets
        || ![patternTypeDisplayName length]
        || ![currentPattern conformsToProtocol: @protocol(PPPresettablePattern)])
    {
        goto ERROR;
    }

    _patternPresets = [patternPresets retain];

    _editablePatterns = [[NSMutableArray array] retain];

    _currentPattern = [currentPattern copyWithZone: NULL];

    _editablePatternsTableDraggedDataType =
                        [[NSString stringWithFormat: kPresetsTableDraggedDataTypeFormatString,
                                                        patternTypeDisplayName]
                                retain];

    if (!_patternPresets
        || !_editablePatterns
        || !_currentPattern
        || !_editablePatternsTableDraggedDataType)
    {
        goto ERROR;
    }

    [self loadEditablePatternsFromPresets];

    [_currentPattern setPresetName: kNewPresetName];

    [_sheetTitleField setStringValue: [NSString stringWithFormat: kSheetTitleFormatString,
                                                                    patternTypeDisplayName]];

    [_editablePatternsTable setDataSource: self];
    [_editablePatternsTable setDelegate: self];
    [_editablePatternsTable registerForDraggedTypes:
                                            [NSArray arrayWithObject:
                                                        _editablePatternsTableDraggedDataType]];

    [self selectPatternsTableRow: 0];

    [self setupSheetStateWithEditablePatterns];

    [self addAsObserverForPPPatternPresetsNotifications];

    return self;

ERROR:
    [self release];

    return nil;
}

- init
{
    return [self initWithPatternPresets: nil
                    patternTypeDisplayName: nil
                    currentPattern: nil
                    delegate: nil];
}

- (void) dealloc
{
    [self removeAsObserverForPPPatternPresetsNotifications];

    [_patternPresets release];

    [_editablePatterns release];

    [_currentPattern release];

    [_editablePatternsTableDraggedDataType release];

    [super dealloc];
}

#pragma mark Actions

- (IBAction) addCurrentPatternAsPresetButtonPressed: (id) sender
{
    [self addCurrentPatternToEditablePatterns];
}

- (IBAction) removePresetButtonPressed: (id) sender
{
    [self removeSelectedPatternFromEditablePatterns];
}

- (IBAction) removeAllPresetsButtonPressed: (id) sender
{
    [self removeAllEditablePatterns];
}

#pragma mark PPDocumentSheetController overrides (actions)

- (IBAction) OKButtonPressed: (id) sender
{
    [self removeAsObserverForPPPatternPresetsNotifications];

    [self savePatternsTableEditing];

    [_patternPresets setPatterns: _editablePatterns];

    [super OKButtonPressed: sender];
}

#pragma mark PPDocumentSheetController overrides (delegate notifiers)

- (void) notifyDelegateSheetDidFinish
{
    if ([_delegate respondsToSelector: @selector(editPatternPresetsSheetDidFinish)])
    {
        [_delegate editPatternPresetsSheetDidFinish];
    }
}

- (void) notifyDelegateSheetDidCancel
{
    if ([_delegate respondsToSelector: @selector(editPatternPresetsSheetDidCancel)])
    {
        [_delegate editPatternPresetsSheetDidCancel];
    }
}

#pragma mark NSTableView data source (Presets table)

- (NSInteger) numberOfRowsInTableView: (NSTableView *) aTableView
{
    return [_editablePatterns count];
}

- (id) tableView: (NSTableView *) tableView
        objectValueForTableColumn: (NSTableColumn *) tableColumn
        row: (NSInteger) row
{
    id <PPPresettablePattern> pattern = [_editablePatterns objectAtIndex: row];

    return [pattern presetName];
}

- (void) tableView: (NSTableView *) tableView
            setObjectValue: (id) object
            forTableColumn: (NSTableColumn *) tableColumn
            row: (NSInteger) row
{
    id <PPPresettablePattern> pattern = [_editablePatterns objectAtIndex: row];

    [pattern setPresetName: object];
}

- (BOOL) tableView: (NSTableView *) tableView
            writeRowsWithIndexes: (NSIndexSet *) rowIndexes
            toPasteboard: (NSPasteboard*) pasteboard
{
    NSData *pasteboardData;

    pasteboardData = [NSKeyedArchiver archivedDataWithRootObject: rowIndexes];

    [pasteboard declareTypes: [NSArray arrayWithObject: _editablePatternsTableDraggedDataType]
                owner: self];

    [pasteboard setData: pasteboardData forType: _editablePatternsTableDraggedDataType];

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
    pasteboardData = [pasteboard dataForType: _editablePatternsTableDraggedDataType];
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
    id <PPPresettablePattern> pattern;

    pboard = [info draggingPasteboard];
    rowData = [pboard dataForType: _editablePatternsTableDraggedDataType];
    rowIndexes = [NSKeyedUnarchiver unarchiveObjectWithData: rowData];
    sourceTableRow = [rowIndexes firstIndex];

    if (destinationTableRow > sourceTableRow)
    {
        destinationTableRow--;
    }

    pattern = [[[_editablePatterns objectAtIndex: sourceTableRow] retain] autorelease];

    [_editablePatterns removeObjectAtIndex: sourceTableRow];

    [_editablePatterns insertObject: pattern atIndex: destinationTableRow];

    [_editablePatternsTable reloadData];
    [self selectPatternsTableRow: destinationTableRow];

    return YES;
}

- (void) tableViewSelectionDidChange: (NSNotification *) notification
{
    if ([_editablePatternsTable numberOfSelectedRows] > 1)
    {
        [self selectPatternsTableRow: [_editablePatternsTable selectedRow]];
    }
    else
    {
        [self updatePatternViewForCurrentPatternsTableSelection];
    }
}

#pragma mark PPPatternPresets notifications

- (void) addAsObserverForPPPatternPresetsNotifications
{
    [[NSNotificationCenter defaultCenter]
                                addObserver: self
                                selector:
                                    @selector(handlePPPatternPresetsNotification_UpdatedPresets:)
                                name: PPPatternPresetsNotification_UpdatedPresets
                                object: _patternPresets];
}

- (void) removeAsObserverForPPPatternPresetsNotifications
{
    [[NSNotificationCenter defaultCenter]
                                removeObserver: self
                                name: PPPatternPresetsNotification_UpdatedPresets
                                object: _patternPresets];
}

- (void) handlePPPatternPresetsNotification_UpdatedPresets: (NSNotification *) notification
{
    if ([_editablePatternsTable editedRow] >= 0)
    {
        [_editablePatternsTable abortEditing];
    }

    [self loadEditablePatternsFromPresets];

    [self setupSheetStateWithEditablePatterns];

    [self selectPatternsTableRow: 0];
}

#pragma mark Private methods

- (void) loadEditablePatternsFromPresets
{
    [_editablePatterns removeAllObjects];

    // edit copies of pattern preset objects, not originals
    [_editablePatterns ppAddCopiesOfObjectsFromArray: [_patternPresets patterns]];
}

- (void) selectPatternsTableRow: (unsigned) row
{
    if (row < [_editablePatterns count])
    {
        [_editablePatternsTable selectRowIndexes: [NSIndexSet indexSetWithIndex: row]
                                byExtendingSelection: NO];
    }
    else
    {
        [_editablePatternsTable deselectAll: self];
    }

    [self updatePatternViewForCurrentPatternsTableSelection];
}

- (void) updatePatternViewForCurrentPatternsTableSelection
{
    int currentSelectionIndex;
    id <PPPresettablePattern> pattern = nil;

    currentSelectionIndex = [_editablePatternsTable selectedRow];

    if ((currentSelectionIndex >= 0) && (currentSelectionIndex < [_editablePatterns count]))
    {
        pattern = [_editablePatterns objectAtIndex: currentSelectionIndex];
    }

    [_patternView setPresettablePattern: pattern];
}

- (void) savePatternsTableEditing
{
    int editedRow;
    id <PPPresettablePattern> pattern;

    editedRow = [_editablePatternsTable editedRow];

    if ((editedRow < 0) || (editedRow >= [_editablePatterns count]))
    {
        return;
    }

    pattern = [_editablePatterns objectAtIndex: editedRow];

    [pattern setPresetName: [[_editablePatternsTable currentEditor] string]];
}

- (void) updateRemoveButtonsEnabledStates
{
    bool shouldEnableRemoveButtons = ([_editablePatterns count] > 0) ? YES : NO;

    [_removePresetButton setEnabled: shouldEnableRemoveButtons];
    [_removeAllPresetsButton setEnabled: shouldEnableRemoveButtons];
}

- (void) setupSheetStateWithEditablePatterns
{
    [_editablePatternsTable reloadData];
    [self updatePatternViewForCurrentPatternsTableSelection];
    [self updateRemoveButtonsEnabledStates];
}

- (int) indexOfEditablePattern: (id <PPPresettablePattern>) pattern
{
    int index;

    if (!pattern)
    {
        return -1;
    }

    for (index=[_editablePatterns count]-1; index>=0; index--)
    {
        if ([pattern isEqualToPresettablePattern: [_editablePatterns objectAtIndex: index]])
        {
            return index;
        }
    }

    return -1;
}

- (void) addCurrentPatternToEditablePatterns
{
    int editingIndex, existingIndex, insertionIndex;

    if (!_currentPattern)
        return;

    editingIndex = [_editablePatternsTable editedRow];
    existingIndex = [self indexOfEditablePattern: _currentPattern];

    if (editingIndex >= 0)
    {
        if (editingIndex == existingIndex)
        {
            return;
        }
        else
        {
            [_editablePatternsTable abortEditing];
        }
    }

    if (existingIndex >= 0)
    {
        [self selectPatternsTableRow: existingIndex];
        return;
    }

    insertionIndex = [_editablePatternsTable selectedRow];

    if (insertionIndex < 0)
    {
        insertionIndex = 0;
    }

    [_editablePatterns insertObject: _currentPattern atIndex: insertionIndex];

    [self setupSheetStateWithEditablePatterns];

    [_editablePatternsTable editColumn: 0 row: insertionIndex withEvent: nil select: YES];
}

- (void) removeSelectedPatternFromEditablePatterns
{
    int deletionIndex, numPresets;

    deletionIndex = [_editablePatternsTable selectedRow];

    if (deletionIndex < 0)
    {
        return;
    }

    if ([_editablePatternsTable editedRow] >= 0)
    {
        [_editablePatternsTable abortEditing];
    }

    [_editablePatterns removeObjectAtIndex: deletionIndex];

    [self setupSheetStateWithEditablePatterns];

    numPresets = [_editablePatterns count];

    if (deletionIndex >= numPresets)
    {
        [self selectPatternsTableRow: numPresets-1];
    }
}

- (void) removeAllEditablePatterns
{
    if ([_editablePatternsTable editedRow] >= 0)
    {
        [_editablePatternsTable abortEditing];
    }

    [_editablePatterns removeAllObjects];

    [self setupSheetStateWithEditablePatterns];

    [self selectPatternsTableRow: -1];
}

@end
