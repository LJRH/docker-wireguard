#!/usr/bin/env bash
# Build, verify, scan, smoke-test, tag and publish a security rebuild.
#
# Tags are derived from the Dockerfile pins, so they can never drift from what
# was actually built:
#   latest, <date>, coredns-<COREDNS_VERSION>, patched-go<GOLANG_VERSION>
#
#   scripts/release.sh --no-push        # everything except the push (default-safe)
#   scripts/release.sh                  # full release, prompts before pushing
#   scripts/release.sh --yes            # full release, no prompt
#   scripts/release.sh --date 20261021  # override the date tag
#
# amd64 only, matching what this fork has always published. Dockerfile.aarch64
# is kept in lock-step but needs emulation, so it is checked for drift, not built.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}" || exit 1

REPO="${REPO:-ljrh/wireguard}"
DATE_TAG="$(date +%Y%m%d)"
PUSH=1
ASSUME_YES=0
SKIP_BUILD=0
STAGING="${REPO}:release-candidate"
CONTAINER="release-smoketest-$$"
FAILURES=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-push) PUSH=0 ;;
    --yes|-y) ASSUME_YES=1 ;;
    --skip-build) SKIP_BUILD=1 ;;
    --date) shift; DATE_TAG="${1:-}" ;;
    --repo) shift; REPO="${1:-}"; STAGING="${REPO}:release-candidate" ;;
    *) printf 'unknown option: %s\n' "$1" >&2; exit 1 ;;
  esac
  shift
done

step() { printf '\n\033[1m==> %s\033[0m\n' "$1"; }
ok()   { printf '  [ ok ] %s\n' "$1"; }
bad()  { printf '  [FAIL] %s\n' "$1"; FAILURES=$((FAILURES+1)); }
note() { printf '  [note] %s\n' "$1"; }
cleanup() { docker rm -f "${CONTAINER}" >/dev/null 2>&1 || true; }
trap cleanup EXIT

# ------------------------------------------------------------------ 0. pins
COREDNS_VERSION="$(grep -oE 'COREDNS_VERSION=[0-9.]+' Dockerfile | head -1 | cut -d= -f2)"
GOLANG_VERSION="$(grep -oE 'GOLANG_VERSION=[0-9.]+' Dockerfile | head -1 | cut -d= -f2)"
ALPINE_BRANCH="$(grep -oE 'baseimage-alpine:(arm64v8-)?[0-9]+\.[0-9]+' Dockerfile | head -1 | grep -oE '[0-9]+\.[0-9]+$')"
if [[ -z "${COREDNS_VERSION}" || -z "${GOLANG_VERSION}" || -z "${ALPINE_BRANCH}" ]]; then
  printf 'error: could not parse pins from Dockerfile\n' >&2; exit 1
fi
TAGS=("latest" "${DATE_TAG}" "coredns-${COREDNS_VERSION}" "patched-go${GOLANG_VERSION}")

step "Release plan"
printf '  repo          : %s\n  alpine        : %s\n  coredns       : %s\n  go            : %s\n' \
  "${REPO}" "${ALPINE_BRANCH}" "${COREDNS_VERSION}" "${GOLANG_VERSION}"
printf '  tags          : %s\n  push          : %s\n' "${TAGS[*]}" \
  "$([[ "${PUSH}" -eq 1 ]] && echo yes || echo 'no (--no-push)')"

# --------------------------------------------- 1. the two Dockerfiles in sync
step "Checking Dockerfile.aarch64 is in lock-step"
# The two files are allowed to differ in exactly two ways: the base image tag
# carries the arm64v8- prefix, and the APKINDEX URL names the other arch.
# Everything else must be byte-identical, so a pin bump can never land in one
# file and not the other.
if grep -q "baseimage-alpine:arm64v8-${ALPINE_BRANCH}\$" Dockerfile.aarch64; then
  ok "aarch64 base image is arm64v8-${ALPINE_BRANCH}"
else
  bad "aarch64 base image is not arm64v8-${ALPINE_BRANCH}"
