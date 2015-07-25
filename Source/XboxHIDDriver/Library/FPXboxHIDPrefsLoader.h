//
// FPXboxHIDPrefsLoader.h
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


#import <Foundation/Foundation.h>

#import "FPXboxHIDDriverInterface.h"


#define kConfigNameDefault	@"Default Layout"

#define kFPDistributedNotificationsObject	@"com.fizzypopstudios.XboxHIDDriver"
#define kFPXboxHIDDeviceConfigurationDidChangeNotification	@"ConfigDidChange"


@interface FPXboxHIDPrefsLoader : NSObject

// create the default set of settings
+ (BOOL) createDefaultsForDevice: (FPXboxHIDDriverInterface*)device;

// list all the config names for a particular device type
+ (NSArray*) configNamesForDeviceType: (NSString*)deviceType;

// get the config name of the specified device
+ (NSString*) configNameForDevice: (FPXboxHIDDriverInterface*)device;

// rename current configuration
+ (BOOL) renameConfig: (NSString*)rename forDevice: (FPXboxHIDDriverInterface*)device;

// is current config the default config?
+ (BOOL) isDefaultConfigForDevice: (FPXboxHIDDriverInterface*)device;

// load the current config for the specified device
+ (BOOL) loadSavedConfigForDevice: (FPXboxHIDDriverInterface*)device;

// save the current config
+ (BOOL) saveConfigForDevice: (FPXboxHIDDriverInterface*)device;

// load named config for device
+ (BOOL) loadConfigForDevice: (FPXboxHIDDriverInterface*)device withName: (NSString*)configName;

// create a new config with specified settings, and make it the device's configuration
+ (BOOL) createConfigForDevice: (FPXboxHIDDriverInterface*)device withName: (NSString*)configName;

// delete the specified configuration
+ (BOOL) deleteConfigWithName: (NSString*)configName;

@end
