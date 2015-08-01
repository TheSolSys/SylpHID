#!/bin/sh

echo "Load kernel extension"
if [ -d "/System/Library/Extensions/Xbox HID.kext" ]; then
	sudo kextload "/System/Library/Extensions/Xbox HID.kext"

elif [ -d "/Library/Extensions/Xbox HID.kext" ]; then
	sudo kextload "/Library/Extensions/Xbox HID.kext"

fi


echo "Start background daemon"
launchctl load /Library/LaunchAgents/com.fizzypopstudios.XboxHIDDaemon.plist
launchctl start com.fizzypopstudios.XboxHIDDaemon


echo "Relaunch System Preferences"
PROCESS="System Preferences"
number=$(ps aux | grep -i "$PROCESS" | grep -v grep | wc -l)
if [ $number -gt 0 ]
    then
        sudo killall "$PROCESS" && open -g "/Applications/System Preferences.app"
fi
