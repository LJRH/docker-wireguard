#!/bin/bash
set -e

echo "=========================================="
echo "WireGuard Security Patch Publisher"
echo "=========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Step 1: Get user info
echo -e "${YELLOW}Step 1: User Information${NC}"
read -p "Enter your GitHub username: " GITHUB_USER
read -p "Enter your Docker Hub username: " DOCKER_USER
read -p "Enter your GitHub repository name (default: docker-wireguard-patched): " REPO_NAME
REPO_NAME=${REPO_NAME:-docker-wireguard-patched}

echo ""
echo "Configuration:"
echo "  GitHub: https://github.com/${GITHUB_USER}/${REPO_NAME}"
echo "  Docker Hub: ${DOCKER_USER}/wireguard"
echo ""
read -p "Is this correct? (y/n): " CONFIRM
if [ "$CONFIRM" != "y" ]; then
    echo "Aborted."
    exit 1
fi

# Step 2: Check if README exists
echo ""
echo -e "${YELLOW}Step 2: Preparing README${NC}"
if [ ! -f "README.SECURITY.md" ]; then
    echo -e "${RED}ERROR: README.SECURITY.md not found!${NC}"
    echo "Please create README.SECURITY.md first."
    exit 1
fi

# Update placeholders in README
sed -i "s/YOUR-DOCKERHUB-USERNAME/${DOCKER_USER}/g" README.SECURITY.md
sed -i "s/YOUR-USERNAME/${GITHUB_USER}/g" README.SECURITY.md
echo -e "${GREEN}✓ README updated with your usernames${NC}"

# Step 3: Git setup
echo ""
echo -e "${YELLOW}Step 3: Git Configuration${NC}"
echo "Current directory: $(pwd)"
echo ""

# Check if already on a branch
CURRENT_BRANCH=$(git branch --show-current)
echo "Current branch: ${CURRENT_BRANCH}"

if [ "$CURRENT_BRANCH" = "security-patches" ]; then
    echo -e "${GREEN}✓ Already on security-patches branch${NC}"
else
    echo "Creating security-patches branch..."
    git checkout -b security-patches || git checkout security-patches
fi

# Stage files
echo "Staging files..."
git add Dockerfile Dockerfile.aarch64 readme-vars.yml AGENTS.md README.SECURITY.md SETUP_GUIDE.md 2>/dev/null || true

# Check what will be committed
echo ""
echo "Files to be committed:"
git status --short

echo ""
read -p "Commit these changes? (y/n): " CONFIRM_COMMIT
if [ "$CONFIRM_COMMIT" != "y" ]; then
    echo "Skipping commit."
else
    git commit -m "Add CoreDNS security patches

- Build CoreDNS 1.13.2 from source with Go 1.25.5
- Fixes CVE-2025-22871 (CRITICAL) and 6 HIGH severity vulnerabilities
- Original Go 1.24.1 in Alpine package was vulnerable
- Minimal changes to maintain compatibility
- Added comprehensive documentation and attribution" || echo "Nothing to commit or already committed"
    echo -e "${GREEN}✓ Changes committed${NC}"
fi

# Step 4: GitHub remote
echo ""
echo -e "${YELLOW}Step 4: GitHub Repository Setup${NC}"
echo ""
echo -e "${YELLOW}ACTION REQUIRED:${NC}"
echo "1. Go to: https://github.com/new"
echo "2. Create a repository named: ${REPO_NAME}"
echo "3. Make it PUBLIC (required for GPL compliance)"
echo "4. Do NOT initialize with README"
echo ""
read -p "Press Enter when you've created the repository..."

# Add remote (using SSH)
REMOTE_URL="git@github.com:${GITHUB_USER}/${REPO_NAME}.git"
if git remote | grep -q "^myfork$"; then
    echo "Removing existing myfork remote..."
    git remote remove myfork
fi

echo "Adding GitHub remote: ${REMOTE_URL}"
git remote add myfork "${REMOTE_URL}"
echo -e "${GREEN}✓ Remote added${NC}"

# Push to GitHub
echo ""
echo "Pushing to GitHub..."
if git push -u myfork security-patches; then
    echo -e "${GREEN}✓ Successfully pushed to GitHub!${NC}"
    echo ""
    echo "View your repository: https://github.com/${GITHUB_USER}/${REPO_NAME}"
else
    echo -e "${RED}✗ Push failed. You may need to authenticate.${NC}"
    echo "Try:"
    echo "  git push -u myfork security-patches"
    exit 1
fi

# Step 5: Docker Hub
echo ""
echo -e "${YELLOW}Step 5: Docker Hub Publishing${NC}"
echo ""
read -p "Push to Docker Hub now? (y/n): " PUSH_DOCKER
if [ "$PUSH_DOCKER" != "y" ]; then
    echo "Skipping Docker Hub push."
    echo ""
    echo "To push later, run:"
    echo "  docker login"
    echo "  docker tag ljrh/wireguard:latest ${DOCKER_USER}/wireguard:latest"
    echo "  docker push ${DOCKER_USER}/wireguard:latest"
    exit 0
fi

# Docker login
echo "Logging into Docker Hub..."
if ! docker login; then
    echo -e "${RED}✗ Docker login failed${NC}"
    exit 1
fi

# Tag images
echo ""
echo "Tagging images..."
TODAY=$(date +%Y%m%d)
docker tag ljrh/wireguard:latest ${DOCKER_USER}/wireguard:latest
docker tag ljrh/wireguard:latest ${DOCKER_USER}/wireguard:${TODAY}
docker tag ljrh/wireguard:latest ${DOCKER_USER}/wireguard:patched-go1.25.5
docker tag ljrh/wireguard:latest ${DOCKER_USER}/wireguard:coredns-1.13.2
echo -e "${GREEN}✓ Images tagged${NC}"

# Push images
echo ""
echo "Pushing to Docker Hub (this may take a few minutes)..."
docker push ${DOCKER_USER}/wireguard:latest
docker push ${DOCKER_USER}/wireguard:${TODAY}
docker push ${DOCKER_USER}/wireguard:patched-go1.25.5
docker push ${DOCKER_USER}/wireguard:coredns-1.13.2
echo -e "${GREEN}✓ Images pushed to Docker Hub!${NC}"

# Final instructions
echo ""
echo "=========================================="
echo -e "${GREEN}SUCCESS!${NC}"
echo "=========================================="
echo ""
echo "✅ GitHub Repository: https://github.com/${GITHUB_USER}/${REPO_NAME}"
echo "✅ Docker Hub: https://hub.docker.com/r/${DOCKER_USER}/wireguard"
echo ""
echo "Next steps:"
echo "1. Update Docker Hub description:"
echo "   - Go to: https://hub.docker.com/r/${DOCKER_USER}/wireguard/settings/general"
echo "   - Add description (see SETUP_GUIDE.md for template)"
echo "   - Link to GitHub repo: https://github.com/${GITHUB_USER}/${REPO_NAME}"
echo ""
echo "2. Test your image:"
echo "   docker pull ${DOCKER_USER}/wireguard:latest"
echo "   docker run --rm ${DOCKER_USER}/wireguard:latest /usr/bin/coredns -version"
echo ""
echo "3. Deploy to your infrastructure:"
echo "   - Update docker-compose.yml with: ${DOCKER_USER}/wireguard:latest"
echo "   - Run: docker-compose up -d"
echo ""
echo "🎉 You're all set!"
