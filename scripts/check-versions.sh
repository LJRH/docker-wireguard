#!/usr/bin/env bash
# Report what this fork pins against what is currently available upstream.
#
# Read-only: touches nothing in the repo, the image, or Docker Hub. Run this
# first when deciding whether a security rebuild is worthwhile.
#
#   scripts/check-versions.sh                   # compare pins + published image
#   IMAGE=ljrh/wireguard:20261021 scripts/check-versions.sh
#   scripts/check-versions.sh --no-image        # skip the apk comparison
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOCKERFILE="${REPO_ROOT}/Dockerfile"
IMAGE="${IMAGE:-ljrh/wireguard:latest}"
CHECK_IMAGE=1
[[ "${1:-}" == "--no-image" ]] && CHECK_IMAGE=0

CACHE="$(mktemp -d)"
trap 'rm -rf "${CACHE}"' EXIT

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
hdr() { printf '\n== %s ==\n' "$1"; }
mark() { [[ -n "$1" && -n "$2" && "$1" != "$2" ]] && printf '%s' "   <-- $3"; }

# Download once into the cache, with one retry. Returns 1 if it never arrived.
grab() {
  local url="$1" out="${CACHE}/$2"
  [[ -s "${out}" ]] && return 0
  curl -sS --max-time 45 -o "${out}" "${url}" 2>/dev/null && [[ -s "${out}" ]] && return 0
  sleep 2
  curl -sS --max-time 45 -o "${out}" "${url}" 2>/dev/null && [[ -s "${out}" ]]
}

# Extract "V:" for a package from a cached APKINDEX tarball.
apk_ver() {
  local idx="${CACHE}/$1" pkg="$2"
  [[ -s "${idx}" ]] || return 1
  tar -xzOf "${idx}" APKINDEX 2>/dev/null \
    | awk -v p="P:${pkg}" '$0==p{f=1} f&&/^V:/{sub(/^V:/,"");print;exit}'
}

[[ -f "${DOCKERFILE}" ]] || die "no Dockerfile at ${DOCKERFILE}"

# ---------------------------------------------------------------- what we pin
ALPINE_BRANCH="$(grep -oE 'baseimage-alpine:(arm64v8-)?[0-9]+\.[0-9]+' "${DOCKERFILE}" | head -1 | grep -oE '[0-9]+\.[0-9]+$')"
COREDNS_PINNED="$(grep -oE 'COREDNS_VERSION=[0-9.]+' "${DOCKERFILE}" | head -1 | cut -d= -f2)"
GO_PINNED="$(grep -oE 'GOLANG_VERSION=[0-9.]+' "${DOCKERFILE}" | head -1 | cut -d= -f2)"
[[ -n "${ALPINE_BRANCH}" && -n "${COREDNS_PINNED}" && -n "${GO_PINNED}" ]] \
  || die "could not parse pins from ${DOCKERFILE}"
GO_LINE="${GO_PINNED%.*}"

printf 'Dockerfile pins : Alpine %s | CoreDNS %s | Go %s\n' \
  "${ALPINE_BRANCH}" "${COREDNS_PINNED}" "${GO_PINNED}"
printf 'Image for apk   : %s\n' "${IMAGE}"

grab "https://go.dev/dl/?mode=json&include=all" go.json || true
grab "http://dl-cdn.alpinelinux.org/alpine/v${ALPINE_BRANCH}/community/x86_64/APKINDEX.tar.gz" community.tgz || true

