# Design brief: Reply from the notification

Change: `openspec/changes/notification-inline-reply/`. Read its design.md for the facts, the send path and what is kept; this brief is what the visual design pass needs and records.

## Design (done)

Claude Design canvas "Hermes: Reply from the notification", built on the Hermes App design system: https://claude.ai/artifact/NdpCnxunitd6yWpb5V7peG (private; ask its owner for access). 19 artboards. The system's notification UI (banner, expanded card, text field, unlock prompt) is drawn as a neutral frame; only its text is the app's. The two in-app boards use the real `ChatHeader`, `UserMessage`, `AssistantMessage` and `ChatComposer`.

Boards, by row:

- **Reply from a finished reply (iPhone):** 1 reply offered, 2 typing the reply, 3 answer arrives, 4 locked device (a labelled placeholder for the system's unlock prompt).
- **How it ends:** 5 not sent with the text kept, 6 not sent with long text, 7 couldn't confirm, 8 App Lock turned on before the reply, 9 App Lock on when the reply finished.
- **Back in the app:** 10 the chat after tapping "Reply not sent" (phone), 11 the same on a Mac window, 12 the Notifications dialog with its new footnote.
- **Mac:** 13 reply offered, 14 typing, 15 not sent.
- **Dark and largest text:** 16 reply offered dark, 17 not sent dark, 18 typing at the largest text size, 19 "Couldn't confirm" at the largest text size.

Decisions taken in the design pass:

- The only new in-app UI is one footnote in the Notifications dialog. Everything else is notification text, so there is no new widget. The prefilled chat is the existing deep-link open and shows no extra banner: the notification already said the reply was not sent, and the text in the composer is the explanation.
- One action. "Reply" is the only button on a "Reply ready" notification; no "Open" button, because a tap on the notification opens the chat. This keeps the action row one 44 pt button on iPhone and one 28 pt button on the Mac.
- Field text: placeholder "Reply to Hermes", button "Send". Not "Your answer" (that is the request question's field) and not "Send reply" (the system's own label stays short for large text).
- Every ending has fixed text and no buttons: a notification that offers "Try again" would invite a resend of text the app no longer has. Where the text is kept, tapping restores it in the composer; the user presses send.
- "Reply not sent" has two bodies (text kept, text too long to keep) and a separate "Couldn't confirm" for a lost answer. They must not be merged: the first two say nothing reached Hermes, the third says it may have.
- Under App Lock the title is "Hermes", never the chat's title, in line with how App Lock treats titles.
- Status is words, not colour. No icon beyond the app icon; the notification's text carries the state.
- Largest text: the system wraps and the field and Send stack; no copy needs truncation (the longest body, "Couldn't confirm your reply was sent. Open Hermes to check.", fits in five lines at the largest size).
- Mac: the same copy and one 28 pt Reply button in the banner; its field opens in the banner. The Mac handles the response in the app's own process, so it behaves as the foreground path.

Corrections where the earlier draft did not work:

- The proposal's "Android is out because the headless runtime only promises iOS" was stale (#914 runs request actions in Android's background isolate). The real reason is the lock screen: no authentication requirement can be set on an Android action. Recorded in the proposal's non-goals.
- "Reply ready notifications have no category today" was stale: `hermes.reply.ready` exists with a placeholder. The action goes in a new sibling category so App Lock and failed replies keep the placeholder-only one.
- The unsent text was to live in the payload at any length; it is now capped at the preview length, never kept under App Lock, and uses its own payload key (`'q'` means "new chat" and would have opened the wrong screen).
- A lost `prompt.submit` answer had no ending; "Couldn't confirm" was added, following the settled lost-answer rule.
- "Reply failed" must not be posted when the background window closes the transport; kept from the earlier draft and covered by the spec.

Copy added by the design (all fixed text, none with the typed text):

| Where                                 | Copy                                                                                                 |
| ------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| Action title                          | Reply                                                                                                |
| Field placeholder                     | Reply to Hermes                                                                                      |
| Field button                          | Send                                                                                                 |
| Not sent, text kept                   | Reply not sent. Open Hermes to try again.                                                            |
| Not sent, text too long               | Reply not sent. Open Hermes to write it again.                                                       |
| Could not confirm                     | Couldn't confirm your reply was sent. Open Hermes to check.                                          |
| App Lock on at reply (title "Hermes") | Open Hermes to reply.                                                                                |
| Notifications dialog footnote         | On iPhone and Mac you can reply to a finished reply from its notification. Not while App Lock is on. |

Catalog widget list (Widgetbook): no new widget. One changed use case: `NotificationsDialog` with the footnote, in both themes, phone and Mac width, at the largest text size (design-system card `NotificationsDialog`, `enabled`, `scheduleAlerts`). The notification itself is system UI and is not a catalog widget; its text is covered by unit tests of `attentionFor`, `inline_reply.dart` and the category definitions.

New components needed: none. The design system had everything the in-app boards used (`ChatHeader`, `UserMessage`, `AssistantMessage`, `ChatComposer`, `ModelPill`, `NotificationsDialog`, `Icon`).

Checked by rendering: all 19 boards were rendered in headless Chrome against the design system bundle and looked at (contact sheets of the notification boards, the Mac banners and dialog, both composer boards and the largest-text boards). That does not replace a look at the canvas in the claude.ai viewer, which was not done.

Not checked and not checkable here: how iOS and macOS actually draw the action, the text field, the Lock Screen and the unlock prompt (the frames are neutral); VoiceOver and Voice Control on the action and the field; Dynamic Type in the system's own notification UI; the notification dialog's footnote placement in the real dialog (the canvas draws it under the dialog, the final place is under "Notify me" in the footer text of that group).

## Who and why

Someone who sent a chat off and gets "Reply ready" while away from the app, and wants to answer in a few words without waiting for the chat to load. They may be on the Lock Screen or in a meeting. They may have turned on App Lock because others handle their phone, so nothing here may let a reply or a title past it.

## Navigation and screens

No navigation change. The action is on the notification; the tap opens the chat as it does today. "Reply not sent" opens the chat with the composer holding the kept text. Settings: no switch; one footnote in the Notifications dialog.

## Accessibility

- The action and its field are the system's, so VoiceOver reads the title "Reply", the placeholder and "Send" as the app gave them: they must be words, not symbols.
- Bodies are full sentences, readable alone. No colour carries meaning.
- Touch targets are the system's (44 pt on iPhone); the Mac banner's button is 28 pt.

## Differences by platform

| Platform       | Reply action | Notes                                                                                                        |
| -------------- | ------------ | ------------------------------------------------------------------------------------------------------------ |
| iPhone, iPad   | yes          | Requires unlock; handled in the plugin's isolate or the app's. Not verified on a device.                     |
| Mac            | yes          | The app's own process handles the response. Not verified.                                                    |
| Android        | no           | No authentication requirement is possible on an action; Android reply notifications show on a locked screen. |
| Windows, Linux | no           | No notification actions.                                                                                     |
| watchOS        | not designed | A mirrored notification may or may not show the action.                                                      |
