/*
    NSError_PPUtilities.m

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

#import "NSError_PPUtilities.h"

#import "PPDefines.h"


#define kErrorDescription_ImageFileVersionIsTooNew                                          \
            @"\n\nThe file was created by a newer version of PikoPixel and cannot be read " \
            "by this version."

#define kErrorDescription_ImageFileDimensionsAreTooLarge                                    \
            [NSString stringWithFormat:                                                     \
                        @"\n\nThe image is too large.\nMaximum size allowed is: %d x %d",   \
                        kMaxCanvasDimension, kMaxCanvasDimension]

#define kErrorDescriptionFormatString_UnableToCreateDataOfType                              \
            @"\n\nUnable to create data in \"%@\" format."


@implementation NSError (PPUtilities)

+ (NSError *) ppError_ImageFileIsCorrupt
{
    return [NSError errorWithDomain: NSCocoaErrorDomain
                        code: NSFileReadCorruptFileError
                        userInfo: nil];
}

+ (NSError *) ppError_ImageFileVersionIsTooNew
{
    NSDictionary *errorUserInfoDict =
                    [NSDictionary dictionaryWithObject:
                                            kErrorDescription_ImageFileVersionIsTooNew
                                    forKey: NSLocalizedFailureReasonErrorKey];

    return [NSError errorWithDomain: NSCocoaErrorDomain
                        code: NSFileReadUnknownError
                        userInfo: errorUserInfoDict];
}

+ (NSError *) ppError_ImageFileDimensionsAreTooLarge
{
    NSDictionary *errorUserInfoDict =
                    [NSDictionary dictionaryWithObject:
                                            kErrorDescription_ImageFileDimensionsAreTooLarge
                                    forKey: NSLocalizedFailureReasonErrorKey];

    return [NSError errorWithDomain: NSCocoaErrorDomain
                        code: NSFileReadUnknownError
                        userInfo: errorUserInfoDict];
}

+ (NSError *) ppError_UnableToCreateDataOfType: (NSString *) typeName
{
    NSString *errorDescription =
                [NSString stringWithFormat:
                            kErrorDescriptionFormatString_UnableToCreateDataOfType, typeName];

    NSDictionary *errorUserInfoDict =
                    [NSDictionary dictionaryWithObject: errorDescription
                                    forKey: NSLocalizedFailureReasonErrorKey];

    return [NSError errorWithDomain: NSCocoaErrorDomain
                        code: NSFileWriteUnknownError
                        userInfo: errorUserInfoDict];
}

@end
