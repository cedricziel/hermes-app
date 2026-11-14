# Design brief: Model providers (`provider-setup`)

The spec is `openspec/changes/provider-setup/` (proposal, design, `specs/provider-setup/spec.md`). This brief is for the Claude Design pass in the "Hermes App" design system, before the Widgetbook use cases. Copy below is final unless the design pass finds a clearer word; keep sentence case, plain words, no server jargon (`.env`, `slug`, `OAuth`, `device code`, `api_mode`) unless the person typed it.

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
2. Section "Default model": one row, title = model id, meta = provider name, chevron. Footer: "Used for new chats in <profile>. A chat can still pick another model." Hidden when nothing is connected.
3. Section "Connected": a row per provider. Title = provider name. Subtitle = how: "API key ending in 4f2a", "API key saved" (no characters known), "Signed in" (+ " as <email>" when Hermes reports one), "Custom endpoint · <host>", "Waiting for sign-in…" (with a small progress indicator in the trailing slot). Meta = "Default" when it serves the default model. Warning line when Hermes reports one ("Rate limited until 14:20", "Missing usable credentials"). Chevron.
4. Section "Add a provider": first a "Recommended" group (Nous Portal, OpenRouter, OpenAI, Anthropic, those not yet connected), then "More providers" (alphabetical), then a last row "Custom endpoint" with subtitle "Any OpenAI-compatible server, like vLLM, llama.cpp or Ollama". Each provider row's subtitle says how it connects: "API key", "Sign in with your account", "Set up on your server". A search field appears above the list when there are more than 12 entries ("Search providers").
5. Footer under everything: "Keys and sign-ins are saved on your Hermes server for the <profile> profile only. They are never stored on this device."

**States:**

| State                            | What shows                                                                                                                                                                                                                                   |
| -------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Loading                          | Bar with title; 4 placeholder rows (skeleton) in "Connected" style; accessibility label "Loading providers".                                                                                                                                 |
| Nothing connected                | `StateMessage` at top: title "No model provider yet", body "Connect one so <profile> can answer. Keys you add here are used by the <profile> profile only." Then "Add a provider" directly below (no button needed, the list is the action). |
| Normal                           | As above.                                                                                                                                                                                                                                    |
| Partial failure                  | The failed part shows an inline warning row in its section: "Account sign-in isn't available right now." / "Saved keys couldn't be read. You can still add a key." / "Custom endpoints couldn't be read." with "Try again".                  |
| Full failure                     | `StateMessage`: "Couldn't load providers", body: Hermes' short reason if it is one of ours, else "Something went wrong on your Hermes server.", button "Try again".                                                                          |
| Offline                          | `StateMessage`: "Can't reach your Hermes server", body "Check your connection or VPN, then try again.", button "Try again". Keeps the last list visible above it when it had one (stale banner "Showing what was last loaded").              |
| Old server / section unsupported | Section simply absent. No message.                                                                                                                                                                                                           |
| Restart required (503)           | Warning row at top: "Your Hermes server was updated and needs a restart before models can change."                                                                                                                                           |

**Platform differences:**

- iPhone: pushed page from the drawer; inset grouped list; pull to refresh.
- Android: Material 3 top app bar, list with dividers; pull to refresh.
- iPad full screen / desktop width ≥ 900 pt: list (360 pt) beside the detail (Screen 2); first connected provider selected; selection highlighted.
- Mac: reached from the sidebar and from Profiles > "Model providers"; Mac toolbar with back, title, "Add Provider" button; list beside detail from 560 pt content width; rows 28 pt high in the list with hover; no pull to refresh (⌘R refreshes).

## Screen 2: Provider detail

**Purpose:** see how this provider is connected and change or remove it.

**Hierarchy:**

1. Header: provider name (large title on iPhone), state line ("Connected with an API key", "Signed in as ada@example.com", "Custom endpoint", "Not connected").
2. If it serves the default model: info row "New chats in <profile> use <model>" with "Change".
3. Section "Credentials": one row per credential: "API key ending in 4f2a" (action "Replace key"), "Signed in · <source label>", "Saved key ending in 7890 · added on the server" (pool entries). For an endpoint: Address, API type, Models (count, expandable list), API key ("Saved" / "None").
4. Section "Models": count and the first five ids, "Show all" (read-only; picking happens in the default-model row).
5. Destructive section at the bottom, red text rows: "Remove key", "Sign out", "Delete endpoint", "Remove saved key ending in 7890". When Hermes cannot remove a sign-in: no button; a footer "Hermes can't remove this sign-in from the app. Run this on your server:" + selectable command + Copy.
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
| Saving                | "Saving…"                                                                                                                                                                       |
| Saved, checked        | Sheet closes into the default-model step.                                                                                                                                       |
| Saved, unchecked      | Default-model step shows a note at top: "Saved. Hermes can't check keys for <provider> ahead of time; your first chat will tell."                                               |
| Saved, couldn't reach | Note: "Saved, but Hermes couldn't reach <provider> to check it."                                                                                                                |
| Refused               | Inline error with Hermes' reason (e.g. the administrator lock); Save stays enabled for another key.                                                                             |
| Unknown outcome       | "Couldn't tell whether the key was saved. Check the list, then try again." and the list re-reads behind it.                                                                     |

**Keyboard and secrets:** no autocorrect, no suggestions, no autofill, password keyboard on Android; Return = Save on desktop; Escape = Cancel. The eye toggle flips back to hidden when the app leaves the foreground. Never show the key in any other place (no confirmation that repeats it).

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

