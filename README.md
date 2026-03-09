# Jellyfin

Kubernetes-native distroless Docker image for [Jellyfin](https://github.com/jellyfin/jellyfin) - a media server.

## Purpose

Provides a minimal, secure Docker image for running Jellyfin in Kubernetes environments. Built on the `distroless-runtime` base image with only the dependencies required for Jellyfin to run.

## Features

- Distroless base (no shell, minimal attack surface)
- Kubernetes-native permissions (no s6-overlay)
- Read-only root filesystem support
- Non-root execution
- Official Jellyfin runtime paths (`/config`, `/cache`)

## Usage

### Docker

```bash
docker run -d \
  --name jellyfin \
  -p 8096:8096 \
  -v /path/to/config:/config \
  -v /path/to/cache:/cache \
  ghcr.io/runlix/jellyfin:release-latest
```

### Kubernetes

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jellyfin
spec:
  template:
    spec:
      containers:
      - name: jellyfin
        image: ghcr.io/runlix/jellyfin:release-latest
        ports:
        - containerPort: 8096
        volumeMounts:
        - name: config
          mountPath: /config
        - name: cache
          mountPath: /cache
        securityContext:
          runAsUser: 65532
          runAsGroup: 65532
          readOnlyRootFilesystem: true
          capabilities:
            drop: ["ALL"]
      volumes:
      - name: config
        persistentVolumeClaim:
          claimName: jellyfin-config
      - name: cache
        persistentVolumeClaim:
          claimName: jellyfin-cache
```

## Tags

See [tags.json](tags.json) for available tags.

## Environment Variables

- `JELLYFIN_DATA_DIR`: Data directory (default: `/config/data`)
- `JELLYFIN_CONFIG_DIR`: Config directory (default: `/config/config`)
- `JELLYFIN_LOG_DIR`: Log directory (default: `/config/log`)
- `JELLYFIN_CACHE_DIR`: Cache directory (default: `/cache`)

## License

GPL-2.0 (upstream Jellyfin license)
