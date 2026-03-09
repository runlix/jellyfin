# Builder image and tag from docker-matrix.json
ARG BUILDER_IMAGE=docker.io/library/debian
ARG BUILDER_TAG=bookworm-slim
# Base image and tag from docker-matrix.json
ARG BASE_IMAGE=ghcr.io/runlix/distroless-runtime
ARG BASE_TAG=stable
# Selected digests (build script will set based on target configuration)
# Default to empty string - build script should always provide valid digests
# If empty, FROM will fail (which is desired to enforce digest pinning)
ARG BUILDER_DIGEST=""
ARG BASE_DIGEST=""
# Jellyfin package URL from docker-matrix.json
ARG PACKAGE_URL=""

# STAGE 1 — fetch Jellyfin binaries
FROM ${BUILDER_IMAGE}:${BUILDER_TAG}@${BUILDER_DIGEST} AS fetch

ARG PACKAGE_URL

WORKDIR /app

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    tar \
 && rm -rf /var/lib/apt/lists/* \
 && mkdir -p /app/jellyfin \
 && curl -L -f "${PACKAGE_URL}" -o jellyfin.tar.gz \
 && tar -xzf jellyfin.tar.gz -C /app/jellyfin --strip-components=1 \
 && chmod +x /app/jellyfin/jellyfin \
 && rm jellyfin.tar.gz

# STAGE 2 — install Jellyfin runtime dependencies
FROM ${BUILDER_IMAGE}:${BUILDER_TAG}@${BUILDER_DIGEST} AS jellyfin-deps

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    sqlite3 \
    fontconfig \
    ffmpeg \
 && rm -rf /var/lib/apt/lists/*

# STAGE 3 — distroless final image
FROM ${BASE_IMAGE}:${BASE_TAG}@${BASE_DIGEST}

ARG LIB_DIR=x86_64-linux-gnu

ENV JELLYFIN_DATA_DIR=/config/data
ENV JELLYFIN_CONFIG_DIR=/config/config
ENV JELLYFIN_LOG_DIR=/config/log
ENV JELLYFIN_CACHE_DIR=/cache

COPY --from=fetch /app /app
COPY --from=jellyfin-deps /usr/bin/sqlite3 /usr/bin/sqlite3
COPY --from=jellyfin-deps /usr/bin/ffmpeg /usr/bin/ffmpeg
COPY --from=jellyfin-deps /usr/bin/ffprobe /usr/bin/ffprobe
COPY --from=jellyfin-deps /usr/lib/${LIB_DIR}/libsqlite3.so.* /usr/lib/${LIB_DIR}/
COPY --from=jellyfin-deps /usr/lib/${LIB_DIR}/libavcodec.so.* \
                          /usr/lib/${LIB_DIR}/libavformat.so.* \
                          /usr/lib/${LIB_DIR}/libavutil.so.* \
                          /usr/lib/${LIB_DIR}/libswresample.so.* \
                          /usr/lib/${LIB_DIR}/libswscale.so.* \
                          /usr/lib/${LIB_DIR}/
COPY --from=jellyfin-deps /usr/lib/${LIB_DIR}/libfontconfig.so.* \
                          /usr/lib/${LIB_DIR}/libfreetype.so.* \
                          /usr/lib/${LIB_DIR}/libexpat.so.* \
                          /usr/lib/${LIB_DIR}/
COPY --from=jellyfin-deps /etc/fonts /etc/fonts
COPY --from=jellyfin-deps /usr/share/fontconfig /usr/share/fontconfig

WORKDIR /app/jellyfin
EXPOSE 8096
USER 65532:65532
ENTRYPOINT ["/app/jellyfin/jellyfin", "--datadir", "/config/data", "--cachedir", "/cache", "--configdir", "/config/config", "--logdir", "/config/log"]
