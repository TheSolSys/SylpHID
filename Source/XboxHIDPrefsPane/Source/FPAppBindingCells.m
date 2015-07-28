//
// FPAppTextFieldCell.m
// "Xbox HID"
//
// Created by Paige Marie DePol <pmd@fizzypopstudios.com>
// Copyright (c)2015 FizzyPop Studios. All Rights Reserved.
// http://xboxhid.fizzypopstudios.com
//
// =========================================================================================================================
// This file is part of the Xbox HID Driver, Daemon, and Preference Pane software (known as "Xbox HID").
//
// "Xbox HID" is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.
//
// "Xbox HID" is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty
// of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License along with "Xbox HID";
// if not, write to the Free Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
// =========================================================================================================================

#import "FPAppBindingCells.h"


// for adding custom highlight
@implementation FPAppTableView

- (id) initWithCoder: (NSCoder*)coder
{
	self = [super initWithCoder: coder];
	if (self != nil) {
		_gradient = [[NSGradient alloc] initWithColorsAndLocations: [NSColor keyboardFocusIndicatorColor], 0.0,
																	[NSColor alternateSelectedControlColor], 1.0, nil];
	}
	return self;
}

- (void)highlightSelectionInClipRect: (NSRect)clipRect
{
	NSInteger rowSelected = [self selectedRow];
	if (rowSelected > -1) {
		NSRect rowRect = [self rectOfRow: rowSelected];
		rowRect.size.height -= 1;
		rowRect.size.width -= 1.5;
		[_gradient drawInBezierPath: [NSBezierPath bezierPathWithRoundedRect: rowRect xRadius: 6 yRadius: 6] angle: 90];
	}
}


- (void) mouseDown: (NSEvent*)event
{
    NSPoint point = [self convertPoint: [event locationInWindow] fromView: nil];
    NSInteger row = [self rowAtPoint: point];

    if (row == -1)
        [self deselectAll:nil];
	else
		[super mouseDown: event];
}

@end


// for adding padding (2px) above text
@implementation FPAppTextFieldCell

- (void) drawInteriorWithFrame: (NSRect)cellFrame inView:(NSView *)controlView
{
	cellFrame.origin.y += 2;
	cellFrame.size.height -= 2;
	[super drawInteriorWithFrame: cellFrame inView: controlView];
}

@end


// for adding padding (1px) around icon
@implementation FPAppImageCell

- (void) drawInteriorWithFrame: (NSRect)cellFrame inView:(NSView *)controlView
{
	cellFrame = NSInsetRect(cellFrame, 1, 1);
	[super drawInteriorWithFrame: cellFrame inView: controlView];
}

@end
