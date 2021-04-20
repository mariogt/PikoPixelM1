/*
    PPOptional.h

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

// Modify __ENABLE_ defines below to enable/disable optional PikoPixel functionality:

#define PP_OPTIONAL__ENABLE_SCREENCASTING               (true)

#define PP_OPTIONAL__ENABLE_CANVAS_SPEED_CHECK          (false)


// __BUILD_WITH_ defines are derived from __ENABLE_ flags and build-environment requirements

#define PP_OPTIONAL__BUILD_WITH_SCREENCASTING           \
            (PP_OPTIONAL__ENABLE_SCREENCASTING)

#define PP_OPTIONAL__BUILD_WITH_CANVAS_SPEED_CHECK      \
            (PP_OPTIONAL__ENABLE_CANVAS_SPEED_CHECK)


// Screencasting functionality requires ObjC runtime API version 2

#define PP_RUNTIME_CHECK_OPTIONAL__RUNTIME_SUPPORTS_SCREENCASTING               \
            (PP_RUNTIME_CHECK__RUNTIME_SUPPORTS_OBJC_RUNTIME_API_VERSION_2)
