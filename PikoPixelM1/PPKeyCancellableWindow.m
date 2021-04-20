/*
    PPKeyCancellableWindow.m

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

#import "PPKeyCancellableWindow.h"

#import "PPKeyConstants.h"
#import "NSObject_PPUtilities.h"


#define kHiddenButtonFrame              NSMakeRect(-1,-1,1,1)


@interface PPKeyCancellableWindow (PrivateMethods)

- (void) addHiddenButtonWithKeyEquivalent: (NSString *) keyEquivalent
                        modifierMask: (unsigned int) modifierMask
                        actionSelector: (SEL) actionSelector;

- (void) performCancelButtonClick: (id) sender;
- (void) performCancelButtonClickAndTerminate: (id) sender;

@end

@implementation PPKeyCancellableWindow

#pragma mark NSWindow overrides

- (void) awakeFromNib
{
    // check before calling [super awakeFromNib] - before 10.6, some classes didn't implement it
    if ([[PPKeyCancellableWindow superclass] instancesRespondToSelector:
                                                                    @selector(awakeFromNib)])
    {
        [super awakeFromNib];
    }

    [self addHiddenButtonWithKeyEquivalent: @"w"
            modifierMask: NSCommandKeyMask
            actionSelector: @selector(performCancelButtonClick:)];

    [self addHiddenButtonWithKeyEquivalent: @"."
            modifierMask: NSCommandKeyMask
            actionSelector: @selector(performCancelButtonClick:)];

    [self addHiddenButtonWithKeyEquivalent: kEscKey
            modifierMask: 0
            actionSelector: @selector(performCancelButtonClick:)];

    [self addHiddenButtonWithKeyEquivalent: @"q"
            modifierMask: NSCommandKeyMask
            actionSelector: @selector(performCancelButtonClickAndTerminate:)];
}

#pragma mark Private methods

- (void) addHiddenButtonWithKeyEquivalent: (NSString *) keyEquivalent
                        modifierMask: (unsigned int) modifierMask
                        actionSelector: (SEL) actionSelector
{
    NSButton *button;

    if (![keyEquivalent length] || !actionSelector)
    {
        goto ERROR;
    }

    button = [[[NSButton alloc] initWithFrame: kHiddenButtonFrame] autorelease];

    if (!button)
        goto ERROR;

    [button setKeyEquivalentModifierMask: modifierMask];
    [button setKeyEquivalent: keyEquivalent];

    [button setTarget: self];
    [button setAction: actionSelector];

    [[self contentView] addSubview: button];

    return;

ERROR:
    return;
}

- (void) performCancelButtonClick: (id) sender
{
    [_cancelButton performClick: self];
}

- (void) performCancelButtonClickAndTerminate: (id) sender
{
    [self performCancelButtonClick: self];

    [NSApp ppPerformSelectorFromNewStackFrame: @selector(terminate:)];
}

@end
