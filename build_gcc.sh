#!/bin/bash

set -e

source ./setup_environment.sh

build_gcc() {
    log_section "Building GCC 13.3.0 for host machine"

    local gcc_version="13.3.0"  # 更新为要求的13.3版本
    local src_dir="$CROSS_BASE/src/gcc"
    local build_dir="$CROSS_BASE/build/gcc"
    local install_dir="$CROSS_BASE/install/gcc"

    # 设置编译GCC所需的环境变量
    export CFLAGS="-O2 -fPIC"
    export CXXFLAGS="-O2 -fPIC"
    # 下载GCC源码
    cd "$CROSS_BASE/src"
    if [ ! -d "gcc" ]; then
        log_info "Downloading GCC..."
        wget "https://ftp.gnu.org/gnu/gcc/gcc-$gcc_version/gcc-$gcc_version.tar.gz"
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

    # 配置GCC - 基于宿主系统参数，但使用本地编译模式
    log_info "Configuring GCC..."
    "$src_dir/configure" \
        --with-pkgversion='Spams 13.3.0' \
        --with-bugurl=file:///usr/share/doc/gcc-13/README.Bugs \
        --enable-languages=c,c++,fortran \
        --program-suffix=-13 \
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
        --target=arm-ev3-linux-gnueabi

    # 编译
    log_info "Compiling GCC..."
    make -j$(nproc)

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
