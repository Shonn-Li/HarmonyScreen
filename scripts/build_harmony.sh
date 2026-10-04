#!/bin/bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
: "${HARMONY_SDK_TOOLS:?Set HARMONY_SDK_TOOLS to the official Huawei command-line-tools directory}"
export PATH="$HARMONY_SDK_TOOLS/bin:$PATH"
cd "$ROOT/HarmonyClient"
ohpm install --all
hvigorw --mode module -p product=default -p module=entry@default -p buildMode=release assembleHap --no-daemon
