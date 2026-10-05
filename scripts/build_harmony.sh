#!/bin/bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
if [[ -n "${HARMONY_SDK_TOOLS:-}" ]]; then
  export PATH="$HARMONY_SDK_TOOLS/bin:$PATH"
else
  DEVECO_APP="${HARMONY_DEVECO_APP:-/Applications/DevEco-Studio.app}"
  if [[ ! -x "$DEVECO_APP/Contents/tools/hvigor/bin/hvigorw" ]]; then
    echo "Install DevEco Studio 6.0.1 or set HARMONY_SDK_TOOLS to matching official Huawei command-line tools." >&2
    exit 1
  fi
  export NODE_HOME="$DEVECO_APP/Contents/tools/node"
  export JAVA_HOME="$DEVECO_APP/Contents/jbr/Contents/Home"
  export DEVECO_SDK_HOME="$DEVECO_APP/Contents/sdk"
  export PATH="$NODE_HOME/bin:$DEVECO_APP/Contents/tools/ohpm/bin:$DEVECO_APP/Contents/tools/hvigor/bin:$PATH"
fi
cd "${HARMONY_CLIENT_DIR:-$ROOT/HarmonyClient}"
ohpm install --all
hvigorw --mode module -p product=default -p module=entry@default -p buildMode=release assembleHap --no-daemon
