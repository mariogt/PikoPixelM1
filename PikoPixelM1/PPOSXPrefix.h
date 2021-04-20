/*
    PPOSXPrefix.h

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

#ifdef __APPLE__

#   import "PPXCConfigCheck.h"

//  Disable clang warnings that are now enabled by default on recent Xcode versions

#   if (defined(__clang__) && _PP_MAC_OS_X_SDK_VERSION_IS_AT_LEAST_10_(11))
#       pragma clang diagnostic ignored "-Wnonnull"
#       pragma clang diagnostic ignored "-Wshorten-64-to-32"
#       pragma clang diagnostic ignored "-Wundeclared-selector"
#   endif

#endif  // __APPLE__
