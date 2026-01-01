# Ready to Publish! 🚀

All files have been updated with your GitHub username: **LJRH**

## ✅ Pre-flight Checklist

- [x] Dockerfiles modified to build CoreDNS from source
- [x] Changelog updated in readme-vars.yml
- [x] Docker image built and tested locally
- [x] SSH authentication to GitHub verified
- [x] Documentation created and personalized
- [x] GPL-3.0 LICENSE file present
- [x] All placeholders replaced with LJRH username

## 🎯 You're Ready to Publish!

### Option 1: Automated (Recommended) ⚡

```bash
cd /home/lukehiggins/docker-wireguard
./publish.sh
```

The script will:
1. Ask for your Docker Hub username
2. Commit your changes
3. Push to GitHub at: `git@github.com:LJRH/docker-wireguard-patched.git`
4. Tag and push Docker images
5. Guide you through Docker Hub setup

**Time:** ~10 minutes

### Option 2: Manual Step-by-Step 📋

#### Step 1: Create GitHub Repository
1. Go to: https://github.com/new
2. Repository name: `docker-wireguard-patched`
3. Description: `LinuxServer.io WireGuard with CoreDNS security patches (CVE-2025-22871 fix)`
4. Visibility: **PUBLIC** ⚠️ (required for GPL-3.0)
5. Do NOT initialize with README
6. Click "Create repository"

#### Step 2: Push to GitHub

```bash
cd /home/lukehiggins/docker-wireguard

# Create and switch to security-patches branch
git checkout -b security-patches

# Stage your files
git add Dockerfile Dockerfile.aarch64 readme-vars.yml AGENTS.md \
        README.SECURITY.md SETUP_GUIDE.md QUICK_START.md

# Commit
git commit -m "Add CoreDNS security patches

- Build CoreDNS 1.13.2 from source with Go 1.25.5
- Fixes CVE-2025-22871 (CRITICAL) and 6 HIGH severity vulnerabilities
- Original Go 1.24.1 in Alpine package was vulnerable
- Minimal changes to maintain compatibility
- GPL-3.0 compliant with full attribution"

# Add your GitHub repo as remote (SSH)
git remote add myfork git@github.com:LJRH/docker-wireguard-patched.git

# Push to GitHub
git push -u myfork security-patches
```

✅ **Verify:** Visit https://github.com/LJRH/docker-wireguard-patched

#### Step 3: Docker Hub Setup

```bash
# Login to Docker Hub
docker login -u LJRH
# (or your Docker Hub username if different)

# Tag your images
docker tag ljrh/wireguard:latest LJRH/wireguard:latest
docker tag ljrh/wireguard:latest LJRH/wireguard:$(date +%Y%m%d)
docker tag ljrh/wireguard:latest LJRH/wireguard:patched-go1.25.5
docker tag ljrh/wireguard:latest LJRH/wireguard:coredns-1.13.2

# Push to Docker Hub
docker push LJRH/wireguard:latest
docker push LJRH/wireguard:$(date +%Y%m%d)
docker push LJRH/wireguard:patched-go1.25.5
docker push LJRH/wireguard:coredns-1.13.2
```

#### Step 4: Update Docker Hub Description

1. Go to: https://hub.docker.com/r/LJRH/wireguard/settings/general
2. Copy this description:

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

Full documentation: https://github.com/LJRH/docker-wireguard-patched

## 📦 Tags

- `latest` - Latest security patched version
- `YYYYMMDD` - Date-based tags for stability
- `patched-go1.25.5` - Specific Go version
- `coredns-1.13.2` - Specific CoreDNS version

## 🙏 Credits

Based on LinuxServer.io's docker-wireguard (GPL-3.0)
- Original: https://github.com/linuxserver/docker-wireguard
- Source: https://github.com/LJRH/docker-wireguard-patched

## ⚖️ License

GPL-3.0 (inherited from LinuxServer.io)
```

3. In "Source Repository" field, enter: `https://github.com/LJRH/docker-wireguard-patched`
4. Click "Update"

## 🧪 Verification

After publishing, verify everything works:

```bash
# Pull from Docker Hub
docker pull LJRH/wireguard:latest

# Verify CoreDNS version (should show go1.25.5)
docker run --rm LJRH/wireguard:latest /usr/bin/coredns -version
# Expected: CoreDNS-1.13.2, linux/amd64, go1.25.5

# Test deployment
docker run -d --name test-wireguard \
  --cap-add=NET_ADMIN \
  --cap-add=SYS_MODULE \
  -e SERVERURL=auto \
  -e SERVERPORT=51820 \
  -e PEERS=1 \
  -e PEERDNS=auto \
  -v ./test-config:/config \
  -p 51820:51820/udp \
  --sysctl="net.ipv4.conf.all.src_valid_mark=1" \
  LJRH/wireguard:latest

# Check logs
docker logs test-wireguard

# Cleanup
docker stop test-wireguard && docker rm test-wireguard
```

## 🚀 Deploy to Your Infrastructure

### bastionvps

Update your docker-compose.yml:

```yaml
services:
  wireguard:
    image: LJRH/wireguard:latest  # ← Your patched image
    container_name: wireguard
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    environment:
      - SERVERURL=auto
      - SERVERPORT=51820
      - PEERS=5
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

Deploy:
```bash
docker-compose pull
docker-compose up -d
```

### /dockerpool/network

```bash
cd /dockerpool/network/wireguard
# Use same docker-compose.yml as above
docker-compose up -d
```

## ✅ Success Criteria

After publishing, you should have:

- [ ] GitHub repository is public at: https://github.com/LJRH/docker-wireguard-patched
- [ ] README.SECURITY.md is visible on GitHub
- [ ] LICENSE file (GPL-3.0) is present
- [ ] Docker image available at: https://hub.docker.com/r/LJRH/wireguard
- [ ] Docker Hub description includes attribution to LinuxServer.io
- [ ] Docker Hub links to your GitHub repository
- [ ] Test pull succeeds: `docker pull LJRH/wireguard:latest`
- [ ] CoreDNS version shows: `go1.25.5`
- [ ] Container starts successfully
- [ ] WireGuard interface works
- [ ] DNS resolution works through CoreDNS

## 📁 File Summary

All documentation is ready:

| File | Purpose |
|------|---------|
| `Dockerfile` | Modified to build CoreDNS from source (amd64) |
| `Dockerfile.aarch64` | Modified to build CoreDNS from source (ARM64) |
| `readme-vars.yml` | Updated changelog |
| `AGENTS.md` | Build guidelines for AI agents |
| `README.SECURITY.md` | Main README for GitHub repo |
| `SETUP_GUIDE.md` | Detailed setup instructions |
| `QUICK_START.md` | Quick reference guide |
| `publish.sh` | Automated publishing script |
| `LICENSE` | GPL-3.0 license (unchanged) |

## 🎉 Ready to Go!

Choose your path:
- **Quick:** Run `./publish.sh` and follow prompts
- **Manual:** Follow steps above

Both paths will get you published in ~10-15 minutes!

## 📞 Need Help?

- GitHub Issues: https://github.com/LJRH/docker-wireguard-patched/issues (after creation)
- Upstream: https://github.com/linuxserver/docker-wireguard

---

**Good luck! 🚀**
