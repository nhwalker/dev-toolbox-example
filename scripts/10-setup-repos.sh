#!/usr/bin/env bash
# Enable the package sources used by this image, in order of preference:
#   1. UBI 9 BaseOS / AppStream / CRB (enabled here)
#   2. EPEL 9 (installed here)
#   3. Rocky Linux 9 fallback repos (copied in via repos/rocky.repo, priority=200)
# The VS Code repo (repos/vscode.repo) is also already in place.
set -euo pipefail

dnf -y install dnf-plugins-core

# Enable the UBI CodeReady Builder (CRB) repo. Match by name rather than
# hardcoding the id so this survives minor renames of the UBI repo files.
crb_repos=$(dnf repolist --all 2>/dev/null | awk '/codeready/ {print $1}')
if [[ -n "${crb_repos}" ]]; then
    # shellcheck disable=SC2086
    dnf config-manager --set-enabled ${crb_repos}
else
    echo "WARNING: no CodeReady Builder repo found to enable" >&2
fi

# EPEL 9. UBI containers resolve $releasever to the full minor version
# (e.g. 9.6), which EPEL's metalink does not accept, so pin it to "9".
dnf -y install \
    https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm
sed -i 's/\$releasever/9/g' /etc/yum.repos.d/epel*.repo

dnf -y makecache
dnf repolist
