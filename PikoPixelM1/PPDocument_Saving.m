/*
    PPDocument_Saving.m

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

#import "PPExportPanelAccessoryViewController.h"
#import "NSBitmapImageRep_PPUtilities.h"
#import "NSWindow_PPUtilities.h"
#import "PPDocumentWindowController.h"
#import "NSObject_PPUtilities.h"
#import "PPDocument_NativeFileIcon.h"


#define kAutosaveCompoundExtensionFormatString          @"%@-%@"
#define kAutosaveCompoundExtensionSeparatorCharString   @"-"


static inline bool IsAutosaveOperation(NSSaveOperationType saveOperation);
static inline bool SaveOperationIsForDocumentFileOfCurrentWindow(
                                                            NSSaveOperationType saveOperation);


static bool gRuntimeRequiresManualSetupOfAutosaveFileExtensions = NO;

//check
static bool saveOperationResult = false;


@interface PPDocument (SavingPrivateMethods)

- (PPDocumentSaveFormat) saveFormatForSaveOperation: (NSSaveOperationType) saveOperation;

- (void) setupCustomFinderIconForSavedDocumentAtPath: (NSString *) filepath;

- (void) cleanupAfterExportSave;

- (bool) flattenedSaveWillLoseSettings;

- (NSString *) autosaveFileExtensionForExtension: (NSString *) fileExtension;

- (NSURL *) autosaveURLWithModifiedExtensionForSaveURL: (NSURL *) saveURL;

@end

@implementation PPDocument (Saving)

+ (void) load
{
    gRuntimeRequiresManualSetupOfAutosaveFileExtensions =
        (PP_RUNTIME_CHECK__RUNTIME_REQUIRES_MANUAL_SETUP_OF_AUTOSAVE_FILE_EXTENSIONS) ?
            YES : NO;
}

- (void) disableAutosaving: (bool) disallowAutosaving
{
    _disallowAutosaving = (disallowAutosaving) ? YES : NO;

    if (!_disallowAutosaving && _shouldAutosaveWhenAllowed)
    {
        [self autosaveDocumentWithDelegate: nil
                didAutosaveSelector: NULL
                contextInfo: NULL];

        _shouldAutosaveWhenAllowed = NO;
    }
}

- (void) exportImage
{
    _saveToOperationShouldUseExportSettings = YES;
    [super saveDocumentTo: self];
}

#pragma mark NSDocument overrides

- (IBAction) saveDocumentTo: (id) sender
{
    _saveToOperationShouldUseExportSettings = NO;
    [super saveDocumentTo: sender];
}

- (void) runModalSavePanelForSaveOperation: (NSSaveOperationType) saveOperation
            delegate: (id) delegate
            didSaveSelector: (SEL) didSaveSelector
            contextInfo: (void *) contextInfo
{
    _savePanelShouldAttachExportAccessoryView =
        ((saveOperation == NSSaveToOperation) && _saveToOperationShouldUseExportSettings) ?
            YES : NO;

    [super runModalSavePanelForSaveOperation: saveOperation
            delegate: delegate
            didSaveSelector: didSaveSelector
            contextInfo: contextInfo];
}

- (BOOL) shouldRunSavePanelWithAccessoryView
{
    return (_savePanelShouldAttachExportAccessoryView) ? NO : YES;
}

- (BOOL) prepareSavePanel: (NSSavePanel *) savePanel
{
    if (![super prepareSavePanel: savePanel])
    {
        goto ERROR;
    }

    if (_savePanelShouldAttachExportAccessoryView)
    {
        if (!_exportPanelViewController)
        {
            _exportPanelViewController =
                [[PPExportPanelAccessoryViewController controllerForPPDocument: self] retain];

            if (!_exportPanelViewController)
                goto ERROR;
        }

        [_exportPanelViewController setupWithSavePanel: savePanel];

        _savePanelShouldAttachExportAccessoryView = NO;
    }

    return YES;

ERROR:
    return NO;
}

- (void) setSaveOperationResultBool:(bool)result {
    saveOperationResult = result;
}

//check
- (BOOL) saveToURL: (NSURL *) absoluteURL
            ofType: (NSString *) typeName
            forSaveOperation: (NSSaveOperationType) saveOperation
            completitionHandler: (void (^)(NSError *errorOrNil))completionHandler
{
    bool didSaveSuccessfully = false;

    _saveFormat = [self saveFormatForSaveOperation: saveOperation];

    if (_saveFormat == kPPDocumentSaveFormat_Autosave)
    {
        if (gRuntimeRequiresManualSetupOfAutosaveFileExtensions)
        {
            absoluteURL = [self autosaveURLWithModifiedExtensionForSaveURL: absoluteURL];
        }
    }
    else if (_saveFormat == kPPDocumentSaveFormat_Export)
    {
        NSString *exportedTypeName = [_exportPanelViewController selectedFileTypeName];

        if (exportedTypeName)
        {
            typeName = exportedTypeName;
        }
    }
    
    //check
    [super saveToURL:absoluteURL ofType:typeName forSaveOperation:saveOperation completionHandler:^(NSError *errorOrNil) {
        if (errorOrNil == nil) {
            NSLog(@"success");
            [self setSaveOperationResultBool:true];
        } else {
            NSLog(@"error");
            [self setSaveOperationResultBool:false];
        }
    }];
    
    didSaveSuccessfully = saveOperationResult;

    if (didSaveSuccessfully && SaveOperationIsForDocumentFileOfCurrentWindow(saveOperation))
    {
        if ([typeName isEqualToString: kNativeFileFormatTypeName])
        {
            // native filetype: set up window titlebar icon
            [[self ppWindow] ppSetDocumentWindowTitlebarIcon: [self nativeFileIconImage]];
        }
        else
        {
            // non-native filetypes: set up flattened-save notice if settings were lost
            if ([self flattenedSaveWillLoseSettings])
            {
                [[self ppDocumentWindowController] ppPerformSelectorFromNewStackFrame:
                                                    @selector(beginFlattenedSaveNoticeSheet)];
            }
        }
    }

    if (_saveFormat == kPPDocumentSaveFormat_Export)
    {
        [self cleanupAfterExportSave];
    }

    return didSaveSuccessfully;
}

- (BOOL) writeToURL: (NSURL *) absoluteURL
            ofType: (NSString *) typeName
            forSaveOperation: (NSSaveOperationType) saveOperation
            originalContentsURL: (NSURL *) absoluteOriginalContentsURL
            error: (NSError **) outError
{
    BOOL didWriteSuccessfully = [super writeToURL: absoluteURL
                                        ofType: typeName
                                        forSaveOperation: saveOperation
                                        originalContentsURL: absoluteOriginalContentsURL
                                        error: outError];

    if (didWriteSuccessfully
        && (_saveFormat != kPPDocumentSaveFormat_Autosave)
        && [typeName isEqualToString: kNativeFileFormatTypeName])
    {
        // The custom finder icon for native-format files needs to be set here: The point where
        // the currently-set version of the document icon is cached by the Finder seems to be
        // from within NSDocument's writeSafelyToURL:... method (the caller of this method),
        // following this method's return.
        // Setting the icon after the writeSafelyToURL:... method call results in an incorrect,
        // out-of-date finder icon (and there's no API to manually update the Finder's cached
        // icon - would need to either resave the file or logout & login).

        [self setupCustomFinderIconForSavedDocumentAtPath: [absoluteURL path]];
    }

    return didWriteSuccessfully;
}

- (NSString *) autosavingFileType
{
    if (_disallowAutosaving)
    {
        _shouldAutosaveWhenAllowed = YES;

        return nil;
    }

    return kNativeFileFormatTypeName;
}

- (NSString *) fileNameExtensionForType: (NSString *) typeName
                saveOperation: (NSSaveOperationType) saveOperation
{
    NSString *fileNameExtension = [super fileNameExtensionForType: typeName
                                            saveOperation: saveOperation];

    if (IsAutosaveOperation(saveOperation))
    {
        // OS X's autosave naming doesn't take the filetype extension into account, so if
        // editing two images with the same name but different types (i.e. A.piko & A.png),
        // they will share the same autosave URL (autosave files are always stored in .piko
        // format, regardless of document type); To prevent autosave overlapping, include the
        // document's file extension as part of the returned fileNameExtension when autosaving.
        // A.png -> A (Autosaved).piko-png (instead of the default: A (Autosaved).piko)

        fileNameExtension = [self autosaveFileExtensionForExtension: fileNameExtension];
    }

    return fileNameExtension;
}

#pragma mark Private methods

- (PPDocumentSaveFormat) saveFormatForSaveOperation: (NSSaveOperationType) saveOperation;
{
    if (IsAutosaveOperation(saveOperation))
    {
        return kPPDocumentSaveFormat_Autosave;
    }
    else if ((saveOperation == NSSaveToOperation) && _saveToOperationShouldUseExportSettings)
    {
        return kPPDocumentSaveFormat_Export;
    }

    return kPPDocumentSaveFormat_Normal;
}

- (void) setupCustomFinderIconForSavedDocumentAtPath: (NSString *) filepath
{
    if (![filepath length])
        goto ERROR;

    [[NSWorkspace sharedWorkspace] setIcon: [self nativeFileIconImage]
                                    forFile: filepath
                                    options: NSExcludeQuickDrawElementsIconCreationOption];

    return;

ERROR:
    return;
}

- (void) cleanupAfterExportSave
{
    [_exportPanelViewController setupWithSavePanel: nil];

    _saveToOperationShouldUseExportSettings = NO;
}

- (bool) flattenedSaveWillLoseSettings
{
    return (([self numLayers] > 1)
            || [self hasSelection]
            || [self hasCustomCanvasSettings]
            || ([self numSamplerImages] > 0)) ? YES : NO;
}

// autosaveFileExtensionForExtension: returns an extension for use when autosaving files.
// This is a workaround for OS X's autosave namespace issue, where editing two images in the
// same directory with the same name but different types (i.e. A.piko & A.png) will currently
// use the same autosave URL for both (autosave files are currently stored in .piko format,
// regardless of document type, so the the default autosave extension would always be "piko").
// The returned autosave extension appends the type extension of the document's saved file:
// "piko" fileExtension + "png" saved document type extension -> "piko-png"

- (NSString *) autosaveFileExtensionForExtension: (NSString *) fileExtension
{
    NSURL *savedDocumentURL = [self fileURL];

    if (savedDocumentURL
        && [fileExtension length])
    {
        NSString *savedDocumentExtension = [[savedDocumentURL path] pathExtension];

        if ([savedDocumentExtension length]
            && ![savedDocumentExtension isEqualToString: fileExtension])
        {
            NSString *autosaveExtension =
                            [NSString stringWithFormat: kAutosaveCompoundExtensionFormatString,
                                                        fileExtension,
                                                        savedDocumentExtension];

            if (autosaveExtension)
            {
                fileExtension = autosaveExtension;
            }
        }
    }

    return fileExtension;
}

// autosaveURLWithModifiedExtensionForSaveURL: is for setting up an autosave URL manually
// on runtimes that don't support NSDocument's fileNameExtensionForType:saveOperation: (< 10.5)

- (NSURL *) autosaveURLWithModifiedExtensionForSaveURL: (NSURL *) saveURL
{
    NSString *savePath, *saveExtension, *autosaveExtension, *autosavePath;
    NSURL *autosaveURL;

    if (!saveURL)
        goto ERROR;

    savePath = [saveURL path];
    saveExtension = [savePath pathExtension];

    if (![saveExtension length])
    {
        goto ERROR;
    }

    if ([saveExtension rangeOfString: kAutosaveCompoundExtensionSeparatorCharString].length)
    {
        // saveURL already has a compound extension, so just return it

        return saveURL;
    }

    autosaveExtension = [self autosaveFileExtensionForExtension: saveExtension];

    if (![autosaveExtension length])
    {
        goto ERROR;
    }

    if ([autosaveExtension isEqualToString: saveExtension])
    {
        return saveURL;
    }

    autosavePath = [[savePath stringByDeletingPathExtension]
                                    stringByAppendingPathExtension: autosaveExtension];

    if (!autosavePath)
        goto ERROR;

    autosaveURL = [NSURL fileURLWithPath: autosavePath];

    if (!autosaveURL)
        goto ERROR;

    return autosaveURL;

ERROR:
    return saveURL;
}

@end

#pragma mark Private functions

static inline bool IsAutosaveOperation(NSSaveOperationType saveOperation)
{
    return ((saveOperation != NSSaveOperation)
            && (saveOperation != NSSaveAsOperation)
            && (saveOperation != NSSaveToOperation)) ?
                YES : NO;
}

static inline bool SaveOperationIsForDocumentFileOfCurrentWindow(
                                                            NSSaveOperationType saveOperation)
{
    return ((saveOperation == NSSaveOperation) || (saveOperation == NSSaveAsOperation)) ?
                YES : NO;
}
