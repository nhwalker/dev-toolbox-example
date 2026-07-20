#!/usr/bin/env bash
# Install the Eclipse IDE (Eclipse IDE for Java Developers). Not available
# as an rpm in any of the configured repos, so it is fetched with curl for
# now; the plan is to vendor the artifact into the repo later instead of
# downloading it at build time.
#
# Inputs (set by the Containerfile):
#   ECLIPSE_RELEASE  e.g. 2025-12  (Eclipse simultaneous release train)
set -euo pipefail

ECLIPSE_RELEASE=${ECLIPSE_RELEASE:?ECLIPSE_RELEASE must be set}

CURL=(curl --fail --location --silent --show-error --retry 3)

arch=$(uname -m)   # x86_64 or aarch64 on the platforms we build for

workdir=$(mktemp -d)
trap 'rm -rf "${workdir}"' EXIT

echo "==> Installing Eclipse ${ECLIPSE_RELEASE}"
"${CURL[@]}" -o "${workdir}/eclipse.tar.gz" \
    "https://download.eclipse.org/technology/epp/downloads/release/${ECLIPSE_RELEASE}/R/eclipse-java-${ECLIPSE_RELEASE}-R-linux-gtk-${arch}.tar.gz"
# --no-same-owner: the EPP tarball's files are owned by a huge UID from
# Eclipse's build farm, which cannot be mapped inside a rootless podman
# build (as used by GitHub Actions) and makes tar fail with EINVAL.
tar -xzf "${workdir}/eclipse.tar.gz" -C /opt --no-same-owner   # unpacks to /opt/eclipse
ln -sfn /opt/eclipse/eclipse /usr/local/bin/eclipse

test -x /opt/eclipse/eclipse
