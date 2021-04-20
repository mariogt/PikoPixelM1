/*
    PPDocumentAnimationFileNoticeSheetController.m

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

#import "PPDocumentAnimationFileNoticeSheetController.h"


#define kAnimationFileAlertMessageText                                                      \
                    @"Warning: This file contains an animation with multiple images, "      \
                    "however, only the first image was loaded, because PikoPixel "          \
                    "currently only supports single-image editing.\n\nIf this image is "    \
                    "later saved at the current file's location, the unloaded animation "   \
                    "images will be overwritten (removed).\n\nTo preserve the animation "   \
                    "in the original file, choose a new save location for the edited image."

#define kAnimationFileAlertInformativeText              @""

#define kAnimationFileAlertDefaultButtonText            @"Choose a new save location..."
#define kAnimationFileAlertAlternateButtonText          @"Use the current save location"

#define kChooseNewSaveLocationReturnCode                NSAlertFirstButtonReturn


@interface PPDocumentAnimationFileNoticeSheetController (PrivateMethods)

- initWithDelegate: (id) delegate;

- (bool) beginAlertModalForWindow: (NSWindow *) window;

- (void) notifyDelegateSheetDidFinishAndShouldChangeSaveLocation:
                                                            (bool) shouldChangeSaveLocation;

@end

@implementation PPDocumentAnimationFileNoticeSheetController

+ (bool) beginAnimationFileNoticeSheetForDocumentWindow: (NSWindow *) window
            delegate: (id) delegate
{
    PPDocumentAnimationFileNoticeSheetController *controller;

    controller = [[[self alloc] initWithDelegate: delegate] autorelease];

    if (![controller beginAlertModalForWindow: window])
    {
        goto ERROR;
    }

    return YES;

ERROR:
    return NO;
}

- initWithDelegate: (id) delegate
{
    NSAlert *alert;
    
    self = [super init];

    if (!self)
        goto ERROR;

    if (!delegate)
        goto ERROR;
    
    alert = [[[NSAlert alloc] init] autorelease];
    alert.messageText = NSLocalizedString(kAnimationFileAlertMessageText, nil);
    alert.buttons.firstObject.title = NSLocalizedString(kAnimationFileAlertDefaultButtonText, nil);
    alert.informativeText = kAnimationFileAlertInformativeText;

    /*alert = [NSAlert alertWithMessageText: kAnimationFileAlertMessageText
                        defaultButton: kAnimationFileAlertDefaultButtonText
                        alternateButton: kAnimationFileAlertAlternateButtonText
                        otherButton: @""
                        informativeTextWithFormat: kAnimationFileAlertInformativeText];*/

    if (!alert)
        goto ERROR;

    _delegate = delegate;
    _alert = [alert retain];

    return self;

ERROR:
    [self release];

    return nil;
}

- init
{
    return [self initWithDelegate: nil];
}

- (void) dealloc
{
    [_alert release];

    [super dealloc];
}

#pragma mark NSAlert sheet modal

- (bool) beginAlertModalForWindow: (NSWindow *) window;
{
    if (![window isVisible] || [[_alert window] isVisible])
    {
        goto ERROR;
    }

    /*[_alert beginSheetModalForWindow: window
            modalDelegate: self
            didEndSelector: @selector(alertDidEnd:returnCode:contextInfo:)
            contextInfo: NULL];*/
    
    //check
    [_alert.window beginSheet: window completionHandler:^(NSInteger result) {
        //if (result == 1) NSLog(@"1");
        //if (result == 0) NSLog(@"0");
    }];

    [self retain];

    return YES;

ERROR:
    return NO;
}

- (void) alertDidEnd: (NSAlert *) alert
            returnCode: (int) returnCode
            contextInfo: (void *) contextInfo
{
    bool shouldChangeSaveLocation = (returnCode == kChooseNewSaveLocationReturnCode) ? YES : NO;

    [self notifyDelegateSheetDidFinishAndShouldChangeSaveLocation: shouldChangeSaveLocation];

    [self autorelease];
}

#pragma mark Delegate notifiers

- (void) notifyDelegateSheetDidFinishAndShouldChangeSaveLocation:
                                                            (bool) shouldChangeSaveLocation
{
    if ([_delegate respondsToSelector:
                    @selector(
                        documentAnimationFileNoticeSheetDidFinishAndShouldChangeSaveLocation:)])
    {
        [_delegate documentAnimationFileNoticeSheetDidFinishAndShouldChangeSaveLocation:
                                                                    shouldChangeSaveLocation];
    }
}

@end
