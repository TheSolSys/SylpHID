//
// FPHIDUtilities.m
// "SylpHID"
//
// Based on SDL Joystick Driver (Simple DirectMedia Layer)
// Copyright (c)1997, 1998, 1999, 2000, 2001, 2002  Sam Lantinga
//
// Forked and Modified by Max Horn <email address unknown>
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


#include "FPHIDUtilities.h"

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <ctype.h>
#include <sys/errno.h>
#include <sysexits.h>
#include <mach/mach.h>
#include <mach/mach_error.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/IOCFPlugIn.h>
//#include <Kernel/IOKit/hidsystem/IOHIDUsageTables.h>
#include <IOKit/hid/IOHIDLib.h>
#include <IOKit/hid/IOHIDKeys.h>
#include <CoreFoundation/CoreFoundation.h>


// total number of joysticks found
static int HIDJoystickCount;


// struct for HID device elements
typedef struct HIDElement {
	IOHIDElementCookie cookie;              // unique value which identifies element, will NOT change
	long min;                               // reported min value possible
	long max;                               // reported max value possible

//	TODO: maybe should handle the following stuff somehow?
//
//	long scaledMin;							// reported scaled min value possible
//	long scaledMax;							// reported scaled max value possible
//	long size;								// size in bits of data return from element
//	Boolean relative;						// are reports relative to last report (deltas)
//	Boolean wrapping;						// does element wrap around (one value higher than max is min)
//	Boolean nonLinear;						// are the values reported non-linear relative to element movement
//	Boolean preferredState;					// does element have a preferred state (such as a button)
//	Boolean nullState;						// does element have null state

	// runtime variables used for auto-calibration
	long minReport;                         // min returned value
	long maxReport;                         // max returned value

	SInt32 lastValue;

	struct HIDElement* pNext;              // next element in list
} HIDElement;


// Struct for HID device hardware information
typedef struct HIDDevice {
	IOHIDDeviceInterface** interface;      // interface to device, NULL = no interface

	char product[256];                      // name of product
	long usage;                             // usage page from IOUSBHID Parser.h which defines general usage
	long usagePage;                         // usage within above page from IOUSBHID Parser.h which defines specific usage

	long axes;                              // number of axis (calculated, not reported by device)
	long buttons;                           // number of buttons (calculated, not reported by device)
	long hats;                              // number of hat switches (calculated, not reported by device)
	long elements;                          // number of total elements (shouldbe total of above) (calculated, not reported by device)

	HIDElement* firstAxis;
	HIDElement* firstButton;
	HIDElement* firstHat;

	struct HIDDevice* pNext;          // next device
} HIDDevice;


// Dummy interface for target in FPSylpHID_JoystickUpdate
@interface Dummy : NSObject

- (void) updateRawReport;
- (void) hidUpdateElement: (int)deviceIndex cookie: (int)cookie value: (SInt32)value;

@end


// Linked list of all available devices
static HIDDevice* gpDeviceList = NULL;


// Forward declaration
static void HIDGetCollectionElements (CFMutableDictionaryRef deviceProperties, HIDDevice* pDevice);


// Error messages
static void HIDReportErrorNum (char* strError, long numError)
{
	NSLog(@"HID Error: %s: %ld", strError, numError);
}


// returns current value for element, polling element
// will return 0 on error conditions which should be accounted for by application
static SInt32 HIDGetElementValue (HIDDevice* pDevice, HIDElement* pElement)
{
	IOReturn result = kIOReturnSuccess;
	IOHIDEventStruct hidEvent;
	hidEvent.value = 0;

	if (pDevice != NULL && pElement != NULL && pDevice->interface != NULL) {
		result = (*(pDevice->interface))->getElementValue(pDevice->interface, pElement->cookie, &hidEvent);
		if (result == kIOReturnSuccess) {
			// record min and max for auto calibration
			if (hidEvent.value < pElement->minReport)
				pElement->minReport = hidEvent.value;
			if (hidEvent.value > pElement->maxReport)
				pElement->maxReport = hidEvent.value;
		}
	}
	// auto user scale
	return hidEvent.value;
}


