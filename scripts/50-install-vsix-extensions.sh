#!/usr/bin/env bash
# Install every .vsix dropped into the repo's vsix/ directory (copied into
# the build at ${VSIX_SOURCE_DIR}) as a VS Code BUILT-IN extension.
#
# Built-in (unpacked under /usr/share/code/resources/app/extensions) rather
# than `code --install-extension` because the latter writes to the invoking
# user's ~/.vscode/extensions — and inside a Toolbx container $HOME is the
# host's home, so a build-time per-user install would never reach the
# actual toolbox user. Built-ins load for every user automatically.
set -euo pipefail

VSIX_SOURCE_DIR=${VSIX_SOURCE_DIR:-/usr/local/share/toolbox-build/vsix}
CODE_EXT_DIR=/usr/share/code/resources/app/extensions

shopt -s nullglob
vsix_files=("${VSIX_SOURCE_DIR}"/*.vsix)

if (( ${#vsix_files[@]} == 0 )); then
    echo "==> No .vsix files in ${VSIX_SOURCE_DIR}; nothing to install"
    exit 0
fi

if [[ ! -d "${CODE_EXT_DIR}" ]]; then
    echo "ERROR: ${CODE_EXT_DIR} not found — is the 'code' rpm installed?" >&2
    exit 1
fi

workdir=$(mktemp -d)
trap 'rm -rf "${workdir}"' EXIT

installed=()
for vsix in "${vsix_files[@]}"; do
    echo "==> Installing $(basename "${vsix}")"
    unpack="${workdir}/$(basename "${vsix}" .vsix)"
    unzip -q "${vsix}" -d "${unpack}"
    manifest="${unpack}/extension/package.json"
    if [[ ! -f "${manifest}" ]]; then
        echo "ERROR: $(basename "${vsix}") contains no extension/package.json — not a VSIX?" >&2
        exit 1
    fi
    id=$(jq -r '"\(.publisher).\(.name)-\(.version)"' "${manifest}")
    if [[ "${id}" == *null* ]]; then
        echo "ERROR: $(basename "${vsix}") package.json lacks publisher/name/version" >&2
        exit 1
    fi
    dest="${CODE_EXT_DIR}/${id}"
    rm -rf "${dest}"
    mv "${unpack}/extension" "${dest}"
    chmod -R a+rX "${dest}"
    echo "    -> ${dest}"
    installed+=("${id}")
done

echo "==> Installed ${#installed[@]} VSIX extension(s): ${installed[*]}"
