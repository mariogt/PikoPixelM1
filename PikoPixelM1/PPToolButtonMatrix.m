/*
    PPToolButtonMatrix.m

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

#import "PPToolButtonMatrix.h"

#import "NSColor_PPUtilities.h"
#import "PPUIColors_Panels.h"


@implementation PPToolButtonMatrix

- (void) dealloc
{
    [_activeToolCellColor release];
    [_inactiveToolCellColor release];

    [super dealloc];
}

- (void) highlightCellWithToolType: (PPToolType) toolType
{
    NSButtonCell *cellToHighlight;

    if (toolType == kPPToolType_ColorRamp)
    {
        toolType = kPPToolType_Line;
    }

    cellToHighlight = [self cellWithTag: (NSInteger) toolType];

    if (_highlightedCell != cellToHighlight)
    {
        [_highlightedCell setBackgroundColor: _inactiveToolCellColor];

        [cellToHighlight setBackgroundColor: _activeToolCellColor];

        [self selectCell: cellToHighlight];

        _highlightedCell = cellToHighlight;
    }
}

- (NSButtonCell *) highlightedCell
{
    return _highlightedCell;
}

- (PPToolType) toolTypeOfSelectedCell
{
    return [self toolTypeOfCell: [self selectedCell]];
}

- (PPToolType) toolTypeOfCellAtRow: (NSInteger) row column: (NSInteger) col
{
    return [self toolTypeOfCell: [self cellAtRow: row column: col]];
}

- (PPToolType) toolTypeOfCell: (NSCell *) cell
{
    if (!cell)
        goto ERROR;

    return (PPToolType) [cell tag];

ERROR:
    // return invalid PPToolType value
    return (PPToolType) -1;
}

#pragma mark NSMatrix overrides

- (void) awakeFromNib
{
    // check before calling [super awakeFromNib] - before 10.6, some classes didn't implement it
    if ([[PPToolButtonMatrix superclass] instancesRespondToSelector: @selector(awakeFromNib)])
    {
        [super awakeFromNib];
    }

    _activeToolCellColor =
        [[NSColor ppCenteredVerticalGradientPatternColorWithHeight: [self cellSize].height
                            innerColor: kUIColor_ToolsPanel_ActiveToolCellGradientInnerColor
                            outerColor: kUIColor_ToolsPanel_ActiveToolCellGradientOuterColor]
                retain];

    _inactiveToolCellColor = [kUIColor_ToolsPanel_InactiveToolCellColor retain];

    [[self cells] makeObjectsPerformSelector: @selector(setBackgroundColor:)
                    withObject: _inactiveToolCellColor];

    [self deselectAllCells];
}

@end
