# RHEL 9 based Toolbx image with a full Java development environment.
#
# Built on the Red Hat UBI 9 toolbox image. Packages come from the UBI
# BaseOS/AppStream/CRB repos and EPEL 9, with Rocky Linux 9 configured as a
# low-priority fallback for anything UBI does not ship publicly. Tools that
# are not packaged at all (Gradle, Eclipse, and JDK 25 if absent from the
# repos) are fetched with curl for now; the plan is to vendor those
# artifacts into this repo later.

FROM registry.access.redhat.com/ubi9/toolbox:latest

LABEL com.github.containers.toolbox="true" \
      name="rhel9-dev-toolbox" \
      version="9" \
      summary="RHEL 9 Toolbx image with Java 8/17/21/25, Maven, Gradle, Node.js, VS Code, Eclipse, JDK Mission Control, Cline, Allure, git, and the podman client" \
      usage="Use with the toolbox(1) command: toolbox create --image <this image>"

# Versions for the curl-installed tools. Bump these to upgrade.
# Gradle checksum comes from https://services.gradle.org/versions/all
ARG GRADLE_VERSION=9.2.0
ARG GRADLE_SHA256=df67a32e86e3276d011735facb1535f64d0d88df84fa87521e90becc2d735444
ARG ECLIPSE_RELEASE=2025-12
# Cline CLI + its kanban board (npm packages), see 32-install-cline.sh
ARG CLINE_VERSION=3.0.46
ARG CLINE_KANBAN_VERSION=0.1.70
# Allure checksum comes from Maven Central (<artifact>.tgz.sha256)
ARG ALLURE_VERSION=2.44.0
ARG ALLURE_SHA256=7021a90828c00cd6ec992027cce48e8a94bd87fad43d0c2dcac4795cadc178d7
# JDK Mission Control (Eclipse Adoptium build). Per-arch checksums are
# listed on the GitHub release's assets page, see 34-install-jmc.sh
ARG JMC_VERSION=9.1.2
ARG JMC_SHA256_X86_64=3085244b8f32bbd0646c8109a9f65f7089497e07e1d6bbc62f64da942d27d748
ARG JMC_SHA256_AARCH64=3247c0e4203d1dee0e20d5d438339fd23f2adbda152e26467cea3b07856fc6c4

COPY repos/ /etc/yum.repos.d/
COPY scripts/ /usr/local/share/toolbox-build/

RUN bash /usr/local/share/toolbox-build/10-setup-repos.sh

RUN bash /usr/local/share/toolbox-build/20-install-dnf-tools.sh

# Curl-installed tools, one script (and one layer) per tool.
RUN GRADLE_VERSION="${GRADLE_VERSION}" \
    GRADLE_SHA256="${GRADLE_SHA256}" \
    bash /usr/local/share/toolbox-build/30-install-gradle.sh

RUN ECLIPSE_RELEASE="${ECLIPSE_RELEASE}" \
    bash /usr/local/share/toolbox-build/31-install-eclipse.sh

# Cline CLI (TUI) + kanban board, installed globally via npm; Node.js 22
# comes from the AppStream module installed in 20-install-dnf-tools.sh.
RUN CLINE_VERSION="${CLINE_VERSION}" \
    CLINE_KANBAN_VERSION="${CLINE_KANBAN_VERSION}" \
    bash /usr/local/share/toolbox-build/32-install-cline.sh

RUN ALLURE_VERSION="${ALLURE_VERSION}" \
    ALLURE_SHA256="${ALLURE_SHA256}" \
    bash /usr/local/share/toolbox-build/33-install-allure.sh

RUN JMC_VERSION="${JMC_VERSION}" \
    JMC_SHA256_X86_64="${JMC_SHA256_X86_64}" \
    JMC_SHA256_AARCH64="${JMC_SHA256_AARCH64}" \
    bash /usr/local/share/toolbox-build/34-install-jmc.sh

# VS Code extension drop-in: every .vsix in the repo's vsix/ directory is
# installed as a built-in extension. The COPY sits directly above its RUN
# so changing vsix contents only rebuilds this layer.
COPY vsix/ /usr/local/share/toolbox-build/vsix/
RUN bash /usr/local/share/toolbox-build/50-install-vsix-extensions.sh

# Eclipse plugin drop-in: every <name>.zip (a mirrored p2 update site made
# with bin/eclipse-offline-package) with a <name>.ius sidecar listing the
# IUs is installed into /opt/eclipse, offline. The COPY sits directly above
# its RUN so changing bundle contents only rebuilds this layer.
COPY eclipse-plugins/ /usr/local/share/toolbox-build/eclipse-plugins/
RUN bash /usr/local/share/toolbox-build/51-install-eclipse-bundles.sh

# User-facing helper commands shipped with the image.
# eclipse-offline-package creates the plugin bundles described above.
COPY bin/ /usr/local/bin/
RUN chmod 0755 /usr/local/bin/eclipse-offline-package

# JAVA_HOME (default JDK 21) plus JAVA<N>_HOME for every installed JDK,
# exported for login shells via /etc/profile.d/java-homes.sh. The ENV below
# additionally covers non-login shells; it must match the default major
# version chosen in 40-configure-java-homes.sh.
RUN bash /usr/local/share/toolbox-build/40-configure-java-homes.sh
ENV JAVA_HOME=/usr/lib/jvm/java-21

# Podman client: `podman` is podman-remote (client-only), talking to the
# host's podman socket that Toolbx shares with the container. Also exports
# DOCKER_HOST so Testcontainers and other Docker-API clients use the same
# socket — see "Podman and Testcontainers" in the README.
RUN bash /usr/local/share/toolbox-build/41-configure-podman-remote.sh

# Final smoke test and cleanup so the layers above stay as small as possible.
RUN bash /usr/local/share/toolbox-build/90-verify-tools.sh
RUN dnf clean all && rm -rf /var/cache/dnf /var/cache/yum /tmp/*
