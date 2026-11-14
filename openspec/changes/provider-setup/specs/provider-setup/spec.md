# Spec Delta

## Purpose

Let a person make a Hermes profile able to chat from the app: see which model providers it has, connect one with an API key, a provider account or a custom endpoint, choose the default model, and remove credentials, without ever keeping or exposing a key on the device.

## ADDED Requirements

### Requirement: Model providers entry points

The app SHALL offer a Model providers screen for one profile, reached from the chat sidebar and drawer ("Model providers", placed before "Helper models") for the chat's profile, and on macOS also from the Profiles page ("Model providers" section, detail "<N> connected") for the selected profile.

#### Scenario: From the drawer

- **GIVEN** the chat's profile is "work"
- **WHEN** the person taps "Model providers" in the drawer
- **THEN** the screen opens for "work"

#### Scenario: From the Mac Profiles page

- **GIVEN** "home" is selected on the Profiles page and has two connected providers
- **WHEN** the page shows its sections
- **THEN** a "Model providers" section reads "2 connected" and opens the screen for "home"

### Requirement: Model providers screen content

The screen SHALL show, in this order, the profile's default model, the connected providers and "Add a provider", with a subtitle naming the profile and the connected count. Each connected provider SHALL state how it is connected ("API key ending in <last four>", "Signed in", "Custom endpoint") and "Default" when it serves the default model.

#### Scenario: Profile with two providers

- **GIVEN** "work" has an OpenRouter key ending in "4f2a" and a Nous Portal sign-in, and OpenRouter serves its default model
- **WHEN** the screen loads
- **THEN** it reads "Model providers", subtitle "work · 2 connected", then the default model, OpenRouter ("API key ending in 4f2a", "Default"), Nous Portal ("Signed in"), and "Add a provider"

#### Scenario: Nothing connected

- **GIVEN** the profile has no provider
- **WHEN** the screen loads
- **THEN** it shows "No model provider yet", "Keys you add here are used by the <profile> profile only." and "Add a provider", with no default-model row

#### Scenario: Loading

- **WHEN** the screen waits for its first answer
- **THEN** it shows placeholder rows labelled "Loading providers" and no empty-state text

### Requirement: Model providers layout

From 900 points wide, and on a full-screen iPad, the list SHALL sit beside the selected provider's detail. Narrower, a provider SHALL open its detail as a page. Forms SHALL open as sheets on phones and as dialogs on iPad, desktop width and macOS, never as a bottom sheet on macOS.

#### Scenario: Wide Mac window

- **GIVEN** a Mac window 1,000 points wide with two connected providers
- **WHEN** the screen opens
- **THEN** the list and the first provider's detail are side by side

#### Scenario: Phone

- **WHEN** the person taps a provider on an iPhone
- **THEN** its detail opens as a page

### Requirement: Reading provider state

The screen SHALL read `GET /api/model/options?include_unconfigured=true`, `GET /api/env`, `GET /api/providers/oauth` and `GET /api/providers/custom-endpoints` for the profile in parallel and parse each answer leniently, skipping rows that do not fit. Rows for the `moa` virtual provider and the managed local runtime SHALL NOT be listed.

#### Scenario: Malformed row

- **WHEN** one provider row lacks a slug
- **THEN** that row is skipped and the others are listed

### Requirement: Partial and full failure

A failure of `GET /api/model/options` SHALL fail the screen with "Couldn't load providers" and "Try again". A failure of another source SHALL hide only what it supplies, with a note on the affected section; a 404 from it SHALL hide its part without any error.

#### Scenario: Model options fail

- **WHEN** `GET /api/model/options` answers 500
- **THEN** the screen shows "Couldn't load providers" with "Try again"

#### Scenario: Account list fails

- **WHEN** `GET /api/providers/oauth` times out and the other sources answer
- **THEN** connected and API-key providers are listed, account sign-in is not offered, and the section notes "Account sign-in isn't available right now"

#### Scenario: Endpoints unsupported

- **WHEN** `GET /api/providers/custom-endpoints` answers 404
- **THEN** the "Custom endpoint" entry is absent and no error is shown

#### Scenario: Offline

- **WHEN** the server cannot be reached
- **THEN** the screen shows "Can't reach your Hermes server" with "Try again" and keeps any list it already showed

### Requirement: Old server

