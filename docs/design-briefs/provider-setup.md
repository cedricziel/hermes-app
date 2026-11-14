# Design brief: Model providers (`provider-setup`)

The spec is `openspec/changes/provider-setup/` (proposal, design, `specs/provider-setup/spec.md`). This brief is for the Claude Design pass in the "Hermes App" design system, before the Widgetbook use cases. Copy below is final unless the design pass finds a clearer word; keep sentence case, plain words, no server jargon (`.env`, `slug`, `OAuth`, `device code`, `api_mode`) unless the person typed it.

## Design (done)

Claude Design canvas "Hermes: Provider setup", built on the Hermes App design system: https://claude.ai/artifact/VQKYB7YsncdJkQgmWTmHkY (private; ask its owner for access). 66 artboards in nine rows: the list on iPhone (two connected, nothing connected, loading, partial failure, couldn't load, offline with the last list kept, restart required, dark, largest text, sign-in pending); iPad full screen, Mac window, Android, the key form as a Mac dialog and as an Android full-screen dialog; the provider detail (API key with default model, account, custom endpoint, still connected through a hand-added key, sign-in Hermes can't remove, dark); the key form (empty, shown with a fake key, empty save, checking, rejected, provider error, refused, outcome unknown for a first key and for a replacement, dark); the sign-in step (waiting, Nous with the code in the link, can't reach the server, declined, expired, failed, start refused, dark, largest text) and "Connect on your server"; the custom endpoint form (new, models found, no models listed, unreachable, edit, an unencrypted address with a key and its confirmation); the default-model step (you're ready, unchecked-key note, later provider, no recommendation, still loading, expensive confirmation); every removal confirmation (iOS, and Android for Remove key); the chat's three welcome cards, dark, Mac, and the failed reply's "Check model providers". Where this brief and the canvas differ, the sections below have been brought in line with the canvas.

Decisions taken in the design pass:

