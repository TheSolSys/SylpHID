//
// FPSylpHIDDriver.h
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
// Portions Copyright (c) 1999-2003 Apple Computer, Inc. All Rights Reserved.
//
// This file contains Original Code and/or Modifications of Original Code as defined in and that are subject to the
// Apple Public Source License Version 1.2 (the 'License'). You may not use this file except in compliance with the License.
//
// Please obtain a copy of the License at http://www.apple.com/publicsource and read it before using this file.
//
// As per license requirements see end of "FPSylpHIDDriver.cpp" for a list of changes made to the original source code.
// =========================================================================================================================


#ifndef _FPSylpHIDDriver_h_
#define _FPSylpHIDDriver_h_

#include <IOKit/IOService.h>

#include <IOKit/hid/IOHIDKeys.h>

#include <IOKit/IOBufferMemoryDescriptor.h>
#include <IOKit/IOTimerEventSource.h>

#include <IOKit/hid/IOHIDDevice.h>

#include <IOKit/usb/IOUSBBus.h>
#include <IOKit/usb/IOUSBInterface.h>
#include <IOKit/usb/USB.h>

#include "FPSylpHIDDriverKeys.h"


// remote control keys (index into ButtonMapping table which is generated
// and stored in the driver's property list)
typedef enum {
	kRemoteDisplay = 0,
	kRemoteReverse,
	kRemotePlay,
	kRemoteForward,
	kRemoteSkipBackward,
	kRemoteStop,
	kRemotePause,
	kRemoteSkipForward,
	kRemoteTitle,
	kRemoteUp,
	kRemoteInfo,
	kRemoteLeft,
	kRemoteSelect,
	kRemoteRight,
	kRemoteMenu,
	kRemoteDown,
	kRemoteBack,
	kRemoteKP1,
	kRemoteKP2,
	kRemoteKP3,
	kRemoteKP4,
	kRemoteKP5,
	kRemoteKP6,
	kRemoteKP7,
	kRemoteKP8,
	kRemoteKP9,
	kRemoteKP0,
	kNumRemoteButtons
} XboxRemoteKey;


// this structure describes the (fabricated) remote report
// that is passed up to the hid layer
typedef struct {
	// note: fields within byte are in reverse order
	// first byte
	UInt8 menu : 1;
	UInt8 info : 1;
	UInt8 title : 1;
	UInt8 right : 1;
	UInt8 left : 1;
	UInt8 down : 1;
	UInt8 up : 1;
	UInt8 select : 1;

	// second byte
	UInt8 skipBackward : 1;
	UInt8 forward : 1;
	UInt8 reverse : 1;
	UInt8 pause : 1;
	UInt8 stop : 1;
	UInt8 play : 1;
	UInt8 display : 1;
	UInt8 back : 1;

	// third byte
	UInt8 kp6 : 1;
	UInt8 kp5 : 1;
	UInt8 kp4 : 1;
	UInt8 kp3 : 1;
	UInt8 kp2 : 1;
	UInt8 kp1 : 1;
	UInt8 kp0 : 1;
	UInt8 skipForward : 1;

	// fourth byte
	UInt8 r1 : 5; // constant
	UInt8 kp9 : 1;
	UInt8 kp8 : 1;
	UInt8 kp7 : 1;

	// constant
	UInt8 r2;
	UInt8 r3;
} XBRemoteReport;


// this describes the actual hid report that we have to parse
typedef struct {
	UInt8 r1, r2;
	UInt8 scancode;
	UInt8 r3, r4, r5;
} XBActualRemoteReport;


// this checks that the structures are of the same size
//typedef int _sizeCheck[ (sizeof(XBRemoteReport) == sizeof(XBActualRemoteReport)) * 2 - 1];
#define ENABLE_HIDREPORT_LOGGING    0


// Report types from low level USB:
//  from USBSpec.h:
//    enum {
//        kHIDRtInputReport     = 1,
//        kHIDRtOutputReport        = 2,
//        kHIDRtFeatureReport       = 3
//    };
//
//  from IOHIDDescriptorParser.h:
//    // types of HID reports (input, output, feature)
//    enum
//    {
//        kHIDInputReport           =   1,
//        kHIDOutputReport,
//        kHIDFeatureReport,
//        kHIDUnknownReport     =   255
//    };
//
// Report types from high level HID Manager:
//  from IOHIDKeys.h:
//    enum IOHIDReportType
//    {
//        kIOHIDReportTypeInput = 0,
//        kIOHIDReportTypeOutput,
//        kIOHIDReportTypeFeature,
//        kIOHIDReportTypeCount
//    };
//
#define HIDMgr2USBReportType(x) (x + 1)
#define USB2HIDMgrReportType(x) (x - 1)


