/*
    NSDocumentController_PPUtilities.m

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

#import "NSDocumentController_PPUtilities.h"

#import "PPDocument.h"


@implementation NSDocumentController (PPUtilities)

- (bool) ppOpenUntitledDuplicateOfPPDocument: (PPDocument *) ppDocumentToDuplicate
{
    PPDocument *newPPDocument = nil;
    NSError *error;

    if (!ppDocumentToDuplicate)
        goto ERROR;

    newPPDocument = [self openUntitledDocumentAndDisplay: NO error: &error];

    if (!newPPDocument || ![newPPDocument isKindOfClass: [PPDocument class]])
    {
        goto ERROR;
    }

    [newPPDocument loadFromPPDocument: ppDocumentToDuplicate];
    [newPPDocument makeWindowControllers];
    [newPPDocument showWindows];

    return YES;

ERROR:
    [newPPDocument close];

    return NO;
}

- (void) ppActivateNextDocument
{
    NSArray *documents;
    NSInteger documentCount, documentIndex, nextDocumentIndex;
    NSDocument *currentDocument, *nextDocument;

    documents = [self documents];
    documentCount = [documents count];

    if (documentCount < 2)
    {
        goto ERROR;
    }

    currentDocument = [self currentDocument];

    if (!currentDocument)
        goto ERROR;

    documentIndex = [documents indexOfObject: currentDocument];

    if (documentIndex == NSNotFound)
    {
        goto ERROR;
    }

    nextDocumentIndex = documentIndex + 1;

    if (nextDocumentIndex >= documentCount)
    {
        nextDocumentIndex = 0;
    }

    nextDocument = [documents objectAtIndex: nextDocumentIndex];

    [[nextDocument ppWindow] makeKeyAndOrderFront: self];

    return;

ERROR:
    return;
}

- (void) ppActivatePreviousDocument
{
    NSArray *documents;
    NSInteger documentCount, documentIndex, previousDocumentIndex;
    NSDocument *currentDocument, *previousDocument;

    documents = [self documents];
    documentCount = [documents count];

    if (documentCount < 2)
    {
        goto ERROR;
    }

    currentDocument = [self currentDocument];

    if (!currentDocument)
        goto ERROR;

    documentIndex = [documents indexOfObject: currentDocument];

    if (documentIndex == NSNotFound)
    {
        goto ERROR;
    }

    previousDocumentIndex = documentIndex - 1;

    if (previousDocumentIndex < 0)
    {
        previousDocumentIndex = documentCount - 1;
    }

    previousDocument = [documents objectAtIndex: previousDocumentIndex];

    [[previousDocument ppWindow] makeKeyAndOrderFront: self];

    return;

ERROR:
    return;
}

- (bool) ppHasMultipleDocuments
{
    return ([[self documents] count] > 1) ? YES : NO;
}

@end
