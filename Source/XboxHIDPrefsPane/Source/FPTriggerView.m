//
// FPTriggerView.m
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


#import "FPTriggerView.h"


@implementation FPTriggerView

- (BOOL) isOpaque
{
	return YES;
}


- (void) setMax: (int)max
{
	_max = max;
	[self setNeedsDisplay: YES];
}


- (void) setValue: (int)value
{
	_value = value;
	[self setNeedsDisplay: YES];
}


- (void) drawRect: (NSRect)rect {

	rect = [self bounds];
	NSRect clip = NSInsetRect(rect, 0, 3);
NSLog(@"value[%.3f] max[%.3f]\n", _value, _max);
	clip.size.height = floor(_value * clip.size.height/_max) + 0.5;
	NSBezierPath* path = [NSBezierPath bezierPathWithRect: clip];

	[[NSColor grayColor] set];  // erase background
	NSRectFill(rect);

	[XBOX_COLOR set];
	NSRectFill(clip);

	[[NSColor colorWithCalibratedWhite: 0.125 alpha: 0.5] set];
	[path stroke];

	[super drawRect: rect];
}

@end
