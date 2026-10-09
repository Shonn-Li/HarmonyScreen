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

## Automatic panel sizing and rotation

The HarmonyOS receiver reports its actual full-screen XComponent viewport in
physical pixels, on connection and whenever the area changes. `display.xDPI` and
`yDPI` estimate the panel dimensions; UI `densityPixels` is used only for vp-to-px
conversion and is not treated as physical PPI.

- **Type 14, client → Mac:** eight payload bytes, four unsigned 14-bit values:
  pixel width, pixel height, xDPI × 10, yDPI × 10. Each value uses two bytes of
  seven data bits, high group first; both bytes have bit 7 set. Old hosts safely
  skip these high-bit bytes as unknown types. Bounds: 320–8192 per side, 32 Mi
  pixels total, DPI zero (unknown) or 50–1000. Invalid reports are ignored.
- Type 14 also opts the receiver into **type 15, Mac → client:** one byte:
  0 follows the phone (respecting rotation lock), 1 portrait, 2 landscape.
  Type 15 is never sent to clients that have not sent a valid type 14.
- The native receiver applies orientation to the HarmonyOS window. It does not
  rotate the video texture: the Mac desktop is resized upright and type 1's
  transform remains zero. Landscape and portrait keep their native pixel axes.

Sizing: panel mm = viewport pixels / reported PPI × 25.4. With “Match Mac text
size”, desktop points = panel mm × (main Mac desktop width / main Mac width in
mm), rounded to even dimensions. Reported physical sizes are estimates. Unknown
or suspicious DPI falls back to native 2× Retina sizing. Encoding remains at the
panel's even pixel dimensions; macOS's 2× desktop render is resampled when the
physical-size match requires a different scale. This is not pixel-perfect 1:1
rendering in matched-size mode; turn off “Match Mac text size” for native 2×.

Updates are debounced 900 ms. The virtual display object and ID survive rotation
and scaling, avoiding unnecessary display detachments and reducing exposure to
macOS's virtual-display capture mapping bug. The transport reconnects briefly.
Left/right/above/below positioning uses current macOS logical bounds; other
screens retain their positions. Native physical Mac remains main.

If multiple virtual screens were already in a corrupt capture state, disconnect
all virtual screens once and reconnect them; app restarts alone may not clear it.
A fresh topology resolved the observed Sidecar/HarmonyScreen mix-up. This is a
known OS limitation, not a guarantee that all future topology changes are safe:
https://github.com/waydabber/BetterDisplay/discussions/1322

## Connection health and phone controls (0.1.7)

The native receiver sends the existing type-4 heartbeat every two seconds while
reading. Eight seconds without any received bytes ends the connection, including
an HDC socket that remains open after the underlying link stops responding. A
connection that responds but produces no decoded frame is retried after twelve
seconds. A static desktop remains valid while heartbeat replies arrive. App
backgrounding closes the stream; returning to the foreground resumes automatic
connection attempts unless the user explicitly paused them.

The Mac polls one HDC snapshot at a time. Confirmed USB device disappearance or
replacement closes only the current loopback viewer; the five-second display
cleanup still applies. A failed probe is treated as unknown, not as an unplug.
Tunnel configuration is also serialized. No authorization or network-debugging
settings are changed.

- **Type 16, phone → Mac:** two high-bit-set bytes for side and alignment. Sides
  0–3 mean left, right, above, below; alignments 0–2 mean start, center, end.
  `[0xff, 0xff]` queries the current setting and opts into replies. Malformed
  payloads are ignored. High-bit payloads are harmless to older hosts.
- **Type 17, Mac → phone:** the current two-byte placement, sent only after a
  valid type-16 request. The phone highlights the acknowledged side rather than
  assuming a tap succeeded. Placement does not require restarting the stream.
- Placement uses Mac desktop coordinates and is saved on the Mac. It is separate
  from rotating the phone or changing the encoded resolution.

During automatic retries, the phone shows stable instructions and fixed Retry
now / Pause reconnect controls. Connection attempts do not toggle the button
labels or show a stale desktop as live. The display surface stays allocated.
