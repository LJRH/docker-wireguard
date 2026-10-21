#!/usr/bin/env bash
# Scan an image with Docker Scout and report only what can actually be acted on.
#
# Unfixable advisories are noise in this repo: they cannot be cleared by a
# rebuild or a pin, so they must not gate a release. This wrapper separates
# the two and sets the exit code off the fixable set only.
#
#   scripts/scan.sh                        # scan ljrh/wireguard:latest
#   scripts/scan.sh ljrh/wireguard:20261021
#   SEVERITY=critical,high scripts/scan.sh # gate on these only (default)
#   scripts/scan.sh --full                 # add the complete report
#
# Exit codes: 0 nothing fixable at or above SEVERITY, 2 action needed,
#             1 scanner or argument problem.
set -uo pipefail

SEVERITY="${SEVERITY:-critical,high}"
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

# docker scout ships either as a CLI plugin or a standalone binary
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

printf '== Fixable findings in %s at severity: %s ==\n' "${IMAGE}" "${SEVERITY}"
# shellcheck disable=SC2086  # SCOUT may be "docker scout", two words by design
${SCOUT} cves "${IMAGE}" --only-fixed --only-severity "${SEVERITY}" \
  --format packages --details --exit-code
rc=$?

printf '\n== Unfixable advisories (tracked, not release-gating) ==\n'
# shellcheck disable=SC2086
${SCOUT} cves "${IMAGE}" --only-unfixed --format packages 2>/dev/null \
  | grep -E '^pkg:|✗' || printf '  none\n'

if [[ "${FULL}" -eq 1 ]]; then
  printf '\n== Full report ==\n'
  # shellcheck disable=SC2086
  ${SCOUT} cves "${IMAGE}" --format packages --details
fi

printf '\n'
if [[ "${rc}" -eq 2 ]]; then
  printf 'RESULT: action needed. Run scripts/check-versions.sh to find the fixed versions.\n'
  exit 2
fi
printf 'RESULT: clean. Nothing fixable at %s.\n' "${SEVERITY}"
exit 0
