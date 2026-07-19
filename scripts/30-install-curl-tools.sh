#!/usr/bin/env bash
# Install tools that are not available as rpms in any of the configured
# repos. These are fetched with curl for now; the plan is to vendor these
# artifacts into the repo later instead of downloading them at build time.
#
# Inputs (set by the Containerfile):
#   GRADLE_VERSION          e.g. 9.2.0
#   GRADLE_SHA256           sha256 of the gradle -bin.zip (optional but recommended)
#   ECLIPSE_RELEASE         e.g. 2025-12  (Eclipse simultaneous release train)
#   TEMURIN_FALLBACK_MAJOR  e.g. 25       (only used if the rpm stage could
#                                          not install java-25-openjdk-devel)
set -euo pipefail

GRADLE_VERSION=${GRADLE_VERSION:?GRADLE_VERSION must be set}
GRADLE_SHA256=${GRADLE_SHA256:-}
ECLIPSE_RELEASE=${ECLIPSE_RELEASE:?ECLIPSE_RELEASE must be set}
TEMURIN_FALLBACK_MAJOR=${TEMURIN_FALLBACK_MAJOR:?TEMURIN_FALLBACK_MAJOR must be set}

CURL=(curl --fail --location --silent --show-error --retry 3)

arch=$(uname -m)   # x86_64 or aarch64 on the platforms we build for

workdir=$(mktemp -d)
trap 'rm -rf "${workdir}"' EXIT

### Gradle ##################################################################
echo "==> Installing Gradle ${GRADLE_VERSION}"
"${CURL[@]}" -o "${workdir}/gradle.zip" \
    "https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip"
if [[ -n "${GRADLE_SHA256}" ]]; then
    echo "${GRADLE_SHA256}  ${workdir}/gradle.zip" | sha256sum --check --strict
fi
mkdir -p /opt/gradle
unzip -q "${workdir}/gradle.zip" -d /opt/gradle
ln -sfn "/opt/gradle/gradle-${GRADLE_VERSION}/bin/gradle" /usr/local/bin/gradle

### Eclipse IDE (Eclipse IDE for Java Developers) ###########################
echo "==> Installing Eclipse ${ECLIPSE_RELEASE}"
"${CURL[@]}" -o "${workdir}/eclipse.tar.gz" \
    "https://download.eclipse.org/technology/epp/downloads/release/${ECLIPSE_RELEASE}/R/eclipse-java-${ECLIPSE_RELEASE}-R-linux-gtk-${arch}.tar.gz"
tar -xzf "${workdir}/eclipse.tar.gz" -C /opt   # unpacks to /opt/eclipse
ln -sfn /opt/eclipse/eclipse /usr/local/bin/eclipse

### JDK 25 fallback (Eclipse Temurin) #######################################
# Only needed when the rpm stage could not install java-25-openjdk-devel.
if compgen -G "/usr/lib/jvm/java-${TEMURIN_FALLBACK_MAJOR}-openjdk*" > /dev/null; then
    echo "==> java-${TEMURIN_FALLBACK_MAJOR}-openjdk already installed from rpms; skipping Temurin"
else
    echo "==> Installing Eclipse Temurin ${TEMURIN_FALLBACK_MAJOR}"
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
fi

### Smoke tests #############################################################
echo "==> Verifying installed tools"
gradle --version
test -x /opt/eclipse/eclipse
java -version
javac -version
mvn --version
git --version
git lfs version
code --version --user-data-dir /tmp/vscode-smoke || true   # code exits non-zero without a display on some versions
ls -d /usr/lib/jvm/java-* 2>/dev/null || true