# -------------------------------------------------------------- Go toolchain
hdr "Go toolchain"
GO_LATEST=""
if [[ -s "${CACHE}/go.json" ]]; then
  GO_LATEST="$(grep -oE "go${GO_LINE//./\\.}\.[0-9]+" "${CACHE}/go.json" | sed 's/^go//' | sort -V | tail -1)"
fi
GO_ALPINE="$(apk_ver community.tgz go || true)"
printf '  %-22s: %s\n' 'pinned in Dockerfile' "${GO_PINNED}"
printf '  %-22s: %s%s\n' "latest in ${GO_LINE} line" "${GO_LATEST:-lookup failed}" \
  "$(mark "${GO_LATEST}" "${GO_PINNED}" 'UPDATE AVAILABLE')"
printf '  %-22s: %s%s\n' "Alpine ${ALPINE_BRANCH} package" "${GO_ALPINE:-lookup failed}" \
  "$(mark "${GO_ALPINE%%-r*}" "${GO_PINNED}" 'pin differs, build downloads a toolchain')"

# ------------------------------------------------------------------- CoreDNS
hdr "CoreDNS"
COREDNS_TAGS="$(git ls-remote --tags https://github.com/coredns/coredns.git 'v1.*' 2>/dev/null \
  | grep -v '\^{}' | sed 's|.*refs/tags/v||' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | sort -V)"
if [[ -n "${COREDNS_TAGS}" ]]; then
  COREDNS_LATEST="$(printf '%s\n' "${COREDNS_TAGS}" | tail -1)"
  COREDNS_PATCH="$(printf '%s\n' "${COREDNS_TAGS}" | grep -E "^${COREDNS_PINNED%.*}\." | tail -1)"
  printf '  %-22s: %s\n' 'pinned' "${COREDNS_PINNED}"
  printf '  %-22s: %s%s\n' "latest in ${COREDNS_PINNED%.*} line" "${COREDNS_PATCH}" \
    "$(mark "${COREDNS_PATCH}" "${COREDNS_PINNED}" 'PATCH AVAILABLE')"
  printf '  %-22s: %s%s\n' 'latest overall' "${COREDNS_LATEST}" \
    "$(mark "${COREDNS_LATEST}" "${COREDNS_PINNED}" 'new minor: check .go-version and go.mod first')"
else
  printf '  tag lookup failed\n'
fi

# -------------------------------------------------------------- Go module pins
hdr "Go module pins"
printf '  %-40s %-14s %-14s\n' MODULE PINNED LATEST
grep -oE '[a-z0-9.]+\.[a-z]+/[^ @=]+@v[0-9][^ \\]*' "${DOCKERFILE}" | sort -u | while read -r pair; do
  mod="${pair%@*}"; pinned="${pair#*@}"
  # the Go module proxy wants uppercase letters escaped as !lowercase
  # shellcheck disable=SC2001  # \L needs sed; bash cannot lowercase per-match
  esc="$(echo "${mod}" | sed 's/\([A-Z]\)/!\L\1/g')"
  latest=""
  if grab "https://proxy.golang.org/${esc}/@latest" "mod_${mod//\//_}.json"; then
    latest="$(grep -oE '"Version":"[^"]+"' "${CACHE}/mod_${mod//\//_}.json" | cut -d'"' -f4)"
  fi
  printf '  %-40s %-14s %-14s%s\n' "${mod}" "${pinned}" "${latest:-?}" \
    "$(mark "${latest}" "${pinned}" 'newer available')"
done

# ------------------------------------------------ Alpine packages in the image
if [[ "${CHECK_IMAGE}" -eq 1 ]]; then
  hdr "Alpine packages in ${IMAGE} outdated for the ${ALPINE_BRANCH} branch"
  if ! docker image inspect "${IMAGE}" >/dev/null 2>&1; then
    printf '  not present locally, pulling...\n'
    docker pull -q "${IMAGE}" >/dev/null 2>&1 \
      || { printf '  could not pull %s, skipped\n' "${IMAGE}"; exit 0; }
  fi
  # apk does the version comparison, so we never reimplement its ordering rules
  out="$(docker run --rm --entrypoint sh "${IMAGE}" -c \
    'apk update >/dev/null 2>&1; apk version -l "<" 2>/dev/null | tail -n +2' 2>/dev/null)"
  if [[ -z "${out//[[:space:]]/}" ]]; then
    printf '  none, every installed package is current for the branch\n'
  else
    while IFS= read -r line; do printf '  %s\n' "${line}"; done <<< "${out}"
    printf '\n  A plain "--pull --no-cache" rebuild picks all of these up.\n'
  fi
fi
