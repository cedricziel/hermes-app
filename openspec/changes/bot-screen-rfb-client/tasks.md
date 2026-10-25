# Tasks

One PR, `feat(bot-screen): add a watch-only RFB client`, about 500 changed lines including tests. Depends on `bot-screen-chat-preview` only by order; no UI.

## 1. Display socket

- [ ] 1.1 Write failing tests against a local `HttpServer`: the opener's URL is `wss` for an `https` base, keeps the base URL's path prefix, has only the `display_ticket` query parameter and no `token` or `ticket`; the returned channel exposes the server's close code and `sink.close(4100)` sends that status; an upgrade answered with 403 throws `DisplaySocketError.notAllowed`, and neither its `toString` nor any field contains the URL or the ticket; a refused connection throws `unreachable` with the same guarantee.
- [ ] 1.2 Factor the connect step out of `openMixedWebSocket` and implement `openDisplaySocket`; verify 1.1 and the existing gateway socket tests pass.

## 2. Handshake and Raw

- [ ] 2.1 Write failing tests for `RfbClient` over an in-memory channel: it sends `RFB 003.008\n`; a security count of 0 reads the reason and fails with `security`; it chooses None and fails without it; it reads the SecurityResult and fails with its reason on non-zero; it sends ClientInit with shared = 1 and parses ServerInit; it then sends SetPixelFormat (32/24, little-endian, true colour, shifts 0/8/16), SetEncodings [16, 1, 0, -223] and a non-incremental request; messages split across and packed into frames parse the same; a server version below 3.8 fails with `version`; a text frame fails with `protocol`.
- [ ] 2.2 Write failing tests: Raw and CopyRect update the framebuffer with alpha 255; DesktopSize resizes it and is followed by a non-incremental request; other updates are followed by an incremental request; Bell and SetColourMapEntries are skipped; ServerCutText with a positive and a negative length is skipped without surfacing its bytes; an unknown message type fails with `protocol`.
- [ ] 2.3 Implement the reader, handshake, Raw, CopyRect and DesktopSize; verify 2.1 and 2.2 pass, and assert over a whole session that the client wrote only handshake bytes, SetPixelFormat, SetEncodings and FramebufferUpdateRequest.

## 3. ZRLE

- [ ] 3.1 Write failing tests for ZRLE with one zlib-format stream spanning two updates, fed exactly each rectangle's length: raw, solid, packed palette with 2, 3–4 and 5–16 colours, plain RLE (including runs over 255), palette RLE, and a partial edge tile; subencodings 17–127 and 129 fail with `decode`; truncating a recorded session at every offset ends with `decode` and never throws to the caller.
- [ ] 3.2 Implement ZRLE; verify 3.1 passes.

## 4. Observability

- [ ] 4.1 No spans, logs or breadcrumbs in this change. Write a failing test that `bytesReceived` and `encodingsSeen` reflect a session, for the span in `bot-screen-live-view`; implement and verify.

## 5. Docs and skills

- [ ] 5.1 Add the RFB client to `CLAUDE.md`'s Bot Screen paragraph: the display socket opener (ticket only, typed errors without URL), the pixel format, the encodings, ZRLE's persistent stream and that the client sends no input.
- [ ] 5.2 No skill change.

## 6. Verify

- [ ] 6.1 Run format, analyze and the full test suite, all clean.
- [ ] 6.2 Following the `verify-bot-screen` skill, run a throwaway test (not committed) that calls `display.observe` on the container backend through the gateway transport's `request`, opens the display socket and completes the handshake and one full ZRLE frame; record the result in the PR. No verify-in-app run: there is no UI.
