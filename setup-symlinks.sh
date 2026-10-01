#!/bin/sh

set -e

if [ $# -lt 3 ]; then
	echo $0 prefix developer-dir cctools
	exit 1
fi
PREFIX="$1"
DEVELOPER_DIR="$2"
CCTOOLS="$3"

abs2rel() {
	perl -MFile::Spec -e 'print File::Spec->abs2rel(@ARGV)' "$1" "$2"
}

CCTOOLS_REL="$(abs2rel "$CCTOOLS" "$PREFIX/bin")"

XCTOOLCHAIN="$DEVELOPER_DIR/Contents/Developer/Toolchains/XcodeDefault.xctoolchain"
XCTOOLCHAIN_REL="$(abs2rel "$XCTOOLCHAIN" "$PREFIX/bin")"
ARCHS="i386 x86_64 armv7 arm64"
mkdir -p $PREFIX/bin
for tool in clang clang++ cc gcc c++ g++ nm; do
	for arch in $ARCHS; do
		ln -sf "$XCTOOLCHAIN_REL/usr/bin/$tool" "$PREFIX/bin/$arch-apple-darwin-$tool"
	done
	ln -sf "$XCTOOLCHAIN_REL/usr/bin/$tool" "$PREFIX/bin/apple-darwin-$tool"
done
for tool in ar as ld ranlib strings strip; do
	for arch in $ARCHS; do
		ln -sf "$CCTOOLS_REL/bin/$tool" "$PREFIX/bin/$arch-apple-darwin-$tool"
	done
	ln -sf "$CCTOOLS_REL/bin/$tool" "$PREFIX/bin/apple-darwin-$tool"
done

CCTOOLS_REL="$(abs2rel "$CCTOOLS" "$PREFIX")"
DEVELOPER_DIR_REL="$(abs2rel "$DEVELOPER_DIR" "$PREFIX")"

cat<<EOF > "$PREFIX/env.sh"
#!/bin/sh

if [ -n "\$BASH_SOURCE" ]; then
	XCODE_CROSS_BASE="\$(cd \$(dirname "\$BASH_SOURCE") && pwd)"
else
	XCODE_CROSS_BASE="$PREFIX"
fi
export DEVELOPER_DIR="\$XCODE_CROSS_BASE/$DEVELOPER_DIR_REL"
export LD_LIBRARY_PATH="\$XCODE_CROSS_BASE/$CCTOOLS_REL/lib"
export PATH="\$XCODE_CROSS_BASE/bin:\$PATH:\$DEVELOPER_DIR/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin:\$XCODE_CROSS_BASE/$CCTOOLS_REL/bin"
unset XCODE_CROSS_BASE
EOF
chmod a+x "$PREFIX/env.sh"
