# Hermes App messenger

A Hermes Agent platform plugin maintained with hermes-app. It registers
`hermes_app` as a messaging destination for `hermes send` and scheduled-job
delivery (`hermes send --list` shows it once a gateway has run). It also adds a bounded, session-frozen
prompt hint so the agent knows about the destination and its messaging skill.

Delivery creates a new saved chat in the sending profile's `state.db`, using
Hermes' public `SessionDB` API. Hermes App finds it and posts a notification;
tap it to open the chat in its profile, and reply as usual. Opening it marks it
read on the dashboard. The dashboard's existing
authenticated session API serves these chats. Nothing listens on a new port,
no app token is needed, and no third-party service receives the message.

## Install on the Hermes server

Use a Hermes version supporting platform plugins, standalone senders, plugin
skills and system prompt sections. Install into each profile that should send:

```sh
hermes plugins install cedricziel/hermes-app/plugins/hermes-app
hermes plugins enable hermes-app
```

Merge this into that profile's `config.yaml` (preserve existing plugins and
platforms):

```yaml
platforms:
  hermes_app:
    enabled: true
    gateway_restart_notification: false
    home_channel:
      platform: hermes_app
      chat_id: inbox
      name: Hermes App inbox
```

Restart the dashboard/gateway normally after installation, then start a **new
conversation** so the agent receives the hint. Existing conversation prompts
stay unchanged to preserve their caches. No gateway needs to be running to
send from the CLI or from a separate cron process.

For another profile, use `hermes -p PROFILE plugins install ...` and
`hermes -p PROFILE plugins enable hermes-app`, and edit that profile's config.
The app must connect to the dashboard on this same Hermes installation.

## Send

```sh
hermes send --list hermes_app
hermes send --to hermes_app:inbox 'Hello from Hermes'
hermes send --to hermes_app --file /absolute/path/to/report.txt
```

The bare platform uses the home channel above. In a new agent conversation,
ask “Send me a message in Hermes App.” The agent can load
`hermes-app:messaging` and send with the CLI. Agent-generated text should be
written to a file first, rather than interpolated into shell syntax.

Hermes does not give the agent a tool to message other platforms on its own;
cron delivery and the `hermes send` CLI are the ways out. The skill therefore
sends only when the user asks, through the CLI, which needs a profile with the
terminal tool.

For scheduled output, select Hermes App in the schedule delivery picker, or
use `deliver="hermes_app:inbox"` with Hermes' existing scheduler. Do not also
ask the job's prompt to send: automatic delivery already sends the output.

## Delivery contract

- A successful send means the message was saved durably on the server. It
  does not mean a device received or read it.
- Each delivery is a fresh chat titled `Message: …`, initially unread, with
  the exact text as an assistant message. It does not start an LLM turn.
  The user may reply normally. Existing and running chats are never modified.
- `inbox` is the only target. Arbitrary session IDs, thread targets and media
  attachments fail explicitly. Markdown and long text are preserved.
- The gateway adapter captures its profile home at construction; standalone
  sends resolve the current profile for each call. One profile cannot choose
  another profile through a delivery target.
- Sending while the app is disconnected works. Hermes App looks for new
  deliveries once a minute while it is open (Android, iOS, macOS) and during
  the iOS and Android background refresh, which the system schedules. Each
  delivery is announced once per device. There is no APNs/FCM push, so a
  closed or suspended app is not woken at once.
- Registering the `hermes_app` platform also gives chats the app starts this
  plugin's platform hint ("You are chatting in Hermes App. Markdown is
  supported."), unless the profile already replaces it with the hint Hermes
  App offers to write.

## Development

Run the tests using the Python environment of a Hermes checkout:

```sh
PYTHONPATH=/path/to/hermes-agent python -m unittest discover \
  -s plugins/hermes-app/tests -v
```

Tests exercise the actual plugin registry, configuration, send engine, cron
target resolution and SessionDB against temporary Hermes homes. The dedicated
GitHub workflow runs against the same Hermes revision pinned by the app's
API contracts. Flutter code and generated API clients are unchanged.
