#!/usr/bin/env bash
# Generate /etc/profile.d/java-homes.sh so every shell in the toolbox gets:
#   JAVA<N>_HOME  for each installed JDK (e.g. JAVA8_HOME, JAVA21_HOME)
#   JAVA_HOME     pointing at the default JDK (21)
set -euo pipefail

DEFAULT_JAVA_MAJOR=21

# The /usr/lib/jvm/* major-version symlinks are owned by the RHEL openjdk
# rpms; JDK 8 predates the plain-number naming scheme.
java_home_for() {
    local major=$1 home
    if [[ "${major}" == "8" ]]; then
        home="/usr/lib/jvm/java-1.8.0"
    else
        home="/usr/lib/jvm/java-${major}"
    fi
    if [[ -x "${home}/bin/java" ]]; then
        echo "${home}"
        return 0
    fi
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
