# HarmonyScreen

A native HarmonyOS second-screen project for macOS, maintained by Shonn Li. Based on [SideScreen](https://github.com/tranvuongquocdat/SideScreen), with its MIT license and attribution preserved.

**Status: developer preview. The Mac host builds; the HDC USB tunnel is hardware-tested. The native HarmonyOS client is source-only pending SDK compilation, device signing, and playback verification. Do not download this expecting a finished HOS 7 display app yet.**

## What exists

- Mac virtual display and hardware HEVC encoding inherited from SideScreen.
- HDC device discovery and reverse forwarding, replacing ADB for USB mode.
- Separate app identity, preferences, and port (54322), so SideScreen can remain installed.
- Native ArkTS/C++ client source using HarmonyOS AVCodec and an XComponent surface. No Android compatibility layer is required by this design.
- Build/sign scripts and a real USB round-trip diagnostic.

## Verified / not yet verified

| Component | Result |
|---|---|
| Mac arm64 build | Builds; 51 Swift tests passed |
| HDC on OpenHarmony 7.0.0.107 | 1 MiB exact USB round-trip passed |
| Portable frame validation | Address/undefined-behavior sanitizer test passed |
| Native HAP build and installation | Pending Huawei SDK and signing |
| Video decoded and displayed on Huawei | Not yet verified |
| Touch, native Wi-Fi pairing, audio | Not enabled in the native preview |
| Apple notarization | Not completed |

## Mac

```sh
scripts/package_harmony_mac.sh
```

For Developer ID signing, set `SIGNING_IDENTITY` to your own available certificate name before running the script. The published preview DMG, when present, is signed by Shonn Li. Signing alone is not notarization.

Install official Huawei Command Line Tools. Place `hdc` plus its runtime dependencies in a supported location (see `HDCBridge.swift`) or set `HARMONYSCREEN_HDC`. Connect one authorized Huawei device. Open HarmonyScreen, grant screen capture, select USB, and start the host. A tunnel-ready status is not proof of a client/video connection.

## HarmonyOS client

`HarmonyClient` is an ArkTS Stage application with a native C++ surface decoder, targeting API 13+ for the initial source configuration. Open it in DevEco Studio and select an installed compatible SDK. Configure your own app signing through Huawei's supported process; private signing configuration must stay outside Git.

```sh
HARMONY_SDK_TOOLS=/path/to/command-line-tools scripts/build_harmony.sh
```

The native client connects only to localhost:54322 through the HDC USB tunnel. Start with 1920×1200 at 30 FPS and zero rotation/flip. Higher resolutions and HiDPI need real-device validation. Never advertise an unsigned package as generally installable on retail Huawei phones.

## Tests

```sh
swift test --package-path MacHost
clang++ -std=c++17 -fsanitize=address,undefined tests/wire_test.cpp -o /tmp/harmonyscreen-wire-test
/tmp/harmonyscreen-wire-test
python3 scripts/test_hdc_transport.py  # one authorized USB phone required
```

See [transport and protocol design](docs/HDC-TRANSPORT.md) and [release checklist](docs/RELEASE.md). The retained AndroidClient and upstream scripts are reference material, not a HarmonyOS build or release route.

## Attribution

The Mac capture/encoder/server originated in SideScreen by Quoc Dat Tran and contributors, under MIT. New HDC integration and native HarmonyOS receiver work is copyright 2026 Shonn Li, also MIT. See LICENSE and NOTICE. This project is not affiliated with Huawei or Apple.
