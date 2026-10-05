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
- DevEco project sync and its native compile also passed after reopening this configuration.
- The earlier API 24 build and device transport evidence below remain historical evidence, not a phone-playback result.

## Native client

- CMake/Ninja arm64 native decoder compilation: passed.
- ArkTS compilation: passed.
- Resource compilation and release-mode HAP packing: passed.
- HAP contains `libharmonyscreen.so`, `libc++_shared.so`, compiled ArkTS, resources and package metadata.
- Release-mode HAP contains no development source map or local user-directory path.
- Minimum API: 13; original target API: 24, current target API: 21. This is build configuration, not tested platform coverage.
- Connected test phone reports OpenHarmony 7.0.0.107 / API 26.
- The original unsigned installation was rejected with `9568320: no signature file`.
- On October 4, DevEco automatic signing generated a Huawei debug certificate/profile after account sign-in and USB reconnection. After linking the signing config to the default build product, signed HAP packaging passed and HDC reported `install bundle successfully` on the Mate XT 2.
- A second signed build using `scripts/build_harmony_signed.py` also passed, staging the private configuration outside tracked source. The device-specific signed HAP and signing material are private and are not public release assets.
- Initial launch was blocked by the phone's lock screen (`10106102`). The owner subsequently unlocked it and supplied a screenshot of native video with 826 rendered frames. Earlier web-console and Application Agent identity-verification notices did not prevent this DevEco debug-signing route; they do not establish public distribution eligibility.

## Full-screen phone validation

- Signed full-screen update built, installed and launched successfully on the authorized Mate XT 2 / API 26.
- The Mac uses custom 1592×1116 with HiDPI enabled and a configured 30 FPS. A 30-frame independent HEVC decode verified the encoded dimensions are 3184×2232.
- A screenshot captured directly from the phone verified the Mac desktop fills its 3184×2232 panel, with no app header/footer or phone status/navigation bars. Screenshots containing the owner's desktop are retained locally rather than committed.
- The XComponent surface stays mounted while controls overlay it. Controls hide after video arrives; tap/back reveal them. The native surface uses aspect-preserving fit for mismatched stream/panel sizes.
- After the Mac stream was stopped, the phone displayed a connection error overlay. Restarting the host restored the video and hid the overlay automatically, without another connection action on the phone.
- No sustained frame-rate, latency, or cable unplug/replug benchmark has been performed. A configured 30 FPS is not a measured throughput claim.

## Mac and USB video transport

- Mac capture permission granted; virtual display active; HDC reverse tunnel configured.
- Host stream: 60 HEVC frames received and independently decoded by FFmpeg at 1920×1200.
- The same 60-frame test passed over Mac → HDC forward → phone → HDC reverse → Mac.
- This verifies encoded video transport across the USB connection, not decoding by the Huawei phone.

## Still unverified

Long-duration stability, measured frame rate and end-to-end latency, physical cable unplug/replug, background/foreground behavior, touch/audio, other device models/orientations, general distribution signing, and Mac notarization.

## Automatic sizing verification — 2026-10-04

- Signed receiver update installed successfully on the previously registered
  Mate XT 2. Full-panel viewport metadata: 3184×2232 / 2232×3184;
  reported x/y DPI approximately 383.1/383.3 (about 211×148 mm unfolded).
- Landscape/portrait/landscape/portrait changes confirmed with direct device
  screenshots, not only a successful build or handshake. Final mode follows
  the phone and respects its rotation lock.
- Mac at 1728×1117 logical points: Huawei matched-size desktop 1060×742 or
  742×1060, left/top aligned. At Mac 2056×1329: portrait desktop 882×1258,
  encoded output still 2232×3184. Restored Mac to its original scaling.
- Mac virtual display ID stayed stable across these changes. Built-in remained
  main and iPad Sidecar retained its right-side arrangement.
- Caught macOS capturing the wrong virtual display through both SCStream and
  CGDisplayStream after repeated display recreation. Reconnected all virtual
  displays once to clear the corrupted mapping, and changed the app to keep
  its virtual-display object while resizing. Final capture uses SCStream.
- 56 Swift tests passed, including viewport bounds, portrait dimensions,
  proportional scaling, edge attachment, and fragmented/coalesced protocol input.