/*
// similiar to HIDGetElementValue, but auto-calibrates the value before returning it
static SInt32 HIDCalibratedValue (HIDDevice* pDevice, HIDElement* pElement)
{
float deviceScale = pElement->max - pElement->min;
float readScale = pElement->maxReport - pElement->minReport;
SInt32 value = HIDGetElementValue(pDevice, pElement);
if (readScale == 0)
return value; // no scaling at all
else
return ((value - pElement->minReport) * deviceScale / readScale) + pElement->min;
}


// similiar to HIDCalibratedValue but calibrates to an arbitrary scale instead of the elements default scale
static SInt32 HIDScaledCalibratedValue (HIDDevice* pDevice, HIDElement* pElement, long min, long max)
{
float deviceScale = max - min;
float readScale = pElement->maxReport - pElement->minReport;
SInt32 value = HIDGetElementValue(pDevice, pElement);
if (readScale == 0)
	return value; // no scaling at all
else
	return ((value - pElement->minReport) * deviceScale / readScale) + min;
}
*/


// Create and open an interface to device, required prior to extracting values or building queues.
// Note: appliction now owns the device and must close and release it prior to exiting
static IOReturn HIDCreateOpenDeviceInterface (io_object_t device, HIDDevice* pDevice)
{
	IOReturn result = kIOReturnSuccess;
	HRESULT plugInResult = S_OK;
	SInt32 score = 0;
	IOCFPlugInInterface** ppPlugInInterface = NULL;

	if (NULL == pDevice->interface) {
		result = IOCreatePlugInInterfaceForService(device, kIOHIDDeviceUserClientTypeID, kIOCFPlugInInterfaceID,
																					&ppPlugInInterface, &score);
		if (result == kIOReturnSuccess) {
			// Call a method of the intermediate plug-in to create the device interface
			plugInResult = (*ppPlugInInterface)->QueryInterface(ppPlugInInterface, CFUUIDGetUUIDBytes(kIOHIDDeviceInterfaceID),
																								 (void*)&(pDevice->interface));
			if (plugInResult != S_OK)
				HIDReportErrorNum("Couldn’t query HID class device interface from plugInInterface", plugInResult);
			(*ppPlugInInterface)->Release(ppPlugInInterface);
		} else
			HIDReportErrorNum("Failed to create **plugInInterface via IOCreatePlugInInterfaceForService", result);
	}

	if (pDevice->interface != NULL) {
		result = (*(pDevice->interface))->open(pDevice->interface, 0);
		if (result != kIOReturnSuccess)
			HIDReportErrorNum("Failed to open pDevice->interface via open", result);
	}

	return result;
}


// Closes and releases interface to device, should be done prior to exiting application
// Note: application will "own" the device if interface is not closed!
// (device may have to be plugged into a different port to get it working again without a restart)
static IOReturn HIDCloseReleaseInterface (HIDDevice* pDevice)
{
	IOReturn result = kIOReturnSuccess;

	if (pDevice != NULL && pDevice->interface != NULL) {
		// close the interface
		result = (*(pDevice->interface))->close(pDevice->interface);
		if (result != kIOReturnSuccess && result != kIOReturnNotOpen)
			HIDReportErrorNum("Failed to close IOHIDDeviceInterface", result);

		//release the interface
		result = (*(pDevice->interface))->Release(pDevice->interface);
		if (kIOReturnSuccess != result)
			HIDReportErrorNum("Failed to release IOHIDDeviceInterface", result);
		pDevice->interface = NULL;
	}
	return result;
}


