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

#define kAppTableColumnIcon		'ICON'
#define kAppTableColumnName		'NAME'
#define kAppTableColumnList		'LIST'

#define kAppSourceIcon			0
#define kAppSourceName			1
#define kAppSourceList			2
#define kAppSourceID			3
#define kAppSourceCell			4


@protocol FPAppBindings

@required
- (void) buildConfigurationPopUpButton: (NSPopUpButton*)button withDefaultConfig: (NSString*)defconfig;
- (void) setAppConfig: (NSString*)config forAppID: (NSString*)appid;
- (void) appSelectionChanged: (NSString*)appid;

@end


@interface FPDataSourceApps : NSObject <NSTableViewDataSource, NSTableViewDelegate> {
	NSArray* _source;
	NSUInteger _count;
	NSPopUpButton* _popup;
	NSString* _device;
	NSTableView* _table;
}

- (void) setSource: (NSDictionary*)source forDeviceID: (NSString*)device  withTableView: (NSTableView*)table;

- (NSString*) appIdentifierForRow: (NSInteger)row;

@end
