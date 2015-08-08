//
// FPSylpHIDPrefsLoader.h
// "SylpHID"
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


#import <Foundation/Foundation.h>

#import "FPSylpHIDDriverInterface.h"


#define kConfigNameDefault	@"Default Layout"

#define kNoticeAppKey		@"AppID"
#define kNoticeConfigKey	@"Config"
#define kNoticeDeviceKey	@"Device"

#define kFPDistributedNotificationsObject	@"com.fizzypopstudios.SylpHIDDriver"
#define kFPSylpHIDDeviceConfigurationDidChangeNotification	  @"ConfigDidChange"


@interface FPSylpHIDPrefsLoader : NSObject

// create the default set of settings
+ (BOOL) createDefaultsForDevice: (FPSylpHIDDriverInterface*)device;

// list all the config names for a particular device type
+ (NSArray*) configNamesForDeviceType: (NSString*)deviceType;

// get the config name of the specified device
+ (NSString*) configNameForDevice: (FPSylpHIDDriverInterface*)device;

// rename current configuration
+ (BOOL) renameCurrentConfig: (NSString*)rename forDevice: (FPSylpHIDDriverInterface*)device;

// rename specific configuration
+ (BOOL) renameConfigNamed: (NSString*)existing withNewName: (NSString*)rename forDevice: (FPSylpHIDDriverInterface*)device;

// returns all current app bindings
+ (NSDictionary*) allAppBindings;

// set all app bindings (used for undo feature)
+ (BOOL) setAllAppBindings: (NSDictionary*)apps;

// returns total number of applications bound to specific config
+ (int) totalAppBindingsForConfigNamed: (NSString*)config;

// set or create app binding
+ (BOOL) setConfigNamed: (NSString*)config forAppID: (NSString*)appid andDeviceID: (NSString*)devid;

// remove app binding
+ (BOOL) removeAppID: (NSString*)appid forDeviceID: (NSString*)devid;

// is current config the default config?
+ (BOOL) isDefaultConfigForDevice: (FPSylpHIDDriverInterface*)device;

// load the current config for the specified device
+ (BOOL) loadSavedConfigForDevice: (FPSylpHIDDriverInterface*)device;

// save the current config
+ (BOOL) saveConfigForDevice: (FPSylpHIDDriverInterface*)device;

// save current config under specific name
+ (BOOL) saveConfigForDevice: (FPSylpHIDDriverInterface*)device withConfigName: configName;

// load named config for device
+ (BOOL) loadConfigForDevice: (FPSylpHIDDriverInterface*)device withName: (NSString*)configName;

// load named config for device, with optional appid to support app specific config bindings
+ (BOOL) loadConfigForDevice: (FPSylpHIDDriverInterface*)device withName: (NSString*)configName	andAppID: (NSString*)appid;

// load application specific config (if present) for device
+ (BOOL) loadConfigForDevice: (FPSylpHIDDriverInterface*)device forAppID: (NSString*)appid;

// create a new config with specified settings, and make it the device's configuration
+ (BOOL) createConfigForDevice: (FPSylpHIDDriverInterface*)device withName: (NSString*)configName;

// delete the specified configuration
+ (BOOL) deleteConfigWithName: (NSString*)configName;

@end
