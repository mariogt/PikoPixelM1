/*
    NSFileManager_PPUtilities.m

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

#import "NSFileManager_PPUtilities.h"

#import "PPUserFolderPaths.h"


@implementation NSFileManager (PPUtilities)

- (bool) ppVerifySupportFileDirectory
{
    NSString *supportFolderPath = PPUserFolderPaths_ApplicationSupport();
    BOOL isDirectory = NO, returnValue = NO;

    if (![supportFolderPath length])
    {
        goto ERROR;
    }

    if ([self fileExistsAtPath: supportFolderPath isDirectory: &isDirectory])
    {
        if (!isDirectory)
            goto ERROR;

        return YES;
    }

#if PP_DEPLOYMENT_TARGET_DEPRECATED_CREATEDIRECTORYATPATHATTRIBUTES

    returnValue = [self createDirectoryAtPath: supportFolderPath
                            withIntermediateDirectories: NO
                            attributes: nil
                            error: nil];

#else   // Deployment target supports createDirectoryAtPath:attributes:

    returnValue = [self createDirectoryAtPath: supportFolderPath attributes: nil];

#endif  // PP_DEPLOYMENT_TARGET_DEPRECATED_CREATEDIRECTORYATPATHATTRIBUTES

    return returnValue;

ERROR:
    return NO;
}

+ (NSString *) ppFilepathForSupportFileWithName: (NSString *) filename
{
    NSString *supportFolderPath = PPUserFolderPaths_ApplicationSupport();

    if (![supportFolderPath length]
        || ![filename length])
    {
        goto ERROR;
    }

    return [supportFolderPath stringByAppendingPathComponent: filename];

ERROR:
    return nil;
}

- (bool) ppDeleteSupportFileAtPath: (NSString *) filepath;
{
    NSString *supportFolderPath = PPUserFolderPaths_ApplicationSupport();
    bool returnValue = NO;

    if (![supportFolderPath length]
        || ![filepath hasPrefix: supportFolderPath]
        || ![self isDeletableFileAtPath: filepath])
    {
        goto ERROR;
    }

#if PP_DEPLOYMENT_TARGET_DEPRECATED_REMOVEFILEATPATHHANDLER

    returnValue = [self removeItemAtPath: filepath error: nil];

#else   // Deployment target supports removeFileAtPath:handler:

    returnValue = [self removeFileAtPath: filepath handler: NULL];

#endif  // PP_DEPLOYMENT_TARGET_DEPRECATED_REMOVEFILEATPATHHANDLER

    return returnValue;

ERROR:
    return NO;
}

@end
