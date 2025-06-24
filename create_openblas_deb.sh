#!/bin/bash

set -e

source ./setup_environment.sh

create_openblas_runtime_deb() {
    local openblas_version="${OPENBLAS_VERSION}"
    local install_dir="$CROSS_BASE/install/openblas"
    local pkg_dir="$CROSS_BASE/packages/libopenblas-base_${openblas_version}+spams1_armel"

    log_section "Creating OpenBLAS runtime DEB package"

    # 检查安装目录是否存在
    if [ ! -d "$install_dir" ]; then
        log_error "OpenBLAS install directory $install_dir does not exist!"
        return 1
    fi

    # 清理并创建包目录
    log_info "Creating package directory structure..."
    rm -rf "$pkg_dir"
    mkdir -p "$pkg_dir/DEBIAN"
    mkdir -p "$pkg_dir/usr/lib/arm-linux-gnueabi"

    # 复制共享库文件
    log_info "Copying shared library files to package directory..."
    if [ -d "$install_dir/lib" ]; then
        find "$install_dir/lib" -type f -name "*.so*" -not -name "*.a" -not -name "*.la" | while read so_file; do
            cp -P "$so_file" "$pkg_dir/usr/lib/arm-linux-gnueabi/"
        done
    fi

    # 计算安装大小
    local installed_size=$(du -sk "$pkg_dir/usr" | cut -f1)

    # 创建控制文件
    log_info "Creating control file..."
    cat > "$pkg_dir/DEBIAN/control" << EOF
Package: libopenblas-base
Version: ${openblas_version}+spams1
Section: libs
Priority: optional
Architecture: armel
Maintainer: spamstech <hi@spams.tech>
Installed-Size: ${installed_size}
Depends: libc6
Description: Optimized BLAS (linear algebra) library based on OpenBLAS
 OpenBLAS is an optimized BLAS library based on GotoBLAS2 1.13 BSD version.
 Cross-compiled for ARM architecture (armel).
 This package contains the shared runtime libraries.
EOF

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

    # 显示包信息
    log_info "Package info:"
    dpkg-deb -I "${pkg_dir}.deb"

    return 0
}

create_openblas_dev_deb() {
    local openblas_version="${OPENBLAS_VERSION}"
    local install_dir="$CROSS_BASE/install/openblas"
    local pkg_dir="$CROSS_BASE/packages/libopenblas-dev_${openblas_version}+spams1_armel"

    log_section "Creating OpenBLAS development DEB package"

    # 检查安装目录是否存在
    if [ ! -d "$install_dir" ]; then
        log_error "OpenBLAS install directory $install_dir does not exist!"
        return 1
    fi

    # 清理并创建包目录
    log_info "Creating package directory structure..."
    rm -rf "$pkg_dir"
    mkdir -p "$pkg_dir/DEBIAN"
    mkdir -p "$pkg_dir/usr/include"
    mkdir -p "$pkg_dir/usr/lib/arm-linux-gnueabi"
    mkdir -p "$pkg_dir/usr/lib/arm-linux-gnueabi/pkgconfig"

    # 复制开发文件
    log_info "Copying development files to package directory..."

    # 复制头文件
    if [ -d "$install_dir/include" ]; then
        cp -r "$install_dir/include/"* "$pkg_dir/usr/include/"
    fi

    # 复制静态库和链接文件
    if [ -d "$install_dir/lib" ]; then
        # 复制静态库和链接库
        find "$install_dir/lib" -type f -name "*.a" -o -name "*.la" | while read file; do
            cp "$file" "$pkg_dir/usr/lib/arm-linux-gnueabi/"
        done

        # 复制符号链接
        find "$install_dir/lib" -type l -name "*.so" | while read link; do
            cp -P "$link" "$pkg_dir/usr/lib/arm-linux-gnueabi/"
        done
    fi

    # 复制pkgconfig文件
    if [ -d "$install_dir/lib/pkgconfig" ]; then
        cp "$install_dir/lib/pkgconfig/"*.pc "$pkg_dir/usr/lib/arm-linux-gnueabi/pkgconfig/" 2>/dev/null || true
    fi

    # 计算安装大小
    local installed_size=$(du -sk "$pkg_dir/usr" | cut -f1)

    # 创建控制文件
    log_info "Creating control file..."
    cat > "$pkg_dir/DEBIAN/control" << EOF
Package: libopenblas-dev
Version: ${openblas_version}+spams1
Section: libdevel
Priority: optional
Architecture: armel
Maintainer: spamstech <hi@spams.tech>
Installed-Size: ${installed_size}
Depends: libopenblas-base (= ${openblas_version}+spams1), libc6
Description: Optimized BLAS (linear algebra) library - development files
 OpenBLAS is an optimized BLAS library based on GotoBLAS2 1.13 BSD version.
 Cross-compiled for ARM architecture (armel).
 This package contains the development files.
EOF

    # 构建 DEB 包
    log_info "Building DEB package..."
    dpkg-deb -Zgzip --uniform-compression --build "$pkg_dir"

    log_success "Created: ${pkg_dir}.deb"

    # 显示包信息
    log_info "Package info:"
    dpkg-deb -I "${pkg_dir}.deb"

    return 0
}

# 创建 OpenBLAS 的运行时库和开发库包
create_openblas_runtime_deb
create_openblas_dev_deb

log_success "OpenBLAS DEB packages created successfully!"
log_info "Package location: $CROSS_BASE/packages/"
ls -la "$CROSS_BASE/packages/libopenblas"*.deb
