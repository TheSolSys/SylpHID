#!/bin/bash

echo -e "\nCreating release DMG for SylpHID"

if [ ! -e "SylpHID.pkgproj" ]; then
	echo -e "MakeDMG.sh must be run in Packaging directory!\n"
	exit
fi

if [ -d DiskImage ]; then
	echo -e "Directory 'DiskImage' already present, aborting!\n"
	exit
fi

rm -f "Build/build.dmg"
rm -f "Build/SylpHID.dmg"
cp "Resources/DiskImage/template.dmg.bz2" "Build/build.dmg.bz2"
bunzip2 "Build/build.dmg.bz2"
if [ ! -e "Build/build.dmg" ]; then
	echo -e "Unable to copy template.dmg from Resources directory!\n"
	exit
fi

echo "Preparing SylpHID distribtion package"
packagesbuild "SylpHID.pkgproj" >/dev/null

echo "Preparing distribution disk image"
mkdir DiskImage
hdiutil attach "Build/build.dmg" -noautoopen -quiet -mountpoint DiskImage

rm -f "DiskImage/Install Sylpʜıᴅ.pkg"
cp -r "Build/SylpHID.pkg" "DiskImage/Install Sylpʜıᴅ.pkg"

rm -f "DiskImage/Uninstall Sylpʜıᴅ.app"
cp -r "Build/Uninstall.app" "DiskImage/Uninstall Sylpʜıᴅ.app"

hdiutil detach DiskImage -quiet -force
rm -rf "DiskImage"

hdiutil convert "Build/build.dmg" -quiet -format UDBZ -o "Build/SylpHID.dmg"
rm "Build/build.dmg"

echo -e "Disk image for SylpHID prepared!\n"
