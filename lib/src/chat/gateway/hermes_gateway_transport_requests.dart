part of 'hermes_gateway_transport.dart';

/// Approval, clarify and vault requests: tracking them and answering them.
extension _Requests on HermesGatewayTransport {
  /// Shows the requests of [rows] (each an `open_requests` list from a resume
  /// or replay answer) that [shown] does not hold yet.
  void _openRequests(
    List<_Incoming> out,
    List<Object?> rows,
    String sid,
    Set<String> shown,
  ) {
    for (final row in rows) {
      if (row is! List) continue;
      for (final item in row) {
        if (item is! Map) continue;
        final id = item['id'];
        final method = item['method'];
        if (id is! String || method is! String) continue;
        final params = item['params'];
        _addRequest(
          out,
          GatewayServerRequest(
            id: id,
            method: method,
            sessionId: sid,
            params: params is Map
                ? {for (final e in params.entries) e.key.toString(): e.value}
                : const {},
          ),
          shown,
        );
      }
    }
  }

  /// Adds [request] to [out] as a shown request, unless its method is not
  /// one the app answers or [shown] already holds its id.
  void _addRequest(
    List<_Incoming> out,
    GatewayServerRequest request,
    Set<String> shown,
  ) {
    if (!handledServerRequests.contains(request.method)) return;
    if (!shown.add(request.id)) return;
    final incoming = _fromServerRequest(request);
    if (incoming != null) out.add((incoming, true));
  }

  /// Points the open requests [mine] at the runtime session [to], after a
  /// reconnect moved the reply there from [from], so that withdrawing or
  /// answering them still finds them.
  void _moveRequests(Set<String> mine, String from, String to) {
    if (from == to) return;
    for (final id in mine) {
      final open = _awaiting[id];
      if (open != null && open.sessionId == from) {
        _awaiting[id] = open.movedTo(to);
      }
    }
  }

  void _forgetRequests(Set<String> mine) {
    mine.forEach(_awaiting.remove);
    mine.clear();
  }

  /// Remembers the requests this turn raised, so they can be answered until
  /// the turn ends, and forgets one that expired.
  void _track(
    ChatEvent event,
    String sessionId,
    Set<String> mine, {
    required bool serverRequest,
  }) {
    final (String, bool)? request = switch (event) {
      ApprovalRequested(:final request) => (request.requestId, false),
      ClarifyRequested(:final request) when serverRequest => (
        request.requestId,
        request.batch,
      ),
      VaultRequested(:final request) => (request.requestId, false),
      UnsupportedRequested(:final request) => (request.requestId, false),
      _ => null,
    };
    if (request != null) {
      final (id, batch) = request;
      mine.add(id);
      _awaiting[id] = _OpenRequest(
        sessionId: sessionId,
        serverRequest: serverRequest,
        batch: batch,
      );
    } else if (event is InputRequestExpired) {
      _awaiting.remove(event.requestId);
    } else if (event is InputRequestsCancelled) {
      // No ids withdraws every request of the reply.
      final withdrawn = event.requestIds.isEmpty
          ? mine.toList()
          : event.requestIds;
      for (final id in withdrawn) {
        if (_awaiting[id]?.sessionId != sessionId) continue;
        _awaiting.remove(id);
        mine.remove(id);
      }
    }
  }

  Future<bool> _answerApproval(String requestId, String choice) async {
    final open = _awaiting[requestId];
    if (open == null) return false;
    if (open.serverRequest) return _respond(requestId, {'choice': choice});
    final client = await _client();
    final result = await client.request('approval.respond', {
      'session_id': open.sessionId,
      'request_id': requestId,
      'choice': choice,
    });
    return ((result['resolved'] as num?) ?? 0) > 0;
  }

  Future<bool> _answerClarify(
    String requestId,
    List<String> values, {
    String? questionId,
    bool multiSelect = false,
  }) async {
    final answer = _clarifyValue(values, multiSelect: multiSelect);
    final open = _awaiting[requestId];
    if (open == null) {
      final client = await _client();
      final result = await client.request('clarify.respond', {
        'request_id': requestId,
        'answer': answer,
        'question_id': ?questionId,
      });
      return result['status'] != 'expired';
    }
    if (!open.batch) return _respond(requestId, {'answer': answer});
    // A batch skipped as a whole has no question to lock: an empty result
    // withdraws all of it.
    if (questionId == null) return _respond(requestId, const {});
    final result = await _connected()?.request('clarify.lock', {
      'request_id': requestId,
      'answer': answer,
      'question_id': questionId,
    });
    return result != null && result['status'] != 'expired';
  }

  Future<List<ApprovalRequest>> _pendingApprovals({
    required String threadId,
    String? profile,
  }) async {
    final client = await _client();
    final listed = await _call(client, 'session.active_list', {
      'profile': ?profile,
    });
    String? sessionId;
    if (listed['sessions'] case final List<Object?> rows) {
      for (final row in rows) {
        if (row case {'session_key': final String key, 'id': final String id}
            when key == threadId) {
          sessionId = id;
          break;
        }
      }
    }
    if (sessionId == null) return const [];
    final Map<String, Object?> pending;
    try {
      pending = await _call(client, 'approval.pending', {
        'session_id': sessionId,
        'profile': ?profile,
      });
    } on GatewayRpcException catch (error) {
      if (error.code == kGatewayMethodNotFound) return const [];
      rethrow;
    }
    return [
      if (pending['approvals'] case final List<Object?> rows)
        for (final row in rows)
          if (row case {'request_id': final String id} when id.isNotEmpty)
            _replayedApproval(id, (row as Map).cast<String, Object?>()),
    ];
  }

