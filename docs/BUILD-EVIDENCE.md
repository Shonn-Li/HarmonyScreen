# Build and transport evidence — 2026-10-04

These checks do **not** establish successful native on-device video playback.

## Official SDK

- Command Line Tools: Mac ARM64, 6.1.1.280.
- Vendor download page: https://developer.huawei.com/consumer/en/download/command-line-tools-for-hmos
- SHA-256 verified against the page's Mac ARM64 copy control: `47d0e558b8285e1452f4d3611863027ec0d1135642761bef23402434e22382d4`.
- Bundled SDK: HarmonyOS 6.1.1.125, API 24.
- Hvigor: 6.24.2.

### DevEco compatibility follow-up

- DevEco Studio 6.0.1.251 rejects a project targeting 6.1.1(24) during editor sync.
- The current project targets 6.0.1(21), matching the installed editor's bundled SDK 6.0.1.112.
- Release-mode native C++, ArkTS compilation and HAP packaging passed using the editor's bundled tools. `scripts/build_harmony.sh` uses this toolchain by default; the minimum API remains 13.
- The earlier API 24 build and device transport evidence below remain historical evidence, not a phone-playback result.

## Native client

- CMake/Ninja arm64 native decoder compilation: passed.
- ArkTS compilation: passed.
- Resource compilation and release-mode HAP packing: passed.
- HAP contains `libharmonyscreen.so`, `libc++_shared.so`, compiled ArkTS, resources and package metadata.
- Release-mode HAP contains no development source map or local user-directory path.
- Minimum API: 13; original target API: 24, current target API: 21. This is build configuration, not tested platform coverage.
- Connected test phone reports OpenHarmony 7.0.0.107 / API 26.
- Unsigned installation was attempted once and rejected with `9568320: no signature file`.
- Huawei-issued application certificate and device provisioning profile are still required. The web console requires developer identity verification before issuing them for the owner's account.

## Mac and USB video transport

- Mac capture permission granted; virtual display active; HDC reverse tunnel configured.
- Host stream: 60 HEVC frames received and independently decoded by FFmpeg at 1920×1200.
- The same 60-frame test passed over Mac → HDC forward → phone → HDC reverse → Mac.
- This verifies encoded video transport across the USB connection, not decoding by the Huawei phone.

## Still unverified

Signed HAP installation, native surface creation, the phone's hardware decoder, displayed frames, clarity at native panel resolution, end-to-end latency, reconnect/background behavior, and Mac notarization.
