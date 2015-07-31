//
// FPXboxHIDPrefsPane.m
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


#import <IOKit/hid/IOHIDUsageTables.h>

#import "FPXboxHIDPrefsPane.h"
#import "FPXboxHIDDriverInterface.h"
#import "FPXboxHIDPrefsLoader.h"
#import "FPHIDUtilities.h"
#import "FPTriggerView.h"
#import "FPAxisPairView.h"
#import "FPButtonView.h"
#import "FPDPadView.h"
#import "FPAnalogDigitalButton.h"
#import "FPImageView.h"
#import "FPAlertView.h"
#import "FPConfigPopUp.h"
#import "SMDoubleSlider.h"


#define kStickAsButtonAlert		15	// percentage threshold for deadzone too small when assigning sticks to buttons

#define kSegmentConfigCreate	0
#define kSegmentConfigDelete	1	// segments for main window segmented control
#define kSegmentConfigPopUp		2

#define kSegmentMenusXbox		0	// segments for main window menu segmented control
#define kSegmentMenusHID		1

#define kSegmentAppsCreate		0
#define kSegmentAppsDelete		1	// segments for app bindings segmented control
#define kSegmentAppsUndo		2

#define kUndoMappings			1	// flags for two types of undo available
#define kUndoBindings			2


typedef void(^OPBlock)(NSInteger result);	// for OpenPanel completion block


@implementation FPXboxHIDPrefsPane

#pragma mark === NSPreferencesPane Methods ==========

- (void) mainViewDidLoad
{
	[_buttonBackView setMax: 1];
	[_buttonBackView setColor: XBOX_COLOR];
	[_buttonBackView showOverlayOnlyWhenActive];

	[_buttonStartView setMax: 1];
	[_buttonStartView setColor: XBOX_COLOR];
	[_buttonStartView showOverlayOnlyWhenActive];

	[_leftStickDeadzoneX setDeadzoneSlider: _leftStickDeadzoneXField];
	[_leftStickDeadzoneX setDeadzoneValue: 0];

	[_leftStickDeadzoneY setDeadzoneSlider: _leftStickDeadzoneYField];
	[_leftStickDeadzoneY setDeadzoneValue: 0];

	[_rightStickDeadzoneX setDeadzoneSlider: _rightStickDeadzoneXField];
	[_rightStickDeadzoneX setDeadzoneValue: 0];

	[_rightStickDeadzoneY setDeadzoneSlider: _rightStickDeadzoneYField];
	[_rightStickDeadzoneY setDeadzoneValue: 0];

	[_leftTriggerLivezone setDoubleLoValue: kButtonMin + 1 andHiValue: kButtonAnalogMax];
	[_leftTriggerMode setIsDigital: NO];

	[_rightTriggerLivezone setDoubleLoValue: kButtonMin + 1 andHiValue: kButtonAnalogMax];
	[_rightTriggerMode setIsDigital: NO];

	[_buttonWhiteLivezone setDoubleLoValue: kButtonMin + 1 andHiValue: kButtonAnalogMax];
	[_buttonWhiteView setColor: [NSColor whiteColor]];
	[_buttonWhiteMode setIsDigital: NO];

	[_buttonBlackLivezone setDoubleLoValue: kButtonMin + 1 andHiValue: kButtonAnalogMax];
	[_buttonBlackView setColor: [NSColor blackColor]];
	[_buttonBlackMode setIsDigital: NO];

	[_buttonBlueLivezone setDoubleLoValue: kButtonMin + 1 andHiValue: kButtonAnalogMax];
	[_buttonBlueView setColor: [NSColor colorWithCalibratedRed: 0.333 green: 0.750 blue: 1.0 alpha: 1.000]];
	[_buttonBlueMode setIsDigital: NO];

	[_buttonYellowLivezone setDoubleLoValue: kButtonMin + 1 andHiValue: kButtonAnalogMax];
	[_buttonYellowView setColor: [NSColor yellowColor]];
	[_buttonYellowMode setIsDigital: NO];

	[_buttonGreenLivezone setDoubleLoValue: kButtonMin + 1 andHiValue: kButtonAnalogMax];
	[_buttonGreenView setColor: [NSColor greenColor]];
	[_buttonGreenMode setIsDigital: NO];

	[_buttonRedLivezone setDoubleLoValue: kButtonMin + 1 andHiValue: kButtonAnalogMax];
	[_buttonRedView setColor: [NSColor redColor]];
	[_buttonRedMode setIsDigital: NO];

	[_createText setDelegate: self];
	[_editText setDelegate: self];

	[_leftStickAlertX setHidden: YES];
	[_leftStickAlertX setAlertView: _alertView];

	[_leftStickAlertY setHidden: YES];
	[_leftStickAlertY setAlertView: _alertView ];

	[_rightStickAlertX setHidden: YES];
	[_rightStickAlertX setAlertView: _alertView];

	[_rightStickAlertY setHidden: YES];
	[_rightStickAlertY setAlertView: _alertView];

	[_actionEdit setTooltip: @"Edit Config Name" withTipControl: _actionTip andBaseControl: _actionBase];
	[_actionUndo setTooltip: @"Undo All Changes" withTipControl: _actionTip andBaseControl: _actionBase];
	[_actionApps setTooltip: @"Edit App Bindings" withTipControl: _actionTip andBaseControl: _actionBase];
	[_actionInfo setTooltip: @"View Pad Information" withTipControl: _actionTip andBaseControl: _actionBase];

	NSBundle* bundle = [NSBundle bundleForClass: [self class]];
	[_creditsText readRTFDFromFile: [bundle pathForResource: @"credits" ofType: @"rtf"]];
	[_creditsText setEditable: YES];
	[_creditsText checkTextInDocument: nil];  // activates hyperlinks
	[_creditsText setEditable: NO];

	[_donateText readRTFDFromFile: [bundle pathForResource: @"donate" ofType: @"rtf"]];
	[_donateText setEditable: YES];
	[_donateText checkTextInDocument: nil];  // activates hyperlinks
	[_donateText setEditable: NO];

	// Use menu item tags to store mapping information
	[[_menuAxisXbox itemAtIndex: kMenuAxisDisabled] setTag: kCookiePadDisabled];
	[[_menuAxisXbox itemAtIndex: kMenuAxisLeftStickH] setTag: kCookiePadLxAxis];
	[[_menuAxisXbox itemAtIndex: kMenuAxisLeftStickV] setTag: kCookiePadLyAxis];
	[[_menuAxisXbox itemAtIndex: kMenuAxisRightStickH] setTag: kCookiePadRxAxis];
	[[_menuAxisXbox itemAtIndex: kMenuAxisRightStickV] setTag: kCookiePadRyAxis];
	[[_menuAxisXbox itemAtIndex: kMenuAxisTriggers] setTag: kCookiePadTriggers];
	[[_menuAxisXbox itemAtIndex: kMenuAxisGreenRed] setTag: kCookiePadGreenRed];
	[[_menuAxisXbox itemAtIndex: kMenuAxisBlueYellow] setTag: kCookiePadBlueYellow];
	[[_menuAxisXbox itemAtIndex: kMenuAxisGreenYellow] setTag: kCookiePadGreenYellow];
	[[_menuAxisXbox itemAtIndex: kMenuAxisBlueRed] setTag: kCookiePadBlueRed];
	[[_menuAxisXbox itemAtIndex: kMenuAxisRedYellow] setTag: kCookiePadRedYellow];
	[[_menuAxisXbox itemAtIndex: kMenuAxisGreenBlue] setTag: kCookiePadGreenBlue];
	[[_menuAxisXbox itemAtIndex: kMenuAxisWhiteBlack] setTag: kCookiePadWhiteBlack];
	[[_menuAxisXbox itemAtIndex: kMenuAxisDPadUpDown] setTag: kCookiePadDPadUpDown];
	[[_menuAxisXbox itemAtIndex: kMenuAxisDPadLeftRight] setTag: kCookiePadDPadLeftRight];
	[[_menuAxisXbox itemAtIndex: kMenuAxisStartBack] setTag: kCookiePadStartBack];
	[[_menuAxisXbox itemAtIndex: kMenuAxisClickLeftRight] setTag: kCookiePadClickLeftRight];

	[[_menuButtonXbox itemAtIndex: kMenuButtonDisabled] setTag: kCookiePadDisabled];
	[[_menuButtonXbox itemAtIndex: kMenuButtonLeftTrigger] setTag: kCookiePadLeftTrigger];
	[[_menuButtonXbox itemAtIndex: kMenuButtonRightTrigger] setTag: kCookiePadRightTrigger];
	[[_menuButtonXbox itemAtIndex: kMenuButtonDPadUp] setTag: kCookiePadDPadUp];
	[[_menuButtonXbox itemAtIndex: kMenuButtonDPadDown] setTag: kCookiePadDPadDown];
	[[_menuButtonXbox itemAtIndex: kMenuButtonDPadLeft] setTag: kCookiePadDPadLeft];
	[[_menuButtonXbox itemAtIndex: kMenuButtonDPadRight] setTag: kCookiePadDPadRight];
	[[_menuButtonXbox itemAtIndex: kMenuButtonStart] setTag: kCookiePadButtonStart];
	[[_menuButtonXbox itemAtIndex: kMenuButtonBack] setTag: kCookiePadButtonBack];
	[[_menuButtonXbox itemAtIndex: kMenuButtonLeftClick] setTag: kCookiePadLeftClick];
	[[_menuButtonXbox itemAtIndex: kMenuButtonRightClick] setTag: kCookiePadRightClick];
	[[_menuButtonXbox itemAtIndex: kMenuButtonGreen] setTag: kCookiePadButtonGreen];
	[[_menuButtonXbox itemAtIndex: kMenuButtonRed] setTag: kCookiePadButtonRed];
	[[_menuButtonXbox itemAtIndex: kMenuButtonBlue] setTag: kCookiePadButtonBlue];
	[[_menuButtonXbox itemAtIndex: kMenuButtonYellow] setTag: kCookiePadButtonYellow];
	[[_menuButtonXbox itemAtIndex: kMenuButtonBlack] setTag: kCookiePadButtonBlack];
	[[_menuButtonXbox itemAtIndex: kMenuButtonWhite] setTag: kCookiePadButtonWhite];

	// copy tags from xbox menus into hid menus
	for (int i = 0; i < kMenuAxisCount; i++)
		if ([[_menuAxisHID itemAtIndex: i] isSeparatorItem] == NO)
			[[_menuAxisHID itemAtIndex: i] setTag: [[_menuAxisXbox itemAtIndex: i] tag]];
	for (int i = 0; i < kMenuButtonCount; i++)
		if ([[_menuButtonHID itemAtIndex: i] isSeparatorItem] == NO)
			[[_menuButtonHID itemAtIndex: i] setTag: [[_menuButtonXbox itemAtIndex: i] tag]];

	_appData = [[FPDataSourceApps alloc] init];
	[(NSTableView*)_appsTable setDataSource: _appData];
	[_appsTable setDelegate: self];

	_lastConfig = nil;
	_undoBindings = nil;

	_appConfig = [NSMutableDictionary dictionary];

	NSShadow *textShadow = [[NSShadow alloc] init];
	[textShadow setShadowOffset: NSMakeSize(0.5, -1)];
	[textShadow setShadowColor: [NSColor colorWithCalibratedWhite: 0.0 alpha: 1]];
	[textShadow setShadowBlurRadius: 1.5];

	NSMutableParagraphStyle *paragraph = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
	[paragraph setAlignment: NSLeftTextAlignment];
	[paragraph setLineBreakMode: NSLineBreakByTruncatingTail];

	_appAttrs = [NSDictionary dictionaryWithObjectsAndKeys: /*textFont,	NSFontAttributeName, */
															textShadow,	NSShadowAttributeName,
															/* textColor,	NSForegroundColorAttributeName, */
															paragraph,	NSParagraphStyleAttributeName,	nil];
}


