# Setup Guide: GitHub + Docker Hub

## Part 1: GitHub Setup (Required for GPL Compliance)

### Step 1: Create a New Repository on GitHub

1. Go to https://github.com/new
2. Fill in:
   - **Repository name**: `docker-wireguard-patched` (or your preferred name)
   - **Description**: `LinuxServer.io WireGuard with CoreDNS security patches (CVE-2025-22871 fix)`
   - **Visibility**: ✅ **Public** (required for GPL-3.0 compliance)
   - **Initialize**: Leave unchecked (we already have files)
3. Click "Create repository"
4. **Copy the repository URL** (should be like: `https://github.com/YOUR-USERNAME/docker-wireguard-patched.git`)

### Step 2: Update Git Configuration

Run these commands in `/home/lukehiggins/docker-wireguard`:

```bash
# Create a new branch for your changes
git checkout -b security-patches

# Stage your modified files
git add Dockerfile Dockerfile.aarch64 readme-vars.yml AGENTS.md

# Commit your changes
git commit -m "Add CoreDNS security patches

- Build CoreDNS 1.13.2 from source with Go 1.25.5
- Fixes CVE-2025-22871 (CRITICAL) and 6 HIGH severity vulnerabilities
- Original Go 1.24.1 in Alpine package was vulnerable
- Minimal changes to maintain compatibility"

# Add your new GitHub repo as a remote
git remote add myfork https://github.com/YOUR-USERNAME/docker-wireguard-patched.git

# Push to your fork
git push -u myfork security-patches
```

### Step 3: Create a README for Your Fork

Create `README.SECURITY.md`:

```markdown
# WireGuard Docker - Security Patched

This is a **security-patched fork** of [LinuxServer.io's WireGuard Docker image](https://github.com/linuxserver/docker-wireguard).

## ⚠️ Security Fixes

This fork addresses critical vulnerabilities in CoreDNS:
- **CVE-2025-22871** (CRITICAL) - HTTP Request Smuggling
- **CVE-2025-61729** (HIGH) - Certificate hostname DoS
- **CVE-2025-61725** (HIGH) - Email parsing CPU exhaustion
- **CVE-2025-61723** (HIGH) - PEM parsing DoS
- **CVE-2025-58188** (HIGH) - DSA certificate panic
- **CVE-2025-58187** (HIGH) - Certificate validation DoS
- **CVE-2025-22874** (HIGH) - Policy validation bypass

## 🔧 Modifications

1. **CoreDNS built from source**: Version 1.13.2 (upgraded from 1.12.1)
2. **Go version**: Built with Go 1.25.5 (fixes all vulnerabilities)
3. **Original issue**: Alpine's CoreDNS package used vulnerable Go 1.24.1

## 📦 Docker Image

Available on Docker Hub: `YOUR-DOCKERHUB-USERNAME/wireguard`

```bash
docker pull YOUR-DOCKERHUB-USERNAME/wireguard:latest
```

## 🚀 Usage

Same as the original LinuxServer.io image. See [upstream documentation](https://github.com/linuxserver/docker-wireguard).

```yaml
services:
  wireguard:
    image: YOUR-DOCKERHUB-USERNAME/wireguard:latest
    container_name: wireguard
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Etc/UTC
      - SERVERURL=auto
      - SERVERPORT=51820
      - PEERS=1
      - PEERDNS=auto
    volumes:
      - ./config:/config
      - /lib/modules:/lib/modules
    ports:
      - 51820:51820/udp
    sysctls:
      - net.ipv4.conf.all.src_valid_mark=1
    restart: unless-stopped
