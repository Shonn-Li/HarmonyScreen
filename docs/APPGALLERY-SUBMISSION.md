# AppGallery submission — 0.1.4

Status: prepared locally, not submitted or published. The signed device build is
installed on the owner's Mate XT 2. The current Huawei web account is signed in
but the developer portal requires real-name verification before distribution.

## App information

- Name: HarmonyScreen
- Bundle: com.shonnli.harmonyscreen
- Version: 0.1.4 (104)
- Price: free
- Suggested category: Utilities / Tools (confirm against the console taxonomy)
- Devices declared by the package: phone, tablet
- Verified hardware: Huawei Mate XT 2 running HarmonyOS 7; Apple silicon Mac
- Minimum declared platform: HarmonyOS 5.0.1 (API 13). Older devices are not yet
  verified; do not advertise universal compatibility.
- Publisher identity: complete Huawei verification under the owner's selected
  individual or company account. YouWo.ai is the product credit; it does not
  imply that Huawei has verified a company account.

## English listing

**Summary:** Turn your Huawei into an extra Mac display over USB.

HarmonyScreen extends your Mac desktop onto a compatible Huawei HarmonyOS device.
Connect with a USB data cable, open the companion Mac app and keep HarmonyScreen
open on your Huawei. Work with a separate desktop for reading, notes or chat.

- Full-screen display with portrait and landscape layouts.
- Follow-phone orientation automatically resizes the Mac desktop.
- Optional scaling to match the apparent text size of your Mac.
- Live stream FPS counter and automatic reconnection.
- Free, with YouWo.ai credit and retained open-source attribution.

Setup requires the companion Mac app, Huawei's HDC tool, USB debugging authorized
on your own Mac, and macOS Screen Recording permission. This release receives
video over USB; phone touch control, audio and native wireless pairing are not
enabled. Resolution, frame rate and compatibility depend on the device and Mac.
Rotating can briefly reconnect the stream while the desktop changes size.

## 中文介绍

**简介：** 通过 USB 将华为设备变成 Mac 的扩展屏幕。

HarmonyScreen 可以把 Mac 的扩展桌面显示在兼容的华为 HarmonyOS 设备上。
使用支持数据传输的 USB 线连接，在 Mac 上打开配套程序，并在华为设备上打开
HarmonyScreen，即可增加用于阅读、笔记或聊天的桌面空间。

- 全屏显示，支持横屏和竖屏。
- 选择“跟随手机”后，旋转设备会自动调整 Mac 桌面尺寸。
- 可按 Mac 的文字显示大小估算缩放比例。
- 实时帧率显示与断线自动重连。
- 免费使用，由 YouWo.ai 提供，保留开源项目署名。

首次使用需要安装配套 Mac 程序及华为 HDC 工具，在自己的 Mac 上完成 USB 调试
授权，并授予 macOS 屏幕录制权限。此版本通过 USB 接收画面，暂不提供手机触控
操作 Mac、音频或原生无线配对。实际分辨率、帧率及兼容性取决于设备与 Mac。
旋转时桌面会重新配置，画面可能短暂重连。

## Review notes

The receiver connects only to 127.0.0.1:54322 through the authorized HDC reverse
tunnel. No account, payment or cloud relay is required in the Huawei receiver.
The INTERNET permission is necessary for this local socket transport. It does
not mean that screen frames are uploaded to YouWo servers. Reviewers need the
companion Mac host and an authorized USB connection to exercise the core feature.

1. Install the signed Mac host and official HDC tool. Grant Screen Recording.
2. Connect a compatible phone via a USB data cable; enable USB debugging and
   approve this Mac. Open the native receiver.
3. The Mac host starts on launch by default unless the user disabled that option.
4. Verify visible desktop content, then rotate portrait/landscape in Follow phone.
5. Stop and restart the host; the foreground receiver reconnects automatically.

## Packaging and remaining store steps

- The `.app` archive built in release mode at
  `HarmonyClient/build/outputs/default/HarmonyClient-default-unsigned.app`.
  It is unsigned and is not ready to upload as a signed store submission.
- The privately signed HAP is debug-provisioned for the owner's phone. Never
  upload it as a general store release, or publish its profile, keys or device ID.
- After account verification, register/associate the bundle with an APP ID,
  obtain the matching distribution certificate/profile, sign a release `.app`,
  and validate it before uploading.
- Review the privacy statement and supply the publisher's contact and public
  privacy URL. Add screenshots containing demonstration content only, select
  distribution regions, complete the console's required declarations and submit
  for Huawei review. Approval and publication remain Huawei-controlled.
- Official guide: https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-publish-app

## Validation

64 Swift tests passed. Both signed Mac and privately signed native phone builds
installed. Observed 3184×2232 landscape → 2232×3184 portrait → 3184×2232 landscape
and matching host layouts with one virtual display identity. A deliberate port
conflict produced a non-blocking reconnect status and recovered automatically
after the test released the port. This does not replace AppGallery review or
testing on additional device models.
