#!/usr/bin/env bash
# Install the Cline CLI coding agent plus its kanban board, globally via
# npm so every toolbox user gets them on the PATH. Two surfaces:
#   - TUI:    `cline` (or `cline --tui`) opens the interactive terminal UI
#   - Kanban: `cline kanban` (or `kanban` directly) launches the local web
#     app that runs agents in parallel, one git worktree per task card
# The standalone `kanban` package is baked in alongside the CLI so the
# board does not have to be fetched from the npm registry at first launch.
#
# Requires Node.js >= 22, installed by 20-install-dnf-tools.sh.
#
# Inputs (set by the Containerfile):
#   CLINE_VERSION         e.g. 3.0.46  (https://www.npmjs.com/package/cline)
#   CLINE_KANBAN_VERSION  e.g. 0.1.70  (https://www.npmjs.com/package/kanban)
set -euo pipefail

CLINE_VERSION=${CLINE_VERSION:?CLINE_VERSION must be set}
CLINE_KANBAN_VERSION=${CLINE_KANBAN_VERSION:?CLINE_KANBAN_VERSION must be set}

echo "==> Installing Cline CLI ${CLINE_VERSION} + kanban ${CLINE_KANBAN_VERSION}"
npm install -g --no-audit --no-fund \
    "cline@${CLINE_VERSION}" \
    "kanban@${CLINE_KANBAN_VERSION}"

# The npm download cache is only build-time dead weight in an image layer.
npm cache clean --force

cline --version
command -v kanban >/dev/null || { echo "ERROR: kanban not on PATH" >&2; exit 1; }
