# Proposal

## Why

A Hermes server with no model provider cannot answer a single message, and today the app can only say so: the composer's pill reads "Set up a model" and opens a dialog that tells the person to run `hermes model` in a terminal on the server. Someone who installed Hermes on a home server and set up the app on their phone has to find a shell before the app is useful. Hermes' dashboard already has every route needed to connect a provider (an API key, a provider account sign-in with a device code, or an OpenAI-compatible endpoint), check it, pick the default model and remove a credential, so the app can do the whole job itself (roadmap item 4.1).

## What Changes

- A new **Model providers** screen per profile, reached from the chat sidebar (next to Helper models) and as a section of the Mac Profiles page. It shows, first, the profile's **default model** (changeable with the existing model picker), then **Connected** providers, then **Add a provider**.
- **Connect with an API key**: a form with one obscured key field, a link to where the provider issues keys, and Save. Hermes checks the key first where it can (OpenRouter, OpenAI, xAI, Gemini); a rejected key, or a provider that answers with an error, is shown with Hermes' message and "Save anyway"; a key Hermes cannot check is saved with a note. The key is saved to the profile's `.env` on the server through `PUT /api/env`.
- **Sign in with a provider account** (the providers Hermes offers a device-code sign-in for: Nous Portal, ChatGPT/Codex subscription, MiniMax, xAI Grok): the app starts the sign-in on the server, shows the code and opens the provider's page, and follows the sign-in until Hermes reports it approved, denied or expired. It keeps following it while the person is elsewhere in the providers screen or in another app (the browser); closing the providers screen stops following without cancelling, and Hermes completes an approval on its own. Account providers Hermes only supports from its own terminal (Anthropic account, Qwen CLI, GitHub Copilot) show the command to run on the server.
- **Custom endpoint**: name, address, optional key, and under Advanced the API type and a model typed by hand. "Check connection" asks Hermes to reach the endpoint from the server and lists its models; Save adds it, and can make it the default.
- **After connecting**, the app proposes the provider's recommended default model (Hermes' own choice) in a confirm step; the person keeps it, picks another, or keeps the current default.
- **Remove**: Remove key, Sign out of an account, Delete endpoint; each asks first, says what stops working (in red when it is the default model's provider), and the list is read again afterwards.
- **First run**: when the profile has no usable model, the chat's welcome view shows "Connect a model to start chatting" with one button (or "Reconnect your model's provider" when the configured provider lost its key, or "Hermes is loading your models" while a connected provider's list warms up), and the composer's "Set up a model" pill opens the same flow instead of the terminal dialog.
- After any change the chat's model list, the composer pill and Helper models read their options again, so every picker agrees with the screen.

Non-goals:

- Revealing a saved key (`POST /api/env/reveal`). A saved key is shown only as its last four characters and can be replaced, never displayed. See design.md.
- Several keys per provider (the credential pool's rotation, `POST /api/credentials/pool`). The pool is read only to explain why a provider stays connected after its key was removed, and its entries can be removed.
- Arbitrary `.env` variables, provider base-URL overrides (`*_BASE_URL`), regions and other per-provider advanced variables. The dashboard's Keys page remains the place for them.
- Local models (`/api/local-models/*`) and the desktop's first-run onboarding (`onboarding.*`), which Hermes only runs on its desktop app's own backend.
- The Nous free tier (`free_tier.*`): Hermes only offers it on the desktop app's local backend.
- Gateway equivalents of the REST routes (`model.save_key`, `model.disconnect`, `model.options`, `setup.status`, `setup.runtime_check`, `reload.env`); the app uses REST throughout (see design.md).
- Changing which model a running chat uses. Provider changes apply to new chats, as the per-chat model pick already does.

## Capabilities

### New Capabilities

- `provider-setup`: seeing a profile's providers and default model, connecting a provider by API key, account sign-in or custom endpoint, checking a credential, choosing the default model after connecting, removing credentials, the first-run path from the chat, and how secrets are handled on the device.

### Modified Capabilities

None. `messenger-navigation` already requires that "Set up a model" opens "model/provider setup or actionable setup guidance"; this change supplies the setup it refers to without changing that requirement. Helper models (`model-settings`) keep their behaviour and only re-read their options.

## Impact

- Code: new `lib/src/providers/` (repository, parsers, sealed results, `ProviderSetupController`, sign-in follower, screens) and `lib/src/providers/widgets/` (plain-model widgets); the chat sidebar and drawer (`chat_screen_layout.dart`, `chat_screen_navigation.dart`), the Mac Profiles page (`ProfileSection`), the welcome view and the composer pill's setup action (`chat_thread_bindings.dart`), Widgetbook use cases, a workflow test, and `design/web`.
- Backend: no new route. REST routes already in `openapi/hermes-agent.openapi.json` and the generated client: `GET /api/model/options`, `GET /api/model/recommended-default`, `POST /api/model/set`, `GET|PUT|DELETE /api/env`, `POST /api/providers/validate`, `GET /api/providers/oauth`, `POST /api/providers/oauth/{id}/start`, `GET /api/providers/oauth/{id}/poll/{session}`, `DELETE /api/providers/oauth/sessions/{session}`, `DELETE /api/providers/oauth/{id}`, `GET|POST /api/providers/custom-endpoints`, `POST /api/providers/custom-endpoints/validate`, `POST /api/providers/custom-endpoints/{id}/activate`, `DELETE /api/providers/custom-endpoints/{id}`, `GET /api/credentials/pool`, `DELETE /api/credentials/pool/{provider}/{index}`. None has a response schema, so every answer is parsed leniently. Verified against Hermes `d923a5eb` (0.22.2), the revision `openapi/HERMES_REF` pins; no regeneration is needed.
- Delivery: six PRs (see tasks.md).
- Security and privacy: the app handles provider API keys for the first time. A key lives only in the text field's controller and the one request that sends it; it is never stored on the device, logged, put in telemetry, breadcrumbs or exception text, shown in a notification, widget or the surface snapshot, and the field is obscured again whenever the app goes inactive, so the app switcher's snapshot never shows it. Saved keys are shown only as their last four characters. The device code of an account sign-in is shown on screen (that is its purpose) but never logged. Every write names its profile explicitly. Request logging must not record request bodies for these routes (checked by a test).
- Observability: spans `providers.load` (`sources_ok`, `sources_failed`, `connected` count bucket), `providers.key.save` (`checked`: `accepted` | `rejected` | `unchecked`, `outcome`), `providers.signin` (`outcome`: `approved` | `denied` | `expired` | `cancelled` | `failed`), `providers.endpoint.check` (`outcome`, `models` bucket), `providers.endpoint.save` (`outcome`, `made_default`), `providers.remove` (`kind`, `outcome`), `providers.default_model.set` (`outcome`, `confirm_asked`), each crossing the network with `hermes.*` attributes; log events `providers.connected` (`method`: `key` | `account` | `endpoint`, `first`: whether the profile had no usable model before) and `providers.read_failed` (`source`, `error_type`) to count setup success and contract drift; breadcrumbs `providers.opened` (`source`: `sidebar` | `profiles_page` | `composer` | `welcome`), `providers.connect.started` (`method`) and `providers.remove.confirmed` (`kind`). None carries a key, code, provider or endpoint name, URL, model id or profile name.
