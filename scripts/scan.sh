#!/usr/bin/env bash
# Scan an image with Docker Scout and report only what we can act on.
#
# "Fixable" in Scout's sense means a fix exists somewhere, which is not the
# same as a fix we can install. Three tiers, learned from real misses:
#
#   BLOCKING   Go findings with a fix, at any severity. Always actionable: we
#              control the toolchain pin and module replaces. Go's vuln db
#              often omits a CVSS score, so these land as "unspecified" and a
#              critical/high gate silently skips them (two x/net advisories,
#              Oct 2026).
#   BLOCKING   apk findings with a fix at critical or high. Urgent enough to
#              act on or decide about even if we must wait for the branch.
#   INFO       apk findings with a fix below that. Usually Alpine branch lag:
#              the fixed release exists upstream but is not in our branch yet
#              (musl CVE-2026-107891 wants 1.2.6-r6; 3.24 ships r3). Nothing
#              a rebuild can do, so it must not block.
#   INFO       Anything with no fix at any version.
#
# Use scripts/check-versions.sh to see whether the branch has caught up.
#
#   scripts/scan.sh                            # scan ljrh/wireguard:latest
#   scripts/scan.sh ljrh/wireguard:20261031
#   scripts/scan.sh --full                     # add the complete report
#   APK_SEVERITY=critical,high,medium ...      # widen the apk gate
#
# Exit codes: 0 nothing blocking, 2 action needed, 1 scanner/argument problem.
set -uo pipefail

APK_SEVERITY="${APK_SEVERITY:-critical,high}"
SCOUT="${SCOUT:-}"
FULL=0
IMAGE=""

for arg in "$@"; do
  case "${arg}" in
    --full) FULL=1 ;;
    -*) printf 'unknown option: %s\n' "${arg}" >&2; exit 1 ;;
    *) IMAGE="${arg}" ;;
  esac
done
IMAGE="${IMAGE:-ljrh/wireguard:latest}"

if [[ -z "${SCOUT}" ]]; then
  if docker scout version >/dev/null 2>&1; then
    SCOUT="docker scout"
  elif [[ -x "${HOME}/.local/bin/docker-scout" ]]; then
    SCOUT="${HOME}/.local/bin/docker-scout"
  else
    printf 'error: docker scout not found (tried "docker scout" and ~/.local/bin/docker-scout)\n' >&2
    exit 1
  fi
fi

# shellcheck disable=SC2086  # SCOUT may be "docker scout", two words by design
scout() { ${SCOUT} "$@"; }

blocking=0

printf '== BLOCKING: Go findings with a fix (any severity) ==\n'
if scout cves "${IMAGE}" --only-fixed --only-package-type golang \
     --format packages --details --exit-code; then
  printf '  none\n'
else
  blocking=1
fi

printf '\n== BLOCKING: Alpine package findings with a fix at %s ==\n' "${APK_SEVERITY}"
if scout cves "${IMAGE}" --only-fixed --only-package-type apk \
     --only-severity "${APK_SEVERITY}" --format packages --details --exit-code; then
  printf '  none\n'
else
  blocking=1
fi

printf '\n== INFO: Alpine package findings with a fix below %s ==\n' "${APK_SEVERITY}"
printf '   (usually branch lag: upstream has the fix, our Alpine branch does not yet)\n'
scout cves "${IMAGE}" --only-fixed --only-package-type apk --format packages 2>/dev/null \
  | grep -E '^pkg:|✗' || printf '  none\n'

printf '\n== INFO: advisories with no fix at any version ==\n'
scout cves "${IMAGE}" --only-unfixed --format packages 2>/dev/null \
  | grep -E '^pkg:|✗' || printf '  none\n'

if [[ "${FULL}" -eq 1 ]]; then
  printf '\n== Full report ==\n'
  scout cves "${IMAGE}" --format packages --details
fi

printf '\n'
if [[ "${blocking}" -ne 0 ]]; then
  printf 'RESULT: action needed. Run scripts/check-versions.sh to find the fixed versions.\n'
  exit 2
fi
printf 'RESULT: clean. Nothing blocking.\n'
exit 0
