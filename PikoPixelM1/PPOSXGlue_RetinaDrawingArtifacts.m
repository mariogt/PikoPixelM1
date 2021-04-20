/*
    PPOSXGlue_RetinaDrawingArtifacts.m

    Copyright 2013-2018 Josh Freeman
    http://www.twilightedge.com

    This file is part of PikoPixel for Mac OS X.
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

//  On OS X retina displays, partial draws of NSViews (updating areas that don't cover the
// entire view) can cause the pixel values on the edges of the updated area to bleed into
// surrounding pixels outside the drawn area (antialiasing or roundoff-error when automatically
// scaling from standard coordinates to retina coordinates?). This leaves drawing artifacts
// behind: very thin lines (single retina-pixel width).
//  Workaround is to patch affected views' setNeedsDisplayInRect: methods, and pass the
// original methods a dirty rect that's slightly larger than the one passed in - increased by a
// standard-coordinate pixel-width along each side - so that the updated area has a margin of
// pixel-values at the borders that are the same color as before the update. This causes the
// line artifacts to disappear because the bleed from the 'new' pixel values will match the
// (unchanged) colors already there.

#if defined(__APPLE__) && (PP_DEPLOYMENT_TARGET_SUPPORTS_RETINA_DISPLAY)

#import <Cocoa/Cocoa.h>
#import "NSObject_PPUtilities.h"
#import "PPAppBootUtilities.h"
#import "PPOSXGlueUtilities.h"
#import "PPCanvasView.h"
#import "PPPreviewView.h"


@implementation NSObject (PPOSXGlue_RetinaDrawingArtifacts)

+ (void) ppOSXGlue_RetinaDrawingArtifacts_InstallPatches
{
    macroSwizzleInstanceMethod(PPCanvasView, setNeedsDisplayInRect:,
                               ppOSXPatch_SetNeedsDisplayInRect:);


    macroSwizzleInstanceMethod(PPPreviewView, setNeedsDisplayInRect:,
                               ppOSXPatch_SetNeedsDisplayInRect:);
}

+ (void) ppOSXGlue_RetinaDrawingArtifacts_Install
{
    PPOSXGlueUtils_PerformNSObjectSelectorOnceWhenAnyDisplayIsRetina(
                                    @selector(ppOSXGlue_RetinaDrawingArtifacts_InstallPatches));
}

+ (void) load
{
    if (PP_RUNTIME_CHECK__RUNTIME_SUPPORTS_RETINA_DISPLAY)
    {
        macroPerformNSObjectSelectorAfterAppLoads(ppOSXGlue_RetinaDrawingArtifacts_Install);
    }
}

@end

@implementation PPCanvasView (PPOSXGlue_RetinaDrawingArtifacts)

- (void) ppOSXPatch_SetNeedsDisplayInRect: (NSRect) invalidRect
{
    [self ppOSXPatch_SetNeedsDisplayInRect: NSInsetRect(invalidRect, -1.0f, -1.0f)];
}

@end

@implementation PPPreviewView (PPOSXGlue_RetinaDrawingArtifacts)

- (void) ppOSXPatch_SetNeedsDisplayInRect: (NSRect) invalidRect
{
    // only need to expand invalidRect within the bounds of _scaleImageBounds; area outside
    // _scaledImageBounds is always filled with the same color, so no drawing-artifacts there

    invalidRect = NSUnionRect(invalidRect,
                              NSIntersectionRect(_scaledImageBounds,
                                                 NSInsetRect(invalidRect, -1.0f, -1.0f)));

    [self ppOSXPatch_SetNeedsDisplayInRect: invalidRect];
}

@end

#endif  // defined(__APPLE__) && (PP_DEPLOYMENT_TARGET_SUPPORTS_RETINA_DISPLAY)