- (void) willSelect
{
	[self configureInterface];
	[self saveLastDeviceIdentifier];
	[self registerForNotifications];
	[self startHIDDeviceInput];
	[self getVersion];

	// if opening sysprefs for first time load saved config for all devices
	// this prevents app-specific configs from overwriting other configs!
	for (id device in _devices)
		[FPXboxHIDPrefsLoader loadSavedConfigForDevice: device];
}


- (void) willUnselect
{
	if (_devices) {
		_devices = nil;
	}
	[self deregisterForNotifications];
	[self stopHIDDeviceInput];
}


#pragma mark === Private Methods ==================

- (void) saveLastDeviceIdentifier
{
	_lastDevice = [[_devices objectAtIndex: [_devicePopUp indexOfSelectedItem]] identifier];
	if (_lastDevice != nil)
		[_textIdentifier setStringValue: _lastDevice];
}


- (void) getVersion
{
	NSBundle* bundle = [NSBundle bundleWithPath: @"/System/Library/Extensions/Xbox HID.kext"];
	NSString* version = [[bundle infoDictionary] objectForKey: @"CFBundleGetInfoString"];
	if (version == nil) version = @"Unknown Version";
	[_textVersion setStringValue: version];
}


#pragma mark --- Devices Popup ------------------------

- (void) buildDevicesPopUpButton
{
	int i;
	int numControllers = 0;
	int numRemotes = 0;

	[_devicePopUp setPullsDown: NO];
	[self clearDevicesPopUpButton];

	for (i = 0; i < [_devices count]; i++) {
		id device = [_devices objectAtIndex: i];
		int deviceNum = 0;
		NSString* name;

		if ([device deviceIsPad]) {
			deviceNum = ++numControllers;
			name = @"Pad";

		} else if ([device deviceIsRemote]) {
			deviceNum = ++numRemotes;
			name = @"IR";

		} else
			deviceNum = 0;

		if (deviceNum)
			[_devicePopUp addItemWithTitle: [NSString stringWithFormat: @"(%@ #%d) %@", name, deviceNum, [device productName]]];
	}

	if (_lastDevice) {
		int offset = 0;
		for (id device in _devices) {
			if ([[device identifier] isEqualToString: _lastDevice]) {
				[_devicePopUp selectItemAtIndex: offset];
				break;
			}
			offset++;
		}
	} else if ([_devicePopUp numberOfItems] > 0)
		[_devicePopUp selectItemAtIndex: 0];

	[self saveLastDeviceIdentifier];
	[self appSetDataSource];
}


- (void) clearDevicesPopUpButton
{
	[_devicePopUp removeAllItems];
}


- (void) buildConfigurationPopUpButton
{
	id device = [_devices objectAtIndex: [_devicePopUp indexOfSelectedItem]];
	[self buildConfigurationPopUpButton: _configPopUp withDefaultConfig: [FPXboxHIDPrefsLoader configNameForDevice: device]];
}


// FPAppBindings protocol method
- (void) buildConfigurationPopUpButton: (FPConfigPopUp*)button withDefaultConfig: (NSString*)defconfig
{
	id device = [_devices objectAtIndex: [_devicePopUp indexOfSelectedItem]];

	NSDictionary* appconf = [_appConfig objectForKey: [device identifier]];
	NSArray* configs = [FPXboxHIDPrefsLoader configNamesForDeviceType: [device deviceType]];
	configs = [configs sortedArrayUsingSelector: @selector(compare:)];

	[button removeAllItems];

	[button addItemWithTitle: kConfigNameDefault];
	if ([configs count] > 1)
		[[button menu] addItem: [NSMenuItem separatorItem]];

	for (NSString* configName in configs) {
		if ([configName isEqualTo: kConfigNameDefault] == NO)
			[button addItemWithTitle: configName];
	}

	if (defconfig == nil) {
		[button selectItemAtIndex: 0];

	} else if (appconf != nil) {
		[button selectItemForAppConfig: appconf withDeviceConfig: defconfig];

 	} else {
		[button clearAppConfig];
		[button selectItemWithTitle: defconfig];

	}
}


#pragma mark --- Config PopUp / Actions -----------------

- (void) enableConfigPopUpButton
{
	[_configPopUp setEnabled: true];
	[_configButtons setEnabled: true];
}


- (void) disableConfigPopUpButton
{
	[_configPopUp clearAppConfig];
	[_configPopUp removeAllItems];
	[_configPopUp setEnabled: false];
	[_configButtons setEnabled: false];
}


- (void) configCreate
{
	NSPoint buttonPoint = NSMakePoint(NSMidX([_configButtons frame]) - 19, NSMidY([_configButtons frame]));
	_popup = [[MAAttachedWindow alloc] initWithView: _createView
	          attachedToPoint: buttonPoint
	          inWindow: [_configButtons window]
	          onSide: MAPositionTop
	          atDistance: 4];
	[_createOK setEnabled: NO];
	[_createOK setKeyEquivalent: @"\r"];
	[_createText setStringValue: @""];
	[_popup setViewMargin: 1.0];
	[self fadeInAttachedWindow];
}


- (IBAction) configCreateEnd: (id)sender
{
	if (sender == _createOK) {
		id device = [_devices objectAtIndex: [_devicePopUp indexOfSelectedItem]];
		[FPXboxHIDPrefsLoader createConfigForDevice: device withName: [_createText stringValue]];
		[self buildConfigurationPopUpButton];
		_lastConfig = [_configPopUp titleOfSelectedItem];

		if ([_createCopy state] == NSOffState) {
			// Reset configuration if copy checkbox not checked
			[device loadDefaultLayout];
			[FPXboxHIDPrefsLoader saveConfigForDevice: device];
			[self initPadOptionsWithDevice: device];
		}
	}

	[self fadeOutAttachedWindow];
}

- (void) configDelete
{
	NSString* config = [_configPopUp titleOfSelectedItem];
	BOOL isDefault = [config isEqualTo: kConfigNameDefault];
	NSPoint buttonPoint = NSMakePoint(NSMidX([_configButtons frame]), NSMidY([_configButtons frame]));
	_popup = [[MAAttachedWindow alloc] initWithView: (isDefault ? _defaultView : _deleteView)
	          attachedToPoint: buttonPoint
	          inWindow: [_configButtons window]
	          onSide: MAPositionTop
	          atDistance: 4];
	[(isDefault ? _defaultOK : _deleteOK) setKeyEquivalent: @"\r"];
	if (isDefault == NO) {
		int total = [FPXboxHIDPrefsLoader totalAppBindingsForConfigNamed: config];
		[_deleteApps setStringValue: total == 0 ? @"No Apps" : total == 1 ? @"1 App" : [NSString stringWithFormat: @"%d Apps", total]];
	}
	[_popup setViewMargin: 1.0];
	[self fadeInAttachedWindow];
}


- (IBAction) configDeleteEnd: (id)sender
{
    id device = [_devices objectAtIndex: [_devicePopUp indexOfSelectedItem]];

	if (sender == _deleteOK) {
		// Delete configuration
		[FPXboxHIDPrefsLoader deleteConfigWithName: [_configPopUp titleOfSelectedItem]];
		[self buildConfigurationPopUpButton];
		_lastConfig = [_configPopUp titleOfSelectedItem];

		// Load configuration now selected in popup
        [FPXboxHIDPrefsLoader loadConfigForDevice: device withName: [_configPopUp titleOfSelectedItem]];

	} else if (sender == _defaultOK) {
		// Reset configuration
		[device loadDefaultLayout];
		[FPXboxHIDPrefsLoader saveConfigForDevice: device];
		[self initPadOptionsWithDevice: device];
	}

	[self fadeOutAttachedWindow];
}


- (void) configActions
{
	id device = [_devices objectAtIndex: [_devicePopUp indexOfSelectedItem]];
	NSPoint buttonPoint = NSMakePoint(NSMidX([_configButtons frame]) + 19, NSMidY([_configButtons frame]));
	_popup = [[MAAttachedWindow alloc] initWithView: _actionView
	          attachedToPoint: buttonPoint
	          inWindow: [_configButtons window]
	          onSide: MAPositionTop
	          atDistance: 4];
	[_actionEdit setEnabled: ![FPXboxHIDPrefsLoader isDefaultConfigForDevice: device]];
	[_actionEdit resetImage];
	[_actionUndo setEnabled: [self canUndo: kUndoMappings]];
	[_actionUndo resetImage];
	[_actionApps setEnabled: YES];
	[_actionApps resetImage];
	[_actionInfo resetImage];
	[_popup setViewMargin: 1.0];
	[self fadeInAttachedWindow];
}


- (IBAction) configActionsPick: (id)sender
{
	id device = [_devices objectAtIndex: [_devicePopUp indexOfSelectedItem]];

	if (sender == _actionNO) {
		[self fadeOutAttachedWindow];
		return;

	} else if (sender == _actionEdit && ![FPXboxHIDPrefsLoader isDefaultConfigForDevice: device]) {
		_xfade = _popup;
		NSPoint buttonPoint = NSMakePoint(NSMidX([_configButtons frame]) + 19, NSMidY([_configButtons frame]));
		_popup = [[MAAttachedWindow alloc] initWithView: _editView
				  attachedToPoint: buttonPoint
				  inWindow: [_configButtons window]
				  onSide: MAPositionTop
				  atDistance: 4];
		NSDictionary* appconf = [_appConfig objectForKey: [device identifier]];
		[_editText setStringValue: appconf != nil ? [appconf objectForKey: kNoticeConfigKey]
												  : [FPXboxHIDPrefsLoader configNameForDevice: device]];
		[_editOK setKeyEquivalent: @"\r"];
		[_editOK setEnabled: NO];
		[_popup setViewMargin: 1.0];
		[self crossFadeAttachedWindow];

	} else if (sender == _actionUndo && [self canUndo: kUndoMappings]) {
		[self performUndo: kUndoMappings];
		[self fadeOutAttachedWindow];

	} else if (sender == _actionApps) {
		_xfade = _popup;
		NSPoint buttonPoint = NSMakePoint(NSMidX([_configButtons frame]) + 19, NSMidY([_configButtons frame]));
		_popup = [[MAAttachedWindow alloc] initWithView: _appsView
				  attachedToPoint: buttonPoint
				  inWindow: [_configButtons window]
				  onSide: MAPositionTop
				  atDistance: 4];
		[_popup setViewMargin: 1.0];
		[self saveUndoState: kUndoBindings];
		[self appSetDataSource];
		[self crossFadeAttachedWindow];

	} else if (sender == _actionInfo) {
		_xfade = _popup;
		NSPoint buttonPoint = NSMakePoint(NSMidX([_configButtons frame]) + 19, NSMidY([_configButtons frame]));
		_popup = [[MAAttachedWindow alloc] initWithView: _usbView
				  attachedToPoint: buttonPoint
				  inWindow: [_configButtons window]
				  onSide: MAPositionTop
				  atDistance: 4];
		[self populateUSBInfo];
		[_usbOK setKeyEquivalent: @"\r"];
		[_popup setViewMargin: 1.0];
		[self crossFadeAttachedWindow];

	}
}