- Mac app Developer ID signed; not notarized. Receiver debug signing remains
  device-specific. Physical fold/unfold and sensor movement are not independently
  tested; orientation requests and resulting real device window sizes are tested.


## 0.1.1 FPS and free YouWo.ai branding (2026-10-04)

- Replaced the cumulative frame label with a rolling one-second receiver FPS
  measurement. It counts successful decoder-to-surface submissions, not physical
  panel refresh or end-to-end latency. Total frames remain in diagnostics.
- Installed the signed 0.1.1 native build on the owner's Mate XT 2. A direct phone
  screenshot showed the YouWo.ai credit, 26.3 FPS during warm-up, and the Keep FPS
  visible control. Later samples reached 28–30 FPS with the Mac set to 30 FPS.
- Portrait playback remains 2232×3184, with a 742×1060 logical desktop under the
  current Mac scaling. The Mac app update and receiver process restart both
  recovered playback. Existing Sidecar remained attached.
- 56 Swift tests passed. Portable frame validation and the new frame-rate test
  passed under AddressSanitizer and UndefinedBehaviorSanitizer. The rate test
  covers partial sampling windows, steady 30 FPS, idle decay to zero and reset.
- Native release build and private debug signing succeeded; Mac Developer ID
  signing and strict signature verification succeeded. LICENSE and NOTICE are
  included in both packages. Device-specific HAP and screenshots stay private.
- Idle waits at protocol message boundaries no longer disconnect merely because
  the desktop sends no new frames. Incomplete message payloads retain their
  receive timeout. This does not promise recovery from every cable/OS failure.
- General Huawei distribution signing, Apple notarization, physical replug and
  cold-install verification on additional devices remain incomplete. This is a
  free developer preview, not a universally installable end-user release.


## Mac 0.1.2 support invitation and release video (2026-10-04)

- Added a native, optional one-time support sheet to the Mac host. Qualification
  requires five minutes of connected frame flow and an explicit Stop in the
  visible, active settings window. Pairing, active streaming, automatic display
  resizing and app exit do not trigger it. Choosing No thanks, closing, Escape
  or opening checkout consumes the invitation. Settings reset does not clear it.
- Checkout is gated on a reviewed public one-time HTTPS destination packaged
  in SupportOffer.json. No YouWo payment link has been supplied or verified;
  production builds remain inactive. The preview shows this explicitly.
- 59 Swift tests passed, including persistence across policy recreation, all
  eligibility gates, exclusion of sleep/disconnected/idle gaps, and URL/payment
  type validation. Native SwiftUI preview rendered and visually reviewed.
- Prepared a 36-second 1080p/30 FPS H.264/AAC video. The user-supplied early phone
  capture and illustrative layout animation are labelled; no private chats or
  signing data appear. Full video decode verification passed. Audio is original.
- Mac Developer ID package built and verified. Live installation/interaction of
  this update remains pending because the Mac was locked during final review.
  Current phone receiver is unchanged at 0.1.1. Payment checkout and social
  cross-posting await the owner's payment destination and platform/account.

## Mac 0.1.3 recurring support invitation (2026-10-04)

- Supersedes the 0.1.2 permanent-dismissal behavior at the owner's request.
  After each session with five minutes of connected frame flow, an explicit Stop
  in the visible, active settings window can show the invitation. Not now,
  closing, Escape or opening checkout dismisses that session's request only.
- Session state stays in memory. New sessions qualify independently; temporary
  disconnections and automatic display rebuilds preserve accumulated use without
  creating extra prompts. Legacy permanent-dismissal preferences are ignored.
- All 61 Swift tests passed, including repeated qualifying sessions, short
  subsequent sessions, duplicate suppression and automatic restart continuity.
  The updated native SwiftUI preview was rendered and visually reviewed.
- The Developer ID signed Mac package built successfully and passed strict
  signature verification. The installed Mac remains 0.1.1; app-control could
  not resolve its window during this update. The Huawei receiver is unchanged.
- No verified YouWo checkout has been provided, so the production invitation
  remains inactive. Contributions remain one-time payments, not subscriptions.
  Apple notarization and general Huawei distribution remain incomplete.
