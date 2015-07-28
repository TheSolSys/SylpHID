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



@implementation FPDataSourceApps

- (id) init
{
	self = [super init];
	if (self != nil) {
		_count = 0;
	}

	return self;
}


- (void) dealloc
{
	if (_source != nil)
		[_source release];

	[super dealloc];
}


- (void) setSource: (NSDictionary*)source forDeviceID: (NSString*)device withTableView: (NSTableView*)table
{
	if (_source != nil)
		[_source release];
	_source = [[NSMutableArray alloc] init];
	NSWorkspace* workspace = [NSWorkspace sharedWorkspace];

	NSPopUpButton* popup = [[NSPopUpButton alloc] init];
	[(id<FPAppBinding>)[table delegate] buildConfigurationPopUpButton: popup withDefault: device forAppBinding: YES];
	[[popup cell] setFont: [NSFont systemFontOfSize: [NSFont systemFontSizeForControlSize: NSSmallControlSize]]];
	[[popup cell] setControlSize: NSSmallControlSize];
	[[table tableColumnWithIdentifier: NS4CC(kAppTableColumnList)] setDataCell: [popup cell]];
	[table setRowHeight: 25];

	for (NSString* appid in source) {
		NSString* path = [workspace absolutePathForAppBundleWithIdentifier: appid];
		if (path != nil) {
			NSDictionary* bindings = [source objectForKey: appid];
			for (NSString* devid in bindings) {
				if ([device isEqualToString: devid] == YES) {
					NSString* appname, *apptype;
					NSImage* icon = [workspace iconForFile: path];
					if ([workspace getInfoForFile: path application: &appname type: &apptype]) {
						[_source addObject: [NSArray arrayWithObjects: icon,
														[[appname lastPathComponent] stringByDeletingPathExtension],
 														[NSNumber numberWithInteger: [popup indexOfSelectedItem]], nil]];
					}
				}
			}
		}
	}

	_count = [_source count];
	[[table tableColumnWithIdentifier: NS4CC(kAppTableColumnList)] setWidth: _count > 7 ? 1 : 1000];
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
