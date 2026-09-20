## 1. Model and history

- [x] 1.1 Add `ChatAttachment` and `ChatMessage.attachments`
- [x] 1.2 Add the pure parser from a stored row's content (string or list) to text plus attachments, with tests for `@image:`, `@file:`, "[User attached file: …]", quoted paths and list content
- [x] 1.3 Use the parser in `HermesChatRepository.loadMessages`; a row that cannot be read is skipped

## 2. Sending

- [ ] 2.1 Add `OutgoingAttachment` and the `attachments` parameter on `ChatTransport.send`; update the fake transport
- [ ] 2.2 In `HermesGatewayTransport.send`, attach images with `image.attach_bytes` and other files with `file.attach` between session setup and `prompt.submit`, append the `ref_text` values, and detach queued images on failure
- [ ] 2.3 Map method-not-found and attach errors to the messages in the spec
- [ ] 2.4 Enforce the 25 MB limit in `chat_screen.dart` before the message is inserted

## 3. Transcript

- [ ] 3.1 Map attachments to image and file messages in `chat_message_mapper.dart` and add the builders
- [ ] 3.2 Send: build `ChatMessage.attachments` from the pending `SharedFile`s and stop composing the "names only" text
- [ ] 3.3 Remove `attachmentsNote` and its test expectations

## 4. Verification and specs

- [ ] 4.1 Extend the fake server or transport tests for image, file, failure, too-large and method-not-found cases
- [ ] 4.2 Extend `test/real_backend_contract_test.dart` with `image.attach_bytes` and `file.attach` (no model call) and a history row with `@image:` content
- [ ] 4.3 Try it in the running macOS app against the dev backend (verify-in-app skill), then archive this change so the specs update
