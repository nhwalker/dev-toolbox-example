#!/usr/bin/env bash
# Install everything that is available as an rpm through the configured
# repos (UBI/CRB -> EPEL -> Rocky fallback -> Microsoft repo for VS Code).
set -euo pipefail

# Java toolchains. RHEL 9 ships full OpenJDK devel packages for these.
# JDK 25 is attempted here too; if the repos don't carry it yet the curl
# stage falls back to Eclipse Temurin 25.
JAVA_PACKAGES=(
    java-1.8.0-openjdk-devel
    java-17-openjdk-devel
    java-21-openjdk-devel
)

TOOL_PACKAGES=(
    maven
    maven-openjdk21 # pin maven's JDK binding to 21 (it defaults to 17)
    git
    git-lfs
    code            # VS Code, from the Microsoft repo
)

# Libraries and utilities needed by the tools above and by the curl-installed
# ones (Eclipse needs GTK; gradle/eclipse archives need unzip/tar).
SUPPORT_PACKAGES=(
    gtk3
    webkit2gtk3     # Eclipse internal browser
    xdg-utils
    alsa-lib
    unzip
    zip
    tar
    gzip
    which
    procps-ng
)

dnf -y install "${JAVA_PACKAGES[@]}" "${TOOL_PACKAGES[@]}" "${SUPPORT_PACKAGES[@]}"

# JDK 25 separately, so an as-yet-missing package doesn't fail the whole
# transaction. The curl stage installs Temurin 25 instead when this fails.
if ! dnf -y install java-25-openjdk-devel; then
    echo "java-25-openjdk-devel not available in the configured repos;" \
         "Temurin ${TEMURIN_FALLBACK_MAJOR:-25} will be installed by the curl stage." >&2
fi

# Register git-lfs system-wide so every toolbox user gets the filters.
git lfs install --system

dnf clean all
