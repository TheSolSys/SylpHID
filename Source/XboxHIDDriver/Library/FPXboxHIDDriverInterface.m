//
// FPXboxHIDDriverInterface.m
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


#import <IOKit/hid/IOHIDKeys.h>
#import <IOKit/hid/IOHIDUsageTables.h>

#import "FPXboxHIDDriverInterface.h"


@implementation FPXboxHIDDriverInterface

#pragma mark === private methods ===

- (BOOL) getDeviceProperties
{
	CFMutableDictionaryRef ioRegistryProperties = 0;

	// get the ioregistry properties
	if (kIOReturnSuccess != IORegistryEntryCreateCFProperties(_driver, &ioRegistryProperties, kCFAllocatorDefault, 0))
		return NO;
	if (!ioRegistryProperties)
		return NO;
	if (_ioRegistryProperties)
		[_ioRegistryProperties release];
	_ioRegistryProperties = (NSMutableDictionary*)ioRegistryProperties;

	// set the device type
	_deviceType = [_ioRegistryProperties objectForKey: NSSTR(kTypeKey)];
	if (!_deviceType)
		return NO;
	_deviceOptions = [_ioRegistryProperties objectForKey: NSSTR(kDeviceOptionsKey)];

	return YES;
}


- (void) setOptionWithKey: (NSString*)key andValue: (id)value
{
	NSDictionary* request;
	IOReturn ret;

	request = [NSDictionary dictionaryWithObjectsAndKeys: _deviceType, NSSTR(kTypeKey),
														  key, NSSTR(kClientOptionKeyKey),
														  value, NSSTR(kClientOptionValueKey), nil];

	ret = IORegistryEntrySetCFProperties(_driver, (CFDictionaryRef*)request);
	if (ret != kIOReturnSuccess)
		NSLog(@"Failed setting driver properties: 0x%x", ret);
}


- (NSMutableDictionary*) elementWithCookieRec: (int)cookie elements: (NSArray*)elements
{
	NSUInteger i, count;

	for (i = 0, count = [elements count]; i < count; i++) {
		NSMutableDictionary* element = [elements objectAtIndex: i];
		NSArray* subElements;

		if (cookie == [[element objectForKey: NSSTR(kIOHIDElementCookieKey)] intValue])
			return element;
		else {
			subElements = [element objectForKey: NSSTR(kIOHIDElementKey)];
			if (subElements) {
				element = [self elementWithCookieRec: cookie elements: subElements];
				if (element)
					return element;
			}
		}
	}

	return nil;
}


- (NSMutableDictionary*) elementWithCookie: (int)cookie
{
	NSArray* elements = [_ioRegistryProperties objectForKey: NSSTR(kIOHIDElementKey)];
	return elements ? [self elementWithCookieRec: cookie elements: elements] : nil;
}


- (void) commitElements
{
	NSArray* elements = [_ioRegistryProperties objectForKey: NSSTR(kIOHIDElementKey)];
	IOReturn ret;

	if (elements) {
		NSDictionary* request = [NSDictionary dictionaryWithObjectsAndKeys: elements, NSSTR(kClientOptionSetElementsKey), nil];

		if (request) {
			ret = IORegistryEntrySetCFProperties(_driver, (CFDictionaryRef*)request);
			if (ret != kIOReturnSuccess)
				NSLog(@"Failed setting driver properties: 0x%x", ret);
		}
	}
}


#pragma mark === interface methods ===

+ (NSArray*) interfaces
{
	IOReturn result = kIOReturnSuccess;
	mach_port_t masterPort = 0;
	io_iterator_t objectIterator = 0;
	CFMutableDictionaryRef matchDictionary = 0;
	io_object_t driver = 0;
	NSMutableArray* interfaceList = nil;

	result = IOMasterPort (bootstrap_port, &masterPort);
	if (kIOReturnSuccess != result) {
		NSLog(@"IOMasterPort error with bootstrap_port");
		return nil;
	}

	// Set up a matching dictionary to search I/O Registry by class name for all HID class devices
	matchDictionary = IOServiceMatching ("FPXboxHIDDriver");
	if (matchDictionary == NULL) {
		NSLog(@"Failed to get CFMutableDictionaryRef via IOServiceMatching");
		return nil;
	}

	// Now search I/O Registry for matching devices
	result = IOServiceGetMatchingServices (masterPort, matchDictionary, &objectIterator);
	if (kIOReturnSuccess != result) {
		NSLog(@"Couldn't create an object iterator");
		return nil;
	}

	if (0 == objectIterator) // there are no joysticks
		return nil;

	interfaceList = [[[NSMutableArray alloc] init] autorelease];

	// IOServiceGetMatchingServices consumes a reference to the dictionary, so we don't need to release the dictionary ref
	while ((driver = IOIteratorNext (objectIterator))) {
		id intf = [FPXboxHIDDriverInterface interfaceWithDriver: driver];
		if (intf)
			[interfaceList addObject: intf];
	}

	IOObjectRelease(objectIterator);

	return interfaceList;
}


