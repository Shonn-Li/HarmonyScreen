#!/bin/bash
# Signing inputs must be kept outside the public repository.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
: "${HARMONY_SDK_TOOLS:?Set the official Huawei command-line-tools directory}"
: "${HARMONY_KEYSTORE:?Path to your private .p12 keystore}"
: "${HARMONY_CERTIFICATE:?Path to your Huawei-issued .cer certificate}"
: "${HARMONY_PROFILE:?Path to your Huawei-issued .p7b profile}"
: "${HARMONY_PASSWORD_FILE:?Path to a private file containing the keystore password}"
ALIAS=${HARMONY_KEY_ALIAS:-harmonyscreen}
INPUT=${1:-"$ROOT/HarmonyClient/entry/build/default/outputs/default/entry-default-unsigned.hap"}
OUTPUT=${2:-"$ROOT/dist/HarmonyScreen-$(cat "$ROOT/VERSION")-harmony-arm64-signed.hap"}
TOOL="$HARMONY_SDK_TOOLS/sdk/default/openharmony/toolchains/lib/hap-sign-tool.jar"
for FILE in "$TOOL" "$INPUT" "$HARMONY_KEYSTORE" "$HARMONY_CERTIFICATE" "$HARMONY_PROFILE" "$HARMONY_PASSWORD_FILE"; do
  [[ -f "$FILE" ]] || { echo "Missing signing input: $FILE" >&2; exit 1; }
done
[[ ! -e "$OUTPUT" ]] || { echo 'Choose a fresh output path; existing signed artifacts are preserved.' >&2; exit 1; }
mkdir -p "$(dirname "$OUTPUT")"
VERIFY_DIR=$(mktemp -d)
trap 'rm -rf "$VERIFY_DIR"' EXIT
PASSWORD=$(cat "$HARMONY_PASSWORD_FILE")
java -jar "$TOOL" sign-app -mode localSign -keyAlias "$ALIAS" \
  -signAlg SHA256withECDSA -compatibleVersion 13 -signCode 1 -appCertFile "$HARMONY_CERTIFICATE" \
  -profileFile "$HARMONY_PROFILE" -inFile "$INPUT" -outFile "$OUTPUT" \
  -keystoreFile "$HARMONY_KEYSTORE" -keyPwd "$PASSWORD" -keystorePwd "$PASSWORD"
unset PASSWORD
[[ -s "$OUTPUT" ]] || { echo 'Signing did not produce a package.' >&2; exit 1; }
java -jar "$TOOL" verify-app -inFile "$OUTPUT" \
  -outCertChain "$VERIFY_DIR/certificate.cer" -outProfile "$VERIFY_DIR/profile.p7b"
shasum -a 256 "$OUTPUT"
