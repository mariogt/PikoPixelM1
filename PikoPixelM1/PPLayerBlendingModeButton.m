/*
    PPLayerBlendingModeButton.m

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

#import "PPLayerBlendingModeButton.h"


#define kButtonIconName_Standard    @"blend_mode_icon_standard"
#define kButtonIconName_Linear      @"blend_mode_icon_linear"

#define kModeName_Standard          @"STANDARD"
#define kModeName_Linear            @"LINEAR"

#define kToolTipFormatString                                                                \
            @"Layer Blending: %@\n\n"                                                       \
            "Layer Blending determines how colors are calculated when compositing "         \
            "partially-transparent layers with visible lower layers:\n\n"                   \
            "• STANDARD blending mixes colors in standard RGB colorspace (sRGB); Most "     \
            "software blends colors this way, however, the results can be visually "        \
            "incorrect (too dark & saturated) due to sRGB's non-linear gamma.\n\n"          \
            "• LINEAR blending produces visually-correct mixed colors; Color values are "   \
            "converted to linear-encoding before mixing."


static NSImage *gIconImage_StandardMode = nil, *gIconImage_LinearMode = nil;
static NSString *gToolTip_StandardMode = nil, *gToolTip_LinearMode = nil;


@interface PPLayerBlendingModeButton (PrivateMethods)

- (void) updateButtonAttributesForCurrentMode;

@end

@implementation PPLayerBlendingModeButton

+ (void) initialize
{
    if ([self class] != [PPLayerBlendingModeButton class])
    {
        return;
    }

    gIconImage_StandardMode = [[NSImage imageNamed: kButtonIconName_Standard] retain];

    gIconImage_LinearMode = [[NSImage imageNamed: kButtonIconName_Linear] retain];


    gToolTip_StandardMode =
            [[NSString stringWithFormat: kToolTipFormatString, kModeName_Standard] retain];

    gToolTip_LinearMode =
            [[NSString stringWithFormat: kToolTipFormatString, kModeName_Linear] retain];
}

- (void) setLayerBlendingMode: (PPLayerBlendingMode) layerBlendingMode
{
    if (!PPLayerBlendingMode_IsValid(layerBlendingMode))
    {
        goto ERROR;
    }

    if (_layerBlendingMode == layerBlendingMode)
    {
        return;
    }

    _layerBlendingMode = layerBlendingMode;

    [self updateButtonAttributesForCurrentMode];

    return;

ERROR:
    return;
}

#pragma mark NSButton overrides

- (void) awakeFromNib
{
    // check before calling [super awakeFromNib] - before 10.6, some classes didn't implement it
    if ([[PPLayerBlendingModeButton superclass] instancesRespondToSelector:
                                                                    @selector(awakeFromNib)])
    {
        [super awakeFromNib];
    }

    [self updateButtonAttributesForCurrentMode];
}

#pragma mark Private methods

- (void) updateButtonAttributesForCurrentMode
{
    NSImage *iconImage;
    NSString *toolTip;

    if (_layerBlendingMode == kPPLayerBlendingMode_Linear)
    {
        iconImage = gIconImage_LinearMode;
        toolTip = gToolTip_LinearMode;
    }
    else
    {
        iconImage = gIconImage_StandardMode;
        toolTip = gToolTip_StandardMode;
    }

    [self setImage: iconImage];
    [self setToolTip: toolTip];
}

@end