+ (FPXboxHIDDriverInterface*) interfaceWithDriver: (io_object_t)driver
{
	return [[[FPXboxHIDDriverInterface alloc] initWithDriver: driver] autorelease];
}


- (id) initWithDriver: (io_object_t)driver
{
	io_name_t className;

	self = [super init];
	if (!self)
		return nil;

	IOObjectRetain(driver);
	_driver = driver;
	_service = 0;

	// check that driver is FPXboxHIDDriver
	if (kIOReturnSuccess != IOObjectGetClass(_driver, className))
		return nil;

	if (0 != strcmp(className, "FPXboxHIDDriver"))
		return nil;

	if (![self getDeviceProperties])
		return nil;

	return self;
}


- (void) dealloc
{
	[super dealloc];

	if (_service) IOServiceClose(_service);
	IOObjectRelease(_driver);
}


- (BOOL) rawReportsActive
{
	return (_service != 0);
}


- (void) enableRawReports
{
	if (_service == 0) {
		IOReturn ret = IOServiceOpen(_driver, mach_task_self(), 0, &_service);
		if (ret != kIOReturnSuccess) {
			NSLog(@"enableRawReports Failure (%x)\n", ret);
			_service = 0;
		}
	}
}


- (void) copyRawReport: (XBPadReport*)report
{
	if (_service != 0) {
		size_t size = sizeof(XBPadReport);
		IOReturn ret = IOConnectCallStructMethod(_service, kXboxHIDDriverClientMethodRawReport, NULL, 0, report, &size);
		if (ret != kIOReturnSuccess)
			NSLog(@"copyRawReport:%p Failure(%x) Service(%d)\n", report, ret, _service);
	}
}


- (io_object_t) driver
{
	return _driver;
}


- (NSString*) deviceType
{
	return _deviceType;
}


- (BOOL) deviceIsPad
{
	return [_deviceType isEqualToString: NSSTR(kDeviceTypePadKey)];
}


- (BOOL) deviceIsRemote
{
	return [_deviceType isEqualToString: NSSTR(kDeviceTypeIRKey)];
}


- (NSString*) productName
{
	return [_ioRegistryProperties objectForKey: NSSTR(kIOHIDProductKey)];
}


- (NSString*) manufacturerName
{
	return [_ioRegistryProperties objectForKey: NSSTR(kIOHIDManufacturerKey)];
}


- (NSString*) identifier
{
	return [NSString stringWithFormat: @"%@-%x", [self deviceType],
	        [[_ioRegistryProperties objectForKey: NSSTR(kIOHIDLocationIDKey)] intValue]];
}


- (BOOL) hasOptions
{
	return _deviceOptions != nil && [_deviceOptions count] > 0;
}


