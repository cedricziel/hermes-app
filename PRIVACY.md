# Privacy

Hermes Agent Companion has no account, no advertising and no third-party analytics or tracking.

The app connects to the Hermes Agent server address you enter. What that server receives and stores is governed by whoever runs it.

## Diagnostics

Release builds send diagnostic logs and traces to a server run by the developer. They are used to find crashes and slow requests, and they are not shared with anyone else. They contain:

- the app version and platform
- a random ID that changes on every launch
- for each request the app makes: the HTTP method, the API path (for example `/api/status`), the status code and how long it took
- the type of error when a request fails
- the type of an error the app did not handle, such as `StateError`, without its message or stack trace

They never contain your server address, your session tokens, your messages or the responses from your server. The app does not add tracing headers to the requests it sends to your server.

Builds made from source without the diagnostics settings send nothing.

## On your device

The app stores:

- the server address you entered and your sign-in preferences, in app preferences
- your session tokens, in the system keychain (iOS and macOS) or keystore (Android)
- whether notifications are on, and whether the system allowed them, in app preferences

When a reply finishes while Hermes is in the background, the notification can show the chat's title and the first part of the reply, so both can appear on a lock screen. For a new chat the title is the start of your own message. The text is made and shown on your device and is not sent anywhere. Turn notifications off in the account menu if you do not want that.

Removing the app deletes this data. Signing out clears the stored tokens.

Questions: open an issue at https://github.com/cedricziel/hermes-app/issues.
