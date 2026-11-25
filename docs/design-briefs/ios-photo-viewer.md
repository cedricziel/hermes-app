# iOS photo viewer

The native viewer a chat photo opens on iPhone and iPad (`ios/Runner/PhotoPreview.swift`, PR #1379). It replaces the Quick Look page sheet of #783, which could not be closed with a swipe on iOS 27: Quick Look draws the photo in another process, so the pan never reaches the sheet. No Claude Design canvas: the viewer is UIKit, not a Hermes design-system widget, and copies Photos. These are the decisions.

- **Placement:** full screen over the chat (`overFullScreen`, cross-dissolve in), on black. The chat shows through as the black fades during a swipe, as in Photos.
- **Bar:** a transparent navigation bar with the system Close item on the left and the system Share item on the right, in dark style. System items keep iOS's own glass look, size and translated labels. A tap on the photo hides the bar and the status bar; another tap shows them.
- **Closing:** Close, a vertical swipe (up or down) past 120 pt or faster than 900 pt/s, or VoiceOver's escape gesture. A shorter swipe springs back. While zoomed in, a drag pans the photo and never closes it.
- **Zoom:** pinch, and double-tap to 2.5x at the tap point or back to fit. Up to 3x, or the photo's full resolution when that is larger.
- **Share:** the system share sheet with the staged file (AirDrop, Save Image, other apps), anchored to the Share item on iPad.
- **Accessibility:** the photo is an image element labelled with its file name. The chat behind is hidden from VoiceOver while the viewer is up.
- **Other platforms:** unchanged. Android, Windows and Linux keep the Flutter `ImageViewerPage`, and the Mac keeps Quick Look.

**Why not a plugin:** pub.dev's image viewers (`photo_view`, `easy_image_viewer` and the like) are Flutter widgets. Using one would mean giving up the native share sheet path from #783 or bridging it back. No plugin presents a native UIKit photo viewer over the Flutter view.
