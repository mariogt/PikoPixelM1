/*
    PPDocumentSamplerImagesSettingsSheetController.m

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

#import "PPDocumentSamplerImagesSettingsSheetController.h"

#import "PPDocumentSamplerImage.h"
#import "NSImage_PPUtilities.h"
#import "NSBitmapImageRep_PPUtilities.h"
#import "NSPasteboard_PPUtilities.h"
#import "PPGeometry.h"


#define kDocumentSamplerImagesSettingsSheetNibName  @"DocumentSamplerImagesSettingsSheet"

#define kSamplerImagesTableDraggedDataType          @"SamplerImagesTableDraggedDataType"

#define kSamplerImagesTableImageColumnIdentifier    @"Images"


@interface PPDocumentSamplerImagesSettingsSheetController (PrivateMethods)

- initWithSamplerImages: (NSArray *) samplerImages
    delegate: (id) delegate;

- (void) updateButtonEnabledStates;

- (NSImage *) imageForSamplerImageTableFromBitmap: (NSBitmapImageRep *) bitmap
                    withCellSize: (NSSize) cellSize;

- (void) selectSamplerImagesTableRow: (unsigned) row;

- (void) addSamplerImage: (PPDocumentSamplerImage *) samplerImage;

- (void) samplerImageOpenPanelDidEnd: (NSOpenPanel *) panel
            returnCode: (int) returnCode
            contextInfo: (void  *) contextInfo;

@end


#if PP_SDK_REQUIRES_PROTOCOLS_FOR_DELEGATES_AND_DATASOURCES

@interface PPDocumentSamplerImagesSettingsSheetController (RequiredProtocols)
                                <NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate>
@end

#endif  // PP_SDK_REQUIRES_PROTOCOLS_FOR_DELEGATES_AND_DATASOURCES


@implementation PPDocumentSamplerImagesSettingsSheetController

+ (bool) beginSamplerImagesSettingsSheetForWindow: (NSWindow *) window
            samplerImages: (NSArray *) samplerImages
            delegate: (id) delegate
{
    PPDocumentSamplerImagesSettingsSheetController *controller;

    controller = [[[self alloc] initWithSamplerImages: samplerImages delegate: delegate]
                            autorelease];

    if (![controller beginSheetModalForWindow: window])
    {
        goto ERROR;
    }

    return YES;

ERROR:
    return NO;
}

- initWithSamplerImages: (NSArray *) samplerImages
    delegate: (id) delegate
{
    self = [super initWithNibNamed: kDocumentSamplerImagesSettingsSheetNibName
                    delegate: delegate];

    if (!self)
        goto ERROR;

    _samplerImages = [[NSMutableArray array] retain];

    if (!_samplerImages)
        goto ERROR;

    if (samplerImages)
    {
        [_samplerImages addObjectsFromArray: samplerImages];
    }

    [_sheet setDelegate: self];

    [_samplerImagesTable setDataSource: self];
    [_samplerImagesTable setDelegate: self];
    [_samplerImagesTable registerForDraggedTypes:
                                [NSArray arrayWithObject: kSamplerImagesTableDraggedDataType]];

    _samplerImagesTableImageColumn =
        [_samplerImagesTable columnWithIdentifier: kSamplerImagesTableImageColumnIdentifier];

    [self updateButtonEnabledStates];

    return self;

ERROR:
    [self release];

    return nil;
}

- (void) dealloc
{
    [_samplerImages release];

    [super dealloc];
}

#pragma mark Actions

- (IBAction) addImageFromClipboardButtonPressed: (id) sender
{
    NSBitmapImageRep *imageBitmap;
    PPDocumentSamplerImage *samplerImage;

    if (![NSPasteboard ppGetImageBitmap: &imageBitmap])
    {
        goto ERROR;
    }

    samplerImage = [PPDocumentSamplerImage samplerImageWithBitmap: imageBitmap];

    if (!samplerImage)
        goto ERROR;

    [self addSamplerImage: samplerImage];

    return;

ERROR:
    return;
}

- (IBAction) addImageFromFileButtonPressed: (id) sender
{
    /*[[NSOpenPanel openPanel] beginSheetForDirectory: nil
                                file: nil
                                types: [NSImage imageTypes]
                                modalForWindow: _sheet
                                modalDelegate: self
                                didEndSelector:
                                    @selector(samplerImageOpenPanelDidEnd:
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

- (IBAction) copyImageToClipboardButtonPressed: (id) sender
{
    unsigned indexOfSelectedImage;
    PPDocumentSamplerImage *samplerImage;

    indexOfSelectedImage = [_samplerImagesTable selectedRow];

    if (indexOfSelectedImage >= [_samplerImages count])
    {
        goto ERROR;
    }

    samplerImage = [_samplerImages objectAtIndex: indexOfSelectedImage];

    if (!samplerImage)
        goto ERROR;

    [NSPasteboard ppSetImageBitmap: [samplerImage bitmap]];

    [self updateButtonEnabledStates];

    return;

ERROR:
    return;
}

- (IBAction) removeImageButtonPressed: (id) sender
{
    unsigned indexOfSelectedImage = [_samplerImagesTable selectedRow];

    if (indexOfSelectedImage >= [_samplerImages count])
    {
        goto ERROR;
    }

    [_samplerImages removeObjectAtIndex: indexOfSelectedImage];

    [_samplerImagesTable reloadData];
    [self updateButtonEnabledStates];

    return;

ERROR:
    return;
}

- (IBAction) removeAllImagesButtonPressed: (id) sender
{
    [_samplerImages removeAllObjects];

    [_samplerImagesTable reloadData];
    [self updateButtonEnabledStates];
}

#pragma mark PPDocumentSheetController overrides (delegate notifiers)

- (void) notifyDelegateSheetDidFinish
{
    if ([_delegate respondsToSelector:
                            @selector(samplerImagesSettingsSheetDidFinishWithSamplerImages:)])
    {
        [_delegate samplerImagesSettingsSheetDidFinishWithSamplerImages: _samplerImages];
    }
}

- (void) notifyDelegateSheetDidCancel
{
    if ([_delegate respondsToSelector: @selector(samplerImagesSettingsSheetDidCancel)])
    {
        [_delegate samplerImagesSettingsSheetDidCancel];
    }
}

#pragma mark NSWindow delegate

- (void) windowDidBecomeKey: (NSNotification *) notification
{
    [self updateButtonEnabledStates];
}

#pragma mark NSTableView data source (Sampler images table)

- (NSInteger) numberOfRowsInTableView: (NSTableView *) aTableView
{
    return [_samplerImages count];
}

- (id) tableView: (NSTableView *) tableView
        objectValueForTableColumn: (NSTableColumn *) tableColumn
        row: (NSInteger) row
{
    PPDocumentSamplerImage *samplerImage;
    NSSize cellSize;

    if (tableView != _samplerImagesTable)
    {
        return nil;
    }

    if (![[tableColumn identifier] isEqualToString: kSamplerImagesTableImageColumnIdentifier])
    {
        return nil;
    }

    samplerImage = [_samplerImages objectAtIndex: row];

    cellSize = [_samplerImagesTable frameOfCellAtColumn: _samplerImagesTableImageColumn
                                    row: row].size;

    return [self imageForSamplerImageTableFromBitmap: [samplerImage bitmap]
                    withCellSize: cellSize];
}

- (BOOL) tableView: (NSTableView *) tableView
            writeRowsWithIndexes: (NSIndexSet *) rowIndexes
            toPasteboard: (NSPasteboard*) pasteboard
{
    NSData *pasteboardData;

    pasteboardData = [NSKeyedArchiver archivedDataWithRootObject: rowIndexes];

    [pasteboard declareTypes: [NSArray arrayWithObject: kSamplerImagesTableDraggedDataType]
                owner: self];

    [pasteboard setData: pasteboardData forType: kSamplerImagesTableDraggedDataType];

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
    pasteboardData = [pasteboard dataForType: kSamplerImagesTableDraggedDataType];
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
    PPDocumentSamplerImage *samplerImage;

    pboard = [info draggingPasteboard];
    rowData = [pboard dataForType: kSamplerImagesTableDraggedDataType];
    rowIndexes = [NSKeyedUnarchiver unarchiveObjectWithData: rowData];
    sourceTableRow = [rowIndexes firstIndex];

    if (destinationTableRow > sourceTableRow)
    {
        destinationTableRow--;
    }

    samplerImage = [[[_samplerImages objectAtIndex: sourceTableRow] retain] autorelease];

    [_samplerImages removeObjectAtIndex: sourceTableRow];

    [_samplerImages insertObject: samplerImage atIndex: destinationTableRow];

    [_samplerImagesTable reloadData];
    [self selectSamplerImagesTableRow: destinationTableRow];

    return YES;
}

- (void) tableViewSelectionDidChange: (NSNotification *) notification
{
    if ([_samplerImagesTable numberOfSelectedRows] > 1)
    {
        [self selectSamplerImagesTableRow: [_samplerImagesTable selectedRow]];
    }
}

#pragma mark NSOpenPanel delegate (Add image from file)

- (void) samplerImageOpenPanelDidEnd: (NSOpenPanel *) panel
            returnCode: (int) returnCode
            contextInfo: (void  *) contextInfo
{
    NSURL *imageURL;
    NSImage *image;
    NSBitmapImageRep *imageBitmap;
    PPDocumentSamplerImage *samplerImage;

    [panel orderOut: self];

    if (returnCode != NSModalResponseOK)
    {
        return;
    }

    imageURL = [[panel URLs] objectAtIndex: 0];

    if (!imageURL)
        goto ERROR;

    image = [[[NSImage alloc] initWithContentsOfURL: imageURL] autorelease];

    if (!image)
        goto ERROR;

    imageBitmap = [image ppBitmap];

    if (!imageBitmap)
        goto ERROR;

    samplerImage = [PPDocumentSamplerImage samplerImageWithBitmap: imageBitmap];

    if (!samplerImage)
        goto ERROR;

    [self addSamplerImage: samplerImage];

    return;

ERROR:
    return;
}

#pragma mark Private methods

- (void) updateButtonEnabledStates
{
    bool hasSamplerImages = ([_samplerImages count]) ? YES : NO;

    [_copyImageToClipboardButton setEnabled: hasSamplerImages];
    [_removeImageButton setEnabled: hasSamplerImages];
    [_removeAllImagesButton setEnabled: hasSamplerImages];
}

- (NSImage *) imageForSamplerImageTableFromBitmap: (NSBitmapImageRep *) bitmap
                    withCellSize: (NSSize) cellSize
{
    NSSize bitmapSize;
    float scale;

    bitmapSize = [bitmap ppSizeInPixels];

    if (PPGeometry_IsZeroSize(bitmapSize))
    {
        goto ERROR;
    }

    scale = MAX(ceilf(4.0f * cellSize.width / bitmapSize.width),
                ceilf(4.0f * cellSize.height / bitmapSize.width));

    return [NSImage ppImageWithBitmap: [bitmap ppImageBitmapScaledByFactor: scale
                                                shouldDrawGrid: NO
                                                gridType: 0
                                                gridColor: nil]];

ERROR:
    return nil;
}

- (void) selectSamplerImagesTableRow: (unsigned) row
{
    if (row < [_samplerImages count])
    {
        [_samplerImagesTable selectRowIndexes: [NSIndexSet indexSetWithIndex: row]
                                byExtendingSelection: NO];
    }
    else
    {
        [_samplerImagesTable deselectAll: self];
    }
}

- (void) addSamplerImage: (PPDocumentSamplerImage *) samplerImage
{
    if (!samplerImage)
        return;

    if (![_samplerImages containsObject: samplerImage])
    {
        int insertionIndex = [_samplerImagesTable selectedRow];

        if (insertionIndex < 0)
        {
            insertionIndex = 0;
        }

        [_samplerImages insertObject: samplerImage atIndex: insertionIndex];

        [_samplerImagesTable reloadData];
        [self updateButtonEnabledStates];
    }
    else
    {
        [self selectSamplerImagesTableRow: [_samplerImages indexOfObject: samplerImage]];
    }
}

@end
