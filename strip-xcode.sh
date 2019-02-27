#!/bin/sh

set -e

if [ -n "$1" ]; then
	cd "$1"
fi

cd Contents

mkdir PlugIns-new
mv PlugIns/Xcode3Core.ideplugin PlugIns/IDEiOSSupportCore.ideplugin PlugIns-new
rm -rf PlugIns
mv PlugIns-new PlugIns
rm -rf Applications _CodeSignature Frameworks Library MacOS OtherFrameworks Resources SharedFrameworks XPCServices _MASReceipt Info.plist PkgInfo version.plist

cd Developer
rm -rf Applications Documentation Library Makefiles Tools usr
mkdir -p usr/bin

cd Toolchains/XcodeDefault.xctoolchain/usr
rm -rf bin
mkdir bin
# Fill in usr/bin later with wrappers/scripts
rm -rf lib/*swift* lib/*.dylib lib/*.framework
cd ../../..
mkdir Toolchains-new
mv Toolchains/XcodeDefault.xctoolchain Toolchains-new
rm -rf Toolchains
mv Toolchains-new Toolchains

cd Platforms
rm -rf AppleTV* Watch*
cd MacOSX.platform
rm -rf usr _CodeSignature
cd Developer/SDKs/MacOSX10.*sdk
rm -rf usr/share
cd ../../../..

cd iPhoneOS.platform
rm -rf DeviceSupport usr _CodeSignature Developer/Library/CoreSimulator
cd ..

cd iPhoneSimulator.platform
rm -rf Developer/Library/CoreSimulator _CodeSignature
cd Developer/SDKs/iPhoneSimulator.sdk
rm -rf usr/share usr/lib usr/libexec Library Developer Applications
if [ ! -e System/Library/Frameworks/Foundation.framework/Foundation.tbd ]; then
	# Xcode 7.x and 8.x has got full frameworks for the simulator here,
	# replace them with thin frameworks with TBD files for the target.
	# Xcode 9 has got TBD files for the simulator as well.
	# On Xcode 9/iOS 11 SDK, building for the simulatorh with header
	# files taken from the target breaks.
	rm -rf System
	cp -a ../../../../iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk/System .
fi
