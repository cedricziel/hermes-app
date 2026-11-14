# Verify Tools

Complete the client-isolation prerequisite in [the shared guide](../SKILL.md)
before launching, and run the app against `scripts/dev-backend.sh`, never the
real `~/.hermes`. Everything below uses a throwaway `HERMES_HOME`
(`.dart_tool/hermes-dev/home`), invented keys and no paid model call. The
routes and answers are in `openspec/changes/toolsets/design.md`.

Read back what the server wrote with the throwaway home's files:

```bash
H="$PWD/.dart_tool/hermes-dev/home"   # profile homes sit under $H/profiles/<name>
grep -n -A12 'platform_toolsets' "$H/config.yaml"
grep -c '' "$H/.env"; cut -d= -f1 "$H/.env"   # key names only; never print values
```

1. **List.** Open the sidebar's More section (phone drawer, iPad and desktop
   sidebar) and choose Tools; on a Mac open the Profiles page, then the Tools
   row. The list groups toolsets under Needs setup, On and Off for the chat's
   profile, and the subtitle reads "profile · N on". Compare N with the
   `platform_toolsets` entry of that profile's `config.yaml`. Create a second
   profile and check that its list differs and that picking it does not change
   the server's active profile.
2. **Switch Web and Terminal.** Switch Web on: no question (unless a provider
   has an install step, then "Install on your server?"). Switch Terminal on:
   the platform alert "Let Hermes run commands?" opens with Cancel and "Switch
   on". While it is open the switch is still off and `config.yaml` is
   unchanged; Cancel sends nothing. Choose "Switch on", then check the row says
   "Applies from your next chat" and `config.yaml` now lists the toolset. Switch
   it off again: no question.
3. **Provider and key.** Open a toolset that needs a key and pick a provider.
   Type an invented key (for example `fc-test-0000000000`); never a real one.
   The field hides it until the eye is tapped, and it hides again after the
   app is backgrounded with the typed text kept. Save, then confirm the key's
   name is in `.env` and its value matches what you typed, and that no screen
   shows the value afterwards. Leaving the field blank saves nothing.
4. **Model.** In a toolset with a model list, open the picker and choose one.
   Read the choice back from `config.yaml`. No model is called.
5. **Terminal backend.** Open the backend list, pick Docker (no Docker needed:
   a backend that needs setup is accepted and shown with the server's note),
   then Local: it asks "Run commands directly on your server?" first and
   changes nothing until confirmed. Read `terminal.backend` back from
   `config.yaml`.
6. **Install step.** Where a provider offers one, start it: "Install on your
   server?" comes first. Follow the progress to done or failure. Do not run an
   installer that downloads software unless the backend is disposable.
7. **Computer use.** The readiness section needs a Linux backend; follow the
   `verify-bot-screen` skill. Check the platform line, driver and checks, no
   permission rows on a non-macOS server, and "Open the bot's screen" only when
   the profile's Bot Screen is offered; it opens the viewer and does nothing
   else.
8. **Old server.** Against a backend without `/api/tools/toolsets` (a Hermes
   from before the routes, or a fake server that answers 404), the sidebar and
   Profiles page show no Tools and no error appears anywhere.
9. **The difference link.** The footers of Tools, Skills, Plugins, MCP servers
   and Helper models end with "What's the difference?"; each opens the same
   sheet with the four terms and Done.

Screenshots (`scripts/dev-app.sh screenshot`): look at the switch rows (state
and saving state readable, risk line on the confirm toolsets), the banners
(offline, could not load, installer started), the confirmation open with the
switch still off, the key field (a key is never visible, not in a screenshot
either), the footer link in the link colour, light and dark, and the largest
text size.

Rules: no paid model call (`HERMES_DEV_MODEL_CALLS` stays unset), no real keys
or tokens in the app, the shell history or a screenshot, never touch
`~/.hermes`, never run `hermes dashboard --stop`. Stop the app and backend
afterwards (`scripts/dev-app.sh stop`, `scripts/dev-backend.sh stop`), delete
screenshots that show a typed key, and `git restore` the Xcode files a macOS
build rewrites.
