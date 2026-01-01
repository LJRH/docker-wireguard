# Docker Image Tags - Quick Reference

All tags point to the **same image** (same security patches, same functionality).

## Available Tags

| Tag | Use Case | Updates? |
|-----|----------|----------|
| `ljrh/wireguard:latest` | **Recommended for most users** | Yes (when you pull) |
| `ljrh/wireguard:20251222` | Production stability | No (pinned) |
| `ljrh/wireguard:coredns-1.13.2` | Track CoreDNS version | No (pinned) |
| `ljrh/wireguard:patched-go1.25.5` | Security audit trail | No (pinned) |

## Which Should You Use?

### For Your Deployments (bastionvps, /dockerpool/network)

**Option A - Always Get Updates (Recommended):**
```yaml
services:
  wireguard:
    image: ljrh/wireguard:latest
```

When you run `docker-compose pull`, you'll get any future updates automatically.

**Option B - Stable/Pinned Version:**
```yaml
services:
  wireguard:
    image: ljrh/wireguard:20251222
```

This exact build, won't change. Good for production if you want control over updates.

## When Publishing to Docker Hub

**Push ALL tags** - this gives users choice:

```bash
docker push ljrh/wireguard:latest
docker push ljrh/wireguard:20251222
docker push ljrh/wireguard:coredns-1.13.2
docker push ljrh/wireguard:patched-go1.25.5
```

The `publish.sh` script automatically does this for you.

## Quick Decision Guide

**Choose `:latest` if:**
- You want automatic security updates
- You trust your testing process
- You're okay with occasional changes

**Choose `:20251222` (date tag) if:**
- You need reproducible deployments
- You want to control when updates happen
- You're in production and want stability

**Choose `:coredns-1.13.2` if:**
- You care about CoreDNS version specifically
- You're tracking dependency versions

**Choose `:patched-go1.25.5` if:**
- You need to document which Go security patch you're using
- You're doing security compliance tracking

## Example Deployment

```yaml
version: "3.8"
services:
  wireguard:
    image: ljrh/wireguard:latest  # ← Recommended
    container_name: wireguard
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    environment:
      - SERVERURL=auto
      - SERVERPORT=51820
      - PEERS=2
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

## TL;DR

✅ **Use `ljrh/wireguard:latest` for your deployments**

All tags are the same image - just labeled differently for user convenience!
