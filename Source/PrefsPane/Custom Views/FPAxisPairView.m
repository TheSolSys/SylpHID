//
// FPAxisPairView.m
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


#import "FPAxisPairView.h"
#import "FPXboxHIDDriverKeys.h"


@implementation FPAxisPairView

- (id) initWithCoder: (NSCoder*)coder {
	self = [super initWithCoder: coder];
	if (self) {
		_x = 0;
		_y = 0;
		_minx = kStickMin;
		_maxx = kStickMax;
		_miny = kStickMin;
		_maxy = kStickMax;
		_pressed = 0;
		_home = [self frame].origin;
	}
	return self;
}


- (void) setPressed: (BOOL)pressed
{
	_pressed = pressed;
	[self setNeedsDisplay: YES];
}


- (void) setX: (float)x
{
	_x = x;
	[self setNeedsDisplay: YES];
}


- (void) setY: (float)y
{
	_y = y;
	[self setNeedsDisplay: YES];
}


- (void) setLiveX: (float)x
{
	_livex = x;
	[self moveView];
	[self setNeedsDisplay: YES];
}


- (void) setLiveY: (float)y
{
	_livey = y;
	[self moveView];
	[self setNeedsDisplay: YES];
}


- (void) moveView
{
	float xoff = (_livex / (kStickRange / 10));
	float yoff = (_livey / (kStickRange / 10));
	[self setFrameOrigin: NSMakePoint(_home.x + xoff, _home.y + yoff)];
}


- (BOOL) isOpaque
{
	return YES;
}


- (void) drawRect: (NSRect)rect
{
	rect = [self bounds];
	NSGraphicsContext* context = [NSGraphicsContext currentContext];
	NSAffineTransform* transform = [NSAffineTransform transform];

	int size = (_pressed * 5000) + 5000;
	NSRect crossHairsRect = NSMakeRect(_x - size - 1000, _y - size, size * 2, size * 2);
	NSBezierPath* circle = [NSBezierPath bezierPathWithOvalInRect: crossHairsRect];

	[super drawRect: rect];

	[context saveGraphicsState];

	[transform scaleXBy: (rect.size.width - rect.origin.x) / (_maxx - _minx)
					yBy: -(rect.size.height - rect.origin.y) / (_maxy - _miny)];
	[transform translateXBy: (_maxx - _minx) / 2.0 yBy: (_maxy - _miny) / 2.0 - (_maxy - _miny)];
	[transform scaleXBy: 0.8 yBy: 0.8];
	[transform concat];

	[XBOX_COLOR set];
	[circle fill];

	[context restoreGraphicsState];
}

@end
