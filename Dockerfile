FROM ubuntu:16.04

RUN apt-get update && apt-get install -y doxygen zip build-essential curl git cmake zlib1g-dev libpng-dev libxml2-dev gobjc python vim-tiny

WORKDIR /opt

RUN set -x \
  && curl -LO http://releases.llvm.org/5.0.0/clang+llvm-5.0.0-linux-x86_64-ubuntu16.04.tar.xz \
  && tar -Jxf clang+llvm-5.0.0-linux-x86_64-ubuntu16.04.tar.xz \
  && rm clang+llvm-5.0.0-linux-x86_64-ubuntu16.04.tar.xz \
  && mv clang+llvm-5.0.0-linux-x86_64-ubuntu16.04 clang \
  && cd clang \
  && mkdir bin-new \
  && mv bin/clang-5.0 bin/clang bin/clang++ bin/llvm-dsymutil bin-new \
  && rm -rf bin \
  && mv bin-new bin \
  && rm -rf lib/*.a lib/*.so lib/*.so.* lib/clang/5.0.0/lib/linux

RUN set -x \
  && git clone https://github.com/facebook/xcbuild.git xcbuild-src \
  && cd xcbuild-src \
  && git checkout 57fe28235a72318b8266a1c4b9d4d0f10e2ff876 \
  && git submodule sync \
  && git submodule update --init \
  && cd .. \
  && mkdir xcbuild-build \
  && cd xcbuild-build \
  && cmake -DCMAKE_INSTALL_PREFIX=/opt/xcbuild -DCMAKE_BUILD_TYPE=Release ../xcbuild-src \
  && make -j$(nproc) \
  && make -j$(nproc) install \
  && cd .. \
  && rm -rf xcbuild-build xcbuild-src

RUN set -x \
  && git clone https://github.com/tpoechtrager/apple-libtapi.git \
  && cd apple-libtapi \
  && git checkout 84c0c83c435e3d916673b1aa48905047e8d422d0 \
  && cd .. \
  && mkdir apple-libtapi-build \
  && cd apple-libtapi-build \
  && cmake -DCMAKE_INSTALL_PREFIX=/opt/cctools -DCMAKE_BUILD_TYPE=Release -DLLVM_INCLUDE_TESTS=OFF ../apple-libtapi/src/apple-llvm/src \
  && make -j$(nproc) libtapi \
  && make -j$(nproc) install-libtapi \
  && mkdir -p /opt/cctools/include \
  && cp -a ../apple-libtapi/src/apple-llvm/src/projects/libtapi/include/tapi /opt/cctools/include \
  && cp projects/libtapi/include/tapi/Version.inc /opt/cctools/include/tapi \
  && cd .. \
  && rm -rf apple-libtapi apple-libtapi-build

# -D_FORTIFY_SOURCE=0, since cctools/misc/libtool.c:2070 gets an incorrect
# guard. Alternatively, the code could be changed to use snprintf instead.
RUN set -x \
  && git clone https://github.com/tpoechtrager/cctools-port.git \
  && cd cctools-port \
  && git checkout 22ebe727a5cdc21059d45313cf52b4882157f6f0 \
  && cd cctools \
  && CFLAGS="-D_FORTIFY_SOURCE=0 -O3" ./configure --prefix=/opt/cctools --with-libtapi=/opt/cctools \
  && make -j$(nproc) \
  && make -j$(nproc) install \
  && cd ../.. \
  && rm -rf cctools-port

ARG XCODE_CROSS_SRC_DIR=.
ADD $XCODE_CROSS_SRC_DIR /opt/xcode-cross/

ARG XCODE_URL

RUN set -x \
  && curl -LO $XCODE_URL \
  && tar --warning=no-unknown-keyword -Jxf $(basename $XCODE_URL) \
  && rm $(basename $XCODE_URL)

RUN set -x \
  && cd Xcode.app \
  && /opt/xcode-cross/setup-toolchain.sh /opt/cctools /opt/clang

ENV DEVELOPER_DIR=/opt/Xcode.app

RUN /opt/xcode-cross/setup-symlinks.sh /opt/xcode-cross $DEVELOPER_DIR /opt/cctools

# Add the Xcode toolchain to the path, but after the normal path directories,
# to allow using the host compiler as usual (for cases that require compilation
# both for host and target at the same time).
ENV PATH=/opt/xcode-cross/bin:$PATH:$DEVELOPER_DIR/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin:/opt/xcbuild/usr/bin:/opt/cctools/bin
