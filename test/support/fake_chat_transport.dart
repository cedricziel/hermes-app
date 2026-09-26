import 'dart:async';

import 'package:hermes_app/src/chat/chat_models.dart' show UnsupportedKind;
import 'package:hermes_app/src/chat/chat_transport.dart';

/// A [ChatTransport] the test drives by hand: every [send] is recorded and
/// its reply stream is fed through the returned [FakeSend].
class FakeChatTransport implements ChatTransport {
  final sends = <FakeSend>[];
  bool closed = false;

  @override
  Stream<ChatEvent> send({
    String? threadId,
    String? profile,
    required String text,
    List<OutgoingAttachment> attachments = const [],
  }) {
    final send = FakeSend(
      threadId: threadId,
      profile: profile,
      text: text,
      attachments: attachments,
    );
    sends.add(send);
    return send._events.stream;
  }

  /// The latest follow-up stream asked for, by thread: feed it with
  /// [FakeFollowUps]. One asked for again after it was listened to is new,
  /// like the gateway's after a later send.
  final followUpStreams = <String, FakeFollowUps>{};

  @override
  Stream<ChatEvent> followUps(String threadId) {
    var follow = followUpStreams[threadId];
    if (follow == null || follow._events.hasListener) {
      follow = followUpStreams[threadId] = FakeFollowUps();
    }
    return follow._events.stream;
  }

  var connectionChecks = 0;

  @override
  Future<void> checkConnection() async => connectionChecks++;

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

  /// When set, the Nth clarify call (1-based, counted across the whole
  /// transport) throws; the others go through.
  int? failClarifyCallNumber;
  var _clarifyCalls = 0;

  /// When set, approval answers wait on it before reporting.
  Completer<void>? answerGate;

  @override
  Future<bool> answerApproval(String requestId, String choice) async {
    if (answerError case final error?) throw error; // ignore: only_throw_errors
    await answerGate?.future;
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
    if (answerError case final error?) throw error; // ignore: only_throw_errors
    if (++_clarifyCalls == failClarifyCallNumber) {
      throw Exception('socket closed');
    }
    clarifyAnswers.add((
      requestId: requestId,
      values: values,
      questionId: questionId,
      multiSelect: multiSelect,
    ));
    return accepts;
  }

  final stops = <String>[];

  /// What [stopReply] reports; false means nothing was running.
  bool stopsRunning = true;

  @override
  Future<bool> stopReply(String threadId) async {
    if (answerError case final error?) throw error; // ignore: only_throw_errors
    stops.add(threadId);
    return stopsRunning;
  }

  final skips = <(String, UnsupportedKind)>[];

  @override
  Future<bool> skipUnsupported(String requestId, UnsupportedKind kind) async {
    if (answerError case final error?) throw error; // ignore: only_throw_errors
    skips.add((requestId, kind));
    return accepts;
  }

  @override
  Future<void> close() async => closed = true;
}

class FakeSend {
  FakeSend({
    required this.threadId,
    this.profile,
    required this.text,
    this.attachments = const [],
  });

  final String? threadId;
  final String? profile;
  final String text;
  final List<OutgoingAttachment> attachments;
  final _events = StreamController<ChatEvent>();

  void emit(ChatEvent event) => _events.add(event);

  /// Ends the stream with an error, like a dropped connection.
  void fail([Object error = 'connection lost']) => _events.addError(error);

  /// Ends the stream without an error.
  void finish() => _events.close();
}

/// The turns Hermes chains on its own, fed by hand.
class FakeFollowUps {
  final _events = StreamController<ChatEvent>();

  void emit(ChatEvent event) => _events.add(event);

  void fail([Object error = 'connection lost']) => _events.addError(error);

  /// Whether the screen is still listening.
  bool get hasListener => _events.hasListener;
}
