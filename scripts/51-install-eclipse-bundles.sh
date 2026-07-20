#!/usr/bin/env bash
# Install every Eclipse plugin bundle dropped into the repo's
# eclipse-plugins/ directory (copied into the build at ${BUNDLE_SOURCE_DIR})
# into the image's Eclipse.
#
# A bundle is a pair of files created with bin/eclipse-offline-package:
#   <name>.zip  a mirrored p2 update site (repository at the zip root)
#   <name>.ius  the installable units to install; one per line, '#' comments
#
# Each zip carries the plugin AND its dependencies, so this step needs no
# network access. Installs go into /opt/eclipse's own profile, so the
# plugins are available to every user of the container.
set -euo pipefail

BUNDLE_SOURCE_DIR=${BUNDLE_SOURCE_DIR:-/usr/local/share/toolbox-build/eclipse-plugins}
ECLIPSE=${ECLIPSE:-/opt/eclipse/eclipse}

shopt -s nullglob
bundles=("${BUNDLE_SOURCE_DIR}"/*.zip)

if (( ${#bundles[@]} == 0 )); then
    echo "==> No plugin bundles in ${BUNDLE_SOURCE_DIR}; nothing to install"
    exit 0
fi

if [[ ! -x "${ECLIPSE}" ]]; then
    echo "ERROR: ${ECLIPSE} not found — is Eclipse installed?" >&2
    exit 1
fi

workdir=$(mktemp -d)
trap 'rm -rf "${workdir}"' EXIT

installed=()
for bundle in "${bundles[@]}"; do
    echo "==> Installing $(basename "${bundle}")"

    sidecar=${bundle%.zip}.ius
    if [[ ! -f "${sidecar}" ]]; then
        echo "ERROR: $(basename "${bundle}") has no $(basename "${sidecar}") sidecar" \
             "listing the IUs to install — re-create the bundle with" \
             "eclipse-offline-package --iu ..." >&2
        exit 1
    fi
    # Strip comments/blank lines and join the IUs with commas for the
    # director. `grep || true`: an all-comments file must reach the empty
    # check below, not trip pipefail.
    ius=$(sed -e 's/#.*//' -e 's/[[:space:]]//g' "${sidecar}" \
        | { grep -v '^$' || true; } | paste -sd, -)
    if [[ -z "${ius}" ]]; then
        echo "ERROR: $(basename "${sidecar}") lists no IUs" >&2
        exit 1
    fi

    unpack="${workdir}/$(basename "${bundle}" .zip)"
    unzip -q "${bundle}" -d "${unpack}"
    if ! compgen -G "${unpack}/content.*" >/dev/null \
        && ! compgen -G "${unpack}/compositeContent.*" >/dev/null; then
        echo "ERROR: $(basename "${bundle}") has no p2 metadata at its root — not an" \
             "eclipse-offline-package zip?" >&2
        exit 1
    fi

    "${ECLIPSE}" -nosplash -consoleLog \
        -application org.eclipse.equinox.p2.director \
        -repository "file:${unpack}" \
        -installIU "${ius}" \
        -vmargs -Djava.awt.headless=true
    echo "    -> ${ius}"
    installed+=("$(basename "${bundle}" .zip)")
done

echo "==> Installed ${#installed[@]} Eclipse plugin bundle(s): ${installed[*]}"
