/*
    PPBitmapPixelTypes.h

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


// Mask bitmap pixels
#pragma mark Mask bitmap pixels

typedef uint8_t PPMaskBitmapPixel;

#define kMaskPixelValue_ON              UINT8_MAX
#define kMaskPixelValue_OFF             0
#define kMaskPixelValue_Threshold       (UINT8_MAX >> 1)


// Image bitmap pixels
#pragma mark Image bitmap pixels

typedef uint32_t PPImageBitmapPixel;

typedef uint8_t PPImagePixelComponent;

#define kMaxImagePixelComponentValue    UINT8_MAX

typedef enum
{
    kPPImagePixelComponent_Red,
    kPPImagePixelComponent_Green,
    kPPImagePixelComponent_Blue,
    kPPImagePixelComponent_Alpha,

    kNumPPImagePixelComponents

} PPImagePixelComponentType;


#define macroImagePixelComponent(imagePixel, componentType)             \
            (((PPImagePixelComponent *) (imagePixel))[componentType])


#define macroImagePixelComponent_Red(imagePixel)                        \
            macroImagePixelComponent(imagePixel, kPPImagePixelComponent_Red)

#define macroImagePixelComponent_Green(imagePixel)                      \
            macroImagePixelComponent(imagePixel, kPPImagePixelComponent_Green)

#define macroImagePixelComponent_Blue(imagePixel)                       \
            macroImagePixelComponent(imagePixel, kPPImagePixelComponent_Blue)

#define macroImagePixelComponent_Alpha(imagePixel)                      \
            macroImagePixelComponent(imagePixel, kPPImagePixelComponent_Alpha)


// Linear RGB16 bitmap pixels
#pragma mark Linear RGB16 bitmap pixels

typedef uint64_t PPLinearRGB16BitmapPixel;

typedef uint16_t PPLinear16PixelComponent;

#define kMaxLinear16PixelComponentValue     UINT16_MAX

typedef enum
{
    kPPLinearRGB16PixelComponent_Red,
    kPPLinearRGB16PixelComponent_Green,
    kPPLinearRGB16PixelComponent_Blue,
    kPPLinearRGB16PixelComponent_Alpha,

    kNumPPLinearRGB16PixelComponents

} PPLinearRGB16PixelComponentType;


#define macroLinearRGB16PixelComponent(linearPixel, componentType)          \
            (((PPLinear16PixelComponent *) (linearPixel))[componentType])


#define macroLinearRGB16PixelComponent_Red(linearPixel)                     \
            macroLinearRGB16PixelComponent(linearPixel, kPPLinearRGB16PixelComponent_Red)

#define macroLinearRGB16PixelComponent_Green(linearPixel)                   \
            macroLinearRGB16PixelComponent(linearPixel, kPPLinearRGB16PixelComponent_Green)

#define macroLinearRGB16PixelComponent_Blue(linearPixel)                    \
            macroLinearRGB16PixelComponent(linearPixel, kPPLinearRGB16PixelComponent_Blue)

#define macroLinearRGB16PixelComponent_Alpha(linearPixel)                   \
            macroLinearRGB16PixelComponent(linearPixel, kPPLinearRGB16PixelComponent_Alpha)
