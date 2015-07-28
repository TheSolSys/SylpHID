//
// FPConfigPopUp.m
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

#import "FPConfigPopUp.h"

#import "FPXboxHIDPrefsLoader.h"


@implementation FPConfigPopUp

- (id) initWithCoder: (NSCoder*)coder
{
	self = [super initWithCoder: coder];
	if (self != nil) {
		_appConfig = nil;
		_devConfig = nil;
		_appIcon = nil;

		_appFrom.origin = NSMakePoint(0,0);
		_appFrom.size = [_appIcon size];

		_appDraw.origin = NSMakePoint([self frame].size.width - 34, 3);
		_appDraw.size = NSMakeSize(14, 14);
	}

	return self;
}




- (void) selectItemForAppConfig: (NSDictionary*)appconfig withDeviceConfig: (NSString*)devconfig
{
	_appConfig = appconfig;

	_devConfig = devconfig;

	NSString* config = [_appConfig objectForKey: kNoticeConfigKey];
	NSString* path = [[NSWorkspace sharedWorkspace] absolutePathForAppBundleWithIdentifier: [appconfig objectForKey: kNoticeAppKey]];

	if (path != nil) {
		_appIcon = [[NSWorkspace sharedWorkspace] iconForFile: path];
	} else {
		NSBundle* bundle = [NSBundle bundleForClass: [self class]];
		_appIcon = [[NSImage alloc] initWithContentsOfFile: [bundle pathForResource:@"iconAppSmallTemplate" ofType:@"png"]];
	}

	_appFrom.origin = NSMakePoint(0,0);
	_appFrom.size = [_appIcon size];

	[self selectItemWithTitle: config];

	if ([_devConfig isEqualToString: config] == NO)
		[[self itemWithTitle: _devConfig] setState: NSMixedState];
}


- (void) clearAppConfig
{
	if (_appConfig) {
		[[self itemWithTitle: _devConfig] setState: NSOffState];

		_appConfig = nil;

		_devConfig = nil;

		_appIcon = nil;

		[self setNeedsDisplay];
	}
}


- (void)drawRect:(NSRect)dirty
{
    [super drawRect: dirty];

	if (_appIcon != nil)
	   [_appIcon drawInRect: _appDraw fromRect: _appFrom operation: NSCompositeSourceAtop fraction: 1.0 respectFlipped: YES hints: NULL];
}

@end
