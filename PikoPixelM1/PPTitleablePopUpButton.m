/*
    PPTitleablePopUpButton.m

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

#import "PPTitleablePopUpButton.h"

#import "NSObject_PPUtilities.h"


@interface PPTitleablePopUpButton (PrivateMethods)

- (void) addAsObserverForNSPopUpButtonNotifications;
- (void) removeAsObserverForNSPopUpButtonNotifications;
- (void) handleNSPopUpButtonNotification_WillPopUp: (NSNotification *) notification;

- (void) addAsObserverForNSMenuNotifications;
- (void) removeAsObserverForNSMenuNotifications;
- (void) handleNSMenuNotification_WillSendAction: (NSNotification *) notification;
- (void) handleNSMenuNotification_DidEndTracking: (NSNotification *) notification;

- (void) updateTitle;
- (void) updateTitleFromNewStackFrame;

- (NSString *) displayTitleFromDelegateForSelectedMenuItem;
- (NSDictionary *) titleTextAttributesFromDelegateForSelectedMenuItem;
- (void) notifyDelegateWillDisplayPopupMenu;

@end

@implementation PPTitleablePopUpButton

- (void) dealloc
{
    [self removeAsObserverForNSPopUpButtonNotifications];
    [self removeAsObserverForNSMenuNotifications];

    [_popupMenu release];

    [super dealloc];
}

- (void) setTitle: (NSString *) title withTextAttributes: (NSDictionary *) textAttributes
{
    NSMenu *menu;
    NSMenuItem *menuItem;
    NSAttributedString *attributedTitle;

    if (!title)
    {
        title = @"";
    }

    if (!textAttributes)
    {
        [self setTitle: title];

        return;
    }

    menu = [[[NSMenu alloc] init] autorelease];

    menuItem = [[[NSMenuItem alloc] initWithTitle: title action: NULL keyEquivalent: @""]
                                autorelease];

    attributedTitle = [[[NSAttributedString alloc] initWithString: title
                                                    attributes: textAttributes]
                                                autorelease];

    if (!menu || !menuItem || !attributedTitle)
    {
        goto ERROR;
    }

    [menuItem setAttributedTitle: attributedTitle];

    [menu addItem: menuItem];

    [super setMenu: menu];

    return;

ERROR:
    [self setTitle: title];

    return;
}

- (void) setDelegate: (id) delegate
{
    _delegate = delegate;
}

#pragma mark NSPopUpButton overrides

- (void) awakeFromNib
{
    // check before calling [super awakeFromNib] - before 10.6, some classes didn't implement it
    if ([[PPTitleablePopUpButton superclass] instancesRespondToSelector:
                                                                    @selector(awakeFromNib)])
    {
        [super awakeFromNib];
    }

    [_popupMenu autorelease];
    _popupMenu = [[super menu] copy];

    _indexOfSelectedPopupMenuItem = [self indexOfSelectedItem];

    [self updateTitle];

    [self addAsObserverForNSPopUpButtonNotifications];
}

- (void) setMenu: (NSMenu *) menu
{
    if (_popupMenu)
    {
        [self removeAsObserverForNSMenuNotifications];

        [_popupMenu autorelease];
    }

    _popupMenu = [menu copy];
}

- (NSMenu *) menu
{
    return _popupMenu;
}

- (void) selectItemAtIndex: (NSInteger) index
{
    _indexOfSelectedPopupMenuItem = index;

    [self updateTitle];
}

- (void) setTitle: (NSString *) aString
{
    if (!aString)
    {
        aString = @"";
    }

    [super removeAllItems];
    [super addItemWithTitle: aString];
}

- (NSInteger) indexOfSelectedItem
{
    return _indexOfSelectedPopupMenuItem;
}

#pragma mark NSPopUpButton notifications

- (void) addAsObserverForNSPopUpButtonNotifications
{
    [[NSNotificationCenter defaultCenter]
                                addObserver: self
                                selector: @selector(handleNSPopUpButtonNotification_WillPopUp:)
                                name: NSPopUpButtonWillPopUpNotification
                                object: self];
}

- (void) removeAsObserverForNSPopUpButtonNotifications
{
    [[NSNotificationCenter defaultCenter] removeObserver: self
                                            name: NSPopUpButtonWillPopUpNotification
                                            object: self];
}

- (void) handleNSPopUpButtonNotification_WillPopUp: (NSNotification *) notification
{
    [self notifyDelegateWillDisplayPopupMenu];

    [super setMenu: [[_popupMenu copy] autorelease]];
    [super selectItemAtIndex: _indexOfSelectedPopupMenuItem];

    [self addAsObserverForNSMenuNotifications];
}

#pragma mark NSMenu notifications

- (void) addAsObserverForNSMenuNotifications
{
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    NSMenu *menu = [super menu];

    [notificationCenter addObserver: self
                        selector: @selector(handleNSMenuNotification_WillSendAction:)
                        name: NSMenuWillSendActionNotification
                        object: menu];

    [notificationCenter addObserver: self
                        selector: @selector(handleNSMenuNotification_DidEndTracking:)
                        name: NSMenuDidEndTrackingNotification
                        object: menu];
}

- (void) removeAsObserverForNSMenuNotifications
{
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    NSMenu *menu = [super menu];

    [notificationCenter removeObserver: self
                        name: NSMenuWillSendActionNotification
                        object: menu];

    [notificationCenter removeObserver: self
                        name: NSMenuDidEndTrackingNotification
                        object: menu];
}

- (void) handleNSMenuNotification_WillSendAction: (NSNotification *) notification
{
    NSMenuItem *menuItem = [[notification userInfo] objectForKey: @"MenuItem"];

    _indexOfSelectedPopupMenuItem = [super indexOfItem: menuItem];

    // updateTitle will remove all menu items from the menu, so retain+autorelease menuItem
    // to prevent its (possible) deallocation before its action is sent
    [[menuItem retain] autorelease];

    [self updateTitle];

    [self removeAsObserverForNSMenuNotifications];
}

- (void) handleNSMenuNotification_DidEndTracking: (NSNotification *) notification
{
    [self updateTitleFromNewStackFrame];

    [self ppPerformSelectorFromNewStackFrame: @selector(removeAsObserverForNSMenuNotifications)];
}

#pragma mark Private methods

- (void) updateTitle
{
    NSString *title = [self displayTitleFromDelegateForSelectedMenuItem];
    NSDictionary *titleAttributes = [self titleTextAttributesFromDelegateForSelectedMenuItem];

    [self setTitle: title withTextAttributes: titleAttributes];
}

- (void) updateTitleFromNewStackFrame
{
    [self ppPerformSelectorFromNewStackFrame: @selector(updateTitle)];
}

#pragma mark Delegate notifiers

- (NSString *) displayTitleFromDelegateForSelectedMenuItem
{
    NSString *itemTitle, *displayTitle;

    itemTitle = [[_popupMenu itemAtIndex: _indexOfSelectedPopupMenuItem] title];

    if (!itemTitle)
    {
        itemTitle = @"";
    }

    if (![_delegate respondsToSelector: @selector(displayTitleForMenuItemWithTitle:
                                                    onTitleablePopUpButton:)])
    {
        return itemTitle;
    }

    displayTitle = [_delegate displayTitleForMenuItemWithTitle: itemTitle
                                onTitleablePopUpButton: self];

    if (!displayTitle)
    {
        displayTitle = itemTitle;
    }

    return displayTitle;
}

- (NSDictionary *) titleTextAttributesFromDelegateForSelectedMenuItem
{
    if ([_delegate respondsToSelector: @selector(titleTextAttributesForMenuItemAtIndex:
                                                    onTitleablePopUpButton:)])
    {
        return [_delegate titleTextAttributesForMenuItemAtIndex: _indexOfSelectedPopupMenuItem
                            onTitleablePopUpButton: self];
    }
    else
    {
        return nil;
    }
}

- (void) notifyDelegateWillDisplayPopupMenu
{
    if ([_delegate respondsToSelector: @selector(titleablePopUpButtonWillDisplayPopupMenu:)])
    {
        [_delegate titleablePopUpButtonWillDisplayPopupMenu: self];
    }
}

@end
