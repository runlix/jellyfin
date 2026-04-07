# Jellyfin

`jellyfin` publishes the Runlix container image for [Jellyfin](https://github.com/jellyfin/jellyfin).

The current published image name is:

```text
ghcr.io/runlix/jellyfin
```

Use a versioned stable manifest tag from [release.json](release.json):

```dockerfile
FROM ghcr.io/runlix/jellyfin:<version>-stable
```

The authoritative published tags, digests, and source revision live in [release.json](release.json).

## What's Included

- Jellyfin upstream binaries
- `sqlite3`
- `jellyfin-ffmpeg7`
- shared runtime libraries from `distroless-runtime-v2-canary`

The image keeps the distroless runtime model while layering in the Jellyfin-specific binaries and media tooling it needs.

## Branch Layout

`main` owns metadata and automation config:

- `README.md`
- `links.json`
- `release.json`
- `renovate.json`
- `.github/workflows/validate-release-metadata.yml`

`release` owns build and publish inputs:

- `.ci/build.json`
- `.ci/smoke-test.sh`
- `linux-*.Dockerfile`
- `.github/workflows/validate-build.yml`
- `.github/workflows/publish-release.yml`

## Release Flow

Changes merge to `release`, where `Publish Release` builds the versioned `stable` and `debug` multi-arch manifests, attests them, optionally sends Telegram, and opens the sync PR back to `main`.

`main` validates metadata and config-only changes with `Validate Release Metadata`.

## Environment Variables

- `JELLYFIN_DATA_DIR`: data directory, default `/config/data`
- `JELLYFIN_CONFIG_DIR`: config directory, default `/config/config`
- `JELLYFIN_LOG_DIR`: log directory, default `/config/log`
- `JELLYFIN_CACHE_DIR`: cache directory, default `/cache`

## Ports

- `8096/tcp`: Jellyfin HTTP endpoint

## License

GPL-2.0
