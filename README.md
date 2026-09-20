# hermes-app

A Flutter client for [Hermes Agent](https://github.com/NousResearch/hermes-agent)
(by [Nous Research](https://nousresearch.com))'s web dashboard. Connect to a
self-hosted `hermes dashboard`, sign in with an OIDC provider or a
username and password, and chat with your agent from iPhone, iPad, Mac and
Android.

- Chat with history, streaming replies, tool calls, and approval and question
  requests from the agent
- A thread list with pinning, archive and delete, plus profiles and bots
- A Kanban board, when the server has the Kanban plugin on
- Notifications when a reply finishes or the agent needs you
- A share extension on iOS and a share inbox on macOS, and an Apple Watch
  companion
- OpenTelemetry export, off unless you configure it

## Try the beta

Join the TestFlight beta for iPhone, iPad and Mac: <https://testflight.apple.com/join/NahPgSAB>

The app checks for a newer version when it opens and offers to take you to it: in the App Store on iOS and macOS, on Google Play on Android, and on the GitHub release page on Linux and Windows. It finds nothing until the app is listed in a store.

You need your own Hermes Agent dashboard to sign in (see [Getting started](#getting-started)). This is an independent app and is not affiliated with Nous Research.

## Screenshots

<p align="center">
  <img src="docs/screenshots/iphone-chat.png" width="23%" alt="A chat on iPhone with tool calls, a code block and a list">
  <img src="docs/screenshots/iphone-threads.png" width="23%" alt="The thread list on iPhone, with a pinned chat">
  <img src="docs/screenshots/iphone-welcome.png" width="23%" alt="A new chat on iPhone with starter prompts">
  <img src="docs/screenshots/iphone-chat-dark.png" width="23%" alt="The same chat on iPhone in dark mode">
</p>

<p align="center">
  <img src="docs/screenshots/ipad-chat.png" width="55%" alt="The wide layout on iPad: navigation rail, thread list and chat">
</p>

<p align="center">
  <img src="docs/screenshots/mac-chat.png" width="90%" alt="The Mac app window with the thread list and a chat">
</p>

They are taken from the real app against a demo Hermes dashboard that holds a
few invented chats. [docs/screenshots](docs/screenshots/README.md) explains how
to retake them.

## Getting started

Run a dashboard the app can reach:

```bash
# on the machine that will host the dashboard
hermes dashboard --host 0.0.0.0 --port 9119 --no-open
```

Enter that machine's address (for example `http://192.168.1.20:9119`) on the
app's first screen. The [Web Dashboard docs](https://hermes-agent.nousresearch.com/docs/user-guide/features/web-dashboard)
cover the username and password or self-hosted OIDC provider.

To run the app from source:

```bash
flutter pub get
flutter run
```

The iOS app embeds a watchOS app (`ios/HermesWatch`), so Xcode needs the
watchOS platform installed (Xcode > Settings > Components) even if you only run
the phone app. `flutter build ios --simulator` then also needs a simulator:
pass one with `-d <simulator id>`.

Plain HTTP works against a dashboard on your network: Android allows cleartext
traffic, iOS and macOS allow local networking, and the macOS sandbox has the
client and server network entitlements the loopback sign-in callback needs.

## Reaching your dashboard over a VPN

If the dashboard is only reachable through Tailscale or WireGuard, turn the VPN
on first, then enter the address the server has on the VPN.

- **Tailscale, recommended:** keep the dashboard on the server's own loopback
  address, which is Hermes' default, and publish it to your tailnet with
  `tailscale serve`:

  ```bash
  hermes dashboard --port 9119 --no-open
  tailscale serve --bg 9119
  ```

  Enter the `https://<machine>.<tailnet>.ts.net` address that `tailscale serve`
  prints. It carries a real certificate, it stays off the internet, and on iOS
  Tailscale's VPN On Demand can start the VPN when the app looks up a `*.ts.net`
  name. Hermes sees these requests as local, so it does not ask anyone to sign
  in: every device on your tailnet can open the dashboard. Limit that with
  Tailscale access rules, or use the next option.
- **Tailscale or WireGuard address:** start the dashboard with `--host` set to
  the server's VPN address, for example `hermes dashboard --host 100.101.102.103`,
  and enter `http://100.101.102.103:9119`. Hermes refuses to bind to anything
  but loopback until a sign-in method is configured (a password in
  `config.yaml`, or an OAuth provider), so set that up first; the app then asks
  you to sign in. Do not use `0.0.0.0`, which also listens on your LAN. The VPN
  encrypts the traffic, so plain HTTP is fine.

The VPN has to be on for the whole device, because signing in opens the system
browser, which must reach the dashboard too. When the address looks like a VPN
or private address and the server does not answer, the app asks whether the VPN
is connected. When the network changes or you return to the app, it tries the
saved server again by itself.

## How sign-in works

The app uses the native-app OAuth flow (RFC 8252) that the dashboard exposes,
for OIDC and for password sign-in alike. It opens the system browser with a
PKCE challenge and a loopback redirect, redeems the returned code for a bearer
token pair kept in the OS keychain, and refreshes the token before it expires
and again on any `401`. When `/api/status` reports `auth_required: false` (the
dashboard's loopback dev mode), sign-in is skipped. The flow mirrors the one in
Hermes Desktop; the code is in `lib/src/auth/`.

## The API client

Most REST calls go through `packages/hermes_api`, a client generated from
`openapi/hermes-agent.openapi.json`. Don't edit it by hand. Regenerate it with
`./scripts/generate_hermes_api_client.sh` (needs a JDK and the Dart SDK); CI
fails if the client drifts from the spec. [openapi/README.md](openapi/README.md)
has the details.

## Development

`CLAUDE.md` covers the commands and the architecture. The repo uses
[pre-commit](https://pre-commit.com) to run the same `dart format` and
`flutter analyze` checks CI does, on staged Dart files:

```bash
pip install pre-commit   # or: brew install pre-commit
pre-commit install
```

## Contributing

The project uses the `oss` plugin from
[cedricziel/claude-plugins](https://github.com/cedricziel/claude-plugins)
(commit discipline, stacked PRs, tests) for anyone working on it with Claude
Code:

```
/plugin marketplace add cedricziel/claude-plugins
/plugin install oss@cedricziel
```

## License

Apache License 2.0. See [LICENSE](LICENSE).
