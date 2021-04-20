/*
    PPLineTool.h

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

#import "PPTool.h"


@interface PPLineTool : PPTool
{
    NSBezierPath *_drawPath;

    NSPoint _segmentStartPoint;
    NSPoint _segmentEndPoint;

    int _numSegments;

    bool _shouldFillDrawPath;

    bool _modifierKeyDown_NewSegment;
    bool _modifierKeyDown_DeleteSegment;

#if PP_DEPLOYMENT_TARGET_ALLOWS_SYSTEM_INTERCEPTION_OF_COMMAND_KEY

    bool _commandKeyIsPressed;
    bool _disallowDeleteSegment;

#endif
}

@end
