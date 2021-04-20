/*
    NSWindow_PPUtilities.m

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

#import "NSWindow_PPUtilities.h"

#import "PPGeometry.h"
#import "NSBitmapImageRep_PPUtilities.h"
#import "NSImage_PPUtilities.h"


#if !PP_SDK_HAS_NSWINDOWANIMATION

#   define NSWindowAnimationBehaviorNone    2

@interface NSWindow (SetAnimationBehaviorMethodForLegacySDKs)

- (void) setAnimationBehavior: (NSInteger) animationBehavior;

@end

#endif // !PP_SDK_HAS_NSWINDOWANIMATION

@implementation NSWindow (PPUtilities)

- (void) ppMakeKeyWindowIfMain
{
    if ([self isMainWindow] && ![self isKeyWindow] && ![NSApp modalWindow])
    {
        [self makeKeyWindow];
    }
}

- (void) ppSetDocumentWindowTitlebarIcon: (NSImage *) iconImage
{
    NSButton *titlebarIconButton;
    NSSize buttonImageSize;
    NSBitmapImageRep *buttonBitmap = nil;
    NSImage *buttonImage = nil;

    titlebarIconButton = [self standardWindowButton: NSWindowDocumentIconButton];

    if (!titlebarIconButton)
        return;

    buttonImageSize = [titlebarIconButton bounds].size;

    if (iconImage)
    {
        buttonBitmap = [NSBitmapImageRep ppImageBitmapOfSize: buttonImageSize];
    }

    if (buttonBitmap)
    {
        NSRect iconImageFrame, buttonBoundsForIconImage;

        iconImageFrame = PPGeometry_OriginRectOfSize([iconImage size]);

        buttonBoundsForIconImage =
            PPGeometry_ScaledBoundsForFrameOfSizeToFitFrameOfSize(iconImageFrame.size,
                                                                    buttonImageSize);

        if (!NSIsEmptyRect(buttonBoundsForIconImage))
        {
            [buttonBitmap ppSetAsCurrentGraphicsContext];

            [[NSGraphicsContext currentContext]
                                        setImageInterpolation: NSImageInterpolationHigh];

            [iconImage drawInRect: buttonBoundsForIconImage
                        fromRect: iconImageFrame
                        operation: NSCompositeCopy
                        fraction: 1.0f];

            [buttonBitmap ppRestoreGraphicsContext];
        }

        buttonImage = [NSImage ppImageWithBitmap: buttonBitmap];
    }

    [titlebarIconButton setImage: buttonImage];
}

- (void) ppDisableWindowAnimation
{
    static bool needToCheckSetAnimationBehaviorSelector = YES,
                setAnimationBehaviorSelectorIsSupported = NO;

    if (needToCheckSetAnimationBehaviorSelector)
    {
        setAnimationBehaviorSelectorIsSupported =
            ([NSWindow instancesRespondToSelector: @selector(setAnimationBehavior:)]) ? YES : NO;

        needToCheckSetAnimationBehaviorSelector = NO;
    }

    if (setAnimationBehaviorSelectorIsSupported)
    {
        [self setAnimationBehavior: NSWindowAnimationBehaviorNone];
    }
}

@end
