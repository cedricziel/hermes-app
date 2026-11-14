import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:dart_otel_instrumentation_messaging/dart_otel_instrumentation_messaging.dart';
import 'package:flutter_otel/flutter_otel.dart'
    show AppEventLogger, noopAppEventLogger;
import 'package:stream_channel/stream_channel.dart';

import '../../api/session_source.dart';
import '../../models/model_provider_option.dart';
import '../../workspaces/workspace_models.dart';
import '../chat_models.dart';
import '../chat_transport.dart';
import '../chat_session_state.dart';
import '../owned_session_transport.dart';
import '../gateway_connection_transport.dart';
import '../connector_operation_transport.dart';
import '../connector_operation_state.dart';
import '../billing_verification_transport.dart';
import '../slash_command.dart';
import 'cancel_aware_stream.dart';
import 'gateway_event_mapper.dart';
import 'gateway_replay.dart';
import 'gateway_rpc_client.dart';
import 'unmapped_events.dart';

part 'hermes_gateway_transport_helpers.dart';
part 'hermes_gateway_transport_owned_sessions.dart';
part 'hermes_gateway_transport_commands.dart';
part 'hermes_gateway_transport_sending.dart';
part 'hermes_gateway_transport_turns.dart';
part 'hermes_gateway_transport_reconnect.dart';
part 'hermes_gateway_transport_follow_ups.dart';
part 'hermes_gateway_transport_requests.dart';
part 'hermes_gateway_transport_branching.dart';
part 'hermes_gateway_transport_connection.dart';

/// Opens the dashboard's `/api/ws` socket, credentials included.
typedef GatewayConnect = Future<StreamChannel<String>> Function();

/// The server-to-client request methods the app answers. The gateway sends
/// many more (vault prompts, desktop bridges); those are refused at once.
const handledServerRequests = {
  'approval',
  'clarify',
  'sudo',
  'secret',
  'vault.save_login',
  'vault.unlock_prompt',
  'vault.code',
};

/// Server requests that reach only the connection that caused them and carry
/// no session, so no other client can answer them. With no handler registered
/// (see [HermesGatewayTransport.registerServerRequestHandler]) they are refused
/// at once, whatever their session; the server would otherwise wait out its
/// own timeout.
const registrableServerRequests = {'display.install.sudo'};

/// Answers a server request of a registered method with its result, or throws
/// a [GatewayRpcException] to refuse it with that error. [connection] is the
/// socket it arrived on (see `GatewayConnectionTransport.gatewayConnection`).
/// Any other throw answers an internal error without its message.
typedef ServerRequestHandler = Future<Map<String, Object?>> Function(
  GatewayServerRequest request,
  Object connection,
);

/// What `image.attach_bytes` answers for a file that is not an image type it
/// knows.
const _unsupportedImage = 4016;

/// How many reconnect attempts follow a drop before the reply gives up.
const _maxReconnectAttempts = 5;

/// How many times a send opens its socket and session before it fails.
const _sendOpenAttempts = 3;

/// How long one reconnect may take, from the drop, before the reply gives up.
const _reconnectBudget = Duration(seconds: 60);

/// How many times one reply may reconnect in all. Each drop gets its own
/// attempts and budget, so a socket that keeps dropping right after it
/// resumes would otherwise never run out.
const _maxReplyReconnects = 5;

Future<void> _delay(Duration delay) => Future<void>.delayed(delay);

/// The fewest characters (whitespace trimmed) of parked deltas that a resume
/// snapshot's text must end with for the deltas to be taken as held by it.
const _minHeldRun = 8;

/// What a send shows while Hermes finishes the turn it began before the app
/// came back, ahead of the prompt the user sent.
const _finishingInterruptedTurn = 'Hermes is finishing the interrupted turn…';

/// The `session.active_list` statuses of a session that still runs a turn.
const _liveStatuses = {
  'starting',
  'waiting',
  'working',
  'streaming',
  'resuming',
};

/// A stored session ID qualified by its explicit owning profile.
typedef _ThreadOwner = (String?, String);

/// A chat event, and whether it came from a server-to-client request.
typedef _Incoming = (ChatEvent event, bool serverRequest);

