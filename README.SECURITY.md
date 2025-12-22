# WireGuard Docker - Security Patched

This is a **security-patched fork** of [LinuxServer.io's WireGuard Docker image](https://github.com/linuxserver/docker-wireguard).

## ⚠️ Security Fixes

This fork addresses critical vulnerabilities in CoreDNS that were present in the Alpine package:

### Critical Vulnerabilities Fixed:
- **CVE-2025-22871** (CRITICAL) - HTTP Request Smuggling in net/http
- **CVE-2025-61729** (HIGH) - Certificate hostname error excessive resource consumption
- **CVE-2025-61725** (HIGH) - Email ParseAddress CPU exhaustion
- **CVE-2025-61723** (HIGH) - PEM parsing non-linear time complexity
- **CVE-2025-58188** (HIGH) - DSA certificate validation panic
- **CVE-2025-58187** (HIGH) - Certificate name constraint checking DoS
- **CVE-2025-22874** (HIGH) - Certificate policy validation bypass

### Root Cause:
Alpine 3.22's `coredns` package (v1.12.1-r6) was compiled with **Go 1.24.1**, which contained these vulnerabilities despite Go 1.24.11 being available in Alpine's repositories.

### Solution:
This fork builds **CoreDNS 1.13.2 from source** during the Docker image build, using the system's Go compiler which pulls **Go 1.25.5** (includes all security fixes).

## 🔧 Modifications

### Changes Made:
1. **CoreDNS Version**: Upgraded from 1.12.1 → 1.13.2
2. **Go Version**: Built with Go 1.25.5 (was Go 1.24.1 in Alpine package)
3. **Build Process**: Changed from Alpine package to source compilation
4. **Dependencies Added** (build-time only): `git`, `go`, `make`, `unbound-dev`

### Files Modified:
- `Dockerfile` - Build CoreDNS from source for amd64
- `Dockerfile.aarch64` - Build CoreDNS from source for ARM64
- `readme-vars.yml` - Added changelog entry

### Impact:
- ✅ All security vulnerabilities fixed
- ✅ Functionally identical to upstream
- ✅ Same image size (~44MB)
- ✅ Full compatibility maintained
- ✅ All WireGuard features work unchanged

## 📦 Docker Image

**Docker Hub**: `ljrh/wireguard`

```bash
docker pull ljrh/wireguard:latest
```

### Available Tags:
- `latest` - Latest security-patched version
- `YYYYMMDD` - Date-based stable tags
- `patched-go1.25.5` - Specific Go version tag
- `coredns-1.13.2` - Specific CoreDNS version tag

## 🚀 Usage

This image is a drop-in replacement for `linuxserver/wireguard`. All original functionality is preserved.

### Docker Compose Example:

```yaml
services:
  wireguard:
    image: ljrh/wireguard:latest
    container_name: wireguard
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Etc/UTC
      - SERVERURL=auto  # or your domain/IP
      - SERVERPORT=51820
      - PEERS=2  # number of peer configs to generate
      - PEERDNS=auto  # uses CoreDNS on 10.13.13.1
      - INTERNAL_SUBNET=10.13.13.0
      - ALLOWEDIPS=0.0.0.0/0  # route all traffic through VPN
      - LOG_CONFS=true  # show QR codes in logs
    volumes:
      - ./config:/config
      - /lib/modules:/lib/modules
    ports:
      - 51820:51820/udp
    sysctls:
      - net.ipv4.conf.all.src_valid_mark=1
    restart: unless-stopped
```

### Docker Run Example:

```bash
docker run -d \
  --name=wireguard \
  --cap-add=NET_ADMIN \
  --cap-add=SYS_MODULE \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=Etc/UTC \
  -e SERVERURL=auto \
  -e SERVERPORT=51820 \
  -e PEERS=2 \
  -e PEERDNS=auto \
  -p 51820:51820/udp \
  -v ./config:/config \
  -v /lib/modules:/lib/modules \
  --sysctl="net.ipv4.conf.all.src_valid_mark=1" \
  --restart unless-stopped \
  ljrh/wireguard:latest
```

For detailed usage instructions, see the [upstream documentation](https://github.com/linuxserver/docker-wireguard).

## 🔍 Verification

### Check CoreDNS Version:
```bash
docker run --rm ljrh/wireguard:latest /usr/bin/coredns -version
```

Expected output:
```
CoreDNS-1.13.2
linux/amd64, go1.25.5, 0233f3e-dirty
```

### Verify WireGuard:
```bash
docker exec wireguard wg show
docker exec wireguard nslookup google.com 10.13.13.1
```

## 📝 Technical Details

### Build Process:

The modified Dockerfiles:
1. Install Alpine's Go 1.24.11 package + build tools
2. Clone CoreDNS 1.13.2 from GitHub
3. Compile with `CGO_ENABLED=1` for proper DNS resolution
4. Install compiled binary to `/usr/bin/coredns`
5. Remove build dependencies to minimize image size
6. Continue with original LinuxServer.io setup

### Why Go 1.25.5?

During the build, CoreDNS's dependencies require Go 1.25+. Go's toolchain management automatically downloads Go 1.25.5, which includes all security patches from:
- Go 1.24.11 (our target)
- Plus additional improvements from the 1.25 branch

This is actually better than our original goal of Go 1.24.11!

## 📊 Comparison

| Aspect | Original (linuxserver/wireguard) | This Fork |
|--------|----------------------------------|-----------|
| CoreDNS Version | 1.12.1 | 1.13.2 |
| Go Version | 1.24.1 (vulnerable) | 1.25.5 (patched) |
| Critical CVEs | 1 | 0 |
| High CVEs | 6 | 0 |
| Build Method | Alpine package | Source compilation |
| Image Size | ~44MB | ~44MB |
| Functionality | Full | Full (identical) |

## 🛠️ Building Locally

```bash
# Clone this repository
git clone https://github.com/LJRH/docker-wireguard-patched.git
cd docker-wireguard-patched

# Build for amd64
docker build --no-cache --pull -t my-wireguard:latest .

# Build for ARM64 (on ARM64 host or with buildx)
docker build --no-cache --pull -f Dockerfile.aarch64 -t my-wireguard:latest .
```

Build time: ~2-3 minutes (including CoreDNS compilation)

## 📄 License

This project inherits the **GNU General Public License v3.0 (GPL-3.0)** from LinuxServer.io's docker-wireguard.

See [LICENSE](LICENSE) file for full terms.

### License Compliance:
- ✅ Source code publicly available (this repository)
- ✅ Original copyright notices preserved
- ✅ Modifications clearly documented
- ✅ Same GPL-3.0 license maintained
- ✅ Appropriate legal notices displayed

## 🙏 Credits & Attribution

### Original Project:
**LinuxServer.io docker-wireguard**
- Repository: https://github.com/linuxserver/docker-wireguard
- License: GPL-3.0
- Maintained by: [LinuxServer.io Team](https://www.linuxserver.io/)

### Components:
- **WireGuard**: https://www.wireguard.com/ (GPLv2/MIT/BSD/Apache)
- **CoreDNS**: https://coredns.io/ (Apache-2.0)
- **Alpine Linux**: https://alpinelinux.org/ (various open source)

### This Fork:
Maintained for security purposes. All functionality and design credit goes to LinuxServer.io.

## 🔒 Security

### Reporting Vulnerabilities:
If you discover security vulnerabilities in this fork, please open an issue on GitHub.

For vulnerabilities in upstream components:
- WireGuard: https://www.wireguard.com/
- CoreDNS: https://github.com/coredns/coredns/security
- LinuxServer.io: https://github.com/linuxserver/docker-wireguard/security

### Security Updates:
This fork will be updated when:
- New critical/high vulnerabilities are discovered
- Alpine base image is updated
- CoreDNS releases security patches
- Go releases security patches

## 📮 Contact

- **Issues**: Open an issue on this repository
- **Upstream Issues**: Report to [LinuxServer.io](https://github.com/linuxserver/docker-wireguard)
- **Security**: See Security section above

## 🤝 Contributing

This is a security-focused fork. Contributions welcome for:
- Security improvements
- Documentation updates
- Bug fixes
- Keeping dependencies updated

Please open issues or pull requests on GitHub.

## ⚖️ Legal

This is a modified version of LinuxServer.io's docker-wireguard, distributed under GPL-3.0.

- No warranty provided (see GPL-3.0)
- Use at your own risk
- This is an independent fork, not officially endorsed by LinuxServer.io
- All trademarks belong to their respective owners

---

**Last Updated**: December 22, 2025  
**Fork Maintained By**: [Your Name/GitHub Username]  
**Based On**: [linuxserver/docker-wireguard](https://github.com/linuxserver/docker-wireguard)
