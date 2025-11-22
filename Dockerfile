FROM ubuntu:20.04

RUN apt-get update -qq \
  && DEBIAN_FRONTEND="noninteractive" apt-get install -qqy --no-install-recommends \
  doxygen zip build-essential curl git cmake zlib1g-dev libpng-dev libxml2-dev \
  gobjc python vim-tiny ca-certificates ninja-build \
  && apt-get clean -y \
  && rm -rf /var/lib/apt/lists/*

ARG BASE=/opt/xcode-cross

WORKDIR /opt

RUN set -x \
  && mkdir -p $BASE \
  && cd $BASE \
  && curl -LO https://github.com/llvm/llvm-project/releases/download/llvmorg-11.0.0/clang+llvm-11.0.0-x86_64-linux-gnu-ubuntu-20.04.tar.xz \
  && tar -Jxf clang+llvm-11.0.0-x86_64-linux-gnu-ubuntu-20.04.tar.xz \
  && rm clang+llvm-11.0.0-x86_64-linux-gnu-ubuntu-20.04.tar.xz \
  && mv clang+llvm-11.0.0-x86_64-linux-gnu-ubuntu-20.04 clang \
  && cd clang \
  && mkdir bin-new \
  && mv bin/clang-11 bin/clang bin/clang++ bin/dsymutil bin/llvm-nm bin-new \
  && rm -rf bin \
  && mv bin-new bin \
  && rm -rf lib/*.a lib/*.so lib/*.so.* lib/clang/11.0.0/lib/linux include

RUN set -x \
  && git clone https://github.com/facebook/xcbuild.git xcbuild-src \
  && cd xcbuild-src \
  && git checkout dbaee552d2f13640773eb1ad3c79c0d2aca7229c \
  && git submodule sync \
  && git submodule update --init \
  && sed -i s/-Werror// CMakeLists.txt \
  && cd .. \
  && mkdir xcbuild-build \
  && cd xcbuild-build \
  && cmake -G Ninja -DCMAKE_INSTALL_PREFIX=$BASE/xcbuild -DCMAKE_BUILD_TYPE=Release ../xcbuild-src \
  && ninja \
  && ninja install \
  && cd .. \
  && rm -rf xcbuild-build xcbuild-src

RUN set -x \
  && git clone https://github.com/tpoechtrager/apple-libtapi.git \
  && cd apple-libtapi \
  && git checkout 664b8414f89612f2dfd35a9b679c345aa5389026 \
  && ln -s ../../clang/include/clang src/llvm/projects/libtapi/include \
  && cd .. \
  && mkdir apple-libtapi-build \
  && cd apple-libtapi-build \
  && cmake -G Ninja -DCMAKE_INSTALL_PREFIX=$BASE/cctools -DCMAKE_BUILD_TYPE=Release -DLLVM_INCLUDE_TESTS=OFF ../apple-libtapi/src/llvm \
  && ln -s ../../clang/include/clang projects/libtapi/include \
  && ninja clang-tablegen-targets \
  && ninja libtapi \
  && ninja install-libtapi install-tapi-headers \
  && cd .. \
  && rm -rf apple-libtapi apple-libtapi-build

RUN set -x \
  && git clone https://github.com/tpoechtrager/cctools-port.git \
  && cd cctools-port \
  && git checkout f28fb5e9c31efd3d0552afcce2d2c03cae25c1ca \
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
ENV PATH=$BASE/bin:$PATH:$DEVELOPER_DIR/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin:$BASE/xcbuild/usr/bin:$BASE/cctools/bin
