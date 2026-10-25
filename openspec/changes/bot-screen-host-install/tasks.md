# Tasks

One PR, `feat(bot-screen): install the desktop on the server`, about 500 changed lines including catalog and `design/web`. Depends on `bot-screen-card`; shipped last in the series.

## 1. Server request routing

- [ ] 1.1 Write failing transport tests: `display.install.sudo` with `session_id: ""` and no handler is answered `-32601` at once (today it is ignored); with a registered handler it is answered with the handler's result; a throwing handler answers an error; unregistering restores the refusal; other unhandled requests keep today's behaviour (refused only while their session is replying).
- [ ] 1.2 Add the handler registry to `HermesGatewayTransport`; verify 1.1 and the existing server-request tests pass. In the contract test move `display.install.sudo` from `refusedRequests` to a `registeredRequests` map and extend the coverage test to `handledServerRequests ∪ registeredRequests ∪ refusedRequests`; set `display.install.log` and `display.install.done` to `Use.transport`.

## 2. Install state

- [ ] 2.1 Write failing tests for `BotScreenInstalls`: Install on Server sends `display.install` with `profile`; a 5300 answer becomes refused with its message; log broadcasts for its key keep the last 6 lines and others are ignored; done with 0, -1, -2 and 1 produce the results, -2 carrying the status' install command; a sudo request for a running key shows the prompt and answers the value once, Cancel answers ''; for another key it refuses; the state survives the chat's controller being disposed; a status read with `installed: true` on resume or after a lost connection ends Installing; 20 minutes without done ends it as unknown.
- [ ] 2.2 Implement and provide it from `AppShell`; verify 2.1 passes.

## 3. Catalog first

- [ ] 3.1 Add card use cases (Not installed with Install on Server, Installing with lines, refused, cancelled, no sudo with the command, failed, may still be running) and `SudoPasswordPrompt` use cases (iOS, Material, Mac; both themes). Verify the catalog test passes.
- [ ] 3.2 Mirror them in `design/web` (`BotScreenCard` states, `SudoPasswordPrompt` with `docs/SudoPasswordPrompt.md`, `category: Surfaces`) and verify `npm run build` passes.

## 4. Wiring

- [ ] 4.1 Write failing widget tests: the button shows only with `placement: gateway` and an install command; the prompt appears after the user navigated from the chat to another tab; its field is obscured with autocorrect, suggestions, learning and autofill off and is empty after answering; closing the panel keeps the install state.
- [ ] 4.2 Wire the button into the card and the prompt host into `AppShell`; verify 4.1 passes.

## 5. Observability

- [ ] 5.1 Write failing tests: `bot_screen.install` (span and log) carries only `outcome` and `asked_password`, including the `unknown` timeout path, which also ends the span; breadcrumbs carry only their fixed values. Implement and verify.

## 6. Docs and skills

- [ ] 6.1 Extend `CLAUDE.md`'s Bot Screen paragraph: install, the server-request handler registry and the explicit refusal, the app-level prompt host, password handling.
- [ ] 6.2 Add an install section to the `verify-bot-screen` skill. The plain image (`nousresearch/hermes-agent:latest`) runs Hermes unprivileged with no `sudo`, so it exercises the no-sudo (-2) path. For the password prompt, the skill builds a throwaway layer on it that installs `sudo` and gives the Hermes user a password-protected sudo rule (a test password, never a real one).

## 7. Verify

- [ ] 7.1 Run format, analyze and the full test suite, all clean.
- [ ] 7.2 Run `verify-in-app` per the `verify-bot-screen` skill: against the sudo layer, press Install on Server, answer the password prompt, screenshot Installing and the Off state after it, and repeat with Cancel; against the plain image, check the no-sudo result shows the install command.