- List: "Add a provider" is a 20 pt heading on the page (15 pt on a Mac) with the search field under it, then the "Recommended" and "More providers" groups. "Custom endpoint" is a group of its own after them, so it is not lost at the end of the alphabet; the privacy note is that group's footer.
- A source that fails shows a warning `Banner` with Try again right above the part it feeds (saved keys above Connected, account sign-in above Recommended). Without saved keys a connected row reads "Connected"; account providers are left out of "Add a provider" while account sign-in is unavailable.
- Offline with a list already shown is a warning `Banner` on top ("Can't reach your Hermes server" / "Showing what was last loaded. Check your connection or VPN.", Try again) and the list stays below. The `StateMessage` is used only when nothing was loaded yet.
- Restart required is a warning `Banner` at the top: "Your Hermes server needs a restart" / "It was updated. Models can't change until it restarts."
- A pending sign-in stays in Connected: subtitle "Waiting for sign-in…", trailing a text "Stop" and an outlined "Continue" (accessibility labels "Cancel sign-in to <provider>" and "Continue sign-in to <provider>"). There is no spinner in the row (the two buttons need the trailing slot and the words carry the state). Stop asks first. On a Mac both are small 28 pt push buttons after the text; at the largest text sizes they drop below the text, full width, Continue first.
- Detail: the bar's title is the provider and its subtitle the profile; the page starts with the status sentence after a success icon ("Connected with an API key"). Then "Default model" (the model, id under it, a text "Change"; footer "New chats in <profile> use this model."), "Credentials" (each row with its own button: "Replace key" outlined), "<N> models" (the first five ids and "Show all <N>"), and the red removal row alone in the last group. An endpoint's Edit is the bar's action; its address is a monospace subtitle so it is never cut at half the row.
- A sign-in Hermes can't remove shows its footer sentence and the command in a monospace box with a text Copy button, and no Sign out row. The same command box serves "Connect on your server".
- Key form: an iOS page sheet with Cancel and Save in the bar. The field row is label, obscured field and a 44 pt eye button, with "<N> characters entered" in muted text under it once something is typed; errors sit under the field in the row, in the error colour with an icon. "Get a key from <provider>" is a row with an open-in-browser icon. While the key is checked, Save becomes a spinner, the field is read-only and a status line under the field reads "Checking key…".
- Rejected key: the bar's Save goes away, so "Edit key" (filled) is the one primary action and "Save anyway" is outlined; editing the key brings Save back. On desktop Return triggers "Edit key". A key saved with "Save anyway" counts as unchecked: the next step shows the "Your first chat will show whether the key works." note, never a plain "You're ready". Provider error: a warning `Banner` with the heading and Hermes' message above the field, "Save anyway" filled and "Try again" outlined, and no bar Save.
- Outcome unknown: a warning `Banner` above an empty field; Save stays disabled until the key is pasted again.
- Sign-in step: "Open <provider>" is the one filled, full-width button; the code is 34 pt monospace semibold in a bordered card with an outlined "Copy code" under it. Failed polls swap the spinner for a warning icon. End states and a refused start use `StateMessage` (icon, sentence, Hermes' message as the detail when there is one, one filled button).
- "Connect on your server": the bar says only the provider and carries "Done"; the long title is the page's heading; "Check again" is the one filled button.
- Endpoint form: Name, Address and API key are three groups, each with its footer; "Check connection" is an outlined full-width button under them; the result is a `Banner` (success "Found 2 models", warning, or error "Couldn't connect") followed, when models were found, by the Model menu and "Hermes will use <address>". "Use for new chats" is a switch row in its own group with a footer saying what stays when it is off. In edit mode "Remove saved key" is a red row inside the key's group and the footer reads "Type a new key to replace the saved one." An `http://` address that is not local to the Hermes server, with a key typed, shows the warning `Banner` "This address isn't encrypted" / "Your key would be sent to it in plain text."; Save then asks "Send the key unencrypted?" (Cancel default, red "Save anyway").
- Default-model step: a 40 pt icon tile, a 22 pt title, the body in the muted colour, then the buttons stacked full width: filled, outlined, text. With no recommendation "Choose model" opens the picker limited to the provider (no inline list of hundreds of models) and "Not now" is a text button. The unchecked-key note is a success `Banner` above the step ("Saved" / "Your first chat will show whether the key works.").
- Removal alerts: the iOS and Mac alert with Cancel as the bold default and the action in red. On Android the library's Material alert fills its default button, which would make Cancel look primary, so both are text buttons and the removal is red text.
- Welcome card: a bordered surface card (no shadow) with a 36 pt icon tile, title, body and a full-width filled button, under the existing welcome tile and "Where should we begin?". Icons: `tune` (Connect), `key` (Reconnect), `hourglass_empty` (Loading). A failed reply shows the error as an error `Banner` and an outlined "Check model providers" under it.

- Mac exception, accepted at review: steps and forms (sign-in, default-model step, rejected key) put their buttons as small 28 pt push buttons aligned to the right, the primary one last, as a Mac dialog does, instead of the full-width stack of the other platforms; "Copy code" is right-aligned the same way.

Corrections where this brief did not work:

- "Waiting for sign-in…" cannot carry both a progress indicator and two buttons in the trailing slot; the row keeps the two buttons and drops the indicator.
- "Any OpenAI-compatible server, like vLLM, llama.cpp or Ollama" is cut off as a one-line row subtitle on a phone; the subtitle is now "vLLM, llama.cpp, Ollama and more".
- Offline: a `StateMessage` under a list reads as a second page; with a list, the message is a banner above it (see Decisions).
- The default-model step's no-recommendation case opens the picker instead of listing the provider's models inline.

Copy added by the design: "Your Hermes server needs a restart" / "It was updated. Models can't change until it restarts." (restart banner), "Stop" (pending row button), "<N> characters entered" (under every secret field), "This address isn't encrypted" / "Your key would be sent to it in plain text." (endpoint banner) and "Send the key unencrypted?" with "Save anyway" (its confirmation), "Use this model?" (expensive confirmation title), "Connected" (connected row subtitle when keys can't be read), "Nous Portal account" and "ChatGPT subscription" (credential row subtitles), "Added on the server" (hand-added key subtitle), "Couldn't connect" (unreachable banner title, the brief's sentence is its detail), "Connected, but no models listed" (warning banner title when Hermes gives no heading), "Type a new key to replace the saved one." (edit footer), "Keeps <current model> for new chats when off. You can change it later." ("Use for new chats" footer), "Saved" (banner title above the unchecked-key note), "The reply failed" (failed reply banner title), "Applies to the <profile> profile only." (server-command footer), "Couldn't start the sign-in" / "Hermes didn't answer. Nothing was started." with "Try again" (a sign-in start that got no answer; the action is offered again).

## Who and what

A person who installed Hermes on their own server opens the app and cannot chat because the server has no model provider. Their job: **get a working model in under a minute, without a terminal**. Later jobs: add a second provider, switch the default model, fix or remove a key. They are often on a phone, holding a key they just copied from a provider's website.

Principles for this feature:

- One obvious primary action per screen.
- The profile a credential belongs to is always visible (keys are per profile on the server).
- A key is never shown again after it is saved; it is identified by its last four characters.
- Anything that removes access asks first and says what stops working.

## Reused kit

`SettingsScaffold` (title, subtitle, bar actions, Mac toolbar), `GroupedListView` / `GroupedSection` / `GroupedRow` (title, meta, subtitle, warning line, chevron, trailing widget), `GroupedTextFieldRow` and `grouped_form.dart` for forms, `GroupedSwitchRow` not needed, `StateMessage` for empty/failure states, `BusyBar` for progress, `showAdaptiveSheet` (bottom sheet on phones, dialog on iPad/desktop and always a dialog on macOS), `showModelPicker` (the existing picker, `withEffort: false`), `ProfileAvatar` for the profile in the subtitle where space allows, `AppIcon` set (`tune`, `power`, `key` if present, else `lock`). Alerts use the platform's alert (`showAdaptiveDialog` / `adaptive_dialog.dart`) with the destructive action styled destructive and Cancel as the default.

## Screen 1: Model providers (list)

**Purpose:** see whether this profile can chat, and with what; get to "add one" fast.

**Hierarchy (top to bottom):**

1. Bar: title "Model providers", subtitle "<profile> · <N> connected" (or "<profile>" when none). No add button in the bar on phones (the "Add a provider" section is on the page); on Mac and desktop width a toolbar button "Add Provider" (title case on Mac menus/toolbars only) that scrolls to and focuses that section.
2. Section "Default model": one row, title = the model's display name (the id when Hermes gives no name), subtitle = the id when it differs, meta = provider name, chevron. Footer: "Used for new chats in <profile>. A chat can still pick another model." Hidden when nothing is connected.
3. Section "Connected": a row per provider. Title = provider name. Subtitle = how: "API key ending in 4f2a", "API key saved" (no characters known), "Signed in" (+ " as <email>" only right after a Nous sign-in, the one case where Hermes reports an email), "Custom endpoint · <host>", "Waiting for sign-in…" (with a text "Stop" and an outlined "Continue" in the trailing slot, no progress indicator). Meta = "Default" when it serves the default model. Warning line when Hermes reports one ("Rate limited until 14:20", "Missing usable credentials"). Chevron.
4. Section "Add a provider": first a "Recommended" group (Nous Portal, OpenRouter, OpenAI, Anthropic, those not yet connected), then "More providers" (alphabetical), then "Custom endpoint" in a group of its own with subtitle "vLLM, llama.cpp, Ollama and more". Each provider row's subtitle says how it connects: "API key", "Sign in with your account", "Set up on your server". A search field appears above the list when there are more than 12 entries ("Search providers").
5. Footer under everything: "Keys and sign-ins are saved on your Hermes server for the <profile> profile only. They are never stored on this device."

**States:**

| State                            | What shows                                                                                                                                                                                                                                                                                                                                  |
| -------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Loading                          | Bar with title; 4 placeholder rows (skeleton) in "Connected" style; accessibility label "Loading providers".                                                                                                                                                                                                                                |
| Nothing connected                | `StateMessage` at top: title "No model provider yet", body "Connect one so <profile> can answer. Keys you add here are used by the <profile> profile only." Then "Add a provider" directly below (no button needed, the list is the action).                                                                                                |
| Normal                           | As above.                                                                                                                                                                                                                                                                                                                                   |
| Partial failure                  | The failed part shows a warning `Banner` with "Try again" right above the part it feeds: "Account sign-in isn't available right now." / "Saved keys couldn't be read. You can still add a key." / "Custom endpoints couldn't be read.". Account providers are left out while account sign-in is unavailable.                                |
| Full failure                     | `StateMessage`: "Couldn't load providers", body: Hermes' short reason if it is one of ours, else "Something went wrong on your Hermes server.", button "Try again".                                                                                                                                                                         |
| Offline                          | With a list already shown: warning banner on top, "Can't reach your Hermes server" / "Showing what was last loaded. Check your connection or VPN." with "Try again", the list below it. With nothing loaded yet: `StateMessage` "Can't reach your Hermes server", body "Check your connection or VPN, then try again.", button "Try again". |
| Old server / section unsupported | Section simply absent. No message.                                                                                                                                                                                                                                                                                                          |
| Restart required (503)           | Warning banner at top: "Your Hermes server needs a restart" / "It was updated. Models can't change until it restarts."                                                                                                                                                                                                                      |

**Platform differences:**

- iPhone: pushed page from the drawer; inset grouped list; pull to refresh.
- Android: Material 3 top app bar, list with dividers; pull to refresh.
- iPad full screen / desktop width ≥ 900 pt: list (360 pt) beside the detail (Screen 2); first connected provider selected; selection highlighted.
- Mac: reached from the sidebar and from Profiles > "Model providers"; Mac toolbar with back, title, "Add Provider" button; list beside detail from 560 pt of content width (`kMacSplitBreakpoint`; the sidebar takes the rest); rows 28 pt high in the list with hover; no pull to refresh (⌘R refreshes).

## Screen 2: Provider detail

**Purpose:** see how this provider is connected and change or remove it.

**Hierarchy:**

1. Bar: provider name as the title, the profile as the subtitle. First line of the page: a success icon and the state sentence ("Connected with an API key", "Signed in as ada@example.com", "Custom endpoint", "Not connected").
2. If it serves the default model: section "Default model", one row with the model and its id and a text "Change"; footer "New chats in <profile> use this model."
3. Section "Credentials": one row per credential: "API key ending in 4f2a" (action "Replace key"), "Signed in" (never Hermes' source label, which can be a file path on the server), "Saved key ending in 7890" with the subtitle "Added on the server" (only keys added by hand on the server; sign-in tokens are never listed as keys). For an endpoint: Address, API type, Models (count, expandable list), API key ("Saved" / "None").
4. Section "Models": count and the first five ids, "Show all" (read-only; picking happens in the default-model row).
5. Destructive section at the bottom, red text rows: "Remove key", "Sign out", "Delete endpoint". Keys added by hand on the server are listed in Credentials read-only with the footer "Manage this key on your server with `hermes auth`." (no button: Hermes can only remove them by position, which is not safe from the app). When Hermes cannot remove a sign-in: no button; a footer "Hermes can't remove this sign-in from the app. Run this on your server:" + selectable command + Copy.
6. "Still connected" note when a removal left other credentials: "Still connected through 1 other saved credential." above the list of them.

**Primary action:** none forced; "Replace key" / "Edit endpoint" is the main one, Remove is last and red.

**Platform differences:** phone pushes a page; wide layouts show it in the right pane with the same sections; Mac uses the inspector-like pane with section headers in small caps per the Mac grouped style, buttons as push buttons, destructive as a red text button.

## Screen 3: Connect with an API key (form)

**Purpose:** paste a key and be done.

**Hierarchy:**

1. Title "Connect <provider>" (or "Replace key" for an existing one). Cancel (leading) and Save (trailing, bold; disabled until the field has text).
2. One field, label "API key", placeholder "Paste your key", obscured, trailing eye button ("Show key" / "Hide key").
3. Helper text under the field: "Saved on your Hermes server for <profile>. You won't see it again here."
4. Link row: "Get a key from <provider>" (opens the provider's page in the browser), only when Hermes gives one.
5. Under Advanced? No. There is nothing advanced here.
6. A secondary text link at the bottom for providers that also have an account option: "Use an <provider> account instead".

**States and copy:**

| State                 | What shows                                                                                                                                                                      |
| --------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Empty Save attempt    | Field error "Paste the key first".                                                                                                                                              |
| Checking              | Save becomes a progress indicator with "Checking key…"; field read-only.                                                                                                        |
| Rejected              | Field error (Hermes' message, e.g. "That API key was rejected. Double-check it and try again."); buttons "Edit key" (primary, focuses the field) and "Save anyway" (secondary). |
| Provider error        | Heading "<provider> didn't answer normally", Hermes' message ("Provider returned HTTP 503 for this key."); buttons "Save anyway" (primary) and "Try again" (secondary).         |
| Saving                | "Saving…"                                                                                                                                                                       |
| Saved, checked        | Sheet closes into the default-model step.                                                                                                                                       |
| Saved, unchecked      | Default-model step shows a note at top: "Saved. Your first chat will show whether the key works."                                                                               |
| Saved, couldn't reach | Note: "Saved, but Hermes couldn't reach <provider> to check it."                                                                                                                |
| Refused               | Inline error with Hermes' reason (e.g. the administrator lock); Save stays enabled for another key.                                                                             |
| Unknown outcome       | First key and replacement alike: "Couldn't tell whether the key was saved. Paste it again to be sure." The field is cleared and the list re-reads behind it.                    |

**Keyboard and secrets:** no autocorrect, no suggestions, no autofill, password keyboard on Android; Return = Save on desktop; Escape = Cancel. Secret fields follow the app-wide rule in `docs/architecture/settings-screens.md` ("Secret fields"): obscured by default, Show/Hide labelled "Show key" / "Hide key", a muted "<N> characters entered" line under the field, hidden again when the app goes inactive, when a check or save starts, after a failed save and when the form closes; the typed key stays through the background and a plain failed save, and is cleared on App Lock, when the form closes and after a lost answer. Never show the key in any other place (no confirmation that repeats it).

**Platform differences:** iPhone: a page sheet (large detent) with the keyboard up at once; Android: full-screen dialog style sheet; iPad/desktop: a 480 pt dialog; Mac: a sheet-style dialog attached to the window, Save as the default button.

## Screen 4: Sign in with an account

**Purpose:** approve Hermes on the provider's website.

**Hierarchy:**

1. Title "Sign in to <provider>". Cancel (leading).
2. Step text: "1. Open <provider> and sign in." Button "Open <provider>" (primary, filled).
3. "2. Enter this code if asked:" then the code, large monospace, grouped as given (e.g. `WDJB-MJHT`), with "Copy code" (copies; the button reads "Copied" for 2 s, announced). Nous' link already includes the code: then the line reads "Check that this code matches:".
4. Status line with a small spinner: "Waiting for you to approve…" ; after failed polls: "Can't reach your server. Still waiting…".
5. Footer: "The code expires in 14 minutes." (counts down per minute, not per second; no ticking motion).
6. Note for the profile: "Signs <profile> in. Other profiles stay as they are."

**End states:** Approved → closes into the default-model step with "Signed in to <provider>" announced. Denied → "The sign-in was declined." + "Start again". Expired → "The code expired." + "Start again". Error → Hermes' message or "Sign-in failed." + "Start again". Start refused → Hermes' sentence + "Check again" (no code shown).

**Leaving:** closing the sheet with a pending sign-in does not cancel it; the list row shows "Waiting for sign-in…" with "Continue" (reopens this step) and "Stop" (asks: "Stop signing in to <provider>?" / "Stop" / "Keep waiting").

**Platform differences:** iPhone: "Open" goes to Safari (not an in-app browser, so password managers and existing sessions work); returning to the app re-checks at once. Mac: dialog; the code is selectable; ⌘C copies it when focused. iPad: dialog.

## Screen 5: Set up on your server

**Purpose:** say honestly that the app cannot do this one, and how to do it.

Title "Connect <provider> on your server". Body: "<provider> is connected from Hermes' own command line. Run this on the computer running Hermes, then check again:" Then the command in a monospace selectable block with "Copy". Primary button "Check again"; secondary "Done". No illustration.

## Screen 6: Custom endpoint (form)

**Purpose:** point Hermes at a model server the person already runs.

**Hierarchy:**

1. Title "Add custom endpoint" / "Edit <name>". Cancel and Save.
2. Name (placeholder "My GPU box"; helper "Shown in the model picker").
3. Address (placeholder "https://example.com/v1"; helper "Hermes connects to this address from your server, so localhost means the server itself."). URL keyboard.
4. API key (optional, obscured, eye toggle; helper "Leave empty if the server needs none."). In edit mode the field shows "Saved key" as placeholder and stays empty; typing replaces it; a red "Remove saved key" row in the same group asks first, and the footer reads "Type a new key to replace the saved one." A non-local `http://` address with a key typed shows a warning `Banner` "This address isn't encrypted" / "Your key would be sent to it in plain text.", and Save asks "Send the key unencrypted?" (Cancel default, red "Save anyway"). "Local" means local to the Hermes server (the app's `isLocalHost` rule applied to the address's host), since the server makes the call.
5. Button "Check connection" (secondary, full width on phones).
6. Result block: models found → "Found 3 models" + a picker row "Model" (first selected); warning → warning `Banner` with Hermes' message (title "Connected, but no models listed" when Hermes gives none); unreachable → error `Banner` "Couldn't connect" / "Hermes couldn't reach <address> from your server."; resolved address differs → info row "Hermes will use <resolved address>".
7. "Advanced" disclosure (`disclosure_tile.dart`), closed by default: "API type" (Automatic, Chat Completions, Responses, Anthropic Messages; footer "Automatic works for most servers. Pick another if chats fail with a 404.") and "Model" (text, for servers that list none).
8. Switch row "Use for new chats" shown only when the profile already has a default (else it becomes the default automatically, footer says so).

Save enabled when Name, Address and a model (found or typed) are present. Saving shows "Saving…"; errors inline with Hermes' message ("Address must start with http:// or https://" is our own sentence for "base_url must include scheme and host").

## Screen 7: Default-model step

**Purpose:** confirm which model new chats use, without making the person understand model ids.

**First provider, no recommendation:** when Hermes recommends no model, nothing is saved: title "Choose a model for new chats", body "<provider> is connected. Pick the model new chats in <profile> should use.", "Choose model" (primary) opening the picker limited to this provider, and "Not now" (secondary; the chat then shows the composer pill's "Choose a model"). "You're ready" appears only after a default is saved.

**First provider (no default before, recommendation saved):** title "You're ready", body "New chats in <profile> use <model> from <provider>." Buttons: "Start chatting" (primary; closes everything and returns to the chat when it came from the chat, else to the list) and "Change model" (secondary; opens the picker limited to this provider).

**After a Nous sign-in that moved the default:** when the profile's default after the sign-in is not empty and differs from the one before it (Hermes moves it off the free tier's model by itself), show "You're ready" with that model and "Change model". When Hermes cleared it (no default after the sign-in), show the no-recommendation state above. When it is unchanged, show the later-provider step below.

**Later provider:** title "Use <model> for new chats?" body "<provider> recommends it. You're using <current model> now." Buttons: "Use <model>" (primary), "Keep <current model>" (secondary), "Choose another model…" (text).

**Still loading:** the model line plus "Hermes is still loading this provider's models." with "Retry".

**Expensive confirmation:** alert, title "Use this model?", body Hermes' message as given, actions "Use it anyway" (default style, not destructive) and "Cancel" (default).

## Screen 8: Removal alerts

| Action             | Title                              | Body                                                                                                                                | Destructive button                |
| ------------------ | ---------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- | --------------------------------- |
| Remove key         | "Remove the <provider> key?"       | "<profile> can no longer use <provider> models." + when default: "New chats in <profile> can't start until you pick another model." | "Remove Key" (Mac) / "Remove key" |
| Sign out           | "Sign out of <provider>?"          | same pattern                                                                                                                        | "Sign Out" / "Sign out"           |
| Delete endpoint    | "Delete <name>?"                   | "Its saved key is deleted too." + default warning                                                                                   | "Delete"                          |
| Clear endpoint key | "Remove the saved key for <name>?" | "Hermes will connect without a key."                                                                                                | "Remove"                          |
| Cancel sign-in     | "Stop signing in to <provider>?"   | "The code stops working."                                                                                                           | "Stop"                            |

Cancel is the default and first-reachable on every alert; the destructive action is red and never the default (Return does not trigger it on Mac).

## Screen 9: Welcome card (chat)

**Purpose:** turn "this server can't answer" into one tap.

Replaces the starter prompts on the chat's welcome view when the profile has no usable model. Three variants, one at a time:

- Reconnect (the configured provider lost its key): title "Reconnect your model's provider", body "New chats in <profile> use <model>, but its provider's key is missing or no longer works.", primary "Reconnect" (opens that provider's detail).
- Loading (a provider is connected but its model list is not ready): title "Hermes is loading your models", body "A provider is connected, but its model list isn't ready yet.", primary "Check again". No connect button.
- Connect (nothing connected), described next.

A failed reply whose error comes from the provider (bad key, no credit) gets the secondary action "Check model providers" under the error, opening the default model's provider.

Connect card: icon (`tune` or a plug), title "Connect a model to start chatting", body "Your Hermes server has no model provider for <profile> yet.", primary button "Connect a model". The composer stays visible but its send button is disabled, and its pill reads "Set up a model" (unchanged) and opens the same screen. On a Mac or wide window the card is centred in the welcome area at max 420 pt wide; on phones it sits where the prompts were.

After setup the card disappears without animation when reduced motion is on, with a short fade otherwise, and the starter prompts appear.

## Accessibility (all screens)

- Targets: 44 × 44 pt on iOS and iPadOS, 48 × 48 dp on Android, including the eye button, Copy and the disclosure. macOS follows the Mac's own sizes (28 pt list rows, regular push buttons) with full keyboard access instead.
- Row labels: "<provider>, <state>[, default model]"; last-four characters read separately ("ending in 4 f 2 a"). The code reads character by character, grouped ("W D J B, M J H T").
- Announcements: "Checking key", "Key saved", "Waiting for sign-in", "Code ready" (once), "Signed in to <provider>", failures.
- Largest accessibility text: rows wrap to as many lines as needed and "Default" gets its own line; credential rows put their button ("Replace key") below the text; the pending row's Continue and Stop drop below its text, full width; the code wraps by group; buttons stack vertically, full width, in forms and steps.
- Labels for the pending row's buttons: "Continue sign-in to <provider>" and "Cancel sign-in to <provider>".
- Contrast: WCAG AA in both themes; warning amber and error red pass on the grouped background; "Default" and every state is a word, never only a dot or colour.
- Reduced motion: no countdown animation, no spinner bouncing; a static "Waiting…" is acceptable with the progress semantics.
- Focus order: title, explanation, primary field, primary action, secondary actions, Cancel. On Mac and desktop, Tab moves through fields; Return submits when the primary button is enabled; Escape cancels.

## Privacy reminders for the design

- No mock or screenshot may contain a real-looking full key; examples show only "ending in 4f2a".
- The key field is obscured in every frame of every use case, except the one "shown" state, which uses an obviously fake key (`test-key-not-real`).
- Links Hermes sends (key page, sign-in page, docs) are opened only when they are `https` (or `http` to a local address); otherwise the button is not drawn, so designs must work without it.
- Nothing about keys appears in notifications, widgets or the app switcher; no design should propose a "key saved" notification.
