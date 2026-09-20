# Privacy

Hermes Agent Companion has no account, no advertising and no third-party analytics or tracking.

The app connects to the Hermes Agent server address you enter. What that server receives and stores is governed by whoever runs it.

## Diagnostics

Release builds send diagnostic logs and traces to a server run by the developer. They are used to find crashes and slow requests, and they are not shared with anyone else. They contain:

- the app version and whether it is a release build
- the operating system (iOS, macOS, Android, Windows or Linux), its major and minor version on iOS and macOS only, and whether the device is a phone, a tablet or a desktop; the form factor is left out when the screen size is not yet known
- a random ID that changes on every launch
- for each request the app makes: the HTTP method, the API path (for example `/api/status`), the status code and how long it took
- the type of error when a request fails
- for the chat connection to your server: the name of each request and event the app sends or receives (for example `session.create` or `tool.start`), its number, the error code when one fails and how long it took, but never what it carries
- sign-in steps: the app's connection state (for example "needs sign-in" or "ready"), whether a sign-in started, succeeded, was cancelled or failed and how long it took, whether it used a password, a short fixed reason such as "timeout", and when a session was refreshed or ended, with the status code the server answered
- the type of an error the app did not handle, such as `StateError`, without its message or stack trace

They never contain your server address, your session tokens, your messages or the responses from your server. The app does not add tracing headers to the requests it sends to your server.

Builds made from source without the diagnostics settings send nothing.

## On your device

The app stores:

- the server address you entered and your sign-in preferences, in app preferences
- your session tokens, in the system keychain (iOS and macOS) or keystore (Android)
- whether notifications are on, and whether the system allowed them, in app preferences

Notifications appear when a reply finishes and when Hermes needs you (an approval or a question), while Hermes is in the background or you are looking at another chat. Every notification shows the chat's title, and a finished reply also shows the first part of the reply, so both can appear on a lock screen. A request that needs you only says that Hermes is waiting. For a new chat the title is the start of your own message. The text is made and shown on your device and is not sent anywhere. Turn notifications off in the account menu if you do not want that.

Removing the app deletes this data. Signing out clears the stored tokens.

Questions: open an issue at https://github.com/cedricziel/hermes-app/issues.
