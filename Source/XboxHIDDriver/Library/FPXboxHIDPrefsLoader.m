//
// FPXboxHIDPrefsLoader.m
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


#import "FPXboxHIDPrefsLoader.h"


#define kConfigsKey                 @"Configurations"
#define kAppsKey					@"Applications"
#define kBindingsKey                @"Bindings"

#define kConfigTypeKey              @"Type"
#define kConfigSettingsKey          @"Settings"

#define kDefaultsSuiteIdentifier    @"com.fizzypopstudios.XboxHIDDriver"

#define kAppFinder					@"com.apple.finder"


@implementation FPXboxHIDPrefsLoader

+ (NSMutableDictionary*) defaults
{
	NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
	[userDefaults synchronize];

	NSMutableDictionary* defaults = (NSMutableDictionary*)[userDefaults persistentDomainForName: kDefaultsSuiteIdentifier];
	if (defaults) {
		defaults = (NSMutableDictionary*)CFPropertyListCreateDeepCopy(kCFAllocatorDefault, (CFPropertyListRef)defaults,
																					 kCFPropertyListMutableContainers);
		[defaults autorelease];
	}

	return defaults;
}


+ (void) setDefaults: (NSDictionary*)defaults
{
	NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
	[userDefaults setPersistentDomain: defaults forName: kDefaultsSuiteIdentifier];
	[userDefaults synchronize];
}


// this needs to be called immediately after the driver loads, before any other prefs are set for the device
+ (BOOL) createDefaultsForDevice: (FPXboxHIDDriverInterface*)device
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

	[FPXboxHIDPrefsLoader setDefaults: defaults];

	return YES;
}


