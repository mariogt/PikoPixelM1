/*
    PPPreviewView.h

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
#import "PPPreviewBackgroundType.h"


@interface PPPreviewView : NSView
{
    id _delegate;

    NSImage *_image;

    float _previewScale;
    float _minimumScaleForCurrentImage;

    NSRect _imageFrame;
    NSRect _scaledImageBounds;

    PPPreviewBackgroundType _backgroundType;
    NSColor *_backgroundFillColor;

    unsigned _resizableDirectionsMask;

    bool _viewIsResizing;
}

- (void) setImage: (NSImage *) image;
- (void) handleUpdateToImage;
- (void) handleUpdateToImageInRect: (NSRect) imageUpdateRect;

- (NSSize) prepareForNewFrameSize: (NSSize) newFrameSize;

- (void) setBackgroundType: (PPPreviewBackgroundType) backgroundType;
- (void) toggleBackgroundType;

- (void) setDelegate: (id) delegate;
- (id) delegate;

@end

@interface NSObject (PPPreviewViewDelegateMethods)

- (void) ppPreviewView: (PPPreviewView *) previewView didChangeScale: (float) scale;

@end
