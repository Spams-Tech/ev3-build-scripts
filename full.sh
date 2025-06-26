#!/bin/bash

set -e

TOTAL_START_TIME=$(date +%s)

handle_interrupt() {
    echo ""
    log_error "Build interrupted by user (Ctrl+C)."
    log_info "The build logs have been saved to $LOG_FILE."
    exit 130
}

# 注册SIGINT信号处理
trap handle_interrupt SIGINT

export LOG_DIR=~/cross-compile/logs
export LOG_FILE="$LOG_DIR/build_$(date +%Y%m%d_%H%M%S).log"

source ./setup_environment.sh

# 导入配置文件
if [ -f "./config.sh" ]; then
    source ./config.sh
else
    log_error "Configuration file config.sh not found!"
    log_error "Please download the configuration file from the repository."
    exit 1
fi

# 显示帮助信息
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Available options:"
    echo "  -h, --help            Display this help message"
    echo "  -j, --jobs N          Set the number of -j to N (default: number of CPU cores)"
    echo "  -q, --quiet           Build in quiet mode (default: no)"
    echo "  -l, --libraries       Build only libraries"
    echo "  -g, --gcc             Build only GCC"
    echo "  -p, --python          Build libraries and Python"
    echo "  -a, --all             Build all components (libraries, Python, and GCC)"
    echo "  -o, --openblas        Also build OpenBLAS (default: no)"
    echo "  -c, --clean           Clean build directories after completion (default: no)"
    echo ""
    echo "Examples:"
    echo "  $0                    Display an interactive menu"
    echo "  $0 -a -j 8 -o         Build all components with -j8 and OpenBLAS"
    echo "  $0 -l -q              Build libraries in quiet mode"
    echo ""
}

# 首先检查是否有帮助选项，如果有则立即显示帮助并退出
for arg in "$@"; do
    if [ "$arg" = "-h" ] || [ "$arg" = "--help" ]; then
        show_help
        exit 0
    fi
done

# 设置默认参数
JOBS=${DEFAULT_JOBS:-$(nproc)}
VERBOSE=${DEFAULT_VERBOSE:-1}
BUILD_MODE=""
BUILD_OPENBLAS=0
CLEAN_AFTER_BUILD=0

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            shift
            ;;
        -j|--jobs)
            if [[ $# -gt 1 ]] && [[ $2 =~ ^[0-9]+$ ]]; then
                JOBS="$2"
                shift 2
            else
                log_error "-j/--jobs requires a numeric argument!"
                show_help
                exit 1
            fi
            ;;
        -q|--quiet)
            VERBOSE=0
            shift
            ;;
        -l|--libraries)
            if [ -n "$BUILD_MODE" ]; then
                log_error "-l/--libraries, -g/--gcc, -p/--python, -a/--all cannot be used together!"
                show_help
                exit 1
            fi
            BUILD_MODE="libraries"
            shift
            ;;
        -g|--gcc)
            if [ -n "$BUILD_MODE" ]; then
                log_error "-l/--libraries, -g/--gcc, -p/--python, -a/--all cannot be used together!"
                show_help
                exit 1
            fi
            BUILD_MODE="gcc"
            shift
            ;;
        -p|--python)
            if [ -n "$BUILD_MODE" ]; then
                log_error "-l/--libraries, -g/--gcc, -p/--python, -a/--all cannot be used together!"
                show_help
                exit 1
            fi
            BUILD_MODE="python"
            shift
            ;;
        -a|--all)
            if [ -n "$BUILD_MODE" ]; then
                log_error "-l/--libraries, -g/--gcc, -p/--python, -a/--all cannot be used together!"
                show_help
                exit 1
            fi
            BUILD_MODE="all"
            shift
            ;;
        -o|--openblas)
            BUILD_OPENBLAS=1
            shift
            ;;
        -c|--clean)
            CLEAN_AFTER_BUILD=1
            shift
            ;;
        *)
            log_error "Invalid option: $1"
            show_help
            exit 1
            ;;
    esac
done

export BUILD_JOBS=$JOBS
export BUILD_VERBOSE=$VERBOSE

format_time() {
    local seconds=$1
    local hours=$((seconds / 3600))
    local minutes=$(( (seconds % 3600) / 60 ))
    local secs=$((seconds % 60))

    if [ $hours -gt 0 ]; then
        printf "%02dh%02dm%02ds" $hours $minutes $secs
    elif [ $minutes -gt 0 ]; then
        printf "%02dm %02ds" $minutes $secs
    else
        printf "%02ds" $secs
    fi
}

show_build_time() {
    local start=$1
    local task=$2
    local duration=$(($(date +%s) - start))
    log_info "The command '${task}' has completed and took $(format_time $duration)."
}

execute_build_command() {
    local command=$1
    local desc=$2
    log_info "$desc"
    local start_time=$(date +%s)

    if [ "$BUILD_VERBOSE" -eq 1 ]; then
        # 详细模式：直接执行命令并显示所有输出，同时保存到日志文件
        $command 2>&1 | tee -a "$LOG_FILE"
    else
        # 安静模式：直接将输出重定向到日志文件，仅在错误时显示
        if ! $command >> "$LOG_FILE" 2>&1; then
            log_error "The command '$command' failed. See the log file for details."
            return 1
        fi
    fi

    show_build_time "$start_time" "$command"
}

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
        log_info "Note that arm-ev3-linux-gnueabi-* toolchain can be built using crosstool-ng and should be installed to $HOME/x-tools/arm-ev3-linux-gnueabi/bin."
        exit 1
    fi
    
    log_success "All prerequisites satisfied."
}

