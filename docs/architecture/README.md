# Architecture notes

The full description of each area of the app, moved here from `CLAUDE.md` so agents load only the area they work on. `CLAUDE.md` keeps a short map with each area's hardest rules. Read the area's file before changing it, and update it with the change.

| Area                                                                                   | File                                                               | Code                                                                                                                         |
| -------------------------------------------------------------------------------------- | ------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------- |
| App shell, navigation, profile scope, app prompt hint                                  | [app-shell.md](app-shell.md)                                       | `lib/main.dart`, `lib/src/app.dart`, `lib/src/shell/`, `lib/src/profiles/`, `lib/src/platform_hint/`                         |
| Auth                                                                                   | [auth.md](auth.md)                                                 | `lib/src/auth/`, `lib/src/network/`                                                                                          |
| Headless runtime                                                                       | [headless-runtime.md](headless-runtime.md)                         | `lib/src/background/`                                                                                                        |
| Chat (controller, messages, activity, composer, search, Mac sidebar)                   | [chat.md](chat.md)                                                 | `lib/src/chat/`, `lib/src/models/`                                                                                           |
| Gateway transport                                                                      | [gateway.md](gateway.md)                                           | `lib/src/chat/gateway/`, `openrpc/`                                                                                          |
| Deep links                                                                             | [deep-links.md](deep-links.md)                                     | `lib/src/deep_links/`                                                                                                        |
| Voice                                                                                  | [voice.md](voice.md)                                               | `lib/src/voice/`, `packages/hermes_speech`                                                                                   |
| Bot Mode                                                                               | [bot-mode.md](bot-mode.md)                                         | `lib/src/bot_mode/`                                                                                                          |
| Bot Screen (card, preview, install, display stream, live viewer, control lease, input) | [bot-screen.md](bot-screen.md)                                     | `lib/src/bot_screen/`                                                                                                        |
| Settings pages, Plugins, MCP servers, Helper models                                    | [settings-screens.md](settings-screens.md)                         | `lib/src/widgets/`, `lib/src/plugins/`, `lib/src/mcp/`, `lib/src/settings/`                                                  |
| Memory settings and proposals                                                          | [memory.md](memory.md)                                             | `lib/src/memory/`                                                                                                            |
| Notifications, background refresh, Live Activities                                     | [notifications-and-background.md](notifications-and-background.md) | `lib/src/notifications/`, `lib/src/background/`, `lib/src/schedules/`, `lib/src/agent_messages/`, `lib/src/live_activities/` |
| Surface snapshot, quick actions, Ask Hermes, request intents, Spotlight                | [surfaces-and-intents.md](surfaces-and-intents.md)                 | `lib/src/surfaces/`, `lib/src/quick_actions/`, `lib/src/intents/`, `lib/src/spotlight/`                                      |
| Watch complications and Handoff                                                        | [watch.md](watch.md)                                               | `lib/src/watch/`, `ios/HermesWatch`, `ios/HermesComplication`                                                                |
| Telemetry                                                                              | [telemetry.md](telemetry.md)                                       | `lib/src/telemetry/`                                                                                                         |
| macOS menu bar, conversation windows, Dock menu, drag out, menu bar item               | [macos.md](macos.md)                                               | `lib/src/macos/`, `lib/src/windows/`, `lib/src/quick_panel/`, `lib/src/drag_out/`                                            |
| Native pieces                                                                          | [native.md](native.md)                                             | `ios/`, `macos/`                                                                                                             |

Other `lib/src/` directories and where they are described:

- `api/`: "Two API layers" in `CLAUDE.md`.
- `kanban/`, `schedules/`: the Kanban and Schedules tabs in [app-shell.md](app-shell.md) (the Mac Kanban toolbar and inspector too); schedule alerts in [notifications-and-background.md](notifications-and-background.md).
- `skills/`, `messaging/`: the shared settings chrome in [settings-screens.md](settings-screens.md); their lenient parsing under "Two API layers" in `CLAUDE.md`.
- `share/`: the iOS share extension and the macOS share inbox in [native.md](native.md).
- `chat/media/` (`MediaStore`, Quick Look): [chat.md](chat.md).
- `handoff/`: [watch.md](watch.md) (Watch Handoff) and [macos.md](macos.md) (conversation windows).
- `app_lock/`: no file of its own; what App Lock hides is described in each surface's file ([surfaces-and-intents.md](surfaces-and-intents.md), [notifications-and-background.md](notifications-and-background.md), [macos.md](macos.md)).
- `core/`, `navigation/`, `screens/`, `theme/`, `update/`: not described yet.

The API layers (generated client versus hand-written calls) stay in `CLAUDE.md`, since they apply to every change. Current behaviour as specified lives in `openspec/specs/`; design history in `openspec/changes/archive/`.

Verification against real, throwaway instances: the `verify` skill (`.claude/skills/verify/SKILL.md`, `scripts/verify.sh`) on Linux and in cloud containers, `verify-in-app` on a Mac. Its "Covered behaviour" table lists what the PR checks exercise; a PR that adds behaviour in an area above adds its check there.
