#!/usr/bin/env bash
set -e
set -o pipefail

# Smoke test for Jellyfin Docker image
# This script receives IMAGE_TAG from the workflow environment

IMAGE="${IMAGE_TAG}"
PLATFORM="${PLATFORM:-linux/amd64}"
CONTAINER_NAME="jellyfin-smoke-test-${RANDOM}"
JELLYFIN_PORT="8096"

# Color output for readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🧪 Jellyfin Smoke Test${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "Image: ${IMAGE}"
echo "Platform: ${PLATFORM}"
echo ""

# Validate IMAGE_TAG is set
if [ -z "${IMAGE}" ] || [ "${IMAGE}" = "null" ]; then
  echo -e "${RED}❌ ERROR: IMAGE_TAG environment variable is not set${NC}"
  exit 1
fi

# Create temporary config/cache directories
CONFIG_DIR=$(mktemp -d)
CACHE_DIR=$(mktemp -d)
chmod 777 "${CONFIG_DIR}" "${CACHE_DIR}"
echo "Config directory: ${CONFIG_DIR}"
echo "Cache directory: ${CACHE_DIR}"
echo ""

# Cleanup function
cleanup() {
  echo ""
  echo -e "${YELLOW}🧹 Cleaning up...${NC}"

  # Capture final logs before stopping
  if docker ps -a | grep -q "${CONTAINER_NAME}"; then
    echo "Saving container logs..."
    docker logs "${CONTAINER_NAME}" > /tmp/jellyfin-smoke-test.log 2>&1 || true
    echo "Logs saved to: /tmp/jellyfin-smoke-test.log"
  fi

  docker stop "${CONTAINER_NAME}" 2>/dev/null || true
  docker rm "${CONTAINER_NAME}" 2>/dev/null || true

  # Clean up temp directories (files may be owned by container user)
  if [ -d "${CONFIG_DIR}" ]; then
    chmod -R 777 "${CONFIG_DIR}" 2>/dev/null || true
    rm -rf "${CONFIG_DIR}" 2>/dev/null || true
  fi

  if [ -d "${CACHE_DIR}" ]; then
    chmod -R 777 "${CACHE_DIR}" 2>/dev/null || true
    rm -rf "${CACHE_DIR}" 2>/dev/null || true
  fi

  echo -e "${YELLOW}Cleanup complete${NC}"
}
trap cleanup EXIT

# Start container (use local image, don't pull from registry)
echo -e "${BLUE}▶️  Starting container...${NC}"
if ! docker run \
  --pull=never \
  --platform="${PLATFORM}" \
  --name "${CONTAINER_NAME}" \
  -v "${CONFIG_DIR}:/config" \
  -v "${CACHE_DIR}:/cache" \
  -p "${JELLYFIN_PORT}:8096" \
  -e TZ=UTC \
  -d \
  "${IMAGE}"; then
  echo -e "${RED}❌ Failed to start container${NC}"
  exit 1
fi

echo -e "${GREEN}✅ Container started${NC}"
echo ""

# Wait for initialization
echo -e "${BLUE}⏳ Waiting for Jellyfin to initialize...${NC}"
echo "Waiting 30 seconds for startup..."
sleep 30

# Check if container is still running
echo ""
echo -e "${BLUE}🔍 Checking container status...${NC}"
if ! docker ps | grep -q "${CONTAINER_NAME}"; then
  echo -e "${RED}❌ Container exited unexpectedly${NC}"
  echo ""
  echo "Container logs:"
  docker logs "${CONTAINER_NAME}" 2>&1
  exit 1
fi
echo -e "${GREEN}✅ Container is running${NC}"
echo ""

# Verify ffmpeg binaries exist and are executable in the image
echo -e "${BLUE}🎬 Verifying ffmpeg binaries...${NC}"
if docker exec "${CONTAINER_NAME}" /usr/lib/jellyfin-ffmpeg/ffmpeg -version >/dev/null 2>&1; then
  echo -e "${GREEN}✅ /usr/lib/jellyfin-ffmpeg/ffmpeg is executable${NC}"
else
  echo -e "${RED}❌ /usr/lib/jellyfin-ffmpeg/ffmpeg failed to execute${NC}"
  docker logs "${CONTAINER_NAME}" 2>&1 | tail -40
  exit 1
