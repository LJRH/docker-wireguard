# Agent Guidelines for docker-wireguard

## Build Commands
- **Build image**: `docker build --no-cache --pull -t linuxserver/wireguard:latest .`
- **Build ARM64**: `docker build --no-cache --pull -f Dockerfile.aarch64 -t linuxserver/wireguard:latest .`
- **Test locally**: Build image, then run with appropriate environment variables (see README.md)
- **No unit tests**: This is a Docker container project with no separate test suite

## Code Style
- **Shell scripts**: Use `#!/usr/bin/with-contenv bash` shebang for s6 scripts
- **ShellCheck**: All shell scripts must pass ShellCheck validation (run in CI)
- **Variables**: Use `${VARIABLE}` syntax for all variable references
- **Naming**: Use SCREAMING_SNAKE_CASE for environment variables, lowercase for local vars
- **Conditionals**: Use `[[ ]]` for bash tests, not `[ ]`
- **Alphanumeric validation**: Use regex like `[[:alnum:]]` for peer name validation
- **File permissions**: S6 service files (run, finish, check) must be executable (chmod +x)

## File Conventions
- **DO NOT edit**: README.md, Jenkinsfile, package_versions.txt (auto-generated)
- **Edit instead**: readme-vars.yml for README changes, jenkins-vars.yml for build changes
- **Dockerfiles**: Add packages in alphabetical order across ALL Dockerfiles (main + aarch64)
- **Changelog**: Add entry in readme-vars.yml changelogs section for any script/Dockerfile changes
- **Templates**: Server and peer conf templates are in root/defaults/

## Important Project Details
- This is a LinuxServer.io maintained container for WireGuard VPN
- Supports both server mode (with PEERS env var) and client mode (without PEERS)
- Uses s6-overlay for process supervision
- Multi-arch build (amd64, arm64v8) managed through Jenkins CI