fi
if grep -q "alpine/v${ALPINE_BRANCH}/main/aarch64/APKINDEX" Dockerfile.aarch64; then
  ok "aarch64 APKINDEX URL points at v${ALPINE_BRANCH}/aarch64"
else
  bad "aarch64 APKINDEX URL is wrong or on the wrong branch"
fi
diff_out="$(diff <(sed -e 's|^FROM .*|FROM BASE|' -e 's/x86_64/ARCH/' Dockerfile) \
                 <(sed -e 's|^FROM .*|FROM BASE|' -e 's/aarch64/ARCH/' Dockerfile.aarch64) || true)"
if [[ -z "${diff_out//[[:space:]]/}" ]]; then
  ok "the two Dockerfiles are otherwise identical"
else
  bad "the two Dockerfiles have diverged:"
  printf '%s\n' "${diff_out}" | sed 's/^/      /'
fi

# ------------------------------------------------------------------ 2. build
if [[ "${SKIP_BUILD}" -eq 1 ]]; then
  step "Build skipped (--skip-build)"
else
  step "Building ${STAGING} (--no-cache --pull)"
  if docker build --no-cache --pull -t "${STAGING}" . ; then
    ok "build succeeded"
  else
    bad "build failed"; exit 1
  fi
fi

# ------------------------------------------------------------- 3. verify image
step "Verifying image contents against the pins"
got_alpine="$(docker run --rm --entrypoint sh "${STAGING}" -c 'cat /etc/alpine-release' 2>/dev/null)"
got_coredns="$(docker run --rm --entrypoint /usr/bin/coredns "${STAGING}" -version 2>/dev/null | head -2 | tr '\n' ' ')"
if [[ "${got_alpine}" == "${ALPINE_BRANCH}".* ]]; then
  ok "alpine ${got_alpine}"
else
  bad "alpine ${got_alpine}, expected ${ALPINE_BRANCH}.x"
fi
if [[ "${got_coredns}" == *"CoreDNS-${COREDNS_VERSION}"* ]]; then
  ok "coredns ${COREDNS_VERSION}"
else
  bad "coredns mismatch: ${got_coredns}"
fi
if [[ "${got_coredns}" == *"go${GOLANG_VERSION},"* ]]; then
  ok "built with go${GOLANG_VERSION}"
else
  bad "go toolchain mismatch: ${got_coredns}"
fi

leftovers="$(docker run --rm --entrypoint sh "${STAGING}" -c \
  'for p in go git make curl coreutils jq net-tools; do apk info -e $p >/dev/null 2>&1 && printf "%s " "$p"; done' 2>/dev/null)"
if [[ -z "${leftovers//[[:space:]]/}" ]]; then
  ok "no build deps or deliberately removed packages present"
else
  bad "unexpected packages in the image: ${leftovers}"
fi

# -------------------------------------------------------------------- 4. scan
step "Scanning for fixable findings"
if SEVERITY="critical,high" "${REPO_ROOT}/scripts/scan.sh" "${STAGING}" >/tmp/release-scan.$$ 2>&1; then
  ok "no fixable critical or high findings"
  grep -A2 'Unfixable advisories' /tmp/release-scan.$$ | tail -n +2 | sed 's/^/      /'
else
  bad "fixable critical or high findings present, release blocked"
  sed 's/^/      /' /tmp/release-scan.$$
fi
rm -f /tmp/release-scan.$$

# ------------------------------------------------------------- 5. smoke test
step "Smoke-testing the container"
if ! lsmod 2>/dev/null | grep -q '^wireguard' && [[ ! -d /sys/module/wireguard ]]; then
  note "wireguard kernel module not loaded on this host, tunnel assertions may fail"
fi
docker rm -f "${CONTAINER}" >/dev/null 2>&1 || true
docker run -d --name "${CONTAINER}" --cap-add NET_ADMIN \
  -e PEERS=2 -e PERSISTENTKEEPALIVE_PEERS=all -e SERVERURL=vpn.example.com -e LOG_CONFS=false \
  --sysctl net.ipv4.conf.all.src_valid_mark=1 "${STAGING}" >/dev/null 2>&1

