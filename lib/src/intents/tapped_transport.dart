import 'dart:async';

import '../chat/chat_models.dart'
    show ApprovalRequest, UnsupportedKind, VaultKind;
import '../chat/chat_transport.dart';
import '../chat/slash_command.dart';
import '../models/model_provider_option.dart';

/// A [ChatTransport] that tells [onEvent] about each event of its sends
/// before the sender sees it, and otherwise is [_inner].
class TappedTransport implements ChatTransport {
  TappedTransport(this._inner, this.onEvent);

  final ChatTransport _inner;
  final void Function(ChatEvent event) onEvent;

  @override
  Stream<ChatEvent> send({
    String? threadId,
    String? profile,
    required String text,
    List<OutgoingAttachment> attachments = const [],
    ModelChoice? model,
    bool queued = false,
  }) => _inner
      .send(
        threadId: threadId,
        profile: profile,
        text: text,
        attachments: attachments,
        model: model,
        queued: queued,
      )
      .map((event) {
        onEvent(event);
        return event;
      });

  @override
  Future<List<SlashCommand>> slashCommands({
    String? threadId,
    String? profile,
  }) => _inner.slashCommands(threadId: threadId, profile: profile);

  @override
  Future<SlashCommandResult> runSlashCommand({
    String? threadId,
    String? profile,
    required String command,
  }) => _inner.runSlashCommand(
    threadId: threadId,
    profile: profile,
    command: command,
  );

  @override
  Stream<ChatEvent> followUps(String threadId, {String? profile}) =>
      _inner.followUps(threadId, profile: profile);

  @override
  Future<Map<String, String>> activeStatuses({String? profile}) =>
      _inner.activeStatuses(profile: profile);

  @override
  Future<void> checkConnection() => _inner.checkConnection();

  @override
  Future<bool> answerApproval(String requestId, String choice) =>
      _inner.answerApproval(requestId, choice);

  @override
  Future<bool> answerClarify(
    String requestId,
    List<String> values, {
    String? questionId,
    bool multiSelect = false,
  }) => _inner.answerClarify(
    requestId,
    values,
    questionId: questionId,
    multiSelect: multiSelect,
  );

  @override
  Future<bool> answerOpenRequest(
    String requestId,
    OpenRequestAnswer answer, {
    String? threadId,
    String? profile,
    bool raisedAsEvent = false,
    DateTime? deadline,
  }) => _inner.answerOpenRequest(
    requestId,
    answer,
    threadId: threadId,
    profile: profile,
    raisedAsEvent: raisedAsEvent,
    deadline: deadline,
  );

  @override
  Future<bool> answerVault(
    String requestId,
    VaultKind kind, {
    String identifier = '',
    String password = '',
    String code = '',
  }) => _inner.answerVault(
    requestId,
    kind,
    identifier: identifier,
    password: password,
    code: code,
  );

  @override
  Future<List<ApprovalRequest>> pendingApprovals({
    required String threadId,
    String? profile,
  }) => _inner.pendingApprovals(threadId: threadId, profile: profile);

  @override
  Future<bool> stopReply(String threadId, {String? profile}) =>
      _inner.stopReply(threadId, profile: profile);

  @override
  Future<int?> undoLastTurn(
    String threadId, {
    String? profile,
    bool retry = false,
  }) => _inner.undoLastTurn(threadId, profile: profile, retry: retry);

  @override
  Future<bool> skipUnsupported(String requestId, UnsupportedKind kind) =>
      _inner.skipUnsupported(requestId, kind);

  @override
  Future<void> close() => _inner.close();
}
