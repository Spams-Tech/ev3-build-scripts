#!/bin/bash

set -e

source ./setup_environment.sh

declare -A packaged_files

# 清理已打包文件记录
clear_packaged_files() {
    unset packaged_files
    declare -g -A packaged_files
}

# 检查文件是否已被打包
is_file_packaged() {
    local file_path=$1
    [ -n "${packaged_files[$file_path]}" ]
}

# 标记文件已被打包
mark_file_as_packaged() {
    local file_path=$1
    local package_name=$2
    packaged_files[$file_path]=$package_name
}

# 智能复制文件，避免重复打包
smart_copy() {
    local src=$1
    local dest=$2
    local pkg_name=$3

    # 仅当文件未被打包时才复制
    if ! is_file_packaged "$src"; then
        mkdir -p "$(dirname "$dest")"
        cp -P "$src" "$dest"
        mark_file_as_packaged "$src" "$pkg_name"
        return 0
    else
        log_info "Skipping file already packaged in ${packaged_files[$src]}: $src"
        return 1
    fi
}

# 创建库的运行时 DEB 包
create_runtime_deb() {
    local lib_name=$1
    local version=$2
    local description=$3
    local dependencies=$4
    local runtime_pkg_name=$5  # 运行时包名
    local control_extra=${6:-""}  # 额外的控制文件配置，可选参数

    log_section "Creating $runtime_pkg_name runtime DEB package"

    local install_dir="$CROSS_BASE/install/$lib_name"
    local pkg_dir="$CROSS_BASE/packages/${runtime_pkg_name}_${version}+spams1_armel"

    # 检查安装目录是否存在
    if [ ! -d "$install_dir" ]; then
        log_error "$lib_name install directory $install_dir does not exist!"
        return 1
    fi
    
    # 清理并创建包目录结构
    log_info "Creating package directory structure..."
    rm -rf "$pkg_dir"
    mkdir -p "$pkg_dir/DEBIAN"
    mkdir -p "$pkg_dir/lib/arm-linux-gnueabi"

    # 复制共享库文件到包目录
    log_info "Copying shared library files to package directory..."
    if [ -d "$install_dir/usr/lib" ]; then
        # 复制实际的共享库文件 (.so*)
        find "$install_dir/usr/lib" -type f -name "*.so*" -not -name "*.a" -not -name "*.la" | while read so_file; do
            smart_copy "$so_file" "$pkg_dir/lib/arm-linux-gnueabi/$(basename "$so_file")" "$runtime_pkg_name"
        done

        # 复制共享库的符号链接 (*.so.*)
        find "$install_dir/usr/lib" -type l -name "*.so.*" | while read link; do
            smart_copy "$link" "$pkg_dir/lib/arm-linux-gnueabi/$(basename "$link")" "$runtime_pkg_name"
        done
    fi

    # 计算安装大小
    local installed_size=$(du -sk "$pkg_dir/lib" | cut -f1)

    # 创建控制文件
    log_info "Creating control file..."
    cat > "$pkg_dir/DEBIAN/control" << EOF
Package: ${runtime_pkg_name}
Version: ${version}+spams1
Section: libs
Priority: optional
Architecture: armel
Maintainer: spamstech <hi@spams.tech>
Installed-Size: ${installed_size}
Description: ${description}
 Cross-compiled ${lib_name} library for ARM architecture (armel).
 This package contains the shared runtime libraries.
EOF
    
    # 如果有依赖关系，添加到控制文件
    if [ -n "$dependencies" ]; then
        echo "Depends: $dependencies" >> "$pkg_dir/DEBIAN/control"
    fi
    
    # 添加额外的控制文件配置
    if [ -n "$control_extra" ]; then
        echo -e "$control_extra" >> "$pkg_dir/DEBIAN/control"
    fi

    # 创建 postinst 脚本
    log_info "Creating postinst script..."
    cat > "$pkg_dir/DEBIAN/postinst" << 'EOF'
#!/bin/bash
set -e
if [ "$1" = "configure" ]; then
    ldconfig
fi
EOF
    chmod 755 "$pkg_dir/DEBIAN/postinst"

    # 创建 postrm 脚本
    log_info "Creating postrm script..."
    cat > "$pkg_dir/DEBIAN/postrm" << 'EOF'
#!/bin/bash
set -e
if [ "$1" = "remove" ] || [ "$1" = "purge" ]; then
    ldconfig
fi
EOF
    chmod 755 "$pkg_dir/DEBIAN/postrm"

    # 构建 DEB 包
    log_info "Building DEB package..."
    dpkg-deb -Zgzip --uniform-compression --build "$pkg_dir"

    log_success "Created: ${pkg_dir}.deb"

    # 验证包
    log_info "Package info:"
    dpkg-deb -I "${pkg_dir}.deb"
    echo ""

    return 0
}

