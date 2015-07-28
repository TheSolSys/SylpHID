//
// FPXboxHIDAppData.h
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


#import "FPDataSourceApps.h"

#define kAppTableMaxRows	8


@implementation FPDataSourceApps

- (id) init
{
	self = [super init];
	if (self != nil) {
		_count = 0;
		_popup = 0;
		_source = nil;
	}

	return self;
}


- (void) setSource: (NSDictionary*)source forDeviceID: (NSString*)device withTableView: (NSTableView*)table
{
	NSWorkspace* workspace = [NSWorkspace sharedWorkspace];
	_source = [[NSMutableArray alloc] init];
	_popup = [[NSPopUpButton alloc] init];

	[(id<FPAppBindings>)[table delegate] buildConfigurationPopUpButton: _popup withDefault: device forAppBinding: YES];
	[[_popup cell] setFont: [NSFont systemFontOfSize: [NSFont systemFontSizeForControlSize: NSSmallControlSize]]];
	[[_popup cell] setControlSize: NSSmallControlSize];
	[[table tableColumnWithIdentifier: NS4CC(kAppTableColumnList)] setDataCell: [_popup cell]];
	[table setRowHeight: 23];

	for (NSString* appid in source) {
		NSString* path = [workspace absolutePathForAppBundleWithIdentifier: appid];
		if (path != nil) {
			NSDictionary* bindings = [source objectForKey: appid];
			for (NSString* devid in bindings) {
				if ([device isEqualToString: devid] == YES) {
					NSString* config = [bindings objectForKey: devid];
					NSString* appname, *apptype;
					NSImage* icon = [workspace iconForFile: path];
					if ([workspace getInfoForFile: path application: &appname type: &apptype]) {
						[_source addObject: [NSArray arrayWithObjects: icon,
														[[appname lastPathComponent] stringByDeletingPathExtension],
 														[NSNumber numberWithInteger: [_popup indexOfItemWithTitle: config ]], nil]];
					}
				}
			}
		}
	}

	_count = [_source count];	// Actual min/max values set in IB, so we just use 1 and 1000 in case we change them
	[[table tableColumnWithIdentifier: NS4CC(kAppTableColumnList)] setWidth: _count > kAppTableMaxRows ? 1 : 1000];
}


- (id) tableView: (NSTableView*)tableView objectValueForTableColumn: (NSTableColumn*)tableColumn row: (NSInteger)row
{
	uint colid = NSSwapInt(*(uint*)StringToC([tableColumn identifier]));
	switch (colid) {
		case kAppTableColumnIcon:
			return [[_source objectAtIndex: row] objectAtIndex: 0];

		case kAppTableColumnName:
			return [[_source objectAtIndex: row] objectAtIndex: 1];

		case kAppTableColumnList:
			return [[_source objectAtIndex: row] objectAtIndex: 2];
	}

	return nil;
}


- (NSInteger) numberOfRowsInTableView: (NSTableView*)tableView
{
	return _count;
}

@end