# HarmonyScreen privacy statement — publisher review draft

This draft describes the native HarmonyOS USB receiver version 0.1.4. Before
store submission, the publisher must confirm its identity, provide a privacy
contact and publish the approved statement at a public URL. This is not an
AppGallery-approved policy.

## Screen content and connection

HarmonyScreen receives video of the selected Mac desktop over a USB data cable
using Huawei's HDC debugging transport. Frames are decoded in memory and shown
on the device. This receiver does not save screen recordings or upload the video
to YouWo servers. The Mac must be trusted and authorized by the device owner.
USB debugging is an operating-system development capability beyond this app;
authorize only computers you control.

The receiver sends its viewport dimensions and reported display density to the
Mac so the Mac can size the virtual desktop. The Mac can send the chosen screen
orientation to the receiver. The receiver has no advertising or analytics SDK,
requires no app account, and does not request access to contacts, location,
camera, microphone, photo library or personal documents. Its INTERNET permission
is used for the local socket carried through HDC.

## Diagnostics and preferences

The receiver writes status, viewport dimensions, frame counts and frame-rate
diagnostics to local HarmonyOS system logs. The Mac companion keeps local
preferences for the display and connection and writes local diagnostic logs.
These logs are not automatically sent to YouWo. Operating-system diagnostics
and vendor services are governed by their respective privacy terms.

## External links

Tapping YouWo.ai opens the user's browser at https://youwo.ai. That website's
privacy practices apply after navigation. The receiver does not transmit screen
frames in that link. This phone release contains no payment checkout.

## User controls

Disconnect stops the receiver's automatic connection attempts. Closing or
backgrounding the receiver stops its stream; returning to it can reconnect.
You can revoke the Mac's USB debugging authorization through HarmonyOS settings.
Uninstalling the receiver removes its application data; system diagnostic logs
are retained and managed by the operating system.

## Publisher contact

Publisher identity and privacy contact: to be supplied by the verified owner
before publication. Do not submit this draft with placeholder information.
