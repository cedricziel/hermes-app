# iOS photo preview

Tapping a photo in a chat on iPhone or iPad opens a native UIKit photo viewer
(`ios/Runner/PhotoPreview.swift`), full screen on black as in Photos. It has
pinch and double-tap zoom, a tap that hides or shows the bar, a Share button
(the system share sheet, including AirDrop, Save Image and compatible installed
apps), and a Close button. A swipe up or down on the photo closes it while it is
not zoomed in; zoomed in, the same drag pans the photo.
The composer keyboard is dismissed before the preview opens. VoiceOver exposes
the thumbnail as a named image button.

It replaced Apple's Quick Look sheet. On iOS 27, Quick Look draws the
photo in another process, so a swipe on the photo never reached the sheet's
dismiss gesture and the photo could only be closed with its X or grabber.
Before Quick Look, the viewer was a Flutter MaterialPageRoute with
InteractiveViewer and Close/Save buttons. That viewer remains the fallback
outside iOS; the React ImageViewerScreen represents
that fallback, rather than simulating the native UI in the web catalog.

Received photos reuse the bytes already loaded for the thumbnail. Embedded
photos are staged directly; picked files are copied into the media cache.
The viewer and its share action receive a local file in Library/Caches/hermes_media,
never a server URL or authentication token. The original file format and name
are retained. Save Image uses the system share sheet and the app's add-only
Photos permission description.

A newer photo request supersedes an older one still being staged. Removing the
thumbnail, replacing its attachment or signing out prevents a stale preview from
opening. Signing out dismisses the preview and clears the cached file. The
native image is hidden for inactive snapshots; backgrounding dismisses it so
it cannot cover the app's lock screen on return.

A native preview failure leaves the thumbnail in the chat and offers a retry
message. Formats must be ones `UIImage` decodes (an animated GIF shows its
first frame). No external app is opened
merely by tapping a photo.

## Validation on iPhone and iPad

Flutter tests cover cache staging, local/received/embedded photos, duplicate
requests, cancellation, native error/retry, keyboard focus and VoiceOver's button
semantics. CI builds the native Swift bridge. UIKit's photo controls require
simulator/device validation:

1. Open a received photo and one you picked. Pinch and double-tap to zoom.
2. Swipe the photo down (and up) to return to the same chat; a short drag
   springs back. Test portrait, landscape and iPad split view; zoom in, pan,
   then zoom out and swipe it away.
3. Use Share to send the actual image through AirDrop and another installed app.
   Confirm the file name, format, orientation and resolution are preserved.
4. Choose Save Image, accept/deny Photos access and retry. Cancelling the share
   sheet must return to the photo rather than close the chat.
5. Open the photo with the composer keyboard up. Close it and confirm the
   keyboard stays dismissed. Use VoiceOver to activate the thumbnail and native
   preview controls.
6. Background/foreground, lock/unlock and sign out while a photo is open or being
   prepared. No photo should reappear over the app lock or after sign-out.

Apple references:
[UIScrollView zooming](https://developer.apple.com/documentation/uikit/uiscrollview),
[UIActivityViewController](https://developer.apple.com/documentation/uikit/uiactivityviewcontroller).
