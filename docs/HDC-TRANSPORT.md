# HarmonyScreen USB design

HarmonyScreen carries a framed video stream over the existing authenticated HDC connection. It does not replace HDC's device authorization, implement a new USB driver, or enable network debugging.

## Reviewed primary sources

- [HDC command reference](https://github.com/openharmony/docs/blob/master/en/application-dev/dfx/hdc.md): client/server/daemon architecture; device selection and authorization; file transfer; fport/rport; task listing/removal; error reporting and troubleshooting.
- [HDC forwarding implementation](https://github.com/openharmony/developtools_hdc/blob/master/src/common/forward.cpp): TCP endpoint setup and loopback forwarding.
- [Native video decoding](https://github.com/openharmony/docs/blob/master/en/application-dev/media/avcodec/video-decoding.md): asynchronous buffers, Annex-B access units, XComponent surface, decoder lifecycle.
- SideScreen's StreamingServer.swift, StreamClient.kt, VideoEncoder.swift and handshake codecs, pinned by the upstream Git history in this repository.

HDC's low-level wire protocol remains owned by Huawei/OpenHarmony; we intentionally call its supported CLI rather than reimplementing authentication or USB multiplexing.

## Data path

Mac virtual display → ScreenCaptureKit → VideoToolbox HEVC Annex-B → TCP localhost:54322 → HDC rport → phone localhost:54322 → native AVCodec decoder → XComponent surface.

The host resolves HDC from HARMONYSCREEN_HDC, ~/.local/bin, Homebrew or DevEco Studio. It lists USB targets, refuses ambiguous selection, and configures `hdc -t DEVICE rport tcp:54322 tcp:54322`. An OK exit code alone is insufficient: HDC prints some failures while exiting zero, so the host checks output and reads back the reverse rule. The existing status loop repairs a missing rule after reconnect.

## Streaming protocol, preview 1

Reuse SideScreen's legacy HEVC stream to keep the port small. Integers below are big endian unless stated otherwise. TCP reads must assemble complete messages; packet boundaries do not correspond to messages.

| Type | Direction | Payload |
|---|---|---|
| 0 | Mac → phone | u32 frame length, then one HEVC Annex-B access unit |
| 1 | Mac → phone | u32 encoded width, u32 encoded height, u32 transform |
| 4 / 5 | phone → Mac / Mac → phone | opaque 8-byte ping/pong timestamp |
| 6 | Mac → phone | u32 frame length, u8 flags, u64 timestamp, access unit; only after metadata opt-in |
| 7 | phone → Mac | u8 keyframe request flags |
| 10 | Mac → phone | u8 codec ID: 0 HEVC, 1 H.264 |
| 13 | Mac → phone | u32 logical desktop width, u32 logical desktop height |

The native preview does not advertise metadata or wireless authentication support. It accepts legacy type 0; the host waits for an HEVC keyframe containing parameter sets. Frames are bounded to 16 MiB, dimensions to 8192 per side and 32 megapixels total. Nonzero rotation/flip is rejected visibly in this preview. Decoder input waits are bounded; disconnect shuts down the socket and releases decoder/surface resources.

The first native preview is display-only. Touch API plumbing exists but UI touch mapping is not enabled until aspect-ratio/rotation behavior is tested on hardware. No audio, clipboard, files or account data travel through the stream.

## Security and release boundaries

USB mode rejects non-loopback clients in the inherited server; device access depends on HDC authorization. Do not use HDC TCP debugging on untrusted networks. No keys, device identifiers, certificates or provisioning profiles belong in this public repository.

Mac Developer ID signing, Apple notarization, Huawei debug signing, Huawei distribution signing, and AppGallery publication are separate steps. A signed Mac DMG does not imply a signed/installable HAP. No public release should claim HOS 7 playback until the native app displays frames on a real device.

## Verified on 2026-10-03

- A connected Huawei running OpenHarmony 7.0.0.107 accepted HDC reverse forwarding.
- A 1 MiB random payload completed Mac → phone → Mac via HDC forward/reverse with exact byte equality.
- This validates TCP carriage over USB, not hardware video decoding or app installation.
