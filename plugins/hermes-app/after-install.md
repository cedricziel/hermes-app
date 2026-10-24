# Finish setting up Hermes App messaging

Enable this plugin with `hermes plugins enable hermes-app`. Merge this into
the current profile's `config.yaml`, preserving its existing entries:

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

Restart the dashboard/gateway normally and start a new conversation so Hermes
learns about the destination. Try `hermes send --to hermes_app:inbox 'Hello'`,
then refresh the chat list in Hermes App under this profile.

This saves a new, replyable chat on the server. It does not send device push
notifications or wake a suspended phone. See this plugin's README for details.