// Note: In other Neptune files, kMaxHIDReportSize was defined as 64. But Ferg & Keithen were unable to
// find that value in the USB HID 1.1 specs. Brent had previously changed it to 256 in the OS 9 HID Driver
// to  allow for reports spanning multiple packets. 256 may be no more a hard and fast limit, but it's
// working for now in OS 9.
#define kMaxHIDReportSize 256           // Max packet size = 8 for low speed & 64 for high speed.
#define kHIDDriverRetryCount    3


class FPSylpHIDDriver: public IOHIDDevice
{
	OSDeclareDefaultStructors(FPSylpHIDDriver)

	IOUSBInterface* _interface;
	IOUSBDevice* _device;
	IOUSBPipe* _interruptPipe;
	UInt32 _maxReportSize;
	IOBufferMemoryDescriptor* _buffer;
	IOUSBCompletion _completion;
	UInt32 _retryCount;
	thread_call_t _deviceDeadCheckThread;
	thread_call_t _clearFeatureEndpointHaltThread;
	bool _deviceDeadThreadActive;
	bool _deviceIsDead;
	bool _deviceHasBeenDisconnected;
	bool _needToClose;
	UInt32 _outstandingIO;
	IOCommandGate* _gate;
	IOUSBPipe* _interruptOutPipe;
	UInt32 _maxOutReportSize;
	IOBufferMemoryDescriptor* _outBuffer;
	UInt32 _deviceUsage;
	UInt32 _deviceUsagePage;
	UInt8 _maxPower;

	// xbox additions
	OSString* _xbDeviceType;
	OSString* _xbDeviceVendor;
	OSString* _xbDeviceName;
	OSData* _xbDeviceHIDReportDescriptor;
	OSDictionary* _xbDeviceOptionsDict;
	OSArray* _xbDeviceButtonMapArray;
	UInt8 _xbLastButtonPressed;

	// timing stuff (for synthesizing events - currently only for remote control)
	UInt16 _xbTimedEventsInterval;
	IOWorkLoop* _xbWorkLoop;
	IOTimerEventSource* _xbTimerEventSource;

	XBPadReport _rawReport;   // For sharing raw report data with pref-pane
	XBPadReport _mapReport;	  // For remapping elements

	// xbox device options
	union {
		XBPadOptions pad;
		// add more devices here...
	} _xbDeviceOptions;

    struct ExpansionData { };
    ExpansionData *reserved;

	static void InterruptReadHandlerEntry (OSObject* target, void* param, IOReturn status, UInt32 bufferSizeRemaining);
	void InterruptReadHandler (IOReturn status, UInt32 bufferSizeRemaining);

	static void CheckForDeadDeviceEntry (OSObject* target);
	void CheckForDeadDevice (void);

	static void ClearFeatureEndpointHaltEntry (OSObject* target);
	void ClearFeatureEndpointHalt (void);

	virtual void processPacket (void* data, UInt32 size);

	virtual void free (void);

	static IOReturn ChangeOutstandingIO (OSObject* target, void* arg0, void* arg1, void* arg2, void* arg3);

public:
	// IOService methods
	virtual bool init (OSDictionary* properties);
	virtual bool start( IOService* provider);
	virtual bool didTerminate (IOService* provider, IOOptionBits options, bool* defer);
	virtual bool willTerminate (IOService* provider, IOOptionBits options);

	// IOHIDDevice methods
	virtual bool handleStart (IOService* provider);
	virtual void handleStop (IOService*  provider);

	virtual IOReturn newReportDescriptor (IOMemoryDescriptor** descriptor ) const;

	virtual OSString* newTransportString (void) const;
	virtual OSNumber* newPrimaryUsageNumber (void) const;
	virtual OSNumber* newPrimaryUsagePageNumber (void) const;

	virtual OSNumber* newVendorIDNumber (void) const;

	virtual OSNumber* newProductIDNumber (void) const;

	virtual OSNumber* newVersionNumber (void) const;

	virtual OSString* newManufacturerString (void) const;

	virtual OSString* newProductString (void) const;

	virtual OSString* newSerialNumberString (void) const;

	virtual OSNumber* newLocationIDNumber (void) const;

	virtual IOReturn getReport (IOMemoryDescriptor* report, IOHIDReportType reportType, IOOptionBits options = 0);

	virtual IOReturn setReport (IOMemoryDescriptor* report, IOHIDReportType reportType, IOOptionBits options = 0);

	virtual IOReturn message (UInt32 type, IOService* provider, void* argument = 0);

