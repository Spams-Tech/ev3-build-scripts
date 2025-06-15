# EV3 Build Scripts

A collection of scripts for building the latest versions of Python, GCC, and related libraries for the LEGO EV3 device. These scripts allow you to cross-compile packages to run on your EV3 brick.

## Build Target

These scripts target the following environment:
- Target system: Debian 10 Buster (armel)
- Docker image: growflavor/ev3images:ev3dev10imgv02b

## Included Software and Versions

### Main Components
- Python 3.13.5
- GCC 13.3.0

### Libraries
- zlib 1.3.1
- OpenSSL 3.5.0
- libffi 3.4.8
- SQLite 3.50.0
- ncurses 6.5
- readline 8.2
- bzip2 1.0.8
- xz 5.8.1
- gdbm 1.25
- util-linux 2.40.4 (used only for libuuid)
- OpenBLAS 0.3.29 [Optional]

## Usage

0. This script is only tested on Ubuntu 22.04 and Ubuntu 24.04. It may not work on other distributions without modification.
   Make sure you have the following packages installed:
   ```
   sudo apt install -y \
       wget tar rsync \
       build-essential
   ```
   
1. Ensure you have the necessary cross-compilation toolchain `arm-ev3-linux-gnueabi-*` installed.
   You can create it using **crosstool-ng**, and add `$HOME/x-tools/arm-ev3-linux-gnueabi/bin` to your PATH.
   

2. Run the main script:
   ```
   chmod +x full.sh
   ./full.sh
   ```
   Follow the prompts to select the components you want to build. The script will download, configure, and compile the selected packages.

## Installation Instructions

After compilation, the generated DEB packages are located in the `~/cross-compile/packages/` directory.

To install the packages, follow these steps:
1. Copy all .deb files to your EV3 device or Docker container
2. Install libraries first: `sudo dpkg -i --force-overwrite <...>.deb`
3. Install Python: `sudo dpkg -i --force-overwrite python3*.deb`
4. Install GCC: `sudo dpkg -i --force-overwrite gcc*.deb`

## Warning

These scripts are **EXPERIMENTAL** and may not work as expected. **Installing the generated packages will overwrite some system packages, which may cause system instability or breakage. Proceed at your own risk.**

## License

**MIT License**, see `LICENSE` file for details.
