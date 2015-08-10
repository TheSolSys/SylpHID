//
// FPSylpHIDPrefsLoader.m
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


#import "FPSylpHIDPrefsLoader.h"


#define kConfigsKey                 @"Configurations"
#define kAppsKey					@"Applications"
#define kBindingsKey                @"Bindings"

#define kConfigTypeKey              @"Type"
#define kConfigSettingsKey          @"Settings"

#define kUserDefaultsDomain			@"com.fizzypopstudios.SylpHID"

#define kAppFinder					@"com.apple.finder"


@implementation FPSylpHIDPrefsLoader

+ (NSMutableDictionary*) defaults
{
	NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
	[userDefaults synchronize];

	NSMutableDictionary* defaults = (NSMutableDictionary*)[userDefaults persistentDomainForName: kUserDefaultsDomain];
	if (defaults) {
		defaults = (NSMutableDictionary*)CFBridgingRelease(CFPropertyListCreateDeepCopy(kCFAllocatorDefault,
								   (__bridge CFPropertyListRef)defaults, kCFPropertyListMutableContainers));
	}

	return defaults;
}


+ (void) setDefaults: (NSDictionary*)defaults
{
	NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
	[userDefaults setPersistentDomain: defaults forName: kUserDefaultsDomain];
	[userDefaults synchronize];
}


// this needs to be called immediately after the driver loads, before any other prefs are set for the device
+ (BOOL) createDefaultsForDevice: (FPSylpHIDDriverInterface*)device
{
	NSMutableDictionary* defaults = [self defaults];

	if (!defaults)
		defaults = [NSMutableDictionary dictionary];

	// don't overwrite user setting
	if (![[defaults objectForKey: kConfigsKey] objectForKey: kConfigNameDefault]) {
		NSLog(@"create default settings for %@", [device identifier]);

		NSMutableDictionary* configs = [NSMutableDictionary dictionary];
		NSMutableDictionary* aConfig = [NSMutableDictionary dictionary];

		[aConfig setObject: [device deviceOptions] forKey: kConfigSettingsKey];
		[aConfig setObject: [device deviceType] forKey: kConfigTypeKey];
		[configs setObject: aConfig forKey: kConfigNameDefault];

		[defaults setObject: configs forKey: kConfigsKey];
	}

	// don't overwrite user setting
	if (![[defaults objectForKey: kBindingsKey] objectForKey: [device identifier]]) {
		NSLog(@"create default binding for %@", [device identifier]);

		NSMutableDictionary* bindings = [defaults objectForKey: kBindingsKey];
		if (!bindings)
			bindings = [NSMutableDictionary dictionary];
		[bindings setObject: kConfigNameDefault forKey: [device identifier]];
		[defaults setObject: bindings forKey: kBindingsKey];
	}

	[FPSylpHIDPrefsLoader setDefaults: defaults];

	return YES;
}


// list all the config names for a particular device type
+ (NSArray*) configNamesForDeviceType: (NSString*)deviceType
{
	NSMutableDictionary* prefs = [FPSylpHIDPrefsLoader defaults];
	NSDictionary* configs = [prefs objectForKey: kConfigsKey];
	NSMutableArray* array = nil;

	NSEnumerator* keys = [configs keyEnumerator];
	if (keys) {
		NSString* key;
		array = [NSMutableArray array];

		while ((key = [keys nextObject])) {
			NSString* type = [[configs objectForKey: key] objectForKey: kConfigTypeKey];
			if ([type isEqualTo: deviceType])
				[array addObject: key];
		}
	}

	return array;
}


// get the config name of the specified device
+ (NSString*) configNameForDevice: (FPSylpHIDDriverInterface*)device
{
	NSString* configName;

	configName = [[[FPSylpHIDPrefsLoader defaults] objectForKey: kBindingsKey] objectForKey: [device identifier]];
	if (!configName)
		configName = kConfigNameDefault;

	return [NSString stringWithString: configName];
}


// rename current config
+ (BOOL) renameCurrentConfig: (NSString*)rename forDevice: (FPSylpHIDDriverInterface*)device
{
	return [self renameConfigNamed: [FPSylpHIDPrefsLoader configNameForDevice: device] withNewName: rename forDevice: device];
}