```

## 📝 Changes Made

See `readme-vars.yml` changelog:
- Date: 22.12.25
- Description: Build CoreDNS from source with Go 1.25.5 to fix security vulnerabilities

Dockerfile changes:
- Removed Alpine `coredns` package (vulnerable)
- Added build dependencies: `git`, `go`, `make`, `unbound-dev`
- Build CoreDNS 1.13.2 from source during image build
- Clean up build dependencies after compilation

## 📄 License

This project inherits the **GPL-3.0** license from LinuxServer.io's docker-wireguard.

## 🙏 Credits

- **Original Project**: [LinuxServer.io docker-wireguard](https://github.com/linuxserver/docker-wireguard)
- **WireGuard**: [wireguard.com](https://www.wireguard.com/)
- **CoreDNS**: [coredns.io](https://coredns.io/)

## 🔒 Security

This fork is maintained for security purposes. If you find vulnerabilities, please open an issue.

## ⚖️ Compliance

This is an open source fork complying with GPL-3.0:
- ✅ Source code publicly available
- ✅ Original copyright preserved
- ✅ Modifications clearly documented
- ✅ Same GPL-3.0 license maintained
```

Save this as README.md in your repo.

---

## Part 2: Docker Hub Setup

### Step 1: Login to Docker Hub

```bash
# Login to Docker Hub
docker login

# Enter your Docker Hub username and password when prompted
```

### Step 2: Tag Your Image

Replace `YOUR-DOCKERHUB-USERNAME` with your actual Docker Hub username:

```bash
# Tag with multiple versions for flexibility
docker tag ljrh/wireguard:latest YOUR-DOCKERHUB-USERNAME/wireguard:latest
docker tag ljrh/wireguard:latest YOUR-DOCKERHUB-USERNAME/wireguard:$(date +%Y%m%d)
docker tag ljrh/wireguard:latest YOUR-DOCKERHUB-USERNAME/wireguard:patched-go1.25.5
docker tag ljrh/wireguard:latest YOUR-DOCKERHUB-USERNAME/wireguard:coredns-1.13.2

# Verify tags
docker images | grep wireguard
```

### Step 3: Push to Docker Hub

```bash
# Push all tags
docker push YOUR-DOCKERHUB-USERNAME/wireguard:latest
docker push YOUR-DOCKERHUB-USERNAME/wireguard:$(date +%Y%m%d)
docker push YOUR-DOCKERHUB-USERNAME/wireguard:patched-go1.25.5
docker push YOUR-DOCKERHUB-USERNAME/wireguard:coredns-1.13.2
```

This will take a few minutes as it uploads the ~44MB image.

### Step 4: Update Docker Hub Repository

1. Go to https://hub.docker.com/r/YOUR-DOCKERHUB-USERNAME/wireguard
2. Click "Edit" or go to Settings
3. Update the **Description**:

```markdown
# WireGuard VPN - Security Patched

Security-patched version of LinuxServer.io's WireGuard Docker image.

## 🔒 Security Fixes

Addresses critical Go vulnerabilities in CoreDNS:
- CVE-2025-22871 (CRITICAL) - HTTP Request Smuggling
- 6 HIGH severity vulnerabilities in Go stdlib

## 🔧 Changes

- CoreDNS 1.13.2 built from source with Go 1.25.5
- Based on Alpine 3.22
- Original Alpine package used vulnerable Go 1.24.1

## 📖 Documentation

Full documentation: https://github.com/YOUR-USERNAME/docker-wireguard-patched

## 📦 Tags

- `latest` - Latest security patched version
- `YYYYMMDD` - Date-based tags for stability
- `patched-go1.25.5` - Specific Go version
- `coredns-1.13.2` - Specific CoreDNS version

## 🙏 Credits

Based on LinuxServer.io's docker-wireguard (GPL-3.0)
- Original: https://github.com/linuxserver/docker-wireguard
- Source: https://github.com/YOUR-USERNAME/docker-wireguard-patched

## ⚖️ License

GPL-3.0 (inherited from LinuxServer.io)
```

4. Save the description

---

## Part 3: Deploy to Your Infrastructure

### Option A: bastionvps

Create/update your docker-compose.yml:

