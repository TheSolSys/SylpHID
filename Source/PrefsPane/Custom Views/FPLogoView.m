//
// FPLogoView.m
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

#import "FPLogoView.h"


@implementation FPLogoView

- (id) initWithCoder: (NSCoder*)coder
{
	self = [super initWithCoder: coder];
	if (self != nil) {
		NSRect frame = [self frame];
		NSBundle* bundle = [NSBundle bundleForClass: [self class]];
		_colors = [[NSImage alloc] initWithContentsOfFile: [bundle pathForResource:@"logoColors" ofType:@"png"]];

		_toRect.origin = NSMakePoint(14, 14);
		_toRect.size = NSMakeSize(75, 14);

		_fromRectTop.origin = NSMakePoint(0, 0);
		_fromRectTop.size = frame.size;
		_anidirTop = NSMakePoint(0.66, -1.25);

		_fromRectBot.origin = NSMakePoint([_colors size].width - frame.size.width, [_colors size].height - frame.size.height);
		_fromRectBot.size = frame.size;
		_anidirBot = NSMakePoint(-1.33, 0.75);

		_timer = [NSTimer scheduledTimerWithTimeInterval: 1.0/20.0
												  target: self
												selector: @selector(logoAnimation:)
												userInfo: nil
												 repeats: YES];
	}

	return self;
}


- (void) dealloc
{
	[_timer invalidate];

}


- (void) logoAnimation: (id)object
{
	_fromRectBot.origin.x += _anidirBot.x;
	if (_fromRectBot.origin.x < 0 || _fromRectBot.origin.x >= [_colors size].width - [self frame].size.width)
		_anidirBot.x = -_anidirBot.x;

	_fromRectBot.origin.y += _anidirBot.y;
	if (_fromRectBot.origin.y < 0 || _fromRectBot.origin.y >= [_colors size].height - [self frame].size.height)
		_anidirBot.y = -_anidirBot.y;

	_fromRectTop.origin.x += _anidirTop.x;
	if (_fromRectTop.origin.x < 0 || _fromRectTop.origin.x >= [_colors size].width - [self frame].size.width)
		_anidirTop.x = -_anidirTop.x;

	_fromRectTop.origin.y += _anidirTop.y;
	if (_fromRectTop.origin.y < 0 || _fromRectTop.origin.y >= [_colors size].height - [self frame].size.height)
		_anidirTop.y = -_anidirTop.y;

	[self setNeedsDisplay];
}


- (void) drawRect: (NSRect)dirty
{
	[[NSColor controlColor] set];
	NSRectFill(dirty);

	[_colors drawInRect: _toRect	fromRect: _fromRectBot	operation: NSCompositeSourceOver
			   fraction: 1.0  respectFlipped: YES				hints: NULL];

	[_colors drawInRect: _toRect	fromRect: _fromRectTop	operation: NSCompositeSourceOver
			   fraction: 0.5  respectFlipped: NO				hints: NULL];

	[super drawRect: dirty];
}

@end
