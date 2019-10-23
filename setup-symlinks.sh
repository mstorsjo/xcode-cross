#!/bin/sh

set -e

if [ $# -lt 3 ]; then
	echo $0 prefix developer-dir cctools
	exit 1
fi
PREFIX="$1"
DEVELOPER_DIR="$2"
CCTOOLS="$3"

ARCHS="i386 x86_64 armv7 arm64"
mkdir -p $PREFIX/bin
for tool in clang clang++ cc gcc c++ g++ nm; do
	for arch in $ARCHS; do
		ln -sf $DEVELOPER_DIR/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/$tool $PREFIX/bin/$arch-apple-darwin-$tool
	done
	ln -sf $DEVELOPER_DIR/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/$tool $PREFIX/bin/apple-darwin-$tool
done
for tool in ar as ld ranlib strings strip; do
	for arch in $ARCHS; do
		ln -sf $CCTOOLS/bin/$tool $PREFIX/bin/$arch-apple-darwin-$tool
	done
	ln -sf $CCTOOLS/bin/$tool $PREFIX/bin/apple-darwin-$tool
done
