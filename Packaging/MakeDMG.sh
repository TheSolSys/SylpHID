#!/bin/bash

echo -e "\nCreating release DMG for Xbox HID"

if [ ! -e "Xbox HID.pkgproj" ]; then
	echo -e "MakeDMG.sh must be run in Packaging directory!\n"
	exit
fi

if [ -d DiskImage ]; then
	echo -e "Directory 'DiskImage' already present, aborting!\n"
	exit
fi

rm -f "Build/build.dmg"
rm -f "Build/Xbox HID.dmg"
cp "Resources/DiskImage/template.dmg.bz2" "Build/build.dmg.bz2"
bunzip2 "Build/build.dmg.bz2"
if [ ! -e "Build/build.dmg" ]; then
	echo -e "Unable to copy template.dmg from Resources directory!\n"
	exit
fi

echo "Preparing Xbox HID distribtion package"
packagesbuild "Xbox HID.pkgproj" >/dev/null

echo "Preparing distribution disk image"
mkdir DiskImage
hdiutil attach "Build/build.dmg" -noautoopen -quiet -mountpoint DiskImage

rm -f "DiskImage/Install Xbox HID.pkg"
cp -r "Build/Xbox HID.pkg" "DiskImage/Install Xbox HID.pkg"

rm -f "DiskImage/Uninstall Xbox HID.app"
cp -r "Build/Uninstall.app" "DiskImage/Uninstall Xbox HID.app"

hdiutil detach DiskImage -quiet -force
rm -rf "DiskImage"

hdiutil convert "Build/build.dmg" -quiet -format UDBZ -o "Build/Xbox HID.dmg"
rm "Build/build.dmg"

echo -e "Disk image for Xbox HID prepared!\n"
