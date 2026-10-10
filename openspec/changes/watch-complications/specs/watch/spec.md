## ADDED Requirements

### Requirement: Complications and Smart Stack widget

The watch app SHALL offer a Voice Chat complication in the `accessoryCircular` and `accessoryCorner` families, and a chat status complication in the `accessoryRectangular` family, which is also the Smart Stack widget. Voice Chat SHALL open the watch app on a new voice message. The chat status SHALL show the title of the latest chat and one of "Working", "Waiting for you", "Reply ready" and "Failed", and a tap SHALL open that chat; with nothing to show it SHALL say "No recent chat" and a tap SHALL open the app.

The phone SHALL send the watch the latest turn's status when a turn starts, waits for the user (an approval, a question, a request only the phone can answer), or ends, for a reply sent from the phone and for a turn sent from the watch. It SHALL send it with `transferCurrentComplicationUserInfo` while the day's budget lasts, and with `updateApplicationContext` otherwise, and only when the status changed. The status SHALL consist of the state, a timestamp, the chat's title and the watch's thread id for the chat. It SHALL NOT contain message, command, question or reply text. A turn waiting for the user SHALL be the one shown, before any other. A reply the user stopped SHALL NOT be shown. Signing out SHALL clear the status. While App Lock is on, the status SHALL carry the state and timestamp only.

The watch app SHALL keep the received status in an App Group shared with the widget extension and reload the widget timelines when a status arrives. The widget SHALL raise its Smart Stack relevance while the turn waits for the user and for ten minutes after a turn ends, SHALL lower it afterwards, and SHALL treat a working or waiting status that was not renewed for 30 minutes as nothing to show, since a suspended phone app cannot report the end of a turn.

#### Scenario: Reply working

- **WHEN** the user sends a prompt in chat "Backup" from the phone
- **THEN** the watch's chat status shows "Backup" and "Working"

#### Scenario: Waiting for an approval

- **WHEN** the agent asks for approval to run `rm -rf build` in a turn
- **THEN** the chat status shows "Waiting for you", ranks first in the Smart Stack, and neither the command nor any other text is sent to the watch

#### Scenario: Turn sent from the watch

- **WHEN** the user sends a message from the watch and the reply completes
- **THEN** the chat status shows "Reply ready" for that chat

#### Scenario: App Lock on

- **WHEN** App Lock is on and a reply starts
- **THEN** the phone sends the state and timestamp, and the chat status shows "Working" without a title

#### Scenario: Phone never reported the end

- **WHEN** the status says "Working" and was last renewed 40 minutes ago
- **THEN** the chat status shows "No recent chat"

#### Scenario: Circular complication

- **WHEN** the user taps the circular or corner complication
- **THEN** the watch app opens a new chat ready to record a voice message

#### Scenario: Signed out

- **WHEN** the user signs out on the phone
- **THEN** the phone clears the status and the chat status shows "No recent chat"
