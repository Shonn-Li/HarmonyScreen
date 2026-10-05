# HarmonyScreen

A free native HarmonyOS second-screen app for macOS, by [YouWo.ai](https://youwo.ai), maintained by Shonn Li. No subscription or account is required for USB streaming. Based on [SideScreen](https://github.com/tranvuongquocdat/SideScreen), with its MIT license and attribution preserved.

**Status: developer preview. Signed native playback on Mate XT 2 is verified over HDC USB, including full-screen 3184×2232 video and recovery after a Mac stream restart. Public assets remain a Mac preview; the device-specific debug HAP is private. General distribution, broad device testing, touch/audio and Mac notarization remain incomplete.**

## What exists

- Mac virtual display and hardware HEVC encoding inherited from SideScreen.
- HDC device discovery and reverse forwarding, replacing ADB for USB mode.
- Separate app identity, preferences, and port (54322), so SideScreen can remain installed.
- Native ArkTS/C++ client source using HarmonyOS AVCodec and an XComponent surface. No Android compatibility layer is required by this design.
- Build/sign scripts and a real USB round-trip diagnostic.

## Verified / not yet verified

| Component | Result |
|---|---|
| Mac arm64 build | Builds; 59 Swift tests passed |
| HDC on OpenHarmony 7.0.0.107 | 1 MiB exact USB round-trip passed |
| Portable frame validation | Address/undefined-behavior sanitizer test passed |
| Native HAP build | Release-mode arm64 HAP built with DevEco Studio 6.0.1.251 / SDK 6.0.1.112 (API 21); earlier API 24 build also passed |
| Native HAP installation | DevEco-generated Huawei debug profile signed the HAP; installation on Mate XT 2 succeeded |
| Actual host video | 60 HEVC frames independently decoded at 1920×1200, locally and through an HDC USB forward/reverse path |
| Video decoded and displayed on Huawei | Verified on Mate XT 2 at 3184×2232, full-screen; Mac stream stop/start recovered automatically |
| Touch, native Wi-Fi pairing, audio | Not enabled in the native preview |
| Apple notarization | Not completed |

## Mac

```sh
scripts/package_harmony_mac.sh
```

For Developer ID signing, set `SIGNING_IDENTITY` to your own available certificate name before running the script. The published preview DMG, when present, is signed by Shonn Li. Signing alone is not notarization.

Install official Huawei Command Line Tools. Place `hdc` plus its runtime dependencies in a supported location (see `HDCBridge.swift`) or set `HARMONYSCREEN_HDC`. Connect one authorized Huawei device. Open HarmonyScreen, grant screen capture, select USB, and start the host. A tunnel-ready status is not proof of a client/video connection.

## HarmonyOS client

`HarmonyClient` is an ArkTS Stage application with a native C++ surface decoder. It compiles against HarmonyOS 6.0.1 (API 21), with a minimum of HarmonyOS 5.0.1 (API 13). The target matches DevEco Studio 6.0.1 so opening the project does not fail SDK validation. Compilation is verified; this minimum is not a claim of tested device coverage. Configure your own app signing through Huawei's supported process; private signing configuration must stay outside Git.

```sh
scripts/build_harmony.sh
```

The script uses the official SDK, Node and Java bundled in `/Applications/DevEco-Studio.app`. Set `HARMONY_DEVECO_APP` for another installation path, or `HARMONY_SDK_TOOLS` to official command-line tools containing a matching API 21 SDK.

This creates `HarmonyClient/entry/build/default/outputs/default/entry-default-unsigned.hap` in release mode. A retail Huawei phone requires a Huawei-issued application certificate and provisioning profile before installation. A Mac Developer ID certificate cannot sign a HarmonyOS app. See [Huawei's signing and build instructions](https://developer.huawei.com/consumer/en/doc/harmonyos-guides/ide-command-line-building-app).

`scripts/sign_harmony.sh` accepts private signing paths through `HARMONY_KEYSTORE`, `HARMONY_CERTIFICATE`, `HARMONY_PROFILE`, and `HARMONY_PASSWORD_FILE`; the default key alias is `harmonyscreen`. Keep these inputs outside this repository. Its certificate-dependent execution is pending validation with an issued certificate; no self-signed or unsigned HAP is advertised as installable.

For DevEco automatic signing, save the generated JSON build profile outside the repository, then restore the public profile with its empty `signingConfigs`. Build privately without putting signing inputs back into the tracked source:

```sh
python3 scripts/build_harmony_signed.py \
  --profile /private/path/deveco-build-profile.private.json5 \
  --output /private/path/HarmonyScreen-device-debug.hap
```

This route has produced a signed HAP using DevEco's generated credentials. It stages a temporary project, preserves existing output files, and leaves the public build profile unchanged. The debug HAP contains a device provisioning profile: keep it private, not in GitHub release assets. It is not a general AppGallery distribution package.

The native client connects only to localhost:54322 through the HDC USB tunnel. It connects when opened, hides its overlay after video arrives, and retries interrupted streams while the page is visible. Tap the desktop to toggle controls; the back gesture also reveals hidden controls. Manual Disconnect stops automatic retries. This receiver remains display-only and does not send taps to the Mac.

Verified unfolded Mate XT 2 setup: custom **1592×1116**, **HiDPI on**, **30 FPS**, zero rotation/flip. This produces **3184×2232** encoded pixels and fills the matching phone panel with Retina-sized desktop text. The native surface fits other aspect ratios without stretching. Automatic sizing and both orientations are now verified on Mate XT 2 (see below); other device models still need validation. Never advertise a device-specific debug package as generally installable on retail Huawei phones.

## Tests

```sh
swift test --package-path MacHost
clang++ -std=c++17 -fsanitize=address,undefined tests/wire_test.cpp -o /tmp/harmonyscreen-wire-test
/tmp/harmonyscreen-wire-test
python3 scripts/test_hdc_transport.py  # one authorized USB phone required
python3 scripts/test_host_stream.py    # running local host and ffprobe required
```

See [transport and protocol design](docs/HDC-TRANSPORT.md) and [release checklist](docs/RELEASE.md). The retained AndroidClient and upstream scripts are reference material, not a HarmonyOS build or release route.

## Attribution

The Mac capture/encoder/server originated in SideScreen by Quoc Dat Tran and contributors, under MIT. New HDC integration and native HarmonyOS receiver work is copyright 2026 Shonn Li, also MIT. See LICENSE and NOTICE. This project is not affiliated with Huawei or Apple.

### Automatic size and portrait (latest source)

The Mac settings now offer **Fit desktop to Huawei automatically**, **Match Mac
text size**, **Follow phone / Portrait / Landscape**, and side/edge alignment.
Turn on auto-fit for a desktop that follows the receiver's usable panel. Matching
Mac text size estimates physical scale from panel DPI and the Mac's current
Displays setting; disable that option for native 2× Retina rendering. Follow
phone respects HarmonyOS's rotation lock. Resizing briefly reconnects the stream.

Verified on the connected Mate XT 2: full-panel 3184×2232 landscape and 2232×3184
portrait, switching both ways with the same Mac display ID, and recalculating
logical size after a Mac display-scale change. The iPad Sidecar display remained
connected during these final tests. See [transport details](docs/HDC-TRANSPORT.md)
for the size calculation and the macOS multi-virtual-display recovery limitation.

### Live FPS and everyday connection

Mac and Huawei 0.1.4 restore automatic rotation and connection recovery. Follow
phone uses the orientation sensor even with the system rotation lock enabled;
the Mac resizes the desktop after the new viewport arrives. A rotation can briefly
reconnect video. Failed Mac startup/reconfiguration now shows a status message
and retries automatically rather than waiting in a blocking error dialog.
New installations start streaming when the Mac app opens by default. An existing
explicitly disabled startup preference is preserved.

Tap the Huawei desktop to show the controls. **Stream FPS** measures successful
video-decoder submissions to the phone display surface over the last second;
it is not the physical panel refresh rate or a glass-to-glass latency measurement.
Choose **Keep FPS visible** for a small persistent counter. The old total frame
count remains in diagnostic logs. A still desktop can have a low or zero update
rate without being disconnected. The Mac shows **Sending FPS**, which measures
a different stage and can differ from the phone.

After the first installation and USB-debugging authorization, leave the Mac host
running and open the Huawei app. The host detects the authorized USB device,
repairs the HDC tunnel after reconnection, and the foreground receiver retries.
**Start streaming on launch** avoids pressing Start each time the Mac app opens.
This is not yet zero-setup installation for a new customer: official HDC,
permissions and a properly provisioned native client are still required. Native
USB attach does not automatically launch the phone app. A sleeping or locked
phone may need to be unlocked and the app reopened.

HarmonyScreen is offered at **$0 under MIT**, with a small optional link to
YouWo.ai in both apps. Opening that link leaves the receiver for the browser;
return to HarmonyScreen to resume. Original SideScreen attribution is retained,
and LICENSE/NOTICE are included in both application packages. General Huawei
distribution signing and Apple notarization remain release blockers; see
[release readiness](docs/RELEASE.md).

### Optional support invitation (Mac 0.1.3)

A quiet support invitation is implemented for the Mac app. It appears after
each session with five minutes of use, when the user clicks Stop, and never
during streaming. Not now, Escape or closing dismisses that session's request;
the next qualifying session asks again. There is no permanent-dismissal option.
All functionality stays free. The invitation remains disabled until a verified
YouWo-owned one-time checkout is configured; no payment link is invented and
no inherited upstream funding link is used. See [support setup](docs/SUPPORT.md).
The support invitation is in the Mac host only.
