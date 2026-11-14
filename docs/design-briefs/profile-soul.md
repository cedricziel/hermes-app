# Design brief: Personality (a profile's SOUL.md)

Change: `openspec/changes/profile-soul/`. Read its design.md for the server facts and the save and conflict rules; this brief is the visual and copy pass.

Status: Design: brief reviewed, canvas pending (publish quota, resumes after 2026-11-15 00:00 UTC)

## Design

The pass was written from the Hermes App design system README, the shared widgets under `lib/src/widgets/`, the Tools and Server care briefs and the change's own design.md. A Claude Design canvas was started and is incomplete (private, partly published: https://claude.ai/artifact/P2oqCBdLmdviWpGWmZmRjB). It is not finished and is not the record; this brief is. Local canvas renders settled the findings folded in below. No build starts before the canvas exists; when it is done, bring it and this brief in line.

Screens and states decided (all in light and dark, phone and desktop width, largest text, German):

- Personality screen: loading, loaded, file not set yet, empty file, text with a note at 20,000 characters and beyond, offline, failed to read, profile gone, old server, unsaved changes, saving, saved, couldn't confirm the save, checking, check failed, nothing sent because the check failed, wide layout, Mac Profiles section.
- Save question, Discard question, "Changed on the server" sheet (with and without the server's text opened).
- Entry rows: Personality after Memory in the sidebar drawer and More section, and in the Mac Profiles section list.

Decisions, one line each:

- Wording: "Personality" everywhere; the footnote under the editor says "This is the SOUL.md file Hermes reads for this profile." and is the only place the file name appears.
- One screen, one editor. The text field fills the page under a short header; the editor area is a filled field (surface-high token) while editable and transparent while read-only (saving, checking). The design-system card border is about 1.2:1 against the page in both themes, too weak to mark a field, so the fill carries it; there is no preview, no Markdown toolbar and no separate read mode.
- Save is a text action in the bar on phones (iOS and Material), disabled while the text equals the baseline. There is no filled button on the phone page: the keyboard covers anything pinned to the bottom, and a bar action stays reachable. Revert is a quiet text button on its own row under the count line; its label aligns to the leading text edge of the note and status lines above it (the button's inner padding is cancelled so the glyphs line up, and the 44 pt / 48 dp target extends past the text). Save and Revert are always visible and disabled while clean, never hidden.
- One page shape on every platform: a pushed page with the settings bar (back, title, subtitle), as Skills and Memory. On the Mac the Profiles section row pushes it; the editor is not a detail pane beside the profile list, so the list is not visible while the page is open. The renders drew it that way and the page needs the width.
- On the Mac and at desktop width (900 pt and up), the bar carries no Save: Save (filled) and Revert (outlined) sit together under the editor on the trailing side, since there is no keyboard to cover them. File > Save (⌘S) is the Mac's other way in.
- Material draws the same grouped-card editor as iOS: the filled field (surface-high), the count and the quiet Revert text button; it does not switch to a Material outlined or filled `TextField`. Only the bar (56 dp), the dialogs and the 48 dp targets are Material.
- Revert asks the same "Discard changes?" question as leaving; it never discards silently.
- The count reads "1,240 characters" with the locale's grouping, under the editor's trailing edge, announced politely after typing stops (not per key).
- The 20,000-character note is an info line under the count with an icon, not a banner: "Hermes may shorten text this long when it builds a chat. The limit depends on your server's settings." It appears at 20,000 and stays; nothing locks at any length. The proposal's "too long to edit" state does not exist (see "Corrections").
- File not set yet and empty file look the same (empty editor, hint text) and differ only by one info line: an empty file adds "Hermes uses its default personality while this is empty." A missing file shows "No personality set yet." Saving either creates or replaces the file.
- While saving or checking, the editor is read-only and Save shows a spinner in place of its label. Edits cannot race the baseline.
- The save question is the platform alert: Cancel first and default, Replace plain (never filled, never red). Material: two text buttons, Cancel first; the design-system AlertDialog draws the default action filled on Material and is never used with a filled default (in the app, `showConfirmDialog(cancelIsDefault: true)` is the call). The title names the profile; a 64-character name wraps.
- "Changed on the server" is a sheet (a dialog on a Mac and wide windows, through `showAdaptiveSheet`), not an alert, because it can hold the server's text. The server's version is closed behind a "Show server's version" disclosure row; opened, it is a selectable, read-only text box (capped at 40% of the height, scrolls) with a Copy button. Keep editing is the filled, default button; Replace anyway is a plain text button under it.
- A lost answer is a warning banner above the editor ("Couldn't confirm the save") with a Check action. At the largest text size and in German the banner's action stacks under the text (the design-system Banner squeezes the text into a narrow column); `AppBanner` in the app must do the same, with the text at full width. The stacked action aligns to the text's leading edge, not 12 px to the right of it as the design-system text button drew it (cancel its inner padding; the target still extends past the text). Every banner action (Check, Check again, Try again) has a minimum target of 44 pt on touch, 48 dp on Android and 28 pt on a Mac, set by construction in `AppBanner` (a minimum size on the button), not by eye; the design-system Banner draws about 24 px and gives no such guarantee. The text stays in the editor. Saved is never shown while it is unconfirmed. The bar's Save stays enabled and asks again before any new request.
- Check running: the banner swaps its action for a spinner and "Checking…". It ends within 10 s with "Couldn't confirm" and Check again. Nothing is resent.
- Check outcomes are compared with the text that was sent, not the editor (the user may have kept typing in the lost-answer state): equal to the sent text is "Saved" (success line) only when the file exists (`exists: true`) and its content equals the sent text, so a missing file never confirms a save, even when both texts are empty; then the baseline moves to it and later edits stay dirty. Equal to the old baseline (same existence and content) is "The server still has the earlier text. Your text is still here." with Save as the bar action. This is not a definite failure: the route has no write precondition, so a timed-out PUT may still land later and replace newer text. The next Save therefore asks the Save question again with one extra line, "An earlier save may still be pending on the server.", and the usual check read runs before any PUT; anything else opens the "Changed on the server" sheet. This splits design.md's "otherwise the conflict question" in two (see "Corrections").
- Both requests of a save are bounded: the check read and the PUT each give up after 10 s (a controller-level timeout, as `kFilesAnswerTimeout` does in the Files controller). A timed-out check read is "Couldn't check the server first, so nothing was sent."; a timed-out PUT is the lost-answer state.
- Before sending, if the server's text already equals the text about to be sent (an earlier unconfirmed save did land), the screen reports Saved, moves the baseline and sends nothing.
- App Lock while a check or PUT is in flight: the request finishes, its outcome is discarded, and after the unlock the screen reloads the server's text.
- Errors never show the response body. Fixed lines per case: read failed, save failed (400, 422, 500), offline, nothing sent because the check failed.
- Leaving with unsaved changes asks "Discard changes?" with Keep editing as default. On the Mac the same question is asked on the bar's back and on closing the window (the page is pushed, so there is no profile or section change beside it while it is open).
- Unsaved text is dropped on sign-out, server change and App Lock (spec), at once: there is no grace period and nothing is kept in memory while locked (owner decision). After an unlock the screen reloads from the server and says nothing about the lost edits beyond what the lock screen already shows.
- Text input is plain: no autocorrect, suggestions, smart quotes or dashes, no autofill, no keyboard learning on Android, no spell-check squiggles, no restoration id. The font is the body font at the user's text size, not monospace.
- The profile is bound to the screen when it opens; the title names it ("Personality", subtitle "work"). A chat-profile switch behind it changes nothing.

Copy added by the design (English; German in the ARB, see "German"):

- Title "Personality"; subtitle "<profile>"; sidebar and Mac row label "Personality".
- Footnote "This is the SOUL.md file Hermes reads for this profile. It tells Hermes who it is and how to talk." (one sentence in the German too; the file name is a literal). "SOUL.md" appears nowhere else (owner decision).
- Hint text "Describe who Hermes is and how it should talk."
- "No personality set yet." and "Hermes uses its default personality while this is empty."
- "<N> characters" / "1 character".
- Note: "Hermes may shorten text this long when it builds a chat. The limit depends on your server's settings."
- Save question: title "Replace the personality of <profile>?", body "New chats use it. Chats already running usually keep the old one; Bot Chats may pick it up.", buttons "Cancel", "Replace". Empty text body: "Hermes will use its default personality. Chats already running usually keep the old one; Bot Chats may pick it up."
- Discard question: title "Discard changes?", body "Your edits to the personality of <profile> haven't been saved.", buttons "Keep editing", "Discard".
- Changed sheet: title "Changed on the server", body "This file changed since you opened it. Replacing it will lose those changes.", rows "Show server's version", "Copy", buttons "Keep editing", "Replace anyway". If the server's file is now gone: "The file was removed on the server." and the server's version reads "No personality set."
- Saved line "Saved. New chats use it." Not-saved line "The server still has the earlier text. Your text is still here."
- Lost answer banner: title "Couldn't confirm the save", detail "It may have gone through. Your text is still here.", action "Check". Checking: "Checking…". After 10 s: title "Couldn't confirm" with action "Check again".
- Errors: "Couldn't read the personality file on the server." (read failed); the save error banner has title "Couldn't save" and detail "Hermes reported a problem. Nothing was changed on the server." (400, 422, 500); "Couldn't check the server first, so nothing was sent." with Try again (the second read failed), and offline "You're offline." with "Couldn't load the personality." on load.
- Profile gone: `StateMessage` "This profile no longer exists." detail "It may have been deleted on the server." no action.
- Old server: `StateMessage` "This server doesn't offer personality settings." detail "Updating Hermes on the server adds them." outlined Back.

New components needed, each a plain-model widget in `lib/src/profiles/soul/widgets/` with Widgetbook use cases:

| Widget             | What it is                                                                   | Closest existing                                                                            |
| ------------------ | ---------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| `SoulEditor`       | multiline field with hint, read-only mode, count line and the notes under it | `GroupedTextFieldRow` (one line only); `SecretFieldRow` shares its input-hardening settings |
| `SoulStatusLine`   | one line under the count: saved, not saved, error, with icon and words       | the row error/warning line of `GroupedRow`; `AppBanner` for the bigger states               |
| `SoulChangedSheet` | the "Changed on the server" body: text, disclosure, copy, two buttons        | `ToolsetConfirmDialog` and `showAdaptiveSheet`                                              |
| `SoulSaveActions`  | Save and Revert as bar actions (phone) or buttons (wide)                     | `NamedIconButton`, `toolsButtonStyle`                                                       |

The canvas has none of these four in the design system, so they are drawn as one-off boards. Also missing from the design system and needed for the canvas: a Banner with a stacked action (text at full width, action below at the largest text size and in German), a Mac Profiles page Personality row (the design-system `MacProfilesPage` has a fixed section list), and Memory among the More entries (the Personality row sits after it). The sidebar icon is Material `face` in the canvas.

Design-system gaps found by the renders (the canvas works around each; the app does not inherit them):

- `ThreadSidebar` draws no More section unless `device="touch"` is passed; the design-system prompt omits this, and the Main and E02 boards pass it.
- `MacProfilesPage` has a fixed section list with neither Memory nor Personality; M01 is hand-built from the same classes.
- `Banner` has no stacked-action mode, and its text button keeps inner padding that shifts a stacked action about 12 px right of the text edge (boards G02, X02).
- `Banner` actions draw about 24 px high and carry no minimum target size.
- `AppLockScreen` shows "Hermes is locked" and Unlock only; it cannot show that edits are gone, which is right (the spec shows nothing).

The save and discard questions use `showConfirmDialog` with `cancelIsDefault: true` and `filled: false`; no new widget. The banner is `AppBanner` (warning, error, neutral). Missing, gone and old-server states are `StateMessage`. A new icon is needed for the entry rows: add `AppIcons.personality` (Material `face_outlined`, Cupertino `person_crop_circle`).

Corrections where the earlier documents did not work:

- The proposal's design list names a "too long to edit" state; design.md and the "Size guidance" requirement say the editor never locks. The brief follows the spec: no such state. The proposal line is corrected in the same PR.
- design.md says a Check that finds different text shows the conflict question. If the server's text equals the baseline the save simply never landed, and "This file changed since you opened it" would be false. The brief splits it (see the decisions). The spec's scenarios still hold; the extra branch is added to design.md.
- The proposal's Save-question variant "with the chat-already-running note" is removed: the note is in every body, so the variants are normal and empty text.

## Local render review

The canvas (https://claude.ai/artifact/P2oqCBdLmdviWpGWmZmRjB, private and partly published) holds 60 boards in light and dark: the Personality page in every state (P01-P18), the Save, Discard and Changed questions (Q01-Q09), dark and largest-text (D, X), the banner states (G), Android (A01-A07), wide layouts (W) and the Mac (M01-M09), plus the sidebar entry (Main, E02). The full 60-board canvas is staged locally and publishes after the quota resets on 2026-11-15; until then this brief is the record. The boards were rendered in a local headless Chrome and the findings above came from those renders.

Not checked: nothing was looked at in the claude.ai viewer; control sizes and contrast were judged by eye (no DOM measurement, no ratios); the editor is static text, so real keyboard and text-input behaviour, the sheet's slide, spinner animation, reduced motion, VoiceOver and TalkBack are untested; the largest text was rendered on iPhone only (X01-X03), German on iPhone, Mac and the Android save question only, with no largest-text board on Android or wide layouts; the published canvas state was not read back. X01 clips a line at the bottom edge because it mocks a scrolling field, not a defect.

## Who and why

Someone who runs Hermes for themselves or a few people and wants the agent to sound a certain way: terser, in German, in character for a bot, or just with a name. Today that means the dashboard in a browser or a shell. They come to this screen with a phone in hand, change a few sentences, save, and open a new chat to see it. They may know it as "the soul file"; most will not.

Two facts the design must not blur:

- **Only new chats use the change.** A chat that is already running keeps the old text. The screen says so before the save, not after.
- **Saving replaces the whole file.** There is no history and no undo in the app. The question before Save and the check before sending exist because of this.

## Shared kit

`SettingsScaffold` (iOS 44 pt bar, `MacToolbar`, Material 56 dp), `GroupedListView` and `GroupedSection` for the page chrome and the footnote, `ContentColumn` (editor width cap), `AppBanner` (lost answer, errors, offline), `StateMessage` (profile gone, old server), `LoadingSkeleton` or a centred spinner (loading), `showConfirmDialog` (save and discard questions), `AdaptiveSheet` (changed on the server), `DisclosureTile` ("Show server's version"), `NamedIconButton` and `toolsButtonStyle` (actions and targets), `DestructiveTintButton` is not used (nothing here is deleted), `CommandRow` is not used. `SecretFieldRow` is not used (the text is not a secret field: it is shown, and not masked), but the editor copies its input hardening. Chrome must be indistinguishable from Memory and Skills.

## Navigation

- iPhone: sidebar drawer, Personality row right after Memory (same row look and `AppIcons` pattern, no count). It pushes the screen; Back returns to the chat; leaving with unsaved changes asks first. The More section on a phone holds the same row for the chat's profile.
- Android: the same; the system back gesture and the bar's back button both go through the Discard question when dirty. Material bar and dialogs.
- iPad and wide windows (900 pt and up): the screen is pushed into the content column, not a two-pane; the editor follows the grouped list's width (about 600 pt on a Mac, 640 pt on an iPad), not 720, and is centred; Save and Revert sit under it.
- Mac: Personality is a section row after Memory in the Profiles page's section list for the selected profile, with the detail line "Who Hermes is and how it talks" (German draft: "Wer Hermes ist und wie es spricht"), as the other `ProfileSection`s have one. The row pushes the page (see the decisions): `MacToolbar` with back, title and subtitle, the editor, the count and notes, then Save (filled) and Revert (outlined) under it. Back or closing the window while dirty asks "Discard changes?". The proposal adds no Mac sidebar row; the Profiles page is the Mac entry. The Personality page offers a File > Save command (`MacCommand.save`, ⌘S, a new entry in `menuLayout`) through its `MacCommandScope`; it opens the Save question and is disabled while clean or busy. View > Back (⌘[) comes from the scaffold as on other pages; no key handler is added for either chord.
- Windows and Linux: as Mac for pointer sizes, as iPad for navigation.

## Screen: Personality

Purpose: read what the profile's SOUL.md says and change it safely.

Order, top to bottom:

1. Bar: back, title "Personality", subtitle "<profile>", Save (text action).
2. Banner area (only when a state needs one): lost answer, error or offline.
3. Editor, filling the height down to the keyboard, with the hint when empty.
4. Count line and note line, then the status line (Saved / Not saved).
5. Revert (quiet text button on its own row, label aligned to the note and status text) on the phone; on wide layouts and the Mac, Save and Revert under the editor instead.
6. Footnote "This is the SOUL.md file Hermes reads for this profile…" in a grouped footer.

The one primary action is Save. Revert is secondary, always visible and disabled while clean. Nothing here is destructive in the sense of a red button: the destructive step is the Replace in the question, which is plain.

States:

- Loading: a centred spinner with "Loading personality…" and the bar; no editor yet. Cancels cleanly on close; a late answer after close is dropped.
- Loaded: editor with the text, count, footnote; Save and Revert disabled.
- File not set yet: empty editor, hint, the line "No personality set yet."
- Empty file: empty editor, hint, the line "Hermes uses its default personality while this is empty."
- Text cleared by the user: the same empty editor and the same default-personality line, live as soon as the editor is empty, also while the Save question is open (the alert sits over it; board Q02 draws it, with "0 characters"). The line is not an error and does not stop Save.
- Long text: the count and, from 20,000, the info line with the note. Still editable and savable at 500,000 and beyond. The editor may be slow at that size; see "Open questions".
- Unsaved changes: Save and Revert enabled; a back or profile change asks to discard.
- Saving: editor read-only, Save shows a spinner, an announcement "Saving". The question has already been answered; the check read and the PUT both run in this state.
- Saved: the status line "Saved. New chats use it." with a check icon; Save and Revert disabled; the baseline is the saved text. The line stays until the next edit.
- Offline on load: `AppBanner` warning "You're offline." "Couldn't load the personality." with Try again; no editor. Offline on Replace: the check read fails, so nothing is sent: error banner "Couldn't check the server first, so nothing was sent." with Try again; the text stays.
- Error on read (500 and others): error banner "Couldn't read the personality file on the server." with Try again; no editor (an empty editor would invite saving over a file the app could not read).
- Error on save (400, 422, 500, or a 200 without `ok: true` is a lost answer, not an error): error banner "Couldn't save. Hermes reported a problem. Nothing was changed on the server." The text stays; Save stays enabled.
- Lost answer: warning banner "Couldn't confirm the save", Check. Checking, then the three outcomes above. A failed Check keeps the banner and says "Couldn't confirm" again after at most 10 s.
- Profile gone (404 "Profile '…'"): `StateMessage`, no editor, no Save, no action (Back is the bar's).
- Old server (route-missing 404 or 405): the row is shown until the first such answer, then hidden for the rest of the connection; the screen that got it shows the neutral `StateMessage` "This server doesn't offer personality settings." with Back.
- 401: the existing sign-in path; the screen shows nothing of its own.
- Changed on the server: the sheet above; nothing is sent until Replace anyway.
- App Lock: see "Privacy".
- Wide layout: editor at the grouped list's width (about 600 pt on a Mac, 640 pt on an iPad), centred; the footnote under it; Save and Revert under the editor on the right, not in the bar on Mac.

Hierarchy at the largest text: the bar title truncates ("Personal…" beside the "Chat" back label) and the profile subtitle stays, wrapping to two lines if needed; the editor keeps at least 12 lines of height without a banner and about 10 with one (the banner takes the difference; the renders showed about 11), and the page scrolls beneath it; the editor itself scrolls, so no text is cut off, only out of view; count, note, status and Revert stack and wrap. Nothing is capped.

## Confirmations and the changed sheet

Save question (platform alert; dialog at wide widths): see the copy above. Cancel is first and default; Replace is plain. Pressing Replace starts the saving state, and the second read happens there. Cancel sends nothing and leaves the text.

Discard question: Keep editing is first and default; Discard is plain, not red and not filled. This is a stated exception to the settled rule: the schedule form and the skill editor (`confirmDiscard` with `destructive: true`) show Discard destructive, and those older screens may follow later. The case for plain: the text is the user's own and nothing is lost on the server. The closest existing analogue to `SoulEditor` is the skill editor's multi-line field. Used for back, Revert, profile or section change on the Mac, and window close.

Changed on the server: a sheet with a drag handle on a phone, a dialog on a Mac and wide windows. Order: title, body, "Show server's version" disclosure row, the Keep editing filled button, the Replace anyway plain button. Opening the disclosure shows the server's text read-only and selectable with Copy under it; Copy puts the text on the clipboard and says "Copied". Dismissing the sheet is Keep editing. Replace anyway sends the PUT once; its result goes through the same states as a normal save (saved, error, lost answer). If a second change appears between the sheet and the PUT, the window stays open (design.md); the screen says nothing about it.

## German

Longer strings and risks: "Persönlichkeit" in the bar and sidebar row (fits, but check the Mac toolbar at 28 pt rows); "Änderungen verwerfen?" and "Weiterbearbeiten" and "Verwerfen" in the Discard question; "Auf dem Server geändert" as a sheet title wraps on a phone; "Trotzdem ersetzen" and "Version des Servers anzeigen" are the longest button and row, so the buttons are full width and the disclosure row wraps; "Die Speicherung konnte nicht bestätigt werden" wraps to three lines in the banner at the largest size; the character count reads "1.240 Zeichen" with the German grouping. The title of the save question carries a profile name of up to 64 characters in a sentence; allow four lines. "SOUL.md" stays a literal. The ARB entries go under `@@x-area-profiles`.

## Accessibility

- Targets: Save, Revert, Check, Check again, Copy, Try again and the disclosure row are at least 44 pt tall on touch, 48 dp on Android and 28 pt on a Mac. Measured by construction (a minimum size on each button, asserted in widget tests with `tester.getSize`), not read off a render.
- The editor has a label "Personality text for <profile>" and a hint; the count is announced politely after typing stops; read-only mode is announced.
- The status is never colour alone: Saved has a check icon and the word, Not saved and the errors have an icon and the sentence, the lost answer has a question-mark icon and "Couldn't confirm".
- Banners are polite live regions (`AppBanner`); "Saving" and "Saved" are announced; the Save action reports itself disabled when clean.
- Focus order: bar action, banner, editor, Revert, footnote. A sheet or alert takes focus and returns it to the control that opened it.
- Reduced motion removes the spinner animation and the sheet's slide; contrast AA in both themes. The text at the largest text size is never cut off in the sheet; it scrolls.

## Privacy

- The text lives only in the screen's state. It is never in preferences, drafts, `restorationId`, logs, spans or breadcrumbs, and the keyboard's learning is off.
- Under App Lock, titles and text are blanked: while locked the screen shows the lock cover, not the editor, and the bar title and profile name are not drawn in the app switcher. After an unlock the state is reloaded from the server; edits that were not saved are gone at once, with no grace period (spec, owner decision).
- No content beyond what a notification body already allows leaves the screen: the server's text in the changed sheet is shown and copyable by the user only.
- The profile name is shown on screen and never logged. Errors show fixed lines, never the response body (it can hold paths).
- Telemetry names are fixed (design.md "Observability").
- Copy puts the user's own text on the clipboard on request only; the app never copies on its own.

## Platform differences

- iPhone: pushed page, bar Save, alert questions, a bottom sheet for the changed state, the keyboard resizes the editor and the page scrolls.
- Android: Material bar, two-text-button dialogs (Cancel first), a Material bottom sheet, back gesture asks to discard.
- iPad and Windows/Linux wide: pushed page with the editor at the list's width and buttons under it; sheets become dialogs.
- Mac: Profiles section row pushes the page with the `MacToolbar` bar, the editor with buttons under it, hover states on buttons, File > Save (⌘S) from the pane's `MacCommandScope`, dialogs not sheets.

## Spec scenario coverage

| Spec requirement and scenario                               | Where the design covers it                                                               |
| ----------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| Backend contract: Another profile                           | Screen title and subtitle carry the bound profile; the path carries its name (tasks 2.2) |
| Backend contract: Old server                                | Old server state: row shown until the first 404, then hidden; neutral `StateMessage` with Back if open |
| Entry points: Phone                                         | Navigation, iPhone and Android; sidebar row after Memory                                 |
| Entry points (Mac Profiles page)                            | Navigation, Mac; section after Memory                                                    |
| Showing the text: File missing versus empty                 | States "File not set yet" and "Empty file"                                               |
| Showing the text: Profile gone                              | State "Profile gone"                                                                     |
| Showing the text (loading, offline, failed)                 | States Loading, Offline on load, Error on read; the last two with Try again                      |
| Editing never saves by itself: Leaving with changes         | Discard question; Keep editing default                                                   |
| Editing never saves by itself (state dropped)               | Privacy; App Lock; sign-out and server change                                            |
| Save is confirmed: Cancel                                   | Save question; Cancel first and default; nothing sent                                    |
| Save is confirmed: Empty text                               | Save question, empty-text body                                                           |
| Changed-on-server check: Someone else saved                 | "Changed on the server" sheet; nothing sent until Replace anyway                         |
| Changed-on-server check: Check fails                        | State "Offline on Replace" / error banner with Try again; text stays                     |
| A lost answer is not a save: Timeout on save                | Lost answer banner with Check; Save asks again                                           |
| A lost answer is not a save: Check finds it saved           | Check outcome "equal to the sent text" shows Saved and moves the baseline                   |
| Size guidance: Long text                                    | Count and info line from 20,000; the editor and Save never lock                          |
| Privacy and observability: Nothing user-written is recorded | Privacy; fixed error lines; names from design.md                                         |

## Open questions for the owner

Decided and removed: App Lock drops unsaved edits at once, with no grace period; "SOUL.md" appears only in the footnote.

1. A very long text (hundreds of thousands of characters) may make a Flutter text field slow. Should the editor degrade (for example, plain scrolling without the count updating per key) past a size, or is that left until it is seen in practice? No limit is added.
2. Should the Mac Profiles page also show a one-line preview of the personality in its section list? The brief says no (it would read the file for every profile and show the user's text in a list); say if it is wanted.
3. Confirm the Mac decision: the Personality row pushes a page with the bar (as Skills do), with no list beside it. A side-by-side detail pane would need the Profiles list kept visible and a Discard question on every profile or section change. The brief chose the pushed page; say if the pane is wanted.
4. `AppIcons.personality` is a new icon pair; confirm `face_outlined` and `person_crop_circle` or name another. The canvas draws Material `face`.
