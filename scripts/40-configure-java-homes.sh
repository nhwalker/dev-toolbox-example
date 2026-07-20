#!/usr/bin/env bash
# Generate /etc/profile.d/java-homes.sh so every shell in the toolbox gets:
#   JAVA<N>_HOME  for each installed JDK (e.g. JAVA8_HOME, JAVA21_HOME)
#   JAVA_HOME     pointing at the default JDK (21)
# Runs after both the rpm and curl install stages so each version resolves
# no matter which one provided it (rpm symlink vs Temurin under /opt/java).
set -euo pipefail

DEFAULT_JAVA_MAJOR=21

# Candidate locations per major version, in order of preference. The
# /usr/lib/jvm/* symlinks are owned by the RHEL openjdk rpms; /opt/java is
# where 32-install-temurin-fallback.sh puts a curl-installed JDK.
java_home_for() {
    local major=$1 candidate
    local candidates=()
    if [[ "${major}" == "8" ]]; then
        candidates+=("/usr/lib/jvm/java-1.8.0")
    else
        candidates+=("/usr/lib/jvm/java-${major}")
    fi
    candidates+=("/opt/java/temurin-${major}")
    for candidate in "${candidates[@]}"; do
        if [[ -x "${candidate}/bin/java" ]]; then
            echo "${candidate}"
            return 0
        fi
    done
    return 1
}

profile=/etc/profile.d/java-homes.sh
{
    echo "# Generated at image build time by 40-configure-java-homes.sh"
    for major in 8 17 21 25; do
        if home=$(java_home_for "${major}"); then
            echo "export JAVA${major}_HOME=\"${home}\""
        else
            echo "ERROR: no JDK found for major version ${major}" >&2
            exit 1
        fi
    done
    echo "export JAVA_HOME=\"\${JAVA${DEFAULT_JAVA_MAJOR}_HOME}\""
} > "${profile}"

echo "==> Wrote ${profile}:"
cat "${profile}"

# Sanity check: JAVA_HOME must resolve to the default major version.
# shellcheck disable=SC1090
source "${profile}"
"${JAVA_HOME}/bin/java" -version 2>&1 | grep -q "\"${DEFAULT_JAVA_MAJOR}\." \
    || { echo "ERROR: JAVA_HOME does not point at JDK ${DEFAULT_JAVA_MAJOR}" >&2; exit 1; }
