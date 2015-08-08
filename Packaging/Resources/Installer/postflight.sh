#!/bin/sh

echo "Load kernel extension"
if [ -d "/System/Library/Extensions/SylpHID.kext" ]; then
	kextload "/System/Library/Extensions/SylpHID.kext"

elif [ -d "/Library/Extensions/SylpHID.kext" ]; then
	kextload "/Library/Extensions/SylpHID.kext"

fi


echo "Start background daemon"
sudo -u $USER launchctl load /Library/LaunchAgents/com.fizzypopstudios.SylpHIDDaemon.plist
sudo -u $USER launchctl start com.fizzypopstudios.SylpHIDDaemon


echo "Relaunch System Preferences"
PROCESS="System Preferences"
number=$(ps aux | grep -i "$PROCESS" | grep -v grep | wc -l)
if [ $number -gt 0 ]; then
	killall "$PROCESS"
	touch "/tmp/sylphid.sysprefs"
fi


if [ -f "/tmp/sylphid.sysprefs" ]; then
	rm -f "/tmp/sylphid.sysprefs"
	sudo -u $USER open -g "/Applications/System Preferences.app"
fi
