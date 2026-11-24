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
#              the fixed release exists upstream but is not in our branch yet.
#              Nothing a rebuild can do, so it must not block. Branch lag can
#              reach the blocking tier too; check-versions.sh tells you whether
#              a rebuild would help. A "fix" that names edge's pkgrel may
#              already be backported to our branch: verify, then record it in
#              vex/ (see below).
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

# Reviewed false positives live in vex/ as OpenVEX statements, each pinned to
# the exact package version it covers so it lapses when that package changes.
# Scout only trusts @docker.com authors by default, hence --vex-author.
# The --full report ignores VEX so suppressed findings stay visible there.
VEX_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/vex"
VEX=()
if [[ -d "${VEX_DIR}" ]]; then
  VEX=(--vex-location "${VEX_DIR}" --vex-author ljrh-wireguard)
fi

blocking=0

printf '== BLOCKING: Go findings with a fix (any severity) ==\n'
if scout cves "${IMAGE}" --only-fixed --only-package-type golang \
     --format packages --details --exit-code "${VEX[@]}"; then
  printf '  none\n'
else
  blocking=1
fi

printf '\n== BLOCKING: Alpine package findings with a fix at %s ==\n' "${APK_SEVERITY}"
if scout cves "${IMAGE}" --only-fixed --only-package-type apk \
     --only-severity "${APK_SEVERITY}" --format packages --details --exit-code "${VEX[@]}"; then
  printf '  none\n'
else
  blocking=1
fi

# Every severity not already covered by the blocking apk gate.
APK_BELOW=""
for sev in critical high medium low unspecified; do
  [[ ",${APK_SEVERITY}," == *",${sev},"* ]] && continue
  APK_BELOW="${APK_BELOW:+${APK_BELOW},}${sev}"
done

printf '\n== INFO: Alpine package findings with a fix below %s ==\n' "${APK_SEVERITY}"
printf '   (usually branch lag: upstream has the fix, our Alpine branch does not yet)\n'
if [[ -n "${APK_BELOW}" ]]; then
  scout cves "${IMAGE}" --only-fixed --only-package-type apk \
       --only-severity "${APK_BELOW}" --format packages "${VEX[@]}" 2>/dev/null \
    | grep -E '^pkg:|✗' || printf '  none\n'
else
  printf '  none\n'
fi

printf '\n== INFO: advisories with no fix at any version ==\n'
scout cves "${IMAGE}" --only-unfixed --format packages "${VEX[@]}" 2>/dev/null \
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
