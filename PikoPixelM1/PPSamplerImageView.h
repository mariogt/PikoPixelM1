/*
    PPSamplerImageView.h

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

#import <Cocoa/Cocoa.h>
#import "PPSamplerImagePanelType.h"
#import "PPResizableDirectionsMasks.h"


@class PPDocumentSamplerImage;

@interface PPSamplerImageView : NSView
{
    PPSamplerImagePanelType _panelType;

    float _minViewDimension;
    float _maxViewDimension;
    float _defaultImageDimension;

    id _delegate;

    PPDocumentSamplerImage *_samplerImage;
    NSRect _imageFrame;
    NSRect _imageDrawBounds;

    NSRect _imageBoundsTrackingRect;
    NSTrackingRectTag _imageBoundsTrackingRectTag;

    float _minScaleForCurrentImage;
    float _maxScaleForCurrentImage;

    NSColor *_lastSampledColor;

    bool _mouseIsSamplingImage;
    bool _mouseIsInsideImageBoundsTrackingRect;
    bool _disallowMouseTracking;
}

- (void) setSamplerImagePanelType: (PPSamplerImagePanelType) panelType
            minViewDimension: (float) minViewDimension
            maxViewDimension: (float) maxViewDimension
            defaultImageDimension: (float) defaultImageDimension
            delegate: (id) delegate;

- (void) setSamplerImage: (PPDocumentSamplerImage *) samplerImage;

- (NSSize) viewSizeForResizingToProposedViewSize: (NSSize) proposedViewSize
            resizableDirectionsMask: (unsigned) resizableDirectionsMask;
- (NSSize) viewSizeForScaledCurrentSamplerImage;

- (void) setupMouseTracking;
- (void) disableMouseTracking: (bool) shouldDisableTracking;

- (bool) mouseIsSamplingImage;
- (void) forceStopSamplingImage;

@end

@interface NSObject (PPSamplerImageViewDelegateMethods)

- (void) ppSamplerImageView: (PPSamplerImageView *) samplerImageView
            didBrowseColor: (NSColor *) color;

- (void) ppSamplerImageView: (PPSamplerImageView *) samplerImageView
            didSelectColor: (NSColor *) color;

- (void) ppSamplerImageViewDidCancelSelection: (PPSamplerImageView *) samplerImageView;

@end
