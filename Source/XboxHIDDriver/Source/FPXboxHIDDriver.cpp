//
// FPXboxHIDDriver.cpp
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
// Portions Copyright (c) 1999-2003 Apple Computer, Inc. All Rights Reserved.
//
// This file contains Original Code and/or Modifications of Original Code as defined in and that are subject to the
// Apple Public Source License Version 1.2 (the 'License'). You may not use this file except in compliance with the License.
//
// Please obtain a copy of the License at http://www.apple.com/publicsource and read it before using this file.
//
// As per license requirements see end of this file for a list of changes made to the original source code.
// =========================================================================================================================


#include "FPXboxHIDDriver.h"

#include <mach/mach_types.h>

#include <libkern/OSByteOrder.h>
#include <IOKit/IOBufferMemoryDescriptor.h>
#include <IOKit/IOMessage.h>

#include <IOKit/hid/IOHIDKeys.h>

#include <IOKit/usb/IOUSBPipe.h>

#define DEBUG_LEVEL 7 // 0=disable all logging, 7=full logging
#include <IOKit/usb/IOUSBLog.h>

#define super IOHIDDevice
OSDefineMetaClassAndStructors(FPXboxHIDDriver, super)


kern_return_t FPXboxHIDDriver_start(kmod_info_t* ki, void* d) {
	return KERN_SUCCESS;
}

kern_return_t FPXboxHIDDriver_stop(kmod_info_t* ki, void* d) {
	return KERN_SUCCESS;
}


// Do what is necessary to start device before probe is called.
bool FPXboxHIDDriver::init (OSDictionary* properties)
{
	USBLog(6, "FPXboxHIDDriver[%p]::init", this);

	if (!super::init(properties)) {
		return false;
	}

	_interface = NULL;
	_buffer = 0;
	_retryCount = kHIDDriverRetryCount;
	_outstandingIO = 0;
	_needToClose = false;
	_maxReportSize = kMaxHIDReportSize;
	_maxOutReportSize = kMaxHIDReportSize;
	_outBuffer = 0;
	_deviceUsage = 0;
	_deviceUsagePage = 0;

	_xbDeviceType = 0;
	_xbDeviceVendor = 0;
	_xbDeviceName = 0;
	_xbDeviceHIDReportDescriptor = 0;
	_xbDeviceOptionsDict = 0;
	_xbDeviceButtonMapArray = 0;
	_xbLastButtonPressed = 0;
	//_xbShouldGenerateTimedEvent = false;
	_xbTimedEventsInterval = 80; // milliseconds
	_xbWorkLoop = 0;
	_xbTimerEventSource = 0;

	return true;
}


// Note: handleStart is not an IOKit thing, but is a IOHIDDevice thing. It is called from IOHIDDevice::start after some
// initialization by that method, but before it calls registerService this method needs to open the provider, and make
// sure to have enough state (basically _interface and _device) to be able to get information from the device.
// NOTE: we do NOT need to start the interrupt read yet!
bool FPXboxHIDDriver::handleStart (IOService* provider)
{
	HIDPreparsedDataRef parseData;
	HIDCapabilities myHIDCaps;
	UInt8* myHIDDesc;
	UInt32 hidDescSize;
	IOReturn err = kIOReturnSuccess;

	USBLog(6, "%s[%p]::handleStart", getName(), this);
	if(!super::handleStart(provider)) {
		USBError(1, "%s[%p]::handleStart - super::handleStart failed", getName(), this);
		return false;
	}

	if(!provider->open(this)) {
		USBError(1, "%s[%p]::handleStart - unable to open provider", getName(), this);
		return (false);
	}

	_interface = OSDynamicCast(IOUSBInterface, provider);
	if (!_interface) {
		USBError(1, "%s[%p]::handleStart - no interface", getName(), this);
		return false;
	}

	// remember my device
	_device = _interface->GetDevice();
	if (!_device) {
		USBError(1, "%s[%p]::handleStart - no device", getName(), this);
		return false;
	}

	if (!setupDevice())
		return false;

	// Get the USB config descriptor for power requirement variable
	const IOUSBConfigurationDescriptor* config = _device->GetFullConfigurationDescriptor(0);
	_maxPower = config->MaxPower;

	// Get the size of the HID descriptor.
	hidDescSize = 0;
	err = GetHIDDescriptor(kUSBReportDesc, 0, NULL, &hidDescSize);
	if ((err != kIOReturnSuccess) || (hidDescSize == 0)) {
		USBLog(1, "%s[%p]::handleStart : unable to get descriptor size", getName(), this);
		return false;       // Won't be able to set last properties.
	}

	myHIDDesc = (UInt8*)IOMalloc(hidDescSize);
	if (myHIDDesc == NULL) {
		USBLog(1, "%s[%p]::handleStart : unable to allocate descriptor", getName(), this);
		return false;
	}

	// Get the real report descriptor.
	err = GetHIDDescriptor(kUSBReportDesc, 0, myHIDDesc, &hidDescSize);
	if (err == kIOReturnSuccess) {
		err = HIDOpenReportDescriptor(myHIDDesc, hidDescSize, &parseData, 0);
		if (err == kIOReturnSuccess) {
			err = HIDGetCapabilities(parseData, &myHIDCaps);
			if (err == kIOReturnSuccess) {
				// Just get these values!
				_deviceUsage = myHIDCaps.usage;
				_deviceUsagePage = myHIDCaps.usagePage;

				_maxOutReportSize = static_cast<unsigned int>(myHIDCaps.outputReportByteLength);
				_maxReportSize = (static_cast<unsigned int>(myHIDCaps.inputReportByteLength) > static_cast<unsigned int>(myHIDCaps.featureReportByteLength)) ?
				                 static_cast<unsigned int>(myHIDCaps.inputReportByteLength) : static_cast<unsigned int>(myHIDCaps.featureReportByteLength);
			} else {
				USBError(1, "%s[%p]::handleStart - failed getting capabilities", getName(), this);
			}
			HIDCloseReportDescriptor(parseData);
		} else {
			USBError(1, "%s[%p]::handleStart - failed parsing descriptor", getName(), this);
		}
	} else {
		USBLog(1, "%s[%p]::handleStart : error getting hid descriptor: %X", getName(), this, err);
	}

	if (myHIDDesc)
		IOFree(myHIDDesc, hidDescSize);

	return true;
}


void FPXboxHIDDriver::handleStop (IOService* provider)
{
	USBLog(7, "%s[%p]::handleStop", getName(), this);

	// cleanup timer
	if (_xbWorkLoop && _xbTimerEventSource) {
		_xbTimerEventSource->cancelTimeout();
		_xbWorkLoop->removeEventSource(_xbTimerEventSource);
		_xbTimerEventSource->release();
		_xbTimerEventSource = 0;
	}

	if (_outBuffer) {
		_outBuffer->release();
		_outBuffer = NULL;
	}

	if (_buffer) {
		_buffer->release();
		_buffer = NULL;
	}

	if (_deviceDeadCheckThread) {
		thread_call_cancel(_deviceDeadCheckThread);
		thread_call_free(_deviceDeadCheckThread);
	}

	if (_clearFeatureEndpointHaltThread) {
		thread_call_cancel(_clearFeatureEndpointHaltThread);
		thread_call_free(_clearFeatureEndpointHaltThread);
	}

	super::handleStop(provider);
}


void FPXboxHIDDriver::free (void)
{
	USBLog(6, "%s[%p]::free", getName(), this);

	super::free();
}


void FPXboxHIDDriver::processPacket (void* data, UInt32 size)
{
	IOLog("Should not be here, FPXboxHIDDriver::processPacket()\n");

	return;
}


