//
// FPXboxHIDDaemon.m
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
#import <IOKit/IOKitLib.h>
#import <signal.h>

#import "FPXboxHIDDriverInterface.h"
#import "FPXboxHIDPrefsLoader.h"


// wait for an xbox device to be connected
// when a device is connected, load settings from disk to configure the device
static void driversDidLoad(void *refcon, io_iterator_t iterator)
{
	io_object_t driver;

	while ((driver = IOIteratorNext(iterator))) {
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

		FPXboxHIDDriverInterface *device = [FPXboxHIDDriverInterface interfaceWithDriver: driver];
		[FPXboxHIDPrefsLoader createDefaultsForDevice: device];
		[FPXboxHIDPrefsLoader loadSavedConfigForDevice: device];

		NSLog(@"Loaded config \"%@\" for Device ID \"%@\"",
			 [FPXboxHIDPrefsLoader configNameForDevice: device], [device identifier]);

		[pool release];
	}
}


static void registerForDriverLoadedNotification()
{
	IOReturn kr = kIOReturnSuccess;
	mach_port_t masterPort = 0;
	IONotificationPortRef notificationPort = NULL;
	CFRunLoopSourceRef runLoopSource = NULL;
	CFMutableDictionaryRef matchDictionary = NULL;
	io_iterator_t notification;

	kr = IOMasterPort(bootstrap_port, &masterPort);
	if (kIOReturnSuccess != kr) {
		printf("IOMasterPort error with bootstrap_port\n");
		exit(-1);
	}

	notificationPort = IONotificationPortCreate(masterPort);
	if (NULL == notificationPort) {
		printf("Couldn't create notification port\n");
		exit(-2);
	}

	runLoopSource = IONotificationPortGetRunLoopSource (notificationPort);
	CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopDefaultMode);

	matchDictionary = IOServiceMatching("FPXboxHIDDriver");
	if (!matchDictionary) {
		printf("IOServiceMatching returned NULL\n");
		exit(-3);
	}

	kr = IOServiceAddMatchingNotification(notificationPort, kIOMatchedNotification, matchDictionary, driversDidLoad,
																			 NULL, &notification);
	if (kIOReturnSuccess != kr) {
		printf("IOServiceAddMatchingNotification failed with 0x%x\n", kr);
		exit(-4);
	}

	if (notification)
		driversDidLoad(NULL, notification);
}

int main (int argc, const char * argv[]) {
	registerForDriverLoadedNotification();

	CFRunLoopRun();

	return 0;
}