// rename specific coniguration
+ (BOOL) renameConfigNamed: (NSString*)current withNewName: (NSString*)rename forDevice: (FPSylpHIDDriverInterface*)device
{
	if ([rename isEqualToString: @""] || [rename isEqualToString: kConfigNameDefault] || [current isEqualToString: kConfigNameDefault])
		return false;	// Can't rename default config, or rename anything else to default name

	if ([[FPSylpHIDPrefsLoader configNamesForDeviceType: [device deviceType]] containsObject: rename])
		return false;	// Don't rename if name already exists

	NSMutableDictionary* prefs = [FPSylpHIDPrefsLoader defaults];
	NSDictionary* settings = [[prefs objectForKey: kConfigsKey] objectForKey: current];

	// add new key as copy of settings, then remove old key
	[[prefs objectForKey: kConfigsKey] setObject: settings forKey: rename];
	[[prefs objectForKey: kConfigsKey] removeObjectForKey: current];

	// iterate through device bindings to update any devices using renamed config
	NSMutableDictionary* bindings = [prefs objectForKey: kBindingsKey];
	NSDictionary* iterate = [NSDictionary dictionaryWithDictionary: bindings];
	for (NSString* device in iterate) {
		if ([[bindings objectForKey: device] isEqualToString: current]) {
			[bindings removeObjectForKey: device];
			[bindings setObject: rename forKey: device];
		}
	}

	// iterate through application bindings to update any apps using renamed config
	NSDictionary* apps = [prefs objectForKey: kAppsKey];
	for (NSString* appid in apps) {
		NSMutableDictionary* bindings = [apps objectForKey: appid];
		NSDictionary* iterate = [NSDictionary dictionaryWithDictionary: bindings];
		for (NSString* device in iterate) {
			if ([[bindings objectForKey: device] isEqualToString: current]) {
				[bindings removeObjectForKey: device];
				[bindings setObject: rename forKey: device];
			}
		}
	}

	[FPSylpHIDPrefsLoader setDefaults: prefs];

	return true;
}


// returns all current app bindings
+ (NSDictionary*) allAppBindings
{
	NSDictionary* bindings = [[FPSylpHIDPrefsLoader defaults] objectForKey: kAppsKey];
	if (bindings != nil)
		return [NSDictionary dictionaryWithDictionary: bindings];
	return nil;
}


// set all app bindings (used for undo feature)
+ (BOOL) setAllAppBindings: (NSDictionary*)apps
{
	NSMutableDictionary* prefs = [FPSylpHIDPrefsLoader defaults];
	[prefs setObject: apps forKey: kAppsKey];
	[FPSylpHIDPrefsLoader setDefaults: prefs];
	return true;
}


// returns total number of applications bound to specific config
+ (int) totalAppBindingsForConfigNamed: (NSString*)config
{
	int total = 0;
	NSMutableDictionary* prefs = [FPSylpHIDPrefsLoader defaults];

	// iterate through application bindings to count apps bound to name
	NSDictionary* apps = [prefs objectForKey: kAppsKey];
	for (NSString* appid in apps) {
		NSMutableDictionary* bindings = [apps objectForKey: appid];
		for (NSString* device in bindings) {
			total += [[bindings objectForKey: device] isEqualToString: config];
		}
	}

	return total;
}


// set or create app binding
+ (BOOL) setConfigNamed: (NSString*)config forAppID: (NSString*)appid andDeviceID: (NSString*)devid
{
	NSMutableDictionary* prefs = [FPSylpHIDPrefsLoader defaults];
	NSMutableDictionary* apps = [prefs objectForKey: kAppsKey];

	if (apps == nil) {
		[prefs setObject: @{ appid: @{ devid: config } } forKey: kAppsKey];
	} else {
		NSMutableDictionary* app = [[prefs objectForKey: kAppsKey] objectForKey: appid];
		if (app == nil)
			[apps setObject: @{ devid: config } forKey: appid];
		else
			[apps setObject: config forKey: devid];
	}

	[FPSylpHIDPrefsLoader setDefaults: prefs];

	return YES;
}


// remove app binding
+ (BOOL) removeAppID: (NSString*)appid forDeviceID: (NSString*)devid
{
	NSMutableDictionary* prefs = [FPSylpHIDPrefsLoader defaults];
	NSMutableDictionary* app = [[prefs objectForKey: kAppsKey] objectForKey: appid];

	if (app != nil) {
		[app removeObjectForKey: devid];
		if ([app count] == 0)
			[[prefs objectForKey: kAppsKey] removeObjectForKey: appid];
		[FPSylpHIDPrefsLoader setDefaults: prefs];
	}

	return YES;
}


// is current config the default config?
+ (BOOL) isDefaultConfigForDevice: (FPSylpHIDDriverInterface*)device
{
	return [[self configNameForDevice: device] isEqualToString: kConfigNameDefault];
}


// load the current config for the specified device
+ (BOOL) loadSavedConfigForDevice: (FPSylpHIDDriverInterface*)device
{
	return [FPSylpHIDPrefsLoader loadConfigForDevice: device withName: [FPSylpHIDPrefsLoader configNameForDevice: device]];
}


// save the current config using selected config name for device
+ (BOOL) saveConfigForDevice: (FPSylpHIDDriverInterface*)device
{
	return [self saveConfigForDevice: device withConfigName: [FPSylpHIDPrefsLoader configNameForDevice: device]];
}


// save current config under specific name (used for app config support)
+ (BOOL) saveConfigForDevice: (FPSylpHIDDriverInterface*)device withConfigName: configName
{
	NSDictionary* settings = [device deviceOptions];
	NSString* configType = [device deviceType];
	NSMutableDictionary* defaults = [FPSylpHIDPrefsLoader defaults];
	NSMutableDictionary* config = [NSMutableDictionary dictionary];

	[config setObject: settings forKey: kConfigSettingsKey];
	[config setObject: configType forKey: kConfigTypeKey];

	[[defaults objectForKey: kConfigsKey] setObject: config forKey: configName];

	[FPSylpHIDPrefsLoader setDefaults: defaults];

	return YES;
}


