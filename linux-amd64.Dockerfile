ARG BUILDER_REF="docker.io/library/debian:bookworm-slim@sha256:13cb01d584d2c23f475c088c168a48f9a08f033a10460572fbfd10912ec5ba7c"
ARG BASE_REF="ghcr.io/runlix/distroless-runtime-v2-canary:stable@sha256:6f96f11dbb9d8f6e76672e73bbf743dbec36d2e4f6d29250151a48379a8c66dd"
ARG PACKAGE_URL="https://repo.jellyfin.org/files/server/linux/stable/v10.11.6/amd64/jellyfin_10.11.6-amd64.tar.gz"

FROM ${BUILDER_REF} AS fetch

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

FROM ${BUILDER_REF} AS jellyfin-deps

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      gnupg \
 && mkdir -p /etc/apt/keyrings \
 && curl -fsSL "https://repo.jellyfin.org/jellyfin_team.gpg.key" | gpg --dearmor -o /etc/apt/keyrings/jellyfin.gpg \
 && chmod a+r /etc/apt/keyrings/jellyfin.gpg \
 && echo "deb [signed-by=/etc/apt/keyrings/jellyfin.gpg] https://repo.jellyfin.org/debian bookworm main" > /etc/apt/sources.list.d/jellyfin.list \
 && apt-get update && apt-get install -y --no-install-recommends \
      sqlite3 \
      fontconfig \
      jellyfin-ffmpeg7 \
      libbrotli1 \
      libpng16-16 \
 && rm -rf /var/lib/apt/lists/*

FROM ${BASE_REF}

ARG LIB_DIR="x86_64-linux-gnu"

ENV JELLYFIN_DATA_DIR=/config/data
ENV JELLYFIN_CONFIG_DIR=/config/config
ENV JELLYFIN_LOG_DIR=/config/log
ENV JELLYFIN_CACHE_DIR=/cache
ENV JELLYFIN_FFMPEG=/usr/lib/jellyfin-ffmpeg/ffmpeg
ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

COPY --from=fetch /app /app
COPY --from=jellyfin-deps /usr/bin/sqlite3 /usr/bin/sqlite3
COPY --from=jellyfin-deps /usr/lib/jellyfin-ffmpeg /usr/lib/jellyfin-ffmpeg
COPY --from=jellyfin-deps /lib/${LIB_DIR}/ /lib/${LIB_DIR}/
COPY --from=jellyfin-deps /usr/lib/${LIB_DIR}/ /usr/lib/${LIB_DIR}/
COPY --from=jellyfin-deps /etc/fonts /etc/fonts
COPY --from=jellyfin-deps /usr/share/fontconfig /usr/share/fontconfig
COPY --from=jellyfin-deps /lib64/ld-linux-x86-64.so.2 /lib64/ld-linux-x86-64.so.2

WORKDIR /app/jellyfin
EXPOSE 8096
USER 65532:65532
ENTRYPOINT ["/app/jellyfin/jellyfin", "--datadir", "/config/data", "--cachedir", "/cache", "--configdir", "/config/config", "--logdir", "/config/log"]
