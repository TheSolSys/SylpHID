#!/bin/sh

echo "Start background daemon"
sudo launchctl load /Library/LaunchAgents/com.fizzypopstuidos.XboxHIDDaemon.plist
sudo launchctl start com.fizzypopstudios.XboxHIDDaemon


echo "Load kernel extension"
if [ -d /System/Library/Extensions/XboxHIDDriver.kext ]; then
	sudo kextload /System/Library/Extensions/XboxHIDDriver.kext
fi

if [ -d /Library/Extensions/XboxHIDDriver.kext ]; then
	sudo kextload /Library/Extensions/XboxHIDDriver.kext
fi


echo "Relaunch System Preferences"
PROCESS="System Preferences"
number=$(ps aux | grep -i "$PROCESS" | grep -v grep | wc -l)
if [ $number -gt 0 ]
    then
        killall "$PROCESS" && open -g "/Applications/System Preferences.app"
fi