- (IBAction) configEditEnd: (id)sender
{
	if (sender == _editOK) {
		id device = [_devices objectAtIndex: [_devicePopUp indexOfSelectedItem]];
		NSDictionary* appconf = [_appConfig objectForKey: [device identifier]];
		if (appconf != nil) {
			NSString* appid = [appconf objectForKey: kNoticeAppKey];
			[FPXboxHIDPrefsLoader renameConfigNamed: [appconf objectForKey: kNoticeConfigKey]
										withNewName: [_editText stringValue]
										  forDevice: device];
			[_appConfig setObject: [NSDictionary dictionaryWithObjectsAndKeys: [_editText stringValue], kNoticeConfigKey,
																				appid, kNoticeAppKey, nil]
						   forKey: [device identifier]];
		} else {
			[FPXboxHIDPrefsLoader renameCurrentConfig: [_editText stringValue] forDevice: device];

		}

		[self buildConfigurationPopUpButton];
		_lastConfig = [_configPopUp titleOfSelectedItem];
	}
	[self fadeOutAttachedWindow];
}


- (void) controlTextDidChange: (NSNotification*)notify
{
	id object = [notify object];
	id button = (object == _createText ? _createOK : _editOK);

	NSString* text = [[object stringValue] stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceCharacterSet]];
	[button setEnabled: [text length] > 0 && ![_configPopUp itemWithTitle: text]];
}


- (NSAttributedString*) formatUSBInfo: (NSString*)info
{
	NSArray* split = [info componentsSeparatedByString: @"|"];
	NSDictionary* attrs = [NSDictionary dictionaryWithObjectsAndKeys: [NSColor disabledControlTextColor],
																	   NSForegroundColorAttributeName, nil];
	NSMutableAttributedString* str = [[NSMutableAttributedString alloc] initWithString: [split objectAtIndex: 0]];
	[str appendAttributedString: [[NSAttributedString alloc] initWithString: @"  "]];
	[str appendAttributedString: [[NSAttributedString alloc] initWithString: [split objectAtIndex: 1]
															     attributes: attrs]];
	return str;
}

- (void) populateUSBInfo
{
	FPXboxHIDDriverInterface* device = [_devices objectAtIndex: [_devicePopUp indexOfSelectedItem]];
	NSString* serial = [device serialNumber];
	[_usbVendorID setStringValue: [device vendorID]];
	[_usbProductID setStringValue: [device productID]];
	[_usbVendorName setStringValue: [device manufacturerName]];
	[_usbProductName setStringValue: [device productName]];
	[_usbVersionNumber setStringValue: [device versionNumber]];
	[_usbSerialNumber setStringValue: (serial ? serial : @"(none)")];
	[_usbSerialNumber setTextColor: (serial ? [NSColor textColor] : [NSColor disabledControlTextColor])];
	[_usbLocationID setStringValue: [NSString stringWithFormat: @"%@ @ %@", [device locationID], [device deviceAddress]]];
	[_usbBusSpeed setAttributedStringValue: [self formatUSBInfo: [device deviceSpeed]]];
	[_usbPowerReqs setAttributedStringValue: [self formatUSBInfo: [device devicePower]]];
}

#pragma mark --- App Bindings -------------------------

- (void) appSetDataSource
{
	NSString* devid = [[_devices objectAtIndex: [_devicePopUp indexOfSelectedItem]] identifier];
	[_appData setSource: [FPXboxHIDPrefsLoader allAppBindings] forDeviceID: devid withTableView: _appsTable];
	[_appsTable deselectAll: nil];
	[_appsAction setEnabled: NO forSegment: kSegmentAppsDelete];
	[_appsAction setEnabled: [self canUndo: kUndoBindings] forSegment: kSegmentAppsUndo];
	[_appsBlank setHidden: [_appData numberOfRowsInTableView: _appsTable] > 0];
	[_appsTable reloadData];
}


- (IBAction) appEditAction: (id)sender
{
	switch ([sender selectedSegment]) {
		case kSegmentAppsCreate: {
			NSApplication* sharedapp = [NSApplication sharedApplication];
			NSOpenPanel* openPanel = [NSOpenPanel openPanel];

			[openPanel setAllowsMultipleSelection: NO];
			[openPanel setCanChooseDirectories: NO];
			[openPanel setCanCreateDirectories: NO];
			[openPanel setCanChooseFiles: YES];
			[openPanel setAllowedFileTypes: @[ @"app" ]];
			[openPanel setDirectoryURL: [NSURL fileURLWithPath: @"/Applications"]];

			[sharedapp stopModal];  // stop modal for popup so sheet works, reenable modal when sheet dismissed
			[_popup setLevel: NSNormalWindowLevel];	 // make pop not "always on top" so sheet slides in over it

			OPBlock block = ^(NSInteger result) {
								if (result == NSFileHandlingPanelOKButton) {
									NSString* file = [[openPanel URL] path];
									NSString* appid = [[NSBundle bundleWithPath: file] bundleIdentifier];
									NSString* config = [_configPopUp titleOfSelectedItem];
									NSString* devid = [[_devices objectAtIndex: [_configPopUp indexOfSelectedItem]] identifier];
									[FPXboxHIDPrefsLoader setConfigNamed: config forAppID: appid andDeviceID: devid];
									[self appSetDataSource];
								}
								[openPanel close];
								[_popup setLevel: NSFloatingWindowLevel];
								[sharedapp runModalForWindow: _popup];
							};

			[openPanel beginSheetModalForWindow: [sharedapp mainWindow]
							  completionHandler: block];
			break;
		}

		case kSegmentAppsDelete: {
			if (_appSelectedID != nil) {
				NSString* devid = [[_devices objectAtIndex: [_devicePopUp indexOfSelectedItem]] identifier];
				[FPXboxHIDPrefsLoader removeAppID: _appSelectedID forDeviceID: devid];
				[self appSetDataSource];
			}
			break;
		}

		case kSegmentAppsUndo: {
			[self performUndo: kUndoBindings];
			[self appSetDataSource];
			break;
		}
	}
}


- (IBAction) appEditEnd: (id)sender
{
	_undoBindings = nil;
	[self fadeOutAttachedWindow];
}


// FPAppBindings protocol methods
- (void) setAppConfig: (NSString*)config forAppID: (NSString*)appid
{
	NSString* devid = [[_devices objectAtIndex: [_devicePopUp indexOfSelectedItem]] identifier];
	[FPXboxHIDPrefsLoader setConfigNamed: config forAppID: appid andDeviceID: devid];
	[_appsAction setEnabled: [self canUndo: kUndoBindings] forSegment: kSegmentAppsUndo];
}


- (void) appSelectionChanged: (NSString*)appid
{
	[_appsAction setEnabled: (appid != nil) forSegment: kSegmentAppsDelete];
	_appSelectedID = appid;
}


// FPAppTableView delegate method (to fix highlight to not make text bold)
- (void) tableView: (NSTableView*)tableView willDisplayCell: (id)cell forTableColumn: (NSTableColumn*)column row: (NSInteger)row
{
	uint colid = NSSwapInt(*(uint*)StringToC([column identifier]));
	if (colid == kAppTableColumnName && [tableView selectedRow] == row)
		[cell setAttributedStringValue: [[NSAttributedString alloc] initWithString: [cell stringValue] attributes: _appAttrs]];
}


#pragma mark --- Credits / Donate ----------------------

- (void) showCredits
{
	NSPoint buttonPoint = NSMakePoint(NSMidX([_btnCredits frame]), NSMidY([_btnCredits frame]));
	_popup = [[MAAttachedWindow alloc] initWithView: _creditsView
	          attachedToPoint: buttonPoint
	          inWindow: [_btnCredits window]
	          onSide: MAPositionTop
	          atDistance: 4];
	[_popup setViewMargin: 5.0];
	[self fadeInAttachedWindow];
}


- (void) showDonate
{
	NSPoint buttonPoint = NSMakePoint(NSMidX([_btnDonate frame]), NSMidY([_btnDonate frame]));
	_popup = [[MAAttachedWindow alloc] initWithView: _donateView
	          attachedToPoint: buttonPoint
	          inWindow: [_btnDonate window]
	          onSide: MAPositionTop
	          atDistance: 4];
	[_popup setViewMargin: 5.0];
	[self fadeInAttachedWindow];
}


#pragma mark --- PopUp Window Support -----------------

// Generic close window for actions that do not require extra processing
- (IBAction) closePopUpWindow: (id)sender
{
	[self fadeOutAttachedWindow];
}


- (void) crossFadeAttachedWindow
{
	[_popup setBorderColor: [NSColor windowFrameColor]];
	[_popup setBackgroundColor: [NSColor controlColor]];
	[_popup setBorderWidth: 0.0];
	[_popup setHasArrow: NSOnState];
	[_popup setArrowBaseWidth: 17];
	[_popup setArrowHeight: 12];
	[_popup setAlphaValue: 0.0];

	[[NSApplication sharedApplication] stopModal];
	[[_configButtons window] addChildWindow: _popup ordered: NSWindowAbove];
	[_popup makeKeyAndOrderFront: self];
	[[_popup animator] setAlphaValue: 1.0];
	[[_xfade animator] setAlphaValue: 0.0];
	[[NSApplication sharedApplication] runModalForWindow: _popup];
}


- (void) fadeInAttachedWindow
{
	[_popup setBorderColor: [NSColor windowFrameColor]];
	[_popup setBackgroundColor: [NSColor controlColor]];
	[_popup setBorderWidth: 0.0];
	[_popup setHasArrow: NSOnState];
	[_popup setArrowBaseWidth: 17];
	[_popup setArrowHeight: 12];
	[_popup setAlphaValue: 0.0];
	[_tabMask setAlphaValue: 0.0];
	[_tabMask setHidden: NO];

	[[_configButtons window] addChildWindow: _popup ordered: NSWindowAbove];
	[_popup makeKeyAndOrderFront: self];
	[[_popup animator] setAlphaValue: 1.0];
	[[_tabMask animator] setAlphaValue: 1.0];
	[[NSApplication sharedApplication] runModalForWindow: _popup];
}


- (void) fadeOutAttachedWindow
{
	NSTimeInterval delay = [[NSAnimationContext currentContext] duration] + 0.1;
	[self performSelector: @selector(fadeOutAttachedWindowDone) withObject: nil afterDelay: delay];
	[[_popup animator] setAlphaValue: 0.0];
	[[_tabMask animator] setAlphaValue: 0.0];
	[[NSApplication sharedApplication] stopModal];
}


- (void) fadeOutAttachedWindowDone
{
	[[_configButtons window] removeChildWindow: _popup];
	[_popup orderOut: nil];
	_popup = nil;

	if (_xfade != nil) {
		_xfade = nil;
	}
}