# 显示选项菜单
show_menu() {
    echo ""
    log_section "Build Options"
    echo "1) Libraries only"
    echo "2) GCC only"
    echo "3) Libraries and Python"
    echo "4) All (Libraries, Python and GCC)"
    echo ""
    echo -n "Please select an option [1-4]: "
    read -r choice

    case $choice in
        1) BUILD_MODE="libraries" ;;
        2) BUILD_MODE="gcc" ;;
        3) BUILD_MODE="python" ;;
        4) BUILD_MODE="all" ;;
        *)
            log_error "Invalid option: $choice"
            show_help
            exit 1
            ;;
    esac

    # 询问是否构建OpenBLAS
    ask_openblas
}

# 询问是否编译OpenBLAS
ask_openblas() {
    if [ -n "$BUILD_MODE" ] && [ "$BUILD_OPENBLAS" -eq 0 ]; then
        echo ""
        log_section "OpenBLAS Option"
        echo "Do you want to build OpenBLAS?"
        echo "1) Yes"
        echo "2) No"
        echo ""
        echo -n "Please select an option [1-2]: "
        read -r openblas_choice

        case $openblas_choice in
            1) BUILD_OPENBLAS=1 ;;
            2) BUILD_OPENBLAS=0 ;;
            *)
                log_error "Invalid option: $openblas_choice"
                show_help
                exit 1
                ;;
        esac
    fi
}

# 构建依赖库
build_libraries() {
    log_section "Step L-1: Building libraries"
    execute_build_command "bash build_libraries.sh" "Executing build script..."

    log_section "Step L-2: Creating DEB packages for libraries"
    execute_build_command "bash create_libraries_deb.sh" "Executing packaging script..."
}

# 构建Python
build_python() {
    log_section "Step P-1: Building Python"
    execute_build_command "bash build_python.sh" "Executing build script..."

    log_section "Step P-2: Creating DEB package for Python"
    execute_build_command "bash create_python_deb.sh" "Executing packaging script..."
}

# 构建GCC
build_gcc() {
    log_section "Step G-1: Building GCC"
    execute_build_command "bash build_gcc.sh" "Executing build script..."

    log_section "Step G-2: Creating DEB package for GCC"
    execute_build_command "bash create_gcc_deb.sh" "Executing packaging script..."
}

# 构建OpenBLAS
build_openblas() {
    log_section "Step O-1: Building OpenBLAS"
    execute_build_command "bash build_openblas.sh" "Executing build script..."

    log_section "Step O-2: Creating DEB package for OpenBLAS"
    execute_build_command "bash create_openblas_deb.sh" "Executing packaging script..."
}

# 清理构建目录
clean_build_directories() {
    if [ "$CLEAN_AFTER_BUILD" -eq 1 ]; then
        log_section "Cleaning build directories"
        log_info "Removing source, build and install directories..."

        # 保留packages和logs目录，清理其他目录
        rm -rf ~/cross-compile/src/* ~/cross-compile/build/* ~/cross-compile/install/*

        log_success "Build directories cleaned successfully."
    fi
}

# 显示构建完成信息
show_completion_info() {
    log_section "Build completed"
    log_success "Selected packages have been built successfully."

    log_info "Generated DEB packages:"
    ls -la ~/cross-compile/packages/*.deb

    local total_end_time=$(date +%s)
    local total_duration=$((total_end_time - TOTAL_START_TIME))
    log_section "Total Build Time: $(format_time $total_duration)"

    log_section "Installation Instructions"
    log_info "To install the packages, follow these steps:"
    log_info "1. Copy all .deb files to your EV3 device / Docker container."
    log_info "2. Install all packages: sudo dpkg -i *.deb"
    log_info "The build logs have been saved to $LOG_FILE."
}

# 执行各个构建步骤
main() {
    log_section "Build Python ${PYTHON_VERSION} (and some libraries), GCC ${GCC_VERSION} for Lego EV3"
    log_info "Target: Debian 10 Buster (armel)"
    log_info "For Docker image: growflavor/ev3images:ev3dev10imgv02b"
    log_info "Host: $(uname -n)"
    log_info "Date: $(date)"
    log_info "Threads: $BUILD_JOBS"
    log_info "Quiet mode: $([ "$BUILD_VERBOSE" -eq 1 ] && echo "OFF" || echo "ON")"
    log_info "Log file: $LOG_FILE"

    log_warning "THIS SCRIPT IS EXPERIMENTAL AND MAY NOT WORK AS EXPECTED!"
    log_warning "TO INSTALL THE GENERATED PACKAGES,"
    log_warning "YOU HAVE TO OVERWRITE SOME SYSTEM PACKAGES,"
    log_warning "WHICH MAY CAUSE SYSTEM INSTABILITY OR BREAKAGE."
    log_warning "PLEASE PROCEED AT YOUR OWN RISK!"

    check_prerequisites

    # 如果未指定构建模式，则显示菜单
    if [ -z "$BUILD_MODE" ]; then
        log_info "Press Enter to continue... or Ctrl+C to exit."
        read -r
        show_menu
    fi

    # 根据构建模式执行相应的构建步骤
    case $BUILD_MODE in
        "libraries")
            log_info "Building: Libraries only"
            build_libraries
            ;;
        "gcc")
            log_info "Building: GCC only"
            build_gcc
            ;;
        "python")
            log_info "Building: Libraries and Python"
            build_libraries
            build_python
            ;;
        "all")
            log_info "Building: All components (Libraries, Python and GCC)"
            build_libraries
            build_python
            build_gcc
            ;;
        *)
            log_error "Invalid build option: $BUILD_MODE"
            exit 1
            ;;
    esac

    if [ "$BUILD_OPENBLAS" -eq 1 ]; then
        log_info "Building OpenBLAS as requested..."
        build_openblas
    else
        log_info "Skipping OpenBLAS build..."
    fi

    show_completion_info

    clean_build_directories
}

# 运行主函数
main "$@"