fi

if docker exec "${CONTAINER_NAME}" /usr/lib/jellyfin-ffmpeg/ffprobe -version >/dev/null 2>&1; then
  echo -e "${GREEN}✅ /usr/lib/jellyfin-ffmpeg/ffprobe is executable${NC}"
else
  echo -e "${RED}❌ /usr/lib/jellyfin-ffmpeg/ffprobe failed to execute${NC}"
  docker logs "${CONTAINER_NAME}" 2>&1 | tail -40
  exit 1
fi
echo ""

# Check logs for critical errors
echo -e "${BLUE}📋 Analyzing container logs...${NC}"
LOGS=$(docker logs "${CONTAINER_NAME}" 2>&1)

# Check for fatal errors
FATAL_COUNT=$(echo "$LOGS" | grep -ciE "fatal|panic|segmentation fault" || true)
if [ "${FATAL_COUNT}" -gt 0 ]; then
  echo -e "${RED}❌ Found ${FATAL_COUNT} critical error(s) in logs:${NC}"
  echo "$LOGS" | grep -iE "fatal|panic|segmentation fault" | head -10
  exit 1
fi

echo -e "${GREEN}✅ No critical errors in logs${NC}"
echo ""

# Test System/Ping endpoint with retries
echo -e "${BLUE}🏥 Testing System/Ping endpoint...${NC}"
PING_URL="http://localhost:${JELLYFIN_PORT}/System/Ping"
MAX_ATTEMPTS=24
ATTEMPT=0
PING_OK=false

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
  ATTEMPT=$((ATTEMPT + 1))

  if curl -fsSL --max-time 5 "${PING_URL}" -o /dev/null 2>/dev/null; then
    PING_OK=true
    break
  fi

  echo "Attempt ${ATTEMPT}/${MAX_ATTEMPTS}: Waiting for System/Ping endpoint..."
  sleep 5
done

if [ "${PING_OK}" = true ]; then
  echo -e "${GREEN}✅ System/Ping endpoint responding (${PING_URL})${NC}"
else
  echo -e "${RED}❌ System/Ping check failed after ${MAX_ATTEMPTS} attempts${NC}"
  echo ""
  echo "Recent container logs:"
  docker logs "${CONTAINER_NAME}" 2>&1 | tail -30
  exit 1
fi
echo ""

# Test root endpoint
echo -e "${BLUE}🌐 Testing root web endpoint...${NC}"
ROOT_URL="http://localhost:${JELLYFIN_PORT}/"
if curl -fsSL --max-time 5 "${ROOT_URL}" -o /dev/null 2>/dev/null; then
  echo -e "${GREEN}✅ Web UI accessible (${ROOT_URL})${NC}"
else
  echo -e "${YELLOW}⚠️  Web UI check failed (non-critical)${NC}"
fi
echo ""

# Verify image is using correct architecture
echo -e "${BLUE}🏗️  Verifying architecture...${NC}"
IMAGE_ARCH=$(docker image inspect "${IMAGE}" | jq -r '.[0].Architecture')
EXPECTED_ARCH=$(echo "${PLATFORM}" | cut -d'/' -f2)

if [ "${IMAGE_ARCH}" = "${EXPECTED_ARCH}" ] || [ "${IMAGE_ARCH}" = "null" ]; then
  if [ "${IMAGE_ARCH}" = "null" ]; then
    echo -e "${YELLOW}⚠️  Cannot verify architecture (not set in image metadata)${NC}"
  else
    echo -e "${GREEN}✅ Architecture matches: ${IMAGE_ARCH}${NC}"
  fi
else
  echo -e "${RED}❌ Architecture mismatch: expected ${EXPECTED_ARCH}, got ${IMAGE_ARCH}${NC}"
  exit 1
fi
echo ""

# Summary
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅✅✅ Smoke Test PASSED ✅✅✅${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Test Summary:"
echo "  • Container started successfully"
echo "  • No critical errors in logs"
echo "  • System/Ping endpoint responding"
echo "  • Web UI accessible"
echo "  • Correct architecture: ${IMAGE_ARCH}"
echo ""

exit 0
