/*
    PPDocumentWindowController_Sheets.m

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

#import "PPDocumentWindowController_Sheets.h"

#import "PPDocument.h"
#import "PPCanvasView.h"
#import "PPDocumentSizeSheetController.h"
#import "PPDocumentScaleSheetController.h"
#import "PPDocumentResizeSheetController.h"
#import "PPDocumentBackgroundSettingsSheetController.h"
#import "PPDocumentGridSettingsSheetController.h"
#import "PPDocumentSamplerImagesSettingsSheetController.h"
#import "PPDocumentAnimationFileNoticeSheetController.h"
#import "PPDocumentFlattenedSaveNoticeSheetController.h"
#import "PPBackgroundPattern.h"
#import "NSObject_PPUtilities.h"



@interface PPDocumentWindowController (SheetsPrivateMethods)

- (void) ppCloseDocumentWithMessage: (NSString *) message;

- (void) ppDocumentCloseAlertSheetDidEnd: (NSAlert *) alert
            returnCode: (NSInteger) returnCode
            contextInfo: (void *) contextInfo;

@end


@implementation PPDocumentWindowController (Sheets)

- (void) beginSizeSheet
{
    [PPDocumentSizeSheetController beginSizeSheetForDocumentWindow: [self window]
                                                        delegate: self];
}

- (void) beginScaleSheet
{
    [PPDocumentScaleSheetController beginScaleSheetForDocumentWindow: [self window]
                                        canvasBitmap: [_ppDocument mergedVisibleLayersBitmap]
                                        delegate: self];
}

- (void) beginResizeSheet
{
    [PPDocumentResizeSheetController beginResizeSheetForDocumentWindow: [self window]
                                        currentImageSize: [_ppDocument canvasSize]
                                        delegate: self];
}

- (void) beginBackgroundSettingsSheet
{
    [PPDocumentBackgroundSettingsSheetController
                                beginBackgroundSettingsSheetForDocumentWindow: [self window]
                                backgroundPattern: [_ppDocument backgroundPattern]
                                backgroundImage: [_ppDocument backgroundImage]
                                backgroundImageVisibility:
                                                    [_ppDocument shouldDisplayBackgroundImage]
                                backgroundImageSmoothing:
                                                    [_ppDocument shouldSmoothenBackgroundImage]
                                delegate: self];
}

- (void) beginGridSettingsSheet
{
    [PPDocumentGridSettingsSheetController
                                    beginGridSettingsSheetForDocumentWindow: [self window]
                                    gridPattern: [_ppDocument gridPattern]
                                    gridVisibility: [_ppDocument shouldDisplayGrid]
                                    delegate: self];
}

- (void) beginSamplerImagesSettingsSheet
{
    [PPDocumentSamplerImagesSettingsSheetController
                                beginSamplerImagesSettingsSheetForWindow: [self window]
                                samplerImages: [_ppDocument samplerImages]
                                delegate: self];
}

- (void) beginAnimationFileNoticeSheet
{
    [PPDocumentAnimationFileNoticeSheetController
                                beginAnimationFileNoticeSheetForDocumentWindow: [self window]
                                delegate: self];
}

- (void) beginFlattenedSaveNoticeSheet
{
    [PPDocumentFlattenedSaveNoticeSheetController
                            beginFlattenedSaveNoticeSheetForDocumentWindow: [self window]];
}

#pragma mark PPDocumentSizeSheetController delegate methods

- (void) documentSizeSheetDidFinishWithWidth: (int) width
            andHeight: (int) height
{
    if (![_ppDocument setupNewPPDocumentWithCanvasSize: NSMakeSize(width, height)])
    {
        goto ERROR;
    }

    return;

ERROR:
    [self ppCloseDocumentWithMessage: @"ERROR: Could not create document."];
}

- (void) documentSizeSheetDidCancel
{
    [_ppDocument close];
}

#pragma mark PPDocumentScaleSheetController delegate methods

- (void) documentScaleSheetDidFinishWithNewImageSize: (NSSize) newImageSize
{
    [_ppDocument resizeToSize: newImageSize shouldScale: YES];
}

- (void) documentScaleSheetDidCancel
{
}

#pragma mark PPDocumentResizeSheetController delegate methods

- (void) documentResizeSheetDidFinishWithNewImageSize: (NSSize) newImageSize
            shouldScale: (bool) shouldScale
{
    [_ppDocument resizeToSize: newImageSize shouldScale: shouldScale];
}

- (void) documentResizeSheetDidCancel
{
}

#pragma mark PPDocumentBackgroundSettingsSheetController delegate methods

- (void) backgroundSettingsSheetDidUpdatePattern: (PPBackgroundPattern *) backgroundPattern
{
    [_canvasView setBackgroundColor: [backgroundPattern patternFillColor]];
}

- (void) backgroundSettingsSheetDidUpdateImage: (NSImage *) backgroundImage
{
    [_canvasView setBackgroundImage: backgroundImage];
}

- (void) backgroundSettingsSheetDidUpdateImageVisibility: (bool) shouldDisplayImage
{
    [_canvasView setBackgroundImageVisibility: shouldDisplayImage];
}

- (void) backgroundSettingsSheetDidUpdateImageSmoothing: (bool) shouldSmoothenImage
{
    [_canvasView setBackgroundImageSmoothing: shouldSmoothenImage];
}

- (void) backgroundSettingsSheetDidFinishWithBackgroundPattern:
                                                    (PPBackgroundPattern *) backgroundPattern
            backgroundImage: (NSImage *) backgroundImage
            shouldDisplayImage: (bool) shouldDisplayImage
            shouldSmoothenImage: (bool) shouldSmoothenImage
{
    [_ppDocument setBackgroundPattern: backgroundPattern
                    backgroundImage: backgroundImage
                    shouldDisplayBackgroundImage: shouldDisplayImage
                    shouldSmoothenBackgroundImage: shouldSmoothenImage];

    // compressed background image data is not automatically set up by setBackgroundPattern:...
    // don't need to manually update it here, but doing so saves time during the next autosave

    if (backgroundImage)
    {
        [_ppDocument setupCompressedBackgroundImageData];
    }
}

- (void) backgroundSettingsSheetDidCancel
{
    [_canvasView setBackgroundImage: [_ppDocument backgroundImage]
                    backgroundImageVisibility: [_ppDocument shouldDisplayBackgroundImage]
                    backgroundImageSmoothing: [_ppDocument shouldSmoothenBackgroundImage]
                    backgroundColor: [_ppDocument backgroundPatternAsColor]];
}

#pragma mark PPDocumentGridSettingsSheetController delegate methods

- (void) gridSettingsSheetDidUpdateGridPattern: (PPGridPattern *) gridPattern
                            andVisibility: (bool) shouldDisplayGrid
{
    [_canvasView setGridPattern: gridPattern
                    gridVisibility: shouldDisplayGrid];
}

- (void) gridSettingsSheetDidFinishWithGridPattern: (PPGridPattern *) gridPattern
                                andVisibility: (bool) shouldDisplayGrid
{
    [_ppDocument setGridPattern: gridPattern
                    shouldDisplayGrid: shouldDisplayGrid];
}

- (void) gridSettingsSheetDidCancel
{
    [_canvasView setGridPattern: [_ppDocument gridPattern]
                    gridVisibility: [_ppDocument shouldDisplayGrid]];
}

#pragma mark PPDocumentSamplerImagesSettingsSheetController delegate methods

- (void) samplerImagesSettingsSheetDidFinishWithSamplerImages: (NSArray *) samplerImages
{
    [_ppDocument setSamplerImages: samplerImages];
}

- (void) samplerImagesSettingsSheetDidCancel
{
}

#pragma mark PPDocumentAnimationFileNoticeSheetController delegate methods

- (void) documentAnimationFileNoticeSheetDidFinishAndShouldChangeSaveLocation:
                                                            (bool) shouldChangeSaveLocation
{
    if (shouldChangeSaveLocation)
    {
        [_ppDocument ppPerformSelectorFromNewStackFrame: @selector(saveDocumentAs:)];
    }
}

#pragma mark Private methods

- (void) ppCloseDocumentWithMessage: (NSString *) message
{
    NSAlert *closeAlert;

    if (!message)
        goto ERROR;
    
    closeAlert = [[[NSAlert alloc] init] autorelease];
    closeAlert.messageText = NSLocalizedString(message, nil);
    closeAlert.buttons.firstObject.title = NSLocalizedString(@"OK", nil);

    /*closeAlert = [NSAlert alertWithMessageText: NSLocalizedString(message, nil)
                            defaultButton: @"OK"
                            alternateButton: nil
                            otherButton: nil
                            informativeTextWithFormat: @""];*/

    if (!closeAlert)
        goto ERROR;

    /*[closeAlert beginSheetModalForWindow: [self window]
                modalDelegate: self
                didEndSelector:
                            @selector(ppDocumentCloseAlertSheetDidEnd:returnCode:contextInfo:)
                contextInfo: NULL];*/
    
    //check
    [closeAlert.window beginSheet: [self window] completionHandler:^(NSInteger result) {
        //if (result == 1) NSLog(@"1");
        //if (result == 0) NSLog(@"0");
    }];

    return;

ERROR:
    [_ppDocument close];
}

- (void) ppDocumentCloseAlertSheetDidEnd: (NSAlert *) alert
            returnCode: (NSInteger) returnCode
            contextInfo: (void *) contextInfo
{
    [[alert window] orderOut: self];

    [_ppDocument close];
}

@end
