//
// FPXboxHIDNotifier.m
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


#import "FPXboxHIDNotifier.h"


@implementation FPXboxHIDNotifier

+ (id) notifier
{
	FPXboxHIDNotifier* notifier;

	notifier = [[FPXboxHIDNotifier alloc] init];

	return notifier;
}


- (id) init
{
	self = [super init];
	if (self && ![self createRunLoopNotifications]) {
		return nil;
	}
	return self;
}


- (void) dealloc
{
	[self releaseRunLoopNotifications];
}


- (void) setMatchedSelector: (SEL)selector target: (id)target
{
	_matchedSelector = selector;
	_matchedTarget = target;
	_matchedImp = [_matchedTarget methodForSelector: _matchedSelector];
}


- (void) fireMatchedSelector
{
	_matchedImp(_matchedTarget, _matchedSelector);
//	[_matchedTarget performSelector: _matchedSelector];
}


static void driversMatched (void* refcon, io_iterator_t iterator)
{
	FPXboxHIDNotifier* self = (__bridge FPXboxHIDNotifier*)refcon;
	io_object_t object;

	do {
		object = IOIteratorNext(iterator);
	} while (object);

	[self fireMatchedSelector];
}


- (void) setTerminatedSelector: (SEL)selector target: (id)target
{
	_terminatedSelector = selector;
	_terminatedTarget = target;
	_terminatedImp = [_terminatedTarget methodForSelector: _terminatedSelector];

}


- (void) fireTerminatedSelector
{
	_terminatedImp(_terminatedTarget, _terminatedSelector);
//	[_terminatedTarget performSelector: _terminatedSelector];
}


static void driversTerminated (void* refcon, io_iterator_t iterator)
{
	FPXboxHIDNotifier* self = (__bridge FPXboxHIDNotifier*)refcon;
	io_object_t object;

	do {
		object = IOIteratorNext(iterator);
	} while (object);

	[self fireTerminatedSelector];
}


- (BOOL) createRunLoopNotifications
{
	IOReturn kr = kIOReturnSuccess;
	mach_port_t masterPort = 0;

	CFMutableDictionaryRef matchDictionary = NULL;
	io_iterator_t notificationIterator;

	kr = IOMasterPort(bootstrap_port, &masterPort);
	if (kr != kIOReturnSuccess) {
		NSLog(@"IOMasterPort error with bootstrap_port\n");
		return NO;
	}

	_notificationPort = IONotificationPortCreate(masterPort);
	if (_notificationPort == NULL) {
		NSLog(@"Couldn't create notification port\n");
		return NO;
	}

	_runLoopSource = IONotificationPortGetRunLoopSource (_notificationPort);
	CFRunLoopAddSource(CFRunLoopGetCurrent(), _runLoopSource, kCFRunLoopDefaultMode);

	matchDictionary = IOServiceMatching("FPXboxHIDDriver");
	if (!matchDictionary) {
		NSLog(@"IOServiceMatching returned NULL\n");
		return NO;
	}
	CFRetain(matchDictionary); // next call will consume one reference

	kr = IOServiceAddMatchingNotification(_notificationPort, kIOMatchedNotification, matchDictionary,
														driversMatched, (__bridge void *)(self), &notificationIterator);
	if (kr != kIOReturnSuccess) {
		NSLog(@"IOServiceAddMatchingNotification with kIOMatchedNotification failed with 0x%x\n", kr);
		return NO;
	}

	if (notificationIterator)
		primeNotifications(NULL, notificationIterator);

	kr = IOServiceAddMatchingNotification(_notificationPort, kIOTerminatedNotification, matchDictionary,
														driversTerminated, (__bridge void *)(self), &notificationIterator);
	if (kr != kIOReturnSuccess) {
		NSLog(@"IOServiceAddMatchingNotification with kIOTerminatedNotification failed with 0x%x\n", kr);
		return NO;
	}

	if (notificationIterator)
		primeNotifications(NULL, notificationIterator);

	return YES;
}


- (void) releaseRunLoopNotifications
{
	CFRunLoopRemoveSource(CFRunLoopGetCurrent(), _runLoopSource, kCFRunLoopDefaultMode);
	IONotificationPortDestroy(_notificationPort);
}


static void primeNotifications (void* refcon, io_iterator_t iterator)
{
	io_object_t object;

	do {
		object = IOIteratorNext(iterator);
	} while (object);
}

@end
