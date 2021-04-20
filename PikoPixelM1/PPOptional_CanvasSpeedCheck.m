/*
    PPOptional_CanvasSpeedCheck.m

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

#import "PPOptional.h"
#if PP_OPTIONAL__BUILD_WITH_CANVAS_SPEED_CHECK

#import <Cocoa/Cocoa.h>
#import "PPAppBootUtilities.h"
#import "PPApplication.h"
#import "NSObject_PPUtilities.h"
#import "PPDocumentWindowController.h"
#import "PPDocument.h"
#import "PPCanvasView.h"
#import "PPTool.h"
#import "PPToolbox.h"
#import "PPGeometry.h"


#define kSpeedCheckMenuItem_Name                        @"Canvas Speed Check"
#define kSpeedCheckMenuItem_KeyEquivalent               @" "
#define kSpeedCheckMenuItem_KeyEquivalentModifierMask   \
                                    (NSCommandKeyMask | NSShiftKeyMask | NSControlKeyMask)


#define kNumSpeedCheckDragMovements                     100


@interface PPApplication (PPOptional_CanvasSpeedCheck)

- (void) ppMenuItemSelected_CanvasSpeedCheck: (id) sender;

@end

@implementation NSObject (PPOptional_CanvasSpeedCheck)

+ (void) load
{
    macroPerformNSObjectSelectorAfterAppLoads(ppOptional_CanvasSpeedCheck_SetupMenuItem);
}

+ (void) ppOptional_CanvasSpeedCheck_SetupMenuItem
{
    NSMenu *canvasMenu;
    NSMenuItem *speedCheckItem;
        // use PPSDKNativeType_NSMenuItemPtr for separatorItem, as -[NSMenu separatorItem]
        // could return either (NSMenuItem *) or (id <NSMenuItem>), depending on the SDK
    PPSDKNativeType_NSMenuItemPtr separatorItem;

    canvasMenu = [[[NSApp mainMenu] itemWithTitle: @"Canvas"] submenu];

    speedCheckItem  =
                [[[NSMenuItem alloc] initWithTitle: kSpeedCheckMenuItem_Name
                                        action: @selector(ppMenuItemSelected_CanvasSpeedCheck:)
                                        keyEquivalent: kSpeedCheckMenuItem_KeyEquivalent]
                                autorelease];

    [speedCheckItem setTarget: NSApp];
    [speedCheckItem setKeyEquivalentModifierMask: kSpeedCheckMenuItem_KeyEquivalentModifierMask];

    separatorItem = [NSMenuItem separatorItem];

    if (!canvasMenu || !speedCheckItem || !separatorItem)
    {
        goto ERROR;
    }

    [canvasMenu addItem: separatorItem];
    [canvasMenu addItem: speedCheckItem];

    return;

ERROR:
    return;
}

@end

@implementation PPApplication (PPOptional_CanvasSpeedCheck)

- (void) ppMenuItemSelected_CanvasSpeedCheck: (id) sender
{
    NSAutoreleasePool *autoreleasePool;
    PPDocumentWindowController *documentWindowController;
    PPDocument *ppDocument;
    PPCanvasView *canvasView;
    PPTool *lineTool;
    NSPoint point1, point2;
    NSTimeInterval totalTime;
    NSDate *startDate;
    int dragLoopCount = 0;
    NSRect drawRect;

    autoreleasePool = [[NSAutoreleasePool alloc] init];

    documentWindowController = [[NSApp mainWindow] windowController];

    if (![documentWindowController isKindOfClass: [PPDocumentWindowController class]])
    {
        return;
    }

    ppDocument = [documentWindowController document];
    canvasView = [documentWindowController canvasView];

    lineTool = [[PPToolbox sharedToolbox] toolOfType: kPPToolType_Line];

    // Line tool - corner to corner

    point1 = NSZeroPoint;
    point2 =
        NSMakePoint([ppDocument canvasSize].width - 1.0, [ppDocument canvasSize].height - 1.0);

    [canvasView setIsDraggingTool: YES];

    [lineTool mouseDownForDocument: ppDocument
                withCanvasView: canvasView
                currentPoint: point1
                modifierKeyFlags: 0];

    startDate = [[NSDate date] retain];
    totalTime = 0;

    dragLoopCount = kNumSpeedCheckDragMovements;

    while (dragLoopCount--)
    {
        [autoreleasePool release];
        autoreleasePool = [[NSAutoreleasePool alloc] init];

        totalTime -= [NSDate timeIntervalSinceReferenceDate];

        [lineTool mouseDraggedOrModifierKeysChangedForDocument: ppDocument
                    withCanvasView: canvasView
                    currentPoint: point2
                    lastPoint: point1
                    mouseDownPoint: point1
                    modifierKeyFlags: 0];

        [canvasView displayIfNeeded];

        [lineTool mouseDraggedOrModifierKeysChangedForDocument: ppDocument
                    withCanvasView: canvasView
                    currentPoint: point1
                    lastPoint: point2
                    mouseDownPoint: point1
                    modifierKeyFlags: 0];

        [canvasView displayIfNeeded];

        totalTime += [NSDate timeIntervalSinceReferenceDate];
    }

    [lineTool mouseUpForDocument: ppDocument
                withCanvasView: canvasView
                currentPoint: point1
                mouseDownPoint: point1
                modifierKeyFlags: 0];


    [canvasView setIsDraggingTool: NO];

    NSLog(@"Speed check: LINE TOOL, CORNERS - time elapsed: %f (%f)", (float) totalTime,
            (float) -[startDate timeIntervalSinceNow]);


    // Line tool - small draw

    drawRect = PPGeometry_CenterRectInRect(PPGeometry_OriginRectOfSize(NSMakeSize(8,8)),
                                            PPGeometry_OriginRectOfSize([ppDocument canvasSize]));

    point1 = drawRect.origin;
    point2 =
        NSMakePoint(point1.x + drawRect.size.width - 1, point1.y + drawRect.size.height - 1);

    [canvasView setIsDraggingTool: YES];

    [lineTool mouseDownForDocument: ppDocument
                withCanvasView: canvasView
                currentPoint: point1
                modifierKeyFlags: 0];

    [startDate release];
    startDate = [[NSDate date] retain];
    totalTime = 0;

    dragLoopCount = kNumSpeedCheckDragMovements;

    while (dragLoopCount--)
    {
        [autoreleasePool release];
        autoreleasePool = [[NSAutoreleasePool alloc] init];

        totalTime -= [NSDate timeIntervalSinceReferenceDate];

        [lineTool mouseDraggedOrModifierKeysChangedForDocument: ppDocument
                    withCanvasView: canvasView
                    currentPoint: point2
                    lastPoint: point1
                    mouseDownPoint: point1
                    modifierKeyFlags: 0];

        [canvasView displayIfNeeded];

        [lineTool mouseDraggedOrModifierKeysChangedForDocument: ppDocument
                    withCanvasView: canvasView
                    currentPoint: point1
                    lastPoint: point2
                    mouseDownPoint: point1
                    modifierKeyFlags: 0];

        [canvasView displayIfNeeded];

        totalTime += [NSDate timeIntervalSinceReferenceDate];
    }

    [lineTool mouseUpForDocument: ppDocument
                withCanvasView: canvasView
                currentPoint: point1
                mouseDownPoint: point1
                modifierKeyFlags: 0];


    [canvasView setIsDraggingTool: NO];

    NSLog(@"Speed check: LINE TOOL, SMALL DRAW - time elapsed: %f (%f)", (float) totalTime,
            (float) -[startDate timeIntervalSinceNow]);


    // Zooming

    [startDate release];
    startDate = [[NSDate date] retain];
    totalTime = 0;

    int initialZoomFactor = [canvasView zoomFactor], zoomCounter;

    for (zoomCounter=1; zoomCounter<=kMaxCanvasZoomFactor; zoomCounter++)
    {
        [autoreleasePool release];
        autoreleasePool = [[NSAutoreleasePool alloc] init];

        totalTime -= [NSDate timeIntervalSinceReferenceDate];

        [canvasView setZoomFactor: zoomCounter];
        [canvasView displayIfNeeded];

        totalTime += [NSDate timeIntervalSinceReferenceDate];
    }

    [canvasView setZoomFactor: initialZoomFactor];

    NSLog(@"Speed check: ZOOMING - time elapsed: %f (%f)", (float) totalTime,
            (float) -[startDate timeIntervalSinceNow]);


    // Redrawing background

    [startDate release];
    startDate = [[NSDate date] retain];
    totalTime = 0;

    dragLoopCount = kNumSpeedCheckDragMovements;

    while (dragLoopCount--)
    {
        [autoreleasePool release];
        autoreleasePool = [[NSAutoreleasePool alloc] init];

        totalTime -= [NSDate timeIntervalSinceReferenceDate];

        [canvasView performSelector: @selector(updateVisibleBackground)];
        [canvasView displayIfNeeded];

        totalTime += [NSDate timeIntervalSinceReferenceDate];
    }

    [canvasView setZoomFactor: initialZoomFactor];

    NSLog(@"Speed check: REDRAW BACKGROUND - time elapsed: %f (%f)", (float) totalTime,
            (float) -[startDate timeIntervalSinceNow]);

    [startDate release];
}

@end

#endif  // PP_OPTIONAL__BUILD_WITH_CANVAS_SPEED_CHECK
