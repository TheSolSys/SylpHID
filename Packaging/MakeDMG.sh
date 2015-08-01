#!/bin/bash

echo -e "\nCreating release DMG for Xbox HID..."

if [ ! -e "Xbox HID.pkgproj" ]; then
	echo -e "MakeDMG.sh must be run in Packaging directory!\n"
	exit
fi

if [ -d DiskImage ]; then
	echo -e "Directory 'DiskImage' already present, aborting!\n"
	exit
fi

rm -f "Resources/Xbox HID.dmg"
cp "Resources/template.dmg" "Build/Xbox HID.dmg"
if [ ! -e "Resources/Xbox HID.dmg" ]; then
	echo -e "Unable to copy template.dmg from Resources directory!\n"
	exit
fi

mkdir DiskImage
hdiutil attach "Resources/template.dmg" -noautoopen -quiet -mountpoint DiskImage

cp "Build/Install Xbox HID.pkg" "DiskImage/Xbox HID.pkg"
cp -R "Build/