- (BOOL) loadOptions: (NSDictionary*)options
{
	// use a little trick here to avoid code duplication...
	// temporarily set the options dictionary so that the "get" methods pull their values from there, but the "set"
	// methods change the values in the driver instance (ioregistry), which is what this method is supposed to do!
	if (options && [_deviceType isEqualTo: NSSTR(kDeviceTypePadKey)]) {
		// the get* methods will now read from the passed in dictionary
		_deviceOptions = options;

		// the set* methods refetch the ioreg properties, so we have to get all the values up front before setting anything
		_savedOptions.InvertLxAxis = [self leftStickHorizInvert];
		_savedOptions.DeadzoneLxAxis = [self leftStickHorizDeadzone];
		_savedOptions.MappingLxAxis = [self leftStickHorizMapping];

		_savedOptions.InvertLyAxis = [self leftStickVertInvert];
		_savedOptions.DeadzoneLyAxis = [self leftStickVertDeadzone];
		_savedOptions.MappingLyAxis = [self leftStickVertMapping];

		_savedOptions.InvertRxAxis = [self rightStickHorizInvert];
		_savedOptions.DeadzoneRxAxis = [self rightStickHorizDeadzone];
		_savedOptions.MappingRxAxis = [self rightStickHorizMapping];

		_savedOptions.InvertRyAxis = [self rightStickVertInvert];
		_savedOptions.DeadzoneRyAxis = [self rightStickVertDeadzone];
		_savedOptions.MappingRyAxis = [self rightStickVertMapping];

		_savedOptions.MappingDPadUp = [self dpadUpMapping];
		_savedOptions.MappingDPadDown = [self dpadDownMapping];
		_savedOptions.MappingDPadLeft = [self dpadLeftMapping];
		_savedOptions.MappingDPadRight = [self dpadRightMapping];

		_savedOptions.MappingButtonStart = [self startButtonMapping];
		_savedOptions.MappingButtonBack = [self backButtonMapping];

		_savedOptions.MappingLeftClick = [self leftClickMapping];
		_savedOptions.MappingRightClick = [self rightClickMapping];

		_savedOptions.AnalogAsDigital = [self analogAsDigital];

		_savedOptions.ThresholdLowLeftTrigger = [self leftTriggerLowThreshold];
		_savedOptions.ThresholdHighLeftTrigger = [self leftTriggerHighThreshold];
		_savedOptions.MappingLeftTrigger = [self leftTriggerMapping];

		_savedOptions.ThresholdLowRightTrigger = [self rightTriggerLowThreshold];
		_savedOptions.ThresholdHighRightTrigger = [self rightTriggerHighThreshold];
		_savedOptions.MappingRightTrigger = [self rightTriggerMapping];

		_savedOptions.ThresholdLowButtonGreen = [self greenButtonLowThreshold];
		_savedOptions.ThresholdHighButtonGreen = [self greenButtonHighThreshold];
		_savedOptions.MappingButtonGreen = [self greenButtonMapping];

		_savedOptions.ThresholdLowButtonRed = [self redButtonLowThreshold];
		_savedOptions.ThresholdHighButtonRed = [self redButtonHighThreshold];
		_savedOptions.MappingButtonRed = [self redButtonMapping];

		_savedOptions.ThresholdLowButtonBlue = [self blueButtonLowThreshold];
		_savedOptions.ThresholdHighButtonBlue = [self blueButtonHighThreshold];
		_savedOptions.MappingButtonBlue = [self blueButtonMapping];

		_savedOptions.ThresholdLowButtonYellow = [self yellowButtonLowThreshold];
		_savedOptions.ThresholdHighButtonYellow = [self yellowButtonHighThreshold];
		_savedOptions.MappingButtonYellow = [self yellowButtonMapping];

		_savedOptions.ThresholdLowButtonWhite = [self whiteButtonLowThreshold];
		_savedOptions.ThresholdHighButtonWhite = [self whiteButtonHighThreshold];
		_savedOptions.MappingButtonWhite = [self whiteButtonMapping];

		_savedOptions.ThresholdLowButtonBlack = [self blackButtonLowThreshold];
		_savedOptions.ThresholdHighButtonBlack = [self blackButtonHighThreshold];
		_savedOptions.MappingButtonBlack = [self blackButtonMapping];

		[self setLeftStickHorizInvert: _savedOptions.InvertLxAxis];
		[self setLeftStickHorizDeadzone: _savedOptions.DeadzoneLxAxis];
		[self setLeftStickHorizMapping: _savedOptions.MappingLxAxis];

		[self setLeftStickVertInvert: _savedOptions.InvertLyAxis];
		[self setLeftStickVertDeadzone: _savedOptions.DeadzoneLyAxis];
		[self setLeftStickVertMapping: _savedOptions.MappingLyAxis];

		[self setRightStickHorizInvert: _savedOptions.InvertRxAxis];
		[self setRightStickHorizDeadzone: _savedOptions.DeadzoneRxAxis];
		[self setRightStickHorizMapping: _savedOptions.MappingRxAxis];

		[self setRightStickVertInvert: _savedOptions.InvertRyAxis];
		[self setRightStickVertDeadzone: _savedOptions.DeadzoneRyAxis];
		[self setRightStickVertMapping: _savedOptions.MappingRyAxis];

		[self setDpadUpMapping: _savedOptions.MappingDPadUp];
		[self setDpadDownMapping: _savedOptions.MappingDPadDown];
		[self setDpadLeftMapping: _savedOptions.MappingDPadLeft];
		[self setDpadRightMapping: _savedOptions.MappingDPadRight];

		[self setStartButtonMapping: _savedOptions.MappingButtonStart];
		[self setBackButtonMapping: _savedOptions.MappingButtonBack];

		[self setLeftClickMapping: _savedOptions.MappingLeftClick];
		[self setRightClickMapping: _savedOptions.MappingRightClick];

		[self setAnalogAsDigital: _savedOptions.AnalogAsDigital];

		[self setLeftTriggerLow: _savedOptions.ThresholdLowLeftTrigger andHighThreshold: _savedOptions.ThresholdHighLeftTrigger];
		[self setLeftTriggerMapping: _savedOptions.MappingLeftTrigger];

		[self setRightTriggerLow: _savedOptions.ThresholdLowRightTrigger andHighThreshold: _savedOptions.ThresholdHighRightTrigger];
		[self setRightTriggerMapping: _savedOptions.MappingRightTrigger];

		[self setGreenButtonLow: _savedOptions.ThresholdLowButtonGreen andHighThreshold: _savedOptions.ThresholdHighButtonGreen];
		[self setGreenButtonMapping: _savedOptions.MappingButtonGreen];

		[self setRedButtonLow: _savedOptions.ThresholdLowButtonRed andHighThreshold: _savedOptions.ThresholdHighButtonRed];
		[self setRedButtonMapping: _savedOptions.MappingButtonRed];

		[self setBlueButtonLow: _savedOptions.ThresholdLowButtonBlue andHighThreshold: _savedOptions.ThresholdHighButtonBlue];
		[self setBlueButtonMapping: _savedOptions.MappingButtonBlue];

		[self setYellowButtonLow: _savedOptions.ThresholdLowButtonYellow andHighThreshold: _savedOptions.ThresholdHighButtonYellow];
		[self setYellowButtonMapping: _savedOptions.MappingButtonYellow];

		[self setWhiteButtonLow: _savedOptions.ThresholdLowButtonWhite andHighThreshold: _savedOptions.ThresholdHighButtonWhite];
		[self setWhiteButtonMapping: _savedOptions.MappingButtonWhite];

		[self setBlackButtonLow: _savedOptions.ThresholdLowButtonBlack andHighThreshold: _savedOptions.ThresholdHighButtonBlack];
		[self setBlackButtonMapping: _savedOptions.MappingButtonBlack];

		return YES;
	}

	return NO;
}


