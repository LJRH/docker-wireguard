# Quick Start Guide

## 🚀 The Fastest Way to Publish

### Automated Script (Recommended)

```bash
cd /home/lukehiggins/docker-wireguard
./publish.sh
```

The script will guide you through:
1. ✅ Collecting your GitHub and Docker Hub usernames
2. ✅ Setting up git and committing changes
3. ✅ Pushing to GitHub
4. ✅ Tagging and pushing to Docker Hub

---

## 📋 Manual Steps (If You Prefer)

### Part 1: GitHub (5 minutes)

```bash
# 1. Create repo on GitHub at: https://github.com/new
#    Name: docker-wireguard-patched (PUBLIC)

# 2. Prepare and push
cd /home/lukehiggins/docker-wireguard
git checkout -b security-patches
git add Dockerfile Dockerfile.aarch64 readme-vars.yml AGENTS.md README.SECURITY.md
git commit -m "Add CoreDNS security patches"
git remote add myfork git@github.com:LJRH/docker-wireguard-patched.git
git push -u myfork security-patches
```

### Part 2: Docker Hub (5 minutes)

```bash
# 1. Login
docker login

# 2. Tag your image
docker tag ljrh/wireguard:latest LJRH/wireguard:latest
docker tag ljrh/wireguard:latest LJRH/wireguard:$(date +%Y%m%d)

# 3. Push
docker push LJRH/wireguard:latest
docker push LJRH/wireguard:$(date +%Y%m%d)
```

### Part 3: Update Docker Hub Description (2 minutes)

1. Go to: `https://hub.docker.com/r/LJRH/wireguard/settings/general`
2. Copy description from `SETUP_GUIDE.md` section 4
3. Link to your GitHub repo
4. Save

---

## ✅ Verification

```bash
# Test pull from Docker Hub
docker pull LJRH/wireguard:latest

# Verify Go version (should show go1.25.5)
docker run --rm LJRH/wireguard:latest /usr/bin/coredns -version
```

---

## 🎯 Deploy to Your Infrastructure

### bastionvps

```yaml
# docker-compose.yml
services:
  wireguard:
    image: LJRH/wireguard:latest
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

```bash
docker-compose up -d
```

### /dockerpool/network

Same compose file, just different location:

```bash
cd /dockerpool/network
mkdir wireguard
cd wireguard
# Create docker-compose.yml
docker-compose up -d
```

---

## 🆘 Troubleshooting

### "Permission denied" on publish.sh
```bash
chmod +x publish.sh
```

### "Authentication required" on git push
```bash
# Make sure SSH key is set up with GitHub
# Check: ssh -T git@github.com
# Should see: "Hi LJRH! You've successfully authenticated..."

# If not set up, add your SSH key:
# 1. Generate key: ssh-keygen -t ed25519 -C "your_email@example.com"
# 2. Add to GitHub: https://github.com/settings/keys
# 3. Copy public key: cat ~/.ssh/id_ed25519.pub
```

### "denied: requested access to the resource is denied" on docker push
```bash
docker login  # Login again
# Make sure repository exists on Docker Hub
```

### Can't find Docker Hub repository
Create it first at: https://hub.docker.com/repository/create

---

## 📚 Full Documentation

- **Setup Guide**: `SETUP_GUIDE.md` - Detailed step-by-step
- **Licensing**: `/tmp/wireguard-test/LICENSING_GUIDE.md` - Legal compliance
- **Security README**: `README.SECURITY.md` - For GitHub repo

---

## ⏱️ Time Estimate

- **Automated (publish.sh)**: ~10 minutes
- **Manual**: ~15 minutes
- **Docker Hub description**: +5 minutes
- **Total**: 15-20 minutes

---

## 🎉 Success Criteria

- [ ] GitHub repo is public
- [ ] README.SECURITY.md is visible
- [ ] LICENSE file present
- [ ] Image on Docker Hub
- [ ] Docker Hub description added
- [ ] GitHub link in Docker Hub
- [ ] Local test passes: `docker run --rm YOUR-USER/wireguard:latest /usr/bin/coredns -version`
- [ ] Shows: `CoreDNS-1.13.2, linux/amd64, go1.25.5`

**You're done! 🚀**
