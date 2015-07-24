//
// FPXboxHIDUserClient.h
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


#ifndef _FPXboxHIDUserClient_h_
#define _FPXboxHIDUserClient_h_

#include "FPXboxHIDDriver.h"

#include <IOKit/IOService.h>
#include <IOKit/IOUserClient.h>

#include <IOKit/hid/IOHIDKeys.h>


class FPXboxHIDUserClient : public IOUserClient
{
    OSDeclareDefaultStructors(FPXboxHIDUserClient);

private:
    task_t _task;
    FPXboxHIDDriver* _driver;

public:
    virtual bool initWithTask (task_t owningTask, void* securityToken, UInt32 type, OSDictionary* properties);
    virtual bool start (IOService* provider);
    virtual IOReturn clientClose (void);
    virtual IOReturn externalMethod (uint32_t selector, IOExternalMethodArguments* args, IOExternalMethodDispatch* dispatch,
																						 OSObject* target, void* reference);

    static IOReturn sGetRawReport (OSObject* target, void* reference, IOExternalMethodArguments* args);
    virtual IOReturn getRawReport (XBPadReport** report);

private:
    const IOExternalMethodDispatch sMethods[kXboxHIDDriverClientMethodCount] = {
	   { (IOExternalMethodAction) &FPXboxHIDUserClient::sGetRawReport, 0, 0, 0, sizeof(XBPadReport) },
    };

public:
	OSMetaClassDeclareReservedUnused(FPXboxHIDUserClient,  0);
	OSMetaClassDeclareReservedUnused(FPXboxHIDUserClient,  1);
	OSMetaClassDeclareReservedUnused(FPXboxHIDUserClient,  2);
	OSMetaClassDeclareReservedUnused(FPXboxHIDUserClient,  3);
	OSMetaClassDeclareReservedUnused(FPXboxHIDUserClient,  4);
	OSMetaClassDeclareReservedUnused(FPXboxHIDUserClient,  5);
	OSMetaClassDeclareReservedUnused(FPXboxHIDUserClient,  6);
	OSMetaClassDeclareReservedUnused(FPXboxHIDUserClient,  7);
	OSMetaClassDeclareReservedUnused(FPXboxHIDUserClient,  8);
	OSMetaClassDeclareReservedUnused(FPXboxHIDUserClient,  9);

};

#endif // _FPXboxHIDUserClient_h_