- (NSDictionary*) deviceOptions
{
	return _deviceOptions;
}


#pragma mark === Left Stick ===
#pragma mark --- Horizontal ---

- (int) leftStickHorizMapping
{
	return [[_deviceOptions objectForKey: NSSTR(kOptionMappingLxAxisKey)] intValue];
}


- (void) setLeftStickHorizMapping: (int)map
{
	[self setOptionWithKey: NSSTR(kOptionMappingLxAxisKey) andValue: NSNUM(map)];
	[self getDeviceProperties];
}


- (BOOL) leftStickHorizInvert
{
	return idToBOOL([_deviceOptions objectForKey: NSSTR(kOptionInvertLxAxisKey)]);
}


- (void) setLeftStickHorizInvert: (BOOL)inverts
{
	[self setOptionWithKey: NSSTR(kOptionInvertLxAxisKey) andValue: BOOLtoID(inverts)];
	[self getDeviceProperties];
}


- (int) leftStickHorizDeadzone
{
	return [[_deviceOptions objectForKey: NSSTR(kOptionDeadzoneLxAxisKey)] intValue];
}


- (void) setLeftStickHorizDeadzone: (int)pcent
{
	[self setOptionWithKey: NSSTR(kOptionDeadzoneLxAxisKey) andValue: NSNUM(pcent)];
	[self getDeviceProperties];
}


#pragma mark --- Vertical ---

- (int) leftStickVertMapping
{
	return [[_deviceOptions objectForKey: NSSTR(kOptionMappingLyAxisKey)] intValue];
}


- (void) setLeftStickVertMapping: (int)map
{
	[self setOptionWithKey: NSSTR(kOptionMappingLyAxisKey) andValue: NSNUM(map)];
	[self getDeviceProperties];
}