```yaml
services:
  wireguard:
    image: YOUR-DOCKERHUB-USERNAME/wireguard:latest
    container_name: wireguard
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Etc/UTC
      - SERVERURL=auto
      - SERVERPORT=51820
      - PEERS=5  # Adjust as needed
      - PEERDNS=auto
      - INTERNAL_SUBNET=10.13.13.0
      - ALLOWEDIPS=0.0.0.0/0
    volumes:
      - ./wireguard-config:/config
      - /lib/modules:/lib/modules
    ports:
      - 51820:51820/udp
    sysctls:
      - net.ipv4.conf.all.src_valid_mark=1
    restart: unless-stopped
```

Deploy:
```bash
docker-compose pull
docker-compose up -d
docker-compose logs -f wireguard
```

### Option B: /dockerpool/network

Same compose file, just place in `/dockerpool/network/wireguard/docker-compose.yml`

```bash
cd /dockerpool/network
mkdir -p wireguard
cd wireguard
# Create docker-compose.yml with content above
docker-compose up -d
```

---

## Quick Commands Reference

### GitHub Quick Start
```bash
cd /home/lukehiggins/docker-wireguard
git checkout -b security-patches
git add Dockerfile Dockerfile.aarch64 readme-vars.yml AGENTS.md
git commit -m "Add CoreDNS security patches"
git remote add myfork https://github.com/YOUR-USERNAME/docker-wireguard-patched.git
git push -u myfork security-patches
```

### Docker Hub Quick Start
```bash
docker login
docker tag ljrh/wireguard:latest YOUR-USERNAME/wireguard:latest
docker tag ljrh/wireguard:latest YOUR-USERNAME/wireguard:$(date +%Y%m%d)
docker push YOUR-USERNAME/wireguard:latest
docker push YOUR-USERNAME/wireguard:$(date +%Y%m%d)
```

### Deployment Quick Start
```bash
# Pull and run
docker pull YOUR-USERNAME/wireguard:latest
docker run -d --name wireguard \
  --cap-add=NET_ADMIN \
  --cap-add=SYS_MODULE \
  -e SERVERURL=auto \
  -e SERVERPORT=51820 \
  -e PEERS=2 \
  -e PEERDNS=auto \
  -v ./config:/config \
  -v /lib/modules:/lib/modules \
  -p 51820:51820/udp \
  --sysctl="net.ipv4.conf.all.src_valid_mark=1" \
  YOUR-USERNAME/wireguard:latest
```

---

## Verification

### Verify Image Security
```bash
# Check CoreDNS version
docker run --rm YOUR-USERNAME/wireguard:latest /usr/bin/coredns -version

# Should output: CoreDNS-1.13.2, linux/amd64, go1.25.5
```

### Verify Container Running
```bash
docker ps | grep wireguard
docker logs wireguard
docker exec wireguard wg show
```

### Test DNS
```bash
docker exec wireguard nslookup google.com 10.13.13.1
```

---

## Troubleshooting

### Issue: Git push fails
**Solution**: Make sure you created the repo on GitHub first and used the correct URL.

### Issue: Docker push fails
**Solution**: Run `docker login` and verify your credentials.

### Issue: Image size too large
**Note**: ~44MB is normal. The compressed size on Docker Hub will be smaller (~20MB).

### Issue: WireGuard module not loading
**Solution**: Make sure your host kernel has WireGuard support or the module is loadable.

---

## Success Checklist

- [ ] Created public GitHub repository
- [ ] Pushed modified Dockerfiles to GitHub
- [ ] Added README.md with attribution
- [ ] LICENSE file present (GPL-3.0)
- [ ] Logged into Docker Hub
- [ ] Tagged image with multiple versions
- [ ] Pushed image to Docker Hub
- [ ] Updated Docker Hub description
- [ ] Linked GitHub repo in Docker Hub
- [ ] Tested deployment locally
- [ ] Deployed to bastionvps (if applicable)
- [ ] Deployed to /dockerpool/network (if applicable)
- [ ] Verified CoreDNS version shows go1.25.5
- [ ] Verified WireGuard interface works
- [ ] Verified DNS resolution works

You're all set! 🎉
