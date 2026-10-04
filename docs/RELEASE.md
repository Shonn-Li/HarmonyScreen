# Release readiness

Completed: Mac build, Swift tests, HDC USB data round-trip, portable frame validation, Mac Developer ID package signing.

Required before an end-user HOS 7 release:

- Compile the native client using the official HarmonyOS SDK; fix all compiler/API diagnostics.
- Obtain a Huawei application certificate and provisioning profile for com.shonnli.harmonyscreen.
- Sign/install a HAP on an authorized device; do not ship private keys, profiles or device identifiers.
- Verify first displayed frame, continuous video, resolution and HiDPI, unplug/replug, app backgrounding, host restart, malformed frame handling and decoder errors.
- Verify window focus/reopen and permissions on a clean Mac installation.
- Notarize the Developer ID-signed Mac DMG with the owner's Apple developer credentials and staple the ticket.
- Publish native HAP and Mac artifacts only with accurate device/test coverage and SHA-256 checksums.

Current preview is not an AppGallery release. No native HAP has been produced yet.
