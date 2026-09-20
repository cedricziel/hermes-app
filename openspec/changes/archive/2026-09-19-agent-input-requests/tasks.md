## 1. Request model, events and reply folding

- [x] 1.1 Add `InputRequestStatus`, `InputRequest`, `ApprovalRequest`, `ClarifyQuestion` and `ClarifyRequest` to `chat_models.dart`, and `ChatMessage.inputRequests` with `awaitingInput`
- [x] 1.2 Add the `ApprovalRequested`, `ClarifyRequested` and `InputRequestExpired` events to `chat_transport.dart`
- [x] 1.3 Fold requests into the reply in `chat_reply.dart` (`recordApproval`, `recordClarifyAnswers`, `expireInputRequests`); expire pending requests on completion and on a failed reply
- [x] 1.4 Unit tests in `test/chat_reply_test.dart`

## 2. Map requests to transcript messages

- [x] 2.1 Add `kKindInputRequest` and `kMetaInputRequest` to `chat_message_kinds.dart`
- [x] 2.2 Emit one custom message per request (`<message id>-input-<n>`) after tool calls, and hide the thinking indicator while a request is pending
- [x] 2.3 Tests in `test/chat_message_mapper_test.dart`

## 3. Gateway events and answer calls

- [x] 3.1 Add `answerApproval` and `answerClarify` to `ChatTransport`
- [x] 3.2 Map `approval.request`, `clarify.request` and both expire events in `HermesGatewayTransport`; remember the gateway session per approval
- [x] 3.3 Send `approval.respond` and `clarify.respond` (multi-select as a JSON array in a string, `question_id` for batches, `false` on `expired`)
- [x] 3.4 Record answers in `FakeChatTransport`
- [x] 3.5 Tests in `test/hermes_gateway_transport_test.dart`

## 4. Approval and clarify cards

- [x] 4.1 Add the shared `InputCardFrame` and `InputCardNote`
- [x] 4.2 Add `ApprovalCard` (one button per choice, confirmation for Always allow, locks after a tap)
- [x] 4.3 Add `ClarifyCard` (choice chips or text field, Send or Confirm, Skip, drafts kept until submit)
- [x] 4.4 Route `kKindInputRequest` to the cards in `chat_builders.dart`
- [x] 4.5 Widget tests in `test/approval_card_test.dart`, `test/clarify_card_test.dart` and `test/chat_builders_test.dart`

## 5. Wire the cards to the chat screen

- [x] 5.1 Handle the new events in `chat_screen.dart` and send answers through the transport
- [x] 5.2 Record the outcome on the reply, or expire it when the backend says the request is gone
- [x] 5.3 Screen tests in `test/chat_input_request_test.dart`

## 6. Verify

- [x] 6.1 Run `dart format`, `flutter analyze` and `flutter test`
- [x] 6.2 Verify in the running app when the model raises a request on demand; otherwise the unit and widget tests are the evidence
