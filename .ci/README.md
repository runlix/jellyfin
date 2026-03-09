# Jellyfin CI Configuration

This directory contains configuration and scripts for the CI/CD pipeline.

## Files

### docker-matrix.json

Defines the build matrix for multi-architecture Docker images. See the [schema documentation](https://github.com/runlix/build-workflow/blob/main/schema/docker-matrix-schema.json) for details.

**Variants:**
- `latest-amd64` - Stable build for AMD64
- `latest-arm64` - Stable build for ARM64
- `debug-amd64` - Debug build for AMD64 (includes debugging tools)
- `debug-arm64` - Debug build for ARM64 (includes debugging tools)

### smoke-test.sh

Automated smoke test script that validates built Docker images before they are released.

**What it tests:**
- Container starts successfully
- No critical errors in logs
- System ping endpoint responds (`/System/Ping`)
- Web UI is accessible
- Correct architecture is used

**Environment Variables:**
- `IMAGE_TAG` (required) - The Docker image tag to test (set by workflow)
- `PLATFORM` (optional) - Platform to test, defaults to `linux/amd64`

## Workflow Integration

The build workflow automatically:

1. On Pull Requests: Builds all variants and runs smoke tests
2. On Merges to Release Branch: Rebuilds all variants and runs smoke tests
3. After Tests Pass: Creates multi-arch manifests and pushes to registry

See [build-workflow documentation](https://github.com/runlix/build-workflow/tree/main/docs) for more details.
