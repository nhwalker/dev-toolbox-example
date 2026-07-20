#!/usr/bin/env bash
# Install async-profiler, a low-overhead sampling profiler for the JVM
# (CPU / allocation / lock / wall-clock, flame graphs, JFR output). Not
# available as an rpm in any of the configured repos, so it is fetched
# from GitHub, sha256-verified.
#
# The perf_events-based CPU engine needs kernel.perf_event_paranoid <= 2
# (or CAP_PERFMON) on the host; asprof falls back to a timer-based engine
# when perf_events is unavailable.
#
# Inputs (set by the Containerfile):
#   ASYNC_PROFILER_VERSION         e.g. 4.4
#   ASYNC_PROFILER_SHA256_X86_64   sha256 of the linux-x64 tarball
#   ASYNC_PROFILER_SHA256_AARCH64  sha256 of the linux-arm64 tarball
#                                  (digests are listed on the GitHub
#                                  release's assets page)
set -euo pipefail

ASYNC_PROFILER_VERSION=${ASYNC_PROFILER_VERSION:?ASYNC_PROFILER_VERSION must be set}

# Upstream names its artifacts x64/arm64 rather than x86_64/aarch64.
arch=$(uname -m)
case "${arch}" in
    x86_64)  ap_arch=x64;   AP_SHA256=${ASYNC_PROFILER_SHA256_X86_64:-} ;;
    aarch64) ap_arch=arm64; AP_SHA256=${ASYNC_PROFILER_SHA256_AARCH64:-} ;;
    *) echo "ERROR: unsupported architecture: ${arch}" >&2; exit 1 ;;
esac

CURL=(curl --fail --location --silent --show-error --retry 3)

workdir=$(mktemp -d)
trap 'rm -rf "${workdir}"' EXIT

echo "==> Installing async-profiler ${ASYNC_PROFILER_VERSION}"
"${CURL[@]}" -o "${workdir}/async-profiler.tar.gz" \
    "https://github.com/async-profiler/async-profiler/releases/download/v${ASYNC_PROFILER_VERSION}/async-profiler-${ASYNC_PROFILER_VERSION}-linux-${ap_arch}.tar.gz"
if [[ -n "${AP_SHA256}" ]]; then
    echo "${AP_SHA256}  ${workdir}/async-profiler.tar.gz" | sha256sum --check --strict
fi

# The tarball unpacks to a versioned top-level directory
# (async-profiler-<version>-linux-<arch>); locate it by its bin/asprof
# rather than assuming the layout, and relocate it to
# /opt/async-profiler.
mkdir -p "${workdir}/extract"
tar --no-same-owner -xzf "${workdir}/async-profiler.tar.gz" -C "${workdir}/extract"
mapfile -t asprofs < <(find "${workdir}/extract" -mindepth 2 -maxdepth 3 -type f -name asprof -path '*/bin/asprof')
if [[ ${#asprofs[@]} -ne 1 ]]; then
    echo "ERROR: expected exactly one bin/asprof in the tarball, found ${#asprofs[@]}; archive root contains:" >&2
    ls -la "${workdir}/extract" >&2
    exit 1
fi
rm -rf /opt/async-profiler
mv "$(dirname "$(dirname "${asprofs[0]}")")" /opt/async-profiler
ln -sfn /opt/async-profiler/bin/asprof /usr/local/bin/asprof
ln -sfn /opt/async-profiler/bin/jfrconv /usr/local/bin/jfrconv

asprof --version
test -x /opt/async-profiler/bin/jfrconv
