//
// FPButtonView.m
// "Xbox HID"
//
// Created by Darrell Walisser <walisser@mac.com>
// Copyright (c)2007 Darrell Walisser. All Rights Reserved.
// http://sourceforge.net/projects/xhd
//
// Forked and Modifed by macman860 <email address unknown>
// https://macman860.wordpress.com
//
// Forked and Modified by Paige Marie DePol <pmd@fizzypopstudios.com>
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


#import "FPButtonView.h"


@implementation FPButtonView

- (void) setValue: (UInt8)value
{
	_value = value;
	[self setNeedsDisplay: YES];
}


- (id) initWithCoder: (NSCoder*)coder {
	self = [super initWithCoder: coder];
	if (self) {
		_value = 0;
		_max = 255;
		_color = [NSColor grayColor];
		_overlay = YES;
	}
	return self;
}




- (void) showOverlayOnlyWhenActive
{
	_overlay = NO;
}

- (void) setMax: (int)max {
	_max = max;
}


- (void) setColor: (NSColor*)color {
	_color = color;
}


- (BOOL) isOpaque
{
	return YES;
}


- (void) drawRect: (NSRect)rect {

	rect = [self bounds];
	[_color set];

	if (_max > 1) {
		NSRect clip = NSInsetRect(rect, 0, 1);
		clip.size.height = floor(_value * clip.size.height/_max) + 0.5;
		NSBezierPath* path = [NSBezierPath bezierPathWithRect: clip];

		NSRectFill(clip);

		[[NSColor colorWithCalibratedWhite: 0.125 alpha: 0.660] set];
		[path stroke];
	} else if (_value) {
		NSRectFill(rect);
	}

	if (_value || _overlay == YES)
		[super drawRect: rect];  // Draw button overlay last
}

@end