	virtual UInt8 deviceSpeed(void) const;

	virtual UInt32 currentPower(void) const;

	virtual UInt32 availablePower(void) const;

	virtual USBDeviceAddress deviceAddress(void) const;

	// HID driver methods
	virtual OSString* newIndexedString (UInt8 index) const;

	virtual UInt32 getMaxReportSize (void);

	virtual void DecrementOutstandingIO (void);
	virtual void IncrementOutstandingIO (void);
	virtual IOReturn StartFinalProcessing (void);
	virtual IOReturn SetIdleMillisecs (UInt16 msecs);

	// driver or subclasses can change the format of the report here
	// for example, to reverse the Y axis values
	// return value indicates if event should be sent to HID layer or not
	virtual void remapElement (int map, XBPadReport* raw, int value);
	virtual bool manipulateReport (IOBufferMemoryDescriptor* report);

	// check the device product/vendor id's
	virtual bool isKnownDevice (IOService* provider);

	// fallback: probe device for #of interfaces, endpoints, etc
	virtual bool findGenericDevice (IOService* provider);

	// use active matching to determine the device type (gamepad, joystick, etc..)
	// so we can support 3rd-party devices
	virtual IOService* probe (IOService* service, SInt32* score);

	virtual IOReturn newUserClient (task_t owningTask, void* securityID, UInt32 type, OSDictionary* properties, IOUserClient** handler);

	// callback for timer event source
	static void generateTimedEvent (OSObject* object, IOTimerEventSource* tes);

	virtual IOReturn setProperties (OSObject* properties);

	// create and publish default option settings
	virtual void setDefaultOptions (void);

	// set device-specific options from our property list
	virtual void setDeviceOptions (void);

	// in handleStart() do any initialization we need here
	virtual bool setupDevice (void);

	// returns last hid report, before any modifications
	virtual XBPadReport* lastRawReport (void);

private:    // Should these be protected or virtual?
	IOReturn GetHIDDescriptor (UInt8 inDescriptorType, UInt8 inDescriptorIndex, UInt8* vOutBuf, UInt32* vOutSize);
	IOReturn GetReport (UInt8 inReportType, UInt8 inReportID, UInt8* vInBuf, UInt32* vInSize);
	IOReturn SetReport (UInt8 outReportType, UInt8 outReportID, UInt8* vOutBuf, UInt32 vOutSize);
	IOReturn GetIndexedString (UInt8 index, UInt8* vOutBuf, UInt32* vOutSize, UInt16 lang = 0x409) const;

#if ENABLE_HIDREPORT_LOGGING
	void LogBufferReport (char* report, UInt32 len);
	void LogMemReport (IOMemoryDescriptor* reportBuffer);
	char GetHexChar (char hexChar);
#endif

public:
	OSMetaClassDeclareReservedUnused(FPSylpHIDDriver,  0);
	OSMetaClassDeclareReservedUnused(FPSylpHIDDriver,  1);
	OSMetaClassDeclareReservedUnused(FPSylpHIDDriver,  2);
	OSMetaClassDeclareReservedUnused(FPSylpHIDDriver,  3);
	OSMetaClassDeclareReservedUnused(FPSylpHIDDriver,  4);
	OSMetaClassDeclareReservedUnused(FPSylpHIDDriver,  5);
	OSMetaClassDeclareReservedUnused(FPSylpHIDDriver,  6);
	OSMetaClassDeclareReservedUnused(FPSylpHIDDriver,  7);
	OSMetaClassDeclareReservedUnused(FPSylpHIDDriver,  8);
	OSMetaClassDeclareReservedUnused(FPSylpHIDDriver,  9);
	OSMetaClassDeclareReservedUnused(FPSylpHIDDriver, 10);
	OSMetaClassDeclareReservedUnused(FPSylpHIDDriver, 11);
	OSMetaClassDeclareReservedUnused(FPSylpHIDDriver, 12);
	OSMetaClassDeclareReservedUnused(FPSylpHIDDriver, 13);
	OSMetaClassDeclareReservedUnused(FPSylpHIDDriver, 14);
	OSMetaClassDeclareReservedUnused(FPSylpHIDDriver, 15);
	OSMetaClassDeclareReservedUnused(FPSylpHIDDriver, 16);
	OSMetaClassDeclareReservedUnused(FPSylpHIDDriver, 17);
	OSMetaClassDeclareReservedUnused(FPSylpHIDDriver, 18);
	OSMetaClassDeclareReservedUnused(FPSylpHIDDriver, 19);
};

#endif  // _FPSylpHIDDriver_h_