- (BOOL) leftStickVertInvert
{
	return idToBOOL([_deviceOptions objectForKey: NSSTR(kOptionInvertLyAxisKey)]);
}


- (void) setLeftStickVertInvert: (BOOL)inverts
{
	[self setOptionWithKey: NSSTR(kOptionInvertLyAxisKey) andValue: BOOLtoID(inverts)];
	[self getDeviceProperties];
}


- (int) leftStickVertDeadzone
{
	return [[_deviceOptions objectForKey: NSSTR(kOptionDeadzoneLyAxisKey)] intValue];
}


- (void) setLeftStickVertDeadzone: (int)pcent
{
	[self setOptionWithKey: NSSTR(kOptionDeadzoneLyAxisKey) andValue: NSNUM(pcent)];
	[self getDeviceProperties];
}


#pragma mark === Right Stick ===
#pragma mark --- Horizontal ---

- (int) rightStickHorizMapping
{
	return [[_deviceOptions objectForKey: NSSTR(kOptionMappingRxAxisKey)] intValue];
}


- (void) setRightStickHorizMapping: (int)map
{
	[self setOptionWithKey: NSSTR(kOptionMappingRxAxisKey) andValue: NSNUM(map)];
	[self getDeviceProperties];
}


- (BOOL) rightStickHorizInvert
{
	return idToBOOL([_deviceOptions objectForKey: NSSTR(kOptionInvertRxAxisKey)]);
}


- (void) setRightStickHorizInvert: (BOOL)inverts
{
	[self setOptionWithKey: NSSTR(kOptionInvertRxAxisKey) andValue: BOOLtoID(inverts)];
	[self getDeviceProperties];
}


- (int) rightStickHorizDeadzone
{
	return [[_deviceOptions objectForKey: NSSTR(kOptionDeadzoneRxAxisKey)] intValue];
}


- (void) setRightStickHorizDeadzone: (int)pcent
{
	[self setOptionWithKey: NSSTR(kOptionDeadzoneRxAxisKey) andValue: NSNUM(pcent)];
	[self getDeviceProperties];
}


#pragma mark --- Vertical ---

- (int) rightStickVertMapping
{
	return [[_deviceOptions objectForKey: NSSTR(kOptionMappingRyAxisKey)] intValue];
}


- (void) setRightStickVertMapping: (int)map
{
	[self setOptionWithKey: NSSTR(kOptionMappingRyAxisKey) andValue: NSNUM(map)];
	[self getDeviceProperties];
}


- (BOOL) rightStickVertInvert
{
	return idToBOOL([_deviceOptions objectForKey: NSSTR(kOptionInvertRyAxisKey)]);
}


- (void) setRightStickVertInvert: (BOOL)inverts
{
	[self setOptionWithKey: NSSTR(kOptionInvertRyAxisKey) andValue: BOOLtoID(inverts)];
	[self getDeviceProperties];
}


- (int) rightStickVertDeadzone
{
	return [[_deviceOptions objectForKey: NSSTR(kOptionDeadzoneRyAxisKey)] intValue];
}


- (void) setRightStickVertDeadzone: (int)pcent
{
	[self setOptionWithKey: NSSTR(kOptionDeadzoneRyAxisKey) andValue: NSNUM(pcent)];
	[self getDeviceProperties];
}


#pragma mark === Digital Button Mappings ===
#pragma mark --- Directional Pad ---

- (int) dpadUpMapping
{
	return [[_deviceOptions objectForKey: NSSTR(kOptionMappingDPadUpKey)] intValue];
}

- (void) setDpadUpMapping: (int)map
{
	[self setOptionWithKey: NSSTR(kOptionMappingDPadUpKey) andValue: NSNUM(map)];
	[self getDeviceProperties];
}


- (int) dpadDownMapping
{
	return [[_deviceOptions objectForKey: NSSTR(kOptionMappingDPadDownKey)] intValue];
}


- (void) setDpadDownMapping: (int)map
{
	[self setOptionWithKey: NSSTR(kOptionMappingDPadDownKey) andValue: NSNUM(map)];
	[self getDeviceProperties];
}


- (int) dpadLeftMapping
{
	return [[_deviceOptions objectForKey: NSSTR(kOptionMappingDPadLeftKey)] intValue];
}


- (void) setDpadLeftMapping: (int)map
{
	[self setOptionWithKey: NSSTR(kOptionMappingDPadLeftKey) andValue: NSNUM(map)];
	[self getDeviceProperties];
}


