#!/bin/bash

set -e

source ./setup_environment.sh

# 检查必要工具
check_prerequisites() {
    log_section "Checking prerequisites..."

    local missing_tools=()
    
    for tool in arm-ev3-linux-gnueabi-gcc wget tar rsync dpkg-deb; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        log_error "Missing required tool(s): ${missing_tools[*]}"
        log_info "Please install them first."
        log_info "Note that arm-ev3-linux-gnueabi-* toolchain can be built using crosstool-ng and should be installed to $HOME/cross-toolchain/arm-ev3-linux-gnueabi/bin."
        exit 1
    fi
    
    log_success "All prerequisites satisfied."
}

# 显示选项菜单
show_menu() {
    echo ""
    log_section "Build Options"
    echo "1) Libraries only"
    echo "2) Libraries and Python"
    echo "3) Libraries and GCC"
    echo "4) GCC only"
    echo "5) All (Libraries, Python and GCC)"
    echo ""
    echo -n "Please choose [1-5]: "
    read -r choice
}

# 构建依赖库
build_libraries() {
    log_section "Step 1: Setting up the environment"
    bash setup_environment.sh

    log_section "Step 2: Building libraries"
    bash build_libraries.sh
    
    log_section "Step 3: Creating DEB packages for libraries"
    bash create_libraries_deb.sh
}

# 构建Python
build_python() {
    log_section "Step 4: Building Python"
    bash build_python.sh
    
    log_section "Step 5: Creating DEB package for Python"
    bash create_python_deb.sh
}

# 构建GCC
build_gcc() {
    log_section "Step 6: Building GCC"
    bash build_gcc.sh

    log_section "Step 7: Creating DEB package for GCC"
    bash create_gcc_deb.sh
}

# 显示构建完成信息
show_completion_info() {
    log_section "Build completed"
    log_success "Selected packages have been built successfully."

    log_info "Generated DEB packages:"
    ls -la ~/cross-compile/packages/*.deb
    
    log_section "Installation Instructions"
    log_info "To install the packages, follow these steps:"
    log_info "1. Copy all .deb files to your EV3 device / Docker container."
    log_info "2. Install libraries first: sudo dpkg -i --force-overwrite <...>.deb"
    log_info "3. Install Python: sudo dpkg -i --force-overwrite python3*armel.deb"
    log_info "4. Install GCC: sudo dpkg -i --force-overwrite gcc*armel.deb"
}

# 执行各个构建步骤
main() {
    log_section "Build Python 3.13.5 (and some libraries), GCC 13.3.0 for Lego EV3"
    log_info "Target: Debian 10 Buster (armel)"
    log_info "For Docker image: growflavor/ev3images:ev3dev10imgv02b"
    log_info "Host: $(uname -n)"
    log_info "Date: $(date)"

    check_prerequisites

    show_menu

    case $choice in
        1)
            log_info "Choice: Libraries only"
            build_libraries
            ;;
        2)
            log_info "Choice: Libraries and Python"
            build_libraries
            build_python
            ;;
        3)
            log_info "Choice: Libraries and GCC"
            build_libraries
            build_gcc
            ;;
        4)
            log_info "Choice: GCC only"
            log_section "Step 1: Setting up the environment"
            bash setup_environment.sh
            build_gcc
            ;;
        5)
            log_info "Choice: All (Libraries, Python and GCC)"
            build_libraries
            build_python
            build_gcc
            ;;
        *)
            log_error "Invalid choice: $choice"
            exit 1
            ;;
    esac

    show_completion_info
}

# 运行主函数
main "$@"