# Deferred tool labels

Hermes uses `tool_call` to invoke tools loaded on demand. It is a dispatcher,
not the name of the action being performed. A single call carries
`{"name": "read_file", "arguments": {"path": "lib/main.dart"}}`; a batch
carries `{"calls": [{"name": "read_file", "arguments": {...}}, ...]}`.
`tool_search` and `tool_describe` discover tools and read their schemas.

New Hermes gateway lifecycle events include `labels`, with `name`, `text`,
and `preview` for each target. The app uses these labels in cards and running
group summaries. Older servers and stored OpenAI-style history fall back to
the nested argument names. A batch shows its first target plus the remaining
count; opening it lists every target and preserves the raw dispatcher and
arguments behind “Raw arguments”. Underlying arguments appear as labelled,
selectable values; command strings retain their exact newlines and shell
quoting, while nested arrays and objects use indented JSON. Terminal calls
also show options such as working directory and timeout alongside their command.
A call without a target stays “Tool call” until Hermes provides one.

Presentation never changes the protocol `name` or call ID. Tool completion,
approval correlation, output warnings and tool-specific renderers keep using
their original identities. Labels on completion can fill in a missing start
label; absent completion labels preserve the earlier name.

Upstream contract checked against Hermes commit
`e6cf2a9b1e8f98d40408b09a9a55993c8459b4b4`:
[gateway payloads](https://github.com/NousResearch/hermes-agent/blob/e6cf2a9b1e8f98d40408b09a9a55993c8459b4b4/gateway/run_turn_progress.py#L44)
and [tool label resolution](https://github.com/NousResearch/hermes-agent/blob/e6cf2a9b1e8f98d40408b09a9a55993c8459b4b4/tools/tool_labels.py#L148).