# 创建库的开发 DEB 包
create_dev_deb() {
    local lib_name=$1
    local version=$2
    local description=$3
    local dependencies=$4
    local runtime_pkg_name=$5  # 运行时包名
    local dev_pkg_name="${runtime_pkg_name}-dev"  # 开发包名
    local control_extra=${6:-""}  # 额外的控制文件配置，可选参数

    log_section "Creating $dev_pkg_name development DEB package"

    local install_dir="$CROSS_BASE/install/$lib_name"
    local pkg_dir="$CROSS_BASE/packages/${dev_pkg_name}_${version}+spams1_armel"

    # 检查安装目录是否存在
    if [ ! -d "$install_dir" ]; then
        log_error "$lib_name install directory $install_dir does not exist!"
        return 1
    fi

    # 清理并创建包目录结构
    log_info "Creating package directory structure..."
    rm -rf "$pkg_dir"
    mkdir -p "$pkg_dir/DEBIAN"
    mkdir -p "$pkg_dir/usr/include"
    mkdir -p "$pkg_dir/usr/lib/arm-linux-gnueabi"
    mkdir -p "$pkg_dir/usr/lib/arm-linux-gnueabi/pkgconfig"
    mkdir -p "$pkg_dir/usr/share"

    # 复制开发文件到包目录
    log_info "Copying development files to package directory..."

    # 复制头文件
    if [ -d "$install_dir/usr/include" ]; then
        # 逐个复制头文件以便跟踪
        find "$install_dir/usr/include" -type f | while read header_file; do
            rel_path=${header_file#$install_dir/usr/include/}
            dest_file="$pkg_dir/usr/include/$rel_path"
            smart_copy "$header_file" "$dest_file" "$dev_pkg_name"
        done
    fi

    # 复制静态库和链接文件
    if [ -d "$install_dir/usr/lib" ]; then
        # 复制静态库和链接库
        find "$install_dir/usr/lib" -type f -name "*.a" -o -name "*.la" | while read file; do
            smart_copy "$file" "$pkg_dir/usr/lib/arm-linux-gnueabi/$(basename "$file")" "$dev_pkg_name"
        done

        # 复制符号链接
        find "$install_dir/usr/lib" -type l -name "*.so" | while read link; do
            smart_copy "$link" "$pkg_dir/usr/lib/arm-linux-gnueabi/$(basename "$link")" "$dev_pkg_name"
        done
    fi

    # 复制pkgconfig文件
    if [ -d "$install_dir/usr/lib/pkgconfig" ]; then
        find "$install_dir/usr/lib/pkgconfig" -name "*.pc" | while read pc_file; do
            smart_copy "$pc_file" "$pkg_dir/usr/lib/arm-linux-gnueabi/pkgconfig/$(basename "$pc_file")" "$dev_pkg_name"
        done
    fi

    # 计算安装大小
    local installed_size=$(du -sk "$pkg_dir/usr" | cut -f1)

    # 创建控制文件
    log_info "Creating control file..."
    cat > "$pkg_dir/DEBIAN/control" << EOF
Package: ${dev_pkg_name}
Version: ${version}+spams1
Section: libdevel
Priority: optional
Architecture: armel
Maintainer: spamstech <hi@spams.tech>
Installed-Size: ${installed_size}
Depends: ${dependencies}
Description: ${description} - development files
 Cross-compiled ${lib_name} library for ARM architecture (armel).
 This package contains the development files.
EOF

    # 添加额外的控制文件配置
    if [ -n "$control_extra" ]; then
        echo -e "$control_extra" >> "$pkg_dir/DEBIAN/control"
    fi

    # 构建 DEB 包
    log_info "Building DEB package..."
    dpkg-deb -Zgzip --uniform-compression --build "$pkg_dir"

    log_success "Created: ${pkg_dir}.deb"

    # 验证包
    log_info "Package info:"
    dpkg-deb -I "${pkg_dir}.deb"
    echo ""

    return 0
}

# 创建二进制工具包
create_bin_deb() {
    local lib_name=$1
    local version=$2
    local description=$3
    local dependencies=$4
    local bin_pkg_name=$5  # 二进制包名

    log_section "Creating $bin_pkg_name binary DEB package"

    local install_dir="$CROSS_BASE/install/$lib_name"
    local pkg_dir="$CROSS_BASE/packages/${bin_pkg_name}_${version}+spams1_armel"

    # 检查安装目录是否存在
    if [ ! -d "$install_dir" ]; then
        log_error "$lib_name install directory $install_dir does not exist!"
        return 1
    fi

    # 清理并创建包目录结构
    log_info "Creating package directory structure..."
    rm -rf "$pkg_dir"
    mkdir -p "$pkg_dir/DEBIAN"
    mkdir -p "$pkg_dir/usr/bin"
    mkdir -p "$pkg_dir/usr/share"

    # 处理SSL配置目录
    if [ "$lib_name" = "openssl" ]; then
        mkdir -p "$pkg_dir/usr/lib/ssl"
    fi

    # 复制二进制文件到包目录
    log_info "Copying binary files to package directory..."
    if [ -d "$install_dir/usr/bin" ]; then
        find "$install_dir/usr/bin" -type f | while read bin_file; do
            smart_copy "$bin_file" "$pkg_dir/usr/bin/$(basename "$bin_file")" "$bin_pkg_name"
        done
    fi

    # 复制文档和man页
    if [ -d "$install_dir/usr/share/man" ]; then
        find "$install_dir/usr/share/man" -type f | while read man_file; do
            rel_path=${man_file#$install_dir/usr/share/man/}
            dest_file="$pkg_dir/usr/share/man/$rel_path"
            smart_copy "$man_file" "$dest_file" "$bin_pkg_name"
        done
    fi

    if [ "$lib_name" = "openssl" ] && [ -d "$install_dir/usr/lib/ssl" ]; then
        log_info "Copying SSL configuration files..."
        cp -r "$install_dir/usr/lib/ssl"/* "$pkg_dir/usr/lib/ssl/" 2>/dev/null || true
    fi

    # 计算安装大小
    local installed_size=$(du -sk "$pkg_dir/usr" | cut -f1)

    # 创建控制文件
    log_info "Creating control file..."
    cat > "$pkg_dir/DEBIAN/control" << EOF
Package: ${bin_pkg_name}
Version: ${version}+spams1
Section: utils
Priority: optional
Architecture: armel
Maintainer: spamstech <hi@spams.tech>
Installed-Size: ${installed_size}
Depends: ${dependencies}
Description: ${description} - utilities
 Cross-compiled ${lib_name} utilities for ARM architecture (armel).
 This package contains utility programs.
EOF

    # 构建 DEB 包
    log_info "Building DEB package..."
    dpkg-deb -Zgzip --uniform-compression --build "$pkg_dir"

    log_success "Created: ${pkg_dir}.deb"

    # 验证包
    log_info "Package info:"
    dpkg-deb -I "${pkg_dir}.deb"
    echo ""

    return 0
}

# 创建所有库的 DEB 包
log_section "Creating DEB packages for all libraries"

# 1. zlib
clear_packaged_files
create_runtime_deb "zlib" "1:${ZLIB_VERSION}" "Compression library - runtime" "libc6" "zlib1g"
create_dev_deb "zlib" "1:${ZLIB_VERSION}" "Compression library" "libc6,zlib1g (= 1:${ZLIB_VERSION}+spams1)" "zlib1g"

# 2. OpenSSL - 分为libssl3运行时库，libcrypto3运行时库，以及libssl-dev开发包和openssl二进制工具包
clear_packaged_files
create_runtime_deb "openssl" "${OPENSSL_VERSION}" "Secure Sockets Layer toolkit - libssl runtime" "libc6,libatomic1" "libssl3"
create_dev_deb "openssl" "${OPENSSL_VERSION}" "Secure Sockets Layer toolkit - development files" "libc6,libssl3 (= ${OPENSSL_VERSION}+spams1)" "libssl"
create_bin_deb "openssl" "${OPENSSL_VERSION}" "Secure Sockets Layer toolkit - utilities" "libc6,libssl3 (= ${OPENSSL_VERSION}+spams1)" "openssl"

# 3. libffi
clear_packaged_files
create_runtime_deb "libffi" "${LIBFFI_VERSION}" "Foreign Function Interface library runtime" "libc6" "libffi8"
create_dev_deb "libffi" "${LIBFFI_VERSION}" "Foreign Function Interface library" "libc6,libffi8 (= ${LIBFFI_VERSION}+spams1)" "libffi"

# 4. SQLite
clear_packaged_files
create_runtime_deb "sqlite" "${SQLITE_VERSION}" "SQLite 3 shared library" "libc6" "libsqlite3-0"
create_dev_deb "sqlite" "${SQLITE_VERSION}" "SQLite 3 shared library" "libc6,libsqlite3-0 (= ${SQLITE_VERSION}+spams1)" "libsqlite3"
create_bin_deb "sqlite" "${SQLITE_VERSION}" "SQLite 3 command line interface" "libc6,libsqlite3-0 (= ${SQLITE_VERSION}+spams1)" "sqlite3"

# 5. ncurses (包含libtinfo6依赖)
clear_packaged_files
create_runtime_deb "ncurses" "${NCURSES_VERSION}" "shared libraries for terminal handling" "libc6" "libncursesw6" "Provides: libtinfo6\nReplaces: libtinfo6"
create_dev_deb "ncurses" "${NCURSES_VERSION}" "shared libraries for terminal handling" "libc6,libncursesw6 (= ${NCURSES_VERSION}+spams1)" "libncurses"
create_bin_deb "ncurses" "${NCURSES_VERSION}" "shared libraries for terminal handling - utilities" "libc6,libncursesw6 (= ${NCURSES_VERSION}+spams1)" "ncurses-bin"

# 6. readline
clear_packaged_files
create_runtime_deb "readline" "${READLINE_VERSION}" "GNU readline and history libraries, runtime" "libc6,libncursesw6 (>= ${NCURSES_VERSION}+spams1)" "libreadline8"
create_dev_deb "readline" "${READLINE_VERSION}" "GNU readline and history libraries" "libc6,libncurses-dev (>= ${NCURSES_VERSION}+spams1),libreadline8 (= ${READLINE_VERSION}+spams1)" "libreadline" "Provides: libreadline-gplv2-dev\nReplaces: libreadline-gplv2-dev"

# 7. bzip2
clear_packaged_files
create_runtime_deb "bzip2" "${BZIP2_VERSION}" "high-quality block-sorting file compressor library - runtime" "libc6" "libbz2-1.0"
create_dev_deb "bzip2" "${BZIP2_VERSION}" "high-quality block-sorting file compressor library" "libc6,libbz2-1.0 (= ${BZIP2_VERSION}+spams1)" "libbz2"
create_bin_deb "bzip2" "${BZIP2_VERSION}" "high-quality block-sorting file compressor" "libc6,libbz2-1.0 (= ${BZIP2_VERSION}+spams1)" "bzip2"

# 8. xz
clear_packaged_files
create_runtime_deb "xz" "${XZ_VERSION}" "XZ-format compression library" "libc6" "liblzma5"
create_dev_deb "xz" "${XZ_VERSION}" "XZ-format compression library" "libc6,liblzma5 (= ${XZ_VERSION}+spams1)" "liblzma"
create_bin_deb "xz" "${XZ_VERSION}" "XZ-format compression utilities" "libc6,liblzma5 (= ${XZ_VERSION}+spams1)" "xz-utils"

# 9. gdbm
clear_packaged_files
create_runtime_deb "gdbm" "${GDBM_VERSION}" "GNU dbm database routines (runtime version)" "libc6" "libgdbm6" "Provides: libgdbm-compat4\nReplaces: libgdbm-compat4"
create_dev_deb "gdbm" "${GDBM_VERSION}" "GNU dbm database routines" "libc6,libgdbm6 (= ${GDBM_VERSION}+spams1)" "libgdbm" "Provides: libgdbm-compat-dev\nReplaces: libgdbm-compat-dev"

# 10. util-linux (仅用于提供 libuuid)
clear_packaged_files
create_runtime_deb "util-linux" "${UTIL_LINUX_VERSION}" "miscellaneous system utilities - runtime libraries" "libc6" "libuuid1"
create_dev_deb "util-linux" "${UTIL_LINUX_VERSION}" "miscellaneous system utilities - development files" "libc6,libuuid1 (= ${UTIL_LINUX_VERSION}+spams1)" "uuid"

log_success "All DEB packages created successfully!"
log_info "Packages location: $CROSS_BASE/packages/"
ls -la "$CROSS_BASE/packages/"*.deb