The Model providers entries SHALL be shown only while the chat's model discovery is supported, meaning its `GET /api/model/options` did not answer 404. On a server where it answers 404, the composer's "Set up a model" SHALL keep showing the server command.

#### Scenario: Server without model options

- **GIVEN** a server whose `GET /api/model/options` answers 404
- **WHEN** the person opens the chat sidebar
- **THEN** there is no "Model providers" entry and no error

### Requirement: API key form

For a provider that takes an API key, the app SHALL offer a form with one field "API key", the link "Get a key from <provider>" when Hermes gives an `https` address for it, and Save. Save SHALL trim the key and refuse an empty one. A saved key SHALL be replaceable with the same form, titled "Replace key", which never shows the old key.

#### Scenario: Empty key

- **WHEN** the person taps Save with only spaces in the field
- **THEN** nothing is sent and the field says "Paste the key first"

### Requirement: Checking a key before saving

Before saving, the app SHALL check the key with `POST /api/providers/validate` (6 second budget) and then save it with `PUT /api/env` under the provider's key variable for the profile, with `provider_setup: true`. A rejected key (`ok: false`, `reachable: true`) SHALL NOT be saved unless the person chooses "Save anyway". Any other check result, a timeout or a failed check SHALL save the key and say what was or was not checked.

#### Scenario: Valid key

- **GIVEN** the profile has no provider
- **WHEN** the person pastes an OpenRouter key, taps Save, and Hermes accepts it
- **THEN** `PUT /api/env` sends `OPENROUTER_API_KEY` for the profile, the form closes and the default-model step opens

#### Scenario: Rejected key

- **WHEN** Hermes' check answers "That API key was rejected. Double-check it and try again."
- **THEN** nothing is saved, the message is shown under the field, and "Save anyway" saves the key without another check

#### Scenario: Provider without a check

- **WHEN** Hermes answers `ok: true, reachable: false`
- **THEN** the key is saved and the confirmation reads "Saved. Hermes can't check keys for <provider> ahead of time; your first chat will tell."

#### Scenario: Check cannot reach the provider

- **WHEN** the check times out or answers `reachable: false` with `ok: false`
- **THEN** the key is saved and the confirmation reads "Saved, but Hermes couldn't reach <provider> to check it."

### Requirement: Key save failures

A refusal of `PUT /api/env` SHALL show Hermes' reason and SHALL NOT be retried automatically. A save whose answer is lost SHALL NOT be resent; the app SHALL read the providers again and show either the provider as connected or "Couldn't tell whether the key was saved. Check the list, then try again."

#### Scenario: Locked key

- **WHEN** `PUT /api/env` answers 400 because an administrator manages the key
- **THEN** Hermes' reason is shown and the key is not resent

#### Scenario: Save answer lost

- **WHEN** the connection drops after `PUT /api/env` was sent
- **THEN** the app reads the providers again instead of resending, and reports what it finds

### Requirement: Account sign-in

For a provider listed with `flow: device_code` in `GET /api/providers/oauth`, the app SHALL start the sign-in with `POST /api/providers/oauth/{id}/start` for the profile, show the code with Copy and "Open <provider>", which opens the provider's verification address in the browser. A start refused by Hermes SHALL show Hermes' sentence with "Check again".

#### Scenario: Code shown

- **WHEN** the person taps "Sign in" on ChatGPT and the start answers a code
- **THEN** the code is shown with Copy and "Open ChatGPT"

#### Scenario: Start refused

- **WHEN** the start answers 400 with Hermes' sentence that Nous Portal is already signed in
- **THEN** the sentence is shown with "Check again" and no code

### Requirement: Following a sign-in

The app SHALL poll `GET /api/providers/oauth/{id}/poll/{session}` at the server's interval, kept between 2 and 10 seconds, and at once when the app returns to the foreground. Failed polls SHALL back off and show "Can't reach your server. Still waiting…" without ending the sign-in. Leaving the sign-in page or the app SHALL NOT cancel it; the provider row SHALL read "Waiting for sign-in…" with Continue and Cancel while the screen exists.

#### Scenario: Leaving and coming back

- **GIVEN** a pending ChatGPT sign-in
- **WHEN** the person approves it in the browser and returns to the app
- **THEN** the app polls at once and shows the provider signed in without another tap