#pragma mark --- Undo --------------------------------

- (void) saveUndoState: (int)mode
{
	if (mode == kUndoMappings) {
		_undoMappings.InvertLxAxis				= [_leftStickInvertX state];
		_undoMappings.DeadzoneLxAxis			= [_leftStickDeadzoneX deadzoneValue];
		_undoMappings.MappingLxAxis				= [[_leftStickMenuX selectedItem] tag];

		_undoMappings.InvertLyAxis				= [_leftStickInvertY state];
		_undoMappings.DeadzoneLyAxis			= [_leftStickDeadzoneY deadzoneValue];
		_undoMappings.MappingLyAxis				= [[_leftStickMenuY selectedItem] tag];

		_undoMappings.InvertRxAxis				= [_rightStickInvertX state];
		_undoMappings.DeadzoneRxAxis			= [_rightStickDeadzoneX deadzoneValue];
		_undoMappings.MappingRxAxis				= [[_rightStickMenuX selectedItem] tag];

		_undoMappings.InvertRyAxis				= [_rightStickInvertY state];
		_undoMappings.DeadzoneRyAxis			= [_rightStickDeadzoneY deadzoneValue];
		_undoMappings.MappingRyAxis				= [[_rightStickMenuY selectedItem] tag];

		_undoMappings.MappingDPadUp				= [[_dpadUpMenu selectedItem] tag];
		_undoMappings.MappingDPadDown			= [[_dpadDownMenu selectedItem] tag];
		_undoMappings.MappingDPadLeft			= [[_dpadLeftMenu selectedItem] tag];
		_undoMappings.MappingDPadRight			= [[_dpadRightMenu selectedItem] tag];

		_undoMappings.MappingButtonStart		= [[_buttonStartMenu selectedItem] tag];
		_undoMappings.MappingButtonBack			= [[_buttonBackMenu selectedItem] tag];

		_undoMappings.MappingLeftClick			= [[_leftStickMenuBtn selectedItem] tag];
		_undoMappings.MappingRightClick			= [[_rightStickMenuBtn selectedItem] tag];

		_undoMappings.AnalogAsDigital			= [self analogDigitalMask];

		_undoMappings.ThresholdLowLeftTrigger	= [_leftTriggerLivezone intLoValue];
		_undoMappings.ThresholdHighLeftTrigger	= [_leftTriggerLivezone intHiValue];
		_undoMappings.MappingLeftTrigger		= [[_leftTriggerMenu selectedItem] tag];
		_undoMappings.AlternateLeftTrigger		= [_leftTriggerAlt state];

		_undoMappings.ThresholdLowRightTrigger  = [_rightTriggerLivezone intLoValue];
		_undoMappings.ThresholdHighRightTrigger	= [_rightTriggerLivezone intHiValue];
		_undoMappings.MappingRightTrigger		= [[_rightTriggerMenu selectedItem] tag];
		_undoMappings.AlternateRightTrigger		= [_rightTriggerAlt state];

		_undoMappings.ThresholdLowButtonGreen	= [_buttonGreenLivezone intLoValue];
		_undoMappings.ThresholdHighButtonGreen	= [_buttonGreenLivezone intHiValue];
		_undoMappings.MappingButtonGreen		= [[_buttonGreenMenu selectedItem] tag];

		_undoMappings.ThresholdLowButtonRed		= [_buttonRedLivezone intLoValue];
		_undoMappings.ThresholdHighButtonRed	= [_buttonRedLivezone intHiValue];
		_undoMappings.MappingButtonRed			= [[_buttonRedMenu selectedItem] tag];

		_undoMappings.ThresholdLowButtonBlue	= [_buttonBlueLivezone intLoValue];
		_undoMappings.ThresholdHighButtonBlue	= [_buttonBlueLivezone intHiValue];
		_undoMappings.MappingButtonBlue			= [[_buttonBlueMenu selectedItem] tag];

		_undoMappings.ThresholdLowButtonYellow	= [_buttonYellowLivezone intLoValue];
		_undoMappings.ThresholdHighButtonYellow	= [_buttonYellowLivezone intHiValue];
		_undoMappings.MappingButtonYellow		= [[_buttonYellowMenu selectedItem] tag];

		_undoMappings.ThresholdLowButtonWhite	= [_buttonWhiteLivezone intLoValue];
		_undoMappings.ThresholdHighButtonWhite	= [_buttonWhiteLivezone intHiValue];
		_undoMappings.MappingButtonWhite		= [[_buttonWhiteMenu selectedItem] tag];

		_undoMappings.ThresholdLowButtonBlack	= [_buttonBlackLivezone intLoValue];
		_undoMappings.ThresholdHighButtonBlack	= [_buttonBlackLivezone intHiValue];
		_undoMappings.MappingButtonBlack		= [[_buttonBlackMenu selectedItem] tag];

	} else if (mode == kUndoBindings) {
		_undoBindings = [FPXboxHIDPrefsLoader allAppBindings];

	}
}


- (BOOL) canUndo: (int)mode
{
	if (mode == kUndoMappings) {
		return ([_leftStickInvertX state]				!= _undoMappings.InvertLxAxis				||
				[_leftStickDeadzoneX deadzoneValue]		!= _undoMappings.DeadzoneLxAxis				||
				[[_leftStickMenuX selectedItem] tag]	!= _undoMappings.MappingLxAxis				||

				[_leftStickInvertY state]				!= _undoMappings.InvertLyAxis				||
				[_leftStickDeadzoneY deadzoneValue]		!= _undoMappings.DeadzoneLyAxis				||
				[[_leftStickMenuY selectedItem] tag]	!= _undoMappings.MappingLyAxis				||

				[_rightStickInvertX state]				!= _undoMappings.InvertRxAxis				||
				[_rightStickDeadzoneX deadzoneValue]	!= _undoMappings.DeadzoneRxAxis				||
				[[_rightStickMenuX selectedItem] tag]	!= _undoMappings.MappingRxAxis				||

				[_rightStickInvertY state]				!= _undoMappings.InvertRyAxis				||
				[_rightStickDeadzoneY deadzoneValue]	!= _undoMappings.DeadzoneRyAxis				||
				[[_rightStickMenuY selectedItem] tag]	!= _undoMappings.MappingRyAxis				||

				[[_dpadUpMenu selectedItem] tag]		!= _undoMappings.MappingDPadUp				||
				[[_dpadDownMenu selectedItem] tag]		!= _undoMappings.MappingDPadDown			||
				[[_dpadLeftMenu selectedItem] tag]		!= _undoMappings.MappingDPadLeft			||
				[[_dpadRightMenu selectedItem] tag]		!= _undoMappings.MappingDPadRight			||

				[[_buttonStartMenu selectedItem] tag]	!= _undoMappings.MappingButtonStart			||
				[[_buttonBackMenu selectedItem] tag]	!= _undoMappings.MappingButtonBack			||

				[[_leftStickMenuBtn selectedItem] tag]	!= _undoMappings.MappingLeftClick			||
				[[_rightStickMenuBtn selectedItem] tag]	!= _undoMappings.MappingRightClick			||

				[self analogDigitalMask]				!= _undoMappings.AnalogAsDigital			||

				[_leftTriggerLivezone intLoValue]		!= _undoMappings.ThresholdLowLeftTrigger	||
				[_leftTriggerLivezone intHiValue]		!= _undoMappings.ThresholdHighLeftTrigger	||
				[[_leftTriggerMenu selectedItem] tag]	!= _undoMappings.MappingLeftTrigger			||
				[_leftTriggerAlt state]					!= _undoMappings.AlternateLeftTrigger		||

				[_rightTriggerLivezone intLoValue]		!= _undoMappings.ThresholdLowRightTrigger	||
				[_rightTriggerLivezone intHiValue]		!= _undoMappings.ThresholdHighRightTrigger	||
				[[_rightTriggerMenu selectedItem] tag]	!= _undoMappings.MappingRightTrigger		||
				[_rightTriggerAlt state]				!= _undoMappings.AlternateRightTrigger		||

				[_buttonGreenLivezone intLoValue]		!= _undoMappings.ThresholdLowButtonGreen	||
				[_buttonGreenLivezone intHiValue]		!= _undoMappings.ThresholdHighButtonGreen	||
				[[_buttonGreenMenu selectedItem] tag]	!= _undoMappings.MappingButtonGreen			||

				[_buttonRedLivezone intLoValue]			!= _undoMappings.ThresholdLowButtonRed		||
				[_buttonRedLivezone intHiValue]			!= _undoMappings.ThresholdHighButtonRed		||
				[[_buttonRedMenu selectedItem] tag]		!= _undoMappings.MappingButtonRed			||

				[_buttonBlueLivezone intLoValue]		!= _undoMappings.ThresholdLowButtonBlue		||
				[_buttonBlueLivezone intHiValue]		!= _undoMappings.ThresholdHighButtonBlue	||
				[[_buttonBlueMenu selectedItem] tag]	!= _undoMappings.MappingButtonBlue			||

				[_buttonYellowLivezone intLoValue]		!= _undoMappings.ThresholdLowButtonYellow	||
				[_buttonYellowLivezone intHiValue]		!= _undoMappings.ThresholdHighButtonYellow	||
				[[_buttonYellowMenu selectedItem] tag]	!= _undoMappings.MappingButtonYellow		||

				[_buttonWhiteLivezone intLoValue]		!= _undoMappings.ThresholdLowButtonWhite	||
				[_buttonWhiteLivezone intHiValue]		!= _undoMappings.ThresholdHighButtonWhite	||
				[[_buttonWhiteMenu selectedItem] tag]	!= _undoMappings.MappingButtonWhite			||

				[_buttonBlackLivezone intLoValue]		!= _undoMappings.ThresholdLowButtonBlack	||
				[_buttonBlackLivezone intHiValue]		!= _undoMappings.ThresholdHighButtonBlack	||
				[[_buttonBlackMenu selectedItem] tag]	!= _undoMappings.MappingButtonBlack			);

	} else {
		return (_undoBindings != nil && ![_undoBindings isEqualToDictionary: [FPXboxHIDPrefsLoader allAppBindings]]);

	}
}


