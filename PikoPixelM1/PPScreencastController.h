/*
    PPScreencastController.h

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

#import "PPOptional.h"
#if PP_OPTIONAL__BUILD_WITH_SCREENCASTING

#import <Cocoa/Cocoa.h>


#define kScreencastEventsMask                       (NSLeftMouseDownMask        \
                                                    | NSLeftMouseUpMask         \
                                                    | NSKeyDownMask             \
                                                    | NSKeyUpMask               \
                                                    | NSFlagsChangedMask)

#define kScreencastMaxSimultaneousKeysAllowed       4


@class PPScreencastPopupPanelController;

@interface PPScreencastController : NSObject
{
    PPScreencastPopupPanelController *_screencastPopupController;

    unichar _keysDown[kScreencastMaxSimultaneousKeysAllowed];
    unsigned _numKeysDown;

    unsigned _currentModifierFlags;

    bool _screencastingIsEnabled;
    bool _mouseIsDown;
}

+ (PPScreencastController *) sharedController;

- (void) setEnabled: (bool) enableScreencasting;

- (void) handleEvent: (NSEvent *) event;

@end

#endif  // PP_OPTIONAL__BUILD_WITH_SCREENCASTING
