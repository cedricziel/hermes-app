import 'dart:async';

import 'package:hermes_app/src/chat/chat_transport.dart';

/// A [ChatTransport] the test drives by hand: every [send] is recorded and
/// its reply stream is fed through the returned [FakeSend].
class FakeChatTransport implements ChatTransport {
  final sends = <FakeSend>[];
  bool closed = false;

  @override
  Stream<ChatEvent> send({String? threadId, required String text}) {
    final send = FakeSend(threadId: threadId, text: text);
    sends.add(send);
    return send._events.stream;
  }

  final approvalAnswers = <(String, String)>[];
  final clarifyAnswers =
      <
        ({
          String requestId,
          List<String> values,
          String? questionId,
          bool multiSelect,
        })
      >[];

  /// What the answer calls report; false means the request is gone.
  bool accepts = true;

  /// When set, the answer calls throw it.
  Object? answerError;

  @override
  Future<bool> answerApproval(String requestId, String choice) async {
    if (answerError case final error?) throw error;
    approvalAnswers.add((requestId, choice));
    return accepts;
  }

  @override
  Future<bool> answerClarify(
    String requestId,
    List<String> values, {
    String? questionId,
    bool multiSelect = false,
  }) async {
    if (answerError case final error?) throw error;
    clarifyAnswers.add((
      requestId: requestId,
      values: values,
      questionId: questionId,
      multiSelect: multiSelect,
    ));
    return accepts;
  }

  @override
  Future<void> close() async => closed = true;
}

class FakeSend {
  FakeSend({required this.threadId, required this.text});

  final String? threadId;
  final String text;
  final _events = StreamController<ChatEvent>();

  void emit(ChatEvent event) => _events.add(event);

  /// Ends the stream with an error, like a dropped connection.
  void fail([Object error = 'connection lost']) => _events.addError(error);

  /// Ends the stream without an error.
  void finish() => _events.close();
}
