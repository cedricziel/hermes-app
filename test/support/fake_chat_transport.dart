import 'dart:async';

import 'package:hermes_app/src/chat/chat_models.dart'
    show UnsupportedKind, VaultKind;
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/slash_command.dart';
import 'package:hermes_app/src/models/model_provider_option.dart';

/// A [ChatTransport] the test drives by hand: every [send] is recorded and
/// its reply stream is fed through the returned [FakeSend].
class FakeChatTransport implements ChatTransport {
  final sends = <FakeSend>[];
  bool closed = false;

  List<SlashCommand> availableSlashCommands = const [];
  final catalogGates = <Completer<List<SlashCommand>>>[];
  final catalogContexts = <(String?, String?)>[];
  final slashRuns = <String>[];
  SlashCommandResult? slashResult;
  Completer<SlashCommandResult>? slashGate;

  @override
  Future<List<SlashCommand>> slashCommands({
    String? threadId,
    String? profile,
  }) async {
    catalogContexts.add((threadId, profile));
    if (catalogGates.isNotEmpty) return catalogGates.removeAt(0).future;
    return availableSlashCommands;
  }

  @override
  Future<SlashCommandResult> runSlashCommand({
    String? threadId,
    String? profile,
    required String command,
  }) async {
    slashRuns.add(command);
    if (slashGate case final gate?) return gate.future;
    return slashResult ??
        SlashCommandResult(
          threadId: threadId ?? 'slash-thread',
          output: 'Done',
        );
  }

  @override
  Stream<ChatEvent> send({
    String? threadId,
    String? profile,
    required String text,
    List<OutgoingAttachment> attachments = const [],
    ModelChoice? model,
    bool queued = false,
  }) {
    final send = FakeSend(
      threadId: threadId,
      profile: profile,
      text: text,
      attachments: attachments,
      model: model,
      queued: queued,
    );
    sends.add(send);
    return send._events.stream;
  }

  /// The latest follow-up stream asked for, by thread: feed it with
  /// [FakeFollowUps]. One asked for again after it was listened to is new,
  /// like the gateway's after a later send.
  final followUpStreams = <String, FakeFollowUps>{};
  var followUpCalls = 0;

  @override
  Stream<ChatEvent> followUps(String threadId, {String? profile}) {
    followUpCalls++;
    var follow = followUpStreams[threadId];
    if (follow == null || follow._listened || follow._events.isClosed) {
      follow = followUpStreams[threadId] = FakeFollowUps();
    }
    return follow._events.stream;
  }

  var connectionChecks = 0;

  @override
  Future<void> checkConnection() async => connectionChecks++;

  /// Session id → status, as [ChatController.refreshActive] reads it.
  final active = <String, String>{};

  @override
  Future<Map<String, String>> activeStatuses() async => Map.of(active);

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

  /// Every [answerOpenRequest] call: the request id, the answer and the
  /// profile.
  final openAnswers = <(String, OpenRequestAnswer, String?)>[];

  /// The thread each [answerOpenRequest] call named.
  final openAnswerThreads = <String?>[];

  /// When set, [answerOpenRequest] waits on it after recording the call.
  Completer<void>? openAnswerGate;

  @override
  Future<bool> answerOpenRequest(
    String requestId,
    OpenRequestAnswer answer, {
    String? threadId,
    String? profile,
  }) async {
    if (answerError case final error?) throw error; // ignore: only_throw_errors
    openAnswers.add((requestId, answer, profile));
    openAnswerThreads.add(threadId);
    await openAnswerGate?.future;
    return accepts;
  }

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

  /// Holds a stop response while another reply event arrives.
  Completer<void>? stopGate;

  /// Answers a stop in place of [stopsRunning], per call.
  Future<bool> Function(String threadId)? onStop;

  @override
  Future<bool> stopReply(String threadId, {String? profile}) async {
    if (onStop case final handler?) {
      stops.add(threadId);
      return handler(threadId);
    }
    if (answerError case final error?) throw error; // ignore: only_throw_errors
    stops.add(threadId);
    await stopGate?.future;
    return stopsRunning;
  }

  /// Every [undoLastTurn], as the thread and whether it was a retry.
  final undos = <(String, bool)>[];

  /// What [undoLastTurn] reports; null is a server that cannot undo.
  int? undoRemoved = 2;

  /// Thrown by [undoLastTurn] when set.
  Object? undoError;

  /// Holds [undoLastTurn]'s answer until completed.
  Completer<void>? undoGate;

  @override
  Future<int?> undoLastTurn(
    String threadId, {
    String? profile,
    bool retry = false,
  }) async {
    undos.add((threadId, retry));
    await undoGate?.future;
    if (undoError case final error?) throw error; // ignore: only_throw_errors
    return undoRemoved;
  }

  final skips = <(String, UnsupportedKind)>[];

  @override
  Future<bool> skipUnsupported(String requestId, UnsupportedKind kind) async {
    if (answerError case final error?) throw error; // ignore: only_throw_errors
    skips.add((requestId, kind));
    return accepts;
  }

  final vaultAnswers =
      <
        ({
          String requestId,
          VaultKind kind,
          String identifier,
          String password,
          String code,
        })
      >[];

  @override
  Future<bool> answerVault(
    String requestId,
    VaultKind kind, {
    String identifier = '',
    String password = '',
    String code = '',
  }) async {
    if (answerError case final error?) throw error; // ignore: only_throw_errors
    vaultAnswers.add((
      requestId: requestId,
      kind: kind,
      identifier: identifier,
      password: password,
      code: code,
    ));
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
    this.model,
    this.queued = false,
  });

  final String? threadId;
  final String? profile;
  final String text;
  final List<OutgoingAttachment> attachments;
  final ModelChoice? model;

  /// Whether the send asked to queue behind a running turn.
  final bool queued;
  final _events = StreamController<ChatEvent>();

  void emit(ChatEvent event) => _events.add(event);

  /// Ends the stream with an error, like a dropped connection.
  void fail([Object error = 'connection lost']) => _events.addError(error);

  /// Ends the stream without an error.
  void finish() => _events.close();
}

/// The turns Hermes chains on its own, fed by hand.
class FakeFollowUps {
  FakeFollowUps() {
    _events.onListen = () => _listened = true;
  }

  final _events = StreamController<ChatEvent>();
  var _listened = false;

  void emit(ChatEvent event) => _events.add(event);

  void fail([Object error = 'connection lost']) => _events.addError(error);

  void finish() => _events.close();

  /// Whether the screen is still listening.
  bool get hasListener => _events.hasListener;
}