#### Scenario: Server unreachable while waiting

- **WHEN** two polls in a row fail
- **THEN** the step shows "Can't reach your server. Still waiting…" and keeps the code

### Requirement: Ending a sign-in

A sign-in SHALL end on `approved` (read the providers again and open the default-model step), `denied` ("The sign-in was declined."), `expired`, a 404 or the code's lifetime plus 30 seconds ("The code expired. Start again."), and `error` (Hermes' message, else "Sign-in failed."). Cancel SHALL send `DELETE /api/providers/oauth/sessions/{session}`.

#### Scenario: Approved

- **WHEN** a poll answers `approved`
- **THEN** the provider shows "Signed in" and the default-model step opens

#### Scenario: Cancelled

- **WHEN** the person taps Cancel on a pending sign-in
- **THEN** the session is cancelled on the server and the provider is listed under "Add a provider" again

#### Scenario: Server restarted

- **WHEN** a poll answers 404
- **THEN** the sign-in ends with "The code expired. Start again."

### Requirement: Providers set up on the server

For an account provider Hermes does not sign in from the dashboard (`flow: external`), and for any connection type the app does not know, the app SHALL show "Connect <provider> on your server" with the command Hermes gives, selectable and with Copy, and "Check again", which reads the providers again. The app SHALL NOT start such a sign-in itself.

#### Scenario: Anthropic account

- **WHEN** the person picks "Use an Anthropic account instead"
- **THEN** the app shows the command Hermes lists and "Check again", and starts nothing

### Requirement: Custom endpoint form

The app SHALL let the person add an OpenAI-compatible endpoint with Name, Address and an optional API key, and under Advanced an API type (Automatic, Chat Completions, Responses, Anthropic Messages) and a model typed by hand. The form SHALL say that Hermes connects to the address from the server, so "localhost" means the server.

#### Scenario: Advanced closed by default

- **WHEN** the form opens
- **THEN** only Name, Address, API key and "Check connection" are visible, with Advanced collapsed

### Requirement: Checking a custom endpoint

"Check connection" SHALL send `POST /api/providers/custom-endpoints/validate` and show the models found as a menu with the first selected, Hermes' warning when it answers `ok: false, reachable: true`, or "Hermes couldn't reach <address> from your server." When Hermes resolved a different address, the form SHALL say "Hermes will use <address>".

#### Scenario: Local server with models

- **WHEN** the person checks "http://localhost:8000" and Hermes answers two models and the resolved address "http://localhost:8000/v1"
- **THEN** both models are offered with the first selected and the form says "Hermes will use http://localhost:8000/v1"

#### Scenario: Endpoint lists no models

- **WHEN** Hermes answers `ok: false, reachable: true` with a message
- **THEN** the message is shown, Advanced opens with the Model field focused, and Save is enabled once a model is typed

### Requirement: Saving a custom endpoint

Save SHALL send `POST /api/providers/custom-endpoints` for the profile with the resolved address, the models found and `make_default` when the profile has no usable default model. An edit SHALL send the API key only when the person changed the key field, and clearing a saved key SHALL ask first.

#### Scenario: Edit without touching the key

- **GIVEN** an endpoint with a saved key
- **WHEN** the person changes only its name and saves
- **THEN** the request carries no API key and the saved key stays

### Requirement: Default model after connecting

After a provider connects, the app SHALL ask `GET /api/model/recommended-default` for it. When the profile had no usable default, the app SHALL save the recommended model at once and say "New chats use <model>" with Change. Otherwise it SHALL ask "Use <model> for new chats?" with "Choose another model…" and "Keep <current model>", and save nothing until the person chooses.

#### Scenario: First provider

- **GIVEN** a profile with no usable model
- **WHEN** an OpenRouter key is saved and Hermes recommends a model
- **THEN** that model is saved as the default and the step reads "New chats use <model>"

#### Scenario: Second provider

- **GIVEN** a profile whose default is served by OpenRouter
- **WHEN** Nous Portal is signed in
- **THEN** the step offers Nous' recommended model and "Keep <current model>"

#### Scenario: Models still loading

- **WHEN** the new provider lists no models yet
- **THEN** the step shows the recommended model alone with "Hermes is still loading this provider's models" and Retry

### Requirement: Saving the default model

