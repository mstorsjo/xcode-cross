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
cd MacOSX.platform
rm -rf usr _CodeSignature
cd Developer/SDKs/MacOSX10.*sdk
rm -rf usr/share
cd ../../../..

for sdk in iPhone Watch AppleTV; do
	OS=${sdk}OS
	SIM=${sdk}Simulator
	cd $OS.platform
	rm -rf DeviceSupport usr _CodeSignature Developer/Library/CoreSimulator
	cd ..

	cd $SIM.platform
	rm -rf Developer/Library/CoreSimulator Developer/Library/Frameworks Developer/Library/PrivateFrameworks _CodeSignature
	cd Developer/SDKs/$SIM.sdk
	rm -rf usr/share usr/libexec Library Developer Applications
	# On Xcode 9.x and newer, usr/lib contains tbd files for the libraries,
	# and linking to them for simulator builds succeeds. On Xcode 8.x and
	# older, the usr/lib dir contains large dylib files, and linking
	# against them doesn't succeed anyway (it's missing
	# /usr/lib/system/libsystem_kernel.dylib). Thus remove the large files
	# from older SDKs, while keeping enough for linking to succeed on
	# newer SDks.
	rm -rf usr/lib/system usr/lib/*.dylib
	if [ ! -e System/Library/Frameworks/Foundation.framework/Foundation.tbd ]; then
		# Xcode 7.x and 8.x has got full frameworks for the simulator here,
		# replace them with thin frameworks with TBD files for the target.
		# Xcode 9 has got TBD files for the simulator as well.
		# On Xcode 9/iOS 11 SDK, building for the simulatorh with header
		# files taken from the target breaks.
		rm -rf System
		cp -a ../../../../$OS.platform/Developer/SDKs/$OS.sdk/System .
	fi
	cd ../../../..
done
