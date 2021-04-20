/*
  PPDocumentSheetController.m

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

#import "PPDocumentSheetController.h"


@implementation PPDocumentSheetController

- (id)initWithNibNamed:(NSString *)nibName delegate:(id)delegate {
    self = [super init];

    if (!self) {
        goto ERROR;
    }

    if (!nibName || !delegate) {
        goto ERROR;
    }

    NSLog(@"nib name passed = %@", [nibName description]);
    //check
    // si modernizamos la API deprecada la aplicacion se cuelga al seleccionar el size del lienzo y apretar return
    // esto no sucede en las otras secciones donde se utiliza el metodo nuevo, en donde se pasa una string macro en el nibname
    //if (![[NSBundle mainBundle] loadNibNamed:nibName owner:self topLevelObjects:nil]) {
    if (![NSBundle loadNibNamed: nibName owner: self]) {
        goto ERROR;
    }
    _delegate = delegate;
    return self;

 ERROR:
    [self release];
    return nil;
}

- (id)init {
    return [self initWithNibNamed:nil delegate:nil];
}

- (void)dealloc {
    [_sheet release];
    [super dealloc];
}

- (bool)beginSheetModalForWindow:(NSWindow *)window {
    if (![window isVisible] || [_sheet isVisible]) {
        goto ERROR;
    }

    /*[NSApp beginSheet: _sheet
      modalForWindow: window
      modalDelegate: self
      didEndSelector: @selector(didEndSheet:returnCode:contextInfo:)
      contextInfo: nil];*/

    //check
    [window beginSheet:_sheet completionHandler:^(NSInteger result) {
            //if (result == 1) NSLog(@"1");
            //if (result == 0) NSLog(@"0");
        }];

    [self retain];
    return YES;

 ERROR:
    return NO;
}

- (void)endSheet {
    if (![_sheet isVisible]) {
        return;
    }

    [NSApp endSheet:_sheet];
    [self autorelease];
}

#pragma mark Actions

- (IBAction)OKButtonPressed:(id)sender {
    [self endSheet];
    [self notifyDelegateSheetDidFinish];
}

- (IBAction)cancelButtonPressed:(id)sender {
    [self endSheet];
    [self notifyDelegateSheetDidCancel];
}

#pragma mark NSApplication sheet modal delegate

- (void)didEndSheet:(NSWindow *)sheet
         returnCode:(int)returnCode
        contextInfo:(void *)contextInfo {
    [sheet orderOut:self];
}

#pragma mark Delegate notifiers

- (void) notifyDelegateSheetDidFinish {
}

- (void) notifyDelegateSheetDidCancel {
}

@end