The default model SHALL be saved with `POST /api/model/set` (`scope: main`) for the profile. When Hermes answers `confirm_required`, the app SHALL show its message with "Use it anyway" and Cancel and resend with `confirm_expensive_model` only after "Use it anyway". The screen's default-model row SHALL open the shared model picker over all connected providers, without reasoning effort.

#### Scenario: Expensive model

- **WHEN** `POST /api/model/set` answers `confirm_required` with a message
- **THEN** the message is shown and the default changes only after "Use it anyway"

### Requirement: Removing credentials

A provider's detail SHALL offer the removal that fits its credential: "Remove key" (`DELETE /api/env`), "Sign out" (`DELETE /api/providers/oauth/{id}`), "Delete endpoint" (`DELETE /api/providers/custom-endpoints/{id}`), and "Remove saved key ending in <last four>" for each further key Hermes holds (`DELETE /api/credentials/pool/{provider}/{index}`). A sign-in Hermes cannot remove SHALL show Hermes' hint or command instead.

#### Scenario: Not removable here

- **WHEN** an account's sign-in has `disconnectable: false`
- **THEN** the detail shows Hermes' hint or the server command, and no Sign out button

### Requirement: Confirming a removal

Each removal SHALL ask first, naming the provider and the profile, with the destructive button in red and Cancel as the default. When the provider serves the default model, the question SHALL add "New chats in <profile> can't start until you pick another model."

#### Scenario: Remove the default provider's key

- **GIVEN** OpenRouter serves the default model of "work"
- **WHEN** the person taps Remove key
- **THEN** the question names OpenRouter and "work", warns that new chats can't start until another model is picked, and Cancel changes nothing

### Requirement: After a removal

After a removal the app SHALL read the providers again. When the provider is still connected through another credential, the detail SHALL say "Still connected through <N> other saved credentials" and list them. A 404 SHALL count as already removed; a lost answer SHALL be re-read, never resent.

#### Scenario: Still connected

- **WHEN** the OpenAI key is removed but a manually added OpenAI key remains
- **THEN** the detail says "Still connected through 1 other saved credential" and offers "Remove saved key ending in <last four>"

#### Scenario: Already gone

- **WHEN** `DELETE /api/env` answers 404
- **THEN** the key is treated as removed and the list is read again

### Requirement: First run from the chat

When the chat's profile has no usable model (discovery succeeds with no usable provider), the welcome view SHALL replace its starter prompts with "Connect a model to start chatting", "Your Hermes server has no model provider for <profile> yet." and the button "Connect a model", which opens Model providers for that profile at "Add a provider". The composer's "Set up a model" SHALL open the same.

#### Scenario: Fresh server

- **GIVEN** a freshly installed Hermes with no provider
- **WHEN** the person signs in and opens a new chat
- **THEN** the welcome view shows "Connect a model to start chatting" and sending is disabled

### Requirement: Pickers stay consistent

When a provider is connected or removed, or when the default model changes, and when the Model providers screen closes, the chat SHALL read its model options again, so the composer pill, the welcome view and sending update without a restart. Helper models and the Profiles screen SHALL read their options when opened.

#### Scenario: Back from setup

- **WHEN** the person connects a provider and closes Model providers
- **THEN** the welcome view shows the starter prompts, the composer pill shows the default model, and sending is enabled

### Requirement: Key entry

A key SHALL be typed into an obscured field with Show and Hide, with autocorrect, suggestions, keyboard learning, smart punctuation and autofill off. A shown key SHALL be hidden again whenever the app leaves the foreground, so the app switcher never shows it. The field SHALL be cleared after a successful save and when the form closes.

#### Scenario: App switcher

- **GIVEN** the person tapped Show on a typed key
- **WHEN** they open the app switcher
- **THEN** the field is obscured before the system takes its snapshot

#### Scenario: Copying the key from another app

- **GIVEN** a partly typed key
- **WHEN** the person switches to the browser and back
- **THEN** the typed key is still in the field, obscured

### Requirement: Keys are never kept or shown

A typed key SHALL exist only in its field and in the request that sends it. It SHALL NOT be written to preferences, secure storage, the surface snapshot, notifications, widgets, Spotlight, logs, spans, breadcrumbs or error text, and request bodies carrying it SHALL NOT be recorded. A saved key SHALL be shown only by its last four characters; the app SHALL NOT read or show a full saved key and SHALL NOT call `POST /api/env/reveal`.

