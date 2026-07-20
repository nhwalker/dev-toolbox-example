#!/usr/bin/env bash
# Install JDK Mission Control (JMC), the GUI analyzer for JDK Flight
# Recorder recordings. Not available as an rpm in any of the configured
# repos (Red Hat's build of JMC ships only in subscription-entitled
# product repos), so the Eclipse Adoptium build is fetched from GitHub,
# sha256-verified. JMC 9 needs JDK 21+ to run; the default java on the
# PATH (JDK 21) satisfies that.
#
# Inputs (set by the Containerfile):
#   JMC_VERSION         e.g. 9.1.2
#   JMC_SHA256_X86_64   sha256 of the linux.gtk.x86_64 tarball
#   JMC_SHA256_AARCH64  sha256 of the linux.gtk.aarch64 tarball
#                       (digests are listed on the GitHub release's
#                       assets page next to each tarball)
set -euo pipefail

JMC_VERSION=${JMC_VERSION:?JMC_VERSION must be set}

arch=$(uname -m)   # x86_64 or aarch64 on the platforms we build for
case "${arch}" in
    x86_64)  JMC_SHA256=${JMC_SHA256_X86_64:-} ;;
    aarch64) JMC_SHA256=${JMC_SHA256_AARCH64:-} ;;
    *) echo "ERROR: unsupported architecture: ${arch}" >&2; exit 1 ;;
esac

CURL=(curl --fail --location --silent --show-error --retry 3)

workdir=$(mktemp -d)
trap 'rm -rf "${workdir}"' EXIT

echo "==> Installing JDK Mission Control ${JMC_VERSION}"
"${CURL[@]}" -o "${workdir}/jmc.tar.gz" \
    "https://github.com/adoptium/jmc-build/releases/download/${JMC_VERSION}/org.openjdk.jmc-${JMC_VERSION}-linux.gtk.${arch}.tar.gz"
if [[ -n "${JMC_SHA256}" ]]; then
    echo "${JMC_SHA256}  ${workdir}/jmc.tar.gz" | sha256sum --check --strict
fi

# The product directory in the tarball is named "JDK Mission Control"
# (spaces included), but the archive root has carried extra sibling
# entries across releases — so locate the directory by its jmc launcher
# rather than assuming the layout, and relocate it to /opt/jmc.
mkdir -p "${workdir}/extract"
tar --no-same-owner -xzf "${workdir}/jmc.tar.gz" -C "${workdir}/extract"
mapfile -t launchers < <(find "${workdir}/extract" -mindepth 1 -maxdepth 2 -type f -name jmc)
if [[ ${#launchers[@]} -ne 1 ]]; then
    echo "ERROR: expected exactly one jmc launcher in the tarball, found ${#launchers[@]}; archive root contains:" >&2
    ls -la "${workdir}/extract" >&2
    exit 1
fi
rm -rf /opt/jmc
mv "$(dirname "${launchers[0]}")" /opt/jmc
ln -sfn /opt/jmc/jmc /usr/local/bin/jmc

test -x /opt/jmc/jmc
