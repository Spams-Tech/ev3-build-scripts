#!/bin/bash

# 软件包版本配置
export GCC_VERSION="13.3.0"
export ZLIB_VERSION="1.3.1"
export OPENSSL_VERSION="3.5.0"
export LIBFFI_VERSION="3.4.8"
export SQLITE_VERSION="3.50.0"
export NCURSES_VERSION="6.5"
export READLINE_VERSION="8.2"
export BZIP2_VERSION="1.0.8"
export XZ_VERSION="5.8.1"
export GDBM_VERSION="1.25"
export UTIL_LINUX_VERSION="2.40.4"
export OPENBLAS_VERSION="0.3.29"
export PYTHON_VERSION="3.13.5"

# 软件包下载链接
export GCC_URL="https://ftp.gnu.org/gnu/gcc/gcc-${GCC_VERSION}/gcc-${GCC_VERSION}.tar.gz"
export ZLIB_URL="https://zlib.net/zlib-${ZLIB_VERSION}.tar.gz"
export OPENSSL_URL="https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz"
export LIBFFI_URL="https://github.com/libffi/libffi/releases/download/v${LIBFFI_VERSION}/libffi-${LIBFFI_VERSION}.tar.gz"
export SQLITE_URL="https://www.sqlite.org/2025/sqlite-autoconf-3500000.tar.gz" # 命名方式不同
export NCURSES_URL="https://ftp.gnu.org/pub/gnu/ncurses/ncurses-${NCURSES_VERSION}.tar.gz"
export READLINE_URL="https://ftp.gnu.org/gnu/readline/readline-${READLINE_VERSION}.tar.gz"
export BZIP2_URL="https://sourceware.org/pub/bzip2/bzip2-${BZIP2_VERSION}.tar.gz"
export XZ_URL="https://tukaani.org/xz/xz-${XZ_VERSION}.tar.gz"
export GDBM_URL="https://ftp.gnu.org/gnu/gdbm/gdbm-${GDBM_VERSION}.tar.gz"
export UTIL_LINUX_URL="https://mirrors.edge.kernel.org/pub/linux/utils/util-linux/v2.40/util-linux-${UTIL_LINUX_VERSION}.tar.gz"
export OPENBLAS_URL="https://github.com/OpenMathLib/OpenBLAS/releases/download/v${OPENBLAS_VERSION}/OpenBLAS-${OPENBLAS_VERSION}.tar.gz"
export PYTHON_URL="https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tar.xz"
