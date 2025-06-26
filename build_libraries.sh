#!/bin/bash

set -e

source ./setup_environment.sh

# 通用库编译函数
build_library() {
    local lib_name=$1
    local lib_url=$2
    local lib_version=$3
    local configure_opts=$4
    local make_opts=$5
    
    log_section "Building $lib_name $lib_version"

    local src_dir="$CROSS_BASE/src/$lib_name"
    local build_dir="$CROSS_BASE/build/$lib_name"
    local install_dir="$CROSS_BASE/install/$lib_name"

    # 设置库特定的环境变量
    export CC=$CROSS_CC
    export CXX=$CROSS_CXX
    export AR=$CROSS_AR
    export STRIP=$CROSS_STRIP
    export RANLIB=$CROSS_RANLIB
    export PKG_CONFIG_PATH="$install_dir/lib/pkgconfig"

    # 下载和解压源码
    cd "$CROSS_BASE/src"
    if [ ! -d "$lib_name" ]; then
        log_info "Downloading $lib_name..."
        local archive_name="${lib_name}.tar.gz"
        wget "$lib_url" -O "$archive_name"
        
        # 解压并正确重命名目录
        local extracted_dir="$lib_name"-"$lib_version"
        tar -xzf "$archive_name"
        log_info "Renaming $extracted_dir to $lib_name..."
        mv "$extracted_dir" "$lib_name"
        
        # 清理压缩包
        rm -f "$archive_name"
    fi
    
    # 创建构建目录
    rm -rf "$build_dir"
    mkdir -p "$build_dir"
    cd "$build_dir"
    
    # 配置
    log_info "Configuring $lib_name..."
    if [ -n "$configure_opts" ]; then
        if [ $lib_name == "readline" ]; then
            "$src_dir/configure" --host=$CROSS_HOST --prefix=/usr --enable-shared --disable-static CPPFLAGS="-I$CROSS_BASE/install/ncurses/usr/include" LDFLAGS="-L$CROSS_BASE/install/ncurses/usr/lib -lncursesw -ltinfow"
        else
          eval "$src_dir/configure --host=$CROSS_HOST --prefix=/usr $configure_opts"
        fi
    else
        if [ $lib_name == "zlib" ]; then
            # zlib 特殊处理
            "$src_dir/configure" --prefix=/usr
        else
            "$src_dir/configure" --host=$CROSS_HOST --prefix=/usr --enable-shared --disable-static
        fi
    fi
    
    # 编译
    log_info "Compiling $lib_name..."
    if [ -n "$make_opts" ]; then
        eval "make -j${BUILD_JOBS:-$(nproc)} $make_opts"
    else
        make -j${BUILD_JOBS:-$(nproc)}
    fi

    # 安装
    log_info "Installing $lib_name..."
    make DESTDIR="$install_dir" install

    if [ $lib_name == "ncurses" ]; then
        log_info "Creating symlinks for ncurses..."
        for lib in ncurses form panel menu tinfo ; do
            ln -sfv lib${lib}w.so $install_dir/usr/lib/lib${lib}.so
            ln -sfv ${lib}w.pc $install_dir/usr/lib/pkgconfig/${lib}.pc
        done
        ln -sfv libncursesw.so $install_dir/usr/lib/libcurses.so
    fi

    # 记录安装的文件列表
    find "$install_dir" -type f > "$CROSS_BASE/install/${lib_name}_files.list"
    log_info "File list saved to $CROSS_BASE/install/${lib_name}_files.list"

    log_success "$lib_name successfully built!"
    log_info "Installed to: $install_dir"
    echo ""
}

# 特殊库编译函数
build_openssl() {
    log_section "Building OpenSSL ${OPENSSL_VERSION}"

    local src_dir="$CROSS_BASE/src/openssl"
    local install_dir="$CROSS_BASE/install/openssl"

    cd "$CROSS_BASE/src"
    if [ ! -d "openssl" ]; then
        log_info "Downloading OpenSSL..."
        wget "${OPENSSL_URL}"
        tar -xf "openssl-${OPENSSL_VERSION}.tar.gz"
        mv "openssl-${OPENSSL_VERSION}" openssl
        rm -f "openssl-${OPENSSL_VERSION}.tar.gz"
    fi
    
    cd "$src_dir"
    make clean || true
    
    log_info "Configuring OpenSSL..."
    ./Configure linux-armv4 \
        --prefix=/usr \
        --openssldir=/usr/lib/ssl \
        --cross-compile-prefix= \
        shared \
        no-asm \
        $CFLAGS
    
    log_info "Compiling OpenSSL..."
    make -j${BUILD_JOBS:-$(nproc)}

    log_info "Installing OpenSSL..."
    make DESTDIR="$install_dir" install_sw install_ssldirs

    find "$install_dir" -type f > "$CROSS_BASE/install/openssl_files.list"
    log_info "File list saved to $CROSS_BASE/install/openssl_files.list"

    log_success "OpenSSL successfully built!"
    log_info "Installed to: $install_dir"
    echo ""
}