// In Mac OS X 64-bit, there is no way to directly modify the IORegistry (change by macman860)
// Instead, the solution to a working preference pane is to make a deep copy of the values and modify them. However, I couln't
// find enough documentation for implementing the "OSCollection * copyCollection (OSDictionary cycleDict = 0)" code, so I ended
// up fixing the problem a different way. Basically I created a new dictionary and called in the default values. Then I overwrote
// the new values (optionKey & optionValue) with setObject, and finally used setProperty to replace the old "Options" property.
IOReturn FPXboxHIDDriver::setProperties (OSObject* properties)
{
	// called from IORegistryEntrySetCFProperties() from user context
	USBLog(6, "%s[%p]::setProperties", getName(), this);

	OSDictionary* dict;
	OSString* deviceType;

	dict = OSDynamicCast(OSDictionary, properties);
	if (dict) {
		// Check if client wants to manipulate device options
		deviceType = OSDynamicCast(OSString, dict->getObject(kTypeKey));
		if (deviceType && _xbDeviceType->isEqualTo(deviceType)) {
			USBLog(6, "%s[%p]::setProperties - change properties for a %s device", getName(), this, deviceType->getCStringNoCopy());

			OSString* optionKey = OSDynamicCast(OSString, dict->getObject(kClientOptionKeyKey));
			OSObject* optionValue = OSDynamicCast(OSObject, dict->getObject(kClientOptionValueKey));

			_xbDeviceOptionsDict = OSDictionary::withCapacity(0);

			//setDefaultOptions();
			OSBoolean* boolean;
			OSNumber* number;

#define SET_BOOLEAN(prop) \
	boolean = OSBoolean::withBoolean(_xbDeviceOptions.pad.prop ); \
	if (boolean) { \
		_xbDeviceOptionsDict->setObject(kOption ## prop ## Key, boolean); \
		boolean->release(); \
	}

#define SET_UINT8_NUMBER(prop) \
	number = OSNumber::withNumber(_xbDeviceOptions.pad.prop, 8); \
	if (number) { \
		_xbDeviceOptionsDict->setObject(kOption ## prop ## Key, number); \
		number->release(); \
	}
			SET_BOOLEAN(InvertLxAxis);
			SET_UINT8_NUMBER(DeadzoneLxAxis);
			SET_UINT8_NUMBER(MappingLxAxis);

			SET_BOOLEAN(InvertLyAxis);
			SET_UINT8_NUMBER(DeadzoneLyAxis);
			SET_UINT8_NUMBER(MappingLyAxis);

			SET_UINT8_NUMBER(MappingLeftClick);

			SET_BOOLEAN(InvertRxAxis);
			SET_UINT8_NUMBER(DeadzoneRxAxis);
			SET_UINT8_NUMBER(MappingRxAxis);

			SET_BOOLEAN(InvertRyAxis);
			SET_UINT8_NUMBER(DeadzoneRyAxis);
			SET_UINT8_NUMBER(MappingRyAxis);

			SET_UINT8_NUMBER(MappingRightClick);

			SET_UINT8_NUMBER(MappingDPadUp);
			SET_UINT8_NUMBER(MappingDPadDown);
			SET_UINT8_NUMBER(MappingDPadLeft);
			SET_UINT8_NUMBER(MappingDPadRight);

			SET_UINT8_NUMBER(MappingButtonStart);
			SET_UINT8_NUMBER(MappingButtonBack);

			SET_UINT8_NUMBER(AnalogAsDigital);

			SET_UINT8_NUMBER(MappingButtonGreen);
			SET_UINT8_NUMBER(ThresholdLowButtonGreen);
			SET_UINT8_NUMBER(ThresholdHighButtonGreen);

			SET_UINT8_NUMBER(MappingButtonRed);
			SET_UINT8_NUMBER(ThresholdLowButtonRed);
			SET_UINT8_NUMBER(ThresholdHighButtonRed);

			SET_UINT8_NUMBER(MappingButtonBlue);
			SET_UINT8_NUMBER(ThresholdLowButtonBlue);
			SET_UINT8_NUMBER(ThresholdHighButtonBlue);

			SET_UINT8_NUMBER(MappingButtonYellow);
			SET_UINT8_NUMBER(ThresholdLowButtonYellow);
			SET_UINT8_NUMBER(ThresholdHighButtonYellow);

			SET_UINT8_NUMBER(MappingButtonBlack);
			SET_UINT8_NUMBER(ThresholdLowButtonBlack);
			SET_UINT8_NUMBER(ThresholdHighButtonBlack);

			SET_UINT8_NUMBER(MappingButtonWhite);
			SET_UINT8_NUMBER(ThresholdLowButtonWhite);
			SET_UINT8_NUMBER(ThresholdHighButtonWhite);

			SET_BOOLEAN(AlternateLeftTrigger);
			SET_UINT8_NUMBER(MappingLeftTrigger);
			SET_UINT8_NUMBER(ThresholdLowLeftTrigger);
			SET_UINT8_NUMBER(ThresholdHighLeftTrigger);

			SET_BOOLEAN(AlternateRightTrigger);
			SET_UINT8_NUMBER(MappingRightTrigger);
			SET_UINT8_NUMBER(ThresholdLowRightTrigger);
			SET_UINT8_NUMBER(ThresholdHighRightTrigger);

#undef SET_UINT8_NUMBER
#undef SET_BOOLEAN

			_xbDeviceOptionsDict->setObject(optionKey, optionValue);

			if (dict && optionKey && optionValue) {
				setProperty(kDeviceOptionsKey, _xbDeviceOptionsDict);

				// rescan properties for options
				setDeviceOptions();

				return kIOReturnSuccess;
			}
		} else {
			USBLog(6, "%s[%p]::setProperties - changing HID elements", getName(), this);

			// check if client wants to change the HID elements structure
			OSArray* newElements = OSDynamicCast(OSArray, dict->getObject(kClientOptionSetElementsKey));
			if (newElements) {
				setProperty(kIOHIDElementKey, newElements);
				return kIOReturnSuccess;
			}
		}
	}

	return kIOReturnError;
}

void FPXboxHIDDriver::generateTimedEvent (OSObject* object, IOTimerEventSource* tes)
{
	FPXboxHIDDriver* driver = OSDynamicCast(FPXboxHIDDriver, object);
	if (driver) {
		//USBLog(1, "should generate event here...");
		if (driver->_xbDeviceType->isEqualTo(kDeviceTypeIRKey)) {
			if (driver->_buffer) {
				void* bytes = driver->_buffer->getBytesNoCopy();
				int len = static_cast<unsigned int>(driver->_buffer->getLength());
				if (len == sizeof(XBRemoteReport)) {
					memset(bytes, 0, len);
					driver->handleReport(driver->_buffer);
					driver->_xbLastButtonPressed = 0;
				}
			}
		}
	}
}


void FPXboxHIDDriver::setDefaultOptions (void)
{
	if (_xbDeviceType->isEqualTo(kDeviceTypePadKey)) {
		_xbDeviceOptions.pad.MappingLxAxis = kCookiePadLxAxis;
		_xbDeviceOptions.pad.InvertLxAxis = false;
		_xbDeviceOptions.pad.DeadzoneLxAxis = 0;

		_xbDeviceOptions.pad.MappingLyAxis = kCookiePadLyAxis;
		_xbDeviceOptions.pad.InvertLyAxis = true;
		_xbDeviceOptions.pad.DeadzoneLyAxis = 0;

		_xbDeviceOptions.pad.MappingLeftClick = kCookiePadLeftClick;

		_xbDeviceOptions.pad.MappingRxAxis = kCookiePadRxAxis;
		_xbDeviceOptions.pad.InvertRxAxis = false;
		_xbDeviceOptions.pad.DeadzoneRxAxis = 0;

		_xbDeviceOptions.pad.MappingRyAxis = kCookiePadRyAxis;
		_xbDeviceOptions.pad.InvertRyAxis = true;
		_xbDeviceOptions.pad.DeadzoneRyAxis = 0;

		_xbDeviceOptions.pad.MappingRightClick = kCookiePadRightClick;

		_xbDeviceOptions.pad.MappingDPadUp = kCookiePadDPadUp;
		_xbDeviceOptions.pad.MappingDPadDown = kCookiePadDPadDown;
		_xbDeviceOptions.pad.MappingDPadLeft = kCookiePadDPadLeft;
		_xbDeviceOptions.pad.MappingDPadRight = kCookiePadDPadRight;

		_xbDeviceOptions.pad.MappingButtonStart = kCookiePadButtonStart;
		_xbDeviceOptions.pad.MappingButtonBack = kCookiePadButtonBack;

		// Face buttons are digital, triggers are analog by default
		_xbDeviceOptions.pad.AnalogAsDigital = (BITMASK(kXboxAnalogButtonGreen) | BITMASK(kXboxAnalogButtonRed)	   |
												BITMASK(kXboxAnalogButtonBlue)  | BITMASK(kXboxAnalogButtonYellow) |
												BITMASK(kXboxAnalogButtonWhite) | BITMASK(kXboxAnalogButtonBlack));

		_xbDeviceOptions.pad.MappingButtonGreen = kCookiePadButtonGreen;
		_xbDeviceOptions.pad.ThresholdLowButtonGreen = 1;
		_xbDeviceOptions.pad.ThresholdHighButtonGreen = 255;

		_xbDeviceOptions.pad.MappingButtonRed = kCookiePadButtonRed;
		_xbDeviceOptions.pad.ThresholdLowButtonRed = 1;
		_xbDeviceOptions.pad.ThresholdHighButtonRed = 255;

		_xbDeviceOptions.pad.MappingButtonBlue = kCookiePadButtonBlue;
		_xbDeviceOptions.pad.ThresholdLowButtonBlue = 1;
		_xbDeviceOptions.pad.ThresholdHighButtonBlue = 255;

		_xbDeviceOptions.pad.MappingButtonYellow = kCookiePadButtonYellow;
		_xbDeviceOptions.pad.ThresholdLowButtonYellow = 1;
		_xbDeviceOptions.pad.ThresholdHighButtonYellow = 255;

		_xbDeviceOptions.pad.MappingButtonBlack = kCookiePadButtonBlack;
		_xbDeviceOptions.pad.ThresholdLowButtonBlack = 1;
		_xbDeviceOptions.pad.ThresholdHighButtonBlack = 255;

		_xbDeviceOptions.pad.MappingButtonWhite = kCookiePadButtonWhite;
		_xbDeviceOptions.pad.ThresholdLowButtonWhite = 1;
		_xbDeviceOptions.pad.ThresholdHighButtonWhite = 255;

		_xbDeviceOptions.pad.AlternateLeftTrigger = 0;
		_xbDeviceOptions.pad.MappingLeftTrigger = kCookiePadLeftTrigger;
		_xbDeviceOptions.pad.ThresholdLowLeftTrigger = 1;
		_xbDeviceOptions.pad.ThresholdHighLeftTrigger = 255;

		_xbDeviceOptions.pad.AlternateRightTrigger = 0;
		_xbDeviceOptions.pad.MappingRightTrigger = kCookiePadRightTrigger;
		_xbDeviceOptions.pad.ThresholdLowRightTrigger = 1;
		_xbDeviceOptions.pad.ThresholdHighRightTrigger = 255;

		// create options dict and populate it with defaults
		_xbDeviceOptionsDict = OSDictionary::withCapacity(30);
		if (_xbDeviceOptionsDict) {
			OSBoolean* boolean;
			OSNumber* number;

#define SET_BOOLEAN(prop) \
	boolean = OSBoolean::withBoolean(_xbDeviceOptions.pad.prop ); \
	if (boolean) { \
		_xbDeviceOptionsDict->setObject(kOption ## prop ## Key, boolean); \
		boolean->release(); \
	}

#define SET_UINT8_NUMBER(prop) \
	number = OSNumber::withNumber(_xbDeviceOptions.pad.prop, 8); \
	if (number) { \
		_xbDeviceOptionsDict->setObject(kOption ## prop ## Key, number); \
		number->release(); \
	}
			SET_BOOLEAN(InvertLxAxis);
			SET_UINT8_NUMBER(DeadzoneLxAxis);
			SET_UINT8_NUMBER(MappingLxAxis);

			SET_BOOLEAN(InvertLyAxis);
			SET_UINT8_NUMBER(DeadzoneLyAxis);
			SET_UINT8_NUMBER(MappingLyAxis);

			SET_UINT8_NUMBER(MappingLeftClick);

			SET_BOOLEAN(InvertRxAxis);
			SET_UINT8_NUMBER(DeadzoneRxAxis);
			SET_UINT8_NUMBER(MappingRxAxis);

			SET_BOOLEAN(InvertRyAxis);
			SET_UINT8_NUMBER(DeadzoneRyAxis);
			SET_UINT8_NUMBER(MappingRyAxis);

			SET_UINT8_NUMBER(MappingRightClick);

			SET_UINT8_NUMBER(MappingDPadUp);
			SET_UINT8_NUMBER(MappingDPadDown);
			SET_UINT8_NUMBER(MappingDPadLeft);
			SET_UINT8_NUMBER(MappingDPadRight);

			SET_UINT8_NUMBER(MappingButtonStart);
			SET_UINT8_NUMBER(MappingButtonBack);

			SET_UINT8_NUMBER(AnalogAsDigital);

			SET_UINT8_NUMBER(MappingButtonGreen);
			SET_UINT8_NUMBER(ThresholdLowButtonGreen);
			SET_UINT8_NUMBER(ThresholdHighButtonGreen);

			SET_UINT8_NUMBER(MappingButtonRed);
			SET_UINT8_NUMBER(ThresholdLowButtonRed);
			SET_UINT8_NUMBER(ThresholdHighButtonRed);

			SET_UINT8_NUMBER(MappingButtonBlue);
			SET_UINT8_NUMBER(ThresholdLowButtonBlue);
			SET_UINT8_NUMBER(ThresholdHighButtonBlue);

			SET_UINT8_NUMBER(MappingButtonYellow);
			SET_UINT8_NUMBER(ThresholdLowButtonYellow);
			SET_UINT8_NUMBER(ThresholdHighButtonYellow);

			SET_UINT8_NUMBER(MappingButtonBlack);
			SET_UINT8_NUMBER(ThresholdLowButtonBlack);
			SET_UINT8_NUMBER(ThresholdHighButtonBlack);

			SET_UINT8_NUMBER(MappingButtonWhite);
			SET_UINT8_NUMBER(ThresholdLowButtonWhite);
			SET_UINT8_NUMBER(ThresholdHighButtonWhite);

			SET_BOOLEAN(AlternateLeftTrigger);
			SET_UINT8_NUMBER(MappingLeftTrigger);
			SET_UINT8_NUMBER(ThresholdLowLeftTrigger);
			SET_UINT8_NUMBER(ThresholdHighLeftTrigger);

			SET_BOOLEAN(AlternateRightTrigger);
			SET_UINT8_NUMBER(MappingRightTrigger);
			SET_UINT8_NUMBER(ThresholdLowRightTrigger);
			SET_UINT8_NUMBER(ThresholdHighRightTrigger);

#undef SET_BOOLEAN
#undef SET_UINT8_NUMBER
		}
	} else {
		_xbDeviceOptionsDict = OSDictionary::withCapacity(1);
	}

	// add options dict to our properties
	if (_xbDeviceOptionsDict)
		setProperty(kDeviceOptionsKey, _xbDeviceOptionsDict);
}

void FPXboxHIDDriver::setDeviceOptions (void)
{
	if (_xbDeviceType->isEqualTo(kDeviceTypePadKey)) {

		// override defaults with xml settings
		if (_xbDeviceOptionsDict) {
			OSBoolean* boolean;
			OSNumber* number;

#define GET_BOOLEAN(field) \
	boolean = OSDynamicCast(OSBoolean, _xbDeviceOptionsDict->getObject(kOption ## field ## Key)); \
	if (boolean) \
		_xbDeviceOptions.pad.field = boolean->getValue()

#define GET_UINT8_NUMBER(field) \
	number = OSDynamicCast(OSNumber, _xbDeviceOptionsDict->getObject(kOption ## field ## Key)); \
	if (number) \
		_xbDeviceOptions.pad.field = number->unsigned8BitValue()

			GET_BOOLEAN(InvertLxAxis);
			GET_UINT8_NUMBER(DeadzoneLxAxis);
			GET_UINT8_NUMBER(MappingLxAxis);

			GET_BOOLEAN(InvertLyAxis);
			GET_UINT8_NUMBER(DeadzoneLyAxis);
			GET_UINT8_NUMBER(MappingLyAxis);

			GET_UINT8_NUMBER(MappingLeftClick);

			GET_BOOLEAN(InvertRxAxis);
			GET_UINT8_NUMBER(DeadzoneRxAxis);
			GET_UINT8_NUMBER(MappingRxAxis);

			GET_BOOLEAN(InvertRyAxis);
			GET_UINT8_NUMBER(DeadzoneRyAxis);
			GET_UINT8_NUMBER(MappingRyAxis);

			GET_UINT8_NUMBER(MappingRightClick);

			GET_UINT8_NUMBER(MappingDPadUp);
			GET_UINT8_NUMBER(MappingDPadDown);
			GET_UINT8_NUMBER(MappingDPadLeft);
			GET_UINT8_NUMBER(MappingDPadRight);

			GET_UINT8_NUMBER(MappingButtonStart);
			GET_UINT8_NUMBER(MappingButtonBack);

			GET_UINT8_NUMBER(AnalogAsDigital);

			GET_UINT8_NUMBER(MappingButtonGreen);
			GET_UINT8_NUMBER(ThresholdLowButtonGreen);
			GET_UINT8_NUMBER(ThresholdHighButtonGreen);

			GET_UINT8_NUMBER(MappingButtonRed);
			GET_UINT8_NUMBER(ThresholdLowButtonRed);
			GET_UINT8_NUMBER(ThresholdHighButtonRed);

			GET_UINT8_NUMBER(MappingButtonBlue);
			GET_UINT8_NUMBER(ThresholdLowButtonBlue);
			GET_UINT8_NUMBER(ThresholdHighButtonBlue);

			GET_UINT8_NUMBER(MappingButtonYellow);
			GET_UINT8_NUMBER(ThresholdLowButtonYellow);
			GET_UINT8_NUMBER(ThresholdHighButtonYellow);

			GET_UINT8_NUMBER(MappingButtonBlack);
			GET_UINT8_NUMBER(ThresholdLowButtonBlack);
			GET_UINT8_NUMBER(ThresholdHighButtonBlack);

			GET_UINT8_NUMBER(MappingButtonWhite);
			GET_UINT8_NUMBER(ThresholdLowButtonWhite);
			GET_UINT8_NUMBER(ThresholdHighButtonWhite);

			GET_BOOLEAN(AlternateLeftTrigger);
			GET_UINT8_NUMBER(MappingLeftTrigger);
			GET_UINT8_NUMBER(ThresholdLowLeftTrigger);
			GET_UINT8_NUMBER(ThresholdHighLeftTrigger);

			GET_BOOLEAN(AlternateRightTrigger);
			GET_UINT8_NUMBER(MappingRightTrigger);
			GET_UINT8_NUMBER(ThresholdLowRightTrigger);
			GET_UINT8_NUMBER(ThresholdHighRightTrigger);

#undef GET_BOOLEAN
#undef GET_UINT8_NUMBER
		}
	}
}

bool FPXboxHIDDriver::setupDevice (void)
{
	// called from handleStart()
	OSDictionary* deviceDict = 0;

	// Load the driver's deviceData dictionary
	OSDictionary* dataDict = OSDynamicCast(OSDictionary, getProperty(kDeviceDataKey));
	if (!dataDict) {
		USBError(1, "%s[%p]::setupDevice - no data dictionary", getName(), this);
		return false;
	}

	// Check that we have a device type (just in case...)
	if (_xbDeviceType) {
		// ...and put in our properties for clients to see
		setProperty(kTypeKey, _xbDeviceType);
	}

	// Get device-specific dictionary
	deviceDict = OSDynamicCast(OSDictionary, dataDict->getObject(_xbDeviceType));
	if (!deviceDict) {
		USBError(1, "%s[%p]::setupDevice - no device support dictionary", getName(), this);
		return false;
	}

	// Finally load the HID descriptor
	_xbDeviceHIDReportDescriptor = OSDynamicCast(OSData, deviceDict->getObject(kDeviceHIDReportDescriptorKey));
	if (!_xbDeviceHIDReportDescriptor || _xbDeviceHIDReportDescriptor->getLength() <= 0) {
		USBLog(1, "%s[%p]::setupDevice - no hid descriptor for device", getName(), this);
		return false;
	}

	// Get the button map (remote control only - can be NULL)
	_xbDeviceButtonMapArray = OSDynamicCast(OSArray, deviceDict->getObject(kDeviceButtonMapKey));

	// If the device is a remote control, setup a timer for generating button-release events
	if (_xbDeviceType->isEqualTo(kDeviceTypeIRKey)) {
		_xbWorkLoop = getWorkLoop();
		if (_xbWorkLoop) {
			_xbTimerEventSource = IOTimerEventSource::timerEventSource(this, &generateTimedEvent);
			if (_xbTimerEventSource) {
				if (kIOReturnSuccess != _xbWorkLoop->addEventSource(_xbTimerEventSource)) {
					USBLog(1, "%s[%p]::setupDevice - couldn't establish a timer", getName(), this);
					return false;
				}
			}
		}
	}

	// Set default device options
	setDefaultOptions();

	return true;
}


XBPadReport* FPXboxHIDDriver::lastRawReport (void)
{
	return &_rawReport;
}


#define IS_DIGITAL(mask)	(_xbDeviceOptions.pad.AnalogAsDigital & BITMASK(kXboxAnalog ## mask))

// this function is only called when value is NOT zero!
void FPXboxHIDDriver::remapElement (int map, XBPadReport* report, int value)
{
	switch (map) {
		// analog buttons
		case kCookiePadButtonGreen:
			if (value > report->a)
				report->a = value;
			break;
		case kCookiePadButtonRed:
			if (value > report->b)
				report->b = value;
			break;
		case kCookiePadButtonBlue:
			if (value > report->x)
				report->x = value;
			break;
		case kCookiePadButtonYellow:
			if (value > report->y)
				report->y = value;
			break;
		case kCookiePadButtonWhite:
			if (value > report->white)
				report->white = value;
			break;
		case kCookiePadButtonBlack:
			if (value > report->black)
				report->black = value;
			break;
		case kCookiePadLeftTrigger:
			if (value > report->lt)
				report->lt = value;
			break;
		case kCookiePadRightTrigger:
			if (value > report->rt)
				report->rt = value;
			break;

		// digital buttons
		case kCookiePadDPadUp:
			report->buttons |= BITMASK(kXboxDigitalDPadUp);
			break;
		case kCookiePadDPadDown:
			report->buttons |= BITMASK(kXboxDigitalDPadDown);
			break;
		case kCookiePadDPadLeft:
			report->buttons |= BITMASK(kXboxDigitalDPadLeft);
			break;
		case kCookiePadDPadRight:
			report->buttons |= BITMASK(kXboxDigitalDPadRight);
			break;
		case kCookiePadButtonStart:
			report->buttons |= BITMASK(kXboxDigitalButtonStart);
			break;
		case kCookiePadButtonBack:
			report->buttons |= BITMASK(kXboxDigitalButtonBack);
			break;
		case kCookiePadLeftClick:
			report->buttons |= BITMASK(kXboxDigitalLeftClick);
			break;
		case kCookiePadRightClick:
			report->buttons |= BITMASK(kXboxDigitalRightClick);
			break;

		// analog axis
		case kCookiePadLxAxis:
			report->lxhi = (value >> 8);
			report->lxlo = (value & 0xFF);
			break;
		case kCookiePadLyAxis:
			report->lyhi = (value >> 8);
			report->lylo = (value & 0xFF);
			break;
		case kCookiePadRxAxis:
			report->rxhi = (value >> 8);
			report->rxlo = (value & 0xFF);
			break;
		case kCookiePadRyAxis:
			report->ryhi = (value >> 8);
			report->rylo = (value & 0xFF);
			break;

		// pseudo elements
		case kCookiePadTriggers:
			if (value > 0)
				report->rt = 255 * (value / 32767.0);
			else
				report->lt = 255 * (-value / 32768.0);
			break;
		case kCookiePadGreenRed:
			if (value > 0)
				report->b = 255 * (value / 32767.0);
			else
				report->a = 255 * (-value / 32768.0);
			break;
		case kCookiePadBlueYellow:
			if (value > 0)
				report->y = 255 * (value / 32767.0);
			else
				report->x = 255 * (-value / 32768.0);
			break;
		case kCookiePadGreenYellow:
			if (value > 0)
				report->y = 255 * (value / 32767.0);
			else
				report->a = 255 * (-value / 32768.0);
			break;
		case kCookiePadBlueRed:
			if (value > 0)
				report->b = 255 * (value / 32767.0);
			else
				report->x = 255 * (-value / 32768.0);
			break;
		case kCookiePadRedYellow:
			if (value > 0)
				report->y = 255 * (value / 32767.0);
			else
				report->b = 255 * (-value / 32768.0);
			break;
		case kCookiePadGreenBlue:
			if (value > 0)
				report->x = 255 * (value / 32767.0);
			else
				report->a = 255 * (-value / 32768.0);
			break;
		case kCookiePadWhiteBlack:
			if (value > 0)
				report->black = 255 * (value / 32767.0);
			else
				report->white = 255 * (-value / 32768.0);
			break;
		case kCookiePadDPadUpDown:
			if (value > 0)
				report->buttons |= BITMASK(kXboxDigitalDPadDown);
			else
				report->buttons |= BITMASK(kXboxDigitalDPadUp);
			break;
		case kCookiePadDPadLeftRight:
			if (value > 0)
				report->buttons |= BITMASK(kXboxDigitalDPadRight);
			else
				report->buttons |= BITMASK(kXboxDigitalDPadLeft);
			break;
		case kCookiePadStartBack:
			if (value > 0)
				report->buttons |= BITMASK(kXboxDigitalButtonBack);
			else
				report->buttons |= BITMASK(kXboxDigitalButtonStart);
			break;
		case kCookiePadClickLeftRight:
			if (value > 0)
				report->buttons |= BITMASK(kXboxDigitalRightClick);
			else
				report->buttons |= BITMASK(kXboxDigitalLeftClick);
			break;
	}
}


bool FPXboxHIDDriver::manipulateReport (IOBufferMemoryDescriptor* report)
{
	// change the report before it's sent to the HID layer
	// return true if report should be sent to HID layer,
	// so that we can ignore certain reports
	if (_xbDeviceType->isEqualTo(kDeviceTypePadKey) &&  report->getLength() == sizeof(XBPadReport)) {
		XBPadReport* raw = (XBPadReport*)(report->getBytesNoCopy());
		_rawReport = *raw; // For raw reporting via IOUserClient

#define INVERT_AXIS(name, axis) \
	if (_xbDeviceOptions.pad.Invert ## axis ## Axis) { \
		SInt16 name = (raw->name ## hi << 8) | raw->name ## lo; \
		name = -(name + 1); \
		raw->name ## hi = name >> 8; \
		raw->name ## lo = name & 0xFF; \
	}
		INVERT_AXIS(lx, Lx);
		INVERT_AXIS(ly, Ly);
		INVERT_AXIS(rx, Rx);
		INVERT_AXIS(ry, Ry);

#undef INVERT_AXIS

#define CLAMP_AXIS(name, dead) \
	if (_xbDeviceOptions.pad.Deadzone ## dead ## Axis) { \
		SInt16 name = ((raw->name ## hi << 8) | raw->name ## lo); \
		int threshold = (32768 * (_xbDeviceOptions.pad.Deadzone ## dead ## Axis / 100.0)); \
		if ((name > 0 && name <= threshold) || (name < 0 && name >= -threshold)) { \
			raw->name ## hi = 0; \
			raw->name ## lo = 0; \
		} else if (name != 0) { \
			if (name < 0) \
				name = -(32768 * ((-name - threshold) / (32768.0 - threshold))); \
			else \
				name = 32768 * ((name - threshold - 1) / (32768.0 - threshold)); \
			raw->name ## hi = (name >> 8); \
			raw->name ## lo = (name & 0xFF); \
		} \
	}
		CLAMP_AXIS(lx, Lx);
		CLAMP_AXIS(ly, Ly);

		CLAMP_AXIS(rx, Rx);
		CLAMP_AXIS(ry, Ry);

#undef CLAMP_AXIS

#define CLAMP_BUTTON(name, button) \
	if (raw->name > _xbDeviceOptions.pad.ThresholdLow ## button) { \
		if (raw->name < _xbDeviceOptions.pad.ThresholdHigh ## button) { \
			float range = _xbDeviceOptions.pad.ThresholdHigh ## button - _xbDeviceOptions.pad.ThresholdLow ## button; \
			raw->name = 255 * ((raw->name - _xbDeviceOptions.pad.ThresholdLow ## button) / range); \
		} else { \
			raw->name = 255; \
		} \
	} else { \
		raw->name = 0; \
	}

		CLAMP_BUTTON(a, ButtonGreen);
		CLAMP_BUTTON(b, ButtonRed);
		CLAMP_BUTTON(x, ButtonBlue);
		CLAMP_BUTTON(y, ButtonYellow);
		CLAMP_BUTTON(black, ButtonBlack);
		CLAMP_BUTTON(white, ButtonWhite);
		CLAMP_BUTTON(lt, LeftTrigger);
		CLAMP_BUTTON(rt, RightTrigger);

#undef CLAMP_BUTTON

#define MAP_ANALOG(name, button) \
	if (_xbDeviceOptions.pad.Mapping ## button && _xbDeviceOptions.pad.Mapping ## button != kCookiePad ## button && raw->name) \
		FPXboxHIDDriver::remapElement(_xbDeviceOptions.pad.Mapping ## button, &_mapReport, raw->name); \
	else if (_xbDeviceOptions.pad.Mapping ## button && raw->name > _mapReport.name) \
		_mapReport.name = raw->name

#define MAP_DIGITAL(button) \
	if (_xbDeviceOptions.pad.Mapping ## button && _xbDeviceOptions.pad.Mapping ## button != kCookiePad ## button && (raw->buttons & BITMASK(kXboxDigital ## button))) \
		FPXboxHIDDriver::remapElement(_xbDeviceOptions.pad.Mapping ## button, &_mapReport, 255); \
	else if (_xbDeviceOptions.pad.Mapping ## button && raw->buttons & BITMASK(kXboxDigital ## button)) \
		_mapReport.buttons |= BITMASK(kXboxDigital ## button)

#define MAP_AXIS(name, axis) \
	SInt16 name = ((raw->name ## hi << 8) | raw->name ## lo); \
	if (_xbDeviceOptions.pad.Mapping ## axis && _xbDeviceOptions.pad.Mapping ## axis != kCookiePad ## axis && name) \
		FPXboxHIDDriver::remapElement(_xbDeviceOptions.pad.Mapping ## axis, &_mapReport, name); \
	else if (_xbDeviceOptions.pad.Mapping ## axis && name) { \
		_mapReport.name ## hi = raw->name ## hi; \
		_mapReport.name ## lo = raw->name ## hi; \
	}

		memset(&_mapReport, 0, sizeof(XBPadReport));

		MAP_ANALOG(a, ButtonGreen);
		MAP_ANALOG(b, ButtonRed);
		MAP_ANALOG(x, ButtonBlue);
		MAP_ANALOG(y, ButtonYellow);
		MAP_ANALOG(white, ButtonWhite);
		MAP_ANALOG(black, ButtonBlack);
		MAP_ANALOG(lt, LeftTrigger);
		MAP_ANALOG(rt, RightTrigger);

		MAP_DIGITAL(DPadUp);
		MAP_DIGITAL(DPadDown);
		MAP_DIGITAL(DPadLeft);
		MAP_DIGITAL(DPadRight);
		MAP_DIGITAL(ButtonStart);
		MAP_DIGITAL(ButtonBack);
		MAP_DIGITAL(LeftClick);
		MAP_DIGITAL(RightClick);

		MAP_AXIS(lx, LxAxis);
		MAP_AXIS(ly, LyAxis);
		MAP_AXIS(rx, RxAxis);
		MAP_AXIS(ry, RyAxis);

#undef MAPPING_ANALOG
#undef MAPPING_DIGITAL

#define ANALOG_DIGITAL(name, button) \
	if (IS_DIGITAL(button) && raw->name > 0) \
		raw->name = 1;

		ANALOG_DIGITAL(a, ButtonGreen);
		ANALOG_DIGITAL(b, ButtonRed);
		ANALOG_DIGITAL(x, ButtonBlue);
		ANALOG_DIGITAL(y, ButtonYellow);
		ANALOG_DIGITAL(white, ButtonWhite);
		ANALOG_DIGITAL(black, ButtonBlack);
		ANALOG_DIGITAL(lt, LeftTrigger);
		ANALOG_DIGITAL(rt, RightTrigger);

#undef ANALOG_DIGITAL

		*raw = _mapReport;
//		_mapReport.r1 = _rawReport.r1;		// Reserved; always 0x00
		_mapReport.r2 = _rawReport.r2;		// Report length
//		_mapReport.r3 = _rawReport.r3;		// Reserved; always 0x00

	} else if (_xbDeviceType->isEqualTo(kDeviceTypeIRKey) && report->getLength() == sizeof(XBActualRemoteReport) && _xbDeviceButtonMapArray) {
		XBActualRemoteReport* raw = (XBActualRemoteReport*)(report->getBytesNoCopy());
		UInt8 scancode = raw->scancode;
		UInt8 testScancode;
		XBRemoteReport* converted = (XBRemoteReport*)raw;
		OSNumber* number;

		if (scancode == _xbLastButtonPressed)
			return false;     // remote sends many events when holding down a button.. skip 'em
		else
			_xbLastButtonPressed = scancode;

#define SET_REPORT_FIELD(field, index) \
	number = OSDynamicCast(OSNumber, _xbDeviceButtonMapArray->getObject(index)); \
	if (number) { \
		testScancode = number->unsigned8BitValue(); \
		if (scancode == testScancode) \
			converted->field = 1; \
		else \
			converted->field = 0; \
	}
		SET_REPORT_FIELD(select, kRemoteSelect);
		SET_REPORT_FIELD(up, kRemoteUp);
		SET_REPORT_FIELD(down, kRemoteDown);
		SET_REPORT_FIELD(left, kRemoteLeft);
		SET_REPORT_FIELD(right, kRemoteRight);
		SET_REPORT_FIELD(title, kRemoteTitle);
		SET_REPORT_FIELD(info, kRemoteInfo);
		SET_REPORT_FIELD(menu, kRemoteMenu);
		SET_REPORT_FIELD(back, kRemoteBack);
		SET_REPORT_FIELD(display, kRemoteDisplay);
		SET_REPORT_FIELD(play, kRemotePlay);
		SET_REPORT_FIELD(stop, kRemoteStop);
		SET_REPORT_FIELD(pause, kRemotePause);
		SET_REPORT_FIELD(reverse, kRemoteReverse);
		SET_REPORT_FIELD(forward, kRemoteForward);
		SET_REPORT_FIELD(skipBackward, kRemoteSkipBackward);
		SET_REPORT_FIELD(skipForward, kRemoteSkipForward);
		SET_REPORT_FIELD(kp0, kRemoteKP0);
		SET_REPORT_FIELD(kp1, kRemoteKP1);
		SET_REPORT_FIELD(kp2, kRemoteKP2);
		SET_REPORT_FIELD(kp3, kRemoteKP3);
		SET_REPORT_FIELD(kp4, kRemoteKP4);
		SET_REPORT_FIELD(kp5, kRemoteKP5);
		SET_REPORT_FIELD(kp6, kRemoteKP6);
		SET_REPORT_FIELD(kp7, kRemoteKP7);
		SET_REPORT_FIELD(kp8, kRemoteKP8);
		SET_REPORT_FIELD(kp9, kRemoteKP9);

#undef SET_REPORT_FIELD
	}

	return true;
}

bool FPXboxHIDDriver::isKnownDevice (IOService* provider)
{
	// Check for a known vendor and product id
	bool isKnown = false;

	IOUSBInterface* interface = OSDynamicCast(IOUSBInterface, provider);

	if (interface) {
		IOUSBDevice* device = interface->GetDevice();
		if (device) {
			char productID[8], vendorID[8];

			// get product and vendor id
			snprintf(vendorID, 8, "%d", device->GetVendorID());
			snprintf(productID, 8, "%d", device->GetProductID());

			OSDictionary* dataDict = OSDynamicCast(OSDictionary, getProperty(kDeviceDataKey));
			if (dataDict) {
				OSDictionary* vendors = OSDynamicCast(OSDictionary, dataDict->getObject(kKnownDevicesKey));
				if (vendors) {
					OSDictionary* vendor = OSDynamicCast(OSDictionary, vendors->getObject(vendorID));
					if (vendor) {
						OSDictionary* product = OSDynamicCast(OSDictionary, vendor->getObject(productID));
						if (product) {
							OSString* typeName, * deviceName, * vendorName;

							typeName = OSDynamicCast(OSString, product->getObject(kTypeKey));
							deviceName = OSDynamicCast(OSString, product->getObject(kNameKey));
							vendorName = OSDynamicCast(OSString, vendor->getObject(kVendorKey));

							USBLog(4,  "%s[%p]::isKnownDevice found %s %s",
							       getName(), this, vendorName->getCStringNoCopy(), deviceName->getCStringNoCopy());

							isKnown = true;

							if (typeName)
								_xbDeviceType = typeName;
							else
								isKnown = false;
							_xbDeviceName = deviceName;
							_xbDeviceVendor = vendorName;
						}
					}
				}
			}
		}
	}

	return isKnown;
}

bool FPXboxHIDDriver::findGenericDevice (IOService* provider)
{
	// This attempts to identify a supported "generic" device by walking the device's property
	// tree and comparing it to a known standard (Microsoft)

	// Unfortunately, this doesn't always work because some devices have slightly different specs
	// than the Microsoft controllers
	IOUSBInterface* interface = 0;
	IOUSBDevice* device = 0;
	OSDictionary* deviceDataDict = 0;               // root dictionary for all device types
	OSDictionary* specificDeviceDict = 0;           // pad, IR, wheel, etc
	OSDictionary* genericPropertiesDict = 0;        // tree of properties that can identify device with unknown vendor/product id
	OSArray* genericInterfaceArray = 0;             // array of interfaces
	OSDictionary* genericInterfaceDict = 0;         // interface
	OSArray* genericEndpointArray = 0;              // array of endpoints
	OSDictionary* genericEndpointDict = 0;          // endpoint

	char const* typesList[] = { kDeviceTypePadKey, kDeviceTypeIRKey, NULL };

	bool foundGenericDevice = false;

	interface = OSDynamicCast(IOUSBInterface, provider);
	if (interface) {
		device = interface->GetDevice();
		if (device) {
			deviceDataDict = OSDynamicCast(OSDictionary, getProperty(kDeviceDataKey));
			if (deviceDataDict) {
				for (int i = 0; typesList[i] != NULL; i++) {
					specificDeviceDict = OSDynamicCast(OSDictionary, deviceDataDict->getObject(typesList[i]));
					if (specificDeviceDict) {
						genericPropertiesDict = OSDynamicCast(OSDictionary, specificDeviceDict->getObject(kDeviceGenericPropertiesKey));
						if (genericPropertiesDict) {
							genericInterfaceArray = OSDynamicCast(OSArray, genericPropertiesDict->getObject(kGenericInterfacesKey));
							if (genericInterfaceArray) {
								int numInterfaces = genericInterfaceArray->getCount();
								int numActualInterfaces = 0;
								bool allEndpointsMatched = true;
								IOUSBFindInterfaceRequest request;
								IOUSBInterface* foundInterface;

								request.bInterfaceClass = kIOUSBFindInterfaceDontCare;
								request.bInterfaceSubClass = kIOUSBFindInterfaceDontCare;
								request.bInterfaceProtocol = kIOUSBFindInterfaceDontCare;
								request.bAlternateSetting = kIOUSBFindInterfaceDontCare;

								foundInterface = device->FindNextInterface(NULL,&request);

								for (int j = 0; j < numInterfaces; j++) {
									if (foundInterface) {
										USBLog(6, "%s[%p]::findGenericDevice - checking interface: %d", getName(), this, j);

										foundInterface->retain();
										numActualInterfaces++;

										genericInterfaceDict = OSDynamicCast(OSDictionary, genericInterfaceArray->getObject(j));
										if (genericInterfaceDict) {
											genericEndpointArray = OSDynamicCast(OSArray, genericInterfaceDict->getObject(kGenericEndpointsKey));
											if (genericEndpointArray) {
												int numEndpoints = genericEndpointArray->getCount();
												int numActualEndpoints = 0;

												for (int k = 0; k < numEndpoints; k++) {
													bool endPointMatched = false;

													USBLog(6, "%s[%p]::findGenericDevice - checking endpoint: %d of %d",
													       getName(), this, k, foundInterface->GetNumEndpoints());

													// check that index is within bounds
													if (k < foundInterface->GetNumEndpoints()) {
														genericEndpointDict = OSDynamicCast(OSDictionary, genericEndpointArray->getObject(k));
														if (genericEndpointDict) {
															UInt8 transferType = 0, pollingInterval = 0;
															UInt16 maxPacketSize = 0;
															IOReturn kr = kIOReturnError;

															UInt8 genericAttributes = 0;
															UInt16 genericMaxPacketSize = 0;
															UInt8 genericPollingInterval = 0;
															UInt8 genericDirection = 0;
															UInt8 genericIndex = 0;

															OSNumber* number;

															// read dictionary attributes
															number = OSDynamicCast(OSNumber, genericEndpointDict->getObject(kGenericAttributesKey));
															if (number)
																genericAttributes = number->unsigned8BitValue();
															number = OSDynamicCast(OSNumber, genericEndpointDict->getObject(kGenericMaxPacketSizeKey));
															if (number)
																genericMaxPacketSize = number->unsigned16BitValue();
															number = OSDynamicCast(OSNumber, genericEndpointDict->getObject(kGenericPollingIntervalKey));
															if (number)
																genericPollingInterval = number->unsigned8BitValue();
															if (genericAttributes & 0x80)
																genericDirection = kUSBIn;
															else
																genericDirection = kUSBOut;
															genericIndex = genericAttributes & 0xF;

															// read device attributes
															kr = foundInterface->GetEndpointProperties(0, genericIndex, genericDirection, &transferType, &maxPacketSize, &pollingInterval);

															if (kIOReturnSuccess == kr) {
																numActualEndpoints++;

																// compare device's endpoint to dictionary entry's endpoint
																if (maxPacketSize == genericMaxPacketSize &&
																    pollingInterval == genericPollingInterval) {
																	endPointMatched = true;

																	USBLog(6, "%s[%p]::findGenericDevice - endpoint %d matched mps=%d int=%d",
																	       getName(), this, k, genericMaxPacketSize, genericPollingInterval);
																} else {
																	USBLog(6, "%s[%p]::findGenericDevice - endpoint %d rejected mps=%d int=%d",
																	       getName(), this, k, genericMaxPacketSize, genericPollingInterval);
																}
															}
														}
													}
													if (!endPointMatched)
														allEndpointsMatched = false;
												}

												if (numEndpoints != numActualEndpoints)
													allEndpointsMatched = false;
											}
										}
										IOUSBInterface* saveInterface = foundInterface; // save so we can call release() on it later

										request.bInterfaceClass = kIOUSBFindInterfaceDontCare;
										request.bInterfaceSubClass = kIOUSBFindInterfaceDontCare;
										request.bInterfaceProtocol = kIOUSBFindInterfaceDontCare;
										request.bAlternateSetting = kIOUSBFindInterfaceDontCare;

										foundInterface = device->FindNextInterface(foundInterface, &request);
										saveInterface->release();
									}
								}

								if (numInterfaces == numActualInterfaces &&
								    allEndpointsMatched) {

									foundGenericDevice = true;

									if (typesList[i])
										_xbDeviceType = OSString::withCString(typesList[i]);
									else
										foundGenericDevice = false;
									_xbDeviceVendor = OSDynamicCast(OSString, specificDeviceDict->getObject(kVendorKey));
									_xbDeviceName   = OSDynamicCast(OSString, specificDeviceDict->getObject(kNameKey));

									if (!_xbDeviceVendor || !_xbDeviceName)
										foundGenericDevice = false;
									if (foundGenericDevice) {
										USBLog(3, "%s[%p]::findGenericDevice - found %s %s", getName(), this,
										       _xbDeviceVendor->getCStringNoCopy(), _xbDeviceName->getCStringNoCopy());

										break; // we're done, return from for loop
									}
								}
							}
						}
					}
				}
			}
		}
	}

	return foundGenericDevice;
}


IOService* FPXboxHIDDriver::probe (IOService* provider, SInt32* score)
{
	if (this->isKnownDevice(provider)) {
		USBLog(3, "%s[%p]::probe found known device", getName(), this);

		// pump up our probe score, since we're probably the best driver
		*score += 10000;
	} else if (this->findGenericDevice(provider)) {
		// there might be a better driver, so don't increase the score
		USBLog(3, "%s[%p]::probe found generic device", getName(), this);
		*score += 1000;
	} else {
		// device is unknown *and* doesn't match known generic properties
		// previous code assumed it was a controller with possibility of
		// an app and/or kernel crash. this is unacceptable to me so
		// for now I am going to disallow such controllers, but will
		// come up with a way to present the controller in the UI and
		// give the user the option to enable it or not, with a warning!
		USBLog(3, "%s[%p]::probe didn't find supported device", getName(), this);

//		_xbDeviceType   = OSString::withCString("Pad");
//		_xbDeviceVendor = OSString::withCString("Unknown");
//		_xbDeviceName   = OSString::withCString("Generic Controller");
//
//		*score += 100;
	}

	return this;
}


IOReturn FPXboxHIDDriver::newUserClient (task_t owningTask, void* securityID, UInt32 type, OSDictionary* properties, IOUserClient** handler)
{
	// Have this set in Info.plist but it seems to only work if set here!?
	setProperty("IOUserClientClass", "FPXboxHIDUserClient");

	return IOHIDDevice::newUserClient(owningTask, securityID, type, properties, handler);
}


// ***********************************************************************************
// ************************ HID Driver Dispatch Table Functions *********************
// **********************************************************************************
IOReturn FPXboxHIDDriver::GetReport (UInt8 inReportType, UInt8 inReportID, UInt8* vInBuf, UInt32* vInSize)
{
	return kIOReturnSuccess;
}


IOReturn FPXboxHIDDriver::getReport (IOMemoryDescriptor* report, IOHIDReportType reportType, IOOptionBits options)
{
	//UInt8     reportID;
	IOReturn ret = kIOReturnSuccess;
	UInt8 usbReportType;
	//IOUSBDevRequestDesc requestPB;

	IncrementOutstandingIO();

	// Get the reportID from the lower 8 bits of options
	////
	//reportID = (UInt8) ( options & 0x000000ff);

	// And now save the report type
	//
	usbReportType = HIDMgr2USBReportType(reportType);

	USBLog(6, "%s[%p]::getReport (type=%d len=%u)", getName(), this,  usbReportType, (unsigned int) report->getLength());

	if (kUSBIn == usbReportType || kUSBNone == usbReportType) {
		// don't support this on remote controls - it can block indefinitely until a button is pressed
		if (!_xbDeviceType->isEqualTo(kDeviceTypeIRKey))
			ret = _interruptPipe->Read(report);
	} else {
		USBLog(3, "%s[%p]::getReport (type=%d len=%u): error operation unsupported", getName(), this,
		       usbReportType, (unsigned int)report->getLength());
		ret = kIOReturnError;
	}
	DecrementOutstandingIO();
	return ret;
}


// DEPRECATED (By What?!)
IOReturn FPXboxHIDDriver::SetReport (UInt8 outReportType, UInt8 outReportID, UInt8* vOutBuf, UInt32 vOutSize)
{
	return kIOReturnSuccess;
}


IOReturn FPXboxHIDDriver::setReport (IOMemoryDescriptor* report, IOHIDReportType reportType, IOOptionBits options)
{
	UInt8 reportID;
	IOReturn ret;
	UInt8 usbReportType;
	IOUSBDevRequestDesc requestPB;

	IncrementOutstandingIO();

	// Get the reportID from the lower 8 bits of options
	//
	reportID = (UInt8) ( options & 0x000000ff);

	// And now save the report type
	//
	usbReportType = HIDMgr2USBReportType(reportType);

	// If we have an interrupt out pipe, try to use it for output type of reports.
	if ( kHIDOutputReport == usbReportType && _interruptOutPipe ) {
#if ENABLE_HIDREPORT_LOGGING
		USBLog(3, "%s[%p]::setReport sending out interrupt out pipe buffer (%p,%d):", getName(), this, report, report->getLength() );
		LogMemReport(report);
#endif
		ret = _interruptOutPipe->Write(report);
		if (ret == kIOReturnSuccess) {
			DecrementOutstandingIO();
			return ret;
		} else {
			USBLog(3, "%s[%p]::setReport _interruptOutPipe->Write failed; err = 0x%x)", getName(), this, ret);
		}
	}
	// If we did not succeed using the interrupt out pipe, we may still be able to use the control pipe.
	// We'll let the family check whether it's a disjoint descriptor or not (but right now it doesn't do it)
	//
#if ENABLE_HIDREPORT_LOGGING
	USBLog(3, "%s[%p]::SetReport sending out control pipe:", getName(), this);
	LogMemReport( report);
#endif

	//--- Fill out device request form
	requestPB.bmRequestType = USBmakebmRequestType(kUSBOut, kUSBClass, kUSBInterface);
	requestPB.bRequest = kHIDRqSetReport;
	requestPB.wValue = (usbReportType << 8) | reportID;
	requestPB.wIndex = _interface->GetInterfaceNumber();
	requestPB.wLength = report->getLength();
	requestPB.pData = report;
	requestPB.wLenDone = 0;

	ret = _device->DeviceRequest(&requestPB);
	if (ret != kIOReturnSuccess)
		USBLog(3, "%s[%p]::setReport request failed; err = 0x%x)", getName(), this, ret);
	DecrementOutstandingIO();
	return ret;
}


// HIDGetHIDDescriptor is used to get a specific HID descriptor from a HID device
// (such as a report descriptor).
IOReturn FPXboxHIDDriver::GetHIDDescriptor (UInt8 inDescriptorType, UInt8 inDescriptorIndex, UInt8* vOutBuf, UInt32* vOutSize)
{
	//IOUSBDevRequest       requestPB;
	IOUSBHIDDescriptor* theHIDDesc;
	IOUSBHIDReportDesc* hidTypeSizePtr;         // For checking owned descriptors.
	UInt8* descPtr;
	UInt32 providedBufferSize;
	UInt16 descSize;
	UInt8 descType;
	UInt8 typeIndex;
	UInt8 numberOwnedDesc;
	IOReturn err = kIOReturnSuccess;
	Boolean foundIt;

	if (!vOutSize)
		return kIOReturnBadArgument;
	if (!_interface) {
		USBLog(2, "%s[%p]::GetHIDDescriptor - no _interface", getName(), this);
		return kIOReturnNotFound;
	}
	// From the interface descriptor, get the HID descriptor.
	// theHIDDesc = (IOUSBHIDDescriptor *)_interface->FindNextAssociatedDescriptor(NULL, kUSBHIDDesc);
	if (!_xbDeviceHIDReportDescriptor)
		return kIOReturnError;
	UInt16 descDataSize = _xbDeviceHIDReportDescriptor->getLength();

	IOUSBHIDDescriptor hidDescriptor =  {
		sizeof(IOUSBHIDDescriptor),   // descLen
		kUSBHIDDesc,                  // descType
		0x0111,                       // descVersNum (1.11)
		0,                            // hidCountryCode
		1,                            // hidNumDescriptors
		kUSBReportDesc,               // hidDescriptorType - Table 7.1.2
		static_cast<UInt8>(descDataSize & 0xFF),          // hidDescriptorLengthLo
		static_cast<UInt8>((descDataSize & 0xFF00) >> 8)  // hidDescriptorLengthHi
	};

	theHIDDesc = (IOUSBHIDDescriptor*)&hidDescriptor;

	if (theHIDDesc == NULL) {
		USBLog(2, "%s[%p]::GetHIDDescriptor - FindNextAssociatedDescriptor(NULL, kUSBHIDDesc) failed", getName(), this);
		return kIOReturnNotFound;
	}
	//USBLog (6, "HID Descriptor: descLen=%d\n\tdescType=0x%X\n\thidCountryCode=0x%X\n\thidNumDescriptors=%d\n\thidDescriptorType=0x%X\n\thidDescriptorLengthLo=%d\n\thidDescriptorLengthHi=%d\n", theHIDDesc->descLen, theHIDDesc->descType, theHIDDesc->hidCountryCode, theHIDDesc->hidNumDescriptors, theHIDDesc->hidDescriptorType, theHIDDesc->hidDescriptorLengthLo, theHIDDesc->hidDescriptorLengthHi);

	// Remember the provided buffer size
	providedBufferSize = *vOutSize;

	// Are we looking for just the main HID descriptor?
	if (inDescriptorType == kUSBHIDDesc || (inDescriptorType == 0 && inDescriptorIndex == 0)) {
		descSize = theHIDDesc->descLen;
		descPtr = (UInt8*)theHIDDesc;

		// No matter what, set the return size to the actual size of the data.
		*vOutSize = descSize;

		// If the provided size is 0, they are just asking for the size, so don't return an error.
		if (providedBufferSize == 0)
			err = kIOReturnSuccess;
		// Otherwise, if the buffer too small, return buffer too small error.
		else if (descSize > providedBufferSize)
			err = kIOReturnNoSpace;
		// Otherwise, if the buffer nil, return that error.
		else if (vOutBuf == NULL)
			err = kIOReturnBadArgument;
		// Otherwise, looks good, so copy the deiscriptor.
		else {
			//IOLog("  Copying HIDDesc w/ vOutBuf = 0x%x, descPtr = 0x%x, and descSize = 0x%x.\n", vOutBuf, descPtr, descSize);
			memcpy(vOutBuf, descPtr, descSize);
		}
	} else {
		// Looking for a particular type of descriptor.
		// The HID descriptor tells how many endpoint and report descriptors it contains.
		numberOwnedDesc = ((IOUSBHIDDescriptor*)theHIDDesc)->hidNumDescriptors;
		hidTypeSizePtr = (IOUSBHIDReportDesc*)&((IOUSBHIDDescriptor*)theHIDDesc)->hidDescriptorType;
		//USBLog (6, "     %d owned descriptors start at %08x\n", numberOwnedDesc, (unsigned int)hidTypeSizePtr);

		typeIndex = 0;
		foundIt = false;
		err = kIOReturnNotFound;
		for (UInt8 i = 0; i < numberOwnedDesc; i++) {
			descType = hidTypeSizePtr->hidDescriptorType;

			//USBLog (6, "descType=0x%X lengthhi=%d lengthlo=%d", descType,
			//    hidTypeSizePtr->hidDescriptorLengthHi, hidTypeSizePtr->hidDescriptorLengthLo);

			// Are we indexing for a specific type?
			if (inDescriptorType != 0) {
				if (inDescriptorType == descType) {
					if (inDescriptorIndex == typeIndex) {
						foundIt = true;
						//USBLog (6, "found it!", descType);
					} else {
						typeIndex++;
					}
				}
			}
			// Otherwise indexing across descriptors in general.
			// (If looking for any type, index must be 1 based or we'll get HID descriptor.)
			else if (inDescriptorIndex == i + 1) {
				//IOLog("  said we found it because inDescriptorIndex = 0x%x.\n", inDescriptorIndex);
				typeIndex = i;
				foundIt = true;
			}
			if (foundIt) {
				err = kIOReturnSuccess;     // Maybe
				//IOLog("     Found the requested owned descriptor, %d\n", i);
				descSize = (hidTypeSizePtr->hidDescriptorLengthHi << 8) + hidTypeSizePtr->hidDescriptorLengthLo;

				//USBLog (6, "descSize=%d", descSize);

				// Did we just want the size or the whole descriptor?
				// No matter what, set the return size to the actual size of the data.
				*vOutSize = descSize;   // OSX: Won't get back if we return an error!

				// If the provided size is 0, they are just asking for the size, so don't return an error.
				if (providedBufferSize == 0)
					err = kIOReturnSuccess;
				// Otherwise, if the buffer too small, return buffer too small error.
				else if (descSize > providedBufferSize)
					err = kIOReturnNoSpace;
				// Otherwise, if the buffer nil, return that error.
				else if (vOutBuf == NULL)
					err = kIOReturnBadArgument;
				// Otherwise, looks good, so copy the descriptor.
				else {
					if (!_device) {
						USBLog(2, "%s[%p]::GetHIDDescriptor - no _device", getName(), this);
						return kIOReturnNotFound;
					}
					if (descSize == _xbDeviceHIDReportDescriptor->getLength() && _xbDeviceHIDReportDescriptor->getBytesNoCopy()) {
						memcpy(vOutBuf, _xbDeviceHIDReportDescriptor->getBytesNoCopy(), descSize);
					} else {
						USBLog(2, "%s[%p]::GetHIDDescriptor - hid report desc wrong size", getName(), this);
						return kIOReturnError;
					}
				}
				break;  // out of for i loop.
			}
			// Make sure we add 3 bytes not 4 regardless of struct alignment.
			hidTypeSizePtr = (IOUSBHIDReportDesc*)(((UInt8*)hidTypeSizePtr) + 3);
		}
	}
	return err;
}


IOReturn FPXboxHIDDriver::newReportDescriptor (IOMemoryDescriptor** desc) const
{
	IOBufferMemoryDescriptor* bufferDesc = NULL;
	IOReturn ret = kIOReturnNoMemory;
	FPXboxHIDDriver* me = (FPXboxHIDDriver*) this;

	// Get the proper HID report descriptor size.
	UInt32 inOutSize = 0;
	ret = me->GetHIDDescriptor(kUSBReportDesc, 0, NULL, &inOutSize);

	if ( ret == kIOReturnSuccess &&  inOutSize != 0) {
		bufferDesc = IOBufferMemoryDescriptor::withCapacity(inOutSize, kIODirectionOutIn);
	}
	if (bufferDesc) {
		ret = me->GetHIDDescriptor(kUSBReportDesc, 0, (UInt8*)bufferDesc->getBytesNoCopy(), &inOutSize);

		if ( ret != kIOReturnSuccess ) {
			bufferDesc->release();
			bufferDesc = NULL;
		}
	}
	*desc = bufferDesc;

	return ret;
}


OSString* FPXboxHIDDriver::newTransportString (void) const
{
	return OSString::withCString("USB");
}


OSNumber* FPXboxHIDDriver::newPrimaryUsageNumber (void) const
{
	return OSNumber::withNumber(_deviceUsage, 32);
}


OSNumber* FPXboxHIDDriver::newPrimaryUsagePageNumber (void) const
{
	return OSNumber::withNumber(_deviceUsagePage, 32);
}


OSNumber* FPXboxHIDDriver::newVendorIDNumber (void) const
{
	UInt16 vendorID = 0;
	if (_device != NULL)
		vendorID = _device->GetVendorID();
	return OSNumber::withNumber(vendorID, 16);
}


OSNumber* FPXboxHIDDriver::newProductIDNumber (void) const
{
	UInt16 productID = 0;
	if (_device != NULL)
		productID = _device->GetProductID();
	return OSNumber::withNumber(productID, 16);
}


OSNumber* FPXboxHIDDriver::newVersionNumber(void) const
{
	UInt16 releaseNum = 0;
	if (_device != NULL)
		releaseNum = _device->GetDeviceRelease();
	return OSNumber::withNumber(releaseNum, 16);
}


UInt8 FPXboxHIDDriver::deviceSpeed(void) const
{
	UInt8 speed = 0;
	if (_device != NULL)
		speed = _device->GetSpeed();
	return speed;
}


UInt32 FPXboxHIDDriver::currentPower(void) const
{
	return _maxPower * 2.0;  // in units of 2 mA
}


UInt32 FPXboxHIDDriver::availablePower(void) const
{
	UInt32 power = 0;
	if (_device != NULL)
		power = _device->GetBusPowerAvailable() * 2.0;	// returns in units of 2 mA
	return power;
}


USBDeviceAddress FPXboxHIDDriver::deviceAddress(void) const
{
	return _device->GetAddress();
}


UInt32 FPXboxHIDDriver::getMaxReportSize()
{
	return _maxReportSize;
}


OSString* FPXboxHIDDriver::newManufacturerString (void) const
{
	char manufacturerString[256];
	UInt32 strSize;
	UInt8 index;
	IOReturn err;

	manufacturerString[0] = 0;

	index = _device->GetManufacturerStringIndex();
	strSize = sizeof(manufacturerString);

	err = GetIndexedString(index, (UInt8*)manufacturerString, &strSize);

	if ( err == kIOReturnSuccess )
		return OSString::withCString(manufacturerString);
	else if (_xbDeviceVendor)
		return OSString::withString(_xbDeviceVendor);
	else
		return NULL;
}


OSString* FPXboxHIDDriver::newProductString (void) const
{
	char productString[256];
	UInt32 strSize;
	UInt8 index;
	IOReturn err;

	productString[0] = 0;

	index = _device->GetProductStringIndex();
	strSize = sizeof(productString);

	err = GetIndexedString(index, (UInt8*)productString, &strSize);

	if ( err == kIOReturnSuccess )
		return OSString::withCString(productString);
	else if (_xbDeviceName)
		return OSString::withString(_xbDeviceName);
	else
		return NULL;
}


OSString* FPXboxHIDDriver::newSerialNumberString (void) const
{
	char serialNumberString[256];
	UInt32 strSize;
	UInt8 index;
	IOReturn err;

	serialNumberString[0] = 0;

	index = _device->GetSerialNumberStringIndex();
	strSize = sizeof(serialNumberString);

	err = GetIndexedString(index, (UInt8*)serialNumberString, &strSize);

	if ( err == kIOReturnSuccess )
		return OSString::withCString(serialNumberString);
	else
		return NULL;
}


OSNumber* FPXboxHIDDriver::newLocationIDNumber (void) const
{
	OSNumber* newLocationID = NULL;

	if (_interface != NULL) {
		OSNumber* locationID = (OSNumber*)_interface->getProperty(kUSBDevicePropertyLocationID);
		if ( locationID )
			// I should be able to just duplicate locationID, but no OSObject::clone() or such.
			newLocationID = OSNumber::withNumber(locationID->unsigned32BitValue(), 32);
	}
	return newLocationID;
}


IOReturn FPXboxHIDDriver::GetIndexedString (UInt8 index, UInt8* vOutBuf, UInt32* vOutSize, UInt16 lang) const
{
	char strBuf[256];
	UInt16 strLen = sizeof(strBuf) - 1;     // GetStringDescriptor MaxLen = 255
	UInt32 outSize = *vOutSize;
	IOReturn err;

	// Valid string index?
	if (index == 0) {
		return kIOReturnBadArgument;
	}

	// Valid language?
	if (lang == 0) {
		lang = 0x409;   // Default is US English.
	}

	err = _device->GetStringDescriptor((UInt8)index, strBuf, strLen, (UInt16)lang);
	if (err != kIOReturnSuccess)
		return err;

	// We return the length of the string plus the null terminator,
	// but don't say a null string is 1 byte long.
	strLen = (strBuf[0] == 0) ? 0 : strlen(strBuf) + 1;

	if (outSize == 0) {
		*vOutSize = strLen;
		return kIOReturnSuccess;
	} else if (outSize < strLen) {
		return kIOReturnMessageTooLarge;
	}
	strlcpy((char*)vOutBuf, strBuf, sizeof(vOutBuf));
	*vOutSize = strLen;
	return kIOReturnSuccess;
}


OSString* FPXboxHIDDriver::newIndexedString (UInt8 index) const
{
	char string[256];
	UInt32 strSize;
	IOReturn err = kIOReturnSuccess;

	string[0] = 0;
	strSize = sizeof(string);

	err = GetIndexedString(index, (UInt8*)string, &strSize );

	if ( err == kIOReturnSuccess )
		return OSString::withCString(string);
	else
		return NULL;
}


IOReturn FPXboxHIDDriver::message (UInt32 type, IOService* provider, void* argument)
{
	IOReturn err = kIOReturnSuccess;

	err = super::message (type, provider, argument);

	switch ( type ) {
	case kIOMessageServiceIsTerminated:
		USBLog(5, "%s[%p]: service is terminated - ignoring", getName(), this);
		break;

	case kIOUSBMessagePortHasBeenReset:
		USBLog(3, "%s[%p]: received kIOUSBMessagePortHasBeenReset", getName(), this);
		_retryCount = kHIDDriverRetryCount;
		_deviceIsDead = FALSE;
		_deviceHasBeenDisconnected = FALSE;

		IncrementOutstandingIO();
		err = _interruptPipe->Read(_buffer, &_completion);
		if (err != kIOReturnSuccess) {
			DecrementOutstandingIO();
			USBLog(3, "%s[%p]::message - err (%x) in interrupt read", getName(), this, err);
			// _interface->close(this); will be done in didTerminate
		}
		break;

	default:
		break;
	}

	return kIOReturnSuccess;
}


bool FPXboxHIDDriver::willTerminate (IOService* provider, IOOptionBits options)
{
	// this method is intended to be used to stop any pending I/O and to make sure that
	// we have begun getting our callbacks in order. by the time we get here, the
	// isInactive flag is set, so we really are marked as being done. we will do in here
	// what we used to do in the message method (this happens first)
	USBLog(3, "%s[%p]::willTerminate isInactive = %d", getName(), this, isInactive());
	if (_interruptPipe)
		_interruptPipe->Abort();
	return super::willTerminate(provider, options);
}


bool FPXboxHIDDriver::didTerminate (IOService* provider, IOOptionBits options, bool* defer)
{
	// this method comes at the end of the termination sequence. Hopefully, all of our outstanding IO is complete
	// in which case we can just close our provider and IOKit will take care of the rest. Otherwise, we need to
	// hold on to the device and IOKit will terminate us when we close it later
	USBLog(3, "%s[%p]::didTerminate isInactive = %d, outstandingIO = %u", getName(), this, isInactive(), (unsigned int) _outstandingIO);
	if (!_outstandingIO)
		_interface->close(this);
	else
		_needToClose = true;
	return super::didTerminate(provider, options, defer);
}


bool FPXboxHIDDriver::start (IOService* provider)
{
	IOReturn err = kIOReturnSuccess;
	IOWorkLoop* wl = NULL;

	USBLog(7, "%s[%p]::start", getName(), this);
	IncrementOutstandingIO();           // make sure that once we open we don't close until start is open
	bool ret = super::start(provider);
	if (!ret) {
		USBLog(1, "%s[%p]::start - failed to start provider", getName(), this);
	}
	if (ret)
		do {
			// OK - at this point IOHIDDevice has successfully started, and now we need to start out interrupt pipe
			// read. we have not initialized a bunch of this stuff yet, because we needed to wait to see if
			// IOHIDDevice::start succeeded or not
			IOUSBFindEndpointRequest request;

			USBLog(7, "%s[%p]::start - getting _gate", getName(), this);
			_gate = IOCommandGate::commandGate(this);

			if(!_gate) {
				USBError(1, "%s[%p]::start - unable to create command gate", getName(), this);
				break;
			}
			wl = getWorkLoop();
			if (!wl) {
				USBError(1, "%s[%p]::start - unable to find my workloop", getName(), this);
				break;
			}
			if (wl->addEventSource(_gate) != kIOReturnSuccess) {
				USBError(1, "%s[%p]::start - unable to add gate to work loop", getName(), this);
				break;
			}
			// Errata for ALL Saitek devices.  Do a SET_IDLE 0 call
			if ( (_device->GetVendorID()) == 0x06a3 )
				SetIdleMillisecs(0);
			request.type = kUSBInterrupt;
			request.direction = kUSBOut;
			_interruptOutPipe = _interface->FindNextPipe(NULL, &request);

			request.type = kUSBInterrupt;
			request.direction = kUSBIn;
			_interruptPipe = _interface->FindNextPipe(NULL, &request);

			if(!_interruptPipe) {
				USBError(1, "%s[%p]::start - unable to get interrupt pipe", getName(), this);
				break;
			}
			_maxReportSize = getMaxReportSize();
			if (_maxReportSize) {
				_buffer = IOBufferMemoryDescriptor::withCapacity(_maxReportSize, kIODirectionIn);
				if ( !_buffer ) {
					USBError(1, "%s[%p]::start - unable to get create buffer", getName(), this);
					break;
				}
			}
			// allocate a thread_call structure
			_deviceDeadCheckThread = thread_call_allocate((thread_call_func_t)CheckForDeadDeviceEntry, (thread_call_param_t)this);
			_clearFeatureEndpointHaltThread = thread_call_allocate((thread_call_func_t)ClearFeatureEndpointHaltEntry, (thread_call_param_t)this);

			if ( !_deviceDeadCheckThread || !_clearFeatureEndpointHaltThread ) {
				USBError(1, "[%s]%p: could not allocate all thread functions", getName(), this);
				break;
			}
			err = StartFinalProcessing();
			if (err != kIOReturnSuccess) {
				USBError(1, "%s[%p]::start - err (%x) in StartFinalProcessing", getName(), this, err);
				break;
			}
			USBError(1, "%s[%p]::start -  USB HID Device @ %d (0x%lx)", getName(), this, _device->GetAddress(), strtoul(_device->getLocation(), (char**)NULL, 16));

			DecrementOutstandingIO();       // release the hold we put on at the beginning

			return true;

		} while (false);
	USBError(1, "%s[%p]::start - aborting startup", getName(), this);
	if (_gate) {
		if (wl)
			wl->removeEventSource(_gate);
		_gate->release();
		_gate = NULL;
	}
	if (_deviceDeadCheckThread)
		thread_call_free(_deviceDeadCheckThread);
	if (_clearFeatureEndpointHaltThread)
		thread_call_free(_clearFeatureEndpointHaltThread);
	if (_interface)
		_interface->close(this);
	DecrementOutstandingIO();       // release the hold we put on at the beginning
	return false;
}


// InterruptReadHandlerEntry is called to process any data coming in through our interrupt pipe
void FPXboxHIDDriver::InterruptReadHandlerEntry (OSObject* target, void* param, IOReturn status, UInt32 bufferSizeRemaining)
{
	FPXboxHIDDriver*   me = OSDynamicCast(FPXboxHIDDriver, target);

	if (!me)
		return;
	me->InterruptReadHandler(status, bufferSizeRemaining);
	me->DecrementOutstandingIO();
}


void FPXboxHIDDriver::InterruptReadHandler (IOReturn status, UInt32 bufferSizeRemaining)
{
	bool queueAnother = true;
	bool timeToGoAway = false;
	IOReturn err = kIOReturnSuccess;

	switch (status) {
	case kIOReturnOverrun:
		USBLog(3, "%s[%p]::InterruptReadHandler kIOReturnOverrun error", getName(), this);
		// This is an interesting error, as we have the data that we wanted and more...  We will use this
		// data but first we need to clear the stall and reset the data toggle on the device.  We will not
		// requeue another read because our _clearFeatureEndpointHaltThread will requeue it.  We then just
		// fall through to the kIOReturnSuccess case.
		// 01-18-02 JRH If we are inactive, then ignore this
		if (!isInactive()) {
			//
			// First, clear the halted bit in the controller
			//
			_interruptPipe->ClearStall();

			// And call the device to reset the endpoint as well
			//
			IncrementOutstandingIO();
			thread_call_enter(_clearFeatureEndpointHaltThread);
		}
		queueAnother = false;
		timeToGoAway = false;

	// Fall through to process the data.

	case kIOReturnSuccess:
		// Reset the retry count, since we had a successful read
		//
		_retryCount = kHIDDriverRetryCount;

		// Handle the data
		//
#if ENABLE_HIDREPORT_LOGGING
		USBLog(6, "%s[%p]::InterruptReadHandler report came in:", getName(), this);
		LogMemReport(_buffer);
#endif
		if (manipulateReport(_buffer))
			handleReport(_buffer);
		if (_xbDeviceType->isEqualTo(kDeviceTypeIRKey))
			if (_xbTimerEventSource) {
				_xbTimerEventSource->cancelTimeout();
				_xbTimerEventSource->setTimeoutMS(_xbTimedEventsInterval);
			}
		if (isInactive())
			queueAnother = false;
		break;

	case kIOReturnNotResponding:
		USBLog(3, "%s[%p]::InterruptReadHandler kIOReturnNotResponding error", getName(), this);
		// If our device has been disconnected or we're already processing a
		// terminate message, just go ahead and close the device (i.e. don't
		// queue another read.  Otherwise, go check to see if the device is
		// around or not.
		//
		if ( _deviceHasBeenDisconnected || isInactive() ) {
			queueAnother = false;
			timeToGoAway = true;
		} else {
			USBLog(3, "%s[%p]::InterruptReadHandler Checking to see if HID device is still connected", getName(), this);
			IncrementOutstandingIO();
			thread_call_enter(_deviceDeadCheckThread);

			// Before requeueing, we need to clear the stall
			//
			_interruptPipe->ClearStall();
		}
		break;

	case kIOReturnAborted:
		// This generally means that we are done, because we were unplugged, but not always
		//
		if (isInactive() || _deviceIsDead ) {
			USBLog(3, "%s[%p]::InterruptReadHandler error kIOReturnAborted (expected)", getName(), this);
			queueAnother = false;
			timeToGoAway = true;
		} else {
			USBLog(3, "%s[%p]::InterruptReadHandler error kIOReturnAborted (try again)", getName(), this);
		}
		break;

	case kIOReturnUnderrun:
	case kIOUSBPipeStalled:
	case kIOUSBLinkErr:
	case kIOUSBNotSent2Err:
	case kIOUSBNotSent1Err:
	case kIOUSBBufferUnderrunErr:
	case kIOUSBBufferOverrunErr:
	case kIOUSBWrongPIDErr:
	case kIOUSBPIDCheckErr:
	case kIOUSBDataToggleErr:
	case kIOUSBBitstufErr:
	case kIOUSBCRCErr:
		// These errors will halt the endpoint, so before we requeue the interrupt read, we have
		// to clear the stall at the controller and at the device.  We will not requeue the read
		// until after we clear the ENDPOINT_HALT feature.  We need to do a callout thread because
		// we are executing inside the gate here and we cannot issue a synchronous request.
		USBLog(3, "%s[%p]::InterruptReadHandler OHCI error (0x%x) reading interrupt pipe", getName(), this, status);
		// 01-18-02 JRH If we are inactive, then ignore this
		if (!isInactive()) {
			// First, clear the halted bit in the controller
			//
			_interruptPipe->ClearStall();

			// And call the device to reset the endpoint as well
			//
			IncrementOutstandingIO();
			thread_call_enter(_clearFeatureEndpointHaltThread);
		}
		// We don't want to requeue the read here, AND we don't want to indicate that we are done
		//
		queueAnother = false;
		break;
	default:
		// We should handle other errors more intelligently, but
		// for now just return and assume the error is recoverable.
		USBLog(3, "%s[%p]::InterruptReadHandler error (0x%x) reading interrupt pipe", getName(), this, status);
		if (isInactive())
			queueAnother = false;
		break;
	}

	if ( queueAnother ) {
		// Queue up another one before we leave.
		//
		IncrementOutstandingIO();
		err = _interruptPipe->Read(_buffer, &_completion);
		if ( err != kIOReturnSuccess) {
			// This is bad.  We probably shouldn't continue on from here.
			USBError(1, "%s[%p]::InterruptReadHandler immediate error 0x%x queueing read\n", getName(), this, err);
			DecrementOutstandingIO();
			timeToGoAway = true;
		}
	}
}


// CheckForDeadDevice is called when we get a kIODeviceNotResponding error in our interrupt pipe.
// This can mean that (1) the device was unplugged, or (2) we lost contact with our hub.
// In case (1), we just need to close the driver and go.  In case (2), we need to ask if we are still attached.
// If we are, then we update our retry count.  Once our retry count (3 from the 9 sources) are exhausted, then
// we issue a DeviceReset to our provider, with the understanding that we will go away (as an interface).
void FPXboxHIDDriver::CheckForDeadDeviceEntry (OSObject* target)
{
	FPXboxHIDDriver*   me = OSDynamicCast(FPXboxHIDDriver, target);

	if (!me)
		return;
	me->CheckForDeadDevice();
	me->DecrementOutstandingIO();
}


void FPXboxHIDDriver::CheckForDeadDevice (void)
{
	IOReturn err = kIOReturnSuccess;

	// Are we still connected?  Don't check again if we're already
	// checking
	//
	if ( _interface && _device && !_deviceDeadThreadActive) {
		_deviceDeadThreadActive = TRUE;

		err = _device->message(kIOUSBMessageHubIsDeviceConnected, NULL, 0);

		if ( kIOReturnSuccess == err ) {
			// Looks like the device is still plugged in.  Have we reached our retry count limit?
			//
			if ( --_retryCount == 0 ) {
				_deviceIsDead = TRUE;
				USBLog(3, "%s[%p]: Detected an kIONotResponding error but still connected.  Resetting port", getName(), this);

				if (_interruptPipe)
					_interruptPipe->Abort();  // This will end up closing the interface as well.

				// OK, let 'er rip.  Let's do the reset thing
				//
				_device->ResetDevice();
			}
		} else {
			// Device is not connected -- our device has gone away.  The message kIOServiceIsTerminated
			// will take care of shutting everything down.
			//
			_deviceHasBeenDisconnected = TRUE;
			USBLog(5, "%s[%p]: CheckForDeadDevice: device has been unplugged", getName(), this);
		}
		_deviceDeadThreadActive = FALSE;
	}
}


// ClearFeatureEndpointHaltEntry is called when we get an OHCI error from our interrupt read
// (except for kIOReturnNotResponding which will check for a dead device). In these cases we need
// to clear the halted bit in the controller AND we need to reset the data toggle on the device.
void FPXboxHIDDriver::ClearFeatureEndpointHaltEntry (OSObject* target)
{
	FPXboxHIDDriver*   me = OSDynamicCast(FPXboxHIDDriver, target);

	if (!me)
		return;
	me->ClearFeatureEndpointHalt();
	me->DecrementOutstandingIO();
}


void FPXboxHIDDriver::ClearFeatureEndpointHalt (void)
{
	IOReturn status;
	IOUSBDevRequest request;

	// Clear out the structure for the request
	//
	bzero( &request, sizeof(IOUSBDevRequest));

	// Build the USB command to clear the ENDPOINT_HALT feature for our interrupt endpoint
	//
	request.bmRequestType   = USBmakebmRequestType(kUSBNone, kUSBStandard, kUSBEndpoint);
	request.bRequest        = kUSBRqClearFeature;
	request.wValue      = 0;    // Zero is ENDPOINT_HALT
	request.wIndex      = _interruptPipe->GetEndpointNumber() | 0x80;  // bit 7 sets the direction of the endpoint to IN
	request.wLength     = 0;
	request.pData       = NULL;

	// Send the command over the control endpoint
	//
	status = _device->DeviceRequest(&request, 5000, 0);

	if ( status ) {
		USBLog(3, "%s[%p]::ClearFeatureEndpointHalt -  DeviceRequest returned: 0x%x", getName(), this, status);
	}
	// Now that we've sent the ENDPOINT_HALT clear feature, we need to requeue the interrupt read.  Note
	// that we are doing this even if we get an error from the DeviceRequest.
	//
	IncrementOutstandingIO();
	status = _interruptPipe->Read(_buffer, &_completion);
	if ( status != kIOReturnSuccess) {
		// This is bad.  We probably shouldn't continue on from here.
		USBLog(3, "%s[%p]::ClearFeatureEndpointHalt -  immediate error %d queueing read", getName(), this, status);
		DecrementOutstandingIO();
		// _interface->close(this); this will be done in didTerminate
	}
}


IOReturn FPXboxHIDDriver::ChangeOutstandingIO (OSObject* target, void* param1, void* param2, void* param3, void* param4)
{
	FPXboxHIDDriver* me = OSDynamicCast(FPXboxHIDDriver, target);
	UInt64 direction = (UInt64)param1;

	if (!me) {
		USBLog(1, "FPXboxHIDDriver::ChangeOutstandingIO - invalid target");
		return kIOReturnSuccess;
	}
	switch (direction) {
	case 1:
		me->_outstandingIO++;
		break;

	case -1:
		if (!--me->_outstandingIO && me->_needToClose) {
			USBLog(3, "%s[%p]::ChangeOutstandingIO isInactive = %d, outstandingIO = %u - closing device",
			       me->getName(), me, me->isInactive(), (unsigned int) me->_outstandingIO);
			me->_interface->close(me);
		}
		break;

	default:
		USBLog(1, "%s[%p]::ChangeOutstandingIO - invalid direction", me->getName(), me);
	}
	return kIOReturnSuccess;
}


void FPXboxHIDDriver::DecrementOutstandingIO (void)
{
	if (!_gate) {
		if (!--_outstandingIO && _needToClose) {
			USBLog(3, "%s[%p]::DecrementOutstandingIO isInactive = %d, outstandingIO = %u - closing device",
			       getName(), this, isInactive(), (unsigned int) _outstandingIO);
			_interface->close(this);
		}
		return;
	}
	_gate->runAction(ChangeOutstandingIO, (void*)-1);
}


void FPXboxHIDDriver::IncrementOutstandingIO (void)
{
	if (!_gate) {
		_outstandingIO++;
		return;
	}
	_gate->runAction(ChangeOutstandingIO, (void*)1);
}


// This method may have a confusing name. This is not talking about Final Processing of the driver (as in
// the driver is going away or something like that. It is talking about FinalProcessing of the start method.
// It is called as the very last thing in the start method, and by default it issues a read on the interrupt pipe.
IOReturn FPXboxHIDDriver::StartFinalProcessing (void)
{
	IOReturn err = kIOReturnSuccess;

	_completion.target = (void*)this;
	_completion.action = (IOUSBCompletionAction) &FPXboxHIDDriver::InterruptReadHandlerEntry;
	_completion.parameter = (void*)0;

	IncrementOutstandingIO();
	err = _interruptPipe->Read(_buffer, &_completion);
	if (err != kIOReturnSuccess) {
		DecrementOutstandingIO();
		USBError(1, "%s[%p]::StartFinalProcessing - err (%x) in interrupt read, retain count %d after release",
		         getName(), this, err, getRetainCount());
	}
	return err;
}


IOReturn FPXboxHIDDriver::SetIdleMillisecs (UInt16 msecs)
{
	IOReturn err = kIOReturnSuccess;
	IOUSBDevRequest request;

	request.bmRequestType = USBmakebmRequestType(kUSBOut, kUSBClass, kUSBInterface);
	request.bRequest = kHIDRqSetIdle;  //See USBSpec.h
	request.wValue = (msecs/4) << 8;
	request.wIndex = _interface->GetInterfaceNumber();
	request.wLength = 0;
	request.pData = NULL;

	err = _device->DeviceRequest(&request, 5000, 0);
	if (err != kIOReturnSuccess) {
		USBLog(3, "%s[%p]: FPXboxHIDDriver::SetIdleMillisecs returned error 0x%x",getName(), this, err);
	}
	return err;

}


#if ENABLE_HIDREPORT_LOGGING
void FPXboxHIDDriver::LogMemReport (IOMemoryDescriptor* reportBuffer)
{
	IOByteCount reportSize;
	char outBuffer[1024];
	char in[1024];
	char* out;
	char inChar;

	out = (char*)&outBuffer;
	reportSize = reportBuffer->getLength();
	reportBuffer->readBytes(0, in, reportSize );
	if (reportSize > 256) reportSize = 256;
	for (unsigned int i = 0; i < reportSize; i++) {
		inChar = in[i];
		*out++ = ' ';
		*out++ = GetHexChar(inChar >> 4);
		*out++ = GetHexChar(inChar & 0x0F);
	}

	*out = 0;

	USBLog(6, outBuffer);
}


char FPXboxHIDDriver::GetHexChar (char hexChar)
{
	char hexChars[] = {'0','1','2','3','4','5','6','7','8','9','A','B','C','D','E','F'};
	return hexChars[0x0F & hexChar];
}
#endif


OSMetaClassDefineReservedUnused(FPXboxHIDDriver,  0);
OSMetaClassDefineReservedUnused(FPXboxHIDDriver,  1);
OSMetaClassDefineReservedUnused(FPXboxHIDDriver,  2);
OSMetaClassDefineReservedUnused(FPXboxHIDDriver,  3);
OSMetaClassDefineReservedUnused(FPXboxHIDDriver,  4);
OSMetaClassDefineReservedUnused(FPXboxHIDDriver,  5);
OSMetaClassDefineReservedUnused(FPXboxHIDDriver,  6);
OSMetaClassDefineReservedUnused(FPXboxHIDDriver,  7);
OSMetaClassDefineReservedUnused(FPXboxHIDDriver,  8);
OSMetaClassDefineReservedUnused(FPXboxHIDDriver,  9);
OSMetaClassDefineReservedUnused(FPXboxHIDDriver, 10);
OSMetaClassDefineReservedUnused(FPXboxHIDDriver, 11);
OSMetaClassDefineReservedUnused(FPXboxHIDDriver, 12);
OSMetaClassDefineReservedUnused(FPXboxHIDDriver, 13);
OSMetaClassDefineReservedUnused(FPXboxHIDDriver, 14);
OSMetaClassDefineReservedUnused(FPXboxHIDDriver, 15);
OSMetaClassDefineReservedUnused(FPXboxHIDDriver, 16);
OSMetaClassDefineReservedUnused(FPXboxHIDDriver, 17);
OSMetaClassDefineReservedUnused(FPXboxHIDDriver, 18);
OSMetaClassDefineReservedUnused(FPXboxHIDDriver, 19);

// =========================================================================================================================
// This is a basic HID driver to provide support for USB Class 3 (HID) devices, heavily modified to support Xbox Controllers
//
// How to Obtain this Code:
// Point your browser at http://xboxhid.fizzypopstudios.com/
//
// Modifications to Original Apple Code:
// -------------------------------------
// 05-16-2003 (XHD Version 1.0 Changes):
// • Added manipulateReport() method to allow subclasses to modify the HID report before it's passed to handleReport()
// • Changed getReport() to read from interface 0, endpoint 0 (input) rather than use a HID control request.
// • Changed GetHIDDescriptor() to read a hardcoded report rather than use a HID control request.
// • Changed GetIndexedString() to read from a hardcoded string table instead of using the USB string request
// • Changed newManufacturerString(), newProductNameString(), newSerialNumbeString() to use hardcoded index.
// • Added hardcoded tables for aformentioned changes.
//
// 05-22-2003 (XHD Version 1.1 Changes):
// • Initial remote control support
//	• Added IOTimerEventSource to send remote button-up events
//	• Added generateTimedEvent() method which fires at _xbTimedEventsInterval millisecond intervals (currently 80ms)
//	• Added button lookup and structure packing to generate remote's report in manipulateReport()
//
// • Generic device detection via property list (don't need the product id/vendor id for everything)
//	 • Added isKnownDevice() method to check vendor/product id's
//	 • Added findGenericDevice() method to handle detection of devices with unknown product ids
//	 • Added probe(), which calls the 2 previous methods (utilized by IOKit's driver matching protocol)
//
// • Initial options support
//	 • Each device type can contain a dictionary for setting options
//	 • This is the first step towards a user-configurable driver
//
// • New defaults
//	 • for compatibility, the analog buttons are clamped to 0-1 (to do 0-255 you'd have to edit the hid report descriptor)
//
// • Removed hardcoded data
//	 • tables - now stored in property list (use the "hex" tool to format data)
//	 • reports - now stored in property list
//
// • Removed GetIndexedString() hack, replaced with property list strings if needed
// • Printing out more error messages
//
// 06-16-2003 (XHD Version 1.2 ßeta Changes):
// This is a major overhaul that allows an external program to modify the driver's settings. The way this works is that
// when the driver loads, it uses a default set of settings. A daemon application can detect when a driver loads and call
// the IORegistryEntrySetCFProperties() to modify the driver settings.
// Clients also can call IORegistryEntryCreateCFProperties() to see what the current settings are.
//
// • Moved property list keys into a FPXboxHIDDriverKeys.h
// • Removed device type enumeration - use string instead
// • Mew pad options: InvertXAxis. InvertRyAxis, InvertRxAxis, ClampButtons, ClampLeftTrigger, ClampRightTrigger,
//					  LeftTriggerThreshold, RightTriggerThreshold;
// • Mew methods to handle prefs setting from user space: setProperties, setDefaultOptions, setupDevice;
//
// 10-13-04 (XHD Version 1.3 Changes):
// In this version I'm trying to further improve compatibility with 3rd-party controllers. It turns out that the generic
// identification routine (findGenericDevice) is not generic enough. Probably the only constant between 3rd-party
// controllers is that they will always have the same interface class/subclass (88/66) and two interrupt endpoints
// (one for output/joysticks, one for input/rumble motors).
//
// Now if findKnownDevice() and findGenericDevice() fail we assume a gamepad is connected.
// This could be bad if we assume wrong; at worst what happens is we read a report that is either to small or too large.
// However, it seems to me that the majority of Xbox devices conform to the original controller's report descriptor
// (for the obvious purpose of being compatible with all xbox games).
//
// 12/18/2012 (XHD v2.0.0 Changes by macman860)
// • Changed to support Standard 32/64-bit architecture
// • Compiled with Mac OS X 10.6 SDK
//
// 07/15/2015 (Xbox HID v1.0.0 Changes by Paige DePol)
// • TODO: ADD CHANGES!
// =========================================================================================================================
