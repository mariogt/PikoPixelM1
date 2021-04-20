/*
    PPNavigatorPopupPanelController.m

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

#import "PPNavigatorPopupPanelController.h"

#import "PPDocument.h"
#import "PPNavigatorPopupView.h"
#import "PPDocumentWindowController.h"
#import "PPCanvasView.h"
#import "PPUIColors_Panels.h"
#import "PPCursorManager.h"
#import "NSObject_PPUtilities.h"


#define kNavigatorPopupPanelNibName  @"NavigatorPopupPanel"


@interface PPNavigatorPopupPanelController (PrivateMethods)

- (void) addAsObserverForPPCanvasViewNotifications;
- (void) removeAsObserverForPPCanvasViewNotifications;
- (void) handlePPCanvasViewNotification_ChangedZoomFactor: (NSNotification *) notification;

- (void) handlePPDocumentNotification_UpdatedMergedVisibleThumbnailImage:
                                                            (NSNotification *) notification;
- (void) handlePPDocumentNotification_UpdatedDrawingLayerThumbnailImage:
                                                            (NSNotification *) notification;
- (void) handlePPDocumentNotification_UpdatedBackgroundSettings:
                                                            (NSNotification *) notification;
- (void) handlePPDocumentNotification_ReloadedDocument: (NSNotification *) notification;

- (void) addAsObserverForPPDocumentWindowControllerNotifications;
- (void) removeAsObserverForPPDocumentWindowControllerNotifications;
- (void) handlePPDocumentWindowControllerNotification_ChangedCanvasDisplayMode:
                                                                (NSNotification *) notification;

- (void) setupWithPPDocumentWindowController:
                                    (PPDocumentWindowController *) ppDocumentWindowController;
- (void) setupWithCanvasView: (PPCanvasView *) canvasView;
- (void) updateZoomSliderPosition;

- (void) setupNavigatorViewImage;
- (void) setupNavigatorViewImageBackground;

- (void) disableNavigatorViewMouseTracking;
- (void) enableNavigatorViewMouseTracking;

@end

@implementation PPNavigatorPopupPanelController

- (void) dealloc
{
    [self setupWithPPDocumentWindowController: nil];

    [self setupWithCanvasView: nil];

    [super dealloc];
}

#pragma mark Actions

- (IBAction) zoomButtonPressed: (id) sender
{
    if (sender == _decreaseZoomButton)
    {
        [_canvasView decreaseZoomFactor];
    }
    else if (sender == _increaseZoomButton)
    {
        [_canvasView increaseZoomFactor];
    }
}

- (IBAction) zoomSliderMoved: (id) sender
{
    NSAutoreleasePool *autoreleasePool;

    [self disableNavigatorViewMouseTracking];
    [[PPCursorManager sharedManager] setCursor: [NSCursor arrowCursor]
                                        atLevel: kPPCursorLevel_PopupPanel
                                        isDraggingMouse: YES];

    autoreleasePool = [[NSAutoreleasePool alloc] init];

    _disallowUpdatesToZoomSliderPosition = YES;

    [_canvasView setZoomFactor: [_zoomSlider floatValue]];

    _disallowUpdatesToZoomSliderPosition = NO;

    [autoreleasePool release];

    [self ppPerformSelectorAtomicallyFromNewStackFrame:
                                                @selector(enableNavigatorViewMouseTracking)];
}

#pragma mark NSWindowController overrides

- (void) windowDidLoad
{
    [_zoomSlider setMinValue: kMinCanvasZoomFactor];
    [_zoomSlider setMaxValue: kMaxCanvasZoomFactor];

    // [super windowDidLoad] calls [self setupPanelForCurrentPPDocument], so any preliminary
    // setup required before calling setupPanelForCurrentPPDocument should go before this call
    [super windowDidLoad];
}

#pragma mark PPPopupPanelController overrides

+ (NSString *) panelNibName
{
    return kNavigatorPopupPanelNibName;
}

- (void) setPPDocument: (PPDocument *) ppDocument
{
    [super setPPDocument: ppDocument];

    if (!_ppDocument)
    {
        [self setupWithPPDocumentWindowController: nil];
        [self setupWithCanvasView: nil];
    }
}

- (void) addAsObserverForPPDocumentNotifications
{
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];

    if (!_ppDocument)
        return;

    [notificationCenter addObserver: self
                        selector:
                            @selector(
                            handlePPDocumentNotification_UpdatedMergedVisibleThumbnailImage:)
                        name: PPDocumentNotification_UpdatedMergedVisibleThumbnailImage
                        object: _ppDocument];

    [notificationCenter addObserver: self
                        selector:
                            @selector(
                            handlePPDocumentNotification_UpdatedDrawingLayerThumbnailImage:)
                        name: PPDocumentNotification_UpdatedDrawingLayerThumbnailImage
                        object: _ppDocument];

    [notificationCenter addObserver: self
                        selector:
                            @selector(handlePPDocumentNotification_UpdatedBackgroundSettings:)
                        name: PPDocumentNotification_UpdatedBackgroundSettings
                        object: _ppDocument];

    [notificationCenter addObserver: self
                        selector: @selector(handlePPDocumentNotification_ReloadedDocument:)
                        name: PPDocumentNotification_ReloadedDocument
                        object: _ppDocument];
}

- (void) removeAsObserverForPPDocumentNotifications
{
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];

    [notificationCenter removeObserver: self
                        name: PPDocumentNotification_UpdatedMergedVisibleThumbnailImage
                        object: _ppDocument];

    [notificationCenter removeObserver: self
                        name: PPDocumentNotification_UpdatedDrawingLayerThumbnailImage
                        object: _ppDocument];

    [notificationCenter removeObserver: self
                        name: PPDocumentNotification_UpdatedBackgroundSettings
                        object: _ppDocument];

    [notificationCenter removeObserver: self
                        name: PPDocumentNotification_ReloadedDocument
                        object: _ppDocument];
}

- (void) setupPanelForCurrentPPDocument
{
    [super setupPanelForCurrentPPDocument];

    [self setupWithPPDocumentWindowController: [_ppDocument ppDocumentWindowController]];

    [self setupWithCanvasView: [_ppDocumentWindowController canvasView]];

    [self setupNavigatorViewImage];
    [self setupNavigatorViewImageBackground];
}

- (void) setupPanelBeforeMakingVisible
{
    [super setupPanelBeforeMakingVisible];

    [_navigatorView handleWindowWillBecomeVisible];
}

- (void) setupPanelAfterVisibilityChange
{
    [super setupPanelAfterVisibilityChange];

    [_navigatorView handleWindowVisibilityChange];

    if (![self panelIsVisible])
    {
        // if the navigator popup's controls were clicked, sometimes the canvas view won't
        // receive a mouseEntered event after the popup hides, leaving the wrong cursor, so
        // force the canvas view to update its cursor:
        [_canvasView updateCursorForCurrentMouseLocation];
    }
}

- (NSColor *) backgroundColorForPopupPanel
{
    return kUIColor_NavigatorPopupPanel_Background;
}

- (void) handleDirectionCommand: (PPDirectionType) directionType
{
    switch (directionType)
    {
        case kPPDirectionType_Right:
        case kPPDirectionType_Up:
        {
            [_canvasView increaseZoomFactor];
        }
        break;

        case kPPDirectionType_Left:
        case kPPDirectionType_Down:
        {
            [_canvasView decreaseZoomFactor];
        }
        break;

        default:
        break;
    }
}

#pragma mark PPCanvasView notifications

- (void) addAsObserverForPPCanvasViewNotifications
{
    if (!_canvasView)
        return;

    [[NSNotificationCenter defaultCenter]
                            addObserver: self
                            selector:
                                @selector(handlePPCanvasViewNotification_ChangedZoomFactor:)
                            name: PPCanvasViewNotification_ChangedZoomFactor
                            object: _canvasView];
}

- (void) removeAsObserverForPPCanvasViewNotifications
{
    [[NSNotificationCenter defaultCenter] removeObserver: self
                                            name: PPCanvasViewNotification_ChangedZoomFactor
                                            object: _canvasView];
}

- (void) handlePPCanvasViewNotification_ChangedZoomFactor: (NSNotification *) notification
{
    [self updateZoomSliderPosition];
}

#pragma mark PPDocument notifications

- (void) handlePPDocumentNotification_UpdatedMergedVisibleThumbnailImage:
                                                            (NSNotification *) notification
{
    if (_navigatorViewImageDisplayMode == kPPLayerDisplayMode_VisibleLayers)
    {
        [_navigatorView handleUpdateToImage];
    }
}

- (void) handlePPDocumentNotification_UpdatedDrawingLayerThumbnailImage:
                                                                (NSNotification *) notification
{
    if (_navigatorViewImageDisplayMode == kPPLayerDisplayMode_DrawingLayerOnly)
    {
        [_navigatorView handleUpdateToImage];
    }
}

- (void) handlePPDocumentNotification_UpdatedBackgroundSettings:
                                                            (NSNotification *) notification
{
    [self setupNavigatorViewImageBackground];
}

- (void) handlePPDocumentNotification_ReloadedDocument: (NSNotification *) notification
{
    [self setupPanelForCurrentPPDocument];
}

#pragma mark PPDocumentWindowController notifications

- (void) addAsObserverForPPDocumentWindowControllerNotifications
{
    if (!_ppDocumentWindowController)
        return;

    [[NSNotificationCenter defaultCenter]
        addObserver: self
        selector:
            @selector(handlePPDocumentWindowControllerNotification_ChangedCanvasDisplayMode:)
        name: PPDocumentWindowControllerNotification_ChangedCanvasDisplayMode
        object: _ppDocumentWindowController];
}

- (void) removeAsObserverForPPDocumentWindowControllerNotifications
{
    [[NSNotificationCenter defaultCenter]
                        removeObserver: self
                        name: PPDocumentWindowControllerNotification_ChangedCanvasDisplayMode
                        object: _ppDocumentWindowController];
}

- (void) handlePPDocumentWindowControllerNotification_ChangedCanvasDisplayMode:
                                                                (NSNotification *) notification
{
    [self setupNavigatorViewImage];
}

#pragma mark Private methods

- (void) setupWithPPDocumentWindowController:
                                    (PPDocumentWindowController *) ppDocumentWindowController
{
    if (_ppDocumentWindowController == ppDocumentWindowController)
    {
        return;
    }

    if (_ppDocumentWindowController)
    {
        [self removeAsObserverForPPDocumentWindowControllerNotifications];
    }

    [_ppDocumentWindowController release];
    _ppDocumentWindowController = [ppDocumentWindowController retain];

    if (_ppDocumentWindowController)
    {
        [self addAsObserverForPPDocumentWindowControllerNotifications];
    }
}

- (void) setupWithCanvasView: (PPCanvasView *) canvasView
{
    if (_canvasView == canvasView)
    {
        return;
    }

    if (_canvasView)
    {
        [self removeAsObserverForPPCanvasViewNotifications];
    }

    [_canvasView release];
    _canvasView = [canvasView retain];

    if (_canvasView)
    {
        [self addAsObserverForPPCanvasViewNotifications];
    }

    [_navigatorView setCanvasView: canvasView];

    [self updateZoomSliderPosition];
}

- (void) updateZoomSliderPosition
{
    if (_disallowUpdatesToZoomSliderPosition)
        return;

    [_zoomSlider setFloatValue: [_canvasView zoomFactor]];
}

- (void) setupNavigatorViewImage
{
    NSImage *navigatorImage;

    _navigatorViewImageDisplayMode = [_ppDocumentWindowController canvasDisplayMode];

    if (_navigatorViewImageDisplayMode == kPPLayerDisplayMode_DrawingLayerOnly)
    {
        navigatorImage = [_ppDocument dissolvedDrawingLayerThumbnailImage];
    }
    else
    {
        navigatorImage = [_ppDocument mergedVisibleLayersThumbnailImage];
    }

    [_navigatorView setImage: navigatorImage];
}

- (void) setupNavigatorViewImageBackground
{
    NSImage *backgroundImage;

    backgroundImage = ([_ppDocument shouldDisplayBackgroundImage]) ?
                            [_ppDocument backgroundImage] : nil;

    [_navigatorView setBackgroundPattern: [_ppDocument backgroundPattern]
                    andBackgroundImage: backgroundImage];
}

- (void) disableNavigatorViewMouseTracking
{
    [_navigatorView disableMouseTracking: YES];
}

- (void) enableNavigatorViewMouseTracking
{
    [_navigatorView disableMouseTracking: NO];
}

@end
