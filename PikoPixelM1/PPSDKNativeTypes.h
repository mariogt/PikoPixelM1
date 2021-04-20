/*
    PPSDKNativeTypes.h

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

#import <Cocoa/Cocoa.h>


// NSInteger: Undefined in old SDKs

#ifndef NSINTEGER_DEFINED

    typedef int NSInteger;
    typedef unsigned int NSUInteger;

#   define NSINTEGER_DEFINED 1

#endif  // NSINTEGER_DEFINED


// CGFloat: Undefined in old SDKs

#ifndef CGFLOAT_DEFINED

    typedef float CGFloat;

#   define CGFLOAT_DEFINED 1

#endif  // CGFLOAT_DEFINED


// PPSDKNativeType_NSMenuItemPtr: SDKs where the NSMenuItem protocol is deprecated use the
// type (NSMenuItem *) when passing menu items for method parameters & return values, but
// old SDKs where the protocol is supported use the type (id <NSMenuItem>)

#if PP_SDK_DEPRECATED_NSMENUITEM_PROTOCOL

    typedef NSMenuItem *PPSDKNativeType_NSMenuItemPtr;

#else   // !PP_SDK_DEPRECATED_NSMENUITEM_PROTOCOL

    typedef id <NSMenuItem> PPSDKNativeType_NSMenuItemPtr;

#endif  // PP_SDK_DEPRECATED_NSMENUITEM_PROTOCOL


// PPSDKNativeType_NSWindowStyleMask: Mac SDK versions 10.12 & later define NSWindowStyleMask
// as a type, and the styleMask parameter for -[NSWindow initWithContentRect:...] uses the new
// type; On older SDKs, the method's styleMask parameter is an NSUInteger

#if PP_SDK_HAS_NSWINDOWSTYLEMASK_TYPE

    typedef NSWindowStyleMask PPSDKNativeType_NSWindowStyleMask;

#else   // !PP_SDK_HAS_NSWINDOWSTYLEMASK_TYPE

    typedef NSUInteger PPSDKNativeType_NSWindowStyleMask;

#endif  // PP_SDK_HAS_NSWINDOWSTYLEMASK_TYPE
