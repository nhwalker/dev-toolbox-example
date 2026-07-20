#!/usr/bin/env bash
# Configure the podman client for use inside a Toolbx container.
#
# A toolbox cannot usefully run its own container engine (nested rootless
# podman needs storage/userns tweaks and duplicates the host's images).
# The supported pattern is the one Toolbx itself is built around: the
# host's rootless podman socket at ${XDG_RUNTIME_DIR}/podman/podman.sock
# is already bind-mounted into every toolbox, and the client-only
# podman-remote package (installed by 20-install-dnf-tools.sh) talks to
# it. This script wires that up:
#   * symlinks `podman` -> podman-remote, so tools that shell out to a
#     plain `podman` work (podman-remote is a client-only build that is
#     always in --remote mode, so the symlink cannot accidentally try to
#     run containers locally)
#   * writes /etc/profile.d/podman-host.sh, which points CONTAINER_HOST
#     (podman) and DOCKER_HOST (Docker-API clients such as Testcontainers)
#     at the host socket whenever it is present
#
# One-time host prerequisite (outside the toolbox):
#   systemctl --user enable --now podman.socket
set -euo pipefail

test -x /usr/bin/podman-remote || { echo "ERROR: podman-remote is not installed" >&2; exit 1; }

# The client-only build never conflicts with a full podman install, but
# guard anyway in case a future base image starts shipping one.
if [[ ! -e /usr/bin/podman ]]; then
    ln -s podman-remote /usr/bin/podman
fi

profile=/etc/profile.d/podman-host.sh
cat > "${profile}" <<'EOF'
# Generated at image build time by 41-configure-podman-remote.sh
# Point the podman client and Docker-API clients (Testcontainers,
# docker-java, ...) at the host's rootless podman socket, which Toolbx
# bind-mounts into the container. Does nothing until the host has run:
#   systemctl --user enable --now podman.socket
if [ -S "${XDG_RUNTIME_DIR:-/nonexistent}/podman/podman.sock" ]; then
    export CONTAINER_HOST="${CONTAINER_HOST:-unix://${XDG_RUNTIME_DIR}/podman/podman.sock}"
    export DOCKER_HOST="${DOCKER_HOST:-${CONTAINER_HOST}}"
    # Testcontainers' Ryuk reaper needs a privileged container under
    # rootless podman. If Ryuk still fails to start, disable it instead:
    #   export TESTCONTAINERS_RYUK_DISABLED=true
    export TESTCONTAINERS_RYUK_CONTAINER_PRIVILEGED="${TESTCONTAINERS_RYUK_CONTAINER_PRIVILEGED:-true}"
fi
EOF

echo "==> Wrote ${profile}:"
cat "${profile}"

podman --version
podman-remote --version