- (void) performUndo: (int)mode
{
	if (mode == kUndoMappings) {
		id device = [_devices objectAtIndex: [_devicePopUp indexOfSelectedItem]];

		[device setLeftStickHorizInvert: _undoMappings.InvertLxAxis];
		[device setLeftStickHorizDeadzone: _undoMappings.DeadzoneLxAxis];
		[device setLeftStickHorizMapping: _undoMappings.MappingLxAxis];

		[device setLeftStickVertInvert: _undoMappings.InvertLyAxis];
		[device setLeftStickVertDeadzone: _undoMappings.DeadzoneLyAxis];
		[device setLeftStickVertMapping: _undoMappings.MappingLyAxis];

		[device setRightStickHorizInvert: _undoMappings.InvertRxAxis];
		[device setRightStickHorizDeadzone: _undoMappings.DeadzoneRxAxis];
		[device setRightStickHorizMapping: _undoMappings.MappingRxAxis];

		[device setRightStickVertInvert: _undoMappings.InvertRyAxis];
		[device setRightStickVertDeadzone: _undoMappings.DeadzoneRyAxis];
		[device setRightStickVertMapping: _undoMappings.MappingRyAxis];

		[device setDpadUpMapping: _undoMappings.MappingDPadUp];
		[device setDpadDownMapping: _undoMappings.MappingDPadDown];
		[device setDpadLeftMapping: _undoMappings.MappingDPadLeft];
		[device setDpadRightMapping: _undoMappings.MappingDPadRight];

		[device setStartButtonMapping: _undoMappings.MappingButtonStart];
		[device setBackButtonMapping: _undoMappings.MappingButtonBack];

		[device setLeftClickMapping: _undoMappings.MappingLeftClick];
		[device setRightClickMapping: _undoMappings.MappingRightClick];

		[device setAnalogAsDigital: _undoMappings.AnalogAsDigital];

		[device setLeftTriggerLow: _undoMappings.ThresholdLowLeftTrigger andHighThreshold: _undoMappings.ThresholdHighLeftTrigger];
		[device setLeftTriggerMapping: _undoMappings.MappingLeftTrigger];
		[device setLeftTriggerAlternate: _undoMappings.AlternateLeftTrigger];

		[device setRightTriggerLow: _undoMappings.ThresholdLowRightTrigger andHighThreshold: _undoMappings.ThresholdHighRightTrigger];
		[device setRightTriggerMapping: _undoMappings.MappingRightTrigger];
		[device setRightTriggerAlternate: _undoMappings.AlternateRightTrigger];

		[device setGreenButtonLow: _undoMappings.ThresholdLowButtonGreen andHighThreshold: _undoMappings.ThresholdHighButtonGreen];
		[device setGreenButtonMapping: _undoMappings.MappingButtonGreen	];

		[device setRedButtonLow: _undoMappings.ThresholdLowButtonRed andHighThreshold: _undoMappings.ThresholdHighButtonRed];
		[device setRedButtonMapping: _undoMappings.MappingButtonRed];

		[device setBlueButtonLow: _undoMappings.ThresholdLowButtonBlue andHighThreshold: _undoMappings.ThresholdHighButtonBlue];
		[device setBlueButtonMapping: _undoMappings.MappingButtonBlue];

		[device setYellowButtonLow: _undoMappings.ThresholdLowButtonYellow andHighThreshold: _undoMappings.ThresholdHighButtonYellow];
		[device setYellowButtonMapping: _undoMappings.MappingButtonYellow];

		[device setWhiteButtonLow: _undoMappings.ThresholdLowButtonWhite andHighThreshold: _undoMappings.ThresholdHighButtonWhite];
		[device setWhiteButtonMapping: _undoMappings.MappingButtonWhite];

		[device setBlackButtonLow: _undoMappings.ThresholdLowButtonBlack andHighThreshold: _undoMappings.ThresholdHighButtonBlack];
		[device setBlackButtonMapping: _undoMappings.MappingButtonBlack];

		[self initPadOptionsWithDevice: device];

	} else if (mode == kUndoBindings) {
		[FPXboxHIDPrefsLoader setAllAppBindings: _undoBindings];
		[self appSetDataSource];

	}
}


#pragma mark --- Error Tab ----------------------------

- (void) showLargeError: (NSString*)errorMessage
{
	[_largeErrorMessage setStringValue: errorMessage];
	[_textMapping setHidden: YES];
	[_tabView selectTabViewItemAtIndex: 0];
}


#pragma mark --- Controller Tab ------------------------

- (void) initPadOptionsWithDevice: (id)device
{
	[_leftStickInvertX setState: [device leftStickHorizInvert]];
	[_leftStickDeadzoneX setDeadzoneValue: [device leftStickHorizDeadzone]];

	[_leftStickInvertY setState: [device leftStickVertInvert]];
	[_leftStickDeadzoneY setDeadzoneValue: [device leftStickVertDeadzone]];

	[_rightStickInvertX setState: [device rightStickHorizInvert]];
	[_rightStickDeadzoneX setDeadzoneValue: [device rightStickHorizDeadzone]];

	[_rightStickInvertY setState: [device rightStickVertInvert]];
	[_rightStickDeadzoneY setDeadzoneValue: [device rightStickVertDeadzone]];

	[_leftTriggerLivezone setIntegerLoValue: [device leftTriggerLowThreshold]];
	[_leftTriggerLivezone setIntegerHiValue: [device leftTriggerHighThreshold]];
	[_leftTriggerAlt setState: [device leftTriggerAlternate]];

	[_rightTriggerLivezone setIntegerLoValue: [device rightTriggerLowThreshold]];
	[_rightTriggerLivezone setIntegerHiValue: [device rightTriggerHighThreshold]];
	[_rightTriggerAlt setState: [device rightTriggerAlternate]];

	[_buttonGreenLivezone setIntegerLoValue: [device greenButtonLowThreshold]];
	[_buttonGreenLivezone setIntegerHiValue: [device greenButtonHighThreshold]];

	[_buttonRedLivezone setIntegerLoValue: [device redButtonLowThreshold]];
	[_buttonRedLivezone setIntegerHiValue: [device redButtonHighThreshold]];

	[_buttonBlueLivezone setIntegerLoValue: [device blueButtonLowThreshold]];
	[_buttonBlueLivezone setIntegerHiValue: [device blueButtonHighThreshold]];

	[_buttonYellowLivezone setIntegerLoValue: [device yellowButtonLowThreshold]];
	[_buttonYellowLivezone setIntegerHiValue: [device yellowButtonHighThreshold]];

	[_buttonBlackLivezone setIntegerLoValue: [device blackButtonLowThreshold]];
	[_buttonBlackLivezone setIntegerHiValue: [device blackButtonHighThreshold]];

	[_buttonWhiteLivezone setIntegerLoValue: [device whiteButtonLowThreshold]];
	[_buttonWhiteLivezone setIntegerHiValue: [device whiteButtonHighThreshold]];

	[self initPadPopUpButtons: device];

	[self saveUndoState: kUndoMappings];
}


- (void) initPadAxisPopUpButton: (NSPopUpButton*)control withMapping: (int)map
{
	BOOL isXbox = ([_configMenus selectedSegment] == kSegmentMenusXbox);
	NSMenu* menu = [(isXbox ? _menuAxisXbox : _menuAxisHID) copy];
	[menu setAutoenablesItems: NO];
	if (!isXbox) {
		if ([_leftTriggerAlt state] == NSOnState && [_rightTriggerAlt state] == NSOnState)
			[[menu itemAtIndex: kMenuAxisTriggers] setTitle: @"Buttons 15 + 16"];
		else if ([_leftTriggerAlt state] == NSOnState && [_rightTriggerAlt state] == NSOffState)
			[[menu itemAtIndex: kMenuAxisTriggers] setTitle: @"Btn 15 + Axis Rz"];
		else if ([_leftTriggerAlt state] == NSOffState && [_rightTriggerAlt state] == NSOnState)
			[[menu itemAtIndex: kMenuAxisTriggers] setTitle: @"Axis Z + Btn 16"];
		else
			[[menu itemAtIndex: kMenuAxisTriggers] setTitle: @"Axis Z + Rz"];
	}
	[control setMenu: menu];
	[control selectItemWithTag: map];
}


- (void) initPadButtonPopUpButton: (NSPopUpButton*)control withMapping: (int)map
{
	BOOL isXbox = ([_configMenus selectedSegment] == kSegmentMenusXbox);
	NSMenu* menu = [(isXbox ? _menuButtonXbox : _menuButtonHID) copy];
	[menu setAutoenablesItems: NO];
	if (!isXbox) {
		if ([_leftTriggerAlt state] == NSOnState)
			[[menu itemAtIndex: kMenuButtonLeftTrigger] setTitle: @"Button 15"];
		if ([_rightTriggerAlt state] == NSOnState)
			[[menu itemAtIndex: kMenuButtonRightTrigger] setTitle: @"Button 16"];
	}
	[control setMenu: menu];
	[control selectItemWithTag: map];
}


- (void) initPadPopUpButtons: (id)device
{
	[self initPadAxisPopUpButton: _leftStickMenuX withMapping: [device leftStickHorizMapping]];
	[self initPadAxisPopUpButton: _leftStickMenuY withMapping: [device leftStickVertMapping]];
	[self initPadAxisPopUpButton: _rightStickMenuX withMapping: [device rightStickHorizMapping]];
	[self initPadAxisPopUpButton: _rightStickMenuY withMapping: [device rightStickVertMapping]];
	[self checkStickMenus];

#define IS_DIGITAL(type)  (([device analogAsDigital] & BITMASK(kXboxAnalog ## type)) > 0)

	[_leftTriggerMode setIsDigital: IS_DIGITAL(LeftTrigger)];
	[self initPadButtonPopUpButton: _leftTriggerMenu withMapping: [device leftTriggerMapping]];
	[self checkAnalogDigitalMode: _leftTriggerMode withPopUpButton: _leftTriggerMenu];

	[_rightTriggerMode setIsDigital: IS_DIGITAL(RightTrigger)];
	[self initPadButtonPopUpButton: _rightTriggerMenu withMapping: [device rightTriggerMapping]];
	[self checkAnalogDigitalMode: _rightTriggerMode withPopUpButton: _rightTriggerMenu];

	[_buttonGreenMode setIsDigital: IS_DIGITAL(ButtonGreen)];
	[self initPadButtonPopUpButton: _buttonGreenMenu withMapping: [device greenButtonMapping]];
	[self checkAnalogDigitalMode: _buttonGreenMode withPopUpButton: _buttonGreenMenu];

	[_buttonRedMode setIsDigital: IS_DIGITAL(ButtonRed)];
	[self initPadButtonPopUpButton: _buttonRedMenu withMapping: [device redButtonMapping]];
	[self checkAnalogDigitalMode: _buttonRedMode withPopUpButton: _buttonRedMenu];

	[_buttonBlueMode setIsDigital: IS_DIGITAL(ButtonBlue)];
	[self initPadButtonPopUpButton: _buttonBlueMenu withMapping: [device blueButtonMapping]];
	[self checkAnalogDigitalMode: _buttonBlueMode withPopUpButton: _buttonBlueMenu];

	[_buttonYellowMode setIsDigital: IS_DIGITAL(ButtonYellow)];
	[self initPadButtonPopUpButton: _buttonYellowMenu withMapping: [device yellowButtonMapping]];
	[self checkAnalogDigitalMode: _buttonYellowMode withPopUpButton: _buttonYellowMenu];

	[_buttonWhiteMode setIsDigital: IS_DIGITAL(ButtonWhite)];
	[self initPadButtonPopUpButton: _buttonWhiteMenu withMapping: [device whiteButtonMapping]];
	[self checkAnalogDigitalMode: _buttonWhiteMode withPopUpButton: _buttonWhiteMenu];

	[_buttonBlackMode setIsDigital: IS_DIGITAL(ButtonBlack)];
	[self initPadButtonPopUpButton: _buttonBlackMenu withMapping: [device blackButtonMapping]];
	[self checkAnalogDigitalMode: _buttonBlackMode withPopUpButton: _buttonBlackMenu];

#undef IS_DIGITAL

	[self checkButtonMenus];

	[self setAnalogDigitalMax];

	[self initPadButtonPopUpButton: _dpadUpMenu withMapping: [device dpadUpMapping]];
	[self initPadButtonPopUpButton: _dpadDownMenu withMapping: [device dpadDownMapping]];
	[self initPadButtonPopUpButton: _dpadLeftMenu withMapping: [device dpadLeftMapping]];
	[self initPadButtonPopUpButton: _dpadRightMenu withMapping: [device dpadRightMapping]];

	[self initPadButtonPopUpButton: _buttonStartMenu withMapping: [device startButtonMapping]];
	[self initPadButtonPopUpButton: _buttonBackMenu withMapping: [device backButtonMapping]];

	[self initPadButtonPopUpButton: _leftStickMenuBtn withMapping: [device leftClickMapping]];
	[self initPadButtonPopUpButton: _rightStickMenuBtn withMapping: [device rightClickMapping]];
}


