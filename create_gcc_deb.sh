#!/bin/bash

set -e

source ./setup_environment.sh

create_gcc_deb() {
    local gcc_version="13.3.0"
    local install_dir="$CROSS_BASE/install/gcc"
    local pkg_dir="$CROSS_BASE/packages/gcc_${gcc_version}_armel"

    log_section "Creating GCC $gcc_version DEB package"

    if [ ! -d "$install_dir" ]; then
        log_error "GCC install directory $install_dir does not exist!"
        return 1
    fi

    # 清理并创建包目录
    log_info "Creating package directory structure..."
    rm -rf "$pkg_dir"
    mkdir -p "$pkg_dir/DEBIAN"

    # 复制GCC安装文件
    log_info "Copying files to package directory..."
    rsync -av "$install_dir/" "$pkg_dir/"

    # 计算安装大小
    local installed_size=$(du -sk "$pkg_dir/usr" | cut -f1)

    # 创建控制文件
    log_info "Creating control file..."
    cat > "$pkg_dir/DEBIAN/control" << EOF
Package: gcc-spams
Version: ${gcc_version}
Section: devel
Priority: optional
Architecture: armel
Maintainer: spamstech <hi@spams.tech>
Installed-Size: ${installed_size}
Depends: libc6
Description: GNU C compiler (cross-compiled for ARM)
 This is the GNU C compiler, a fairly portable optimizing compiler for C.
 This package contains a version of GCC that can compile code for ARM
 architecture (armel).
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

create_gcc_deb
log_success "GCC DEB package created successfully!"
log_info "Package location: $CROSS_BASE/packages/"
ls -la "$CROSS_BASE/packages/gcc"*.deb
