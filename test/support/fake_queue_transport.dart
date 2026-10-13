import 'dart:async';

import 'package:hermes_app/src/models/model_provider_option.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';

import 'fake_chat_transport.dart';

class FakeQueueTransport extends FakeChatTransport
    implements QueueSubmissionTransport {
  bool loseAcceptance = false;
  String acceptanceStatus = 'streaming';
  Completer<void>? acceptanceGate;
  final _prepared = Completer<void>();
  Future<void> get prepared => _prepared.future;
  @override
  Stream<ChatEvent> sendQueued({
    String? threadId,
    String? profile,
    required String text,
    List<OutgoingAttachment> attachments = const [],
    ModelChoice? model,
    required Future<void> Function() beforeSubmit,
    Future<void> Function()? onNotSubmitted,
    bool Function()? queueDispatchAllowed,
  }) async* {
    try {
      if (queueDispatchAllowed?.call() == false) {
        throw QueueSubmissionNotStarted(StateError('Queue unavailable'));
      }
      await beforeSubmit();
      if (queueDispatchAllowed?.call() == false) {
        throw QueueSubmissionNotStarted(StateError('Queue unavailable'));
      }
    } on Object catch (error) {
      await onNotSubmitted?.call();
      throw QueueSubmissionNotStarted(error);
    } finally {
      if (!_prepared.isCompleted) _prepared.complete();
    }
    final source = send(
      threadId: threadId,
      profile: profile,
      text: text,
      attachments: attachments,
      model: model,
      queued: true,
    );
    if (loseAcceptance) {
      sends.last.finish();
      throw StateError('Submit answer lost');
    }
    await acceptanceGate?.future;
    yield PromptAccepted(acceptanceStatus);
    yield* source;
  }
}
