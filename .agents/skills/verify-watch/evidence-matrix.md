# Watch verification evidence

Every case starts unverified. Record simulator and paired-hardware results
separately as passed, failed, or unavailable with a reason and evidence path.

| Case | Expected result source |
|---|---|
| Cold launch with backgrounded phone | watch-native-verification; completion or recoverable unavailability |
| Sleep and wake during send | watch-send-attempt-isolation; no stale visible mutation |
| Phone termination after acceptance | watch-send-journal; check result before explicit resend |
| Disconnect and reconnect | watch-send-recovery; only matching turn recovered |
| Delayed approval notification | watch-request-guidance; show where to answer |
| Stop waiting, late completion | watch-send-attempt-isolation; reject old attempt |
| Voice interruption and recording cap | watch-voice-review; retain review draft |
| Logout during load, send, recording | watch-session-privacy; clear private data |
| Server or owner switch, overlapping IDs | watch-context-identity; reject cross-context operations |
| Old invalidation after new handshake | watch-session-privacy; reject stale revision |
| Legacy cache migration | watch-context-identity; unbound data unavailable |
| Watch and phone protocol skew | watch-context-identity; actionable compatibility failure |
| Approval confirm, deny, stale request | watch-inline-approvals; accept current offered actions only |
| Choice and free-text question answer | watch-inline-questions; correct structured request answered |
| Failed text retry, edit, discard; answer reading | watch-conversation-usability; visible recovery and stable position |
| Profile, status, cached freshness | watch-glanceable-chats; context and freshness correct |
| Built-in starters and contextual actions | watch-contextual-actions; choices match state |
| Smallest watch and larger Dynamic Type | All UI changes; readable and operable controls |

Each record contains case, change, commit, toolchain, OS versions, platform,
fixture preflight evidence, expected result, actual result, result, and evidence
path. Capture fixed outcomes in logs. Screenshots may contain invented text.
Mirrored notification actions, microphone interruption, background scheduling,
and real device wake behavior require paired-hardware evidence.