#### Scenario: Telemetry on

- **GIVEN** telemetry is enabled
- **WHEN** a key is checked, saved and removed
- **THEN** no span attribute, log record or breadcrumb contains the key or its last four characters

#### Scenario: Short saved key

- **WHEN** Hermes shows a saved key as `«redacted:***»`
- **THEN** the row reads "API key saved" with no characters of it

### Requirement: Device codes

The device code of a sign-in SHALL be shown and copyable, and SHALL NOT be logged or kept after the sign-in ends.

#### Scenario: Sign-in ends

- **WHEN** a sign-in is approved
- **THEN** the code is no longer held by the app

### Requirement: Profile scope

Every read and write SHALL carry the profile the screen was opened for, and none on a server without profiles. Answers for a profile the screen no longer shows SHALL be dropped. Changing the chat's profile SHALL NOT change the profile of an open screen. A sign-in SHALL keep following the profile it was started for.

#### Scenario: Profile switch on the Mac Profiles page

- **GIVEN** the providers of "work" are loading
- **WHEN** the person selects "home"
- **THEN** "work"'s answer is dropped and "home"'s providers are shown

### Requirement: App Lock and sign-out

While App Lock covers the app the screen SHALL be hidden like every other screen and a pending sign-in SHALL keep polling. Sign-out and a change of server SHALL close the screen, drop typed keys and stop following sign-ins without cancelling them.

#### Scenario: Sign-out during a sign-in

- **WHEN** the person signs out while a sign-in waits
- **THEN** the screen closes, nothing is kept on the device, and no further request is sent for that sign-in

### Requirement: Touch targets and contrast

Every control SHALL be at least 44 by 44 points on Apple platforms and 48 by 48 dp on Android, and text SHALL meet WCAG AA contrast in both themes. Connection state SHALL be stated in words, never by colour alone.

#### Scenario: Default provider in dark mode

- **WHEN** the list is shown in dark mode
- **THEN** "Default" is a word next to the provider, not only a coloured mark

### Requirement: Screen reader and text size

Screen readers SHALL read a provider row as "<provider>, <state>" and a device code character by character, and SHALL announce "Checking key", "Waiting for sign-in" and the code's arrival once. Text SHALL scale to the largest accessibility size without cutting off a provider name, state or code. Motion SHALL follow reduced-motion.

#### Scenario: Largest text size

- **GIVEN** the largest accessibility text size on an iPhone
- **WHEN** the sign-in step shows an eight-character code
- **THEN** the code is fully visible, wrapped in its groups, and Copy stays reachable

#### Scenario: VoiceOver row

- **WHEN** VoiceOver focuses the OpenRouter row
- **THEN** it reads "OpenRouter, API key ending in 4 f 2 a, default model"

### Requirement: Provider setup backend contract

The feature SHALL rely only on the REST routes design.md lists (`/api/model/*`, `/api/env`, `/api/providers/*`, `/api/credentials/pool`), verified at Hermes `d923a5eb` (0.22.2) and all without response schemas. It SHALL NOT use `/api/env/reveal`, `POST /api/credentials/pool`, or the gateway methods `model.save_key`, `model.disconnect`, `setup.*`, `onboarding.*` or `free_tier.*`.

#### Scenario: Contract test

- **GIVEN** `HERMES_DEV_URL` points at a throwaway backend
- **WHEN** the real-backend contract test runs
- **THEN** it reads the five list routes and both validate routes and checks the fields this spec relies on

### Requirement: Provider setup telemetry

The feature SHALL record the spans `providers.load`, `providers.key.save`, `providers.signin`, `providers.endpoint.check`, `providers.endpoint.save`, `providers.remove` and `providers.default_model.set`, the logs `providers.connected` and `providers.read_failed`, and the breadcrumbs `providers.opened`, `providers.connect.started` and `providers.remove.confirmed`, with only fixed attributes, counts and outcomes.

#### Scenario: Connection counted

- **WHEN** the first provider of a profile is connected with an API key
- **THEN** `providers.connected` is logged with `method: key` and `first: true` and nothing else

#### Scenario: No content in telemetry

- **WHEN** any of these signals is recorded
- **THEN** it holds no key, code, provider or endpoint name, address, model id, profile name or Hermes message text
