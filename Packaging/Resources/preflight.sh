#!/bin/sh

echo "Checking for 'xhd' Driver"
if [ -d /System/Library/Extensions/DWXboxHIDDriver.kext ]; then
	echo "Removing old 'xhd' Driver"
	PROCESS="XboxHIDDaemon"
	number=$(ps aux | grep -i $PROCESS | grep -v grep | wc -l)
	if [ $number -gt 0 ]; then
		sudo killall $PROCESS
	fi

	sudo kextunload /System/Library/Extensions/DWXBoxHIDDriver.kext

	sudo -u $USER xhdLoginItem -remove /Library/PreferencePanes/XboxHIDPrefsPane.prefPane/Contents/Resources/XboxHIDDaemonLauncher.app
	sudo xhdLoginItem -remove -g /Library/PreferencePanes/XboxHIDPrefsPane.prefPane/Contents/Resources/XboxHIDDaemonLauncher.app
	sudo -u $USER xhdLoginItem -remove ~/Library/PreferencePanes/XboxHIDPrefsPane.prefPane/Contents/Resources/XboxHIDDaemonLauncher.app
	sudo xhdLoginItem -remove -g ~/Library/PreferencePanes/XboxHIDPrefsPane.prefPane/Contents/Resources/XboxHIDDaemonLauncher.app

	rm -rf ~/Library/Preferences/org.walisser.XboxHIDDriver.plist
	rm -rf ~/Library/PreferencePanes/XboxHIDPrefsPane.prefPane
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
if [ -d /Library/PreferencePanes/XboxHIDPrefPane.prefPane]; then
	echo "Removing previous version"

	if [ -d /System/Library/Extensions/XboxHIDDriver.kext ]; then
		sudo kextunload /System/Library/Extensions/XboxHIDDriver.kext
		sudo rm -rf /System/Library/Extensions/XboxHIDDriver.kext
	fi

	if [ -d /Library/Extensions/XboxHIDDriver.kext ]; then
		sudo kextunload /Library/Extensions/XboxHIDDriver.kext
		sudo rm -rf /Library/Extensions/XboxHIDDriver.kext
	fi

	launchctl stop com.fizzypopstudios.XboxHIDDaemon
	launchctl unload /Library/LaunchAgents/com.fizzypopstudios.XboxHIDDaemon.plist
	sudo rm /Library/LaunchAgents/com.fizzypopstudios.XboxHIDDaemon.plist
fi
