---
name: messaging
description: Send a message to the user in Hermes App using its configured messenger plugin.
---

Use this skill when the user asks for a message in Hermes App.

1. Write the message as UTF-8 text to a temporary file using a file-writing
   tool. Do not interpolate user text into a shell command.
2. Run `hermes send --to hermes_app:inbox --file /absolute/path/to/message.txt`.
3. Check the exit code. Only a successful send means the message was saved.
4. Remove the temporary file when finished.

The message appears as a new saved chat in the current profile on the same
Hermes dashboard. Hermes App announces it with a notification and the user
can open it and reply.
Do not pass another profile unless the user explicitly names it. Never use
an existing chat ID as the delivery target or append to a running conversation.

For a scheduled delivery, use the existing scheduler with
`deliver="hermes_app:inbox"`. Its delivery engine sends the output; the job
prompt must not send it again. Bare `deliver="hermes_app"` requires the home
channel shown in this plugin's setup instructions.

Messages are text-only, including Markdown. Attachments are rejected. Saved
delivery works while the app is disconnected. The app notices it within about
a minute while it is open; a closed or suspended phone is not woken at once,
so do not promise an immediate alert.
