FROM ubuntu:24.04

RUN apt-get update -qq \
  && DEBIAN_FRONTEND="noninteractive" apt-get install -qqy --no-install-recommends \
  doxygen zip build-essential curl git cmake zlib1g-dev libpng-dev libxml2-dev \
  gobjc python3 vim-tiny ca-certificates ninja-build \
  && apt-get clean -y \
  && rm -rf /var/lib/apt/lists/*

ARG BASE=/opt/xcode-cross

WORKDIR /opt

RUN set -x \
  && mkdir -p $BASE \
  && cd $BASE \
  && curl -LO https://github.com/llvm/llvm-project/releases/download/llvmorg-19.1.7/LLVM-19.1.7-Linux-X64.tar.xz \
  && tar -Jxf LLVM-*.tar.xz \
  && rm LLVM-*.tar.xz \
  && mv LLVM-* clang \
  && cd clang \
  && mkdir bin-new \
  && mv bin/clang-19 bin/clang bin/clang++ bin/dsymutil bin/llvm-nm bin-new \
  && rm -rf bin \
  && mv bin-new bin \
  && rm -rf lib/*.a lib/*.so lib/*.so.* lib/*-unknown-linux-gnu lib/clang/19/lib/*linux* include

RUN set -x \
  && git clone https://github.com/tpoechtrager/apple-libtapi.git \
  && cd apple-libtapi \
  && git checkout 640b4623929c923c0468143ff2a363a48665fa54 \
  && cd .. \
  && mkdir apple-libtapi-build \
  && cd apple-libtapi-build \
  && cmake -G Ninja -DCMAKE_INSTALL_PREFIX=$BASE/cctools -DCMAKE_BUILD_TYPE=Release -DLLVM_INCLUDE_TESTS=OFF -DLLVM_ENABLE_PROJECTS="clang;tapi" ../apple-libtapi/src/llvm \
  && ninja libtapi \
  && ninja install-libtapi install-tapi-headers \
  && cd .. \
  && rm -rf apple-libtapi apple-libtapi-build

RUN set -x \
  && git clone https://github.com/tpoechtrager/cctools-port.git \
  && cd cctools-port \
  && git checkout e101a6940dcb5988808a16626bc43851f00dc05f \
  && cd cctools \
  && PATH=$BASE/clang/bin:$PATH ./configure --prefix=$BASE/cctools --with-libtapi=$BASE/cctools \
  && PATH=$BASE/clang/bin:$PATH make -j$(nproc) \
  && make -j$(nproc) install \
  && cd ../.. \
  && rm -rf cctools-port

ARG XCODE_URL

RUN set -x \
  && cd $BASE \
  && curl -LO $XCODE_URL \
  && tar --warning=no-unknown-keyword -Jxf $(basename $XCODE_URL) \
  && rm $(basename $XCODE_URL)

ARG XCODE_CROSS_SRC_DIR=.
ADD $XCODE_CROSS_SRC_DIR/setup-toolchain.sh $XCODE_CROSS_SRC_DIR/setup-symlinks.sh $BASE/

RUN set -x \
  && cd $BASE \
  && cd Xcode.app \
  && $BASE/setup-toolchain.sh $BASE/cctools $BASE/clang

ENV DEVELOPER_DIR=$BASE/Xcode.app

RUN $BASE/setup-symlinks.sh $BASE $DEVELOPER_DIR $BASE/cctools

RUN rm $BASE/setup-symlinks.sh $BASE/setup-toolchain.sh

# Add the Xcode toolchain to the path, but after the normal path directories,
# to allow using the host compiler as usual (for cases that require compilation
# both for host and target at the same time).
ENV PATH=$BASE/bin:$PATH:$DEVELOPER_DIR/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin:$BASE/cctools/bin
