# dev-toolbox-example

A custom [Toolbx](https://containertoolbx.org/) image for Red Hat / Fedora
`toolbox`, based on **RHEL 9** (Red Hat UBI 9).

## What's inside

| Tool | Version(s) | Source |
| --- | --- | --- |
| OpenJDK (full devel packages) | 8, 17, 21, 25 | UBI AppStream rpms |
| Maven | RHEL 9 packaged | UBI AppStream |
| Gradle | 9.2.0 | curl from services.gradle.org (sha256-verified) |
| Node.js + npm | 22 (LTS) | UBI AppStream `nodejs:22` module |
| Cline CLI + kanban board | 3.0.46 / 0.1.70 | npm (installed globally at build time) |
| Allure test reports | 2.44.0 | curl from Maven Central (sha256-verified) |
| VS Code | latest | Microsoft rpm repo |
| VS Code extensions | clangd 0.6.0, Cline 4.0.9 + whatever is in `vsix/` | drop-in `.vsix` files, baked in at build time |
| C toolchain | clang/clangd, gcc, make, cmake, gdb, bear | UBI AppStream + EPEL (bear) |
| Eclipse IDE for Java Developers | 2025-12 | curl from download.eclipse.org |
| Eclipse plugins | whatever is in `eclipse-plugins/` | drop-in p2 update-site zips, baked in at build time |
| Git + Git LFS | RHEL 9 packaged | UBI / EPEL / Rocky |
| Podman client (`podman-remote`) | RHEL 9 packaged | UBI AppStream |

`JAVA_HOME` points at JDK 21 by default, and each installed JDK also gets a
versioned variable: `JAVA8_HOME`, `JAVA17_HOME`, `JAVA21_HOME`,
`JAVA25_HOME` (exported via `/etc/profile.d/java-homes.sh`). Handy for
Maven/Gradle toolchains or per-project overrides like
`JAVA_HOME=$JAVA17_HOME mvn verify`. To switch the default `java` on the
PATH, use `sudo alternatives --config java`.

## Package sources

Repos are consulted in this order of preference:

1. **UBI 9** BaseOS / AppStream / CodeReady Builder (CRB) — the public
   Red Hat UBI repos built into the base image.
2. **EPEL 9** — installed during the build.
3. **Rocky Linux 9** BaseOS / AppStream / CRB — configured at dnf
   `priority=200` so they act purely as a *fallback* for packages the public
   UBI repos do not carry (see `repos/rocky.repo`).

Tools with no rpm available anywhere (Gradle and Eclipse) are downloaded
with curl at build time — one script per tool under `scripts/`. **TODO:**
vendor these artifacts into the repo (with checksums) instead of
downloading at build time.

## Building

```sh
podman build -t rhel9-dev-toolbox -f Containerfile .
# or: make build
```

Note: this is a large image (five JDKs plus two IDEs); expect a multi-GB
result and a long first build.

## Using with toolbox

```sh
toolbox create --image localhost/rhel9-dev-toolbox rhel9-dev
toolbox enter rhel9-dev
```

Or, once CI has published the image to GHCR:

```sh
toolbox create --image ghcr.io/nhwalker/rhel9-dev-toolbox:latest rhel9-dev
toolbox enter rhel9-dev
```

GUI apps (VS Code, Eclipse) work inside a toolbox because Toolbx shares the
host's Wayland/X11 sockets — just run `code` or `eclipse` from inside the
container.

## Cline

Cline ships three ways in this image:

- **TUI** — run `cline` (or `cline --tui`) inside the toolbox for the
  interactive terminal UI: plan/act toggle, slash commands, file mentions,
  live tool approvals.
- **Kanban board** — run `cline kanban` (or `kanban` directly) from a git
  repo to launch the local web app that runs agents in parallel, one
  isolated git worktree per task card. The `kanban` npm package is baked
  into the image, so the board works without a registry fetch.
- **VS Code extension** — vendored in `vsix/` and installed as a built-in
  extension. The file is named `saoudrizwan.claude-dev-*.vsix` because
  Cline's original name was "Claude Dev" and marketplace extension IDs
  cannot change after publishing — it is the official Cline extension
  (display name "Cline", repo `github.com/cline/cline`).

On first use, authenticate with `cline auth` (Cline account or a provider
API key). Config lives in `~/.cline/`, which Toolbx shares with the host —
so a login done inside the toolbox is also visible to host installs of
Cline and vice versa. `cline doctor` diagnoses setup issues.

## Allure test reports

The [Allure 2](https://allurereport.org/) commandline is installed at
`/opt/allure` with `allure` on the PATH (it runs on the image's JRE). Use
it to render reports from test result folders produced by JUnit/TestNG/
Cucumber runs:

```sh
allure serve build/allure-results     # one-shot: generate + open in browser
allure generate --output report ...   # static report
```

## Podman and Testcontainers

A toolbox does not run its own container engine — nested podman inside a
rootless container needs storage and user-namespace workarounds and would
duplicate the host's image store. Instead the image ships
**`podman-remote`**, the client-only podman build, and symlinks it to
`podman`. It talks to the **host's** podman over the rootless API socket
at `$XDG_RUNTIME_DIR/podman/podman.sock`, which Toolbx already
bind-mounts into every toolbox (the same mechanism that shares the
Wayland socket). Containers you start from inside the toolbox are
ordinary host containers — siblings of the toolbox, not children.

One-time setup **on the host** (the only step the image cannot do for
you):

```sh
systemctl --user enable --now podman.socket
```

Inside the toolbox, `/etc/profile.d/podman-host.sh` then detects the
socket and exports:

- `CONTAINER_HOST` — so `podman` (and anything using the podman client
  libraries) targets the host socket explicitly;
- `DOCKER_HOST` — the podman socket serves the Docker API, so
  Docker-API clients like **Testcontainers**, docker-java, and
  docker-compose work against it unchanged. `mvn verify` / `gradle test`
  with Testcontainers just work — no per-project configuration;
- `TESTCONTAINERS_RYUK_CONTAINER_PRIVILEGED=true` — Testcontainers'
  Ryuk cleanup container needs `--privileged` under rootless podman. If
  Ryuk still gives you trouble, set `TESTCONTAINERS_RYUK_DISABLED=true`
  (cleanup then relies on the JVM shutdown hook).

Each variable is only set if the socket exists and you have not already
set it yourself. If `podman ps` reports a connection error, the socket is
not enabled on the host — run the `systemctl --user` command above, then
open a new shell in the toolbox.

## Eclipse plugins as offline bundles

The image ships an `eclipse-offline-package` command that mirrors an
Eclipse p2 update site into an offline bundle: a `<name>.zip` of the update
site (plugin + all dependencies) and a `<name>.ius` sidecar listing the
installable units. Like the `vsix/` folder for VS Code, bundles dropped
into `eclipse-plugins/` are installed into the image's Eclipse at build
time — with no network needed, so plugins survive air-gapped builds.

```sh
# See what an update site offers
eclipse-offline-package --site https://download.eclipse.org/egit/updates --list

# Bundle one feature and its dependencies (features need .feature.group)
eclipse-offline-package --site https://download.eclipse.org/egit/updates \
    --iu org.eclipse.egit.feature.group --name egit
mv egit.zip egit.ius eclipse-plugins/
# rebuild the image
```

The zip holds the p2 repository at its root, so on any offline machine it
also works directly in the Eclipse UI via *Help > Install New Software... >
Add... > Archive...*. See `eclipse-plugins/README.md` and
`eclipse-offline-package --help` for details.

## Repository layout

```
Containerfile                    Image definition (versions are build ARGs)
repos/rocky.repo                 Rocky Linux 9 fallback repos (priority=200)
repos/vscode.repo                Microsoft VS Code rpm repo
scripts/10-setup-repos.sh        Enable CRB, install EPEL
scripts/20-install-dnf-tools.sh  Everything installable via dnf
scripts/30-install-gradle.sh     Gradle (curl, sha256-verified)
scripts/31-install-eclipse.sh    Eclipse IDE (curl)
scripts/32-install-cline.sh      Cline CLI + kanban board (npm, global)
scripts/33-install-allure.sh     Allure 2 commandline (curl, sha256-verified)
scripts/40-configure-java-homes.sh  JAVA_HOME + versioned JAVA<N>_HOME exports
scripts/41-configure-podman-remote.sh  podman -> podman-remote symlink + host
                                 socket exports (CONTAINER_HOST, DOCKER_HOST)
scripts/50-install-vsix-extensions.sh  Installs vsix/*.vsix into VS Code
vsix/                            Drop-in folder for VS Code .vsix extensions
scripts/51-install-eclipse-bundles.sh  Installs eclipse-plugins/*.zip into Eclipse
eclipse-plugins/                 Drop-in folder for Eclipse plugin bundles
                                 (zip + .ius pairs, see its README)
bin/eclipse-offline-package      Creates those bundles from a p2 update site
scripts/90-verify-tools.sh       Final smoke test of every installed tool
.github/workflows/build-image.yml  CI/CD: lint + build (PRs), publish to
                                   GHCR (main, weekly schedule, manual runs)
```

## Bumping versions

Gradle, Eclipse, Cline (+ kanban), and Allure versions are `ARG`s at the
top of the `Containerfile` — edit them there or override at build time,
e.g.:

```sh
podman build --build-arg GRADLE_VERSION=9.3.0 -t rhel9-dev-toolbox .
```

When bumping Gradle, update `GRADLE_SHA256` too — the official checksum for
each release is listed at <https://services.gradle.org/versions/all>.
Likewise for Allure: `ALLURE_SHA256` is published next to the artifact on
Maven Central as `allure-commandline-<version>.tgz.sha256`.
