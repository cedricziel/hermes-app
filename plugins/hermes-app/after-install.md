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
learns about the destination. Try `hermes send --to hermes_app:inbox 'Hello'`:
Hermes App posts a notification for it, within about a minute while it is open.

This saves a new, replyable chat on the server. A closed or suspended phone is
not woken at once. See this plugin's README for details.
