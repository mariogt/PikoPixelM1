/*
    PPDocumentResizeSheetController.m

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

#import "PPDocumentResizeSheetController.h"

#import "PPDefines.h"
#import "NSTextField_PPUtilities.h"


#define kDocumentResizeSheetNibName   @"DocumentResizeSheet"


@interface PPDocumentResizeSheetController (PrivateMethods)

- initWithCurrentImageSize: (NSSize) currentImageSize andDelegate: (id) delegate;

@end


#if PP_SDK_REQUIRES_PROTOCOLS_FOR_DELEGATES_AND_DATASOURCES

@interface PPDocumentResizeSheetController (RequiredProtocols) <NSTextFieldDelegate>
@end

#endif  // PP_SDK_REQUIRES_PROTOCOLS_FOR_DELEGATES_AND_DATASOURCES


@implementation PPDocumentResizeSheetController

+ (bool) beginResizeSheetForDocumentWindow: (NSWindow *) window
            currentImageSize: (NSSize) currentImageSize
            delegate: (id) delegate
{
    PPDocumentResizeSheetController *controller;

    controller = [[[self alloc] initWithCurrentImageSize: currentImageSize
                                andDelegate: delegate]
                            autorelease];

    if (![controller beginSheetModalForWindow: window])
    {
        goto ERROR;
    }

    return YES;

ERROR:
    return NO;
}

- initWithCurrentImageSize: (NSSize) currentImageSize andDelegate: (id) delegate
{
    self = [super initWithNibNamed: kDocumentResizeSheetNibName delegate: delegate];

    if (!self)
        goto ERROR;

    _widthTextFieldValue = currentImageSize.width;
    [_widthTextField setIntValue: _widthTextFieldValue];
    [_widthTextField setDelegate: self];

    _heightTextFieldValue = currentImageSize.height;
    [_heightTextField setIntValue: _heightTextFieldValue];
    [_heightTextField setDelegate: self];

    return self;

ERROR:
    [self release];

    return nil;
}

- init
{
    return [self initWithCurrentImageSize: NSZeroSize andDelegate: nil];
}

#pragma mark PPDocumentSheetController overrides (delegate notifiers)

- (void) notifyDelegateSheetDidFinish
{
    if ([_delegate respondsToSelector:
                        @selector(documentResizeSheetDidFinishWithNewImageSize:shouldScale:)])
    {
        NSSize newImageSize = NSMakeSize(_widthTextFieldValue, _heightTextFieldValue);
        bool shouldScale = [_shouldScaleCheckbox intValue] ? YES : NO;

        [_delegate documentResizeSheetDidFinishWithNewImageSize: newImageSize
                                                shouldScale: shouldScale];
    }
}

- (void) notifyDelegateSheetDidCancel
{
    if ([_delegate respondsToSelector: @selector(documentResizeSheetDidCancel)])
    {
        [_delegate documentResizeSheetDidCancel];
    }
}

#pragma mark NSTextField delegate methods (width/height textfields)

- (void) controlTextDidChange: (NSNotification *) notification
{
    id notifyingObject = [notification object];

    if (notifyingObject == _widthTextField)
    {
        _widthTextFieldValue = [_widthTextField ppClampIntValueToMax: kMaxCanvasDimension
                                                    min: kMinCanvasDimension
                                                    defaultValue: _widthTextFieldValue];
    }
    else if (notifyingObject == _heightTextField)
    {
        _heightTextFieldValue = [_heightTextField ppClampIntValueToMax: kMaxCanvasDimension
                                                    min: kMinCanvasDimension
                                                    defaultValue: _heightTextFieldValue];
    }
}

@end
