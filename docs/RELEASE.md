# Release readiness

Completed: Mac build, Swift tests, HDC USB data round-trip, portable frame validation, Mac Developer ID package signing, native arm64 HAP compilation in release mode, Huawei debug signing and installation on Mate XT 2, native full-screen 3184×2232 playback and automatic recovery after a Mac stream restart. Independent Mac HEVC decoding passed at 1920×1200 and 3184×2232.

Required before an end-user HOS 7 release:

- Native client compiled using DevEco Studio 6.0.1.251 / SDK 6.0.1.112 (API 21), matching the editor; an earlier API 24 command-line build also passed. Preview versioning is maintained separately from supported SDK/API versions. Signing warning is expected until the certificate/profile are configured.
- Debug certificate/profile generation and signed installation have succeeded for com.shonnli.harmonyscreen. Obtain appropriate distribution signing before advertising a generally installable HAP.
- Keep device-specific debug HAPs, private keys, provisioning profiles and device identifiers out of public release assets.
- First displayed frame, full-screen resolution/HiDPI and a Mac stream restart are verified. Still test sustained performance, physical unplug/replug, app backgrounding, malformed frame handling and decoder errors on the device.
- Verify window focus/reopen and permissions on a clean Mac installation.
- Notarize the Developer ID-signed Mac DMG with the owner's Apple developer credentials and staple the ticket.
- Publish native HAP and Mac artifacts only with accurate device/test coverage and SHA-256 checksums.

Current preview is not an AppGallery release. DevEco automatic signing produced a debug HAP that installed and displayed the Mac desktop full-screen on the authorized Mate XT 2. The debug HAP is retained privately because its provisioning profile is device-specific.

0.1.1 adds phone-side stream FPS, YouWo.ai branding, packaged MIT attribution and idle-boundary timeout handling. The owner’s signed phone installation and a full Mac host update/restart are verified. It remains a $0 developer preview with the distribution gates above.
