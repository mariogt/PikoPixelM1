/*
    PPDocument_ActiveTool.m

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

#import "PPDocument.h"

#import "PPDocument_Notifications.h"
#import "PPToolbox.h"


@implementation PPDocument (ActiveTool)

- (void) setSelectedToolType: (PPToolType) toolType
{
    if (!PPToolType_IsValid(toolType) || (toolType == _selectedToolType))
    {
        return;
    }

    _lastSelectedToolType = _selectedToolType;
    _selectedToolType = toolType;

    [self postNotification_SwitchedSelectedTool];
}

- (void) setSelectedToolTypeToLastSelectedType
{
    [self setSelectedToolType: _lastSelectedToolType];
}

- (PPToolType) selectedToolType
{
    return _selectedToolType;
}

- (void) setActiveToolType: (PPToolType) toolType
{
    if (!PPToolType_IsValid(toolType) || (toolType == _activeToolType))
    {
        return;
    }

    _activeTool = [[PPToolbox sharedToolbox] toolOfType: toolType];
    _activeToolType = toolType;

    [self postNotification_SwitchedActiveTool];
}

- (PPToolType) activeToolType
{
    return _activeToolType;
}

- (PPTool *) activeTool
{
    return _activeTool;
}

@end
