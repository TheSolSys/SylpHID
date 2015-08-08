//
// FPAppTextFieldCell.m
// "SylpHID"
//
// Created by Paige Marie DePol <pmd@fizzypopstudios.com>
// Copyright (c)2015 FizzyPop Studios. All Rights Reserved.
// http://xboxhid.fizzypopstudios.com
//
// =========================================================================================================================
// This file is part of the SylpHID Driver, Daemon, and Preference Pane software (collectively known as "SylpHID").
//
// "SylpHID" is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.
//
// "SylpHID" is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty
// of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License along with "SylpHID";
// if not, write to the Free Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
// =========================================================================================================================

#import "FPAppTableView.h"
#import "FPDataSourceApps.h"


@implementation FPAppTableView

- (id) initWithCoder: (NSCoder*)coder
{
	self = [super initWithCoder: coder];
	if (self != nil) {
		_selection = -1;
		_gradient = [[NSGradient alloc] initWithColorsAndLocations: [NSColor keyboardFocusIndicatorColor], 0.0,
																	[NSColor alternateSelectedControlColor], 1.0, nil];
	}
	return self;
}


- (void) highlightSelectionInClipRect: (NSRect)clipRect
{
	NSInteger rowSelected = [self selectedRow];
	if (rowSelected > -1) {
		NSRect rowRect = [self rectOfRow: rowSelected];
		rowRect.size.height -= 1;
		rowRect.size.width -= 1.5;
		[_gradient drawInBezierPath: [NSBezierPath bezierPathWithRoundedRect: rowRect xRadius: 6 yRadius: 6] angle: 90];
	}
}


- (void) deselectAll: (id)sender
{
	[super deselectAll: sender];
	_selection = -2;
}


- (void) mouseDown: (NSEvent*)event
{
    NSPoint point = [self convertPoint: [event locationInWindow] fromView: nil];
    NSInteger row = [self rowAtPoint: point];

    if (row == -1)
        [self deselectAll: nil];
	else
		[super mouseDown: event];

	NSInteger selected = [self selectedRow];
	if (selected != _selection) {
		[(id<FPAppBindings>)[self delegate] appSelectionChanged: [(FPDataSourceApps*)[self dataSource] appIdentifierForRow: selected]];
		_selection = selected;
	}
}

@end


