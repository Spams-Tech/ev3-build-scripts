#!/bin/bash

# 定义颜色和输出函数
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[0;33m'
export BLUE='\033[0;34m'
export PURPLE='\033[0;35m'
export CYAN='\033[0;36m'
export NC='\033[0m' # No Color

# 日志输出函数
log_info() {
    local msg="[INFO] $1"
    echo -e "${BLUE}$msg${NC}"
    echo "$(date +"%Y-%m-%d %H:%M:%S") $msg" >> "$LOG_FILE"
}

log_success() {
    local msg="[SUCCESS] $1"
    echo -e "${GREEN}$msg${NC}"
    echo "$(date +"%Y-%m-%d %H:%M:%S") $msg" >> "$LOG_FILE"
}

log_warning() {
    local msg="[WARNING] $1"
    echo -e "${YELLOW}$msg${NC}"
    echo "$(date +"%Y-%m-%d %H:%M:%S") $msg" >> "$LOG_FILE"
}

log_error() {
    local msg="[ERROR] $1"
    echo -e "${RED}$msg${NC}"
    echo "$(date +"%Y-%m-%d %H:%M:%S") $msg" >> "$LOG_FILE"
}

log_section() {
    local msg="$1"
    echo -e "\n${CYAN}===========================================${NC}"
    echo -e "${CYAN}$msg${NC}"
    echo -e "${CYAN}===========================================${NC}\n"
    echo "$(date +"%Y-%m-%d %H:%M:%S") =========== $msg ===========" >> "$LOG_FILE"
}

# 创建工作目录结构
mkdir -p ~/cross-compile/{src,build,packages,logs}
mkdir -p ~/cross-compile/install/{zlib,openssl,libffi,sqlite,ncurses,readline,bzip2,xz,gdbm,util-linux,python,gcc,openblas}

# 设置基础环境变量
export CROSS_BASE=$HOME/cross-compile
export CROSS_HOST=arm-ev3-linux-gnueabi
export CROSS_CC=arm-ev3-linux-gnueabi-gcc
export CROSS_CXX=arm-ev3-linux-gnueabi-g++
export CROSS_AR=arm-ev3-linux-gnueabi-ar
export CROSS_STRIP=arm-ev3-linux-gnueabi-strip
export CROSS_RANLIB=arm-ev3-linux-gnueabi-ranlib
export CROSS_FC=arm-ev3-linux-gnueabi-gfortran

# 通用编译参数
export CFLAGS="-O2 -mcpu=arm926ej-s"
export CXXFLAGS="$CFLAGS"

log_success "Environment setup completed!"
log_info "Work directory: $CROSS_BASE"
