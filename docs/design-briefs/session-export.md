# Design brief: Export chat as JSON

Change: `openspec/changes/session-export/`. Read its design.md for the server facts (route, no `Content-Length`, a stream that can stop short, no redaction); this brief is the visual and copy pass.

## Design (done)

No Claude Design canvas was built for this change. The pass was written from the Hermes App design system README and the repo's files (`lib/src/widgets/`, `thread_actions_menu.dart`, the briefs of Server care and Tools). There is no canvas link and no artboard count; nothing here was rendered or looked at in a viewer. The first pictures of these states are the Widgetbook use cases, and they are the place to correct this brief.

Screens and states decided: the menu row in five places (enabled, hidden, disabled while busy), one alert in three phases (confirmation, progress, failure with eight messages), the saved snack bar, and the silent cancel.

Decisions, one line each:

- There is no screen. The feature is one menu row and one modal alert that changes phase (confirm, then progress, then a failure). It is the same shell as the existing confirmations: `AppAlertDialog` (Cupertino alert on iOS, restrained Mac alert at every width, Material dialog on Android, Windows and Linux). No sheet, no page, no bar.
- The alert never names the chat and never shows its title, so App Lock has nothing to blank and the app switcher shows nothing private.
- Confirmation: title "Export this chat as JSON?", the secrets sentence is the first line of the message, Cancel is the default (bold on Apple; on Android and desktop two text buttons, Cancel first, neither filled, as for every Android confirmation). Export is a plain button, never red: it is not destructive, the file leaves the app's protection.
- Progress is the same alert with the title "Preparing the export…", the thin `BusyBar` (size unknown, so never a percentage and no byte counter) and Cancel. Escape and a tap outside do nothing while it runs; Cancel is the way out.
- Failures reuse the alert: a title that starts with the word "Couldn't" or names the problem, one sentence of cause, one sentence of consequence ("Nothing was saved."). Buttons: Close (default) and, where retrying can help, Try again, which goes back to the confirmation, never straight to a request.
- Eight failures have eight messages (table below). Status is the words in the title; there is no coloured icon to carry it.
- A saved file is a floating snack bar, "Chat saved", with no path, no name and no action. A cancelled save sheet shows nothing.
- Menu row: "Export Chat as JSON…" (Mac, title case) and "Export chat as JSON…" (elsewhere, sentence case, matching the existing "Copy Transcript" / "Copy transcript" split), directly under Copy Transcript, with the ellipsis because a dialog follows. No shortcut.
- One export at a time: while one runs, the row is disabled everywhere.
- The settled 10-second rule does not fit a download of unknown size, so there is one exception: after 10 s without the first byte the progress alert adds the line "Still waiting for Hermes. Cancel stops it." and goes on until the spec's five-minute deadline, then says "Couldn't confirm the export" (see "Lost answer"). Reason: the request only reads, the user holds Cancel, and the alert never says saved. Open question 1 asks whether the deadline should shrink.

Corrections: none (there was no canvas to correct against).

Copy added by the design (English; German in the table at the end):

- Confirmation: "Export this chat as JSON?" / "The file holds this session as Hermes stored it, including the system prompt, tool output and file paths. It can contain secrets such as keys. Save it only somewhere you trust." / "Cancel", "Export".
- Progress: "Preparing the export…" / "Hermes is sending the file. A long chat can take a while." / "Cancel"; after 10 s the extra line "Still waiting for Hermes. Cancel stops it."
- Failures and the snack bar: see the failure table and "Saved".

New components needed:

