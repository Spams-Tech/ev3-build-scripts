#!/bin/bash

set -e

source ./setup_environment.sh

build_python() {
    log_section "Building Python ${PYTHON_VERSION}"

    local python_version="${PYTHON_VERSION}"
    local src_dir="$CROSS_BASE/src/python"
    local build_dir="$CROSS_BASE/build/python"
    local install_dir="$CROSS_BASE/install/python"

    # 设置所有依赖库的路径
    local all_lib_paths=""
    local all_include_paths=""
    local all_pkg_config_paths=""

    for lib in zlib openssl libffi sqlite ncurses readline bzip2 xz gdbm util-linux; do
        if [ -d "$CROSS_BASE/install/$lib/usr" ]; then
            all_lib_paths="$all_lib_paths -L$CROSS_BASE/install/$lib/usr/lib"
            all_include_paths="$all_include_paths -I$CROSS_BASE/install/$lib/usr/include"
            all_pkg_config_paths="$all_pkg_config_paths:$CROSS_BASE/install/$lib/usr/lib/pkgconfig"
        fi
    done

    # 设置环境变量
    export CC=$CROSS_CC
    export CXX=$CROSS_CXX
    export AR=$CROSS_AR
    export RANLIB=$CROSS_RANLIB
    export LDFLAGS="-lncursesw -ltinfo$all_lib_paths"
    export CPPFLAGS="$all_include_paths"
    export PKG_CONFIG_PATH="${all_pkg_config_paths#:}"
    export CFLAGS="$CFLAGS -fPIC"
    export CXXFLAGS="$CXXFLAGS -fPIC"

    # 下载 Python 源码
    cd "$CROSS_BASE/src"
    if [ ! -d "python" ]; then
        log_info "Downloading Python..."
        wget "${PYTHON_URL}"
        tar -xf "Python-${python_version}.tar.xz"
        mv "Python-${python_version}" python
        rm -f "Python-${python_version}.tar.xz"
    fi

    cd "$src_dir"

    # 创建配置文件
    log_info "Creating config.site for cross compilation..."
    cat > config.site << EOF
ac_cv_file__dev_ptmx=yes
ac_cv_file__dev_ptc=no
ac_cv_have_long_long_format=yes
ac_cv_buggy_getaddrinfo=no
EOF

    # 首先构建本地 Python（用于交叉编译）
    log_info "Building native Python for cross compilation..."
    rm -rf "$CROSS_BASE/build/python-native"
    mkdir -p "$CROSS_BASE/build/python-native"
    cd "$CROSS_BASE/build/python-native"

    local SAVED_CC="$CC"
    local SAVED_CXX="$CXX"
    local SAVED_AR="$AR"
    local SAVED_RANLIB="$RANLIB"
    local SAVED_CFLAGS="$CFLAGS"
    local SAVED_CXXFLAGS="$CXXFLAGS"
    local SAVED_LDFLAGS="$LDFLAGS"
    local SAVED_CPPFLAGS="$CPPFLAGS"
    local SAVED_PKG_CONFIG_PATH="$PKG_CONFIG_PATH"


    # 清除交叉编译环境变量用于本地编译
    unset CC CXX AR RANLIB CFLAGS CXXFLAGS LDFLAGS CPPFLAGS PKG_CONFIG_PATH

    log_info "Configuring native Python..."
    "$src_dir/configure" --prefix="$CROSS_BASE/build/python-native-install"

    log_info "Compiling native Python..."
    make -j${BUILD_JOBS:-$(nproc)}

    log_info "Installing native Python..."
    make install

    # 恢复交叉编译环境变量
    export CC="$SAVED_CC"
    export CXX="$SAVED_CXX"
    export AR="$SAVED_AR"
    export RANLIB="$SAVED_RANLIB"
    export CFLAGS="$SAVED_CFLAGS"
    export CXXFLAGS="$SAVED_CXXFLAGS"
    export LDFLAGS="$SAVED_LDFLAGS"
    export CPPFLAGS="$SAVED_CPPFLAGS"
    export PKG_CONFIG_PATH="$SAVED_PKG_CONFIG_PATH"

    # 交叉编译 Python
    log_info "Building Python..."
    rm -rf "$build_dir"
    mkdir -p "$build_dir"
    cd "$build_dir"

    export CONFIG_SITE="$src_dir/config.site"

    log_info "Configuring Python..."
    "$src_dir/configure" \
        --host="$CROSS_HOST" \
        --build=$(gcc -dumpmachine) \
        --prefix="$install_dir" \
        --with-ensurepip=no \
        --enable-shared \
        --with-lto \
        --with-openssl="$CROSS_BASE/install/openssl/usr" \
        --with-build-python="$CROSS_BASE/build/python-native-install/bin/python3.13"

    # 编译
    log_info "Compiling Python..."
    make -j${BUILD_JOBS:-$(nproc)}

    # 安装
    log_info "Installing Python..."
    make altinstall

    # 记录安装文件
    find "$install_dir" -type f > "$CROSS_BASE/install/python_files.list"
    log_info "File list saved to $CROSS_BASE/install/python_files.list"

    log_success "Python $python_version successfully built!"
    log_info "Installed to: $install_dir"
}

# 执行 Python 编译
build_python
