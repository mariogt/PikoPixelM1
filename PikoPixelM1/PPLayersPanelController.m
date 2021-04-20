/*
    PPLayersPanelController.m

    Copyright 2013-2018,2020 Josh Freeman
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

#import "PPLayersPanelController.h"

#import "PPDocument.h"
#import "PPDocumentWindowController.h"
#import "PPDocumentLayer.h"
#import "PPLayersTableView.h"
#import "PPLayerBlendingModeButton.h"
#import "PPLayerOpacitySliderCell.h"
#import "PPGeometry.h"
#import "PPBackgroundPattern.h"
#import "PPLayerControlButtonImagesManager.h"
#import "PPTextAttributesDicts.h"
#import "PPPanelDefaultFramePinnings.h"
#import "NSObject_PPUtilities.h"
#import "NSBitmapImageRep_PPUtilities.h"
#import "NSImage_PPUtilities.h"
#import "PPThumbnailUtilities.h"


#define kLayersPanelNibName                     @"LayersPanel"

#define kLayersTableColumnIdentifier_Enabled    @"Enabled"
#define kLayersTableColumnIdentifier_Thumbnail  @"Thumbnail"
#define kLayersTableColumnIdentifier_Name       @"Name"
#define kLayersTableColumnIdentifier_Opacity    @"Opacity"

#define kLayersTableDraggedDataType             @"PPLayersTableDraggedDataType"

#define kLayersTableColumnIndex_Thumbnail       1


@interface PPLayersPanelController (PrivateMethods)

- (void) handlePPDocumentNotification_UpdatedDrawingLayerThumbnailImage:
                                                            (NSNotification *) notification;
- (void) handlePPDocumentNotification_SwitchedDrawingLayer: (NSNotification *) notification;
- (void) handlePPDocumentNotification_ReorderedLayers: (NSNotification *) notification;
- (void) handlePPDocumentNotification_PerformedMultilayerOperation:
                                                            (NSNotification *) notification;
- (void) handlePPDocumentNotification_ChangedLayerAttribute: (NSNotification *) notification;
- (void) handlePPDocumentNotification_SwitchedLayerOperationTarget:
                                                            (NSNotification *) notification;
- (void) handlePPDocumentNotification_SwitchedLayerBlendingMode:
                                                            (NSNotification *) notification;
- (void) handlePPDocumentNotification_UpdatedBackgroundSettings:
                                                            (NSNotification *) notification;
- (void) handlePPDocumentNotification_ReloadedDocument: (NSNotification *) notification;

- (void) addAsObserverForPPDocumentWindowControllerNotifications;
- (void) removeAsObserverForPPDocumentWindowControllerNotifications;
- (void) handlePPDocumentWindowControllerNotification_ChangedCanvasDisplayMode:
                                                            (NSNotification *) notification;

- (void) addAsObserverForPPLayerControlButtonImagesManagerNotifications;
- (void) removeAsObserverForPPLayerControlButtonImagesManagerNotifications;
- (void) handlePPLayerControlButtonImagesManagerNotification_ChangedDrawLayerImages:
                                                                (NSNotification *) notification;
- (void) handlePPLayerControlButtonImagesManagerNotification_ChangedEnabledLayersImages:
                                                                (NSNotification *) notification;

- (void) addAsObserverForPPLayersTableViewNotifications;
- (void) removeAsObserverForPPLayersTableViewNotifications;
- (void) handlePPLayersTableViewNotification_TextDidEndEditing: (NSNotification *) notification;

- (void) setupLayerThumbnailsCacheForCurrentPPDocument;
- (void) destroyLayerThumbnailsCache;
- (void) destroyAllCachedLayerThumbnailsAndResizeCacheForCurrentPPDocument;
- (void) setupLayerThumbnailDrawMembersForCurrentPPDocument;
- (NSImage *) cachedThumbnailForLayerAtIndex: (unsigned) index;
- (void) destroyCachedThumbnailForLayerAtIndex: (unsigned) index;
- (void) destroyAllCachedLayerThumbnails;
- (void) setupLayerThumbnailBackgroundBitmapForCurrentPPDocument;
- (void) destroyLayerThumbnailBackgroundBitmap;

- (id) cachedDisabledLayerNameAttrStringForLayerName: (NSString *) layerName;
- (void) destroyAllCachedDisabledLayerNameAttrStrings;

- (void) setupTrackingRectForPanelContentView: (NSView *) panelContentView;
- (void) mouseEntered: (NSEvent *) theEvent;
- (void) mouseExited: (NSEvent *) theEvent;

- (void) handleResizedPanel;
- (void) resizeLayerControlButtonsForPanelContentWidth: (float) contentWidth;
- (void) setupWithPPDocumentWindowController:
                                    (PPDocumentWindowController *) ppDocumentWindowController;
- (void) updateCanvasDisplayMode;
- (void) updateLayerOperationTarget;

- (void) updateCanvasDisplayModeButtonImage;
- (void) updateLayerOperationTargetButtonImage;
- (void) updateLayerControlButtonImages;
- (void) updateLayerBlendingModeButtonWithCurrentMode;

- (void) reloadLayersTableDataAndUpdateSelection;
- (void) reloadLayersTableDataForLayerAtIndex: (unsigned) layerIndex;
- (void) reloadLayersTableThumbnailDataForLayerAtIndex: (unsigned) layerIndex;
- (void) updateLayersTableSelection;
- (unsigned) tableRowIndexForLayerIndex: (unsigned) layerIndex;
- (unsigned) layerIndexForTableRowIndex: (unsigned) rowIndex;

- (bool) isEditingLayerNameText;
- (void) endEditingForLayerNameText;
- (void) resignKeyWindowUnlessEditingLayerNameText;

@end


#if PP_SDK_REQUIRES_PROTOCOLS_FOR_DELEGATES_AND_DATASOURCES

@interface PPLayersPanelController (RequiredProtocols) <NSTableViewDataSource,
                                                        NSTableViewDelegate>
@end

#endif  // PP_SDK_REQUIRES_PROTOCOLS_FOR_DELEGATES_AND_DATASOURCES


@implementation PPLayersPanelController

- (void) dealloc
{
    [self removeAsObserverForPPLayerControlButtonImagesManagerNotifications];

    [self removeAsObserverForPPLayersTableViewNotifications];

    [self setupWithPPDocumentWindowController: nil];

    [self destroyLayerThumbnailsCache];

    [_cachedDisabledLayerNameAttrStringsDict release];

    [super dealloc];
}

- (void) setTrackingOpacitySliderCell: (PPLayerOpacitySliderCell *) trackingOpacitySliderCell
{
    bool shouldDisableThumbnailImageUpdateNotifications;

    [_layersTable restoreSelectionFromLastMouseDown];

    if (_trackingOpacitySliderCell == trackingOpacitySliderCell)
    {
        return;
    }

    _trackingOpacitySliderCell = trackingOpacitySliderCell;

    shouldDisableThumbnailImageUpdateNotifications = (trackingOpacitySliderCell) ? YES : NO;

    // improve drawing performance by disabling thumbnail updates until finished tracking
    [_ppDocument disableThumbnailImageUpdateNotifications:
                                                shouldDisableThumbnailImageUpdateNotifications];

    if (!shouldDisableThumbnailImageUpdateNotifications)
    {
        [_ppDocument sendThumbnailImageUpdateNotifications];
    }
}

#pragma mark Actions

- (IBAction) canvasDisplayModeButtonPressed: (id) sender
{
    [_ppDocumentWindowController toggleCanvasDisplayMode];
}

- (IBAction) layerOperationTargetButtonPressed: (id) sender
{
    [_ppDocumentWindowController toggleLayerOperationTarget: self];
}

- (IBAction) layersTableOpacitySliderMoved: (id) sender
{
    int clickedRow;
    PPDocumentLayer *layer;

    if (sender != _layersTable)
    {
        return;
    }

    clickedRow = [_layersTable clickedRow];

    if ((clickedRow == -1) || !_trackingOpacitySliderCell)
    {
        return;
    }

    layer = [_ppDocument layerAtIndex: [self layerIndexForTableRowIndex: clickedRow]];

    _ignoreNotificationForChangedLayerAttribute = YES;

    [layer setOpacityWithoutRegisteringUndo: [_trackingOpacitySliderCell floatValue]];

    _ignoreNotificationForChangedLayerAttribute = NO;
}

- (IBAction) addLayerButtonPressed: (id) sender
{
    // end editing of layer name if necessary, otherwise the button's undoable action will
    // register before the layer name change registers (wrong order)
    [self endEditingForLayerNameText];

    [_ppDocument createNewLayer];
}

- (IBAction) deleteLayerButtonPressed: (id) sender
{
    // end editing of layer name if necessary, otherwise the button's undoable action will
    // register before the layer name change registers (wrong order)
    [self endEditingForLayerNameText];

    [_ppDocument removeLayerAtIndex: [_ppDocument indexOfDrawingLayer]];
}

- (IBAction) duplicateLayerButtonPressed: (id) sender
{
    // end editing of layer name if necessary, otherwise the button's undoable action will
    // register before the layer name change registers (wrong order)
    [self endEditingForLayerNameText];

    [_ppDocument duplicateLayerAtIndex: [_ppDocument indexOfDrawingLayer]];
}

- (IBAction) layerBlendingModeButtonPressed: (id) sender
{
    [_ppDocument toggleLayerBlendingMode];
}

#pragma mark NSWindowController overrides

- (void) windowDidLoad
{
    [_layersTable setDataSource: self];
    [_layersTable setDelegate: self];

    [_layersTable registerForDraggedTypes:
                    [NSArray arrayWithObject: kLayersTableDraggedDataType]];

    _layerThumbnailMaxSize =
        NSMakeSize(
            [[_layersTable
                    tableColumnWithIdentifier: kLayersTableColumnIdentifier_Thumbnail] width],
            [_layersTable rowHeight] - 1.0f);

    _layerThumbnailDestinationRect.origin.y = 1.0f;

    _cachedDisabledLayerNameAttrStringsDict = [[NSMutableDictionary dictionary] retain];


    // [super windowDidLoad] may show & resize the panel, so call as late as possible
    [super windowDidLoad];


    [self handleResizedPanel];

    [self addAsObserverForPPLayerControlButtonImagesManagerNotifications];

    [self addAsObserverForPPLayersTableViewNotifications];
}

- (NSUndoManager *) undoManager
{
    return [_ppDocument undoManager];
}

#pragma mark PPPanelController overrides

+ controller
{
    PPLayersPanelController *layersPanelController = [super controller];

    // on rare occasions, seeing a hard-to-repro crash - the stack trace suggests that it
    // may be due to the unloaded layers panel, so forcing the window to load (for now)
    [layersPanelController window];

    return layersPanelController;
}

+ (NSString *) panelNibName
{
    return kLayersPanelNibName;
}

- (void) setPPDocument: (PPDocument *) ppDocument
{
    [super setPPDocument: ppDocument];

    if (!_ppDocument)
    {
        [self setupWithPPDocumentWindowController: nil];
    }
}

- (void) addAsObserverForPPDocumentNotifications
{
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];

    if (!_ppDocument)
        return;

    [notificationCenter addObserver: self
                        selector:
                            @selector(
                            handlePPDocumentNotification_UpdatedDrawingLayerThumbnailImage:)
                        name: PPDocumentNotification_UpdatedDrawingLayerThumbnailImage
                        object: _ppDocument];

    [notificationCenter addObserver: self
                        selector: @selector(handlePPDocumentNotification_SwitchedDrawingLayer:)
                        name: PPDocumentNotification_SwitchedDrawingLayer
                        object: _ppDocument];

    [notificationCenter addObserver: self
                        selector: @selector(handlePPDocumentNotification_ReorderedLayers:)
                        name: PPDocumentNotification_ReorderedLayers
                        object: _ppDocument];

    [notificationCenter addObserver: self
                        selector:
                        @selector(handlePPDocumentNotification_PerformedMultilayerOperation:)
                        name: PPDocumentNotification_PerformedMultilayerOperation
                        object: _ppDocument];

    [notificationCenter addObserver: self
                        selector: @selector(handlePPDocumentNotification_ChangedLayerAttribute:)
                        name: PPDocumentNotification_ChangedLayerAttribute
                        object: _ppDocument];

    [notificationCenter addObserver: self
                        selector:
                            @selector(handlePPDocumentNotification_SwitchedLayerOperationTarget:)
                        name: PPDocumentNotification_SwitchedLayerOperationTarget
                        object: _ppDocument];

    [notificationCenter addObserver: self
                        selector:
                            @selector(handlePPDocumentNotification_SwitchedLayerBlendingMode:)
                        name: PPDocumentNotification_SwitchedLayerBlendingMode
                        object: _ppDocument];

    [notificationCenter addObserver: self
                        selector:
                            @selector(handlePPDocumentNotification_UpdatedBackgroundSettings:)
                        name: PPDocumentNotification_UpdatedBackgroundSettings
                        object: _ppDocument];

    [notificationCenter addObserver: self
                        selector: @selector(handlePPDocumentNotification_ReloadedDocument:)
                        name: PPDocumentNotification_ReloadedDocument
                        object: _ppDocument];
}

- (void) removeAsObserverForPPDocumentNotifications
{
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];

    [notificationCenter removeObserver: self
                        name: PPDocumentNotification_UpdatedDrawingLayerThumbnailImage
                        object: _ppDocument];

    [notificationCenter removeObserver: self
                        name: PPDocumentNotification_SwitchedDrawingLayer
                        object: _ppDocument];

    [notificationCenter removeObserver: self
                        name: PPDocumentNotification_ReorderedLayers
                        object: _ppDocument];

    [notificationCenter removeObserver: self
                        name: PPDocumentNotification_PerformedMultilayerOperation
                        object: _ppDocument];

    [notificationCenter removeObserver: self
                        name: PPDocumentNotification_ChangedLayerAttribute
                        object: _ppDocument];

    [notificationCenter removeObserver: self
                        name: PPDocumentNotification_SwitchedLayerOperationTarget
                        object: _ppDocument];

    [notificationCenter removeObserver: self
                        name: PPDocumentNotification_SwitchedLayerBlendingMode
                        object: _ppDocument];

    [notificationCenter removeObserver: self
                        name: PPDocumentNotification_UpdatedBackgroundSettings
                        object: _ppDocument];

    [notificationCenter removeObserver: self
                        name: PPDocumentNotification_ReloadedDocument
                        object: _ppDocument];
}

- (bool) allowPanelToBecomeKey
{
    return YES;
}

- (bool) defaultPanelEnabledState
{
    return YES;
}

- (PPFramePinningType) pinningTypeForDefaultWindowFrame
{
    return kPPPanelDefaultFramePinning_Layers;
}

- (void) setupPanelForCurrentPPDocument
{
    [self setupWithPPDocumentWindowController: [_ppDocument ppDocumentWindowController]];

    [self updateCanvasDisplayMode];
    [self updateLayerOperationTarget];

    [self setupLayerThumbnailsCacheForCurrentPPDocument];

    [self destroyAllCachedDisabledLayerNameAttrStrings];

    [self reloadLayersTableDataAndUpdateSelection];

    [self updateLayerBlendingModeButtonWithCurrentMode];

    // [super setupPanelForCurrentPPDocument] may show the panel, so call as late as possible
    [super setupPanelForCurrentPPDocument];

    if (_needToUpdateLayerControlButtonImages && [self panelIsVisible])
    {
        [self updateLayerControlButtonImages];
    }
}

- (void) setupPanelBeforeMakingVisible
{
    [super setupPanelBeforeMakingVisible];

    if (_needToUpdateLayerControlButtonImages)
    {
        [self updateLayerControlButtonImages];
    }
}

#pragma mark NSWindow delegate methods

- (void) windowDidResize: (NSNotification *) notification
{
    [self handleResizedPanel];
}

- (void) windowDidBecomeKey: (NSNotification *) notification
{
    [self ppPerformSelectorFromNewStackFrame:
                                        @selector(resignKeyWindowUnlessEditingLayerNameText)];
}

- (NSUndoManager *) windowWillReturnUndoManager: (NSWindow *) window
{
    return [self undoManager];
}

#pragma mark PPDocument notifications

- (void) handlePPDocumentNotification_UpdatedDrawingLayerThumbnailImage:
                                                                (NSNotification *) notification
{
    unsigned layerIndex = [_ppDocument indexOfDrawingLayer];

    [self destroyCachedThumbnailForLayerAtIndex: layerIndex];

    [self reloadLayersTableThumbnailDataForLayerAtIndex: layerIndex];
}

- (void) handlePPDocumentNotification_SwitchedDrawingLayer: (NSNotification *) notification
{
    [self updateLayersTableSelection];
}

- (void) handlePPDocumentNotification_ReorderedLayers: (NSNotification *) notification
{
    [self destroyAllCachedLayerThumbnailsAndResizeCacheForCurrentPPDocument];

    [self reloadLayersTableDataAndUpdateSelection];
}

- (void) handlePPDocumentNotification_PerformedMultilayerOperation:
                                                            (NSNotification *) notification
{
    [self destroyAllCachedLayerThumbnailsAndResizeCacheForCurrentPPDocument];

    [self reloadLayersTableDataAndUpdateSelection];
}

- (void) handlePPDocumentNotification_ChangedLayerAttribute: (NSNotification *) notification
{
    NSDictionary *userInfo;
    NSNumber *layerIndexNumber;
    int layerIndex = -1;

    if (_ignoreNotificationForChangedLayerAttribute)
        return;

    userInfo = [notification userInfo];

    layerIndexNumber =
            [userInfo objectForKey: PPDocumentNotification_UserInfoKey_IndexOfChangedLayer];

    if (layerIndexNumber)
    {
        layerIndex = [layerIndexNumber intValue];
    }

    if (layerIndex >= 0)
    {
        [self reloadLayersTableDataForLayerAtIndex: layerIndex];
    }
    else
    {
        [_layersTable reloadData];
    }
}

- (void) handlePPDocumentNotification_SwitchedLayerOperationTarget:
                                                            (NSNotification *) notification
{
    [self updateLayerOperationTarget];
    [self updateLayerOperationTargetButtonImage];
}

- (void) handlePPDocumentNotification_SwitchedLayerBlendingMode: (NSNotification *) notification
{
    [self updateLayerBlendingModeButtonWithCurrentMode];
}

- (void) handlePPDocumentNotification_UpdatedBackgroundSettings: (NSNotification *) notification
{
    [self setupLayerThumbnailBackgroundBitmapForCurrentPPDocument];

    [self destroyAllCachedLayerThumbnails];

    [_layersTable reloadData];
}

- (void) handlePPDocumentNotification_ReloadedDocument: (NSNotification *) notification
{
    [self setupPanelForCurrentPPDocument];
}

#pragma mark PPDocumentWindowController notifications

- (void) addAsObserverForPPDocumentWindowControllerNotifications
{
    if (!_ppDocumentWindowController)
        return;

    [[NSNotificationCenter defaultCenter]
        addObserver: self
        selector:
            @selector(handlePPDocumentWindowControllerNotification_ChangedCanvasDisplayMode:)
        name: PPDocumentWindowControllerNotification_ChangedCanvasDisplayMode
        object: _ppDocumentWindowController];
}

- (void) removeAsObserverForPPDocumentWindowControllerNotifications
{
    [[NSNotificationCenter defaultCenter]
                        removeObserver: self
                        name: PPDocumentWindowControllerNotification_ChangedCanvasDisplayMode
                        object: _ppDocumentWindowController];
}

- (void) handlePPDocumentWindowControllerNotification_ChangedCanvasDisplayMode:
                                                                (NSNotification *) notification
{
    [self updateCanvasDisplayMode];
    [self updateCanvasDisplayModeButtonImage];
}

#pragma mark PPLayerControlButtonImagesManager notifications

- (void) addAsObserverForPPLayerControlButtonImagesManagerNotifications
{
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];

    [notificationCenter
        addObserver: self
        selector:
            @selector(
                handlePPLayerControlButtonImagesManagerNotification_ChangedDrawLayerImages:)
        name: PPLayerControlButtonImagesManagerNotification_ChangedDrawLayerImages
        object: nil];

    [notificationCenter
        addObserver: self
        selector:
            @selector(
                handlePPLayerControlButtonImagesManagerNotification_ChangedEnabledLayersImages:)
        name: PPLayerControlButtonImagesManagerNotification_ChangedEnabledLayersImages
        object: nil];
}

- (void) removeAsObserverForPPLayerControlButtonImagesManagerNotifications
{
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];

    [notificationCenter
                removeObserver: self
                name: PPLayerControlButtonImagesManagerNotification_ChangedDrawLayerImages
                object: nil];

    [notificationCenter
                removeObserver: self
                name: PPLayerControlButtonImagesManagerNotification_ChangedEnabledLayersImages
                object: nil];
}

- (void) handlePPLayerControlButtonImagesManagerNotification_ChangedDrawLayerImages:
                                                                (NSNotification *) notification
{
    if (!_ppDocument || ![self panelIsVisible])
    {
        _needToUpdateLayerControlButtonImages = YES;

        return;
    }

    if (_canvasDisplayMode == kPPLayerDisplayMode_DrawingLayerOnly)
    {
        [self updateCanvasDisplayModeButtonImage];
    }

    if (_layerOperationTarget == kPPLayerOperationTarget_DrawingLayerOnly)
    {
        [self updateLayerOperationTargetButtonImage];
    }
}

- (void) handlePPLayerControlButtonImagesManagerNotification_ChangedEnabledLayersImages:
                                                                (NSNotification *) notification
{
    if (!_ppDocument || ![self panelIsVisible])
    {
        _needToUpdateLayerControlButtonImages = YES;

        return;
    }

    if (_canvasDisplayMode != kPPLayerDisplayMode_DrawingLayerOnly)
    {
        [self updateCanvasDisplayModeButtonImage];
    }

    if (_layerOperationTarget != kPPLayerOperationTarget_DrawingLayerOnly)
    {
        [self updateLayerOperationTargetButtonImage];
    }
}

#pragma mark PPLayersTableView data source

- (NSInteger) numberOfRowsInTableView: (NSTableView *) aTableView
{
    return [_ppDocument numLayers];
}

- (id) tableView: (NSTableView *) tableView
        objectValueForTableColumn: (NSTableColumn *) tableColumn
        row: (NSInteger) row
{
    NSString *identifier;
    unsigned layerIndex;
    PPDocumentLayer *layer;

    if (tableView != _layersTable)
    {
        return nil;
    }

    identifier = [tableColumn identifier];

    layerIndex = [self layerIndexForTableRowIndex: row];

    if ([identifier isEqualToString: kLayersTableColumnIdentifier_Thumbnail])
    {
        return [self cachedThumbnailForLayerAtIndex: layerIndex];
    }

    layer = [_ppDocument layerAtIndex: layerIndex];

    if (!layer)
    {
        return nil;
    }

    if ([identifier isEqualToString: kLayersTableColumnIdentifier_Enabled])
    {
        return [NSNumber numberWithBool: [layer isEnabled]];
    }
    else if ([identifier isEqualToString: kLayersTableColumnIdentifier_Name])
    {
        NSString *layerName = [layer name];

        if ([layer isEnabled])
        {
            return layerName;
        }
        else
        {
            return [self cachedDisabledLayerNameAttrStringForLayerName: layerName];
        }
    }
    else if ([identifier isEqualToString: kLayersTableColumnIdentifier_Opacity])
    {
        return [NSNumber numberWithFloat: [layer opacity]];
    }
    else
    {
        return nil;
    }
}

- (void) tableView: (NSTableView *) tableView
            setObjectValue: (id) object
            forTableColumn: (NSTableColumn *) tableColumn
            row: (NSInteger) row
{
    PPDocumentLayer *layer;
    NSString *identifier;

    if (tableView != _layersTable)
    {
        return;
    }

    layer = [_ppDocument layerAtIndex: [self layerIndexForTableRowIndex: row]];

    if (!layer)
        return;

    identifier = [tableColumn identifier];

    _ignoreNotificationForChangedLayerAttribute = YES;

    if ([identifier isEqualToString: kLayersTableColumnIdentifier_Enabled])
    {
        [layer setEnabled: [object boolValue]];

        // switching a layer's enabled state also switches the way its name is drawn (different
        // text attributes), so force the row to redisplay so the layer's name redraws:
        [_layersTable setNeedsDisplayInRect: [_layersTable rectOfRow: row]];
    }
    else if ([identifier isEqualToString: kLayersTableColumnIdentifier_Name])
    {
        NSUndoManager *undoManager = [self undoManager];

        // Might be setting the layer name as the result of clicking a button that forces
        // editing to end before performing an additional undoable action (Layers panel buttons:
        // +, -, or Duplicate), so force the undo manager to group the name change as its own
        // undo grouping to prevent the actions from being merged (since they're both registered
        // under the same event).

        [undoManager setGroupsByEvent: NO];
        [undoManager beginUndoGrouping];

        [layer setName: object];

        [undoManager endUndoGrouping];
        [undoManager setGroupsByEvent: YES];
    }
    else if ([identifier isEqualToString: kLayersTableColumnIdentifier_Opacity])
    {
        [layer setOpacity: [object floatValue]];
    }

    _ignoreNotificationForChangedLayerAttribute = NO;
}

- (BOOL) tableView: (NSTableView *) tableView
            writeRowsWithIndexes: (NSIndexSet *) rowIndexes
            toPasteboard: (NSPasteboard*) pasteboard
{
    NSData *pasteboardData;

    pasteboardData = [NSKeyedArchiver archivedDataWithRootObject: rowIndexes];

    [pasteboard declareTypes: [NSArray arrayWithObject: kLayersTableDraggedDataType]
                owner: self];
    [pasteboard setData: pasteboardData forType: kLayersTableDraggedDataType];

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
    pasteboardData = [pasteboard dataForType: kLayersTableDraggedDataType];
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
    int sourceTableRow, oldLayerIndex, newLayerIndex;

    pboard = [info draggingPasteboard];
    rowData = [pboard dataForType: kLayersTableDraggedDataType];
    rowIndexes = [NSKeyedUnarchiver unarchiveObjectWithData: rowData];
    sourceTableRow = [rowIndexes firstIndex];

    oldLayerIndex = [self layerIndexForTableRowIndex: sourceTableRow];
    newLayerIndex = [self layerIndexForTableRowIndex: destinationTableRow];

    if (destinationTableRow > sourceTableRow)
    {
        newLayerIndex++;
    }

    [_ppDocument moveLayerAtIndex: oldLayerIndex toIndex: newLayerIndex];

    return YES;
}

#pragma mark PPLayersTableView delegate methods

- (void) tableViewSelectionDidChange: (NSNotification *) notification
{
    if (!_ppDocument || ![_ppDocument numLayers])
    {
        return;
    }

    if ([_layersTable numberOfSelectedRows] != 1)
    {
        [self updateLayersTableSelection];
    }
    else
    {
        [_ppDocument selectDrawingLayerAtIndex:
                            [self layerIndexForTableRowIndex: [_layersTable selectedRow]]];
    }
}

#pragma mark PPLayersTableView notifications

- (void) addAsObserverForPPLayersTableViewNotifications
{
    NSText *layersTableFieldEditor = [[self window] fieldEditor: YES forObject: _layersTable];

    if (!layersTableFieldEditor)
        return;

    [[NSNotificationCenter defaultCenter]
                            addObserver: self
                            selector:
                                @selector(handlePPLayersTableViewNotification_TextDidEndEditing:)
                            name: NSTextDidEndEditingNotification
                            object: layersTableFieldEditor];
}

- (void) removeAsObserverForPPLayersTableViewNotifications
{
    [[NSNotificationCenter defaultCenter]
                            removeObserver: self
                            name: NSTextDidEndEditingNotification
                            object: nil];
}

- (void) handlePPLayersTableViewNotification_TextDidEndEditing: (NSNotification *) notification
{
    [self ppPerformSelectorFromNewStackFrame:
                                        @selector(resignKeyWindowUnlessEditingLayerNameText)];
}

#pragma mark Layers table thumbnails

- (void) setupLayerThumbnailsCacheForCurrentPPDocument
{
    [self destroyAllCachedLayerThumbnailsAndResizeCacheForCurrentPPDocument];

    [self setupLayerThumbnailDrawMembersForCurrentPPDocument];

    [self setupLayerThumbnailBackgroundBitmapForCurrentPPDocument];
}

- (void) destroyLayerThumbnailsCache
{
    [self destroyAllCachedLayerThumbnails];
    [self destroyLayerThumbnailBackgroundBitmap];
}

- (void) destroyAllCachedLayerThumbnailsAndResizeCacheForCurrentPPDocument
{
    [self destroyAllCachedLayerThumbnails];

    _numCachedLayerThumbnails = [_ppDocument numLayers];
}

- (void) setupLayerThumbnailDrawMembersForCurrentPPDocument
{
    _layerThumbnailSourceRect.size = [_ppDocument canvasSize];
    _layerThumbnailDestinationRect.size =
        PPGeometry_ScaledBoundsForFrameOfSizeToFitFrameOfSize(_layerThumbnailSourceRect.size,
                                                                _layerThumbnailMaxSize).size;

    _layerThumbnailInterpolation =
        PPThumbUtils_ImageInterpolationForSourceRectToDestinationRect(
                                                                _layerThumbnailSourceRect,
                                                                _layerThumbnailDestinationRect);

}

- (NSImage *) cachedThumbnailForLayerAtIndex: (unsigned) index
{
    NSImage *thumbnailImage;

    if (index >= _numCachedLayerThumbnails)
    {
        goto ERROR;
    }

    thumbnailImage = _cachedLayerThumbnailImages[index];

    if (!thumbnailImage)
    {
        NSBitmapImageRep *thumbnailBitmap;
        NSImage *layerImage;

        layerImage = [[_ppDocument layerAtIndex: index] image];
        thumbnailBitmap = [[_layerThumbnailBackgroundBitmap copy] autorelease];

        if (!layerImage || !thumbnailBitmap)
        {
            goto ERROR;
        }

        [thumbnailBitmap ppSetAsCurrentGraphicsContext];

        [[NSGraphicsContext currentContext] setImageInterpolation: _layerThumbnailInterpolation];

        [layerImage drawInRect: _layerThumbnailDestinationRect
                    fromRect: _layerThumbnailSourceRect
                    operation: NSCompositeSourceOver
                    fraction: 1.0f];

        [thumbnailBitmap ppRestoreGraphicsContext];

        thumbnailImage = [NSImage ppImageWithBitmap: thumbnailBitmap];

        _cachedLayerThumbnailImages[index] = [thumbnailImage retain];
    }

    return thumbnailImage;

ERROR:
    return nil;
}

- (void) destroyCachedThumbnailForLayerAtIndex: (unsigned) index
{
    if (index >= _numCachedLayerThumbnails)
    {
        return;
    }

    [_cachedLayerThumbnailImages[index] release];
    _cachedLayerThumbnailImages[index] = nil;
}

- (void) destroyAllCachedLayerThumbnails
{
    NSImage **currentThumbnail = &_cachedLayerThumbnailImages[0];
    int thumbnailCounter = _numCachedLayerThumbnails;

    while (thumbnailCounter--)
    {
        if (*currentThumbnail)
        {
            [*currentThumbnail release];
            *currentThumbnail = nil;
        }

        currentThumbnail++;
    }
}

- (void) setupLayerThumbnailBackgroundBitmapForCurrentPPDocument
{
    PPBackgroundPattern *documentBackgroundPattern, *thumbnailBackgroundPattern;
    float patternScalingFactor;
    NSColor *thumbnailBackgroundPatternColor;
    NSSize backgroundImageSize;
    NSBitmapImageRep *backgroundBitmap;

    [self destroyLayerThumbnailBackgroundBitmap];

    if (!_ppDocument || NSIsEmptyRect(_layerThumbnailSourceRect))
    {
        goto ERROR;
    }

    documentBackgroundPattern = [_ppDocument backgroundPattern];

    patternScalingFactor = kScalingFactorForThumbnailBackgroundPatternSize
                                * _layerThumbnailDestinationRect.size.width
                                / _layerThumbnailSourceRect.size.width;

    if (patternScalingFactor > 1.0f)
    {
        patternScalingFactor = 1.0f;
    }

    thumbnailBackgroundPattern =
            [documentBackgroundPattern backgroundPatternScaledByFactor: patternScalingFactor];

    thumbnailBackgroundPatternColor = [thumbnailBackgroundPattern patternFillColor];

    if (!thumbnailBackgroundPatternColor)
        goto ERROR;

    backgroundImageSize.width = _layerThumbnailDestinationRect.size.width;
    backgroundImageSize.height = NSMaxY(_layerThumbnailDestinationRect);

    if (PPGeometry_IsZeroSize(backgroundImageSize))
    {
        goto ERROR;
    }

    backgroundBitmap = [NSBitmapImageRep ppImageBitmapOfSize: backgroundImageSize];

    if (!backgroundBitmap)
        goto ERROR;

    [backgroundBitmap ppSetAsCurrentGraphicsContext];

    [thumbnailBackgroundPatternColor set];
    NSRectFill(_layerThumbnailDestinationRect);

    [backgroundBitmap ppRestoreGraphicsContext];

    _layerThumbnailBackgroundBitmap = [backgroundBitmap retain];

    return;

ERROR:
    return;
}

- (void) destroyLayerThumbnailBackgroundBitmap
{
    [_layerThumbnailBackgroundBitmap release];
    _layerThumbnailBackgroundBitmap = nil;
}

#pragma mark Layers table disabled layer titles

- (id) cachedDisabledLayerNameAttrStringForLayerName: (NSString *) layerName
{
    id disabledLayerName;

    if (!layerName)
    {
        layerName = @"";
    }

    disabledLayerName = [_cachedDisabledLayerNameAttrStringsDict objectForKey: layerName];

    if (!disabledLayerName)
    {
        disabledLayerName =
            [[[NSAttributedString alloc] initWithString: layerName
                                            attributes:
                                                    PPTextAttributesDict_DisabledTitle_Table()]
                                    autorelease];

        if (disabledLayerName)
        {
            [_cachedDisabledLayerNameAttrStringsDict setObject: disabledLayerName
                                                        forKey: layerName];
        }
        else
        {
            disabledLayerName = layerName;
        }
    }

    return disabledLayerName;
}

- (void) destroyAllCachedDisabledLayerNameAttrStrings
{
    [_cachedDisabledLayerNameAttrStringsDict removeAllObjects];
}

#pragma mark Panel content view mouse tracking

- (void) setupTrackingRectForPanelContentView: (NSView *) panelContentView
{
    if (_panelContentViewTrackingRectTag)
    {
        [panelContentView removeTrackingRect: _panelContentViewTrackingRectTag];
    }

    _panelContentViewTrackingRectTag =
                                [panelContentView addTrackingRect: [panelContentView bounds]
                                                    owner: self
                                                    userData: nil
                                                    assumeInside: _mouseIsInsideTrackingRect];
}

- (void) mouseEntered: (NSEvent *) theEvent
{
    NSTrackingRectTag trackingRectTag = [theEvent trackingNumber];

    if (trackingRectTag == _panelContentViewTrackingRectTag)
    {
        _mouseIsInsideTrackingRect = YES;
    }
    else
    {
        [super mouseEntered: theEvent];
    }
}

- (void) mouseExited: (NSEvent *) theEvent
{
    NSTrackingRectTag trackingRectTag = [theEvent trackingNumber];

    if (trackingRectTag == _panelContentViewTrackingRectTag)
    {
        if (_mouseIsInsideTrackingRect)
        {
            _mouseIsInsideTrackingRect = NO;

            [_ppDocument ppMakeWindowKey];
        }
    }
    else
    {
        [super mouseExited: theEvent];
    }
}

#pragma mark Private methods

- (void) handleResizedPanel
{
    NSView *panelContentView = [[self window] contentView];

    [self resizeLayerControlButtonsForPanelContentWidth: [panelContentView bounds].size.width];

    [self setupTrackingRectForPanelContentView: panelContentView];
}

- (void) resizeLayerControlButtonsForPanelContentWidth: (float) contentWidth
{
    float halfContentWidth, displayModeButtonFrameWidth, operationTargetButtonFrameWidth;
    NSRect currentButtonFrame, newButtonFrame;

    halfContentWidth = contentWidth / 2.0f;

    displayModeButtonFrameWidth = floorf(halfContentWidth) + 1.0f;
    operationTargetButtonFrameWidth = ceilf(halfContentWidth) + 1.0f;

    currentButtonFrame = [_canvasDisplayModeButton frame];
    newButtonFrame = currentButtonFrame;
    newButtonFrame.size.width = displayModeButtonFrameWidth;
    newButtonFrame.origin.x = 0.0f;

    if (!NSEqualRects(currentButtonFrame, newButtonFrame))
    {
        [_canvasDisplayModeButton setFrame: newButtonFrame];
    }

    currentButtonFrame = [_layerOperationTargetButton frame];
    newButtonFrame = currentButtonFrame;
    newButtonFrame.size.width = operationTargetButtonFrameWidth;
    newButtonFrame.origin.x = contentWidth - newButtonFrame.size.width;

    if (!NSEqualRects(currentButtonFrame, newButtonFrame))
    {
        [_layerOperationTargetButton setFrame: newButtonFrame];
    }
}

- (void) setupWithPPDocumentWindowController:
                                    (PPDocumentWindowController *) ppDocumentWindowController
{
    if (_ppDocumentWindowController == ppDocumentWindowController)
    {
        return;
    }

    if (_ppDocumentWindowController)
    {
        [self removeAsObserverForPPDocumentWindowControllerNotifications];
    }

    [_ppDocumentWindowController release];
    _ppDocumentWindowController = [ppDocumentWindowController retain];

    if (_ppDocumentWindowController)
    {
        [self addAsObserverForPPDocumentWindowControllerNotifications];
    }
}

- (void) updateCanvasDisplayMode
{
    _canvasDisplayMode = [_ppDocumentWindowController canvasDisplayMode];

    if (_canvasDisplayMode != kPPLayerDisplayMode_DrawingLayerOnly)
    {
        _canvasDisplayMode = kPPLayerDisplayMode_VisibleLayers;
    }
}

- (void) updateLayerOperationTarget
{
    _layerOperationTarget = [_ppDocument layerOperationTarget];

    if (_layerOperationTarget != kPPLayerOperationTarget_DrawingLayerOnly)
    {
        _layerOperationTarget = kPPLayerOperationTarget_VisibleLayers;
    }
}

- (void) updateCanvasDisplayModeButtonImage
{
    NSImage *buttonImage =
                [[PPLayerControlButtonImagesManager sharedManager]
                                                buttonImageForDisplayMode: _canvasDisplayMode];

    // button's current image may already be buttonImage, so force redraw by clearing the image
    // first
    [_canvasDisplayModeButton setImage: nil];
    [_canvasDisplayModeButton setImage: buttonImage];
}

- (void) updateLayerOperationTargetButtonImage
{
    NSImage *buttonImage =
                [[PPLayerControlButtonImagesManager sharedManager]
                                        buttonImageForOperationTarget: _layerOperationTarget];

    // button's current image may already be buttonImage, so force redraw by clearing the image
    // first
    [_layerOperationTargetButton setImage: nil];
    [_layerOperationTargetButton setImage: buttonImage];
}

- (void) updateLayerControlButtonImages
{
    [self updateCanvasDisplayModeButtonImage];
    [self updateLayerOperationTargetButtonImage];

    _needToUpdateLayerControlButtonImages = NO;
}

- (void) updateLayerBlendingModeButtonWithCurrentMode
{
    [_layerBlendingModeButton setLayerBlendingMode: [_ppDocument layerBlendingMode]];
}

- (void) reloadLayersTableDataAndUpdateSelection
{
    [_layersTable reloadData];

    [self updateLayersTableSelection];
}

- (void) reloadLayersTableDataForLayerAtIndex: (unsigned) layerIndex
{
    NSRect updateRect;

    updateRect = [_layersTable rectOfRow: [self tableRowIndexForLayerIndex: layerIndex]];

    if (NSIsEmptyRect(updateRect))
    {
        return;
    }

    [_layersTable setNeedsDisplayInRect: updateRect];
}

- (void) reloadLayersTableThumbnailDataForLayerAtIndex: (unsigned) layerIndex
{
    NSRect updateRect;

    updateRect = [_layersTable frameOfCellAtColumn: kLayersTableColumnIndex_Thumbnail
                                row: [self tableRowIndexForLayerIndex: layerIndex]];

    if (NSIsEmptyRect(updateRect))
    {
        return;
    }

    [_layersTable setNeedsDisplayInRect: updateRect];
}

- (void) updateLayersTableSelection
{
    if ([_ppDocument numLayers])
    {
        unsigned int rowOfDrawingLayer;

        rowOfDrawingLayer = [self tableRowIndexForLayerIndex: [_ppDocument indexOfDrawingLayer]];

        [_layersTable selectRowIndexes: [NSIndexSet indexSetWithIndex: rowOfDrawingLayer]
                        byExtendingSelection: NO];
    }
    else
    {
        [_layersTable deselectAll: self];
    }
}

- (unsigned) tableRowIndexForLayerIndex: (unsigned) layerIndex
{
    return [_ppDocument numLayers] - 1 - layerIndex;
}

- (unsigned) layerIndexForTableRowIndex: (unsigned) rowIndex
{
    return [_ppDocument numLayers] - 1 - rowIndex;
}

- (bool) isEditingLayerNameText
{
    NSWindow *layersPanel;
    NSText *layersTableFieldEditor;

    layersPanel = [self window];

    if (![layersPanel isKeyWindow])
    {
        return NO;
    }

    layersTableFieldEditor = [layersPanel fieldEditor: NO forObject: _layersTable];

    if (!layersTableFieldEditor)
    {
        return NO;
    }

    return (layersTableFieldEditor == [layersPanel firstResponder]) ? YES : NO;
}

- (void) endEditingForLayerNameText
{
    if ([self isEditingLayerNameText])
    {
        [[self window] endEditingFor: _layersTable];
    }
}

- (void) resignKeyWindowUnlessEditingLayerNameText
{
    if ([[self window] isKeyWindow] && ![self isEditingLayerNameText])
    {
        [_ppDocument ppMakeWindowKey];
    }
}

@end
