//
// FPDPadView.m
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


#import "FPDPadView.h"
#import "FPXboxHIDDriverKeys.h"


@implementation FPDPadView

- (id) initWithCoder: (NSCoder*)coder {
	self = [super initWithCoder: coder];
	if (self != nil) {
		_up = 0;
		_down = 0;
		_left = 0;
		_right = 0;
	}
	return self;
}


- (BOOL) isOpaque
{
	return YES;
}


- (void) setValue: (int)value forDirection: (int)direction
{
	switch(direction) {
		case kXboxDigitalDPadUp:
			_up = value;
			break;
		case kXboxDigitalDPadDown:
			_down = value;
			break;
		case kXboxDigitalDPadLeft:
			_left = value;
			break;
		case kXboxDigitalDPadRight:
			_right = value;
			break;
	}

	[self setNeedsDisplay: YES];
}


#define kCosine60	0.5
#define kSine60		0.8660254037844386

- (void) drawRect: (NSRect)rect {
	rect = NSInsetRect([self bounds], 2, 2);
	float h3 =  rect.size.height / 3.0;
	float w3 =  rect.size.width / 3.0;

	NSBezierPath* triPath = [NSBezierPath bezierPath];
	float triBase = rect.size.width / 5;
	float triHeight = kSine60 * triBase;
	[triPath moveToPoint: NSMakePoint(0, 0)];
	[triPath lineToPoint: NSMakePoint(triBase, 0)];
	[triPath lineToPoint: NSMakePoint(triBase * kCosine60, triBase * kSine60)];
	[triPath closePath];

	NSAffineTransform* transform;
	NSGraphicsContext* context = [NSGraphicsContext currentContext];
	float largeOffset = (w3 - triHeight) / 2;
	float smallOffset = (w3 - triBase) / 2;

	[XBOX_COLOR set];

	if (_left) {
		[context saveGraphicsState];

		transform = [NSAffineTransform transform];
		[transform translateXBy: w3 - largeOffset yBy: h3 + smallOffset];
		[transform rotateByDegrees: 90];
		[transform concat];
		[triPath fill];

		[context restoreGraphicsState];
	}

	if (_up) {
		[context saveGraphicsState];

		transform = [NSAffineTransform transform];
		[transform translateXBy: w3 + smallOffset + 0.5 yBy: (h3 * 2) + largeOffset + 1];
		[transform concat];
		[triPath fill];

		[context restoreGraphicsState];
	}

	if (_right) {
		[context saveGraphicsState];

		transform = [NSAffineTransform transform];
		[transform translateXBy: (w3 * 2) + largeOffset yBy: h3 + smallOffset + triBase];
		[transform rotateByDegrees: -90];
		[transform concat];
		[triPath fill];

		[context restoreGraphicsState];
	}

	if (_down) {
		[context saveGraphicsState];

		transform = [NSAffineTransform transform];
		[transform translateXBy: w3 + triBase + smallOffset + 0.5 yBy: triHeight + largeOffset];
		[transform rotateByDegrees: -180];
		[transform concat];
		[triPath fill];

		[context restoreGraphicsState];
	}
}

@end