- (int) dpadRightMapping
{
	return [[_deviceOptions objectForKey: NSSTR(kOptionMappingDPadRightKey)] intValue];
}


- (void) setDpadRightMapping: (int)map
{
	[self setOptionWithKey: NSSTR(kOptionMappingDPadRightKey) andValue: NSNUM(map)];
	[self getDeviceProperties];
}


#pragma mark --- Start / Back ---

- (int) startButtonMapping
{
	return [[_deviceOptions objectForKey: NSSTR(kOptionMappingButtonStartKey)] intValue];
}


- (void) setStartButtonMapping: (int)map
{
	[self setOptionWithKey: NSSTR(kOptionMappingButtonStartKey) andValue: NSNUM(map)];
	[self getDeviceProperties];
}


- (int) backButtonMapping
{
	return [[_deviceOptions objectForKey: NSSTR(kOptionMappingButtonBackKey)] intValue];
}


- (void) setBackButtonMapping: (int)map
{
	[self setOptionWithKey: NSSTR(kOptionMappingButtonBackKey) andValue: NSNUM(map)];
	[self getDeviceProperties];
}


#pragma mark --- Left / Right Click ---

- (int) leftClickMapping
{
	return [[_deviceOptions objectForKey: NSSTR(kOptionMappingLeftClickKey)] intValue];
}


- (void) setLeftClickMapping: (int)map
{
	[self setOptionWithKey: NSSTR(kOptionMappingLeftClickKey) andValue: NSNUM(map)];
	[self getDeviceProperties];
}


- (int) rightClickMapping
{
	return [[_deviceOptions objectForKey: NSSTR(kOptionMappingRightClickKey)] intValue];
}


- (void) setRightClickMapping: (int)map
{
	[self setOptionWithKey: NSSTR(kOptionMappingRightClickKey) andValue: NSNUM(map)];
	[self getDeviceProperties];
}


#pragma mark === Analog Button Mappings ===

- (int) analogAsDigital
{
	return [[_deviceOptions objectForKey: NSSTR(kOptionAnalogAsDigitalKey)] intValue];
}


- (void) setAnalogAsDigital: (int)mask
{
	NSMutableDictionary* element;
	int max, i;

	for (i = kCookiePadFirstFaceButton; i < kCookiePadLastFaceButton; i++) {
		max = (mask & BITMASK((i - kCookiePadFirstFaceButton))) ? 1 : 255;
		element = [self elementWithCookie: i];

		if (element) {
			[element setObject: NSNUM(max) forKey: NSSTR(kIOHIDElementMaxKey)];
			[element setObject: NSNUM(max) forKey: NSSTR(kIOHIDElementScaledMaxKey)];
		}
	}

	for (i = kCookiePadFirstTrigger; i < kCookiePadLastTrigger; i++) {
		max = (mask & BITMASK((i - kCookiePadFirstTrigger))) ? 1 : 255;
		element = [self elementWithCookie: i];

		if (element) {
			[element setObject: NSNUM(max) forKey: NSSTR(kIOHIDElementMaxKey)];
			[element setObject: NSNUM(max) forKey: NSSTR(kIOHIDElementScaledMaxKey)];
		}
	}

	// update elements structure in ioregistry/driver
	[self commitElements];
	[self setOptionWithKey: NSSTR(kOptionAnalogAsDigitalKey) andValue: NSNUM(mask)];
	[self getDeviceProperties];
}


#pragma mark --- Left Trigger ---

- (int) leftTriggerMapping
{
	return [[_deviceOptions objectForKey: NSSTR(kOptionMappingLeftTriggerKey)] intValue];
}


- (void) setLeftTriggerMapping: (int)map
{
	[self setOptionWithKey: NSSTR(kOptionMappingLeftTriggerKey) andValue: NSNUM(map)];
	[self getDeviceProperties];
}


- (int) leftTriggerLowThreshold
{
	return [[_deviceOptions objectForKey: NSSTR(kOptionThresholdLowLeftTriggerKey)] intValue];
}


- (int) leftTriggerHighThreshold
{
	return [[_deviceOptions objectForKey: NSSTR(kOptionThresholdHighLeftTriggerKey)] intValue];
}


