/*
    PPLayersTableView.m

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

#import "PPLayersTableView.h"


@implementation PPLayersTableView

- (void) dealloc
{
    [_selectedRowsAtMouseDown release];

    [super dealloc];
}

- (void) restoreSelectionFromLastMouseDown
{
    [self selectRowIndexes: _selectedRowsAtMouseDown byExtendingSelection: NO];
}

#pragma mark Actions

- (IBAction) layerEnabledButtonCellClicked: (id) sender
{
    [self restoreSelectionFromLastMouseDown];
}

#pragma mark NSTableView overrides

- (BOOL) acceptsFirstMouse: (NSEvent *) theEvent
{
    return YES;
}

- (void) mouseDown: (NSEvent *) theEvent
{
    [_selectedRowsAtMouseDown release];
    _selectedRowsAtMouseDown = [[self selectedRowIndexes] retain];

    [super mouseDown: theEvent];
}

- (NSUndoManager *) undoManager
{
    // returning nil prevents the tableview's textfield editor from finding the document's
    // undoManager higher up in the responder chain (PPLayersPanelController), which prevents
    // undoing the document's non-text actions while editing a layer name

    return nil;
}

@end
