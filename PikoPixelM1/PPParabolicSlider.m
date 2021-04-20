/*
    PPParabolicSlider.m

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

#import "PPParabolicSlider.h"


@interface PPParabolicSlider (PrivateMethods)

- (void) setupParabolicSlider;

@end

@implementation PPParabolicSlider

#pragma mark NSSlider overrides

- (id) initWithFrame: (NSRect) frameRect
{
    self = [super initWithFrame: frameRect];

    if (!self)
        goto ERROR;

    [self setupParabolicSlider];

    return self;

ERROR:
    [self release];

    return nil;
}

- (void) awakeFromNib
{
    // check before calling [super awakeFromNib] - before 10.6, some classes didn't implement it
    if ([[PPParabolicSlider superclass] instancesRespondToSelector: @selector(awakeFromNib)])
    {
        [super awakeFromNib];
    }

    [self setupParabolicSlider];
}

- (double) minValue
{
    return _ppMinValue;
}

- (void) setMinValue: (double) aDouble
{
    _ppMinValue = aDouble;
    _ppValueRange = _ppMaxValue - _ppMinValue;
}

- (double) maxValue
{
    return _ppMaxValue;
}

- (void) setMaxValue: (double) aDouble
{
    _ppMaxValue = aDouble;
    _ppValueRange = _ppMaxValue - _ppMinValue;
}

- (int) intValue
{
    return (int) round([self doubleValue]);
}

- (void) setIntValue: (int) anInt
{
    [self setDoubleValue: (double) anInt];
}

- (float) floatValue
{
    return (float) [self doubleValue];
}

- (void) setFloatValue: (float) aFloat
{
    [self setDoubleValue: (double) aFloat];
}

- (double) doubleValue
{
    double sliderPosition = [super doubleValue];

    return _ppMinValue + _ppValueRange * sliderPosition * sliderPosition;
}

- (void) setDoubleValue: (double) aDouble
{
    double sliderPosition = 0.0;

    if ((aDouble > _ppMinValue) && (_ppValueRange != 0))
    {
        sliderPosition = sqrt((aDouble - _ppMinValue) / _ppValueRange);
    }

    [super setDoubleValue: sliderPosition];
}

#pragma mark Private methods

- (void) setupParabolicSlider
{
    double sliderPosition = [super doubleValue];

    _ppMinValue = [super minValue];
    _ppMaxValue = [super maxValue];
    _ppValueRange = _ppMaxValue - _ppMinValue;

    [super setMinValue: 0.0];
    [super setMaxValue: 1.0];

    [self setDoubleValue: sliderPosition];
}

@end