- (void) setLeftTriggerLow: (int)low andHighThreshold: (int)high
{
	[self setOptionWithKey: NSSTR(kOptionThresholdLowLeftTriggerKey) andValue: NSNUM(low)];
	[self setOptionWithKey: NSSTR(kOptionThresholdHighLeftTriggerKey) andValue: NSNUM(high)];
	[self getDeviceProperties];
}


#pragma mark --- Right Trigger ---

- (int) rightTriggerMapping
{
	return [[_deviceOptions objectForKey: NSSTR(kOptionMappingRightTriggerKey)] intValue];
}


- (void) setRightTriggerMapping: (int)map
{
	[self setOptionWithKey: NSSTR(kOptionMappingRightTriggerKey) andValue: NSNUM(map)];
	[self getDeviceProperties];
}


- (int) rightTriggerLowThreshold
{
	return [[_deviceOptions objectForKey: NSSTR(kOptionThresholdLowRightTriggerKey)] intValue];
}


- (int) rightTriggerHighThreshold
{
	return [[_deviceOptions objectForKey: NSSTR(kOptionThresholdHighRightTriggerKey)] intValue];
}


- (void) setRightTriggerLow: (int)low andHighThreshold: (int)high
{
	[self setOptionWithKey: NSSTR(kOptionThresholdLowRightTriggerKey) andValue: NSNUM(low)];
	[self setOptionWithKey: NSSTR(kOptionThresholdHighRightTriggerKey) andValue: NSNUM(high)];
	[self getDeviceProperties];
}


#pragma mark --- Green (A) ---

- (int) greenButtonMapping
{
	return [[_deviceOptions objectForKey: NSSTR(kOptionMappingButtonGreenKey)] intValue];
}


- (void) setGreenButtonMapping: (int)map
{
	[self setOptionWithKey: NSSTR(kOptionMappingButtonGreenKey) andValue: NSNUM(map)];
	[self getDeviceProperties];
}


- (int) greenButtonLowThreshold
{
	return [[_deviceOptions objectForKey: NSSTR(kOptionThresholdLowButtonGreenKey)] intValue];
}


- (int) greenButtonHighThreshold
{
	return [[_deviceOptions objectForKey: NSSTR(kOptionThresholdHighButtonGreenKey)] intValue];
}


- (void) setGreenButtonLow: (int)low andHighThreshold: (int)high
{
	[self setOptionWithKey: NSSTR(kOptionThresholdLowButtonGreenKey) andValue: NSNUM(low)];
	[self setOptionWithKey: NSSTR(kOptionThresholdHighButtonGreenKey) andValue: NSNUM(high)];
	[self getDeviceProperties];
}


#pragma mark --- Red (B) ---

- (int) redButtonMapping
{
	return [[_deviceOptions objectForKey: NSSTR(kOptionMappingButtonRedKey)] intValue];
}


- (void) setRedButtonMapping: (int)map
{
	[self setOptionWithKey: NSSTR(kOptionMappingButtonRedKey) andValue: NSNUM(map)];
	[self getDeviceProperties];
}


- (int) redButtonLowThreshold
{
	return [[_deviceOptions objectForKey: NSSTR(kOptionThresholdLowButtonRedKey)] intValue];
}


- (int) redButtonHighThreshold
{
	return [[_deviceOptions objectForKey: NSSTR(kOptionThresholdHighButtonRedKey)] intValue];
}


- (void) setRedButtonLow: (int)low andHighThreshold: (int)high
{
	[self setOptionWithKey: NSSTR(kOptionThresholdLowButtonRedKey) andValue: NSNUM(low)];
	[self setOptionWithKey: NSSTR(kOptionThresholdHighButtonRedKey) andValue: NSNUM(high)];
	[self getDeviceProperties];
}


#pragma mark --- Blue (X) ---

- (int) blueButtonMapping
{
	return [[_deviceOptions objectForKey: NSSTR(kOptionMappingButtonBlueKey)] intValue];
}


- (void) setBlueButtonMapping: (int)map
{
	[self setOptionWithKey: NSSTR(kOptionMappingButtonBlueKey) andValue: NSNUM(map)];
	[self getDeviceProperties];
}


- (int) blueButtonLowThreshold
{
	return [[_deviceOptions objectForKey: NSSTR(kOptionThresholdLowButtonBlueKey)] intValue];
}


- (int) blueButtonHighThreshold
{
	return [[_deviceOptions objectForKey: NSSTR(kOptionThresholdHighButtonBlueKey)] intValue];
}


