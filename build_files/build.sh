#!/bin/bash
set -ouex pipefail

# =============================================================================
# DefenestraOS Build Script
#
# Single entry point matching sibling image patterns (bazzite, bluefin, aurora).
# Called from Containerfile with build context mounted at /ctx.
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo ":: DefenestraOS build starting..."
echo "   IMAGE_NAME=${IMAGE_NAME:-unset}"
echo "   IMAGE_VARIANT=${IMAGE_VARIANT:-unset}"

# Step 1: Strip bazzite branding, onboarding, app store
"${SCRIPT_DIR}/strip-bazzite.sh"

# Step 2: Rename bazzite-* scripts/services → defenestra-*
"${SCRIPT_DIR}/rename-scripts.sh"

# Step 3: Install defenestra packages, overlay system_files, enable services
"${SCRIPT_DIR}/install-defenestra.sh"

# Step 4: Stamp OS identity (os-release, image-info.json)
"${SCRIPT_DIR}/image-info"

# Step 5: Compile schemas, update caches, clean up
"${SCRIPT_DIR}/finalize.sh"

echo ":: DefenestraOS build complete."
