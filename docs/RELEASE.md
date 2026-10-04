# Release readiness

Completed: Mac build, Swift tests, HDC USB data round-trip, portable frame validation, Mac Developer ID package signing, native arm64 HAP compilation in release mode, 60-frame HEVC decode at 1920×1200 locally and through the HDC USB forward/reverse path.

Required before an end-user HOS 7 release:

- Native client compiled using official Command Line Tools 6.1.1.280 / SDK 6.1.1.125. Remaining SDK warning: its package-version validator rejects the project's intentional 0.1.0 preview version. Signing warning is expected until the certificate/profile are configured.
- Obtain a Huawei application certificate and provisioning profile for com.shonnli.harmonyscreen.
- Sign/install a HAP on an authorized device; do not ship private keys, profiles or device identifiers.
- Verify first displayed frame, continuous video, resolution and HiDPI, unplug/replug, app backgrounding, host restart, malformed frame handling and decoder errors.
- Verify window focus/reopen and permissions on a clean Mac installation.
- Notarize the Developer ID-signed Mac DMG with the owner's Apple developer credentials and staple the ticket.
- Publish native HAP and Mac artifacts only with accurate device/test coverage and SHA-256 checksums.

Current preview is not an AppGallery release. A native unsigned HAP has been produced; the connected device rejects it with error 9568320 (no signature file). Huawei developer identity verification and an issued app certificate/profile are required to proceed. No on-phone frames have been verified.
