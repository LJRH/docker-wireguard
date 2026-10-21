# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **security-patched fork** of [LinuxServer.io's docker-wireguard](https://github.com/linuxserver/docker-wireguard). The core modification is building CoreDNS from source during the Docker image build to avoid vulnerable Alpine-packaged versions. The published image is `ljrh/wireguard` on Docker Hub.

## Build Commands

```bash
# Build amd64 image
docker build --no-cache --pull -t linuxserver/wireguard:latest .

# Build ARM64 image
docker build --no-cache --pull -f Dockerfile.aarch64 -t linuxserver/wireguard:latest .
```

There is no test suite. Testing is done by running the built image with appropriate environment variables (see README.md).

## Files: What to Edit vs. What Not to Touch

| Do NOT edit | Edit instead |
|---|---|
| `README.md` (auto-generated) | `readme-vars.yml` |
| `Jenkinsfile` | `jenkins-vars.yml` |
| `package_versions.txt` | — |

When making Dockerfile changes, **always update both** `Dockerfile` (amd64) and `Dockerfile.aarch64` (ARM64) in parallel. Add APK packages in alphabetical order. Add a changelog entry in `readme-vars.yml` for any script or Dockerfile change.

## Architecture

### s6-overlay Service Startup Order

The container uses s6-overlay for process supervision. Services start in dependency order:

1. `init-wireguard-module` — loads the WireGuard kernel module if not already loaded
2. `init-wireguard-confs` — generates server/peer configs from env vars (server mode) or validates client confs
3. `svc-coredns` — starts CoreDNS (only in server mode or when port 53 is free)
4. `svc-wireguard` — brings up WireGuard tunnel(s) via `wg-quick`

Service definitions live in `root/etc/s6-overlay/s6-rc.d/`. Config generation logic is in `root/etc/s6-overlay/s6-rc.d/init-wireguard-confs/run`.

### Server vs. Client Mode

- **Server mode**: triggered by setting the `PEERS` env var. The `init-wireguard-confs` script generates `wg0.conf` and per-peer configs using templates from `root/defaults/`. CoreDNS runs and peers use it for DNS (`PEERDNS=auto`).
- **Client mode**: no `PEERS` var. User drops `.conf` files into `/config/wg_confs/`. CoreDNS is disabled.

### CoreDNS Source Build (the key fork change)

The Dockerfile installs Alpine's `go`, `git` and `make` as `.build-deps`, clones CoreDNS at the pinned tag, builds with `CGO_ENABLED=1`, installs to `/usr/bin/coredns`, then removes all build deps. This keeps image size equivalent to the upstream Alpine package approach while using a current Go toolchain.

Alpine's `go` package depends on gcc, musl-dev and binutils, which is what makes `CGO_ENABLED=1` work. Go itself is never compiled here; it is a prebuilt package. See "Go toolchain mechanics" below.

To update CoreDNS or Go versions, change `COREDNS_VERSION` and `GOLANG_VERSION` in **both** Dockerfiles. `scripts/release.sh` refuses to publish if the two files have drifted.

### Config Templates

`root/defaults/server.conf` and `root/defaults/peer.conf` are the WireGuard config templates. `root/defaults/Corefile` is the CoreDNS config template. These are copied to `/config/templates/` at first run so users can customize them.

## Shell Script Conventions

- Shebang: `#!/usr/bin/with-contenv bash`
- All variables: `${VARIABLE}` syntax
- Environment variables: `SCREAMING_SNAKE_CASE`
- Conditionals: `[[ ]]` not `[ ]`
- Peer name validation: `[[:alnum:]]` regex
- All s6 service scripts (`run`, `finish`, `check`) must be executable (`chmod +x`)
- All scripts must pass ShellCheck (enforced in CI)

## Release Process

Three scripts cover the whole loop. Run them from the repo root.

```bash
scripts/check-versions.sh          # what we pin vs what is available upstream
scripts/scan.sh [image]            # fixable findings only; exit 2 means act
scripts/release.sh --no-push       # build, verify, scan, smoke-test (dry run)
scripts/release.sh                 # same, then tag and push (prompts first)
```

