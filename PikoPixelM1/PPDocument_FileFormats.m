/*
    PPDocument_FileFormats.m

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

#import "PPDocument_NativeFileFormat.h"
#import "PPGeometry.h"
#import "NSBitmapImageRep_PPUtilities.h"
#import "NSError_PPUtilities.h"


#define kTypeName_GIF               @"GIF Graphic"
#define kTypeName_JPEG              @"JPEG Graphic"
#define kTypeName_PNG               @"PNG Graphic"
#define kTypeName_TIFF              @"TIFF Graphic"
#define kTypeName_BMP               @"BMP Graphic"


@implementation PPDocument (FileFormats)

#pragma mark NSDocument overrides

- (NSData *) dataOfType: (NSString *) typeName error: (NSError **) outError
{
    NSData *returnedData;
    NSBitmapImageRep *bitmap;
    NSBitmapImageFileType bitmapImageFileType = NSPNGFileType;
    NSDictionary *propertiesDict = nil;

    if (outError)
    {
        *outError = nil;
    }

    if ([typeName isEqualToString: kNativeFileFormatTypeName])
    {
        returnedData = [self nativeFileFormatData];

        if (!returnedData)
            goto ERROR;

        return returnedData;
    }

    if (_saveFormat == kPPDocumentSaveFormat_Export)
    {
        bitmap = [self mergedVisibleLayersBitmapUsingExportPanelSettings];
    }
    else
    {
        bitmap = _mergedVisibleLayersBitmap;
    }

    if ([typeName isEqualToString: kTypeName_PNG])
    {
        bitmapImageFileType = NSPNGFileType;
    }
    else if ([typeName isEqualToString: kTypeName_TIFF])
    {
        bitmapImageFileType = NSTIFFFileType;

        propertiesDict =
            [NSDictionary dictionaryWithObject: [NSNumber numberWithInt: NSTIFFCompressionLZW]
                            forKey: NSImageCompressionMethod];
    }
    else if ([typeName isEqualToString: kTypeName_GIF])
    {
        bitmapImageFileType = NSGIFFileType;
    }
    else if ([typeName isEqualToString: kTypeName_JPEG])
    {
        bitmapImageFileType = NSJPEGFileType;

        propertiesDict =
            [NSDictionary dictionaryWithObject: [NSNumber numberWithFloat: 1.0f]
                            forKey: NSImageCompressionFactor];
    }
    else if ([typeName isEqualToString: kTypeName_BMP])
    {
        bitmapImageFileType = NSBMPFileType;
    }

    returnedData =
            [bitmap representationUsingType: bitmapImageFileType properties: propertiesDict];

    if (!returnedData)
        goto ERROR;

    return returnedData;

ERROR:
    if (outError)
    {
        *outError = [NSError ppError_UnableToCreateDataOfType: typeName];
    }

    return nil;
}

- (BOOL) readFromData: (NSData *) data
            ofType: (NSString *) typeName
            error: (NSError **) outError
{
    NSError *error = nil;
    NSBitmapImageRep *importedBitmap, *imageBitmap;

    if ([typeName isEqualToString: kNativeFileFormatTypeName])
    {
        PPDocument *ppDocument = [PPDocument ppDocumentFromNativeFileFormatData: data
                                                returnedError: &error];

        if (ppDocument && [self loadFromPPDocument: ppDocument])
        {
            return YES;
        }
        else
        {
            goto ERROR;
        }
    }

    importedBitmap = [NSBitmapImageRep imageRepWithData: data];

    if (!importedBitmap)
        goto ERROR;

    imageBitmap = [importedBitmap ppImageBitmap];

    if (!imageBitmap)
        goto ERROR;

    if (PPGeometry_SizeExceedsDimension([imageBitmap ppSizeInPixels], kMaxCanvasDimension))
    {
        error = [NSError ppError_ImageFileDimensionsAreTooLarge];
        goto ERROR;
    }

    if (![self loadFromImageBitmap: imageBitmap withFileType: typeName])
    {
        goto ERROR;
    }

    _sourceBitmapHasAnimationFrames = [importedBitmap ppImportedBitmapHasAnimationFrames];

    if (outError)
    {
        *outError = nil;
    }

    return YES;

ERROR:
    if (outError)
    {
        if (!error)
        {
            error = [NSError ppError_ImageFileIsCorrupt];
        }

        *outError = error;
    }

    return NO;
}

@end