// list all the config names for a particular device type
+ (NSArray*) configNamesForDeviceType: (NSString*)deviceType
{
	NSMutableDictionary* prefs = [FPXboxHIDPrefsLoader defaults];
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
+ (NSString*) configNameForDevice: (FPXboxHIDDriverInterface*)device
{
	NSString* configName;

	configName = [[[FPXboxHIDPrefsLoader defaults] objectForKey: kBindingsKey] objectForKey: [device identifier]];
	if (!configName)
		configName = kConfigNameDefault;

	return configName;
}


// rename current config
+ (BOOL) renameCurrentConfig: (NSString*)rename forDevice: (FPXboxHIDDriverInterface*)device
{
	return [self renameConfigNamed: [FPXboxHIDPrefsLoader configNameForDevice: device] withNewName: rename forDevice: device];
}


// rename specific coniguration
+ (BOOL) renameConfigNamed: (NSString*)current withNewName: (NSString*)rename forDevice: (FPXboxHIDDriverInterface*)device
{
	if ([rename isEqualToString: @""] || [rename isEqualToString: kConfigNameDefault] || [current isEqualToString: kConfigNameDefault])
		return false;	// Can't rename default config, or rename anything else to default name

	if ([[FPXboxHIDPrefsLoader configNamesForDeviceType: [device deviceType]] containsObject: rename])
		return false;	// Don't rename if name already exists

	NSMutableDictionary* prefs = [FPXboxHIDPrefsLoader defaults];
	NSDictionary* settings = [[prefs objectForKey: kConfigsKey] objectForKey: current];

	// add new key as copy of settings, then remove old key
	[[prefs objectForKey: kConfigsKey] setObject: settings forKey: rename];
	[[prefs objectForKey: kConfigsKey] removeObjectForKey: current];

	// iterate through device bindings to update any devices using renamed config
	NSMutableDictionary* bindings = [prefs objectForKey: kBindingsKey];
	for (NSString* device in bindings) {
		if ([[bindings objectForKey: device] isEqualToString: current]) {
			[bindings removeObjectForKey: device];
			[bindings setObject: rename forKey: device];
		}
	}

	// iterate through application bindings to update any apps using renamed config
	NSDictionary* apps = [prefs objectForKey: kAppsKey];
	for (NSString* appid in apps) {
		NSMutableDictionary* bindings = [apps objectForKey: appid];
		for (NSString* device in bindings) {
			if ([[bindings objectForKey: device] isEqualToString: current]) {
				[bindings removeObjectForKey: device];
				[bindings setObject: rename forKey: device];
			}
		}
	}

	[FPXboxHIDPrefsLoader setDefaults: prefs];

	return true;
}


// returns all current app bindings
+ (NSDictionary*) allAppBindings
{
	NSDictionary* bindings = [[FPXboxHIDPrefsLoader defaults] objectForKey: kAppsKey];
	if (bindings != nil)
		return [NSDictionary dictionaryWithDictionary: bindings];
	return nil;
}


// returns total number of applications bound to specific config
+ (int) totalAppBindingsForConfigNamed: (NSString*)config
{
	int total = 0;
	NSMutableDictionary* prefs = [FPXboxHIDPrefsLoader defaults];

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


// is current config the default config?
+ (BOOL) isDefaultConfigForDevice: (FPXboxHIDDriverInterface*)device
{
	return [[self configNameForDevice: device] isEqualToString: kConfigNameDefault];
}


// load the current config for the specified device
+ (BOOL) loadSavedConfigForDevice: (FPXboxHIDDriverInterface*)device
{
	NSString* configName = [FPXboxHIDPrefsLoader configNameForDevice: device];
	return [FPXboxHIDPrefsLoader loadConfigForDevice: device withName: configName];
}


// save the current config using selected config name for device
+ (BOOL) saveConfigForDevice: (FPXboxHIDDriverInterface*)device
{
	return [self saveConfigForDevice: device withConfigName: [FPXboxHIDPrefsLoader configNameForDevice: device]];
}


// save current config under specific name (used for app config support)
+ (BOOL) saveConfigForDevice: (FPXboxHIDDriverInterface*)device withConfigName: configName
{
	NSDictionary* settings = [device deviceOptions];
	NSString* configType = [device deviceType];
	NSMutableDictionary* defaults = [FPXboxHIDPrefsLoader defaults];
	NSMutableDictionary* config = [NSMutableDictionary dictionary];

	[config setObject: settings forKey: kConfigSettingsKey];
	[config setObject: configType forKey: kConfigTypeKey];

	[[defaults objectForKey: kConfigsKey] setObject: config forKey: configName];

	[FPXboxHIDPrefsLoader setDefaults: defaults];

	return YES;
}


// load named config for device
+ (BOOL) loadConfigForDevice: (FPXboxHIDDriverInterface*)device withName: (NSString*)configName
{
	return [self loadConfigForDevice: device withName: configName andAppID: nil];
}


// load named config for device, with optional appid to support app specific config bindings
+ (BOOL) loadConfigForDevice: (FPXboxHIDDriverInterface*)device withName: (NSString*)configName	andAppID: (NSString*)appid
{
	NSMutableDictionary* defaults = [FPXboxHIDPrefsLoader defaults];
	NSDictionary* config = [[defaults objectForKey: kConfigsKey] objectForKey: configName];

	// first check that config type matches
	if ([[config objectForKey: kConfigTypeKey] isEqualTo: [device deviceType]]) {
		// then load the config
		BOOL success = [device loadOptions: [config objectForKey: kConfigSettingsKey]];
		if (success) {
			id userInfo = nil;

			if (appid == nil) {
				// change the binding for the device
				[[defaults objectForKey: kBindingsKey] setObject: configName forKey: [device identifier]];
				[FPXboxHIDPrefsLoader setDefaults: defaults];

				NSLog(@"Loaded config \"%@\" for Device ID \"%@\"", configName, [device identifier]);
			} else {
				userInfo = [NSDictionary dictionaryWithObjectsAndKeys: appid, kNoticeAppKey, configName, kNoticeConfigKey, nil];

				NSLog(@"Loaded config \"%@\" (%@) for Device ID \"%@\"", configName, appid, [device identifier]);
			}

			// broadcast a message to other applications that the device's configuration has changed
			[[NSDistributedNotificationCenter defaultCenter] postNotificationName: kFPXboxHIDDeviceConfigurationDidChangeNotification
																		   object: kFPDistributedNotificationsObject
																		 userInfo: userInfo
															   deliverImmediately: YES];
		}
		return success;
	}

	return NO;
}


// load app-specific confg (if present) for device
+ (BOOL) loadConfigForDevice: (FPXboxHIDDriverInterface*)device forAppID: (NSString*)appid
{
	NSMutableDictionary* defaults = [FPXboxHIDPrefsLoader defaults];

	// load default config for device when finder activated
	if ([appid isEqualToString: kAppFinder]) {
		return [FPXboxHIDPrefsLoader loadSavedConfigForDevice: device];

	// otherwise, check if an app specific config for device exists and load it if it does
	} else {
		NSString* config = [[[defaults objectForKey: kAppsKey] objectForKey: appid] objectForKey: [device identifier]];
		return (config != nil ? [FPXboxHIDPrefsLoader loadConfigForDevice: device withName: config andAppID: appid] : NO);

	}
}


// create a new config with current settings, and make it the device's configuration
+ (BOOL) createConfigForDevice: (FPXboxHIDDriverInterface*)device withName: (NSString*)configName
{
	NSMutableDictionary* defaults = [FPXboxHIDPrefsLoader defaults];

	// change the binding to the new config name
	[[defaults objectForKey: kBindingsKey] setObject: configName forKey: [device identifier]];

	[FPXboxHIDPrefsLoader setDefaults: defaults];

	// save the current config with the new name
	return [FPXboxHIDPrefsLoader saveConfigForDevice: device];
}


// delete the specified configuration
+ (BOOL) deleteConfigWithName: (NSString*)configName
{
	// don't allow deleting the default config
	if (![configName isEqualTo: kConfigNameDefault]) {
		NSMutableDictionary* defaults = [FPXboxHIDPrefsLoader defaults];

		// remove the config
		[[defaults objectForKey: kConfigsKey] removeObjectForKey: configName];

		// change any bindings to the default config
		NSEnumerator* identifiers = [[defaults objectForKey: kBindingsKey] keyEnumerator];
		NSString* identifier;

		while (identifier = [identifiers nextObject]) {
			if ([[[defaults objectForKey: kBindingsKey] objectForKey: identifier] isEqualTo: configName])
				[[defaults objectForKey: kBindingsKey] setObject: kConfigNameDefault forKey: identifier];
		}

		[FPXboxHIDPrefsLoader setDefaults: defaults];

		return YES;
	}

	return NO;
}

@end