// extracts actual specific element information from each element CF dictionary entry
static void HIDGetElementInfo (CFTypeRef refElement, HIDElement* pElement)
{
	long number;
	CFTypeRef refType;

	refType = CFDictionaryGetValue(refElement, CFSTR(kIOHIDElementCookieKey));
	if (refType && CFNumberGetValue(refType, kCFNumberLongType, &number))
		pElement->cookie = (IOHIDElementCookie)number;

	refType = CFDictionaryGetValue(refElement, CFSTR(kIOHIDElementMinKey));
	if (refType && CFNumberGetValue(refType, kCFNumberLongType, &number))
		pElement->min = number;

	refType = CFDictionaryGetValue(refElement, CFSTR(kIOHIDElementMaxKey));
	if (refType && CFNumberGetValue(refType, kCFNumberLongType, &number))
		pElement->max = number;

	pElement->minReport = pElement->max;
	pElement->maxReport = pElement->min;

//	TODO: maybe should handle the following stuff somehow?
//
//	refType = CFDictionaryGetValue (refElement, CFSTR(kIOHIDElementScaledMinKey));
//	if (refType && CFNumberGetValue (refType, kCFNumberLongType, &number))
//		pElement->scaledMin = number;
//	refType = CFDictionaryGetValue (refElement, CFSTR(kIOHIDElementScaledMaxKey));
//	if (refType && CFNumberGetValue (refType, kCFNumberLongType, &number))
//		pElement->scaledMax = number;
//	refType = CFDictionaryGetValue (refElement, CFSTR(kIOHIDElementSizeKey));
//	if (refType && CFNumberGetValue (refType, kCFNumberLongType, &number))
//		pElement->size = number;
//	refType = CFDictionaryGetValue (refElement, CFSTR(kIOHIDElementIsRelativeKey));
//	if (refType)
//		pElement->relative = CFBooleanGetValue (refType);
//	refType = CFDictionaryGetValue (refElement, CFSTR(kIOHIDElementIsWrappingKey));
//	if (refType)
//		pElement->wrapping = CFBooleanGetValue (refType);
//	refType = CFDictionaryGetValue (refElement, CFSTR(kIOHIDElementIsNonLinearKey));
//	if (refType)
//		pElement->nonLinear = CFBooleanGetValue (refType);
//	refType = CFDictionaryGetValue (refElement, CFSTR(kIOHIDElementHasPreferedStateKey));
//	if (refType)
//		pElement->preferredState = CFBooleanGetValue (refType);
//	refType = CFDictionaryGetValue (refElement, CFSTR(kIOHIDElementHasNullStateKey));
//	if (refType)
//		pElement->nullState = CFBooleanGetValue (refType);
}


// examines device element hierarchy to find elements of interest
// if element of interest allocate storage, add to list and retrieve element specific info
// if collection then call function to unpack elements which will then recall this function
static void HIDAddElement (CFTypeRef refElement, HIDDevice* pDevice)
{
	HIDElement* element = NULL;
	HIDElement** headElement = NULL;
	long elementType, usagePage, usage;
	CFTypeRef refElementType = CFDictionaryGetValue(refElement, CFSTR(kIOHIDElementTypeKey));
	CFTypeRef refUsagePage = CFDictionaryGetValue(refElement, CFSTR(kIOHIDElementUsagePageKey));
	CFTypeRef refUsage = CFDictionaryGetValue(refElement, CFSTR(kIOHIDElementUsageKey));

	if ((refElementType) && (CFNumberGetValue(refElementType, kCFNumberLongType, &elementType))) {
		// look at types of interest
		if ((elementType == kIOHIDElementTypeInput_Misc) || (elementType == kIOHIDElementTypeInput_Button) ||
		    (elementType == kIOHIDElementTypeInput_Axis)) {
			if (refUsagePage && CFNumberGetValue(refUsagePage, kCFNumberLongType, &usagePage) &&
			    refUsage && CFNumberGetValue(refUsage, kCFNumberLongType, &usage)) {
				// only interested in kHIDPage_GenericDesktop and kHIDPage_Button
				if (usagePage == kHIDPage_GenericDesktop) {
					switch (usage) {       // look at usage to determine function
						case kHIDUsage_GD_X:
						case kHIDUsage_GD_Y:
						case kHIDUsage_GD_Z:
						case kHIDUsage_GD_Rx:
						case kHIDUsage_GD_Ry:
						case kHIDUsage_GD_Rz:
						case kHIDUsage_GD_Slider:
						case kHIDUsage_GD_Dial:
						case kHIDUsage_GD_Wheel:
							element = (HIDElement*)calloc(sizeof(HIDElement), 1);
							if (element) {
								pDevice->axes++;
								headElement = &(pDevice->firstAxis);
							}
							break;

						case kHIDUsage_GD_Hatswitch:
							element = (HIDElement*)calloc(sizeof(HIDElement), 1);
							if (element) {
								pDevice->hats++;
								headElement = &(pDevice->firstHat);
							}
							break;
					}
				} else if (usagePage == kHIDPage_Button) {
					element = (HIDElement*)calloc(sizeof(HIDElement), 1);
					if (element) {
						pDevice->buttons++;
						headElement = &(pDevice->firstButton);
					}
				}
			}
		} else if (elementType == kIOHIDElementTypeCollection)
			HIDGetCollectionElements((CFMutableDictionaryRef)refElement, pDevice);
	}
	if (element && headElement) {
		pDevice->elements++;
		if (NULL == *headElement)
			*headElement = element;
		else {
			HIDElement* elementPrevious = nil, * elementCurrent;
			elementCurrent = *headElement;
			while (elementCurrent) {
				elementPrevious = elementCurrent;
				elementCurrent = elementPrevious->pNext;
			}
			elementPrevious->pNext = element;
		}
		element->pNext = NULL;
		HIDGetElementInfo(refElement, element);
	}
}


