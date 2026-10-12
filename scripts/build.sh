#!/usr/bin/env bash
# ==============================================================================
# build.sh: Compiles Joplin Web App from submodule and builds Docker container
# ==============================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
JOPLIN_DIR="${REPO_ROOT}/joplin"
PAGES_DIR="${REPO_ROOT}/pages"
IMAGE_NAME="${IMAGE_NAME:-ghcr.io/adamoutler/web-app:latest}"

BUILD_DOCKER=false
if [[ "${1:-}" == "--docker" ]] || [[ "${BUILD_CONTAINER:-false}" == "true" ]]; then
  BUILD_DOCKER=true
fi

echo "=========================================="
echo " Joplin Web App Build & Stage Process"
echo "=========================================="

echo "==> Step 1: Checking submodule status..."
if [ ! -d "${JOPLIN_DIR}/packages/app-mobile/web" ]; then
  echo "Submodule not initialized. Initializing..."
  git -C "${REPO_ROOT}" submodule update --init --recursive joplin
fi

echo "==> Step 2: Preparing Node.js & Yarn..."
corepack enable || true

echo "==> Step 3: Installing dependencies in Joplin repository..."
(
  cd "${JOPLIN_DIR}"
  yarn install
)

echo "==> Step 4: Compiling Joplin web client..."
(
  cd "${JOPLIN_DIR}/packages/app-mobile"
  yarn web
)

echo "==> Step 5: Staging build output into pages/..."
mkdir -p "${PAGES_DIR}"
rm -rf "${PAGES_DIR:?}"/*
cp -r "${JOPLIN_DIR}/packages/app-mobile/web/dist/"* "${PAGES_DIR}/"
echo "Staged $(ls -1 "${PAGES_DIR}" | wc -l) files/directories into ${PAGES_DIR}."

if [ "$BUILD_DOCKER" = true ]; then
  echo "==> Step 6: Building Docker container image (${IMAGE_NAME})..."
  docker build -t "${IMAGE_NAME}" "${REPO_ROOT}"
  echo "Docker image ${IMAGE_NAME} built successfully."
else
  echo ""
  echo "Web app compiled successfully into ${PAGES_DIR}!"
  echo "To build the Docker image, run:"
  echo "  docker build -t ${IMAGE_NAME} ."
  echo "Or pass --docker to this script."
fi
