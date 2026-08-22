#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -ouex pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo ":: defenestraOS build starting..."
echo "   IMAGE_NAME=${IMAGE_NAME:-unset}"
echo "   IMAGE_VARIANT=${IMAGE_VARIANT:-unset}"

"${SCRIPT_DIR}/strip-bazzite.sh"
"${SCRIPT_DIR}/rename-scripts.sh"
"${SCRIPT_DIR}/install-defenestra.sh"
"${SCRIPT_DIR}/gen-protected-path.sh"
"${SCRIPT_DIR}/image-info"
"${SCRIPT_DIR}/finalize.sh"

echo ":: defenestraOS build complete."
