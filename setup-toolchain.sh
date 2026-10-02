#!/bin/sh

if [ $# -lt 2 ]; then
	echo $0 cctools clang
	exit 1
fi

if [ ! -d Contents/Developer/usr/bin ]; then
	echo Execute this in the xcode dir root
	exit 1
fi

CCTOOLS=$1
CLANG=$2

if [ ! -e $CCTOOLS/bin/lipo ]; then
	echo lipo not found in $CCTOOLS
	exit 1
fi

if [ ! -e $CLANG/bin/clang ]; then
	echo clang not found in $CLANG
	exit 1
fi

set -e

cd Contents/Developer/usr/bin
ln -sf /bin/true copypng
ln -sf /bin/true ibtool

cd ../../Toolchains/XcodeDefault.xctoolchain/usr/bin

TOOLS_SYMLINK="ar as cmpdylib ctf_insert dyldinfo install_name_tool ld libtool"
TOOLS_SYMLINK="$TOOLS_SYMLINK lipo nmedit pagestuff ranlib segedit size string"
TOOLS_SYMLINK="$TOOLS_SYMLINK strip unwinddump vtool"

for tool in $TOOLS_SYMLINK; do
	ln -sf $CCTOOLS/bin/$tool .
done

cat<<EOF > clang
#!/bin/bash
ARGS=()
TARGET_SET=""
SYSROOT_SET=""
TOOL=\$(basename \$0 | sed 's/.*-\([^-]*\)/\1/')
ARCH=\$(basename \$0 | sed 's/-.*//')
case \$ARCH in
i386|x86_64|arm*)
	ARGS+=(-target \$ARCH-apple-darwin16)
	TARGET_SET=1
	;;
*)
	;;
esac
while [ \$# -gt 0 ]; do
	a=\$1
	if [ "\$a" = "-arch" ]; then
		shift
		ARGS+=(-target \$1-apple-darwin16 -arch \$1)
		TARGET_SET=1
		shift
	else
		if [ "\$a" = "-isysroot" ]; then
			SYSROOT_SET=1
		elif [ "\$a" = "-target" ]; then
			TARGET_SET=1
		fi
		ARGS+=("\$a")
		shift
	fi
done
if [ -z "\$TARGET_SET" ]; then
	ARGS+=(-target x86_64-apple-darwin16)
fi
if [ -z "\$SYSROOT_SET" ]; then
	SDKS=\$DEVELOPER_DIR/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs
	if [ -d \$SDKS/MacOSX.sdk ]; then
		SDK=\$SDKS/MacOSX.sdk
	else
		# Is there a better way to find the default sdk?
		SDK=\$SDKS/\$(ls \$SDKS | grep -E 'MacOSX[[:digit:]]' | head -1)
	fi
	ARGS+=(-isysroot \$SDK)
fi
export PATH=$CCTOOLS/bin:\$PATH
if [ "\$TOOL" = "clang++" ] || [ "\$TOOL" = "c++" ] || [ "\$TOOL" = "g++" ]; then
	ARGS+=(--driver-mode=g++)
fi
ARGS+=(-no-canonical-prefixes)
EXE=\$(dirname \$(readlink -f \$0))/clang-exe
\$EXE "\${ARGS[@]}"
EOF
chmod a+x clang
ln -sf clang clang++
ln -sf clang cc
ln -sf clang c89
ln -sf clang c99
ln -sf clang c++
ln -sf clang gcc
ln -sf clang g++

ln -s $CLANG/bin/dsymutil .
ln -s $CLANG/bin/llvm-nm nm
ln -s $CLANG/bin/clang clang-exe

cd ../lib/clang
# If there are symlinks among the clang version directories, e.g. 17.0.0 -> 17,
# remove the symlink so the next step finds only one directory.
for i in $(find . -maxdepth 1 -type l); do
	rm $i
done
# Rename the original bundled clang resource directory to "orig", to avoid
# potential version number clashes.
mv * orig
# Fetch the version number of the resource directory of the clang we're
# using.
VER=$(cd $CLANG/lib/clang && ls)
# Link in the clang resource directory from the external installation into
# this directory.
ln -s $CLANG/lib/clang/$VER .
# Provide the original libraries in the external clang's resource directory.
ln -s $(pwd)/orig/lib/darwin $VER/lib