// collects information from each array member in device element list (each array memeber = element)
static void HIDGetElementsCFArrayHandler (const void* value, void* parameter)
{
	if (CFGetTypeID(value) == CFDictionaryGetTypeID())
		HIDAddElement((CFTypeRef)value, (HIDDevice*)parameter);
}


// handles retrieval of element information from arrays of elements in device IO registry information
static void HIDGetElements (CFTypeRef refElementCurrent, HIDDevice* pDevice)
{
	CFTypeID type = CFGetTypeID(refElementCurrent);
	if (type == CFArrayGetTypeID()) { // if element is an array
		CFRange range = { 0, CFArrayGetCount(refElementCurrent) };
		// CountElementsCFArrayHandler called for each array member
		CFArrayApplyFunction(refElementCurrent, range, HIDGetElementsCFArrayHandler, pDevice);
	}
}


// handles extracting element information from element collection CF types
// used from top level element decoding and hierarchy deconstruction to flatten device element list
static void HIDGetCollectionElements (CFMutableDictionaryRef deviceProperties, HIDDevice* pDevice)
{
	CFTypeRef refElementTop = CFDictionaryGetValue(deviceProperties, CFSTR(kIOHIDElementKey));
	if (refElementTop)
		HIDGetElements(refElementTop, pDevice);
}


// use top level element usage page and usage to discern device usage page and usage setting appropriate vlaues in device record
static void HIDTopLevelElementHandler (const void* value, void* parameter)
{
	CFTypeRef refCF = 0;
	if (CFGetTypeID(value) != CFDictionaryGetTypeID())
		return;

	refCF = CFDictionaryGetValue(value, CFSTR(kIOHIDElementUsagePageKey));
	if (!CFNumberGetValue(refCF, kCFNumberLongType, &((HIDDevice*)parameter)->usagePage))
		HIDReportErrorNum("CFNumberGetValue error retrieving pDevice->usagePage", 0);

	refCF = CFDictionaryGetValue(value, CFSTR(kIOHIDElementUsageKey));
	if (!CFNumberGetValue(refCF, kCFNumberLongType, &((HIDDevice*)parameter)->usage))
		HIDReportErrorNum("CFNumberGetValue error retrieving pDevice->usage", 0);
}


