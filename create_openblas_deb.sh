#!/bin/bash

set -e

source ./setup_environment.sh

create_openblas_deb() {
    local openblas_version="0.3.29"
    local install_dir="$CROSS_BASE/install/openblas"
    local pkg_dir="$CROSS_BASE/packages/libopenblas_${openblas_version}_armel"

    log_section "Creating OpenBLAS $openblas_version DEB package"

    # 检查安装目录是否存在
    if [ ! -d "$install_dir" ]; then
        log_error "OpenBLAS install directory $install_dir does not exist!"
        return 1
    fi

    # 清理并创建包目录
    log_info "Creating package directory structure..."
    rm -rf "$pkg_dir"
    mkdir -p "$pkg_dir/DEBIAN"
    mkdir -p "$pkg_dir/usr"

    # 复制 OpenBLAS 安装文件
    log_info "Copying files to package directory..."
    rsync -av \
        --exclude='pkgconfig' \
        "$install_dir/" "$pkg_dir/usr/"

    # 如果有 pkgconfig 文件，放到正确位置
    if [ -d "$install_dir/lib/pkgconfig" ]; then
        mkdir -p "$pkg_dir/usr/lib/arm-linux-gnueabi/pkgconfig"
        cp "$install_dir/lib/pkgconfig"/* "$pkg_dir/usr/lib/arm-linux-gnueabi/pkgconfig/" 2>/dev/null || true
    fi

    # 移动库文件到 multiarch 目录
    if [ -d "$pkg_dir/usr/lib" ] && [ "$(ls -A $pkg_dir/usr/lib)" ]; then
        log_info "Moving library files to multiarch directory..."
        mkdir -p "$pkg_dir/usr/lib/arm-linux-gnueabi"
        find "$pkg_dir/usr/lib" -maxdepth 1 -name "*.so*" -exec mv {} "$pkg_dir/usr/lib/arm-linux-gnueabi/" \; 2>/dev/null || true
        find "$pkg_dir/usr/lib" -maxdepth 1 -name "*.a" -exec mv {} "$pkg_dir/usr/lib/arm-linux-gnueabi/" \; 2>/dev/null || true
        find "$pkg_dir/usr/lib" -maxdepth 1 -name "*.la" -exec mv {} "$pkg_dir/usr/lib/arm-linux-gnueabi/" \; 2>/dev/null || true
        find "$pkg_dir/usr/lib" -maxdepth 1 -name "lib*" -type d -exec mv {} "$pkg_dir/usr/lib/arm-linux-gnueabi/" \; 2>/dev/null || true
    fi

    # 计算安装大小
    local installed_size=$(du -sk "$pkg_dir/usr" | cut -f1)

    # 创建控制文件
    log_info "Creating control file..."
    cat > "$pkg_dir/DEBIAN/control" << EOF
Package: libopenblas-spams
Version: ${openblas_version}
Section: libs
Priority: optional
Architecture: armel
Maintainer: spamstech <hi@spams.tech>
Installed-Size: ${installed_size}
Depends: libc6
Description: Optimized BLAS (linear algebra) library based on OpenBLAS
 OpenBLAS is an optimized BLAS library based on GotoBLAS2 1.13 BSD version.
 Cross-compiled for ARM architecture (armel).
 This package contains the shared libraries and development files.
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
}

create_openblas_deb
log_success "OpenBLAS DEB package created successfully!"
log_info "Package location: $CROSS_BASE/packages/"
ls -la "$CROSS_BASE/packages/libopenblas"*.deb
