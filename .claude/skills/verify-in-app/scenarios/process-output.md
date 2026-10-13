# Process output

Follow the shared isolation procedure before launching. Use synthetic conversations and processes on the retained verification backend `167e9fdb84248cd0fff80762dc57b6a914b6e930`; record the exact app source. The current bundled contract is `71d34bad1045610252eda02ee79549436896e784`; the process notification and payload schemas match the retained baseline.

1. Deliver interleaved `agent.terminal.output` chunks for two process IDs during a main turn. Confirm each process card contains only its ordered plain text and the main reply keeps its existing typing, prose, and settlement behavior.
2. Deliver `terminal.close` before the first output chunk. Confirm a Closed placeholder appears, later output fills it, and no success, failure, or exit code is inferred. Repeat while no main turn is active and confirm no synthetic reply or queued dispatch starts.
3. Deliver more than 64 KiB of multibyte UTF-8 output. Confirm a readable bounded newest tail and an omission footer. Fill 16 cards, close one, then add another; confirm closed-first eviction and the omitted-card footer.
4. Expand a long output card in the actual chat on a narrow window. Confirm the text scrolls in a capped details viewport and the transcript and composer remain usable. Escape sequences, markup, and URLs must stay inert text.
5. Disconnect, replace profile, reclaim the runtime, or lock protected activity while chunks are pending. Confirm old buffers release and late chunks from the old binding cannot enter replacement buffers. Normal reconnect replay and simultaneous live delivery must not append a repeated sequence twice.

There is no complete process-output archive or recovery API. Inspect only actual authorized live/replay data; do not resume or create a chat solely to populate process cards. Record native observations separately from automated receipts.
