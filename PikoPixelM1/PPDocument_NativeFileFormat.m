/*
    PPDocument_NativeFileFormat.m

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

#import "PPDocument_NativeFileFormat.h"

#import "NSError_PPUtilities.h"
#import "NSBitmapImageRep_PPUtilities.h"


/*
PikoPixel Native File Format v1

4 parts packed together:
-----------
1. Binary data (PNG of the merged visible image - allows for viewing/editing by other apps)
-----------
2. Binary data (NSKeyedArchive of PPDocument)
-----------
3. Descriptor (PPNativeFileFormatDataDescriptor - contains lengths of PNG & NSKeyedArchive data)
-----------
4. Trailer (PPNativeFileFormatDataTrailer - contains version info & length of descriptor)
*/

#define kPPNativeFileFormatVersion_1            1


/*
PikoPixel Native File Format v2 (PikoPixel 1.0 BETA8)

Used for documents with Layer Blending Mode set to Linear (documents with Standard blending mode
are stored as v1 format for backwards compatibility)

Aside from the additional Layer Blending Mode entry in the archived PPDocument data, format v2
is the same as v1
*/

#define kPPNativeFileFormatVersion_2            2


#define kPPNativeFormatDataTrailerSignature     'ppDT'

#define kPPNativeFormatDataDescriptorSignature  'ppDD'

#define kMaxSupportedPPNativeFileFormatVersion  kPPNativeFileFormatVersion_2


// Format versions used when writing data, based on whether linear blending is enabled
#define kPPNativeFormatVersion_UsesLinearBlending       kPPNativeFileFormatVersion_2
#define kPPNativeFormatVersion_UsesStandardBlending     kPPNativeFileFormatVersion_1


typedef struct
{
    uint32_t signature;
    uint32_t formatVersion;
    uint32_t minSupportedFormatVersion;
    uint32_t descriptorLength;

} PPNativeFileFormatDataTrailer;

typedef struct
{
    uint32_t signature;
    uint32_t pngDataLength;
    uint32_t archivedDocumentDataLength;

} PPNativeFileFormatDataDescriptor;


static void SwapUInt32sWithByteCount(uint32_t *uint32sToSwap, unsigned byteCount);
static void PPNativeFileFormatDataTrailer_FixByteOrder(
                                                PPNativeFileFormatDataTrailer *dataTrailer);
static void PPNativeFileFormatDataDescriptor_FixByteOrder(
                                            PPNativeFileFormatDataDescriptor *dataDescriptor);

@implementation PPDocument (NativeFileFormat)

- (NSData *) nativeFileFormatData
{
    NSData *pngData, *archivedDocumentData;
    NSMutableData *nativeFileFormatData;
    PPNativeFileFormatDataDescriptor dataDescriptor;
    PPNativeFileFormatDataTrailer dataTrailer;

    if (_saveFormat != kPPDocumentSaveFormat_Autosave)
    {
        pngData = [_mergedVisibleLayersBitmap ppCompressedPNGData];
    }
    else
    {
        // in order to speed up autosaving, leave the PNG representation blank
        pngData = [NSData data];
    }

    archivedDocumentData = [NSKeyedArchiver archivedDataWithRootObject: self];

    nativeFileFormatData = [NSMutableData data];

    if (!pngData || !archivedDocumentData || !nativeFileFormatData)
    {
        goto ERROR;
    }

    dataDescriptor.signature = kPPNativeFormatDataDescriptorSignature;
    dataDescriptor.pngDataLength = [pngData length];
    dataDescriptor.archivedDocumentDataLength = [archivedDocumentData length];

    dataTrailer.signature = kPPNativeFormatDataTrailerSignature;

    if (_layerBlendingMode == kPPLayerBlendingMode_Linear)
    {
        dataTrailer.formatVersion = kPPNativeFormatVersion_UsesLinearBlending;
        dataTrailer.minSupportedFormatVersion = kPPNativeFormatVersion_UsesLinearBlending;
    }
    else
    {
        dataTrailer.formatVersion = kPPNativeFormatVersion_UsesStandardBlending;
        dataTrailer.minSupportedFormatVersion = kPPNativeFormatVersion_UsesStandardBlending;
    }

    dataTrailer.descriptorLength = sizeof(PPNativeFileFormatDataDescriptor);

    PPNativeFileFormatDataDescriptor_FixByteOrder(&dataDescriptor);
    PPNativeFileFormatDataTrailer_FixByteOrder(&dataTrailer);

    [nativeFileFormatData appendData: pngData];
    [nativeFileFormatData appendData: archivedDocumentData];
    [nativeFileFormatData appendBytes: &dataDescriptor length: sizeof(dataDescriptor)];
    [nativeFileFormatData appendBytes: &dataTrailer length: sizeof(dataTrailer)];

    return nativeFileFormatData;

ERROR:
    return archivedDocumentData;
}