`check-versions.sh` is read-only and answers "is a rebuild worth it?". It compares
the Dockerfile pins against the latest Go patch, the latest CoreDNS tags, the Go
module proxy, and Alpine's branch index. It also runs `apk version -l '<'` inside
the published image, which is the authoritative way to see whether a plain rebuild
would pick up newer packages.

`release.sh` derives its tags from the Dockerfile pins, so tags can never claim a
version the image does not contain. It publishes four: `latest`, the date,
`coredns-<version>` and `patched-go<version>`. It aborts before tagging if any
check fails. `--no-push` deliberately tags nothing locally.

After a release, still done by hand:

1. Changelog entry in `readme-vars.yml` (required for any Dockerfile or script change).
2. Refresh the "Current build" table and changelog in `overview.md`.
3. Commit and push to the `myfork` remote, branch `security-patches`.
4. Paste `overview.md` into the Docker Hub repository description. Hub does not read it from the repo.
5. Delete any `patched-go<old>` tag on Hub that now names a vulnerable toolchain. The CLI cannot remove remote tags.

Weekly scanning runs via `.github/workflows/security-scan.yml`, which opens an
issue when fixable findings appear. It needs `DOCKERHUB_USERNAME` and
`DOCKERHUB_TOKEN` repository secrets for Scout authentication.

## Decisions Already Made

Settled after investigation. Do not re-derive these; revisit only if the
underlying facts change.

- **`apk del curl coreutils jq` is deliberate and load-bearing.** The plain base
  image scans with findings in coreutils and in nghttp2-libs via curl. Deleting
  them is what clears those. Docker Mods still works: the base image's
  `/docker-mods` has a `curl_check()` that reinstalls curl and jq on demand.
- **`grep` must stay.** `init-wireguard-confs` uses `grep -Fxqz` for the
  PersistentKeepalive peer match and busybox grep has no `-z`. GNU grep is the
  only thing pulling `pcre2` into the image. A verified pure-bash replacement
  exists but was rejected: it diverges from upstream for no security gain, since
  pcre2's vulnerable paths are only reachable through `grep -P`, which nothing uses.
- **`net-tools` is deliberately omitted** even though upstream ships it. Nothing
  in the image calls any of its binaries; every apparent match is `ip route` from
  iproute2. It carries unfixed CVE-2025-46836.
- **`unbound-dev` was removed.** CoreDNS has no unbound plugin in `plugin.cfg`,
  so libunbound was never linked.
- **The `wg-quick` sysctl sed patch was removed.** wireguard-tools 1.0.20260223
  ships the `src_valid_mark` guard upstream, so the patch had become a silent no-op.
- **Alpine's security database lags upstream.** In Sept 2026 Scout reported three
  pcre2 CVEs as unfixed at every version when 10.48 already contained the fixes;
  they aged off once Alpine recorded the data. Check the upstream project's release
  notes before acting on an apk advisory marked "not fixed". `scan.sh --only-fixed`
  avoids this class of noise entirely.

## Go Toolchain Mechanics

- Go is a **prebuilt Alpine package**, never compiled here. The only cost of a
  pin that Alpine does not match is an extra prebuilt toolchain **download**.
- Alpine sets `GOTOOLCHAIN=local` by default, so a download only happens because
  the Dockerfile overrides it with `GOTOOLCHAIN=go${GOLANG_VERSION}`.
- Pinning the version Alpine already ships means zero download. `check-versions.sh`
  reports when the pin and Alpine's package diverge.
- **Never drop the `GOLANG_VERSION=` argument to `make`.** CoreDNS's Makefile
  falls back to its own `.go-version`, which is older, and would pull that instead.
- The stdlib version in the built binary is whatever toolchain compiled it, so Go
  stdlib CVEs are fixed by bumping `GOLANG_VERSION`, not by any apk package.

## Known Limitations

- **amd64 only.** `Dockerfile.aarch64` is kept in lock-step and checked by
  `release.sh`, but building it needs emulation, so no arm64 image is published.
- **One Dockerfile per arch.** Upstream does this, so the fork follows. Collapsing
  to a single buildx file driven by `TARGETARCH` would remove the duplication and
  enable arm64, at the cost of diverging from upstream's layout.
