# Design brief: Link WhatsApp

Change: `openspec/changes/whatsapp-onboarding/`. Read its design.md for the server facts (statuses, the 600 s expiry, the 900 s drop, what apply does, what cancel does not do); this brief is the visual and copy pass.

## Design: brief reviewed, canvas pending (publish quota, resumes after 2026-11-15 00:00 UTC)

No Claude Design canvas exists yet, so there is no canvas link and none should be assumed. The brief was written from the Hermes App design system README, the merged briefs (`server-care.md`, `toolsets.md`), the shared widgets in `lib/src/widgets/` and the change's own files, then reviewed against the app-wide rules. No build starts before the canvas exists; when it does, run the design pass and bring this brief in line with it. The catalog PR (task 1 in tasks.md) is where the states below are first drawn, and it is the first place a human sees them; where a catalog use case shows that a decision here does not work, correct the brief in that PR, in a "Corrections" paragraph like the other briefs.

Screens and states decided (one pushed screen, "Link WhatsApp", whose body follows a phase; plus the entry button and the Finish confirmation):

- Entry: the "Link WhatsApp" button in the WhatsApp setup form.
- A. Setup: mode, allowed numbers, Start. Empty, invalid number, refused by the server, offline, lost answer.
- B. Preparing: Installing and Starting, with Cancel.
- C. Handset notice: before the tap, after the tap.
- D. QR: shown, hidden, rotated, expiring, expired; wide two-column layout.
- E. Linked: new account, "Already linked", Finish.
- F. Ends without a link: failed (the server's text), superseded, expired, setup gone, old server, profile deleted.
- G. Finish: the confirmation, saving, refused, lost answer with Check, setup gone, and the two saved outcomes on the Messaging list.

Decisions taken in this pass:

- One screen, not one route per step: the body switches by phase, as the Telegram pairing screen does. Back leaves the screen and cancels (best effort, once). There is no Done step: Finish closes both screens to the refreshed Messaging list.
- The entry is the same outlined button as Telegram's (magic icon), labelled "Link WhatsApp", with the line "Or enter the details yourself." under it. It is a button, never a start: opening the pairing screen sends nothing.
- Mode is two rows of the kit's choice row (Bot, Self-chat) with one line each, not a segmented control, because each needs a sentence. Bot is selected first. The numbers field is a text row with the phone keyboard.
- Start is the screen's one filled button in A. In every later phase the one button that moves the setup on is filled (Show QR code, Finish, Start again), and where no retry exists the one button is the outlined Back. Cancel is always an outlined button, never filled, never red.
- The code is a fixed 240 pt square (280 pt wide layouts) on a white tile with a 16 pt quiet zone, black modules, in light and dark alike. It never inverts, never takes theme colours and never scales with text size, because a scanner needs the contrast and the quiet zone. The tile sits on the surface colour with a 1 pt border in dark.
- The hidden state keeps the tile's exact footprint (no layout jump) and shows an eye-off icon and the word "Hidden". On a handset it carries "Show QR code"; on a tablet or computer it carries the line "Shows again when the app is unlocked and in front." and no button.
- The countdown counts the setup's 600 s, not the code's rotation (the server's `expires_at` is fixed at start and Baileys' rotation interval is not verified), so it reads "Setup closes in 8:42", not "Code expires". It turns into a warning banner with an icon for the last 60 s. It is announced to screen readers at 60, 30 and 10 seconds left, never every second.
- "Waiting for a scan" is a spinner plus the words, a polite live region. A rotated code replaces the tile content at once with no animation and no announcement.
- Handset notice (C): an `AppBanner` in the neutral tone with a phone icon, then the filled "Show QR code". After the tap the notice shrinks to one muted line above the code ("Scan this with the phone that has WhatsApp.") so the tap does not hide the instruction.
- Linked (E): a success banner, then the account as rows (name as title, number as subtitle, because a long name must not be cut at half the row), then a "What Finish does" section. "Already linked" is a neutral banner, not a success one, and says the app cannot unlink or replace the account.
- Failed texts are the server's own, shown in a surface-high box, selectable, wrapping (they can hold paths and 10 log lines), under a fixed title "WhatsApp setup stopped". No per-reason wording.
- Finish confirmation is `showConfirmDialog(..., cancelIsDefault: true)` (`AppAlertDialog`: Cupertino alert, restrained Mac alert, Material dialog with two text buttons). The helper defaults to `filled: true, cancelIsDefault: false`, so the flag must be passed. Cancel is first and the default (bold on Apple platforms); "Save and restart" is plain, never red and never filled. By its doc comment the helper binds the Return key to neither button, so on the Mac Return is not bound; the brief does not claim it is Cancel's, and Escape cancels.
- Finish result is shown on the Messaging list (`MessagingScreen`, titled "Messaging"; "Bots" is the Bot Mode tab, a different screen) as an `AppBanner` after the screens close: success tone when a restart was requested and `needs_restart` is false; warning tone otherwise. Neither says the gateway restarted.
- Polling pauses while the app is in the background or App Lock is locked (owner decision). On return, once unlocked, a neutral `AppBanner` with a pause icon says "Paused while the app was away." with the detail "Checking again now. The code may have changed." It goes at the next answer; if that poll fails, the offline banner replaces it. While locked nothing polls and App Lock's cover hides the screen.
- Lost answers end within 10 s with "Couldn't confirm...". Start: the action offered is Start again (it supersedes any earlier pairing). Finish: Check. Neither request is resent.
- A phone with a second device is the supported handset path. There is no "link by number" and no hint that there is one.

Copy added by the design (English; German in the localization task): everything quoted in the sections below. The spec's own strings (design.md "Decisions", the spec scenarios) are used verbatim: "Scan this with the phone that has WhatsApp.", "Show QR code", "Hidden", "Already linked", "Could not confirm the setup was saved.", "This server cannot link WhatsApp from the app", the Finish question and its two buttons, "Working...", "Waiting for a scan". Wording not stated by design.md, to be confirmed by the owner, is under "Open questions for the owner".

New components needed (plain-model widgets in `lib/src/messaging/widgets/`, each with Widgetbook use cases):

| Widget                | What it is                                                                          | Closest existing                                                                                                           |
| --------------------- | ----------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| `QrCodeCard`          | White tile with the code, "Hidden" state, countdown line, "Waiting for a scan" line | none; the tile is new, the lines are `GroupedRow`-weight text                                                              |
| `ScanSteps`           | The four numbered steps, text only                                                  | `DisclosureTile` body text; no list widget exists                                                                          |
| `HandsetQrNotice`     | Notice plus "Show QR code" button, before and after the tap                         | `AppBanner` (neutral) with an action                                                                                       |
| `PairingStageCard`    | Spinner, title, one line, stage word, Cancel                                        | `InstallProgress` running body in `lib/src/widgets/install_parts.dart`; reuse its spinner row if it fits without log lines |
| `LinkedAccountCard`   | Success or "Already linked" banner and the account rows                             | `AppBanner` plus `GroupedRow`                                                                                              |
| `WhatsAppSetupForm`   | Mode rows, numbers field, Start                                                     | `GroupedChoiceRow`, `GroupedTextFieldRow` (`grouped_form.dart`)                                                            |
| `PairingEnd`          | Title, the server's text in a box, Start again or Back                              | `StateMessage` plus a text box as in the tools install failure                                                             |
| `WhatsAppPairingView` | The body for every phase, over one model, so the screen holds only the controller   | `ContentColumn` body of the Telegram screen                                                                                |

The QR renderer is a package chosen in the screen PR under the repo's pub.dev rule. `QrCodeCard` takes a payload string and draws with whichever renderer is chosen; its use cases use an invented payload (`demo-qr-0001`), never a real one.

## Who and why

The person who runs Hermes on their own machine and wants the WhatsApp channel working without opening the web dashboard. They are on a phone more often than not, which is exactly the device that cannot scan its own screen. They know WhatsApp; they may not know what a bridge, a JID or a gateway is, so the words below avoid those. They want three things: to know whether the link worked, to not open the bot to strangers by accident, and to not interrupt other channels without being asked.

Facts the design must not blur:

- **The server links the account, the app only shows the code.** The app does not hold WhatsApp credentials; they stay in the server's session directory. Nothing here unlinks an account.
- **Leaving cancels the pairing, not the link.** If the scan already succeeded, the account stays linked and only the settings are unsaved.
- **Finish restarts a shared gateway.** A restart stops conversations on every messaging channel it serves, not the app's chat.
- **The QR code is a credential.** Whoever scans it links their WhatsApp to this server.

## Shared kit (reuse, do not invent)

- Page chrome: the Telegram pairing screen's chrome (a pushed route with `AdaptiveBackButton`, title "Link WhatsApp", `ContentColumn`). The settings screens' `SettingsScaffold` is not used: this is a flow, not a settings page, and the Telegram screen it sits beside is a flow.
- `AppBanner` for every status and outcome (tone, icon, title, detail, action; a polite live region; status is icon plus words).
- `GroupedListView`, `GroupedSection`, `GroupedRow`, `GroupedChoiceRow` and `GroupedTextFieldRow` for the setup form and the account rows.
- `StateMessage` for the end states that offer only Start again or Back.
- `LoadingSkeleton` is not needed: the first state after Start is the stage card, not a list.
- `showConfirmDialog` / `AppAlertDialog` for the Finish question. `AdaptiveSheet` is not needed.
- `SecretFieldRow` is not used. Nothing is typed as a secret; the QR payload and pairing id are secrets by the "Secret fields" rule in `docs/architecture/settings-screens.md`, adapted as the design.md "Decisions" say (no Show/Hide field, hidden on lifecycle and lock, no copy). Do not restate the rule here.
- `DestructiveTintButton` is not used: nothing is deleted. Cancel and Leave are ordinary outlined buttons.
- Icons from `AppIcons`; status is always icon plus word. Buttons use the app's 44 pt / 48 dp / 28 pt button styling as the Tools screens do.

## Navigation

- **iPhone, Android phone:** Messaging list, WhatsApp row, setup form, "Link WhatsApp" pushes the pairing screen. Back goes to the form with the pairing cancelled. Finish pops both screens to the Messaging list.
- **iPad, wide Android, Windows, Linux:** the same pushes, centred in a `ContentColumn`; no list-beside-detail, because the flow has one thread. At content width of 640 pt or more the QR phase is two columns.
- **Mac:** the same push in the content area. The Telegram pairing screen it copies uses a plain `AppBar` with `AdaptiveBackButton(previousTitle: 'Messaging')` on every platform, Mac included, so there is no separate Mac toolbar: Back and ⌘[ (which cancels, like Back; the chord goes through `MacCommandScope`, never a key handler), title "Link WhatsApp". Return presses the screen's filled button when it has focus order priority (Start in A, Finish in E); this is the screen's own focus handling, not the confirm dialog's.

## Screen: Link WhatsApp

Job: "Link my WhatsApp to Hermes, tell me when it worked, then save it."

Title "Link WhatsApp". Subtitle: none (the profile is shown only where it matters, in E). A back button labelled with the previous screen's title as on the Telegram screen.

### A. Setup

- Section "Mode" with a footer line under it. Rows: "Bot" with "Hermes has its own WhatsApp number. The people you allow message that number."; "Self-chat" with "Hermes uses your own number. You talk to it in your chat with yourself." One selected (check at the trailing edge on Apple, leading radio on Material), as `GroupedChoiceRow`.
- Section "Who may message it" holding the field "Allowed phone numbers" (phone keyboard, autocorrect and suggestions off). Footer: "Digits with country code, separated by commas. Leave it blank to keep the current list. In Self-chat a blank list means your own number."
- Button "Start" (filled, full width). Under it a muted line: "The server installs what it needs, then shows a code to scan."
- Hierarchy: mode, numbers, Start. Start is the only filled button.

States:

- Empty: nothing selected beyond Bot, blank numbers; Start enabled (blank is valid, it keeps the old list).
- Invalid number (checked on Start and on leaving the field): the field's error line with an error icon: "Enter phone numbers: digits, with an optional + at the start, separated by commas." For `*` or a JID: "Letting everyone message Hermes is a server setting. Here you can only name phone numbers." Nothing is sent.
- Starting: Start becomes a spinner row "Starting..." (the button stays, disabled, keeps its width); Back stays active and cancels nothing because no id exists yet.
- Server refused (400 or 422, any `detail`): `AppBanner` error "Couldn't start the setup." with the server's text as the detail; the form keeps its values; Start is available again.
- Offline or unreachable: only a connection error before the request was sent (no route, no connection made). `AppBanner` warning "You're offline." with "Couldn't start the setup. Nothing was started." and Start stays available. Any failure after the request was sent (a dropped connection, a timeout, no answer) is the lost-answer state below, never this one.
- Lost answer: after 10 s, or on any failure after the request was sent, `AppBanner` warning "Couldn't confirm the setup started." with "It may have begun on your server. Starting again replaces it." and a filled "Start again". Nothing is resent.
- Old server: see F.

### B. Preparing

- Stage card: spinner (16 pt), title "Preparing WhatsApp on your server..." and the stage word as the card's second line: "Installing" or "Starting". Detail: "This can take a few minutes the first time. You can leave this screen; leaving cancels the setup." The unknown status reads "Working...".
- Below, an outlined "Cancel setup".
- Loading means this card; there is no skeleton and no progress percentage (the server gives none).
- Installing for the full 300 s window is expected, so no warning is added at any elapsed time; the server's own error (F) ends it.
- Offline while here: the card stays, with an `AppBanner` warning above it, "You're offline." detail "Checking again when you're back." Polling continues every 2 s.
- After a pause (background or App Lock): the same neutral "Paused while the app was away." banner above the card until the next poll answers.
- Lost answer: not applicable (the screen polls; a failed poll is the offline line above).

### C. Handset notice (shortest side under 600 dp, QR status)

- Before the tap: `HandsetQrNotice`: `AppBanner` neutral, phone icon, title "Scan this with the phone that has WhatsApp.", detail "A phone can't scan its own screen. Open this screen on another device, or on a computer, signed in to the same server." Then the filled "Show QR code". Under it the outlined "Cancel setup".
- After the tap: the notice becomes the one muted line; the code shows (D). The tap moves screen-reader focus to the code.
- Each lock, background or lifecycle leaving `resumed` returns to the "before the tap" state. On return, once unlocked, the "Paused while the app was away." banner shows above the notice until the next poll answers.
- The notice is the honest handset path. It is not an error and has no warning tone.

### D. QR

- Order: the code tile, then "Waiting for a scan" (spinner plus words), then "Setup closes in 8:42", then `ScanSteps`, then Cancel setup.
- `ScanSteps`: "1. Open WhatsApp on the phone that has your account." "2. Tap Settings, then Linked devices." "3. Tap Link a device." "4. Point the camera at this code."
- Wide layout (content 640 pt or more): the tile left, a column right holding the status line, the countdown, the steps and Cancel.
- Hidden: tile footprint kept, eye-off icon, "Hidden". Handset: "Show QR code". Tablet and computer: "Shows again when the app is unlocked and in front."
- Rotated: the tile redraws at once; no animation, no announcement, the countdown is unchanged.
- Countdown at 0:00 while offline: the end shows locally as soon as the countdown reaches zero (the screen cannot poll), the expired block of F with its "Start again", and no code is kept.
- Expiring (last 60 s): the countdown line becomes an `AppBanner` warning "Setup closes soon." detail "Scan now, or start again after it closes." A warning icon with the words; the code stays.
- Expired (status `expired` or a 410): the tile is replaced by an end state (F, "The code expired"). The code is not kept.
- Offline: the code stays, with an `AppBanner` warning above it, "You're offline." detail "This code may be out of date." Polling continues.
- App Lock and lifecycle: hidden as above. Polling is paused then; on return, once unlocked, the "Paused while the app was away." banner (neutral, pause icon, detail "Checking again now. The code may have changed.") shows above the code until the next poll answers. If the countdown ran out while paused, the expired block of F shows locally at once.

### E. Linked

- `LinkedAccountCard`: success `AppBanner` "WhatsApp is linked." Then a section "Account" with a row "Name" (value if short, else subtitle) and "Number" with the digits shown as given with a leading +. A missing name reads "Name not given"; a missing number reads "Number not given".
- Already linked: neutral banner "Already linked" with the detail "This server already has a WhatsApp account linked for this profile. Hermes uses it as it is. The app can't unlink or replace it." No QR. The rows are the same.
- Section "What Finish does" (footer text only, no rows): "Saves the mode and allowed numbers for <profile>, switches WhatsApp on, and asks the messaging gateway to restart." In Self-chat with a blank list: "Allowed: your own number."
- Filled "Finish", full width. Under it, muted: "If you leave now, the account stays linked on the server, but the setup isn't saved."
- There is no Start again here and no "link another account".

### F. Ends without a link

Each is a `StateMessage`-style centred block (icon, title, detail) with one button, filled for Start again and outlined Back where no retry exists; the server's text, when there is one, sits in a surface-high box under the detail. All stop polling.

| End                                               | Title                                           | Detail                                                            | Button            |
| ------------------------------------------------- | ----------------------------------------------- | ----------------------------------------------------------------- | ----------------- |
| Error (any text)                                  | "WhatsApp setup stopped"                        | the server's text as given                                        | "Start again"     |
| Expired (410 or `expired`)                        | "The code expired"                              | "A setup closes after 10 minutes. Start again to get a new code." | "Start again"     |
| Superseded (`cancelled`, not by the user)         | "Another setup replaced this one"               | "WhatsApp was set up again from another device or window."        | "Start again"     |
| Gone (404 on a poll)                              | "This setup is no longer on the server"         | "It may have expired, or the server restarted."                   | "Start again"     |
| Old server (405, or 404 not starting "Profile '") | "This server cannot link WhatsApp from the app" | "You can still enter WhatsApp's settings yourself in the form."   | "Back" (outlined) |
| Profile deleted (404 starting "Profile '")        | "This chat's profile no longer exists"          | "Pick another profile to set up WhatsApp."                        | "Back" (outlined) |

Start again returns to A with the earlier values, so nothing is retyped, and asks for a new pairing. Old server and profile deleted offer no retry and nothing is retried.

### G. Finish

- The confirmation, shown when Finish is pressed in E: title "Save and restart?", body "Save the WhatsApp setup and ask the messaging gateway to restart? Conversations on messaging channels will be interrupted.", buttons "Cancel" (first, default) and "Save and restart" (plain). The Mac alert is the restrained one at every width. Material shows the same two text buttons, Cancel first.
- Saving: Finish becomes a spinner row "Saving..."; the route cannot be popped until the answer or 10 s (system back and the iOS swipe included), and the Mac back chord, which goes through `MacCommandScope`, is disabled; no key handler is added. Leaving does not send Cancel while apply is in flight. Leaving after the lost-apply state sends nothing new either: no second apply and no `DELETE` (the record is most likely gone, and `DELETE` would not unlink anything).
- Saved: the screens close to the Messaging list, which shows an `AppBanner` at the top, with a close button.
  - Restart started: success tone, "WhatsApp is set up." detail "A restart of the messaging gateway was requested."
  - `restart_started` false: warning tone, "WhatsApp is saved." detail "No restart was requested. Restart the messaging gateway from Server." Action "Open Server" where the server screen exists.
  - `restart_started` true but `needs_restart` true: warning tone, "WhatsApp is saved." detail "A restart was requested; if WhatsApp doesn't answer, restart it from Server." Same action.
  - After a Check-confirmed save (below) the restart outcome is unknown: warning tone, "WhatsApp is saved." detail "Restart the messaging gateway from Server if WhatsApp doesn't answer." with no restart claim.
  - A `restart_error` is appended to the detail as given.
  - The banner never says the gateway restarted.
- Refused (400, 409, 500 with a `detail`): `AppBanner` error "Couldn't save the setup." with the server's text; the screen stays on E with Finish available again. Apply is not repeated by itself.
- Lost answer (a dropped connection, or no answer in 10 s): `AppBanner` warning "Could not confirm the setup was saved." detail "Check whether WhatsApp is on for this profile." with a filled "Check". Finish is not shown again. Check reads the platform list. Before Finish sends apply the screen records whether `enabled` was already on for the profile. If it was off and Check shows it on, the save happened: the screens close with the Check-confirmed "WhatsApp is saved." banner above. If it was already on, Check cannot tell a saved setup from an earlier one, so it ends with "Couldn't confirm. Try again." and never reports saved. If Check shows it off, the banner reads "Not saved yet." with "Start again". If Check itself fails or 10 s pass: "Couldn't confirm. Try again." with Check once more. In l10n the spec's verbatim "Could not confirm the setup was saved." is kept as written, alongside A's "Couldn't confirm the setup started." (the two differ on purpose; do not unify them).
- Setup gone (404 on apply): the same end block as F, "This setup is no longer on the server", with the detail "The settings may not have been saved." and "Start again". On a linked session Start again returns to E at once with no new scan.

## Platform and size behaviour

- Desktop focus (owner decision): the code hides whenever the window loses focus, because the lifecycle leaves `resumed` then, while `AppLockController` covers on inactive only on phones. On a Mac, Windows or Linux window, switching to another app hides the code and it shows again on return. The catalog keeps a use case for the desktop hidden state with the "Shows again when the app is unlocked and in front." line, so the behaviour is seen before wiring.

- Handset (shortest side under 600 dp): C before D; stacked layout; buttons full width (handsets only).
- Tablet and desktop: D at once; two columns at 640 pt or more; the same buttons at their natural width in a row (primary first).
- Mac: the same `AppBar` chrome as every platform (no separate toolbar), ⌘[ back, 28 pt minimum targets, text buttons are standard Mac buttons. The Mac alert is restrained.
- Android: Material app bar, back button and the system back gesture both cancel. The Finish dialog is two text buttons. The code is not shielded from screenshots here: `FLAG_SECURE` is a follow-up outside this change (below).
- Windows, Linux: the Mac layout with the same `AppBar`; no extra chords.

## States every screen covers

| State             | Where                                                       |
| ----------------- | ----------------------------------------------------------- |
| Loading           | B (stage card); A "Starting..."; G "Saving..."              |
| Empty             | A with blank numbers                                        |
| Offline           | the warning banner in A, B, D; the error in G               |
| Error             | F, the refused banners in A and G                           |
| Lost answer       | A (Start again) and G (Check), both end within 10 s         |
| App Lock          | the code goes to "Hidden"; polling pauses; "Paused while the app was away." on return |
| Phone and desktop | C versus D, stacked versus two columns                      |
| Light and dark    | the tile stays black on white; banners use their tones      |
| Largest text      | see below                                                   |
| German            | see below                                                   |

## Largest text size

The text honours the selected size with no cap. The QR tile stays 240 pt (it is a scan target, not text); the page scrolls. Buttons stay full width on handsets and wrap to two lines; at tablet and desktop width they keep their natural width in a row. `ScanSteps` and the notice wrap; the countdown moves under "Waiting for a scan". Account rows move the value under the title. At a text scale of 2 or more the two-column layout stacks regardless of width.

## German

English strings are shorter than German; the long-string risks are: "Link WhatsApp" (WhatsApp verknüpfen), "Show QR code" (QR-Code anzeigen), "Waiting for a scan" (Warte auf das Scannen), "Allowed phone numbers" (Erlaubte Telefonnummern), "Save and restart" (Speichern und neu starten, a long confirm button on Material's two text buttons: allow it to wrap), "messaging gateway" (Messaging-Gateway, which may break at its hyphen; allow it to wrap there, and check a long compound without a hyphen still fits), and the step "Tap Linked devices" (use WhatsApp's own German labels, to be confirmed on a German install). The headline copy must not rely on a fixed width; the banner title wraps to three lines.

## Accessibility

- Targets: 44 pt Apple, 48 dp Android, 28 pt Mac minimum for every button and row. The QR tile is not a target; in the hidden state only "Show QR code" is.
- The QR tile is one semantics node: "QR code to scan with WhatsApp" when shown, "QR code hidden" when hidden. The payload is never in the semantics tree, a tooltip or a debug label.
- Status in words with an icon and never colour alone: the banners (tone icons), "Waiting for a scan" (spinner and words), the countdown (icon in the expiring state).
- Live regions: `AppBanner` is polite. The stage change (Installing to Starting to Waiting) is announced once each. The countdown is announced at 60, 30 and 10 seconds left, not every second. A rotated code is not announced.
- Focus order: banner or status, the code, the primary button, Cancel. After "Show QR code" focus moves to the code. After a lost answer or a refusal focus moves to the banner.
- Contrast: the tile's black on white is the maximum; banners follow the kit's AA tones.
- Keyboard on desktop: Tab follows the visual order; Return presses the filled button; Escape on the Finish dialog is Cancel.
- Reduced motion: no animation is added; spinners stay as they carry state.

## Privacy

- The QR payload and pairing id live in screen state only: not in logs, spans, breadcrumbs, preferences, the clipboard, a share sheet, a screenshot-friendly cache or state restoration. Cleared when the screen closes.
- No Copy and no Share anywhere on the screen. The code is not selectable text.
- App Lock blanks titles and text as it does elsewhere; on lock the code is "Hidden". The account's name and number, the allowed numbers and the server's error text are shown on this screen only. They go into no notification, snapshot, Lock Screen, Siri or log; the observability list in the proposal holds fixed words only.
- The profile name in "What Finish does" is shown to the user and never recorded.
- No content beyond a notification body leaves the app: nothing here posts a notification.
- Secrets stay in screen state; nothing is written to secure storage because nothing here is a typed credential.

## Spec scenario coverage

| Spec requirement and scenario                       | Screen and state                                                                                   |
| --------------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| Backend contract: Unknown fields and statuses       | B "Working..." for an unknown status; E "Name not given" and "Number not given" for missing fields |
| Backend contract: Old server                        | F, old server                                                                                      |
| Backend contract: Deleted profile                   | F, profile deleted                                                                                 |
| Entry and explicit start: Opening does not start    | A (no request on open; entry button is a button)                                                   |
| Entry and explicit start: Start carries the profile | A, Start (no visible change; a controller test)                                                    |
| Entry and explicit start: Numbers are checked       | A, invalid number (both messages)                                                                  |
| Progress and polling: Server installs packages      | B, Installing                                                                                      |
| Progress and polling: App in background             | C and D, hidden; B and D polling paused, then the "Paused" banner on return                        |
| Progress and polling: App Lock                      | B, C and D: nothing polls while locked; the "Paused" banner once unlocked                           |
| QR code: Code rotates                               | D, rotated                                                                                         |
| QR code: No copy or log                             | D (no copy or share action); Privacy                                                               |
| QR code: Hidden on lock or background               | D, hidden; C, before the tap                                                                       |
| QR code: Desktop focus                              | D, hidden, with the "Shows again" line                                                              |
| Handset flow: Phone                                 | C, both states                                                                                     |
| Handset flow: Mac                                   | D at once, with the "Shows again" line when hidden                                                 |
| Final states: Expired                               | F, expired; D, expiring                                                                            |
| Final states: Superseded                            | F, superseded                                                                                      |
| Final states: Error text                            | F, error                                                                                           |
| Final states: Already linked                        | E, "Already linked"                                                                                |
| Finish asks first: Saved                            | G, saved (both banners)                                                                            |
| Finish asks first: Refused                          | G, refused                                                                                         |
| Finish asks first: Setup gone after connected       | G, setup gone                                                                                      |
| Lost answers: Lost apply                            | G, lost answer with Check                                                                          |
| Leaving cancels: Back while waiting                 | Navigation and B, D (Back and Cancel setup); E footer                                              |
| Privacy: Request span                               | Not visible on any screen; controller test (task 2.4)                                             |

## Differences by platform

|               | iPhone                | Android phone                  | iPad / wide window      | Mac                     |
| ------------- | --------------------- | ------------------------------ | ----------------------- | ----------------------- |
| Code shown    | After "Show QR code"  | After "Show QR code"           | At once                 | At once                 |
| Layout        | Stacked               | Stacked                        | Two columns from 640 pt | Two columns from 640 pt |
| Finish dialog | Cupertino alert       | Two text buttons               | Alert                   | Restrained Mac alert    |
| Back          | Back button and swipe | Back button and system gesture | Back button             | Back, ⌘[                |
| Targets       | 44 pt                 | 48 dp                          | 44 pt                   | 28 pt                   |

## Decided by the owner

- App Lock pauses polling. Polling runs only while the app is in front and unlocked; on return once unlocked the "Paused while the app was away." line shows until the next answer (spec: Progress and polling).
- On desktop the code is hidden whenever the window loses focus (spec: QR code, Desktop focus).
- A "Hide QR code" button is left out (no spec scenario).

## Follow-ups outside this change

- Android `FLAG_SECURE` for the QR (block screenshots and recordings while the code is shown). Not part of this change: it needs native work and the proposal rules that out. Roadmap candidate only; no task here.

## Open questions for the owner

1. Mode wording. design.md does not say what "Bot" and "Self-chat" do beyond the bridge's two modes. The one-liners above ("Hermes has its own WhatsApp number..." and "Hermes uses your own number...") are the designer's reading and need confirming against the bridge.
2. Check after a lost apply reads the platform list; which field there means "WhatsApp is on" is to be confirmed from the fixtures (task 2.1 in tasks.md). Finish records `enabled` before sending apply; if it was already on, Check cannot confirm a save and ends with "Couldn't confirm", and after a Check-confirmed save the banner makes no restart claim (see G).
3. WhatsApp's German labels for Linked devices and Link a device, to be copied from a German install.
4. A "Open Server" action on the not-restarted banner relies on the Server screen being reachable from the Messaging list; confirm it is, or drop the action and keep the words.
