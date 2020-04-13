FROM ubuntu:18.04

RUN apt-get update -qq \
  && apt-get install -qqy --no-install-recommends doxygen zip build-essential \
  curl git cmake zlib1g-dev libpng-dev libxml2-dev gobjc python vim-tiny \
  ca-certificates ninja-build \
  && apt-get clean -y \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /opt

RUN set -x \
  && curl -LO http://releases.llvm.org/8.0.0/clang+llvm-8.0.0-x86_64-linux-gnu-ubuntu-18.04.tar.xz \
  && tar -Jxf clang+llvm-8.0.0-x86_64-linux-gnu-ubuntu-18.04.tar.xz \
  && rm clang+llvm-8.0.0-x86_64-linux-gnu-ubuntu-18.04.tar.xz \
  && mv clang+llvm-8.0.0-x86_64-linux-gnu-ubuntu-18.04 clang \
  && cd clang \
  && mkdir bin-new \
  && mv bin/clang-8 bin/clang bin/clang++ bin/dsymutil bin/llvm-nm bin-new \
  && rm -rf bin \
  && mv bin-new bin \
  && rm -rf lib/*.a lib/*.so lib/*.so.* lib/clang/8.0.0/lib/linux

RUN set -x \
  && git clone https://github.com/facebook/xcbuild.git xcbuild-src \
  && cd xcbuild-src \
  && git checkout 57fe28235a72318b8266a1c4b9d4d0f10e2ff876 \
  && git submodule sync \
  && git submodule update --init \
  && cd .. \
  && mkdir xcbuild-build \
  && cd xcbuild-build \
  && cmake -G Ninja -DCMAKE_INSTALL_PREFIX=/opt/xcbuild -DCMAKE_BUILD_TYPE=Release ../xcbuild-src \
  && ninja \
  && ninja install \
  && cd .. \
  && rm -rf xcbuild-build xcbuild-src

RUN set -x \
  && git clone https://github.com/tpoechtrager/apple-libtapi.git \
  && cd apple-libtapi \
  && git checkout 3efb201881e7a76a21e0554906cf306432539cef \
  && ln -s ../../clang/include/clang src/llvm/projects/libtapi/include \
  && cd .. \
  && mkdir apple-libtapi-build \
  && cd apple-libtapi-build \
  && cmake -G Ninja -DCMAKE_INSTALL_PREFIX=/opt/cctools -DCMAKE_BUILD_TYPE=Release -DLLVM_INCLUDE_TESTS=OFF ../apple-libtapi/src/llvm \
  && ln -s ../../clang/include/clang projects/libtapi/include \
  && ninja clang-tablegen-targets \
  && ninja libtapi \
  && ninja install-libtapi install-tapi-headers \
  && cd .. \
  && rm -rf apple-libtapi apple-libtapi-build

RUN set -x \
  && git clone https://github.com/tpoechtrager/cctools-port.git \
  && cd cctools-port \
  && git checkout 8d34d0fbb0037518383e438f40588ef5a3b0c8bf \
  && cd cctools \
  && PATH=/opt/clang/bin:$PATH ./configure --prefix=/opt/cctools --with-libtapi=/opt/cctools \
  && PATH=/opt/clang/bin:$PATH make -j$(nproc) \
  && make -j$(nproc) install \
  && cd ../.. \
  && rm -rf cctools-port

ARG XCODE_URL

RUN set -x \
  && curl -LO $XCODE_URL \
  && tar --warning=no-unknown-keyword -Jxf $(basename $XCODE_URL) \
  && rm $(basename $XCODE_URL)

ARG XCODE_CROSS_SRC_DIR=.
ADD $XCODE_CROSS_SRC_DIR/setup-toolchain.sh $XCODE_CROSS_SRC_DIR/setup-symlinks.sh /opt/xcode-cross/

RUN set -x \
  && cd Xcode.app \
  && /opt/xcode-cross/setup-toolchain.sh /opt/cctools /opt/clang

ENV DEVELOPER_DIR=/opt/Xcode.app

RUN /opt/xcode-cross/setup-symlinks.sh /opt/xcode-cross $DEVELOPER_DIR /opt/cctools

# Add the Xcode toolchain to the path, but after the normal path directories,
# to allow using the host compiler as usual (for cases that require compilation
# both for host and target at the same time).
ENV PATH=/opt/xcode-cross/bin:$PATH:$DEVELOPER_DIR/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin:/opt/xcbuild/usr/bin:/opt/cctools/bin