// extracts device info from CF dictionary records in IO registry
static void HIDGetDeviceInfo (io_object_t device, CFMutableDictionaryRef hidProperties, HIDDevice* pDevice)
{
	CFMutableDictionaryRef usbProperties = 0;
	io_registry_entry_t parent1, parent2;

	// Mac OS X currently is not mirroring all USB properties to HID page so we need to look at USB device page
	// to also get dictionary for usb properties: step up two levels and get CF dictionary for USB properties
	if ((IORegistryEntryGetParentEntry(device, kIOServicePlane, &parent1) == KERN_SUCCESS) &&
	    (IORegistryEntryGetParentEntry(parent1, kIOServicePlane, &parent2) == KERN_SUCCESS) &&
	    (IORegistryEntryCreateCFProperties(parent2, &usbProperties, kCFAllocatorDefault, kNilOptions) == KERN_SUCCESS)) {
		if (usbProperties) {
			// get device info (try hid dictionary first, if fail then go to usb dictionary)
			CFTypeRef refCF = 0;
			// get product name
			refCF = CFDictionaryGetValue(hidProperties, CFSTR(kIOHIDProductKey));
			if (!refCF)
				refCF = CFDictionaryGetValue(usbProperties, CFSTR("USB Product Name"));
			if (refCF && !CFStringGetCString(refCF, pDevice->product, 256, CFStringGetSystemEncoding()))
				HIDReportErrorNum("CFStringGetCString error retrieving pDevice->product", 0);

			// get usage page and usage
			refCF = CFDictionaryGetValue(hidProperties, CFSTR(kIOHIDPrimaryUsagePageKey));
			if (refCF) {
				if (!CFNumberGetValue(refCF, kCFNumberLongType, &pDevice->usagePage))
					HIDReportErrorNum("CFNumberGetValue error retrieving pDevice->usagePage", 0);
				refCF = CFDictionaryGetValue(hidProperties, CFSTR(kIOHIDPrimaryUsageKey));
				if (refCF && !CFNumberGetValue(refCF, kCFNumberLongType, &pDevice->usage))
					HIDReportErrorNum("CFNumberGetValue error retrieving pDevice->usage", 0);
			}

			// get top level element HID usage page or usage
			if (refCF == NULL) {
				// use top level element instead
				CFTypeRef refCFTopElement = 0;
				refCFTopElement = CFDictionaryGetValue(hidProperties, CFSTR(kIOHIDElementKey));
				{
					// refCFTopElement points to an array of element dictionaries
					CFRange range = { 0, CFArrayGetCount(refCFTopElement) };
					CFArrayApplyFunction(refCFTopElement, range, HIDTopLevelElementHandler, pDevice);
				}
			}
			CFRelease(usbProperties);
		} else
			HIDReportErrorNum("IORegistryEntryCreateCFProperties failed to create usbProperties", 0);

		if (IOObjectRelease(parent2) != kIOReturnSuccess)
			HIDReportErrorNum("IOObjectRelease error with parent2", 0);
		if (IOObjectRelease(parent1) != kIOReturnSuccess)
			HIDReportErrorNum("IOObjectRelease error with parent1", 0);
	}
}


static HIDDevice* HIDBuildDevice (io_object_t device)
{
	HIDDevice* pDevice = (HIDDevice*)calloc(sizeof(HIDDevice),1);
	if (pDevice) {
		// get dictionary for HID properties
		CFMutableDictionaryRef hidProperties = 0;
		kern_return_t result = IORegistryEntryCreateCFProperties(device, &hidProperties, kCFAllocatorDefault, kNilOptions);
		if ((result == KERN_SUCCESS) && hidProperties) {
			// create device interface
			result = HIDCreateOpenDeviceInterface(device, pDevice);
			if (result == kIOReturnSuccess) {
				HIDGetDeviceInfo(device, hidProperties, pDevice); // device used to find parents in registry tree
				HIDGetCollectionElements(hidProperties, pDevice);
			} else {
				free(pDevice);
				pDevice = NULL;
			}
			CFRelease(hidProperties);
		} else {
			free(pDevice);
			pDevice = NULL;
		}
	}
	return pDevice;
}


// disposes of the element list associated with a device and the memory associated with the list
static void HIDDisposeElementList (HIDElement** elementList)
{
	HIDElement* pElement = *elementList;
	while (pElement) {
		HIDElement* pElementNext = pElement->pNext;
		free(pElement);
		pElement = pElementNext;
	}
	*elementList = NULL;
}


// disposes of a single device (closing and release interface, free memory for device and elements, sets device pointer to NULL)
static HIDDevice* HIDDisposeDevice (HIDDevice** ppDevice)
{
	kern_return_t result = KERN_SUCCESS;
	HIDDevice* pDeviceNext = NULL;
	if (*ppDevice) {
		// save next device prior to disposing of this device
		pDeviceNext = (*ppDevice)->pNext;

		// free element lists
		HIDDisposeElementList(&(*ppDevice)->firstAxis);
		HIDDisposeElementList(&(*ppDevice)->firstButton);
		HIDDisposeElementList(&(*ppDevice)->firstHat);

		result = HIDCloseReleaseInterface(*ppDevice);
		if (kIOReturnSuccess != result)
			HIDReportErrorNum("HIDCloseReleaseInterface failed when trying to dispose device", result);
		free(*ppDevice);
		*ppDevice = NULL;
	}
	return pDeviceNext;
}


