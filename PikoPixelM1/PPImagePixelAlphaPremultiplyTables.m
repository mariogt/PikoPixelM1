/*
    PPImagePixelAlphaPremultiplyTables.m

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

#import "PPImagePixelAlphaPremultiplyTables.h"


#define kNumLookupTables    (kMaxImagePixelComponentValue+1)
#define kSizeOfLookupTable  ((kMaxImagePixelComponentValue+1) * sizeof(PPImagePixelComponent))


PPImagePixelComponent *gImageAlphaPremultiplyTables[kNumLookupTables],
                        *gImageAlphaUnpremultiplyTables[kNumLookupTables];


static bool SetupImageAlphaPremultiplyTables(void);


@implementation NSObject (PPImagePixelAlphaPremultiplyTables)

+ (void) load
{
    SetupImageAlphaPremultiplyTables();
}

@end

#pragma mark Private functions

static bool SetupImageAlphaPremultiplyTables(void)
{
    int tablesBufferSize, alphaValue, colorValue;
    unsigned char *premultiplyTablesBuffer = NULL, *unpremultiplyTablesBuffer = NULL;
    PPImagePixelComponent *currentTable;

    tablesBufferSize = kNumLookupTables * kSizeOfLookupTable;

    premultiplyTablesBuffer = (unsigned char *) malloc (tablesBufferSize);
    unpremultiplyTablesBuffer = (unsigned char *) malloc (tablesBufferSize);

    if (!premultiplyTablesBuffer || !unpremultiplyTablesBuffer)
    {
        goto ERROR;
    }

    // alphaValue=[0] tables

        // premultiply

    currentTable = premultiplyTablesBuffer;
    premultiplyTablesBuffer += kSizeOfLookupTable;

    memset(currentTable, 0, kSizeOfLookupTable);
    gImageAlphaPremultiplyTables[0] = currentTable;

        // unpremultiply

    currentTable = unpremultiplyTablesBuffer;
    unpremultiplyTablesBuffer += kSizeOfLookupTable;

    memset(currentTable, 0, kSizeOfLookupTable);
    gImageAlphaUnpremultiplyTables[0] = currentTable;


    // alphaValue=[1..MAX] tables

    for (alphaValue=1; alphaValue<=kMaxImagePixelComponentValue; alphaValue++)
    {
        // premultiply

        currentTable = premultiplyTablesBuffer;
        premultiplyTablesBuffer += kSizeOfLookupTable;

        currentTable[0] = 0;

        for (colorValue=1; colorValue<=kMaxImagePixelComponentValue; colorValue++)
        {
            currentTable[colorValue] =
                (PPImagePixelComponent) roundf(((float) colorValue)
                                                * ((float) alphaValue)
                                                / ((float) kMaxImagePixelComponentValue));
        }

        gImageAlphaPremultiplyTables[alphaValue] = currentTable;

        // unpremultiply

        currentTable = unpremultiplyTablesBuffer;
        unpremultiplyTablesBuffer += kSizeOfLookupTable;

        currentTable[0] = 0;

        for (colorValue=1; colorValue<alphaValue; colorValue++)
        {
            currentTable[colorValue] =
                (PPImagePixelComponent) roundf(((float) colorValue)
                                                * ((float) kMaxImagePixelComponentValue)
                                                / ((float) alphaValue));
        }

        while (colorValue <= kMaxImagePixelComponentValue)
        {
            currentTable[colorValue] = kMaxImagePixelComponentValue;
            colorValue++;
        }

        gImageAlphaUnpremultiplyTables[alphaValue] = currentTable;
    }

    return YES;

ERROR:
    if (premultiplyTablesBuffer)
    {
        free(premultiplyTablesBuffer);
    }

    if (unpremultiplyTablesBuffer)
    {
        free(unpremultiplyTablesBuffer);
    }

    return NO;
}
