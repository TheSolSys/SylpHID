//
// FPBoxLine.m
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

#import "FPBoxLine.h"


@implementation FPBoxLine

- (id) initWithCoder: (NSCoder*)coder
{
	self = [super initWithCoder: coder];
	if (self != nil) {
		_light = [[NSGradient alloc] initWithColorsAndLocations: [NSColor colorWithCalibratedWhite: 1.0 alpha: 0.0], 0.0,
		/* light white */										 [NSColor colorWithCalibratedWhite: 1.0 alpha: 0.5], 0.35,
																 [NSColor colorWithCalibratedWhite: 1.0 alpha: 0.5], 0.65,
																 [NSColor colorWithCalibratedWhite: 1.0 alpha: 0.0], 1.0, nil];
		_dark = [[NSGradient alloc] initWithColorsAndLocations: [NSColor colorWithCalibratedWhite: 0.66 alpha: 0.0], 0.0,
		/* dark grey */											[NSColor colorWithCalibratedWhite: 0.66 alpha: 1.0], 0.15,
																[NSColor colorWithCalibratedWhite: 0.66 alpha: 1.0], 0.85,
																[NSColor colorWithCalibratedWhite: 0.66 alpha: 0.0], 1.0, nil];

	}

	return self;
}


- (void)drawRect:(NSRect)dirty
{
	NSSize size = self.frame.size;
	[_light drawInRect: NSMakeRect(0, size.height - 5, size.width, 1) angle: 0];
	[_dark drawInRect: NSMakeRect(0, size.height - 4, size.width, 1) angle: 0];
}

@end
