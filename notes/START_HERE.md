# 🚀 START HERE

> **Historical.** This describes the one-time fork publication in Dec 2025 and
> references `scripts/publish.sh`, which has been removed. For the current
> release process see the "Release Process" section of `CLAUDE.md`:
> `scripts/check-versions.sh`, `scripts/scan.sh`, `scripts/release.sh`.

## What You Have

A **security-patched** WireGuard Docker image that fixes:
- ✅ CVE-2025-22871 (CRITICAL) 
- ✅ 6 HIGH severity vulnerabilities

**Image**: `ljrh/wireguard:latest` (built and tested locally)

## Next Steps

### Quick Path (Recommended) ⚡
```bash
cd /home/lukehiggins/docker-wireguard
./publish.sh
```
**Time: ~10 minutes**

### Manual Path 📋
1. Read `READY_TO_PUBLISH.md`
2. Follow step-by-step instructions

## After Publishing

Update your deployments:

**bastionvps** or **/dockerpool/network**:
```yaml
services:
  wireguard:
    image: LJRH/wireguard:latest  # ← Your patched image
    # ... rest of config
```

## Documentation

- `READY_TO_PUBLISH.md` - Complete publishing guide
- `SETUP_GUIDE.md` - Detailed steps
- `QUICK_START.md` - Quick reference
- `README.SECURITY.md` - GitHub repo README

## Key Info

- **GitHub Repo**: Will be at `git@github.com:LJRH/docker-wireguard-patched.git`
- **Docker Hub**: Will be at `LJRH/wireguard`
- **License**: GPL-3.0 (compliant)
- **SSH**: Already configured ✅

**Ready to publish! Choose your path above.**