- (void) setAnalogDigitalMax
{
#define A2D_MAX(name, button) { \
	id name = [self analogToDigitalControlForPopUp: _ ## name ## Menu]; \
	if ([_ ## name ## Mode isLocked] == NO && [_ ## name ## Mode isDigital] == YES) \
		[name setMax: kButtonMin + 1]; \
	else \
		[name setMax: kButtonAnalogMax]; \
}

	A2D_MAX(leftTrigger, LeftTrigger);
	A2D_MAX(rightTrigger, RightTrigger);
	A2D_MAX(buttonGreen, ButtonGreen);
	A2D_MAX(buttonRed, ButtonRed);
	A2D_MAX(buttonBlue, ButtonBlue);
	A2D_MAX(buttonYellow, ButtonYellow);
	A2D_MAX(buttonWhite, ButtonWhite);
	A2D_MAX(buttonBlack, ButtonBlack);

#undef A2D_MAX
}


- (int) analogDigitalMask
{
	int mask = 0;

#define A2D_MASK(name, button) { \
	if ([_ ## name ## Mode isLocked] == NO && [_ ## name ## Mode isDigital] == YES) \
		mask |= BITMASK(kXboxAnalog ## button); \
}

	A2D_MASK(leftTrigger, LeftTrigger);
	A2D_MASK(rightTrigger, RightTrigger);
	A2D_MASK(buttonGreen, ButtonGreen);
	A2D_MASK(buttonRed, ButtonRed);
	A2D_MASK(buttonBlue, ButtonBlue);
	A2D_MASK(buttonYellow, ButtonYellow);
	A2D_MASK(buttonWhite, ButtonWhite);
	A2D_MASK(buttonBlack, ButtonBlack);

#undef A2D_MASK

	return mask;
}


- (void) initOptionsInterface
{
	NSInteger deviceIndex;
	id device;
	BOOL error = YES;

	deviceIndex = [_devicePopUp indexOfSelectedItem];
	if (deviceIndex >= 0 && deviceIndex < [_devices count]) {
		device = [_devices objectAtIndex: deviceIndex];
		if (device && [device hasOptions]) {
			if ([device deviceIsPad]) {
				[_tabView selectTabViewItemAtIndex: 1];
				[_textMapping setHidden: NO];
				[self initPadOptionsWithDevice: device];
				[device enableRawReports];
				error = NO;
			}
		}
	}
	if (error) {
		[self showLargeError: @"No Configurable Options"];
		[self disableConfigPopUpButton];
	}
}


- (void) configureInterface
{
	_devices = [FPXboxHIDDriverInterface interfaces];

	if (_devices) {
		[self buildDevicesPopUpButton];
		[self enableConfigPopUpButton];
		[self buildConfigurationPopUpButton];
		[self initOptionsInterface];
	} else {
		[self showLargeError: @"No Xbox Devices Found"];
		[self disableConfigPopUpButton];
		[self clearDevicesPopUpButton];
	}
}


- (id) analogToDigitalControlForPopUp: (NSPopUpButton*)popup
{
	switch([[popup selectedItem] tag]) {
		case kCookiePadLeftTrigger:
			return _leftTriggerView;

		case kCookiePadRightTrigger:
			return _rightTriggerView;

		case kCookiePadButtonGreen:
			return _buttonGreenView;

		case kCookiePadButtonRed:
			return _buttonRedView;

		case kCookiePadButtonBlue:
			return _buttonBlueView;

		case kCookiePadButtonYellow:
			return _buttonYellowView;

		case kCookiePadButtonWhite:
			return _buttonWhiteView;

		case kCookiePadButtonBlack:
			return _buttonBlackView;

		default:
			return nil;
	}
}


- (void) updateAnalogDigitalModeForDevice: (id)device
{
	[self setAnalogDigitalMax];
	[device setAnalogAsDigital: [self analogDigitalMask]];
}


- (BOOL) checkAnalogDigitalMode: (FPAnalogDigitalButton*)control withPopUpButton: (NSPopUpButton*)button
{
	NSInteger item = [button indexOfSelectedItem];
	if (item >= kMenuButtonDPadUp && item <= kMenuButtonRightClick) {
		[control setIsDigital: YES];
		[control setLocked: YES];
		[control setToolTip: @"Digital Only"];

	} else {
		[control setLocked: NO];
		[control setToolTip: @"Analog / Digital"];

	}

	[control setNeedsDisplay];

	return YES;     // padOptionChanged:withControl: will call updateAnalogDigitalModeForDevice:
}


- (void) checkButtonMenus
{
	NSInteger tag;

	for (int i = kMenuButtonSeparator1; i < kMenuButtonSeparator2; i++) {
		[[_buttonGreenMenu itemAtIndex: i] setEnabled: YES];
		[[_buttonRedMenu itemAtIndex: i] setEnabled: YES];
		[[_buttonBlueMenu itemAtIndex: i] setEnabled: YES];
		[[_buttonYellowMenu itemAtIndex: i] setEnabled: YES];
		[[_buttonWhiteMenu itemAtIndex: i] setEnabled: YES];
		[[_buttonBlackMenu itemAtIndex: i] setEnabled: YES];
		[[_leftTriggerMenu itemAtIndex: i] setEnabled: YES];
		[[_rightTriggerMenu itemAtIndex: i] setEnabled: YES];
	}

	for (int i = kMenuButtonSeparator3; i < kMenuButtonCount; i++) {
		[[_buttonGreenMenu itemAtIndex: i] setEnabled: YES];
		[[_buttonRedMenu itemAtIndex: i] setEnabled: YES];
		[[_buttonBlueMenu itemAtIndex: i] setEnabled: YES];
		[[_buttonYellowMenu itemAtIndex: i] setEnabled: YES];
		[[_buttonWhiteMenu itemAtIndex: i] setEnabled: YES];
		[[_buttonBlackMenu itemAtIndex: i] setEnabled: YES];
		[[_leftTriggerMenu itemAtIndex: i] setEnabled: YES];
		[[_rightTriggerMenu itemAtIndex: i] setEnabled: YES];
	}

	tag = [[_buttonGreenMenu selectedItem] tag];
	if (tag != kMenuButtonDisabled) {
		[[[_buttonRedMenu menu] itemWithTag: tag] setEnabled: NO];
		[[[_buttonBlueMenu menu] itemWithTag: tag] setEnabled: NO];
		[[[_buttonYellowMenu menu] itemWithTag: tag] setEnabled: NO];
		[[[_buttonWhiteMenu menu] itemWithTag: tag] setEnabled: NO];
		[[[_buttonBlackMenu menu] itemWithTag: tag] setEnabled: NO];
		[[[_leftTriggerMenu menu] itemWithTag: tag] setEnabled: NO];
		[[[_rightTriggerMenu menu] itemWithTag: tag] setEnabled: NO];
	}

	tag = [[_buttonRedMenu selectedItem] tag];
	if (tag != kMenuButtonDisabled) {
		[[[_buttonGreenMenu menu] itemWithTag: tag] setEnabled: NO];
		[[[_buttonBlueMenu menu] itemWithTag: tag] setEnabled: NO];
		[[[_buttonYellowMenu menu] itemWithTag: tag] setEnabled: NO];
		[[[_buttonWhiteMenu menu] itemWithTag: tag] setEnabled: NO];
		[[[_buttonBlackMenu menu] itemWithTag: tag] setEnabled: NO];
		[[[_leftTriggerMenu menu] itemWithTag: tag] setEnabled: NO];
		[[[_rightTriggerMenu menu] itemWithTag: tag] setEnabled: NO];
	}

	tag = [[_buttonBlueMenu selectedItem] tag];
	if (tag != kMenuButtonDisabled) {
		[[[_buttonGreenMenu menu] itemWithTag: tag] setEnabled: NO];
		[[[_buttonRedMenu menu] itemWithTag: tag] setEnabled: NO];
		[[[_buttonYellowMenu menu] itemWithTag: tag] setEnabled: NO];
		[[[_buttonWhiteMenu menu] itemWithTag: tag] setEnabled: NO];
		[[[_buttonBlackMenu menu] itemWithTag: tag] setEnabled: NO];
		[[[_leftTriggerMenu menu] itemWithTag: tag] setEnabled: NO];
		[[[_rightTriggerMenu menu] itemWithTag: tag] setEnabled: NO];
	}

	tag = [[_buttonYellowMenu selectedItem] tag];
	if (tag != kMenuButtonDisabled) {
		[[[_buttonGreenMenu menu] itemWithTag: tag] setEnabled: NO];
		[[[_buttonRedMenu menu] itemWithTag: tag] setEnabled: NO];
		[[[_buttonBlueMenu menu] itemWithTag: tag] setEnabled: NO];
		[[[_buttonWhiteMenu menu] itemWithTag: tag] setEnabled: NO];
		[[[_buttonBlackMenu menu] itemWithTag: tag] setEnabled: NO];
		[[[_leftTriggerMenu menu] itemWithTag: tag] setEnabled: NO];
		[[[_rightTriggerMenu menu] itemWithTag: tag] setEnabled: NO];
	}

	tag = [[_buttonWhiteMenu selectedItem] tag];
	if (tag != kMenuButtonDisabled) {
		[[[_buttonGreenMenu menu] itemWithTag: tag] setEnabled: NO];
		[[[_buttonRedMenu menu] itemWithTag: tag] setEnabled: NO];
		[[[_buttonBlueMenu menu] itemWithTag: tag] setEnabled: NO];
		[[[_buttonYellowMenu menu] itemWithTag: tag] setEnabled: NO];
		[[[_buttonBlackMenu menu] itemWithTag: tag] setEnabled: NO];
		[[[_leftTriggerMenu menu] itemWithTag: tag] setEnabled: NO];
		[[[_rightTriggerMenu menu] itemWithTag: tag] setEnabled: NO];
	}

	tag = [[_buttonBlackMenu selectedItem] tag];
	if (tag != kMenuButtonDisabled) {
		[[[_buttonGreenMenu menu] itemWithTag: tag] setEnabled: NO];
		[[[_buttonRedMenu menu] itemWithTag: tag] setEnabled: NO];
		[[[_buttonBlueMenu menu] itemWithTag: tag] setEnabled: NO];
		[[[_buttonYellowMenu menu] itemWithTag: tag] setEnabled: NO];
		[[[_buttonWhiteMenu menu] itemWithTag: tag] setEnabled: NO];
		[[[_leftTriggerMenu menu] itemWithTag: tag] setEnabled: NO];
		[[[_rightTriggerMenu menu] itemWithTag: tag] setEnabled: NO];
	}

	tag = [[_leftTriggerMenu selectedItem] tag];
	if (tag != kMenuButtonDisabled) {
		[[[_buttonGreenMenu menu] itemWithTag: tag] setEnabled: NO];
		[[[_buttonRedMenu menu] itemWithTag: tag] setEnabled: NO];
		[[[_buttonBlueMenu menu] itemWithTag: tag] setEnabled: NO];
		[[[_buttonYellowMenu menu] itemWithTag: tag] setEnabled: NO];
		[[[_buttonWhiteMenu menu] itemWithTag: tag] setEnabled: NO];
		[[[_buttonBlackMenu menu] itemWithTag: tag] setEnabled: NO];
		[[[_rightTriggerMenu menu] itemWithTag: tag] setEnabled: NO];
	}

	tag = [[_rightTriggerMenu selectedItem] tag];
	if (tag != kMenuButtonDisabled) {
		[[[_buttonGreenMenu menu] itemWithTag: tag] setEnabled: NO];
		[[[_buttonRedMenu menu] itemWithTag: tag] setEnabled: NO];
		[[[_buttonBlueMenu menu] itemWithTag: tag] setEnabled: NO];
		[[[_buttonYellowMenu menu] itemWithTag: tag] setEnabled: NO];
		[[[_buttonWhiteMenu menu] itemWithTag: tag] setEnabled: NO];
		[[[_buttonBlackMenu menu] itemWithTag: tag] setEnabled: NO];
		[[[_leftTriggerMenu menu] itemWithTag: tag] setEnabled: NO];
	}
}


- (void) checkStickMenus
{
	NSInteger tag;

	for (int i = kMenuAxisSeparator1; i < kMenuAxisCount; i++) {
		[[_leftStickMenuX itemAtIndex: i] setEnabled: YES];
		[[_leftStickMenuY itemAtIndex: i] setEnabled: YES];
		[[_rightStickMenuX itemAtIndex: i] setEnabled: YES];
		[[_rightStickMenuY itemAtIndex: i] setEnabled: YES];
	}

	tag = [[_leftStickMenuX selectedItem] tag];
	if (tag != kMenuAxisDisabled) {
		[[[_leftStickMenuY menu] itemWithTag: tag] setEnabled: NO];
		[[[_rightStickMenuX menu] itemWithTag: tag] setEnabled: NO];
		[[[_rightStickMenuY menu] itemWithTag: tag] setEnabled: NO];
	}

	tag = [[_leftStickMenuY selectedItem] tag];
	if (tag != kMenuAxisDisabled) {
		[[[_leftStickMenuX menu] itemWithTag: tag] setEnabled: NO];
		[[[_rightStickMenuX menu] itemWithTag: tag] setEnabled: NO];
		[[[_rightStickMenuY menu] itemWithTag: tag] setEnabled: NO];
	}

	tag = [[_rightStickMenuX selectedItem] tag];
	if (tag != kMenuAxisDisabled) {
		[[[_leftStickMenuX menu] itemWithTag: tag] setEnabled: NO];
		[[[_leftStickMenuY menu] itemWithTag: tag] setEnabled: NO];
		[[[_rightStickMenuY menu] itemWithTag: tag] setEnabled: NO];
	}

	tag = [[_rightStickMenuY selectedItem] tag];
	if (tag != kMenuAxisDisabled) {
		[[[_leftStickMenuX menu] itemWithTag: tag] setEnabled: NO];
		[[[_leftStickMenuY menu] itemWithTag: tag] setEnabled: NO];
		[[[_rightStickMenuX menu] itemWithTag: tag] setEnabled: NO];
	}

	[self checkStickAlerts];
}


- (void) checkStickAlerts
{
	[_leftStickAlertX setHidden: !([_leftStickMenuX indexOfSelectedItem] > kMenuAxisSeparator2 &&
								   [_leftStickDeadzoneX deadzoneValue] < kStickAsButtonAlert)];

	[_leftStickAlertY setHidden: !([_leftStickMenuY indexOfSelectedItem] > kMenuAxisSeparator2 &&
								   [_leftStickDeadzoneY deadzoneValue] < kStickAsButtonAlert)];

	[_rightStickAlertX setHidden: !([_rightStickMenuX indexOfSelectedItem] > kMenuAxisSeparator2 &&
								    [_rightStickDeadzoneX deadzoneValue] < kStickAsButtonAlert)];

	[_rightStickAlertY setHidden: !([_rightStickMenuY indexOfSelectedItem] > kMenuAxisSeparator2 &&
								    [_rightStickDeadzoneY deadzoneValue] < kStickAsButtonAlert)];
}


- (void) padOptionChanged: (id)device withControl: (id)control
{
	BOOL updateAD = NO;

	// left stick
	if (control == _leftStickInvertX) {
		[device setLeftStickHorizInvert: [_leftStickInvertX state]];

	} else if (control == _leftStickDeadzoneX) {
		[device setLeftStickHorizDeadzone: [_leftStickDeadzoneX deadzoneValue]];
		[self checkStickAlerts];

	} else if (control == _leftStickMenuX) {
		[device setLeftStickHorizMapping: (int)[[_leftStickMenuX selectedItem] tag]];
		[self checkStickMenus];

	} else if (control == _leftStickInvertY) {
		[device setLeftStickVertInvert: [_leftStickInvertY state]];

	} else if (control == _leftStickDeadzoneY) {
		[device setLeftStickVertDeadzone: [_leftStickDeadzoneY deadzoneValue]];
		[self checkStickAlerts];

	} else if (control == _leftStickMenuY) {
		[device setLeftStickVertMapping: (int)[[_leftStickMenuY selectedItem] tag]];
		[self checkStickMenus];

	// right stick
	} else if (control == _rightStickInvertX) {
		[device setRightStickHorizInvert: [_rightStickInvertX state]];

	} else if (control == _rightStickDeadzoneX) {
		[device setRightStickHorizDeadzone: [_rightStickDeadzoneX deadzoneValue]];
		[self checkStickAlerts];

	} else if (control == _rightStickMenuX) {
		[device setRightStickHorizMapping: (int)[[_rightStickMenuX selectedItem] tag]];
		[self checkStickMenus];

	} else if (control == _rightStickInvertY) {
		[device setRightStickVertInvert: [_rightStickInvertY state]];

	} else if (control == _rightStickDeadzoneY) {
		[device setRightStickVertDeadzone: [_rightStickDeadzoneY deadzoneValue]];
		[self checkStickAlerts];

	} else if (control == _rightStickMenuY) {
		[device setRightStickVertMapping: (int)[[_rightStickMenuY selectedItem] tag]];
		[self checkStickMenus];

	// triggers
	} else if (control == _leftTriggerLivezone) {
		[device setLeftTriggerLow: [_leftTriggerLivezone doubleLoValue] andHighThreshold: [_leftTriggerLivezone doubleHiValue]];

	} else if (control == _leftTriggerMenu) {
		[device setLeftTriggerMapping: (int)[[_leftTriggerMenu selectedItem] tag]];
		updateAD = [self checkAnalogDigitalMode: _leftTriggerMode withPopUpButton: _leftTriggerMenu];

	} else if (control == _leftTriggerAlt) {
		[device setLeftTriggerAlternate: [_leftTriggerAlt state]];
		[self initPadPopUpButtons: device];

	} else if (control == _rightTriggerLivezone) {
		[device setRightTriggerLow: [_rightTriggerLivezone doubleLoValue] andHighThreshold: [_rightTriggerLivezone doubleHiValue]];

	} else if (control == _rightTriggerMenu) {
		[device setRightTriggerMapping: (int)[[_rightTriggerMenu selectedItem] tag]];
		updateAD = [self checkAnalogDigitalMode: _rightTriggerMode withPopUpButton: _rightTriggerMenu];

	} else if (control == _rightTriggerAlt) {
		[device setRightTriggerAlternate: [_rightTriggerAlt state]];
		[self initPadPopUpButtons: device];

	// analog buttons
	} else if (control == _buttonGreenLivezone) {
		[device setGreenButtonLow: [_buttonGreenLivezone doubleLoValue] andHighThreshold: [_buttonGreenLivezone doubleHiValue]];

	} else if (control == _buttonGreenMenu) {
		[device setGreenButtonMapping: (int)[[_buttonGreenMenu selectedItem] tag]];
		updateAD = [self checkAnalogDigitalMode: _buttonGreenMode withPopUpButton: _buttonGreenMenu];

	} else if (control == _buttonRedLivezone) {
		[device setRedButtonLow: [_buttonRedLivezone doubleLoValue] andHighThreshold: [_buttonRedLivezone doubleHiValue]];

	} else if (control == _buttonRedMenu) {
		[device setRedButtonMapping: (int)[[_buttonRedMenu selectedItem] tag]];
		updateAD = [self checkAnalogDigitalMode: _buttonRedMode withPopUpButton: _buttonRedMenu];

	} else if (control == _buttonBlueLivezone) {
		[device setBlueButtonLow: [_buttonBlueLivezone doubleLoValue] andHighThreshold: [_buttonBlueLivezone doubleHiValue]];

	} else if (control == _buttonBlueMenu) {
		[device setBlueButtonMapping: (int)[[_buttonBlueMenu selectedItem] tag]];
		updateAD = [self checkAnalogDigitalMode: _buttonBlueMode withPopUpButton: _buttonBlueMenu];

	} else if (control == _buttonYellowLivezone) {
		[device setYellowButtonLow: [_buttonYellowLivezone doubleLoValue] andHighThreshold: [_buttonYellowLivezone doubleHiValue]];

	} else if (control == _buttonYellowMenu) {
		[device setYellowButtonMapping: (int)[[_buttonYellowMenu selectedItem] tag]];
		updateAD = [self checkAnalogDigitalMode: _buttonYellowMode withPopUpButton: _buttonYellowMenu];

	} else if (control == _buttonWhiteLivezone) {
		[device setWhiteButtonLow: [_buttonWhiteLivezone doubleLoValue] andHighThreshold: [_buttonWhiteLivezone doubleHiValue]];

	} else if (control == _buttonWhiteMenu) {
		[device setWhiteButtonMapping: (int)[[_buttonWhiteMenu selectedItem] tag]];
		updateAD = [self checkAnalogDigitalMode: _buttonWhiteMode withPopUpButton: _buttonWhiteMenu];

	} else if (control == _buttonBlackLivezone) {
		[device setBlackButtonLow: [_buttonBlackLivezone doubleLoValue] andHighThreshold: [_buttonBlackLivezone doubleHiValue]];

	} else if (control == _buttonBlackMenu) {
		[device setBlackButtonMapping: (int)[[_buttonBlackMenu selectedItem] tag]];
		updateAD = [self checkAnalogDigitalMode: _buttonBlackMode withPopUpButton: _buttonBlackMenu];

	// digital buttons
	} else if (control == _dpadUpMenu) {
		[device setDpadUpMapping: (int)[[_dpadUpMenu selectedItem] tag]];

	} else if (control == _dpadDownMenu) {
		[device setDpadDownMapping: (int)[[_dpadDownMenu selectedItem] tag]];

	} else if (control == _dpadLeftMenu) {
		[device setDpadLeftMapping: (int)[[_dpadLeftMenu selectedItem] tag]];

	} else if (control == _dpadRightMenu) {
		[device setDpadRightMapping: (int)[[_dpadRightMenu selectedItem] tag]];

	} else if (control == _leftStickMenuBtn) {
		[device setLeftClickMapping: (int)[[_leftStickMenuBtn selectedItem] tag]];

	} else if (control == _rightStickMenuBtn) {
		[device setRightClickMapping: (int)[[_rightStickMenuBtn selectedItem] tag]];

	} else if (control == _buttonStartMenu) {
		[device setStartButtonMapping: (int)[[_buttonStartMenu selectedItem] tag]];

	} else if (control == _buttonBackMenu) {
		[device setBackButtonMapping: (int)[[_buttonBackMenu selectedItem] tag]];

	}

	// analog as digital buttons
	if (updateAD || control == _leftTriggerMode || control == _rightTriggerMode ||
	    control == _buttonGreenMode || control == _buttonRedMode    ||
	    control == _buttonBlueMode  || control == _buttonYellowMode ||
	    control == _buttonWhiteMode || control == _buttonBlackMode) {
		if (updateAD == NO) [control toggleMode];
		[self updateAnalogDigitalModeForDevice: device];
		[self checkButtonMenus];
	}
}


#pragma mark --- HID Interface -------------------------

- (void) hidDeviceInputPoller: (id)object
{
	FPXboxHID_JoystickUpdate(self);
}


- (void) hidUpdateElement: (int)deviceIndex cookie: (int)cookie value: (SInt32)value
{
	if (deviceIndex == [_devicePopUp indexOfSelectedItem] && [[_devices objectAtIndex: deviceIndex] deviceIsPad]) {
		switch (cookie) {
		case kCookiePadDPadUp:
			[(FPDPadView*)_dPadView setValue: value forDirection: kXboxDigitalDPadUp];
			break;

		case kCookiePadDPadDown:
			[(FPDPadView*)_dPadView setValue: value forDirection: kXboxDigitalDPadDown];
			break;

		case kCookiePadDPadLeft:
			[(FPDPadView*)_dPadView setValue: value forDirection: kXboxDigitalDPadLeft];
			break;

		case kCookiePadDPadRight:
			[(FPDPadView*)_dPadView setValue: value forDirection: kXboxDigitalDPadRight];
			break;

		case kCookiePadButtonStart:
			[(FPButtonView*)_buttonStartView setValue: value];
			break;

		case kCookiePadButtonBack:
			[(FPButtonView*)_buttonBackView setValue: value];
			break;

		case kCookiePadLeftClick:
			[(FPAxisPairView*)_leftStickView setPressed: value];
			break;

		case kCookiePadRightClick:
			[(FPAxisPairView*)_rightStickView setPressed: value];
			break;

		case kCookiePadButtonGreen:
			[(FPButtonView*)_buttonGreenView setValue: value];
			break;

		case kCookiePadButtonRed:
			[(FPButtonView*)_buttonRedView setValue: value];
			break;

		case kCookiePadButtonBlue:
			[(FPButtonView*)_buttonBlueView setValue: value];
			break;

		case kCookiePadButtonYellow:
			[(FPButtonView*)_buttonYellowView setValue: value];
			break;

		case kCookiePadButtonBlack:
			[(FPButtonView*)_buttonBlackView setValue: value];
			break;

		case kCookiePadButtonWhite:
			[(FPButtonView*)_buttonWhiteView setValue: value];
			break;

		case kCookiePadLeftTrigger:
			[(FPTriggerView*)_leftTriggerView setValue: value];
			break;

		case kCookiePadRightTrigger:
			[(FPTriggerView*)_rightTriggerView setValue: value];
			break;

		case kCookiePadLxAxis:
			[(FPAxisPairView*)_leftStickView setX: value];
			break;

		case kCookiePadLyAxis:
			[(FPAxisPairView*)_leftStickView setY: value];
			break;

		case kCookiePadRxAxis:
			[(FPAxisPairView*)_rightStickView setX: value];
			break;

		case kCookiePadRyAxis:
			[(FPAxisPairView*)_rightStickView setY: value];
			break;
		}
	}
}


#define kStickValueToLive(v)	(((v) + kStickRange) / (kStickRange * 2.0))

- (void) updateRawReport
{
	FPXboxHIDDriverInterface* device = [_devices objectAtIndex: [_devicePopUp indexOfSelectedItem]];
	if (device && [device deviceIsPad] && [device rawReportsActive]) {
		SInt16 axis;

		[device copyRawReport: &_rawReport];

		[(SMDoubleSlider*)_buttonGreenLivezone setLiveValue: (_rawReport.a / kButtonAnalogMaxF)];
		[(SMDoubleSlider*)_buttonRedLivezone setLiveValue: (_rawReport.b / kButtonAnalogMaxF)];
		[(SMDoubleSlider*)_buttonBlueLivezone setLiveValue: (_rawReport.x / kButtonAnalogMaxF)];
		[(SMDoubleSlider*)_buttonYellowLivezone setLiveValue: (_rawReport.y / kButtonAnalogMaxF)];
		[(SMDoubleSlider*)_buttonBlackLivezone setLiveValue: (_rawReport.black / kButtonAnalogMaxF)];
		[(SMDoubleSlider*)_buttonWhiteLivezone setLiveValue: (_rawReport.white / kButtonAnalogMaxF)];
		[(SMDoubleSlider*)_leftTriggerLivezone setLiveValue: (_rawReport.lt / kButtonAnalogMaxF)];
		[(SMDoubleSlider*)_rightTriggerLivezone setLiveValue: (_rawReport.rt / kButtonAnalogMaxF)];

		axis = kStickHighLowToValue(_rawReport.lxhi, _rawReport.lxlo);
		[_leftStickDeadzoneX setLiveValue: kStickValueToLive(axis)];
		[_leftStickView setLiveX: axis];

		axis = kStickHighLowToValue(_rawReport.lyhi, _rawReport.lylo);
		[_leftStickDeadzoneY setLiveValue: kStickValueToLive(axis)];
		[_leftStickView setLiveY: axis];

		axis = kStickHighLowToValue(_rawReport.rxhi, _rawReport.rxlo);
		[_rightStickDeadzoneX setLiveValue: kStickValueToLive(axis)];
		[_rightStickView setLiveX: axis];

		axis = kStickHighLowToValue(_rawReport.ryhi, _rawReport.rylo);
		[_rightStickDeadzoneY setLiveValue: kStickValueToLive(axis)];
		[_rightStickView setLiveY: axis];
	}
}


- (void) startHIDDeviceInput
{
	FPXboxHID_JoystickInit();
	_timer = [NSTimer scheduledTimerWithTimeInterval: 1.0/30.0 target: self selector: @selector(hidDeviceInputPoller:)
	          userInfo: nil repeats: YES];
}


- (void) stopHIDDeviceInput
{
	[_timer invalidate];
	FPXboxHID_JoystickQuit();
}


- (void) devicesPluggedOrUnplugged
{
	[self configureInterface];
	[self stopHIDDeviceInput];
	[self startHIDDeviceInput];
}


// FPDeviceNotifer protocol method
- (void) devicesPluggedIn
{
	[self devicesPluggedOrUnplugged];
}


// FPDeviceNotifer protocol method
- (void) devicesUnplugged
{
	[self devicesPluggedOrUnplugged];
}


- (void) registerForNotifications
{
	// get notified when config changes out from under us (or when we change it ourselves)
	_notifier = [FPXboxHIDNotifier notifierWithDelegate: self];
	[[NSDistributedNotificationCenter defaultCenter] addObserver: self
														selector: @selector(deviceConfigDidChange:)
															name: kFPXboxHIDDeviceConfigurationDidChangeNotification
														  object: kFPDistributedNotificationsObject];
}


- (void) deregisterForNotifications
{
	if (_notifier) {
		_notifier = nil;
	}
	[[NSDistributedNotificationCenter defaultCenter] removeObserver: self
	 name: kFPXboxHIDDeviceConfigurationDidChangeNotification
	 object: kFPDistributedNotificationsObject];
}


- (void) deviceConfigDidChange: (id)notify
{
	NSDictionary* appconf = [notify userInfo];
	if ([appconf objectForKey: kNoticeAppKey])
		[_appConfig setObject: appconf forKey: [appconf objectForKey: kNoticeDeviceKey]];
	else
		[_appConfig removeObjectForKey: [appconf objectForKey: kNoticeDeviceKey]];
	_lastConfig = [_appConfig objectForKey: kNoticeConfigKey];
	[self buildConfigurationPopUpButton];
	[self configureInterface];
}


#pragma mark --- Actions ------------------------------

- (IBAction) selectDevice: (id)sender
{
	[self enableConfigPopUpButton];
	[self buildConfigurationPopUpButton];
	[self initOptionsInterface];
	[self saveLastDeviceIdentifier];
	[self appSetDataSource];
}


- (IBAction) changePadOption: (id)sender
{
	id device = [_devices objectAtIndex: [_devicePopUp indexOfSelectedItem]];
	NSDictionary* appconf = [_appConfig objectForKey: [device identifier]];
	if ([device deviceIsPad])
		[self padOptionChanged: device withControl: sender];
	if (appconf != nil)
		[FPXboxHIDPrefsLoader saveConfigForDevice: device withConfigName: [appconf objectForKey: kNoticeConfigKey]];
	else
		[FPXboxHIDPrefsLoader saveConfigForDevice: device];
}


- (IBAction) clickConfigSegment: (id)sender
{
	switch ([sender selectedSegment]) {
		case kSegmentConfigCreate:
			[self configCreate];
			break;
		case kSegmentConfigDelete:
			[self configDelete];
			break;
		case kSegmentConfigPopUp:
			[self configActions];
			break;
	}
}


- (IBAction) clickMenuSegment: (id)sender
{
	[self initPadPopUpButtons: [_devices objectAtIndex: [_devicePopUp indexOfSelectedItem]]];
}


- (IBAction) clickCredits: (id)sender
{
	[self showCredits];
}


- (IBAction) clickDonate: (id)sender
{
	[self showDonate];
}


- (IBAction) selectConfig: (id)sender
{
	NSString* configName = [_configPopUp titleOfSelectedItem];
	if ([configName isEqualToString: _lastConfig] == NO) {
		id device = [_devices objectAtIndex: [_devicePopUp indexOfSelectedItem]];
		NSDictionary* appconf = [_appConfig objectForKey: [device identifier]];
		_lastConfig = [_configPopUp titleOfSelectedItem];

		// first save the current config
		if (appconf != nil) {
			[FPXboxHIDPrefsLoader saveConfigForDevice: device withConfigName: [appconf objectForKey: kNoticeConfigKey]];
			[_configPopUp clearAppConfig];
			[_appConfig removeObjectForKey: [device identifier]];
		} else {
			[FPXboxHIDPrefsLoader saveConfigForDevice: device];
		}

		// now load the new config
		[FPXboxHIDPrefsLoader loadConfigForDevice: device withName: configName];

		// GUI update is handled in deviceConfigDidChange:
	}
}

@end
