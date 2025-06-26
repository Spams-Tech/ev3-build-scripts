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

## Prerequisites

1. This script is only tested on Ubuntu 22.04 and Ubuntu 24.04. It may not work on other distributions without modification.
   Make sure you have the following packages installed:
   ```
   sudo apt install -y \
       wget tar rsync \
       build-essential dpkg-dev
   ```
   
2. Ensure you have the necessary cross-compilation toolchain `arm-ev3-linux-gnueabi-*` installed.
   You can create it using **crosstool-ng**, and add `$HOME/x-tools/arm-ev3-linux-gnueabi/bin` to your PATH.

# Usage

The main script (`full.sh`) supports several command line options:

```
Usage: ./full.sh [OPTIONS]

Available options:
  -h, --help            Display this help message
  -j, --jobs N          Set the number of -j to N (default: number of CPU cores)
  -q, --quiet           Build in quiet mode (default: no)
  -l, --libraries       Build only libraries
  -g, --gcc             Build only GCC
  -p, --python          Build libraries and Python
  -a, --all             Build all components (libraries, Python, and GCC)
  -o, --openblas        Also build OpenBLAS (default: no)
  -c, --clean           Clean build directories after completion (default: no)
```

### Examples

```bash
# Display an interactive menu
./full.sh

# Build all components with 8 parallel jobs and include OpenBLAS
./full.sh -a -j 8 -o

# Build only libraries in quiet mode
./full.sh -l -q
```

### Interactive Mode

If you run the script without any build mode option (`-l`, `-g`, `-p`, `-a`), it will display an interactive menu for you to select which components to build.
The `-j N, --jobs N`, `-q, --quiet`, `-o, --openblas`, `-c, --clean` options are only effective when used with a build mode option mentioned above. If you only set them, you have to choose the build mode interactively later.

## Installation Instructions

After compilation, the generated DEB packages are located in the `~/cross-compile/packages/` directory.

To install the packages, follow these steps:
1. Copy all .deb files to your EV3 device or Docker container
2. Install all packages: `sudo dpkg -i *.deb`

## Logs

Build logs are saved to `~/cross-compile/logs/` directory, with the format `build_YYYYMMDD_HHMMSS.log`.

## Warning

These scripts are **EXPERIMENTAL** and may not work as expected. **Installing the generated packages will overwrite some system packages, which may cause system instability or breakage. Proceed at your own risk.**

## License

**MIT License**, see `LICENSE` file for details.

## Contributing

If you find any issues or have suggestions for improvements, feel free to open an [issue](https://github.com/Spams-Tech/ev3-build-scripts/issues) or submit a [pull request](https://github.com/Spams-Tech/ev3-build-scripts/pulls).