/// [ChatTransport] over the dashboard's JSON-RPC gateway: `session.create` or
/// `session.resume`, then `prompt.submit`, whose reply arrives as events.
class HermesGatewayTransport
    implements
        ChatTransport,
        PromptAcknowledgement,
        GatewayRequester,
        OwnedSessionTransport,
        ConnectorOperationTransport,
        GatewayConnectionTransport,
        QueueSubmissionTransport,
        BillingVerificationTransport {
  HermesGatewayTransport({
    required this._connect,
    this._telemetry,
    this._events = noopAppEventLogger,
    this.requestTimeout = const Duration(seconds: 30),
    this.probeTimeout = const Duration(seconds: 10),
    this.connectTimeout = const Duration(seconds: 15),
    this.silenceProbe = const Duration(seconds: 45),
    Random? random,
    this._sleep = _delay,
  }) : _random = random ?? Random();

  var _promptAccepted = false;

  @override
  bool get promptAccepted => _promptAccepted;

  /// Jitters the delay before each reconnect attempt. Tests inject a fixed one.
  final Random _random;

  /// Waits out the delay before a reconnect attempt. Tests inject a recorder.
  final Future<void> Function(Duration delay) _sleep;

  /// Replays what a dropped socket missed, per runtime session.
  final _ledger = ReplayLedger();

  /// How long opening a session or submitting a prompt may go unanswered
  /// before the connection is given up on.
  final Duration requestTimeout;

  /// How long a connection may take to answer [checkConnection].
  final Duration probeTimeout;

  /// How long opening the socket may take before it is given up on, so a
  /// server that never answers the upgrade does not outlast the OS connect
  /// timeout for every send waiting on it.
  final Duration connectTimeout;

  /// How long a reply in flight may go without a frame of its session before
  /// `session.active_list` is asked whether the turn still runs.
  final Duration silenceProbe;

  final GatewayConnect _connect;
  final MessagingConnectionTracer? _telemetry;

  /// Where the `gateway.*` log events go. They carry fixed names and coarse
  /// values, never the text of a message.
  final AppEventLogger _events;

  /// The frame types this connection showed nothing for, as far as they were
  /// reported.
  var _unmapped = UnmappedEvents();
  GatewayRpcClient? _open;
  Future<GatewayRpcClient>? _opening;
  final _awaiting = <String, _OpenRequest>{};

  /// The sessions still listened to after their reply ended, by thread.
  final _idle = <_ThreadOwner, _Watch>{};

  /// The threads whose reply a send settled on a stand-in idle report while
  /// the prompt's own turn was still to come. That turn's end, when it is
  /// seen on the follow-ups, is the same reply and is not logged again.
  final _settledEarly = <_ThreadOwner>{};

  /// The runtime sessions a reply is in flight for, with how many.
  final _replying = <String, int>{};

  final _requestHandlers = <String, ServerRequestHandler>{};

  /// Has [handler] answer the server requests of [method], which must be one
  /// of [registrableServerRequests]. A later registration for the same method
  /// replaces this one. The returned function removes this registration only.
  void Function() registerServerRequestHandler(
    String method,
    ServerRequestHandler handler,
  ) {
    if (!registrableServerRequests.contains(method)) {
      throw ArgumentError.value(method, 'method', 'cannot be registered');
    }
    _requestHandlers[method] = handler;
    return () {
      if (identical(_requestHandlers[method], handler)) {
        _requestHandlers.remove(method);
      }
    };
  }

  /// The runtime session a reply is in flight in, by the thread it belongs to.
  final _runtimeOf = <_ThreadOwner, String>{};

  /// The model each thread was last set to from here, by thread.
  final _modelOf = <_ThreadOwner, ModelChoice>{};

  final _ownedBindings = <_ThreadOwner, OwnedSessionBinding>{};
  final _ownedSessions = StreamController<OwnedSessionChange>.broadcast(
    sync: true,
  );
  @override
  Stream<OwnedSessionChange> get ownedSessions => _ownedSessions.stream;

  final _connectionEvents = StreamController<GatewayConnectionEvent>.broadcast(
    sync: true,
  );
  final _billingPending = <OwnedSessionBinding>{};
  final _billingUnavailable = <Object>{};
  @override
  bool billingVerificationSupported(OwnedSessionBinding binding) =>
      _ownsBinding(binding) &&
      !_billingUnavailable.contains(binding.connection);
  @override
  Future<Map<String, Object?>> stepUpBilling(
    OwnedSessionBinding binding, {
    required bool Function() authorize,
  }) => _stepUpBilling(binding, authorize: authorize);

  @override
  Stream<GatewayConnectionEvent> get connectionEvents =>
      _connectionEvents.stream;
  @override
  Object? get gatewayConnection => _closed ? null : _connected();
  @override
  bool ownsGatewayConnection(Object connection) =>
      !_closed && identical(_connected(), connection);

  @override
  Future<Map<String, Object?>> respondToConnectorOperation(
    OwnedSessionBinding binding,
    Map<String, Object?> params, {
    required bool Function() authorize,
  }) => _respondToConnectorOperation(binding, params, authorize: authorize);

  @override
  OwnedSessionBinding? ownedSessionFor(String threadId, {String? profile}) {
    final binding = _ownedBindings[(profile, threadId)];
    return binding != null && _ownsBinding(binding) ? binding : null;
  }

  @override
  Future<Map<String, Object?>> readOwnedSession(
    OwnedSessionBinding binding,
    String method,
  ) => _readOwnedSession(binding, method);

  /// Shared authenticated RPC for profile and Bot Mode repositories.
  @override
  Future<Map<String, Object?>> request(
    String method, [
    Map<String, Object?> params = const {},
  ]) async => _call(await _client(), method, params);

  /// Like [request], but a call that gets no answer within [timeout] throws
  /// [GatewayRequestTimeout] and leaves the connection, and the replies
  /// running on it, alone.
  @override
  Future<Map<String, Object?>> requestKeepingConnection(
    String method,
    Map<String, Object?> params, {
    required Duration timeout,
  }) async => (await requestKeepingConnectionOnClient(
    method,
    params,
    timeout: timeout,
  )).$1;

  /// [requestKeepingConnection], also saying which connection carried the
  /// call (the token `GatewayConnectionTransport.gatewayConnection` gives),
  /// for a call whose server request comes back on that connection alone.
  @override
  Future<(Map<String, Object?>, Object)> requestKeepingConnectionOnClient(
    String method,
    Map<String, Object?> params, {
    required Duration timeout,
  }) async {
    final client = await _client();
    return (
      await client.requestWithin(method, params, timeout: timeout),
      client,
    );
  }

  @override
  Future<Map<String, Object?>> requestOn(
    Object connection,
    String method,
    Map<String, Object?> params, {
    required Duration timeout,
  }) async {
    final open = _connected();
    if (_closed || open == null || !identical(open, connection)) {
      throw const GatewayConnectionClosed();
    }
    // A socket the OS dropped while nothing watched it would fail this call
    // only after its timeout; check one that went quiet first, as `_client`
    // does, and drop a dead one.
    if (open.isStale && !await _alive(open)) {
      _drop(open);
      throw const GatewayConnectionClosed();
    }
    return open.requestWithin(method, params, timeout: timeout);
  }

  @override
  Future<List<SlashCommand>> slashCommands({
    String? threadId,
    String? profile,
  }) => _slashCommands(threadId: threadId, profile: profile);

  @override
  Future<SlashCommandResult> runSlashCommand({
    String? threadId,
    String? profile,
    required String command,
  }) =>
      _runSlashCommand(threadId: threadId, profile: profile, command: command);

  @override
  Stream<ChatEvent> send({
    String? threadId,
    String? profile,
    required String text,
    List<OutgoingAttachment> attachments = const [],
    ModelChoice? model,
    bool queued = false,
    WorkspaceChoice? workspace,
  }) => _send(
    threadId: threadId,
    profile: profile,
    text: text,
    attachments: attachments,
    model: model,
    queued: queued,
    workspace: workspace,
  );

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
  }) {
    if (profile == null || profile.trim().isEmpty) {
      return Stream.error(
        QueueSubmissionNotStarted(StateError('Queued profile unresolved')),
      );
    }
    return _send(
      threadId: threadId,
      profile: profile,
      text: text,
      attachments: attachments,
      model: model,
      queued: true,
      beforeSubmit: beforeSubmit,
      onNotSubmitted: onNotSubmitted,
      queueDispatchAllowed: queueDispatchAllowed,
    );
  }

  /// The connections being probed, so callers that arrive meanwhile wait for
  /// the same answer instead of each waiting out a probe of their own.
  final _probes = <GatewayRpcClient, Future<bool>>{};

  @override
  Future<void> checkConnection() async {
    final open = _connected();
    if (open == null || await _alive(open)) return;
    _drop(open);
  }

  @override
  Stream<ChatEvent> followUps(String threadId, {String? profile}) =>
      _followUps(threadId, profile: profile);

  @override
  Future<Map<String, String>> activeStatuses({String? profile}) async {
    final GatewayRpcClient client;
    final Map<String, Object?> result;
    try {
      client = await _client();
      result = await _call(client, 'session.active_list', {
        'profile': ?profile,
      });
    } on Object {
      return const {};
    }
    return _statusesOf(result);
  }

  @override
  Future<bool> answerApproval(String requestId, String choice) =>
      _answerApproval(requestId, choice);

  @override
  Future<bool> answerClarify(
    String requestId,
    List<String> values, {
    String? questionId,
    bool multiSelect = false,
  }) => _answerClarify(
    requestId,
    values,
    questionId: questionId,
    multiSelect: multiSelect,
  );

  @override
  Future<List<ApprovalRequest>> pendingApprovals({
    required String threadId,
    String? profile,
  }) => _pendingApprovals(threadId: threadId, profile: profile);

  /// `request.answer` resolves an open server-to-client request by its id,
  /// with no session attached, for a client that never received the frame.
  /// A request the server raised as an event (`approval.request`,
  /// `clarify.request`), or any request on a server without
  /// `request.answer`, takes the older answers: `approval.respond`,
  /// `clarify.respond`. An approval `request.answer` does not know (`expired`)
  /// may still be one of those, so it is tried there too; a question's
  /// `expired` is final.
  ///
  /// The chat is never resumed to answer: that rebuilds the session, may
  /// start Hermes' continuation of an interrupted turn and can take the live
  /// session from the socket that owns it. `approval.respond` names the chat
  /// by its stored id, which Hermes accepts as the durable identity of a live
  /// session.
  @override
  Future<bool> answerOpenRequest(
    String requestId,
    OpenRequestAnswer answer, {
    String? threadId,
    String? profile,
    bool raisedAsEvent = false,
    DateTime? deadline,
  }) => _answerOpenRequest(
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
  }) => _answerVault(
    requestId,
    kind,
    identifier: identifier,
    password: password,
    code: code,
  );

  @override
  Future<bool> stopReply(String threadId, {String? profile}) =>
      _stopReply(threadId, profile: profile);

  @override
  Future<int?> undoLastTurn(
    String threadId, {
    String? profile,
    bool retry = false,
  }) => _undoLastTurn(threadId, profile: profile, retry: retry);

  @override
  Future<BranchedThread?> branchThread(
    String threadId, {
    String? profile,
    int dropTurns = 0,
  }) => _branchThread(threadId, profile: profile, dropTurns: dropTurns);

  @override
  Future<bool> skipUnsupported(String requestId, UnsupportedKind kind) =>
      _skipUnsupported(requestId, kind);

  @override
  Future<void> close() async {
    _closed = true;
    final open = _open;
    _open = null;
    final idle = _idle.values.toList();
    _idle.clear();
    _settledEarly.clear();
    _ownedBindings.clear();
    unawaited(_ownedSessions.close());
    unawaited(_connectionEvents.close());
    for (final watch in idle) {
      await watch.close();
    }
    // Not awaited: the socket may already be gone, and closing a channel whose
    // peer has left can wait forever. Nothing here needs the close to finish.
    unawaited(open?.close());
  }

  /// Set by [close]. A reply still running then would otherwise reconnect on
  /// the socket that close just ended, and leave the new one open.
  var _closed = false;
}
