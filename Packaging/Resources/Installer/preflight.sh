#!/bin/sh

syspref=0

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

	PROCESS="System Preferences"
	syspref=$(ps aux | grep -i "$PROCESS" | grep -v grep | wc -l)
	if [ $syspref -gt 0 ]; then
		killall "$PROCESS"
	fi
fi


echo "Checking if upgrading"
if [ -d "/Library/PreferencePanes/SylpHID.prefPane" ]; then
	echo "Removing previous version"

	sudo -u $USER launchctl stop com.fizzypopstudios.SylpHIDDaemon
	sudo -u $USER launchctl unload /Library/LaunchAgents/com.fizzypopstudios.SylpHIDDaemon.plist
	rm /Library/LaunchAgents/com.fizzypopstudios.SylpHIDDaemon.plist

	rm -rf "/Library/PreferencePanes/SylpHID.prefPane"

	if [ -d "/System/Library/Extensions/SylpHID.kext" ]; then
		kextunload "/System/Library/Extensions/SylpHID.kext"
		rm -rf "/System/Library/Extensions/SylpHID.kext"

	elif [ -d "/Library/Extensions/SylpHID.kext" ]; then
		kextunload "/Library/Extensions/SylpHID.kext"
		rm -rf "/Library/Extensions/SylpHID.kext"

	fi

	if [ $syspref -eq 0 ]; then
		PROCESS="System Preferences"
		syspref=$(ps aux | grep -i "$PROCESS" | grep -v grep | wc -l)
		if [ $syspref -gt 0 ]; then
			killall "$PROCESS"
		fi
	fi
fi


if [ $syspref -gt 0 ]; then
	touch /tmp/sylphid.sysprefs
fi
