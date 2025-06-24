#!/bin/bash

set -e

source ./setup_environment.sh

build_gcc() {
    log_section "Building GCC ${GCC_VERSION} for host machine"

    local gcc_version="${GCC_VERSION}"  # 从配置文件获取版本
    local src_dir="$CROSS_BASE/src/gcc"
    local build_dir="$CROSS_BASE/build/gcc"
    local install_dir="$CROSS_BASE/install/gcc"

    # 下载GCC源码
    cd "$CROSS_BASE/src"
    if [ ! -d "gcc" ]; then
        log_info "Downloading GCC..."
        wget "${GCC_URL}"
        tar -xf "gcc-$gcc_version.tar.gz"
        mv "gcc-$gcc_version" gcc

        # 下载依赖项
        cd gcc
        log_info "Downloading GCC prerequisites..."
        ./contrib/download_prerequisites
        cd ..
    fi

    # 创建构建目录
    rm -rf "$build_dir"
    mkdir -p "$build_dir"
    cd "$build_dir"

    log_info "Configuring GCC..."
        "$src_dir/configure" \
        --with-pkgversion="Spams ${GCC_VERSION}" \
        --with-bugurl=https://github.com/Spam-Tech/ev3-build-scripts \
        --enable-languages=c,c++,fortran \
        --enable-shared \
        --enable-linker-build-id \
        --with-build-sysroot=$($CROSS_CC -print-sysroot) \
        --without-included-gettext \
        --enable-threads=posix \
        --enable-nls \
        --enable-clocale=gnu \
        --enable-libstdcxx-debug \
        --enable-libstdcxx-time=yes \
        --with-default-libstdcxx-abi=new \
        --enable-gnu-unique-object \
        --disable-libitm \
        --disable-libquadmath \
        --disable-libquadmath-support \
        --enable-default-pie \
        --enable-multiarch \
        --disable-sjlj-exceptions \
        --disable-werror \
        --enable-checking=release \
        --host=arm-ev3-linux-gnueabi \
        --target=arm-ev3-linux-gnueabi \
        CFLAGS="-O2 -fPIC" \
        CXXFLAGS="-O2 -fPIC"

    # 编译
    log_info "Compiling GCC..."
    make -j${BUILD_JOBS:-$(nproc)}

    # 安装
    log_info "Installing GCC..."
    make install DESTDIR="$install_dir"

    # 记录安装文件
    find "$install_dir" -type f > "$CROSS_BASE/install/gcc_files.list"
    log_info "File list saved to $CROSS_BASE/install/gcc_files.list"

    log_success "GCC $gcc_version successfully built!"
    log_info "Installed to: $install_dir"
}

# 执行GCC编译
build_gcc
