#!/usr/bin/env bash
# JDK fallback: install Eclipse Temurin with curl, but only when the rpm
# stage could not install the matching java-N-openjdk-devel package (e.g. a
# JDK newer than what the configured repos carry). Skipped entirely when the
# rpm JDK is present. To be vendored into the repo later like the other
# curl-fetched tools.
#
# Inputs (set by the Containerfile):
#   TEMURIN_FALLBACK_MAJOR  e.g. 25
set -euo pipefail

TEMURIN_FALLBACK_MAJOR=${TEMURIN_FALLBACK_MAJOR:?TEMURIN_FALLBACK_MAJOR must be set}

CURL=(curl --fail --location --silent --show-error --retry 3)

if compgen -G "/usr/lib/jvm/java-${TEMURIN_FALLBACK_MAJOR}-openjdk*" > /dev/null; then
    echo "==> java-${TEMURIN_FALLBACK_MAJOR}-openjdk already installed from rpms; skipping Temurin"
    exit 0
fi

workdir=$(mktemp -d)
trap 'rm -rf "${workdir}"' EXIT

echo "==> Installing Eclipse Temurin ${TEMURIN_FALLBACK_MAJOR}"
arch=$(uname -m)
case "${arch}" in
    x86_64)  temurin_arch=x64 ;;
    aarch64) temurin_arch=aarch64 ;;
    *) echo "Unsupported architecture for Temurin: ${arch}" >&2; exit 1 ;;
esac
"${CURL[@]}" -o "${workdir}/temurin.tar.gz" \
    "https://api.adoptium.net/v3/binary/latest/${TEMURIN_FALLBACK_MAJOR}/ga/linux/${temurin_arch}/jdk/hotspot/normal/eclipse"
mkdir -p /opt/java
tar -xzf "${workdir}/temurin.tar.gz" -C /opt/java
jdk_home=$(find /opt/java -maxdepth 1 -type d -name "jdk-${TEMURIN_FALLBACK_MAJOR}*" | head -n 1)
ln -sfn "${jdk_home}" "/opt/java/temurin-${TEMURIN_FALLBACK_MAJOR}"
# Register with alternatives at a low priority so the rpm-installed JDKs
# keep providing the default `java`; switch with `alternatives --config java`.
alternatives --install /usr/bin/java java "${jdk_home}/bin/java" 100
alternatives --install /usr/bin/javac javac "${jdk_home}/bin/javac" 100

"${jdk_home}/bin/java" -version
