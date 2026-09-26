# [ljrh/wireguard](https://github.com/LJRH/docker-wireguard)

A **security-patched build** of [linuxserver/wireguard](https://github.com/linuxserver/docker-wireguard). It is a drop-in replacement: same base image, same s6 services, same environment variables, same `/config` layout. The only change is that **CoreDNS is compiled from source with a current Go toolchain and pinned, patched dependencies** instead of being installed from the Alpine package, so the image does not inherit CVEs from a stale Alpine `coredns` package.

[WireGuard®](https://www.wireguard.com/) is an extremely simple yet fast and modern VPN that utilizes state-of-the-art cryptography. It aims to be faster, simpler, leaner, and more useful than IPsec, while avoiding the massive headache. It intends to be considerably more performant than OpenVPN. WireGuard is designed as a general purpose VPN for running on embedded interfaces and super computers alike, fit for many different circumstances. Initially released for the Linux kernel, it is now cross-platform (Windows, macOS, BSD, iOS, Android) and widely deployable.

## Why this image exists

The upstream image installs CoreDNS from the Alpine repository. That package is rebuilt infrequently, so it regularly ships a CoreDNS release and Go toolchain that are several security releases behind. This image instead:

* Clones the pinned CoreDNS release tag at build time
* Builds it with a pinned, current Go 1.26.x toolchain (`CGO_ENABLED=1`, so `/etc/hosts` and `resolv.conf` behave as upstream)
* Pins the Go modules that most often carry advisories (`google.golang.org/grpc`, `go.etcd.io/etcd/client`, `golang.org/x/crypto`, `golang.org/x/mod`) to fixed versions
* Removes all build dependencies afterwards, so image size matches upstream
* Is rebuilt with `--pull --no-cache` so the latest Alpine 3.24 package fixes (OpenSSL etc.) are always included

Every release is scanned with Docker Scout before it is pushed. As of the current build the scan reports **0 critical and 0 high** findings. The remaining findings have no remediation available: three `pcre2` advisories that Alpine has not yet marked fixed even though 10.48 contains the upstream fixes, and `golang.org/x/crypto` GO-2026-5932, which has no fixed version in any release.

### Current build

| Component | Version |
|---|---|
| Base image | `ghcr.io/linuxserver/baseimage-alpine:3.24` |
| CoreDNS | 1.14.7 (built from source) |
| Go toolchain | 1.26.8 |
| wireguard-tools | 1.0.20260223-r0 |
| OpenSSL | 3.5.8-r0 |

Verify the CoreDNS build inside the image:

```bash
docker run --rm --entrypoint /usr/bin/coredns ljrh/wireguard:latest -version
# CoreDNS-1.14.7
# linux/amd64, go1.26.8, ...
```

## Supported Architectures

Only `amd64` images are currently published. A `Dockerfile.aarch64` is maintained in the repository in lock-step with the amd64 one and can be built locally on ARM64 hosts (see [Building locally](#building-locally)).

| Architecture | Available | Tag |
| :----: | :----: | ---- |
| x86-64 | ✅ | `latest`, `YYYYMMDD`, `coredns-x.y.z`, `patched-goX.Y.Z` |
| arm64 | ❌ (build locally) | — |

## Tag summary

All tags from a given release point at the same image digest.

| Tag | Description |
|---|---|
| `latest` | Most recent security-patched build. Pull this for automatic updates. |
| `YYYYMMDD` (e.g. `20260906`) | Immutable date-stamped build for pinned production deployments. |
| `coredns-1.14.7` | Same build, tagged by the CoreDNS release it contains. |
| `patched-go1.26.8` | Same build, tagged by the Go toolchain used to compile CoreDNS. |

## Application Setup

During container start, it will first check if the wireguard module is already installed and loaded. All currently supported kernels should have the wireguard module built-in (along with some older custom kernels). However, the module may not be enabled. Make sure it is enabled prior to starting the container.

This can be run as a server or a client, based on the parameters used.

### Note on iptables

Some hosts may not load the iptables kernel modules by default. In order for the container to be able to load them, you need to assign the `SYS_MODULE` capability and add the optional `/lib/modules` volume mount. Alternatively you can `modprobe` them from the host before starting the container.

### Server Mode

If the environment variable `PEERS` is set to a number or a list of strings separated by comma, the container will run in server mode and the necessary server and peer/client confs will be generated. The peer/client config qr codes will be output in the docker log if `LOG_CONFS` is set to `true`. They will also be saved in text and png format under `/config/peerX` in case `PEERS` is a variable and an integer or `/config/peer_X` in case a list of names was provided instead of an integer.

Variables `SERVERURL`, `SERVERPORT`, `INTERNAL_SUBNET`, `PEERDNS`, `INTERFACE`, `ALLOWEDIPS` and `PERSISTENTKEEPALIVE_PEERS` are optional variables used for server mode. Any changes to these environment variables will trigger regeneration of server and peer confs. Peer/client confs will be recreated with existing private/public keys. Delete the peer folders for the keys to be recreated along with the confs.

To add more peers/clients later on, you increment the `PEERS` environment variable or add more elements to the list and recreate the container.

To display the QR codes of active peers again, you can use the following command and list the peer numbers as arguments: `docker exec -it wireguard /app/show-peer 1 4 5` or `docker exec -it wireguard /app/show-peer myPC myPhone myTablet` (Keep in mind that the QR codes are also stored as PNGs in the config folder).

The templates used for server and peer confs are saved under `/config/templates`. Advanced users can modify these templates and force conf generation by deleting `/config/wg_confs/wg0.conf` and restarting the container.

The container managed server conf is hardcoded to `wg0.conf`. However, the users can add additional tunnel config files with `.conf` extensions into `/config/wg_confs/` and the container will attempt to start them all in alphabetical order. If any one of the tunnels fail, they will all be stopped and the default route will be deleted, requiring user intervention to fix the invalid conf and a container restart.

In server mode the bundled CoreDNS listens on the WireGuard interface address (`10.13.13.1` by default) and forwards to the Docker host's resolvers. Peers use it automatically when `PEERDNS=auto`.

### Client Mode

Do not set the `PEERS` environment variable. Drop your client conf(s) into the config folder as `/config/wg_confs/<tunnel name>.conf` and start the container. If there are multiple tunnel configs, the container will attempt to start them all in alphabetical order. If any one of the tunnels fail, they will all be stopped and the default route will be deleted, requiring user intervention to fix the invalid conf and a container restart.

If you get IPv6 related errors in the log and connection cannot be established, edit the `AllowedIPs` line in your peer/client wg0.conf to include only `0.0.0.0/0` and not `::/0`; and restart the container.

CoreDNS is not started in client mode.

### Road warriors, roaming and returning home

If you plan to use Wireguard both remotely and locally, say on your mobile phone, you will need to consider routing. Most firewalls will not route ports forwarded on your WAN interface correctly to the LAN out of the box. This means that when you return home, even though you can see the Wireguard server, the return packets will probably get lost.

This is not a Wireguard specific issue and the two generally accepted solutions are NAT reflection (setting your edge router/firewall up in such a way as it translates internal packets correctly) or split horizon DNS (setting your internal DNS to return the private rather than public IP when connecting locally).

### Site-to-site VPN

Site-to-site VPN in server mode requires customizing the `AllowedIPs` statement for a specific peer in `wg0.conf`. Since `wg0.conf` is autogenerated when server vars are changed, it is not recommended to edit it manually.

Set an env var `SERVER_ALLOWEDIPS_PEER_<peer name or number>` to the additional subnets you'd like to add, comma separated and excluding the peer IP (ie. `"192.168.1.0/24,192.168.2.0/24"`). For instance `SERVER_ALLOWEDIPS_PEER_laptop="192.168.1.0/24,192.168.2.0/24"` will result in the wg0.conf entry `AllowedIPs = 10.13.13.2,192.168.1.0/24,192.168.2.0/24` for the peer named `laptop`.

This var is only considered when the confs are regenerated. Delete `wg0.conf` and restart the container to force regeneration if necessary.

For the full upstream notes on maintaining local access to attached services and other advanced topics, see the [linuxserver/wireguard documentation](https://docs.linuxserver.io/images/docker-wireguard/).

## Usage

To help you get started creating a container from this image you can either use docker-compose or the docker cli.

> **Note:** Unless a parameter is flagged as 'optional', it is *mandatory* and a value must be provided.

### docker-compose (recommended)

```yaml
---
services:
  wireguard:
    image: ljrh/wireguard:latest
    container_name: wireguard
    cap_add:
      - NET_ADMIN
      - SYS_MODULE #optional
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Etc/UTC
      - SERVERURL=wireguard.domain.com #optional
      - SERVERPORT=51820 #optional
      - PEERS=1 #optional
      - PEERDNS=auto #optional
      - INTERNAL_SUBNET=10.13.13.0 #optional
      - ALLOWEDIPS=0.0.0.0/0 #optional
      - PERSISTENTKEEPALIVE_PEERS= #optional
      - LOG_CONFS=true #optional
    volumes:
      - /path/to/wireguard/config:/config
      - /lib/modules:/lib/modules #optional
    ports:
      - 51820:51820/udp
    sysctls:
      - net.ipv4.conf.all.src_valid_mark=1
    restart: unless-stopped
```

### docker cli

```bash
docker run -d \
  --name=wireguard \
  --cap-add=NET_ADMIN \
  --cap-add=SYS_MODULE `#optional` \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=Etc/UTC \
  -e SERVERURL=wireguard.domain.com `#optional` \
  -e SERVERPORT=51820 `#optional` \
  -e PEERS=1 `#optional` \
  -e PEERDNS=auto `#optional` \
  -e INTERNAL_SUBNET=10.13.13.0 `#optional` \
  -e ALLOWEDIPS=0.0.0.0/0 `#optional` \
  -e PERSISTENTKEEPALIVE_PEERS= `#optional` \
  -e LOG_CONFS=true `#optional` \
  -p 51820:51820/udp \
  -v /path/to/wireguard/config:/config \
  -v /lib/modules:/lib/modules `#optional` \
  --sysctl="net.ipv4.conf.all.src_valid_mark=1" \
  --restart unless-stopped \
  ljrh/wireguard:latest
```

## Parameters

Containers are configured using parameters passed at runtime (such as those above). These parameters are separated by a colon and indicate `<external>:<internal>` respectively. For example, `-p 8080:80` would expose port `80` from inside the container to be accessible from the host's IP on port `8080` outside the container.

| Parameter | Function |
| :----: | --- |
| `-p 51820/udp` | wireguard port |
| `-e PUID=1000` | for UserID - see below for explanation |
| `-e PGID=1000` | for GroupID - see below for explanation |
| `-e TZ=Etc/UTC` | specify a timezone to use, see this [list](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones#List). |
| `-e SERVERURL=wireguard.domain.com` | External IP or domain name for docker host. Used in server mode. If set to `auto`, the container will try to determine and set the external IP automatically |
| `-e SERVERPORT=51820` | External port for docker host. Used in server mode. |
| `-e PEERS=1` | Number of peers to create confs for. Required for server mode. Can also be a list of names: `myPC,myPhone,myTablet` (alphanumeric only) |
| `-e PEERDNS=auto` | DNS server set in peer/client configs (can be set as `8.8.8.8`). Used in server mode. Defaults to `auto`, which uses wireguard docker host's DNS via included CoreDNS forward. |
| `-e INTERNAL_SUBNET=10.13.13.0` | Internal subnet for the wireguard and server and peers (only change if it clashes). Used in server mode. |
| `-e ALLOWEDIPS=0.0.0.0/0` | The IPs/Ranges that the peers will be able to reach using the VPN connection. If not specified the default value is: '0.0.0.0/0, ::0/0' This will cause ALL traffic to route through the VPN, if you want split tunneling, set this to only the IPs you would like to use the tunnel AND the ip of the server's WG ip, such as 10.13.13.1. |
| `-e PERSISTENTKEEPALIVE_PEERS=` | Set to `all` or a list of comma separated peers (ie. `1,4,laptop`) for the wireguard server to send keepalive packets to listed peers every 25 seconds. Useful if server is accessed via domain name and has dynamic IP. Used only in server mode. |
| `-e LOG_CONFS=true` | Generated QR codes will be displayed in the docker log. Set to `false` to skip log output. |
| `-v /config` | Contains all relevant configuration files. |
| `-v /lib/modules` | Path to host kernel module for situations where it's not already loaded. |
| `--sysctl=` | Required for client mode. |
| `--cap-add=NET_ADMIN` | Necessary for Wireguard to create its VPN interface. |
| `--cap-add=SYS_MODULE` | Necessary for loading Wireguard kernel module if it's not already loaded. |
| `--read-only=true` | Run container with a read-only filesystem. Not supported in client mode. |

## User / Group Identifiers

When using volumes (`-v` flags), permissions issues can arise between the host OS and the container, we avoid this issue by allowing you to specify the user `PUID` and group `PGID`.

Ensure any volume directories on the host are owned by the same user you specify and any permissions issues will vanish like magic.

In this instance `PUID=1000` and `PGID=1000`, to find yours use `id your_user` as below:

```bash
id your_user
```

Example output:

```text
uid=1000(your_user) gid=1000(your_user) groups=1000(your_user)
```

## Docker Mods

This image is built on the LinuxServer.io Alpine base image, so [Docker Mods](https://github.com/linuxserver/docker-mods) work exactly as they do with the upstream image.

## Support Info

* Shell access whilst the container is running:

    ```bash
    docker exec -it wireguard /bin/bash
    ```

* To monitor the logs of the container in realtime:

    ```bash
    docker logs -f wireguard
    ```

* Check the running tunnel and peers:

    ```bash
    docker exec wireguard wg show
    ```

* Test the bundled CoreDNS from inside the container (server mode):

    ```bash
    docker exec wireguard nslookup example.com 10.13.13.1
    ```

* Container version number:

    ```bash
    docker inspect -f '{{ index .Config.Labels "build_version" }}' wireguard
    ```

* Image version number:

    ```bash
    docker inspect -f '{{ index .Config.Labels "build_version" }}' ljrh/wireguard:latest
    ```

## Updating Info

Below are the instructions for updating containers.

### Via Docker Compose

* Update images:
    * All images:

        ```bash
        docker-compose pull
        ```

    * Single image:

        ```bash
        docker-compose pull wireguard
        ```

* Update containers:
    * All containers:

        ```bash
        docker-compose up -d
        ```

    * Single container:

        ```bash
        docker-compose up -d wireguard
        ```

* You can also remove the old dangling images:

    ```bash
    docker image prune
    ```

### Via Docker Run

* Update the image:

    ```bash
    docker pull ljrh/wireguard:latest
    ```

* Stop the running container:

    ```bash
    docker stop wireguard
    ```

* Delete the container:

    ```bash
    docker rm wireguard
    ```

* Recreate a new container with the same docker run parameters as instructed above (if mapped correctly to a host folder, your `/config` folder and settings will be preserved)
* You can also remove the old dangling images:

    ```bash
    docker image prune
    ```

## Building locally

If you want to make local modifications to this image for development purposes or just to customize the logic:

```bash
git clone https://github.com/LJRH/docker-wireguard.git
cd docker-wireguard
docker build \
  --no-cache \
  --pull \
  -t ljrh/wireguard:latest .
```

On an ARM64 host use `-f Dockerfile.aarch64`. The build clones and compiles CoreDNS, so expect it to take a few minutes longer than the upstream image.

To bump CoreDNS or Go, change `COREDNS_VERSION` and the `GOTOOLCHAIN` / `GOLANG_VERSION` values in **both** Dockerfiles, and adjust the `go get` / `go mod edit -replace` pins as needed.

## Versions

Fork changelog (security-patch releases only; see the upstream repository for the full history):

* **26.09.26:** - Rebase to Alpine 3.24, aligning with upstream. Brings wireguard-tools 1.0.20260223-r0 and busybox 1.37.0-r31, which clears CVE-2025-60876. Drop `unbound-dev` from build deps (CoreDNS has no unbound plugin, so libunbound was never linked). Drop the `wg-quick` sysctl sed patch, now redundant as wireguard-tools 1.0.20260223 ships the src_valid_mark guard upstream. Consolidate the repeated `GOTOOLCHAIN` pins into one variable; Alpine 3.24 ships Go 1.26.8, so the toolchain no longer needs downloading at build time. Add `iputils` to match upstream's package list. `net-tools` is deliberately omitted: nothing in the image uses it and it carries unfixed CVE-2025-46836.
* **06.09.26:** - Update CoreDNS to 1.14.7 and Go toolchain to 1.26.8 (fixes CVE-2026-39821, CVE-2026-56862, CVE-2026-56859, CVE-2026-56853, CVE-2026-46600, CVE-2026-42504, CVE-2026-33818 and further stdlib CVEs). Pin google.golang.org/grpc to v1.83.2 (GHSA-hrxh-6v49-42gf, CVE-2026-84304), go.etcd.io/etcd/client to v3.6.14 (CVE-2026-73500), golang.org/x/crypto to v0.56.0 (CVE-2026-78662, CVE-2026-56855, CVE-2026-56854) and golang.org/x/mod to v0.40.0 (CVE-2026-56865, CVE-2026-56864). Drop x/net pin as CoreDNS 1.14.7 already requires v0.57.0. Rebuild picks up OpenSSL 3.5.8-r0 from Alpine (CVE-2026-63073, CVE-2026-75803, CVE-2026-34182 and others).
* **27.05.26:** - Bump golang.org/x/net pin to v0.55.0 to fix CVE-2026-39821 (CRITICAL, CVSS 10.0 — IDNA Punycode validation bypass in ToASCII/ToUnicode).
* **23.05.26:** - Update CoreDNS to 1.14.3 (fixes CVE-2026-33190, CVE-2026-32936, CVE-2026-32934, CVE-2026-35579, CVE-2026-33489) and Go toolchain to 1.26.3 (fixes CVE-2026-42499, CVE-2026-39836, CVE-2026-39820, CVE-2026-33814, CVE-2026-33811). Pin golang.org/x/crypto to v0.52.0 (CVE-2026-46597) and golang.org/x/net to v0.53.0 (CVE-2026-33814) in CoreDNS build.
* **22.04.26:** - Remove jq from image to fix CVE-2026-32316 (heap buffer overflow). No fix available in Alpine 3.23 packages.
* **11.04.26:** - Rebase to Alpine 3.23. Upgrade Go toolchain to 1.26.2 to fix CVE-2026-32283 (crypto/tls deadlock) and CVE-2026-27140 (cmd/go build-time code execution). Update APKINDEX URL to v3.23.
* **28.03.26:** - Pin google.golang.org/grpc to v1.79.3 in CoreDNS build to fix CVE-2026-33186.
* **11.03.26:** - Update CoreDNS to 1.14.2 to fix CVE-2026-26017 and CVE-2026-26018.
* **11.03.26:** - Upgrade Go toolchain to 1.26.1 for CoreDNS build.
* **02.03.26:** - Update CoreDNS to 1.14.1 and Go to 1.25.7 to fix CVE-2025-61728, CVE-2025-61726, CVE-2025-68121, CVE-2025-61731, CVE-2025-68119 and additional security fixes in crypto/tls.
* **01.01.26:** - Update CoreDNS build to use Go 1.25.5 and update dependencies to fix CVEs. Add apk upgrade to build process.
* **22.12.25:** - Build CoreDNS from source with Go 1.24.11 to fix security vulnerabilities (CVE-2025-22871 and others).

## License, credits and disclaimer

This is an independent fork of [linuxserver/docker-wireguard](https://github.com/linuxserver/docker-wireguard) and is **not endorsed by or affiliated with LinuxServer.io**. All container design credit belongs to the LinuxServer.io team. The image is distributed under the same **GPL-3.0** license as upstream; source for every published tag is available in the GitHub repository.

* WireGuard® is a registered trademark of Jason A. Donenfeld. https://www.wireguard.com/
* CoreDNS: https://coredns.io/ (Apache-2.0)
* Alpine Linux: https://alpinelinux.org/

No warranty is provided. Use at your own risk. Security issues with this fork should be reported via GitHub issues; issues in WireGuard, CoreDNS or the LinuxServer.io base image should go to their respective projects.