build_bzip2() {
    log_section "Building bzip2 ${BZIP2_VERSION}"

    local src_dir="$CROSS_BASE/src/bzip2"
    local install_dir="$CROSS_BASE/install/bzip2"
    
    cd "$CROSS_BASE/src"
    if [ ! -d "bzip2" ]; then
        log_info "Downloading bzip2..."
        wget "${BZIP2_URL}"
        tar -xf "bzip2-${BZIP2_VERSION}.tar.gz"
        mv "bzip2-${BZIP2_VERSION}" bzip2
        rm -f "bzip2-${BZIP2_VERSION}.tar.gz"
    fi
    
    cd "$src_dir"
    make clean || true
    
    # 修改 Makefile 使用交叉编译器
    log_info "Configuring bzip2..."
    sed -i \
        -e "s/CC=gcc/CC=$CROSS_CC/" \
        -e "s/AR=ar/AR=$CROSS_AR/" \
        -e "s/RANLIB=ranlib/RANLIB=$CROSS_RANLIB/" \
        Makefile
    sed -i \
        -e "s/all: libbz2.a bzip2 bzip2recover test/all: libbz2.a bzip2 bzip2recover/" \
        Makefile

    log_info "Compiling bzip2..."
    make -j${BUILD_JOBS:-$(nproc)} CFLAGS="$CFLAGS -fPIC"

    log_info "Installing bzip2..."
    make install PREFIX="$install_dir"/usr
    make -j${BUILD_JOBS:-$(nproc)} libbz2.a CFLAGS="$CFLAGS -fPIC"
    cp libbz2.a "$install_dir"/usr/lib/
    $CROSS_CC -shared -Wl,-soname,libbz2.so.1 -o "$install_dir/usr/lib/libbz2.so.1.0.8" \
        blocksort.o huffman.o crctable.o randtable.o compress.o decompress.o bzlib.o
    
    cd "$install_dir/usr/lib"
    ln -sf libbz2.so.1.0.8 libbz2.so.1.0
    ln -sf libbz2.so.1.0.8 libbz2.so.1
    ln -sf libbz2.so.1.0.8 libbz2.so
    
    find "$install_dir" -type f > "$CROSS_BASE/install/bzip2_files.list"
    log_info "File list saved to $CROSS_BASE/install/bzip2_files.list"

    log_success "bzip2 successfully built!"
    log_info "Installed to: $install_dir"
    echo ""
}

# 编译所有库
log_section "Starting cross-compilation of all libraries..."

# 1. zlib
build_library "zlib" "${ZLIB_URL}" "${ZLIB_VERSION}" ""

# 2. OpenSSL (特殊处理)
build_openssl

# 3. libffi
build_library "libffi" "${LIBFFI_URL}" "${LIBFFI_VERSION}" ""

# 4. SQLite
build_library "sqlite" "${SQLITE_URL}" "autoconf-3500000" \
    "--enable-threadsafe --enable-fts5"

# 5. ncurses
build_library "ncurses" "${NCURSES_URL}" "${NCURSES_VERSION}" \
    "--with-shared --with-termlib --with-terminfo-dirs=\"/usr/share/terminfo:/lib/terminfo:/etc/terminfo\" --with-pkg-config-libdir=$HOME/cross-compile/install/ncurses/lib/pkgconfig --without-debug --enable-widec --enable-pc-files --enable-overwrite --with-strip-program=$HOME/x-tools/arm-ev3-linux-gnueabi/bin/arm-ev3-linux-gnueabi-strip"

# 6. readline
build_library "readline" "${READLINE_URL}" "${READLINE_VERSION}" \
    "--with-curses"

# 7. bzip2 (特殊处理)
build_bzip2

# 8. xz
build_library "xz" "${XZ_URL}" "${XZ_VERSION}" \
    "--enable-shared --disable-static"

# 9. gdbm
build_library "gdbm" "${GDBM_URL}" "${GDBM_VERSION}" \
    "--enable-shared --disable-static --enable-libgdbm-compat"

# 10. util-linux (仅用于提供 libuuid)
build_library "util-linux" "${UTIL_LINUX_URL}" "${UTIL_LINUX_VERSION}" \
    "--disable-all-programs --enable-libuuid --disable-year2038"

log_success "All libraries successfully built!"