+ (PPDocument *) ppDocumentFromNativeFileFormatData: (NSData *) data
                    returnedError: (NSError **) returnedError
{
    const unsigned char *dataBytes;
    unsigned dataLength, numBytesFromEndOfData;
    NSError *error = nil;
    PPNativeFileFormatDataTrailer dataTrailer;
    PPNativeFileFormatDataDescriptor dataDescriptor;
    NSData *archivedDocumentData;
    PPDocument *document;

    dataBytes = [data bytes];
    dataLength = [data length];

    if (!data || (dataLength < sizeof(dataTrailer)))
    {
        goto ERROR;
    }

    numBytesFromEndOfData = sizeof(dataTrailer);
    memcpy(&dataTrailer, &dataBytes[dataLength - numBytesFromEndOfData], sizeof(dataTrailer));
    PPNativeFileFormatDataTrailer_FixByteOrder(&dataTrailer);

    if (dataTrailer.signature != kPPNativeFormatDataTrailerSignature)
    {
        goto ERROR;
    }

    if (dataTrailer.minSupportedFormatVersion > kMaxSupportedPPNativeFileFormatVersion)
    {
        error = [NSError ppError_ImageFileVersionIsTooNew];
        goto ERROR;
    }

    numBytesFromEndOfData += dataTrailer.descriptorLength;

    if (numBytesFromEndOfData >= dataLength)
    {
        goto ERROR;
    }

    memcpy(&dataDescriptor, &dataBytes[dataLength - numBytesFromEndOfData],
            sizeof(dataDescriptor));
    PPNativeFileFormatDataDescriptor_FixByteOrder(&dataDescriptor);

    if (dataDescriptor.signature != kPPNativeFormatDataDescriptorSignature)
    {
        goto ERROR;
    }

    if ((dataDescriptor.pngDataLength + dataDescriptor.archivedDocumentDataLength
            + numBytesFromEndOfData) != dataLength)
    {
        goto ERROR;
    }

    if (!dataDescriptor.archivedDocumentDataLength)
    {
        goto ERROR;
    }

    numBytesFromEndOfData += dataDescriptor.archivedDocumentDataLength;

    archivedDocumentData = [NSData dataWithBytes: &dataBytes[dataLength - numBytesFromEndOfData]
                                        length: dataDescriptor.archivedDocumentDataLength];

    if (!archivedDocumentData)
        goto ERROR;

    document = [NSKeyedUnarchiver unarchiveObjectWithData: archivedDocumentData];

    if (![document isKindOfClass: [PPDocument class]])
    {
        goto ERROR;
    }

    if (returnedError)
    {
        *returnedError = nil;
    }

    return document;

ERROR:
    if (returnedError)
    {
        if (!error)
        {
            error = [NSError ppError_ImageFileIsCorrupt];
        }

        *returnedError = error;
    }

    return nil;
}

@end

#define macroSwapUInt32(uint32ToSwap)               \
            (((uint32ToSwap & 0xFF000000) >> 24)    \
            | ((uint32ToSwap & 0x00FF0000) >> 8)    \
            | ((uint32ToSwap & 0x0000FF00) << 8)    \
            | ((uint32ToSwap & 0x000000FF) << 24))

static void SwapUInt32sWithByteCount(uint32_t *uint32sToSwap, unsigned byteCount)
{
    unsigned uint32Counter;

    if (!uint32sToSwap)
        return;

    uint32Counter = byteCount / sizeof(uint32_t);

    while (uint32Counter--)
    {
        *uint32sToSwap = macroSwapUInt32(*uint32sToSwap);
        uint32sToSwap++;
    }
}

static void PPNativeFileFormatDataTrailer_FixByteOrder(
                                                PPNativeFileFormatDataTrailer *dataTrailer)
{
    if (NSHostByteOrder() == NS_BigEndian)
    {
        SwapUInt32sWithByteCount((uint32_t *) dataTrailer, sizeof(*dataTrailer));
    }
}

static void PPNativeFileFormatDataDescriptor_FixByteOrder(
                                            PPNativeFileFormatDataDescriptor *dataDescriptor)
{
    if (NSHostByteOrder() == NS_BigEndian)
    {
        SwapUInt32sWithByteCount((uint32_t *) dataDescriptor, sizeof(*dataDescriptor));
    }
}

