## Why

On the Mac a chat can only be read in the main window, next to the sidebar. The Mac native concept adds conversation windows: a chat opened in its own window, without the sidebar, so several chats (also from different profiles) can sit side by side and a long reply can be watched while the main window is used for something else.

## What Changes

- On macOS, "Open in New Window" (⌥⌘O, thread context menu) and a double-click on a thread in the sidebar open that chat in its own window.
- The conversation window has no sidebar. Its 52 pt toolbar holds the traffic lights, the chat's title and "<profile> · <model>" below it, and the window actions: Show in Main Window, Pin/Unpin (⇧⌘P), Share and a … menu (Rename, Copy Transcript, Archive, Delete). The message column and composer are the main window's.
- A conversation window stays on the profile it was opened from. Switching profile in the main window does not change it.
- Opening a chat that already has a window brings that window to the front instead of opening a second one.
- The open conversation windows are listed in the Window menu (checked for the key window); ⌘0 brings back the main window, ⌘W closes the conversation window.
- Open conversation windows are reopened, with their frames, when the app is launched again on the same server.
- The main window refreshes a chat that is open in a conversation window when it becomes the key window again, and a conversation window refreshes its chat when it becomes key, so a reply sent in one shows in the other.
- Signing out or changing server closes every conversation window.

### Non-goals

- Conversation windows on Windows, Linux, iPad or anywhere but macOS. The menu item and double-click do nothing there.
- Live mirroring of a streaming reply into a second window. The other window catches up when it becomes key.
- Notifications for replies that finish in a conversation window; the main window's notifications are unchanged.
- Following a theme change made in the main window while a conversation window is open; it takes the theme at open.

### Security and privacy

Each conversation window runs in its own Flutter engine. It never reads the token store and never refreshes a token: it asks the main window for the headers of each request, and on a 401 asks again, naming the rejected headers. The main window's `AuthController` stays the only owner of the session and the only refresher, so rotating refresh tokens cannot race. The secure storage plugin is not registered in conversation windows at all. The persisted window list holds server URL, profile name, session id and title (no tokens) in shared preferences.

### Telemetry

None. Conversation windows do not start their own telemetry SDK; their HTTP calls get no span.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `chat`: a "Conversation windows (macOS)" requirement.

## Impact

- New dependency `desktop_multi_window` (mixin.dev): one engine per window on macOS.
- `macos/Runner`: the main window survives being closed (hidden, so ⌘0 can bring it back), sub-window chrome and a per-window channel (close, show, frame autosave, share, key state).
- `lib/src/windows/`: the window registry and restoration (main isolate), the sub-window app, the token hand-off, the conversation window screen and its toolbar.
- `AuthController`: headers for a conversation window's request.
- `ChatController`: refresh one thread's details and messages.
- The thread view is pulled out of `chat_screen.dart` so both windows use it.