  Future<bool> _answerOpenRequest(
    String requestId,
    OpenRequestAnswer answer, {
    String? threadId,
    String? profile,
    bool raisedAsEvent = false,
    DateTime? deadline,
  }) async {
    final client = await _client();
    if (raisedAsEvent) {
      return _answerEventRequest(
        client,
        requestId,
        answer,
        threadId: threadId,
        profile: profile,
        deadline: deadline,
      );
    }
    final result = switch (answer) {
      ApprovalChoiceAnswer(:final choice) => {'choice': choice},
      QuestionAnswer(:final questionId, :final values, :final multiSelect) => {
        'answers': {
          questionId: _clarifyValue(values, multiSelect: multiSelect),
        },
      },
    };
    try {
      _beforeDeadline(deadline);
      final reply = await _call(client, 'request.answer', {
        'id': requestId,
        'result': result,
        'profile': ?profile,
      });
      if (reply['status'] == 'ok') return true;
      if (answer is! ApprovalChoiceAnswer) return false;
    } on GatewayRpcException catch (error) {
      if (error.code != kGatewayMethodNotFound) rethrow;
    }
    return _answerEventRequest(
      client,
      requestId,
      answer,
      threadId: threadId,
      profile: profile,
      deadline: deadline,
    );
  }

  Future<bool> _answerEventRequest(
    GatewayRpcClient client,
    String requestId,
    OpenRequestAnswer answer, {
    required String? threadId,
    required String? profile,
    required DateTime? deadline,
  }) async {
    switch (answer) {
      case QuestionAnswer(:final questionId, :final values, :final multiSelect):
        _beforeDeadline(deadline);
        final reply = await _call(client, 'clarify.respond', {
          'request_id': requestId,
          'answer': _clarifyValue(values, multiSelect: multiSelect),
          if (questionId.isNotEmpty) 'question_id': questionId,
        });
        return reply['status'] != 'expired';
      case ApprovalChoiceAnswer(:final choice):
        if (threadId == null) return false;
        _beforeDeadline(deadline);
        final reply = await _call(client, 'approval.respond', {
          'session_id': threadId,
          'profile': ?profile,
          'request_id': requestId,
          'choice': choice,
        });
        return ((reply['resolved'] as num?) ?? 0) > 0;
    }
  }

  Future<bool> _answerVault(
    String requestId,
    VaultKind kind, {
    String identifier = '',
    String password = '',
    String code = '',
  }) async {
    final open = _awaiting[requestId];
    // A vault prompt is always a server-to-client request: the gateway has
    // no `*.respond` method for it.
    if (open == null || !open.serverRequest) return false;
    final value = switch (kind) {
      VaultKind.saveLogin => {'identifier': identifier, 'password': password},
      VaultKind.unlock => password,
      VaultKind.code => code,
    };
    return _respond(requestId, {'value': value});
  }

  Future<bool> _skipUnsupported(String requestId, UnsupportedKind kind) async {
    final open = _awaiting[requestId];
    if (open == null) return false;
    if (open.serverRequest) return _respond(requestId, {'value': ''});
    final client = _connected();
    if (client == null) return false;
    final (method, key) = switch (kind) {
      UnsupportedKind.sudo => ('sudo.respond', 'password'),
      UnsupportedKind.secret => ('secret.respond', 'value'),
    };
    final result = await client.request(method, {
      'request_id': requestId,
      key: '',
    });
    return result['status'] != 'expired';
  }

  /// Answers a server-to-client request on the open connection, which after a
  /// reconnect is not the one the request arrived on (see [_connected]). The
  /// gateway does not say whether it was still waiting; a request that ended
  /// was already expired by `request.cancel`, and it drops an answer it no
  /// longer waits for.
  bool _respond(String requestId, Map<String, Object?> result) {
    final client = _connected();
    if (client == null) return false;
    client.respond(requestId, result);
    return true;
  }
}

/// The id of the request [event] raises, if it raises one.
String? _requestIdOf(ChatEvent event) => switch (event) {
  ApprovalRequested(:final request) => request.requestId,
  ClarifyRequested(:final request) => request.requestId,
  VaultRequested(:final request) => request.requestId,
  UnsupportedRequested(:final request) => request.requestId,
  _ => null,
};

/// An approval from `approval.pending`, which replays the queue's entries
/// and may leave `choices` out; they are then worked out from the flags the
/// entry does carry, claiming only what the entry allows.
ApprovalRequest _replayedApproval(
  String requestId,
  Map<String, Object?> fields,
) {
  final approval = toApproval(requestId, fields);
  if (approval.choices.isNotEmpty) return approval;
  return ApprovalRequest(
    requestId: approval.requestId,
    command: approval.command,
    description: approval.description,
    toolName: approval.toolName,
    choices: [
      'once',
      if (fields['allow_session'] == true) 'session',
      if (fields['allow_permanent'] == true) 'always',
      'deny',
    ],
  );
}

/// An answer given up on must not go out late.
void _beforeDeadline(DateTime? deadline) {
  if (deadline != null && !DateTime.now().isBefore(deadline)) {
    throw TimeoutException('The answer is past its deadline');
  }
}

String _clarifyValue(List<String> values, {required bool multiSelect}) =>
    multiSelect ? jsonEncode(values) : (values.isEmpty ? '' : values.first);
