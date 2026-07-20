#!/usr/bin/env bash
# Install the Allure 2 test report tool (allure-commandline). Not available
# as an rpm in any of the configured repos, so it is fetched from Maven
# Central, sha256-verified. Runs on the JRE already installed by
# 20-install-dnf-tools.sh.
#
# Inputs (set by the Containerfile):
#   ALLURE_VERSION  e.g. 2.44.0
#   ALLURE_SHA256   sha256 of the allure-commandline .tgz; Maven Central
#                   publishes it next to the artifact (<artifact>.tgz.sha256)
set -euo pipefail

ALLURE_VERSION=${ALLURE_VERSION:?ALLURE_VERSION must be set}
ALLURE_SHA256=${ALLURE_SHA256:-}

CURL=(curl --fail --location --silent --show-error --retry 3)

workdir=$(mktemp -d)
trap 'rm -rf "${workdir}"' EXIT

echo "==> Installing Allure ${ALLURE_VERSION}"
"${CURL[@]}" -o "${workdir}/allure.tgz" \
    "https://repo.maven.apache.org/maven2/io/qameta/allure/allure-commandline/${ALLURE_VERSION}/allure-commandline-${ALLURE_VERSION}.tgz"
if [[ -n "${ALLURE_SHA256}" ]]; then
    echo "${ALLURE_SHA256}  ${workdir}/allure.tgz" | sha256sum --check --strict
fi
mkdir -p /opt/allure
tar --no-same-owner -xzf "${workdir}/allure.tgz" -C /opt/allure
chmod 0755 "/opt/allure/allure-${ALLURE_VERSION}/bin/allure"
ln -sfn "/opt/allure/allure-${ALLURE_VERSION}/bin/allure" /usr/local/bin/allure

allure --version
