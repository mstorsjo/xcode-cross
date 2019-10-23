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

ln -sf $CCTOOLS/bin/libtool .
ln -sf $CCTOOLS/bin/lipo .
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
		ARGS+=(-target \$1-apple-darwin16)
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
	# Is there a better way to find the default sdk?
	SDKS=\$DEVELOPER_DIR/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs
	SDK=\$SDKS/\$(ls \$SDKS | grep MacOSX | head -1)
	ARGS+=(-isysroot \$SDK)
fi
export PATH=$CCTOOLS/bin:\$PATH
if [ "\$TOOL" = "clang++" ] || [ "\$TOOL" = "c++" ] || [ "\$TOOL" = "g++" ]; then
	EXE=$CLANG/bin/clang++
else
	EXE=$CLANG/bin/clang
fi
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

cd ../lib
mkdir -p $CLANG/lib/arc
for i in $(pwd)/arc/libarclite*.a; do
	ln -s $i $CLANG/lib/arc
done
