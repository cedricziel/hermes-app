# Privacy

Hermes Agent Companion has no account, no advertising and no third-party analytics or tracking.

The app connects to the Hermes Agent server address you enter. What that server receives and stores is governed by whoever runs it.

## Diagnostics

Release builds send diagnostic logs and traces to a server run by the developer. They are used to find crashes and slow requests, and they are not shared with anyone else. They contain:

- the app version and platform
- a random ID that changes on every launch
- for each request the app makes: the HTTP method, the API path (for example `/api/status`), the status code and how long it took
- the type of error when a request fails

They never contain your server address, your session tokens, your messages or the responses from your server. The app does not add tracing headers to the requests it sends to your server.

Builds made from source without the diagnostics settings send nothing.

## On your device

The app stores:

- the server address you entered and your sign-in preferences, in app preferences
- your session tokens, in the system keychain (iOS and macOS) or keystore (Android)

Removing the app deletes this data. Signing out clears the stored tokens.

Questions: open an issue at https://github.com/cedricziel/hermes-app/issues.
