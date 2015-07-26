//
// FPXboxHIDUserClient.cpp
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


#include "FPXboxHIDUserClient.h"
#include "FPXboxHIDDriverKeys.h"

#define DEBUG_LEVEL 0 // 0=disable all logging, 7=full logging
#include <IOKit/usb/IOUSBLog.h>

#define super IOUserClient

OSDefineMetaClassAndStructors(FPXboxHIDUserClient, IOUserClient)


IOReturn FPXboxHIDUserClient::sGetRawReport (OSObject* target, void* reference, IOExternalMethodArguments* args)
{
	XBPadReport* source;
	IOReturn ret = ((FPXboxHIDUserClient*)target)->getRawReport(&source);
	if (ret != kIOReturnSuccess)
		return ret;
	XBPadReport* dest = (XBPadReport*)args->structureOutput;

	*dest = *source;
	args->structureOutputSize = sizeof(XBPadReport);

	return kIOReturnSuccess;
}


IOReturn FPXboxHIDUserClient::getRawReport (XBPadReport** report)
{
	if (_driver == NULL || isInactive()) {
		// Return an error if we don't have a provider. This could happen if the user process
		// called getRawReport without calling IOServiceOpen first. Or, the user client could be
		// in the process of being terminated and is thus inactive.
		return kIOReturnNotAttached;
	}
	// set 'report' pointer to last raw report
	// all this is taking place in kernel-space, the user/kernel boundary
	// will be crossed in 'sGetRawReport' via the 'args' structureOutput
	*report = _driver->lastRawReport();

	return kIOReturnSuccess;
}


IOReturn FPXboxHIDUserClient::sLoadDefaultLayout (OSObject* target, void* reference, IOExternalMethodArguments* args)
{
	return ((FPXboxHIDUserClient*)target)->loadDefaultLayout();
}


IOReturn FPXboxHIDUserClient::loadDefaultLayout (void)
{
	if (_driver == NULL || isInactive()) {
		// Return an error if we don't have a provider. This could happen if the user process
		// called getRawReport without calling IOServiceOpen first. Or, the user client could be
		// in the process of being terminated and is thus inactive.
		return kIOReturnNotAttached;
	}

	// set 'report' pointer to last raw report
	// all this is taking place in kernel-space, the user/kernel boundary
	// will be crossed in 'sGetRawReport' via the 'args' structureOutput
	_driver->setDefaultOptions();

	return kIOReturnSuccess;
}


IOReturn FPXboxHIDUserClient::sGetSpeed (OSObject* target, void* reference, IOExternalMethodArguments* args)
{
	uint64_t* speed = args->scalarOutput;
	IOReturn ret = ((FPXboxHIDUserClient*)target)->getSpeed(speed);
	if (ret != kIOReturnSuccess)
		return ret;
	args->scalarOutputCount = 1;

	return kIOReturnSuccess;
}


IOReturn FPXboxHIDUserClient::getSpeed (uint64_t* speed)
{
	if (_driver == NULL || isInactive()) {
		// Return an error if we don't have a provider. This could happen if the user process
		// called getRawReport without calling IOServiceOpen first. Or, the user client could be
		// in the process of being terminated and is thus inactive.
		return kIOReturnNotAttached;
	}
	// set 'report' pointer to last raw report
	// all this is taking place in kernel-space, the user/kernel boundary
	// will be crossed in 'sGetRawReport' via the 'args' structureOutput
	*speed = _driver->deviceSpeed();

	return kIOReturnSuccess;
}


IOReturn FPXboxHIDUserClient::sGetPower (OSObject* target, void* reference, IOExternalMethodArguments* args)
{
	uint64_t* power = args->scalarOutput;
	IOReturn ret = ((FPXboxHIDUserClient*)target)->getPower(power);
	if (ret != kIOReturnSuccess)
		return ret;
	args->scalarOutputCount = 2;

	return kIOReturnSuccess;
}


IOReturn FPXboxHIDUserClient::getPower (uint64_t* power)
{
	if (_driver == NULL || isInactive()) {
		// Return an error if we don't have a provider. This could happen if the user process
		// called getRawReport without calling IOServiceOpen first. Or, the user client could be
		// in the process of being terminated and is thus inactive.
		return kIOReturnNotAttached;
	}
	// set 'report' pointer to last raw report
	// all this is taking place in kernel-space, the user/kernel boundary
	// will be crossed in 'sGetRawReport' via the 'args' structureOutput
	power[0] = _driver->currentPower();
	power[1] = _driver->availablePower();

	return kIOReturnSuccess;
}


bool FPXboxHIDUserClient::initWithTask (task_t owningTask, void* securityToken, UInt32 type, OSDictionary* properties)
{
	if (!owningTask || !super::initWithTask(owningTask, securityToken, type, properties))
		return false;
	_task = owningTask;
	task_reference(_task);

	_driver = NULL;

	return true;
}


bool FPXboxHIDUserClient::start (IOService* provider)
{
	if (!_task || !super::start(provider))
		return false;
	_driver = OSDynamicCast(FPXboxHIDDriver, provider);
	if (!attach(_driver))
		return false;
	return true;
}



IOReturn FPXboxHIDUserClient::clientClose (void)
{
	if (_task) {
		task_deallocate(_task);
		_task = 0;
	}
	if (_driver) {
		detach(_driver);
		_driver = 0;
	}
	terminate();
	return kIOReturnSuccess;
}


IOReturn FPXboxHIDUserClient::externalMethod (uint32_t selector, IOExternalMethodArguments* args,
                                              IOExternalMethodDispatch* dispatch, OSObject* target, void* reference)
{
	// Ensure the requested control selector is within range.
	if (selector >= kXboxHIDDriverClientMethodCount)
		return kIOReturnUnsupported;
	dispatch = (IOExternalMethodDispatch*)&sMethods[selector];
	target = this;
	reference = NULL;

	return super::externalMethod(selector, args, dispatch, target, reference);
}

OSMetaClassDefineReservedUnused(FPXboxHIDUserClient,  0);
OSMetaClassDefineReservedUnused(FPXboxHIDUserClient,  1);
OSMetaClassDefineReservedUnused(FPXboxHIDUserClient,  2);
OSMetaClassDefineReservedUnused(FPXboxHIDUserClient,  3);
OSMetaClassDefineReservedUnused(FPXboxHIDUserClient,  4);
OSMetaClassDefineReservedUnused(FPXboxHIDUserClient,  5);
OSMetaClassDefineReservedUnused(FPXboxHIDUserClient,  6);
OSMetaClassDefineReservedUnused(FPXboxHIDUserClient,  7);
OSMetaClassDefineReservedUnused(FPXboxHIDUserClient,  8);
OSMetaClassDefineReservedUnused(FPXboxHIDUserClient,  9);
