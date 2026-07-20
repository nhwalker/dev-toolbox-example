#!/usr/bin/env bash
# Install the Eclipse Memory Analyzer (MAT) stand-alone RCP application,
# for analyzing JVM heap dumps (dominator tree, leak suspects, OQL). Not
# available as an rpm in any of the configured repos, so it is fetched
# from download.eclipse.org, sha512-verified (eclipse.org publishes
# sha512, not sha256 — see the sums.php endpoint below). MAT 1.17 needs
# Java 21+ to run; the default java on the PATH (JDK 21) satisfies that.
#
# Inputs (set by the Containerfile):
#   MAT_VERSION         full build id, e.g. 1.17.0.20260601
#   MAT_SHA512_X86_64   sha512 of the linux.gtk.x86_64 zip
#   MAT_SHA512_AARCH64  sha512 of the linux.gtk.aarch64 zip
#     checksums come from
#     https://www.eclipse.org/downloads/sums.php?file=/mat/<ver>/rcp/<zip>
set -euo pipefail

MAT_VERSION=${MAT_VERSION:?MAT_VERSION must be set}
# Release directory on download.eclipse.org uses the three-part version
# (1.17.0), the zip filename the full build id (1.17.0.20260601).
MAT_RELEASE=${MAT_VERSION%.*}

arch=$(uname -m)   # x86_64 or aarch64 on the platforms we build for
case "${arch}" in
    x86_64)  MAT_SHA512=${MAT_SHA512_X86_64:-} ;;
    aarch64) MAT_SHA512=${MAT_SHA512_AARCH64:-} ;;
    *) echo "ERROR: unsupported architecture: ${arch}" >&2; exit 1 ;;
esac

CURL=(curl --fail --location --silent --show-error --retry 3)

workdir=$(mktemp -d)
trap 'rm -rf "${workdir}"' EXIT

echo "==> Installing Eclipse Memory Analyzer ${MAT_VERSION}"
"${CURL[@]}" -o "${workdir}/mat.zip" \
    "https://download.eclipse.org/mat/${MAT_RELEASE}/rcp/MemoryAnalyzer-${MAT_VERSION}-linux.gtk.${arch}.zip"
if [[ -n "${MAT_SHA512}" ]]; then
    echo "${MAT_SHA512}  ${workdir}/mat.zip" | sha512sum --check --strict
fi

# The zip unpacks to a single top-level "mat" directory.
unzip -q "${workdir}/mat.zip" -d "${workdir}/extract"
test -x "${workdir}/extract/mat/MemoryAnalyzer"
rm -rf /opt/mat
mv "${workdir}/extract/mat" /opt/mat
ln -sfn /opt/mat/MemoryAnalyzer /usr/local/bin/mat

# ParseHeapDump.sh locates MemoryAnalyzer via $(dirname "$0"), so a
# symlink into /usr/local/bin would break it — wrap it instead. This is
# MAT's headless mode: parse a dump and emit reports without a display.
cat > /usr/local/bin/mat-parse-heapdump <<'EOF'
#!/bin/sh
# Headless Eclipse MAT: parse a heap dump and generate reports, e.g.
#   mat-parse-heapdump dump.hprof org.eclipse.mat.api:suspects
exec /opt/mat/ParseHeapDump.sh "$@"
EOF
chmod 0755 /usr/local/bin/mat-parse-heapdump

test -x /opt/mat/MemoryAnalyzer
test -x /opt/mat/ParseHeapDump.sh
