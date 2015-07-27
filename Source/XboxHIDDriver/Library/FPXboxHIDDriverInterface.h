//
// FPXboxHIDDriverInterface.h
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


#import <IOKit/IOKitLib.h>
#import <libkern/OSTypes.h>
#import <Cocoa/Cocoa.h>

#import "FPXboxHIDDriverKeys.h"


// ObjC and C foundation objects are interchangeable
#define NSSTR(x) ((NSString*)CFSTR(x))


static inline id BOOLtoID(BOOL value)
{
	if (value)
		return (id)kCFBooleanTrue;
	else
		return (id)kCFBooleanFalse;
}


extern BOOL idToBOOL(id obj);
extern id NSNUM(SInt32 num);


@interface FPXboxHIDDriverInterface : NSObject
{
	io_object_t _driver;
	io_connect_t _service;
	NSDictionary* _ioRegistryProperties;
	NSString* _deviceType;
	NSDictionary* _deviceOptions;
}


// utility method: get all connected xbox devices
// returns array of FPXboxHIDDriverInterface objects
+ (NSArray*) interfaces;

+ (FPXboxHIDDriverInterface*) interfaceWithDriver: (io_object_t)driver;
- initWithDriver: (io_object_t)driver;

- (io_object_t) driver;          // associated instance of the driver
- (NSString*) deviceType;
- (BOOL) deviceIsPad;
- (BOOL) deviceIsRemote;
- (NSString*) vendorID;
- (NSString*) vendorSource;
- (NSString*) productID;
- (NSString*) productName;
- (NSString*) manufacturerName;
- (NSString*) versionNumber;
- (NSString*) serialNumber;
- (NSString*) locationID;
- (NSString*) identifier;
- (NSString*) deviceSpeed;
- (NSString*) devicePower;
- (NSString*) deviceAddress;

// true if the device type has options (currently only the pad has options)
- (BOOL) hasOptions;

// load a dictionary of options (say a saved configuration) into the ioregistry
- (BOOL) loadOptions: (NSDictionary*)options;

// load default settings from kernel driver
- (void) loadDefaultLayout;

// fetch the current device options from the ioregistry
- (NSDictionary*) deviceOptions;

// raw reporting (for showing actual data via black/red tick marks on sliders)
- (BOOL) rawReportsActive;
- (void) enableRawReports;
- (void) copyRawReport: (XBPadReport*)report;

// axis
- (int) leftStickHorizMapping;
- (void) setLeftStickHorizMapping: (int)map;
- (BOOL) leftStickHorizInvert;
- (void) setLeftStickHorizInvert: (BOOL)inverts;
- (int) leftStickHorizDeadzone;
- (void) setLeftStickHorizDeadzone: (int)pcent;

- (int) leftStickVertMapping;
- (void) setLeftStickVertMapping: (int)map;
- (BOOL) leftStickVertInvert;
- (void) setLeftStickVertInvert: (BOOL)inverts;
- (int) leftStickVertDeadzone;
- (void) setLeftStickVertDeadzone: (int)pcent;

- (int) rightStickHorizMapping;
- (void) setRightStickHorizMapping: (int)map;
- (BOOL) rightStickHorizInvert;
- (void) setRightStickHorizInvert: (BOOL)inverts;
- (int) rightStickHorizDeadzone;
- (void) setRightStickHorizDeadzone: (int)pcent;

- (int) rightStickVertMapping;
- (void) setRightStickVertMapping: (int)map;
- (BOOL) rightStickVertInvert;
- (void) setRightStickVertInvert: (BOOL)inverts;
- (int) rightStickVertDeadzone;
- (void) setRightStickVertDeadzone: (int)pcent;

// digital buttons
- (int) dpadUpMapping;
- (void) setDpadUpMapping: (int)map;
- (int) dpadDownMapping;
- (void) setDpadDownMapping: (int)map;
- (int) dpadLeftMapping;
- (void) setDpadLeftMapping: (int)map;
- (int) dpadRightMapping;
- (void) setDpadRightMapping: (int)map;

- (int) backButtonMapping;
- (void) setBackButtonMapping: (int)map;
- (int) startButtonMapping;
- (void) setStartButtonMapping: (int)map;

- (int) leftClickMapping;
- (void) setLeftClickMapping: (int)map;
- (int) rightClickMapping;
- (void) setRightClickMapping: (int)map;

// analog buttons
- (int) analogAsDigital;
- (void) setAnalogAsDigital: (int)mask;

- (BOOL) leftTriggerAlternate;
- (void) setLeftTriggerAlternate: (bool)flag;
- (int) leftTriggerMapping;
- (void) setLeftTriggerMapping: (int)map;
- (int) leftTriggerLowThreshold;
- (int) leftTriggerHighThreshold;
- (void) setLeftTriggerLow: (int)low andHighThreshold: (int)high;

- (BOOL) rightTriggerAlternate;
- (void) setRightTriggerAlternate: (bool)flag;
- (int) rightTriggerMapping;
- (void) setRightTriggerMapping: (int)map;
- (int) rightTriggerLowThreshold;
- (int) rightTriggerHighThreshold;
- (void) setRightTriggerLow: (int)low andHighThreshold: (int)high;

- (int) greenButtonMapping;
- (void) setGreenButtonMapping: (int)map;
- (int) greenButtonLowThreshold;
- (int) greenButtonHighThreshold;
- (void) setGreenButtonLow: (int)low andHighThreshold: (int)high;

- (int) redButtonMapping;
- (void) setRedButtonMapping: (int)map;
- (int) redButtonLowThreshold;
- (int) redButtonHighThreshold;
- (void) setRedButtonLow: (int)low andHighThreshold: (int)high;

- (int) blueButtonMapping;
- (void) setBlueButtonMapping: (int)map;
- (int) blueButtonLowThreshold;
- (int) blueButtonHighThreshold;
- (void) setBlueButtonLow: (int)low andHighThreshold: (int)high;

- (int) yellowButtonMapping;
- (void) setYellowButtonMapping: (int)map;
- (int) yellowButtonLowThreshold;
- (int) yellowButtonHighThreshold;
- (void) setYellowButtonLow: (int)low andHighThreshold: (int)high;

- (int) blackButtonMapping;
- (void) setBlackButtonMapping: (int)map;
- (int) blackButtonLowThreshold;
- (int) blackButtonHighThreshold;
- (void) setBlackButtonLow: (int)low andHighThreshold: (int)high;

- (int) whiteButtonMapping;
- (void) setWhiteButtonMapping: (int)map;
- (int) whiteButtonLowThreshold;
- (int) whiteButtonHighThreshold;
- (void) setWhiteButtonLow: (int)low andHighThreshold: (int)high;

@end

