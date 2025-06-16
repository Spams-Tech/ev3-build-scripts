#!/bin/bash

set -e

source ./setup_environment.sh

build_openblas() {
    log_section "Building OpenBLAS ${OPENBLAS_VERSION}"

    local openblas_version="${OPENBLAS_VERSION}"
    local src_dir="$CROSS_BASE/src/openblas"
    local install_dir="$CROSS_BASE/install/openblas"

    # 设置编译环境变量
    export CC=$CROSS_CC
    export FC=$CROSS_FC
    export LD=$CROSS_LD
    export AR=$CROSS_AR
    export RANLIB=$CROSS_RANLIB
    export CFLAGS="$CFLAGS -fPIC"

    # 下载 OpenBLAS 源码
    cd "$CROSS_BASE/src"
    if [ ! -d "openblas" ]; then
        log_info "Downloading OpenBLAS..."
        wget "${OPENBLAS_URL}"
        tar -xzf "OpenBLAS-${openblas_version}.tar.gz"
        mv "OpenBLAS-${openblas_version}" openblas
        rm -f "OpenBLAS-${openblas_version}.tar.gz"
    fi

    # 构建 OpenBLAS
    cd "$src_dir"
    log_info "Building OpenBLAS..."
    make clean || true

    # 使用适合ARM的参数进行编译
    make HOSTCC=gcc CC=$CROSS_CC FC=$CROSS_FC TARGET=ARMV5 -j${BUILD_JOBS:-$(nproc)}

    # 安装到指定目录
    log_info "Installing OpenBLAS..."
    make PREFIX="$install_dir" HOSTCC=gcc CC=$CROSS_CC FC=$CROSS_FC TARGET=ARMV5 install

    # 记录安装的文件列表
    find "$install_dir" -type f > "$CROSS_BASE/install/openblas_files.list"
    log_info "File list saved to $CROSS_BASE/install/openblas_files.list"

    log_success "OpenBLAS successfully built!"
    log_info "Installed to: $install_dir"
}

# 执行 OpenBLAS 编译
build_openblas