- (void) setBlueButtonLow: (int)low andHighThreshold: (int)high
{
	[self setOptionWithKey: NSSTR(kOptionThresholdLowButtonBlueKey) andValue: NSNUM(low)];
	[self setOptionWithKey: NSSTR(kOptionThresholdHighButtonBlueKey) andValue: NSNUM(high)];
	[self getDeviceProperties];
}


#pragma mark --- Yellow (Y) ---

- (int) yellowButtonMapping
{
	return [[_deviceOptions objectForKey: NSSTR(kOptionMappingButtonYellowKey)] intValue];
}


- (void) setYellowButtonMapping: (int)map
{
	[self setOptionWithKey: NSSTR(kOptionMappingButtonYellowKey) andValue: NSNUM(map)];
	[self getDeviceProperties];
}


- (int) yellowButtonLowThreshold
{
	return [[_deviceOptions objectForKey: NSSTR(kOptionThresholdLowButtonYellowKey)] intValue];
}


- (int) yellowButtonHighThreshold
{
	return [[_deviceOptions objectForKey: NSSTR(kOptionThresholdHighButtonYellowKey)] intValue];
}


- (void) setYellowButtonLow: (int)low andHighThreshold: (int)high
{
	[self setOptionWithKey: NSSTR(kOptionThresholdLowButtonYellowKey) andValue: NSNUM(low)];
	[self setOptionWithKey: NSSTR(kOptionThresholdHighButtonYellowKey) andValue: NSNUM(high)];
	[self getDeviceProperties];
}


#pragma mark --- Black Button ---

- (int) blackButtonMapping
{
	return [[_deviceOptions objectForKey: NSSTR(kOptionMappingButtonBlackKey)] intValue];
}


- (void) setBlackButtonMapping: (int)map
{
	[self setOptionWithKey: NSSTR(kOptionMappingButtonBlackKey) andValue: NSNUM(map)];
	[self getDeviceProperties];
}


- (int) blackButtonLowThreshold
{
	return [[_deviceOptions objectForKey: NSSTR(kOptionThresholdLowButtonBlackKey)] intValue];
}


- (int) blackButtonHighThreshold
{
	return [[_deviceOptions objectForKey: NSSTR(kOptionThresholdHighButtonBlackKey)] intValue];
}


- (void) setBlackButtonLow: (int)low andHighThreshold: (int)high
{
	[self setOptionWithKey: NSSTR(kOptionThresholdLowButtonBlackKey) andValue: NSNUM(low)];
	[self setOptionWithKey: NSSTR(kOptionThresholdHighButtonBlackKey) andValue: NSNUM(high)];
	[self getDeviceProperties];
}


#pragma mark --- White Button ---

- (int) whiteButtonMapping
{
	return [[_deviceOptions objectForKey: NSSTR(kOptionMappingButtonWhiteKey)] intValue];
}


- (void) setWhiteButtonMapping: (int)map
{
	[self setOptionWithKey: NSSTR(kOptionMappingButtonWhiteKey) andValue: NSNUM(map)];
	[self getDeviceProperties];
}


- (int) whiteButtonLowThreshold
{
	return [[_deviceOptions objectForKey: NSSTR(kOptionThresholdLowButtonWhiteKey)] intValue];
}


- (int) whiteButtonHighThreshold
{
	return [[_deviceOptions objectForKey: NSSTR(kOptionThresholdHighButtonWhiteKey)] intValue];
}


- (void) setWhiteButtonLow: (int)low andHighThreshold: (int)high
{
	[self setOptionWithKey: NSSTR(kOptionThresholdLowButtonWhiteKey) andValue: NSNUM(low)];
	[self setOptionWithKey: NSSTR(kOptionThresholdHighButtonWhiteKey) andValue: NSNUM(high)];
	[self getDeviceProperties];
}


@end


#pragma mark === Utility Functions ===

BOOL idToBOOL(id obj)
{
	return [obj intValue] ? YES : NO;
}


id NSNUM(SInt32 num)
{
	CFNumberRef cfNumber;
	id obj;

	cfNumber = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &num);

	obj = (id)cfNumber;
	[obj autorelease];

	return obj;
}


id NSPTR(void* ptr)
{
	CFNumberRef cfNumber;
	id obj;

	cfNumber = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt64Type, &ptr);

	obj = (id)cfNumber;
	[obj autorelease];

	return obj;
}
