//
// FPSylpHIDAppData.h
// "SylpHID"
//
// Created by Paige Marie DePol <pmd@fizzypopstudios.com>
// Copyright (c)2015 FizzyPop Studios. All Rights Reserved.
// http://sylphid.fizzypopstudios.com
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
	NSMutableArray* input = [[NSMutableArray alloc] init];
	_popup = [[NSPopUpButton alloc] init];
	_device = device;
	_table = table;

	[(id<FPAppBindings>)[_table delegate] buildConfigurationPopUpButton: _popup withDefaultConfig: nil];
	[[_popup cell] setFont: [NSFont systemFontOfSize: [NSFont systemFontSizeForControlSize: NSSmallControlSize]]];
	[[_popup cell] setControlSize: NSSmallControlSize];
	[[_table tableColumnWithIdentifier: NS4CC(kAppTableColumnList)] setDataCell: [_popup cell]];
	[_table setRowHeight: 23];

	for (NSString* appid in source) {
		NSString* path = [workspace absolutePathForAppBundleWithIdentifier: appid];
		if (path != nil) {
			NSDictionary* bindings = [source objectForKey: appid];
			for (NSString* devid in bindings) {
				if ([_device isEqualToString: devid] == YES) {
					NSImage* icon = [workspace iconForFile: path];
					NSString* appname = [[NSFileManager defaultManager] displayNameAtPath: path];
					NSInteger index = [_popup indexOfItemWithTitle: [bindings objectForKey: devid]];
					[input addObject: [NSMutableArray arrayWithObjects: icon, [appname stringByDeletingPathExtension],
															[NSNumber numberWithInteger: index == -1 ? 0 : index], appid, nil]];
				}
			}
		}
	}

	// Sort app bindings by application name
	_source = [input sortedArrayUsingComparator: ^NSComparisonResult(NSArray* first, NSArray* second) {
		return [[first objectAtIndex: kAppSourceName] compare: [second objectAtIndex: kAppSourceName]];
	}];

	_count = [_source count];	// Actual min/max values set in IB, so we just use 1 and 1000 in case we change them
	[[table tableColumnWithIdentifier: NS4CC(kAppTableColumnList)] setWidth: _count > kAppTableMaxRows ? 1 : 1000];
}


- (NSString*) appIdentifierForRow: (NSInteger)row
{
	return (row > -1 && row < _count) ? [[_source objectAtIndex: row] objectAtIndex: kAppSourceID] : nil;
}


- (id) tableView: (NSTableView*)tableView objectValueForTableColumn: (NSTableColumn*)tableColumn row: (NSInteger)row
{
	uint colid = NSSwapInt(*(uint*)StringToC([tableColumn identifier]));
	switch (colid) {
		case kAppTableColumnIcon:
			return [[_source objectAtIndex: row] objectAtIndex: kAppSourceIcon];

		case kAppTableColumnName:
			return [[_source objectAtIndex: row] objectAtIndex: kAppSourceName];

		case kAppTableColumnList:
			return [[_source objectAtIndex: row] objectAtIndex: kAppSourceList];
	}

	return nil;
}


- (void) tableView: (NSTableView*)tableView setObjectValue: (id)object forTableColumn: (NSTableColumn*)tableColumn row:(NSInteger)row
{
	uint colid = NSSwapInt(*(uint*)StringToC([tableColumn identifier]));
	if (colid == kAppTableColumnList) {
		[[_source objectAtIndex: row] setObject: object atIndex: 2];
		[(id<FPAppBindings>)[_table delegate] setAppConfig: [_popup itemTitleAtIndex: [object integerValue]]
												  forAppID: [[_source objectAtIndex: row] objectAtIndex: kAppSourceID]];

	}
}


- (NSInteger) numberOfRowsInTableView: (NSTableView*)tableView
{
	return _count;
}

@end