// load named config for device
+ (BOOL) loadConfigForDevice: (FPSylpHIDDriverInterface*)device withName: (NSString*)configName
{
	return [self loadConfigForDevice: device withName: configName andAppID: nil];
}


// load named config for device, with optional appid to support app specific config bindings
+ (BOOL) loadConfigForDevice: (FPSylpHIDDriverInterface*)device withName: (NSString*)configName	andAppID: (NSString*)appid
{
	NSMutableDictionary* defaults = [FPSylpHIDPrefsLoader defaults];
	NSDictionary* config = [[defaults objectForKey: kConfigsKey] objectForKey: configName];

	// first check that config type matches
	if ([[config objectForKey: kConfigTypeKey] isEqualTo: [device deviceType]]) {
		// then load the config
		BOOL success = [device loadOptions: [config objectForKey: kConfigSettingsKey]];
		if (success) {
			NSDictionary* userInfo;

			if (appid == nil) {
				userInfo = [NSDictionary dictionaryWithObjectsAndKeys: [device identifier], kNoticeDeviceKey,
																	   configName,			kNoticeConfigKey, nil];

				// change the binding for the device if not loading config for app
				[[defaults objectForKey: kBindingsKey] setObject: configName forKey: [device identifier]];
				[FPSylpHIDPrefsLoader setDefaults: defaults];

				NSLog(@"Loaded config \"%@\" for Device \"%@\"", configName, [device identifier]);
			} else {
				userInfo = [NSDictionary dictionaryWithObjectsAndKeys: [device identifier], kNoticeDeviceKey,
																	   appid,				kNoticeAppKey,
																	   configName,			kNoticeConfigKey, nil];

				NSLog(@"Loaded config \"%@\" (%@) for Device \"%@\"", configName, appid, [device identifier]);
			}

			// broadcast a message to other applications that the device's configuration has changed
			[[NSDistributedNotificationCenter defaultCenter] postNotificationName: kFPSylpHIDDeviceConfigurationDidChangeNotification
																		   object: kFPDistributedNotificationsObject
																		 userInfo: userInfo
															   deliverImmediately: YES];
		}
		return success;
	}

	return NO;
}


// load app-specific confg (if present) for device
+ (BOOL) loadConfigForDevice: (FPSylpHIDDriverInterface*)device forAppID: (NSString*)appid
{
	NSMutableDictionary* defaults = [FPSylpHIDPrefsLoader defaults];

	// load default config for device when finder activated
	if ([appid isEqualToString: kAppFinder]) {
		return [FPSylpHIDPrefsLoader loadSavedConfigForDevice: device];

	// otherwise, check if an app specific config for device exists and load it if it does
	} else {
		NSString* config = [[[defaults objectForKey: kAppsKey] objectForKey: appid] objectForKey: [device identifier]];
		return (config != nil ? [FPSylpHIDPrefsLoader loadConfigForDevice: device withName: config andAppID: appid] : NO);

	}
}


// create a new config with current settings, and make it the device's configuration
+ (BOOL) createConfigForDevice: (FPSylpHIDDriverInterface*)device withName: (NSString*)configName
{
	NSMutableDictionary* defaults = [FPSylpHIDPrefsLoader defaults];

	// change the binding to the new config name
	[[defaults objectForKey: kBindingsKey] setObject: configName forKey: [device identifier]];

	[FPSylpHIDPrefsLoader setDefaults: defaults];

	// save the current config with the new name
	return [FPSylpHIDPrefsLoader saveConfigForDevice: device];
}


// delete the specified configuration
+ (BOOL) deleteConfigWithName: (NSString*)configName
{
	// don't allow deleting the default config
	if (![configName isEqualTo: kConfigNameDefault]) {
		NSMutableDictionary* defaults = [FPSylpHIDPrefsLoader defaults];
		NSDictionary* iterate;

		// remove the config
		[[defaults objectForKey: kConfigsKey] removeObjectForKey: configName];

		// change any bindings to the default config
		iterate = [NSDictionary dictionaryWithDictionary: [defaults objectForKey: kBindingsKey]];
		NSMutableDictionary *bindings = [defaults objectForKey: kBindingsKey];
		for (NSString* identifier in iterate) {
			if ([[bindings objectForKey: identifier] isEqualTo: configName])
				[bindings setObject: kConfigNameDefault forKey: identifier];
		}

		iterate = [NSDictionary dictionaryWithDictionary: [defaults objectForKey: kAppsKey]];
		NSMutableDictionary *applications = [defaults objectForKey: kAppsKey];
		for (NSString* appid in iterate) {
			for (NSString* device in [iterate objectForKey: appid]) {
				if ([[[applications objectForKey: appid] objectForKey: device] isEqualTo: configName])
					[[applications objectForKey: appid] setObject: kConfigNameDefault forKey: device];
			}
		}

		[FPSylpHIDPrefsLoader setDefaults: defaults];

		return YES;
	}

	return NO;
}

@end
