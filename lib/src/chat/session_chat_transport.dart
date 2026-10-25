import 'dart:async';

import '../models/model_provider_option.dart';
import 'chat_models.dart';
import 'chat_transport.dart';
import 'slash_command.dart';
import 'owned_session_transport.dart';
import 'gateway_connection_transport.dart';
import 'connector_operation_transport.dart';
import 'billing_verification_transport.dart';

/// Work was blocked or its delegate was invalidated before it completed.
final class SessionTransportUnavailable extends StateError {
  SessionTransportUnavailable({required this.retired})
    : super(retired ? 'Chat session retired' : 'Chat session suspended');

  final bool retired;
}

/// Stable transport identity with replaceable, terminally closed delegates.
/// The activity owner must verify recovery policy before calling [resume].
final class SessionChatTransport
    implements
        ChatTransport,
        PromptAcknowledgement,
        GatewayRequester,
        OwnedSessionTransport,
        ConnectorOperationTransport,
        GatewayConnectionTransport,
        QueueSubmissionTransport,
        BillingVerificationTransport {
  SessionChatTransport(this._create) : _delegate = _create() {
    final delegate = _delegate;
    _acknowledgement = delegate is PromptAcknowledgement
        ? delegate as PromptAcknowledgement
        : null;
  }

  final ChatTransport Function() _create;
  ChatTransport? _delegate;
  var _epoch = 0;
  var _retired = false;
  PromptAcknowledgement? _acknowledgement;
  final _subscriptions = <Future<void> Function()>{};
  Future<void> _closing = Future<void>.value();

  SessionTransportUnavailable get _unavailable =>
      SessionTransportUnavailable(retired: _retired);

  ChatTransport get _active => _delegate ?? (throw _unavailable);

  bool _current(int epoch) => _delegate != null && epoch == _epoch;

  void _check(int epoch) {
    if (!_current(epoch)) throw _unavailable;
  }

  Future<T> _call<T>(Future<T> Function(ChatTransport) operation) async {
    final delegate = _active;
    final epoch = _epoch;
    try {
      final result = await operation(delegate);
      _check(epoch);
      return result;
    } on Object {
      _check(epoch);
      rethrow;
    }
  }

  Stream<T> _stream<T>(Stream<T> Function(ChatTransport) open) {
    final delegate = _delegate;
    if (delegate == null) return Stream.error(_unavailable);
    final epoch = _epoch;
    StreamSubscription<T>? subscription;
    final attached = Completer<StreamSubscription<T>?>();
    Future<void>? cancellation;
    late final StreamController<T> controller;
    Future<void> cancel() => cancellation ??= () async {
      try {
        final inner = subscription ?? await attached.future;
        await inner?.cancel();
      } finally {
        _subscriptions.remove(cancel);
        if (!controller.isClosed) {
          if (!_current(epoch)) controller.addError(_unavailable);
          unawaited(controller.close());
        }
      }
    }();

    controller = StreamController<T>(
      sync: true,
      onListen: () {
        if (!_current(epoch)) {
          attached.complete(null);
          controller.addError(_unavailable);
          unawaited(controller.close());
          return;
        }
        _subscriptions.add(cancel);
        try {
          final source = open(delegate);
          _check(epoch);
          subscription = source.listen(
            (event) {
              if (_current(epoch)) controller.add(event);
            },
            onError: (Object error, StackTrace stack) {
              if (_current(epoch)) controller.addError(error, stack);
            },
            onDone: () {
              _subscriptions.remove(cancel);
              if (!_current(epoch) && !controller.isClosed) {
                controller.addError(_unavailable);
              }
              unawaited(controller.close());
            },
          );
        } on Object catch (error, stack) {
          _subscriptions.remove(cancel);
          controller.addError(_current(epoch) ? error : _unavailable, stack);
          unawaited(controller.close());
        } finally {
          attached.complete(subscription);
        }
      },
      onPause: () => subscription?.pause(),
      onResume: () => subscription?.resume(),
      onCancel: cancel,
    );
    // Paused listeners can hold frames already queued before suspension.
    return controller.stream.transform(
      StreamTransformer<T, T>.fromHandlers(
        handleData: (event, sink) {
          if (_current(epoch)) sink.add(event);
        },
        handleError: (error, stack, sink) {
          if (_current(epoch) || error is SessionTransportUnavailable) {
            sink.addError(error, stack);
          }
        },
      ),
    );
  }

  /// Closes the gate synchronously; cancels streams before closing delegates.
  Future<void> suspend() {
    if (_delegate == null) return _closing;
    final delegate = _delegate!;
    _delegate = null;
    _epoch++;
    final cancellations = _subscriptions
        .toList()
        .map((cancel) => cancel())
        .toList();
    final closing = () async {
      try {
        await Future.wait(cancellations);
      } finally {
        await delegate.close();
      }
    }();
    return _closing = Future.wait([_closing, closing]).then((_) {});
  }

  /// Creates a fresh delegate after the activity owner authorizes recovery.
  /// Throws [SessionTransportUnavailable] once permanently retired.
  void resume() {
    if (_retired) throw _unavailable;
    if (_delegate != null) return;
    _delegate = _create();
    _epoch++;
  }

  @override
  Future<void> close() {
    _retired = true;
    return suspend();
  }

  @override
  bool get promptAccepted => _acknowledgement?.promptAccepted ?? false;

  @override
  Stream<OwnedSessionChange> get ownedSessions => _stream(
    (delegate) => delegate is OwnedSessionTransport
        ? (delegate as OwnedSessionTransport).ownedSessions
        : const Stream<OwnedSessionChange>.empty(),
  );

  @override
  OwnedSessionBinding? ownedSessionFor(String threadId, {String? profile}) {
    final delegate = _delegate;
    return delegate is OwnedSessionTransport
        ? (delegate as OwnedSessionTransport).ownedSessionFor(
            threadId,
            profile: profile,
          )
        : null;
  }

  @override
  Future<Map<String, Object?>> readOwnedSession(
    OwnedSessionBinding binding,
    String method,
  ) => _call((delegate) {
    if (delegate is! OwnedSessionTransport) {
      throw UnsupportedError('No owned session read');
    }
    return (delegate as OwnedSessionTransport).readOwnedSession(
      binding,
      method,
    );
  });

  @override
  bool billingVerificationSupported(OwnedSessionBinding binding) {
    final delegate = _delegate, epoch = _epoch;
    return delegate is BillingVerificationTransport &&
        (delegate as BillingVerificationTransport).billingVerificationSupported(
          binding,
        ) &&
        _current(epoch);
  }

  @override
  Future<Map<String, Object?>> stepUpBilling(
    OwnedSessionBinding binding, {
    required bool Function() authorize,
  }) => _call((delegate) {
    final epoch = _epoch;
    if (delegate is! BillingVerificationTransport) {
      throw UnsupportedError('No billing verification');
    }
    return (delegate as BillingVerificationTransport).stepUpBilling(
      binding,
      authorize: () => _current(epoch) && authorize(),
    );
  });

  @override
  Stream<GatewayConnectionEvent> get connectionEvents => _stream(
    (delegate) => delegate is GatewayConnectionTransport
        ? (delegate as GatewayConnectionTransport).connectionEvents
        : const Stream<GatewayConnectionEvent>.empty(),
  );
  @override
  Object? get gatewayConnection {
    final delegate = _delegate, epoch = _epoch;
    if (delegate is! GatewayConnectionTransport) return null;
    final connection =
        (delegate as GatewayConnectionTransport).gatewayConnection;
    return _current(epoch) ? connection : null;
  }

  @override
  bool ownsGatewayConnection(Object connection) {
    final delegate = _delegate, epoch = _epoch;
    return delegate is GatewayConnectionTransport &&
        (delegate as GatewayConnectionTransport).ownsGatewayConnection(
          connection,
        ) &&
        _current(epoch);
  }

  @override
  Future<Map<String, Object?>> respondToConnectorOperation(
    OwnedSessionBinding binding,
    Map<String, Object?> params, {
    required bool Function() authorize,
  }) => _call((delegate) {
    final epoch = _epoch;
    if (delegate is! ConnectorOperationTransport) {
      throw UnsupportedError('No connector response');
    }
    return (delegate as ConnectorOperationTransport)
        .respondToConnectorOperation(
          binding,
          params,
          authorize: () => _current(epoch) && authorize(),
        );
  });

  @override
  Future<Map<String, Object?>> request(
    String method, [
    Map<String, Object?> params = const {},
  ]) => _call((delegate) {
    if (delegate is! GatewayRequester) {
      throw UnsupportedError('Transport does not support gateway RPC');
    }
    return (delegate as GatewayRequester).request(method, params);
  });

  @override
  Future<Map<String, Object?>> requestKeepingConnection(
    String method,
    Map<String, Object?> params, {
    required Duration timeout,
  }) => _call((delegate) {
    if (delegate is! GatewayRequester) {
      throw UnsupportedError('Transport does not support gateway RPC');
    }
    return (delegate as GatewayRequester).requestKeepingConnection(
      method,
      params,
      timeout: timeout,
    );
  });

  @override
  Future<List<SlashCommand>> slashCommands({
    String? threadId,
    String? profile,
  }) => _call((d) => d.slashCommands(threadId: threadId, profile: profile));

  @override
  Future<SlashCommandResult> runSlashCommand({
    String? threadId,
    String? profile,
    required String command,
  }) => _call(
    (d) => d.runSlashCommand(
      threadId: threadId,
      profile: profile,
      command: command,
    ),
  );

  @override
  Stream<ChatEvent> send({
    String? threadId,
    String? profile,
    required String text,
    List<OutgoingAttachment> attachments = const [],
    ModelChoice? model,
    bool queued = false,
  }) => _stream((d) {
    _acknowledgement = d is PromptAcknowledgement
        ? d as PromptAcknowledgement
        : null;
    return d.send(
      threadId: threadId,
      profile: profile,
      text: text,
      attachments: attachments,
      model: model,
      queued: queued,
    );
  });

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
  }) => _stream((delegate) {
    if (profile == null || profile.trim().isEmpty) {
      throw QueueSubmissionNotStarted(StateError('Queued profile unresolved'));
    }
    if (delegate is! QueueSubmissionTransport) {
      throw UnsupportedError('Transport cannot protect queued submissions');
    }
    final epoch = _epoch;
    _acknowledgement = delegate is PromptAcknowledgement
        ? delegate as PromptAcknowledgement
        : null;
    return (delegate as QueueSubmissionTransport).sendQueued(
      threadId: threadId,
      profile: profile,
      text: text,
      attachments: attachments,
      model: model,
      onNotSubmitted: onNotSubmitted,
      queueDispatchAllowed: () =>
          _current(epoch) && (queueDispatchAllowed?.call() ?? true),
      beforeSubmit: () async {
        try {
          _check(epoch);
          await beforeSubmit();
          _check(epoch);
        } on Object catch (error) {
          throw error is QueueSubmissionNotStarted
              ? error
              : QueueSubmissionNotStarted(error);
        }
      },
    );
  });

  @override
  Stream<ChatEvent> followUps(String threadId, {String? profile}) =>
      _stream((d) => d.followUps(threadId, profile: profile));

  @override
  Future<Map<String, String>> activeStatuses({String? profile}) =>
      _call((d) => d.activeStatuses(profile: profile));

  @override
  Future<void> checkConnection() => _call((d) => d.checkConnection());

  @override
  Future<bool> answerApproval(String requestId, String choice) =>
      _call((d) => d.answerApproval(requestId, choice));

  @override
  Future<bool> answerClarify(
    String requestId,
    List<String> values, {
    String? questionId,
    bool multiSelect = false,
  }) => _call(
    (d) => d.answerClarify(
      requestId,
      values,
      questionId: questionId,
      multiSelect: multiSelect,
    ),
  );

  @override
  Future<bool> answerOpenRequest(
    String requestId,
    OpenRequestAnswer answer, {
    String? threadId,
    String? profile,
    bool raisedAsEvent = false,
    DateTime? deadline,
  }) => _call(
    (d) => d.answerOpenRequest(
      requestId,
      answer,
      threadId: threadId,
      profile: profile,
      raisedAsEvent: raisedAsEvent,
      deadline: deadline,
    ),
  );

  @override
  Future<List<ApprovalRequest>> pendingApprovals({
    required String threadId,
    String? profile,
  }) => _call((d) => d.pendingApprovals(threadId: threadId, profile: profile));

  @override
  Future<bool> answerVault(
    String requestId,
    VaultKind kind, {
    String identifier = '',
    String password = '',
    String code = '',
  }) => _call(
    (d) => d.answerVault(
      requestId,
      kind,
      identifier: identifier,
      password: password,
      code: code,
    ),
  );

  @override
  Future<bool> stopReply(String threadId, {String? profile}) =>
      _call((d) => d.stopReply(threadId, profile: profile));

  @override
  Future<int?> undoLastTurn(
    String threadId, {
    String? profile,
    bool retry = false,
  }) => _call((d) => d.undoLastTurn(threadId, profile: profile, retry: retry));

  @override
  Future<bool> skipUnsupported(String requestId, UnsupportedKind kind) =>
      _call((d) => d.skipUnsupported(requestId, kind));
}
