#!/usr/bin/env bash
# Install everything that is available as an rpm through the configured
# repos (UBI/CRB -> EPEL -> Rocky fallback -> Microsoft repo for VS Code).
set -euo pipefail

# Java toolchains. RHEL 9 ships full OpenJDK devel packages for all of
# these (JDK 25 since RHEL 9.8).
JAVA_PACKAGES=(
    java-1.8.0-openjdk-devel
    java-11-openjdk-devel
    java-17-openjdk-devel
    java-21-openjdk-devel
    java-25-openjdk-devel
)

TOOL_PACKAGES=(
    maven
    maven-openjdk21 # pin maven's JDK binding to 21 (it defaults to 17)
    git
    git-lfs
    code            # VS Code, from the Microsoft repo
    nodejs          # from the nodejs module stream enabled below
    npm
)

# Node.js comes as an AppStream module with no default stream on RHEL 9, so
# the major version must be enabled explicitly before installing. 22 is the
# newest LTS the UBI repos are guaranteed to carry, and satisfies the
# Cline CLI's >= 22 requirement (see 32-install-cline.sh).
NODEJS_STREAM=22

# C development toolchain, sized for working with the vscode-clangd
# extension (shipped via the vsix/ drop-in): clangd itself lives in
# clang-tools-extra, and bear (EPEL) generates the compile_commands.json
# that clangd needs for plain Makefile projects.
C_DEV_PACKAGES=(
    clang
    clang-tools-extra   # clangd, clang-tidy, clang-format
    gcc
    make
    cmake
    gdb
    bear
)

# Libraries and utilities needed by the tools above and by the curl-installed
# ones (Eclipse needs GTK; gradle/eclipse archives need unzip/tar).
SUPPORT_PACKAGES=(
    gtk3
    webkit2gtk3     # Eclipse internal browser
    xdg-utils
    alsa-lib
    jq              # used by 50-install-vsix-extensions.sh
    unzip
    zip
    tar
    gzip
    which
    procps-ng
)

dnf -y module enable "nodejs:${NODEJS_STREAM}"

dnf -y install "${JAVA_PACKAGES[@]}" "${TOOL_PACKAGES[@]}" "${C_DEV_PACKAGES[@]}" "${SUPPORT_PACKAGES[@]}"

# Register git-lfs system-wide so every toolbox user gets the filters.
git lfs install --system

dnf clean all
