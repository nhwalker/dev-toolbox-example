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
      summary="RHEL 9 Toolbx image with Java 8/11/17/21/25, Maven, Gradle, VS Code, Eclipse, and git" \
      usage="Use with the toolbox(1) command: toolbox create --image <this image>"

# Versions for the curl-installed tools. Bump these to upgrade.
# Gradle checksum comes from https://services.gradle.org/versions/all
ARG GRADLE_VERSION=9.2.0
ARG GRADLE_SHA256=df67a32e86e3276d011735facb1535f64d0d88df84fa87521e90becc2d735444
ARG ECLIPSE_RELEASE=2025-12
ARG TEMURIN_FALLBACK_MAJOR=25

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

RUN TEMURIN_FALLBACK_MAJOR="${TEMURIN_FALLBACK_MAJOR}" \
    bash /usr/local/share/toolbox-build/32-install-temurin-fallback.sh

# Final smoke test and cleanup so the layers above stay as small as possible.
RUN bash /usr/local/share/toolbox-build/90-verify-tools.sh
RUN dnf clean all && rm -rf /var/cache/dnf /var/cache/yum /tmp/*