**End states:** Approved → closes into the default-model step with "Signed in to <provider>" announced. Denied → "The sign-in was declined." + "Try again". Expired → "The code expired." + "Start again". Error → Hermes' message or "Sign-in failed." + "Try again". Start refused → Hermes' sentence + "Check again" (no code shown).

**Leaving:** closing the sheet with a pending sign-in does not cancel it; the list row shows "Waiting for sign-in…" with "Continue" (reopens this step) and "Cancel" (asks: "Stop signing in to <provider>?" / "Stop" / "Keep waiting").

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
4. API key (optional, obscured, eye toggle; helper "Leave empty if the server needs none."). In edit mode the field shows "Saved key" as placeholder and stays empty; typing replaces it; a "Remove saved key" text button asks first.
5. Button "Check connection" (secondary, full width on phones).
6. Result block: models found → "Found 3 models" + a picker row "Model" (first selected); warning → amber warning row with Hermes' message; unreachable → red row "Hermes couldn't reach <address> from your server."; resolved address differs → info row "Hermes will use <resolved address>".
7. "Advanced" disclosure (`disclosure_tile.dart`), closed by default: "API type" (Automatic, Chat Completions, Responses, Anthropic Messages; footer "Automatic works for most servers. Pick another if chats fail with a 404.") and "Model" (text, for servers that list none).
8. Switch row "Use for new chats" shown only when the profile already has a default (else it becomes the default automatically, footer says so).

Save enabled when Name, Address and a model (found or typed) are present. Saving shows "Saving…"; errors inline with Hermes' message ("Address must start with http:// or https://" is our own sentence for "base_url must include scheme and host").

## Screen 7: Default-model step

**Purpose:** confirm which model new chats use, without making the person understand model ids.

**First provider (no default before):** title "You're ready", body "New chats in <profile> use <model> from <provider>." Buttons: "Start chatting" (primary; closes everything and returns to the chat when it came from the chat, else to the list) and "Change model" (secondary; opens the picker limited to this provider).

**Later provider:** title "Use <model> for new chats?" body "<provider> recommends it. You're using <current model> now." Buttons: "Use <model>" (primary), "Keep <current model>" (secondary), "Choose another model…" (text).

**Still loading:** the model line plus "Hermes is still loading this provider's models." with "Retry".

**Expensive confirmation:** alert, title "This model is expensive", body Hermes' message as given, actions "Use it anyway" (default style, not destructive) and "Cancel" (default).

## Screen 8: Removal alerts

| Action             | Title                              | Body                                                                                                                                | Destructive button                |
| ------------------ | ---------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- | --------------------------------- |
| Remove key         | "Remove the <provider> key?"       | "<profile> can no longer use <provider> models." + when default: "New chats in <profile> can't start until you pick another model." | "Remove Key" (Mac) / "Remove key" |
| Sign out           | "Sign out of <provider>?"          | same pattern                                                                                                                        | "Sign Out" / "Sign out"           |
| Delete endpoint    | "Delete <name>?"                   | "Its saved key is deleted too." + default warning                                                                                   | "Delete"                          |
| Remove pool key    | "Remove saved key ending in 7890?" | "Hermes stops using this key for <provider>."                                                                                       | "Remove"                          |
| Clear endpoint key | "Remove the saved key for <name>?" | "Hermes will connect without a key."                                                                                                | "Remove"                          |
| Cancel sign-in     | "Stop signing in to <provider>?"   | "The code stops working."                                                                                                           | "Stop"                            |

Cancel is the default and first-reachable on every alert; the destructive action is red and never the default (Return does not trigger it on Mac).

## Screen 9: Welcome card (chat)

**Purpose:** turn "this server can't answer" into one tap.

Replaces the starter prompts on the chat's welcome view when the profile has no usable model. Card: icon (`tune` or a plug), title "Connect a model to start chatting", body "Your Hermes server has no model provider for <profile> yet.", primary button "Connect a model". The composer stays visible but its send button is disabled, and its pill reads "Set up a model" (unchanged) and opens the same screen. On a Mac or wide window the card is centred in the welcome area at max 420 pt wide; on phones it sits where the prompts were.

After setup the card disappears without animation when reduced motion is on, with a short fade otherwise, and the starter prompts appear.

## Accessibility (all screens)

- Targets: 44 × 44 pt (Apple), 48 × 48 dp (Android), including the eye button, Copy and the disclosure.
- Row labels: "<provider>, <state>[, default model]"; last-four characters read separately ("ending in 4 f 2 a"). The code reads character by character, grouped ("W D J B, M J H T").
- Announcements: "Checking key", "Key saved", "Waiting for sign-in", "Code ready" (once), "Signed in to <provider>", failures.
- Largest accessibility text: rows wrap to as many lines as needed, the code wraps by group, buttons stack vertically in forms and steps.
- Contrast: WCAG AA in both themes; warning amber and error red pass on the grouped background; "Default" and every state is a word, never only a dot or colour.
- Reduced motion: no countdown animation, no spinner bouncing; a static "Waiting…" is acceptable with the progress semantics.
- Focus order: title, explanation, primary field, primary action, secondary actions, Cancel. On Mac and desktop, Tab moves through fields; Return submits when the primary button is enabled; Escape cancels.

## Privacy reminders for the design

- No mock or screenshot may contain a real-looking full key; examples show only "ending in 4f2a".
- The key field is obscured in every frame of every use case, except the one "shown" state, which uses an obviously fake key (`test-key-not-real`).
- Nothing about keys appears in notifications, widgets or the app switcher; no design should propose a "key saved" notification.
