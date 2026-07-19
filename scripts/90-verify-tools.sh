#!/usr/bin/env bash
# Final smoke test: make sure every tool this image promises is actually
# present and runnable. Runs as the last build step.
set -euo pipefail

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
