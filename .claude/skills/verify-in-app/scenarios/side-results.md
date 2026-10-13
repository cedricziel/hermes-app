# Side results

Follow the shared isolation procedure before launching. Use synthetic chats on pinned Hermes backend `167e9fdb84248cd0fff80762dc57b6a914b6e930` and record the exact app source.

1. Start a main prompt and invoke an existing backend `/background` or `/btw` action. Confirm the result appears as a separate compact disclosure while main prose continues; opening details exposes the reported answer and optional question.
2. Finish the main reply, then deliver a background result on its followed runtime. Confirm no synthetic reply starts and no queued prompt is dispatched by that event.
3. Repeat a completion with the same kind and task ID, then use the same task ID with the other kind. Confirm replacement of the matching card and a separate card for the other kind. Missing/empty task IDs are ignored; empty answer text has a neutral label.
4. Disconnect during the main turn and deliver a side result in the backend replay ring. Confirm details clear on physical connection loss and only authorized replay/live results appear after normal reconnection. A frame present in both replay and live delivery must not duplicate a card.
5. Replace the profile, reclaim the runtime, or retire authenticated activity while a result is pending. Confirm old details clear and late frames cannot reappear in the new protected context. Separately check that App Lock covers the UI while preserving the existing policy for ordinary in-flight replies. Same-socket send takeover of the same owned runtime must preserve cards.

Side results have no dedicated history API. Do not launch or resume a conversation merely to populate cards, and do not claim cold-start restoration beyond actual received/replayed or documented durable data. Record native observations separately from automated receipts.