| Name                   | What it is                                                                                                                                      | Closest existing                                                                                            |
| ---------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| `SessionExportAlert`   | Plain-model alert with a phase: `confirm`, `progress` (with `stalled`), `failed(kind)`; callbacks `onConfirm`, `onCancel`, `onRetry`, `onClose` | `AppAlertDialog` + `AppDialogAction` (shell); `BusyBar` (progress line); `showConfirmDialog` (confirm only) |
| `SessionExportFailure` | Enum of the eight failure kinds with their copy keys, shared by the widget and the controller                                                   | none (the controller's outcomes of 1.3)                                                                     |

No other widget: the menu rows are entries in the existing menus and the snack bar is the app's usual `SnackBar`.

## Who and why

Someone who runs Hermes on their own machine and wants the full record of one chat: to keep it, to attach it to a bug report, to read what the agent did in a tool call, or to move it. Copy Transcript gives them the visible turns; this gives everything Hermes stored. They are on any of the six clients, mostly at a desk (Mac, Windows, Linux) or on a phone sending the file to Files.

Two facts the design must not blur:

- **The file can hold secrets.** The system prompt, tool arguments and results, and file paths come as stored, unredacted. The confirmation says so before anything is requested.
- **It is this session, not the whole lineage.** A chat Hermes compressed into a new session exports only its current session. The copy says "this session as Hermes stored it" and never "the whole chat".

## Shared kit (reuse, do not invent)

- `AppAlertDialog` and `AppDialogAction` (`lib/src/widgets/adaptive_dialog.dart`), with `scrollable: true` so the buttons stay in view at the largest text size. Not `showConfirmDialog` for the progress and failure phases, since the phase changes inside one alert.
- `BusyBar` for the progress line.
- The existing thread menus: `ThreadAction`, `macThreadMenuItems`, `ThreadActionsButton`, `mac_chat_toolbar.dart`, `conversation_windows_menu.dart`, `MacCommand` in `menu_layout.dart`.
- `MediaActions.save` for the system save sheet; `threadExportFileName` rules for the name.
- The app's usual `SnackBar` for "Chat saved". Icons from `AppIcons` (the row has no leading icon, like Copy Transcript).
- Not used: `StateMessage` (no screen), `AppBanner` (nothing persistent), `SecretFieldRow` (no secret is typed or shown), `SettingsScaffold`.

## Navigation

There is no navigation. The action runs where the user already is and returns to it.

- **iPhone, Android phone:** chat header "…" menu (`ThreadActionsButton`): after Copy transcript and before the Rename group. Sidebar row menu on the chat list: the same order.
- **iPad, wide Android, Windows, Linux:** the same two menus. The row menu in the sidebar is the dense button (28 pt minimum target stays).
- **Mac:** the row menu and the toolbar "…" menu (after Copy Transcript, before Connection Details), the **Chat** menu in the menu bar ("Export Chat as JSON…" after Copy Transcript, no shortcut), and the conversation window's menu. The alert is the restrained Mac alert, centred on the window that started the export.
- Absent for a local or mock chat or one without a profile in context menus. In the Mac menu bar, which does not move items around, the item is present and disabled for such a chat (open question 2).

## The alert, phase by phase

Job: "Confirm that I know what is in the file, show that Hermes is working, and tell me plainly whether a file exists."

One alert, one phase at a time; the transitions replace title, message and buttons in place (no second window).

### 1. Confirm

Title "Export this chat as JSON?". Message as above. Buttons: Cancel (default), Export. Cancel, Escape and a tap outside all cancel with no request. Hierarchy: the secrets sentence is part of the single message paragraph, not a separate warning box (an alert holds one block of text); "can contain secrets such as keys" is the sentence a reader must not skip, so it is the second sentence and the message is no longer than three.

### 2. Progress

Title "Preparing the export…". `BusyBar` under the message, indeterminate. Message "Hermes is sending the file. A long chat can take a while." One button: Cancel (default). The alert is not dismissible by Escape or by a tap outside (a stray tap must not cancel a long download; the explicit button must). After 10 s without a first byte the message gains the line "Still waiting for Hermes. Cancel stops it." and the bar keeps moving. When the bytes are complete and valid, the alert closes and the system save sheet opens at once; there is no "ready" phase.

### 3. Failure

Title and message from the table. Buttons: Close (default) and, for the rows marked, Try again. Try again closes the failure and shows phase 1 again; the user confirms again before any request (spec: nothing is resent on its own).

| Kind               | Title                          | Message                                                                                         | Try again |
| ------------------ | ------------------------------ | ----------------------------------------------------------------------------------------------- | --------- |
| `gone`             | Chat not on the server         | This chat is no longer on the server. Nothing was saved.                                        | no        |
| `unsupported`      | This server can't export chats | It may be running an older version of Hermes. Nothing was saved.                                | no        |
| `profile` (404)    | Profile not found              | The profile this chat belongs to doesn't exist on the server any more. Nothing was saved.       | no        |
| `profile` (400)    | Profile name not valid         | Hermes didn't accept this chat's profile name, so it couldn't read the chat. Nothing was saved. | no        |
| `unreadable` (503) | Hermes can't read its chats    | The server's chat store couldn't be read. Check the server, then try again. Nothing was saved.  | yes       |
| `lost` (timeout)   | Couldn't confirm the export    | Hermes didn't finish in time. Nothing was saved.                                                | yes       |
| `incomplete`       | The export was incomplete      | The file stopped before the end, so nothing was saved.                                          | yes       |
| `offline`          | You're offline                 | Connect to the internet or your server, then try again. Nothing was saved.                      | yes       |

"Profile" has two rows because the spec gives a 404 and a 400 their own messages; they share the kind and the Try again rule. The `profile` messages do not print the profile name (it is not a secret, but the alert has no need of it and the name is a server value). No message prints a decoder message, a status code, the id or a path.

## Saved and cancelled

- Saved: floating `SnackBar` "Chat saved", the app's usual duration, no action, no name, no path. On iOS it appears over the chat after the Files sheet closes; on a Mac after the panel closes.
- Cancelled sheet: nothing, not even a snack bar. The bytes are dropped.

## Menu rows

States: enabled; absent (local or mock chat, or no profile); disabled while an export runs (any menu, same label, no extra text). In the Mac menu bar: enabled, disabled (also with no chat selected, and while one runs). The row has no leading icon in the Mac and Material menus, like Copy Transcript. Order in every menu: Copy Transcript, Export Chat as JSON…, then the existing next item.

## Every state

- **Loading:** phase 2. **Empty:** none, a chat with no messages still exports (a file with an empty list of messages is valid). **Error:** the table. **Offline:** `offline`; the row stays enabled, since a connection that comes back is the usual fix.
- **Lost answer:** a timeout or a stalled stream. At 10 s without the first byte, the extra progress line. At the deadline (five minutes, spec), `lost`, "Couldn't confirm the export", Try again confirms again, nothing resent. A connection that drops with some bytes received is `incomplete`, never `lost`: the user is told the file stopped, not that the outcome is unknown.
- **App Lock:** locking while a phase is showing closes the alert and cancels the fetch; unlocking shows nothing (no alert, no save sheet, no snack bar). No title is in the alert, so nothing needs blanking. The row itself follows the menu's existing rules (the menu is not reachable while locked).
- **Phone and desktop/Mac:** the alert's width is the platform's own. The Mac alert is at its restrained width at every window size; the Cupertino alert is 270 pt; Material and Windows/Linux dialogs follow Material's width.
- **Light and dark:** theme colours only; nothing custom, no hex.
- **Largest text size:** the message wraps and scrolls inside the alert (`scrollable: true`); the buttons stay visible; the Cupertino alert stacks its two buttons. Nothing is cut with an ellipsis.
- **German:** the strings are 20 to 40 percent longer ("Chat als JSON exportieren…", "Der Export ist unvollständig"). Titles must wrap to two lines on a 270 pt Cupertino alert; no fixed heights.

## Accessibility

- Alert buttons are 44 pt on Apple, 48 dp on Android, at least 28 pt on the Mac (the platform alert's own buttons meet this); the dense sidebar "…" button keeps its 28 pt target and its label "Chat actions for <title>" (existing).
- The progress alert is announced as "Preparing the export" and its `BusyBar` carries an indeterminate progress label; the stalled line is announced when it appears (live region). Completion is announced by the save sheet or by the snack bar's text.
- Focus starts on Cancel in the confirmation and the progress alert, on Close in a failure. Escape cancels the confirmation and closes a failure; it does nothing during progress.
- Status is always a word in the title ("Couldn't confirm", "incomplete", "offline"); no colour and no icon carries meaning.
- Keyboard: Tab order is the visual order; Enter activates the default button only when it is the focused one (Cancel, Close), so Enter never exports by reflex.
- Reduced motion: the bar's animation follows the platform setting; the stalled line does not animate.

## Privacy

- The alert, the snack bar and the menu show no title, id, profile, path or content. The file name appears only in the system save sheet, after the user has confirmed.
- Bytes live in memory until the sheet returns, the user cancels, the profile or server changes, the user signs out, or App Lock locks. They are never staged in the media cache, copied to the clipboard or logged.
- A `FormatException` message is never shown, logged or reported (spec); the failure is `incomplete`.
- Telemetry names are fixed (`session_export.*`); none is shown in the interface.
- Nothing typed or shown here is a secret of the app's own; the file's possible secrets are the reason for the confirmation, not something the app displays.

## Differences by platform

|                | iPhone / iPad                                                                                                  | Android                           | Mac                                                        | Windows, Linux                    |
| -------------- | -------------------------------------------------------------------------------------------------------------- | --------------------------------- | ---------------------------------------------------------- | --------------------------------- |
| Entry          | Header menu, sidebar row menu                                                                                  | Same                              | Row menu, toolbar "…", Chat menu, conversation window menu | Header menu, sidebar row menu     |
| Alert          | Cupertino alert                                                                                                | Material dialog, two text buttons | Restrained Mac alert                                       | Material dialog, two text buttons |
| Save           | Files export sheet                                                                                             | System "create document" picker   | Save panel with the name                                   | Save dialog                       |
| Row label case | Sentence case                                                                                                  | Sentence case                     | Title case                                                 | Sentence case                     |
| Shortcut       | none                                                                                                           | none                              | none                                                       | none                              |
| Backgrounding | A suspended app may lose the request; it reads as `lost` or `incomplete` (not verified) | Same | n/a | n/a |

## Scenario coverage

| Spec scenario            | Where it is covered                                                       |
| ------------------------ | ------------------------------------------------------------------------- |
| One request              | Phase 1 then 2: one request after Export; Try again returns to phase 1    |
| Server without the route | Failure `unsupported`, no Try again                                       |
| Server chat              | Menu rows in all five places, "Menu rows"                                 |
| Local chat               | Row absent (disabled in the Mac menu bar), Copy Transcript unchanged      |
| Chat of another profile  | Request carries the chat's profile (not visible); failure `profile` (404) |
| Cancel                   | Phase 1: Cancel, Escape, tap outside; no request, nothing saved           |
| Confirm                  | Phase 1 to phase 2 "Preparing the export…" with Cancel                    |
| Truncated stream         | Failure `incomplete`; no save sheet, no resend                            |
| Saved bytes              | Save sheet name from the title with `.json`; not visible in the alert     |
| Timeout                  | Failure `lost` "Couldn't confirm the export"; Try again confirms again    |
| Chat gone                | Failure `gone`                                                            |
| Corrupt body             | Failure `incomplete`; no decoder text in any message                      |
| Cancelled sheet          | Nothing shown, bytes dropped                                              |
| Saved                    | Snack bar "Chat saved", no path                                           |
| App Lock                 | Alert closes, fetch cancelled, nothing after unlock                       |
| Failed export            | Log event only; the user sees the matching failure row                    |

## German copy (draft, owner to review)

| English                             | German                                                                                                                                                                                                                   |
| ----------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Export chat as JSON…                | Chat als JSON exportieren…                                                                                                                                                                                               |
| Export this chat as JSON?           | Diesen Chat als JSON exportieren?                                                                                                                                                                                        |
| Confirmation message                | Die Datei enthält diese Sitzung so, wie Hermes sie gespeichert hat, auch den Systemprompt, Tool-Ausgaben und Dateipfade. Sie kann Geheimnisse wie Schlüssel enthalten. Speichere sie nur an einem Ort, dem du vertraust. |
| Preparing the export…               | Export wird vorbereitet …                                                                                                                                                                                                |
| Chat saved                          | Chat gespeichert                                                                                                                                                                                                         |
| The export was incomplete           | Der Export ist unvollständig                                                                                                                                                                                             |
| Couldn't confirm the export         | Export nicht bestätigt                                                                                                                                                                                                   |
| Try again / Close / Export / Cancel | Erneut versuchen / Schließen / Exportieren / Abbrechen                                                                                                                                                                   |

The ARB files hold the full set; German follows the existing glossary in `lib/l10n/` (check "Sitzung" and "Systemprompt" against it).

## Open questions for the owner

1. **Deadline.** The spec's five minutes before "Couldn't confirm" is far from the 10 s rule. The design keeps the spec (a long export is legitimate) and adds the 10 s "Still waiting" line. Do you want a stall deadline instead (no bytes for 30 s ends it as `lost`)? That changes the spec's Timeout scenario.
2. **Mac menu bar.** Present but disabled for a local chat, or removed? The spec says the action is not offered; a disabled fixed menu item is the macOS convention and is assumed here.
3. **Bytes counter.** The size is unknown, so the design shows none. If `_getBytes` can report received bytes cheaply, "12 MB received" would show a stuck download from a slow one. Not designed.
4. **Share.** The save sheet is the only exit. If `share_plus` lands with Server files, "Share…" would be a second row; left out here.
5. **Compressed chats.** The copy says "this session"; should the confirmation also say a continued chat's earlier part is not included? Not added: the app cannot tell in advance.

## Not verified

No canvas; no rendering at all. The wording of the system alerts at the largest text size, VoiceOver and TalkBack output, `saveFile` on a physical iPhone, Android and the macOS sandbox, and the real response were not checked.
