# dev-toolbox-example

A custom [Toolbx](https://containertoolbx.org/) image for Red Hat / Fedora
`toolbox`, based on **RHEL 9** (Red Hat UBI 9).

## What's inside

| Tool | Version(s) | Source |
| --- | --- | --- |
| OpenJDK (full devel packages) | 8, 17, 21, 25 | UBI AppStream rpms; JDK 25 falls back to Eclipse Temurin via curl if the repos don't carry it yet |
| Maven | RHEL 9 packaged | UBI AppStream |
| Gradle | 9.2.0 | curl from services.gradle.org (sha256-verified) |
| VS Code | latest | Microsoft rpm repo |
| Eclipse IDE for Java Developers | 2025-12 | curl from download.eclipse.org |
| Git + Git LFS | RHEL 9 packaged | UBI / EPEL / Rocky |

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

Tools with no rpm available anywhere (Gradle, Eclipse, and the Temurin JDK
fallback) are downloaded with curl at build time — one script per tool under
`scripts/`. **TODO:** vendor these artifacts into the repo (with checksums)
instead of downloading at build time.

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

## Repository layout

```
Containerfile                    Image definition (versions are build ARGs)
repos/rocky.repo                 Rocky Linux 9 fallback repos (priority=200)
repos/vscode.repo                Microsoft VS Code rpm repo
scripts/10-setup-repos.sh        Enable CRB, install EPEL
scripts/20-install-dnf-tools.sh  Everything installable via dnf
scripts/30-install-gradle.sh     Gradle (curl, sha256-verified)
scripts/31-install-eclipse.sh    Eclipse IDE (curl)
scripts/32-install-temurin-fallback.sh  Temurin JDK, only if the rpm JDK is missing
scripts/40-configure-java-homes.sh  JAVA_HOME + versioned JAVA<N>_HOME exports
scripts/90-verify-tools.sh       Final smoke test of every installed tool
.github/workflows/build-image.yml  CI/CD: lint + build (PRs), publish to
                                   GHCR (main, weekly schedule, manual runs)
```

## Bumping versions

Gradle, Eclipse, and the JDK-25 fallback versions are `ARG`s at the top of
the `Containerfile` — edit them there or override at build time, e.g.:

```sh
podman build --build-arg GRADLE_VERSION=9.3.0 -t rhel9-dev-toolbox .
```

When bumping Gradle, update `GRADLE_SHA256` too — the official checksum for
each release is listed at <https://services.gradle.org/versions/all>.