for _ in $(seq 1 15); do
  docker exec "${CONTAINER}" test -e /sys/class/net/wg0 >/dev/null 2>&1 && break
  docker exec "${CONTAINER}" true >/dev/null 2>&1 || break
  sleep 1
done

if [[ "$(docker inspect -f '{{.State.Status}}' "${CONTAINER}" 2>/dev/null)" == "running" ]]; then
  ok "container running"
else
  bad "container is not running"
fi

peers="$(docker exec "${CONTAINER}" wg show 2>/dev/null | grep -cE '^peer:')"
if [[ "${peers}" == "2" ]]; then
  ok "tunnel up with 2 peers"
else
  bad "expected 2 peers, got ${peers}"
fi

keep="$(docker exec "${CONTAINER}" wg show 2>/dev/null | grep -c 'persistent keepalive')"
if [[ "${keep}" == "2" ]]; then
  ok "PersistentKeepalive set for both peers"
else
  bad "keepalive count ${keep}, expected 2"
fi

if docker exec "${CONTAINER}" sh -c 'nslookup example.com 10.13.13.1 >/dev/null 2>&1'; then
  ok "CoreDNS resolves via 10.13.13.1"
else
  bad "CoreDNS lookup failed"
fi

if docker exec "${CONTAINER}" /app/show-peer 1 >/dev/null 2>&1; then
  ok "show-peer renders"
else
  bad "show-peer failed"
fi

logprobs="$(docker logs "${CONTAINER}" 2>&1 | grep -iE 'error|unrecognized option|not found|panic' || true)"
if [[ -z "${logprobs//[[:space:]]/}" ]]; then
  ok "startup log clean"
else
  bad "problems in startup log:"; printf '%s\n' "${logprobs}" | sed 's/^/      /'
fi
cleanup

# ------------------------------------------------------------------- 6. gate
step "Result"
if [[ "${FAILURES}" -gt 0 ]]; then
  printf '  %s check(s) failed. Nothing has been tagged or pushed.\n' "${FAILURES}"
  exit 1
fi
ok "all checks passed"

# ---------------------------------------------------------------- 7. publish
# A dry run must not retag anything: "latest" locally is the operator's pointer
# to what is actually published, and silently moving it is confusing.
if [[ "${PUSH}" -eq 0 ]]; then
  step "Dry run complete (--no-push)"
  printf '  Would tag %s as:\n' "${STAGING}"
  for t in "${TAGS[@]}"; do printf '    %s:%s\n' "${REPO}" "${t}"; done
  printf '\n  To publish this exact build: scripts/release.sh --skip-build --date %s\n' "${DATE_TAG}"
  printf '  The candidate image is left as %s\n' "${STAGING}"
  exit 0
fi

step "Tagging"
for t in "${TAGS[@]}"; do
  docker tag "${STAGING}" "${REPO}:${t}" && printf '  %s:%s\n' "${REPO}" "${t}"
done

if [[ "${ASSUME_YES}" -eq 0 ]]; then
  printf '\nPush %s tags to Docker Hub as %s? [y/N] ' "${#TAGS[@]}" "${REPO}"
  read -r reply
  [[ "${reply}" == "y" || "${reply}" == "Y" ]] || { printf 'Aborted. Local tags left in place.\n'; exit 0; }
fi

step "Pushing"
for t in "${TAGS[@]}"; do
  printf '  %-24s ' "${t}"
  if docker push "${REPO}:${t}" 2>&1 | grep -oE 'digest: sha256:[0-9a-f]{12}' | tail -1; then :; else
    bad "push failed for ${t}"
  fi
done
docker rmi "${STAGING}" >/dev/null 2>&1 || true

step "Published"
printf '  digest : %s\n' "$(docker inspect -f '{{index .RepoDigests 0}}' "${REPO}:latest" 2>/dev/null)"
printf '  tags   : %s\n' "${TAGS[*]}"
printf '\nNext: changelog entry in readme-vars.yml, refresh overview.md, commit, push.\n'
[[ "${FAILURES}" -eq 0 ]] || exit 1
