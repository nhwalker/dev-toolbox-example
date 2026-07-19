#!/usr/bin/env bash
# Install Gradle. Not available as an rpm in any of the configured repos, so
# it is fetched with curl for now; the plan is to vendor the artifact into
# the repo later instead of downloading it at build time.
#
# Inputs (set by the Containerfile):
#   GRADLE_VERSION  e.g. 9.2.0
#   GRADLE_SHA256   sha256 of the gradle -bin.zip (optional but recommended;
#                   official values: https://services.gradle.org/versions/all)
set -euo pipefail

GRADLE_VERSION=${GRADLE_VERSION:?GRADLE_VERSION must be set}
GRADLE_SHA256=${GRADLE_SHA256:-}

CURL=(curl --fail --location --silent --show-error --retry 3)

workdir=$(mktemp -d)
trap 'rm -rf "${workdir}"' EXIT

echo "==> Installing Gradle ${GRADLE_VERSION}"
"${CURL[@]}" -o "${workdir}/gradle.zip" \
    "https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip"
if [[ -n "${GRADLE_SHA256}" ]]; then
    echo "${GRADLE_SHA256}  ${workdir}/gradle.zip" | sha256sum --check --strict
fi
mkdir -p /opt/gradle
unzip -q "${workdir}/gradle.zip" -d /opt/gradle
ln -sfn "/opt/gradle/gradle-${GRADLE_VERSION}/bin/gradle" /usr/local/bin/gradle

gradle --version
