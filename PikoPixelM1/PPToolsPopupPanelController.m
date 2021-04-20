/*
    PPToolsPopupPanelController.m

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

#import "PPToolsPopupPanelController.h"

#import "PPToolButtonMatrix.h"
#import "PPDocument.h"
#import "PPUIColors_Panels.h"
#import "PPPopupPanelActionKeys.h"


#define kToolsPopupPanelNibName  @"ToolsPopupPanel"


@interface PPToolsPopupPanelController (PrivateMethods)

- (void) handlePPDocumentNotification_SwitchedActiveTool: (NSNotification *) notification;

- (void) updateToolButtonMatrix;

@end

@implementation PPToolsPopupPanelController

#pragma mark Actions

- (IBAction) toolButtonMatrixClicked: (id) sender
{
    [_ppDocument setSelectedToolType: [_toolButtonMatrix toolTypeOfSelectedCell]];
}

#pragma mark PPPopupPanelController overrides

+ (NSString *) panelNibName
{
    return kToolsPopupPanelNibName;
}

- (void) addAsObserverForPPDocumentNotifications
{
    if (!_ppDocument)
        return;

    [[NSNotificationCenter defaultCenter]
                                addObserver: self
                                selector:
                                    @selector(handlePPDocumentNotification_SwitchedActiveTool:)
                                name: PPDocumentNotification_SwitchedActiveTool
                                object: _ppDocument];
}

- (void) removeAsObserverForPPDocumentNotifications
{
    [[NSNotificationCenter defaultCenter] removeObserver: self
                                            name: PPDocumentNotification_SwitchedActiveTool
                                            object: _ppDocument];
}

- (void) setupPanelForCurrentPPDocument
{
    [super setupPanelForCurrentPPDocument];

    [self updateToolButtonMatrix];
}

- (NSColor *) backgroundColorForPopupPanel
{
    return kUIColor_ToolsPopupPanel_Background;
}

- (bool) handleActionKey: (NSString *) key
{
    if ([key isEqualToString: kToolsPopupPanelActionKey_SelectLastTool])
    {
        [_ppDocument setSelectedToolTypeToLastSelectedType];

        return YES;
    }

    return NO;
}

- (void) handleDirectionCommand: (PPDirectionType) directionType
{
    NSInteger numRows, numCols, cellRow, cellCol;
    NSCell *highlightedCell;

    [_toolButtonMatrix getNumberOfRows: &numRows columns: &numCols];

    highlightedCell = [_toolButtonMatrix highlightedCell];

    if (!highlightedCell
        || ![_toolButtonMatrix getRow: &cellRow column: &cellCol ofCell: highlightedCell])
    {
        goto ERROR;
    }

    switch (directionType)
    {
        case kPPDirectionType_Left:
        {
            if (--cellCol < 0)
            {
                cellCol = numCols - 1;
            }
        }
        break;

        case kPPDirectionType_Right:
        {
            if (++cellCol >= numCols)
            {
                cellCol = 0;
            }
        }
        break;

        case kPPDirectionType_Up:
        {
            if (--cellRow < 0)
            {
                cellRow = numRows - 1;
            }
        }
        break;

        case kPPDirectionType_Down:
        {
            if (++cellRow >= numRows)
            {
                cellRow = 0;
            }
        }
        break;

        default:
        {
            goto ERROR;
        }
        break;
    }

    [_ppDocument setSelectedToolType:
                            [_toolButtonMatrix toolTypeOfCellAtRow: cellRow column: cellCol]];

    return;

ERROR:
    return;
}

#pragma mark PPDocument notifications

- (void) handlePPDocumentNotification_SwitchedActiveTool: (NSNotification *) notification
{
    [self updateToolButtonMatrix];
}

#pragma mark Private methods

- (void) updateToolButtonMatrix
{
    [_toolButtonMatrix highlightCellWithToolType: [_ppDocument activeToolType]];
}

@end
