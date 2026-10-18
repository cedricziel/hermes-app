# iOS photo preview

Tapping a photo in a chat on iPhone or iPad opens Apple's Quick Look preview
in a large system sheet. It provides native pinch/double-tap zoom, a Share
sheet (including AirDrop and compatible installed apps), and pull-down dismissal.
The composer keyboard is dismissed before the preview opens. VoiceOver exposes
the thumbnail as a named image button.

The previous viewer was a Flutter MaterialPageRoute with InteractiveViewer and
Close/Save buttons. It had no share action or interactive dismissal. That
viewer remains the fallback outside iOS; the React ImageViewerScreen represents
that fallback, rather than simulating Apple's system UI in the web catalog.

Received photos reuse the bytes already loaded for the thumbnail. Embedded
photos are staged directly; picked files are copied into the media cache.
Quick Look and its share action receive a local file in Library/Caches/hermes_media,
never a server URL or authentication token. The original file format and name
are retained. Save Image uses the system share sheet and the app's add-only
Photos permission description.

A newer photo request supersedes an older one still being staged. Removing the
thumbnail, replacing its attachment or signing out prevents a stale preview from
opening. Signing out dismisses the preview and clears the cached file. The
native image is hidden for inactive snapshots; backgrounding dismisses it so
it cannot cover the app's lock screen on return.

A native preview failure leaves the thumbnail in the chat and offers a retry
message. Formats must be supported by iOS Quick Look. No external app is opened
merely by tapping a photo.

## Validation on iPhone and iPad

Flutter tests cover cache staging, local/received/embedded photos, duplicate
requests, cancellation, native error/retry, keyboard focus and VoiceOver's button
semantics. CI builds the native Swift bridge. UIKit's photo controls require
simulator/device validation:

1. Open a received photo and one you picked. Pinch and double-tap to zoom.
2. Pull down from the sheet or grabber to return to the same chat. Test portrait,
   landscape and iPad split view; pan a zoomed photo before dismissing it.
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
[QLPreviewController](https://developer.apple.com/documentation/quicklook/qlpreviewcontroller),
[UISheetPresentationController](https://developer.apple.com/documentation/uikit/uisheetpresentationcontroller).
