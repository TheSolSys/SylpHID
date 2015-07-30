#!/bin/sh

echo "Start background daemon"
sudo launchctl load /Library/LaunchDaemons/com.fizzypopstudios.XboxHIDDaemon.plist
sudo launchctl start com.fizzypopstudios.XboxHIDDaemon


echo "Load kernel extension"
if [ -d "/System/Library/Extensions/Xbox HID.kext" ]; then
	sudo kextload "/System/Library/Extensions/Xbox HID.kext"

elif [ -d "/Library/Extensions/Xbox HID.kext" ]; then
	sudo kextload "/Library/Extensions/Xbox HID.kext"

fi


echo "Relaunch System Preferences"
PROCESS="System Preferences"
number=$(ps aux | grep -i "$PROCESS" | grep -v grep | wc -l)
if [ $number -gt 0 ]
    then
        sudo killall "$PROCESS" && open -g "/Applications/System Preferences.app"
fi
