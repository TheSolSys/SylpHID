#!/bin/sh

echo "Checking for 'xhd' driver"
if [ -d /System/Library/Extensions/DWXboxHIDDriver.kext ]; then
	echo "Removing old 'xhd' driver"
	PROCESS="XboxHIDDaemon"
	number=$(ps aux | grep -i $PROCESS | grep -v grep | wc -l)
	if [ $number -gt 0 ]; then
		killall $PROCESS
	fi

	kextunload /System/Library/Extensions/DWXBoxHIDDriver.kext

	sudo -u $USER xhdLoginItem -remove /Library/PreferencePanes/XboxHIDPrefsPane.prefPane/Contents/Resources/XboxHIDDaemonLauncher.app
	xhdLoginItem -remove -g /Library/PreferencePanes/XboxHIDPrefsPane.prefPane/Contents/Resources/XboxHIDDaemonLauncher.app

	sudo -u $USER xhdLoginItem -remove ~/Library/PreferencePanes/XboxHIDPrefsPane.prefPane/Contents/Resources/XboxHIDDaemonLauncher.app
	xhdLoginItem -remove -g ~/Library/PreferencePanes/XboxHIDPrefsPane.prefPane/Contents/Resources/XboxHIDDaemonLauncher.app

	sudo -u $USER defaults delete org.walisser.XboxHIDDriver
	rm -f /Users/*/Library/Preferences/org.walisser.XboxHIDDriver.plist
	rm -rf /Users/*/Library/PreferencePanes/XboxHIDPrefsPane.prefPane
	rm -rf /Library/PreferencePanes/XboxHIDPrefsPane.prefPane
	rm -rf /System/Library/Extensions/DWXboxHIDDriver.kext
	rm -rf /private/var/db/receipts/org.walisser.driver.DWXBoxHIDDriver.bom
	rm -rf /private/var/db/receipts/org.walisser.driver.DWXBoxHIDDriver.plist

	echo "Relaunch System Preferences"
	PROCESS="System Preferences"
	number=$(ps aux | grep -i "$PROCESS" | grep -v grep | wc -l)
	if [ $number -gt 0 ]
		then
			killall "$PROCESS" && open -g "/Applications/System Preferences.app"
	fi
fi


echo "Checking if upgrading"
if [ -d "/Library/PreferencePanes/Xbox HID.prefPane" ]; then
	echo "Removing previous version"

	sudo -u $USER launchctl stop com.fizzypopstudios.XboxHIDDaemon
	sudo -u $USER launchctl unload /Library/LaunchAgents/com.fizzypopstudios.XboxHIDDaemon.plist
	rm /Library/LaunchAgents/com.fizzypopstudios.XboxHIDDaemon.plist

	if [ -d "/System/Library/Extensions/Xbox HID.kext" ]; then
		kextunload "/System/Library/Extensions/Xbox HID.kext"
		rm -rf "/System/Library/Extensions/Xbox HID.kext"

	elif [ -d "/Library/Extensions/Xbox HID.kext" ]; then
		kextunload "/Library/Extensions/Xbox HID.kext"
		rm -rf "/Library/Extensions/Xbox HID.kext"

	fi
fi
