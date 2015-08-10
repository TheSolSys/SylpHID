//
// FPSylpHIDUserClient.h
// "SylpHID"
//
// Created by Paige Marie DePol <pmd@fizzypopstudios.com>
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


#ifndef _FPSylpHIDUserClient_h_
#define _FPSylpHIDUserClient_h_

#include "FPSylpHIDDriver.h"

#include <IOKit/IOService.h>
#include <IOKit/IOUserClient.h>

#include <IOKit/hid/IOHIDKeys.h>


class FPSylpHIDUserClient : public IOUserClient
{
    OSDeclareDefaultStructors(FPSylpHIDUserClient);

private:
    task_t _task;
    FPSylpHIDDriver* _driver;

public:
    virtual bool initWithTask (task_t owningTask, void* securityToken, UInt32 type, OSDictionary* properties);
    virtual bool start (IOService* provider);
    virtual IOReturn clientClose (void);
    virtual IOReturn externalMethod (uint32_t selector, IOExternalMethodArguments* args, IOExternalMethodDispatch* dispatch,
																						 OSObject* target, void* reference);
    static IOReturn sGetRawReport (OSObject* target, void* reference, IOExternalMethodArguments* args);
    virtual IOReturn getRawReport (XBPadReport** report);

    static IOReturn sLoadDefaultLayout (OSObject* target, void* reference, IOExternalMethodArguments* args);
    virtual IOReturn loadDefaultLayout (void);

	static IOReturn sGetSpeed (OSObject* target, void* reference, IOExternalMethodArguments* args);
	virtual IOReturn getSpeed (uint64_t* speed);

	static IOReturn sGetPower (OSObject* target, void* reference, IOExternalMethodArguments* args);
	virtual IOReturn getPower (uint64_t* power);

	static IOReturn sGetAddress (OSObject* target, void* reference, IOExternalMethodArguments* args);
	virtual IOReturn getAddress (uint64_t* addr);

private:
    const IOExternalMethodDispatch sMethods[kSylpHIDDriverClientMethodCount] = {
	   { (IOExternalMethodAction) &FPSylpHIDUserClient::sGetRawReport, 0, 0, 0, sizeof(XBPadReport) },
	   { (IOExternalMethodAction) &FPSylpHIDUserClient::sLoadDefaultLayout, 0, 0, 0, 0 },
	   { (IOExternalMethodAction) &FPSylpHIDUserClient::sGetSpeed, 0, 0, 1, 0 },
	   { (IOExternalMethodAction) &FPSylpHIDUserClient::sGetPower, 0, 0, 2, 0 },
	   { (IOExternalMethodAction) &FPSylpHIDUserClient::sGetAddress, 0, 0, 1, 0 },
    };

public:
	OSMetaClassDeclareReservedUnused(FPSylpHIDUserClient,  0);
	OSMetaClassDeclareReservedUnused(FPSylpHIDUserClient,  1);
	OSMetaClassDeclareReservedUnused(FPSylpHIDUserClient,  2);
	OSMetaClassDeclareReservedUnused(FPSylpHIDUserClient,  3);
	OSMetaClassDeclareReservedUnused(FPSylpHIDUserClient,  4);
	OSMetaClassDeclareReservedUnused(FPSylpHIDUserClient,  5);
	OSMetaClassDeclareReservedUnused(FPSylpHIDUserClient,  6);
	OSMetaClassDeclareReservedUnused(FPSylpHIDUserClient,  7);
	OSMetaClassDeclareReservedUnused(FPSylpHIDUserClient,  8);
	OSMetaClassDeclareReservedUnused(FPSylpHIDUserClient,  9);

};

#endif // _FPSylpHIDUserClient_h_
