# Reply previews on iPhone

Regular reply notifications include a plain-text preview of the completed
answer. Their native category supplies “Reply ready” while iOS hides previews.
Set **Settings → Notifications → Hermes → Show Previews → When Unlocked** to
reveal the answer after unlocking. Choosing Never or Always remains an iOS
preference; Hermes does not override it. Reply alerts remain ordinary alerts,
with no time-sensitive interruption or approval buttons.

Completed Live Activities also include a preview, shown below the status in
the Lock Screen card and expanded Dynamic Island. SwiftUI marks the preview
and chat title as privacy-sensitive so the system can redact them. Compact
Dynamic Island and watch Smart Stack views retain their concise status.

Previews contain at most 120 user-perceived characters, with Markdown turned
into plain text. They only contain a successful, completed answer: streaming
text, commands, questions and failure details are not shared in the Live
Activity. Empty answers keep the generic status.

App Lock suppresses reply previews in regular alerts, background completion
alerts and Live Activities. Until the saved App Lock preference loads, Live
Activities omit previews. Enabling App Lock dismisses any finished activity
that already carried a preview, since ActivityKit cannot update ended cards.

The existing `flutter_local_notifications` and `live_activities` integrations
carry the content. No lock-state polling or extra permissions are needed.
