#!/usr/bin/env bash
# Final smoke test: make sure every tool this image promises is actually
# present and runnable. Runs as the last build step.
set -euo pipefail

echo "==> Verifying installed tools"

# JAVA_HOME / JAVA<N>_HOME exports
# shellcheck disable=SC1091
source /etc/profile.d/java-homes.sh
for var in JAVA_HOME JAVA8_HOME JAVA11_HOME JAVA17_HOME JAVA21_HOME JAVA25_HOME; do
    home=${!var:?${var} is not set}
    test -x "${home}/bin/javac" || { echo "ERROR: ${var}=${home} has no javac" >&2; exit 1; }
    echo "${var}=${home}"
done

gradle --version
test -x /opt/eclipse/eclipse
test -x /opt/jmc/jmc
asprof --version
command -v jfrconv >/dev/null || { echo "ERROR: jfrconv not on PATH" >&2; exit 1; }
test -x /opt/mat/MemoryAnalyzer
test -x /usr/local/bin/mat-parse-heapdump
eclipse-offline-package --help >/dev/null
node --version
npm --version
cline --version
command -v kanban >/dev/null || { echo "ERROR: kanban not on PATH" >&2; exit 1; }
allure --version
java -version
javac -version
mvn --version
git --version
git lfs version
clangd --version
clang --version | head -1
gcc --version | head -1
cmake --version | head -1
gdb --version | head -1
make --version | head -1
bear --version
podman --version           # symlink to podman-remote; --version needs no server
podman-remote --version
# shellcheck disable=SC1091
source /etc/profile.d/podman-host.sh   # syntax check; no-op without the host socket
code --version --user-data-dir /tmp/vscode-smoke || true   # code exits non-zero without a display on some versions
ls -d /usr/lib/jvm/java-* 2>/dev/null || true