// Function to scan the system for joysticks
// Joystick 0 should be the system default joystick
// This function should return the number of available joysticks, or -1 on an unrecoverable fatal error
int FPSylpHID_JoystickInit()
{
	IOReturn result = kIOReturnSuccess;
	mach_port_t masterPort = 0;
	io_iterator_t hidObjectIterator = 0;
	CFMutableDictionaryRef hidMatchDictionary = NULL;
	HIDDevice* device, * lastDevice;
	io_object_t ioHIDDeviceObject = 0;

	HIDJoystickCount = 0;

	if (NULL != gpDeviceList) {
		HIDReportErrorNum("Joystick: Device list already inited", 0);
		return -1;
	}

	result = IOMasterPort(bootstrap_port, &masterPort);
	if (kIOReturnSuccess != result) {
		HIDReportErrorNum("Joystick: IOMasterPort error with bootstrap_port", 0);
		return -1;
	}

	// Set up a matching dictionary to search I/O Registry by class name for all HID class devices
	hidMatchDictionary = IOServiceMatching("FPSylpHIDDriver");
	if (hidMatchDictionary == NULL) {
		HIDReportErrorNum("Joystick: Failed to get HID CFMutableDictionaryRef via IOServiceMatching", 0);
		return -1;
	}

	// Now search I/O Registry for matching devices
	// IOServiceGetMatchingServices consumes a reference to the dictionary, so we don't need to release the dictionary ref.
	result = IOServiceGetMatchingServices(masterPort, hidMatchDictionary, &hidObjectIterator);
	if (result != kIOReturnSuccess) {
		HIDReportErrorNum("Joystick: Couldn't create a HID object iterator", 0);
		return -1;
	}

	// there are no joysticks
	if (hidObjectIterator == 0) {
		gpDeviceList = NULL;
		HIDJoystickCount = 0;
		return 0;
	}

	// build flat linked list of devices from device iterator
	gpDeviceList = lastDevice = NULL;
	while ((ioHIDDeviceObject = IOIteratorNext(hidObjectIterator))) {
		// build a device record
		device = HIDBuildDevice(ioHIDDeviceObject);
		if (!device)
			continue;
		// dump device object, it is no longer needed
		IOObjectRelease(ioHIDDeviceObject);

		// Filter device list to non-keyboard/mouse stuff
		if (device->usagePage == kHIDPage_GenericDesktop && (device->usage == kHIDUsage_GD_Keyboard || device->usage == kHIDUsage_GD_Mouse)) {
			// release memory for the device
			HIDDisposeDevice(&device);
			free(device);
			continue;
		}
		// Add device to the end of the list
		if (lastDevice)
			lastDevice->pNext = device;
		else
			gpDeviceList = device;
		lastDevice = device;
	}

	// release the iterator
	IOObjectRelease(hidObjectIterator);

	// Count the total number of devices we found
	device = gpDeviceList;
	while (device) {
		HIDJoystickCount++;
		device = device->pNext;
	}

	return HIDJoystickCount;
}


// Update joystick information, this is called via a polling timer
void FPSylpHID_JoystickUpdate(id target)
{
	HIDDevice* device;
	HIDElement* element;
	SInt32 value;
	int i;
	int deviceIndex;

	deviceIndex = 0;
	for (device = gpDeviceList; device; device = device->pNext, deviceIndex++) {
		[target updateRawReport];

		element = device->firstAxis;
		i = 0;
		while (element) {
			value = HIDGetElementValue(device, element);
			if (value != element->lastValue) {
				[target hidUpdateElement: deviceIndex cookie: (int)element->cookie value: value];
			}
			element->lastValue = value;

			element = element->pNext;
			i++;
		}

		element = device->firstButton;
		i = 0;
		while (element) {
			value = HIDGetElementValue(device, element);
			if (value != element->lastValue)
				[target hidUpdateElement: deviceIndex cookie: (int)element->cookie value: value];
			element->lastValue = value;

			element = element->pNext;
			i++;
		}

		element = device->firstHat;
		i = 0;
		while (element) {
			value = HIDGetElementValue(device, element);
			if (value != element->lastValue)
				[target hidUpdateElement: deviceIndex cookie: (int)element->cookie value: value];
			element->lastValue = value;

			element = element->pNext;
			i++;
		}
	}

	return;
}


// Function to perform any system-specific joystick related cleanup
void FPSylpHID_JoystickQuit(void)
{
	while (NULL != gpDeviceList)
		gpDeviceList = HIDDisposeDevice(&gpDeviceList);
}
