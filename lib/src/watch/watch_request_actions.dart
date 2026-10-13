import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../chat/chat_models.dart';
import '../chat/chat_transport.dart';
import 'watch_context.dart';

/// Transient request details and answers, bound to the phone's live context.
/// Call [clear] on lock activation, logout, and context departure.
class WatchRequestActions {
  WatchRequestActions({
    required this.context,
    required this.allowed,
    required this.transport,
    this.epoch = _zero,
  });
  static int _zero() => 0;
  final int Function() epoch;
  final WatchContext? Function() context;
  final bool Function() allowed;
  final ChatTransport? Function() transport;
  final _live = <String, _LiveRequest>{};
  final _attempted = <String, String>{};
  final _knownQuestions = <String>{};
  int _generation = 0;
  static const payloadLimit = 60000;

  bool eligible(
    WatchContext scope,
    String? profile,
    String thread,
    String id,
    String kind,
  ) {
    if (!allowed() ||
        context()?.id != scope.id ||
        context()?.revision != scope.revision) {
      return false;
    }
    final live = _live[_key(scope, profile, thread, id)];
    return live != null && _details(live)?['kind'] == kind;
  }

  void closeOwner(ChatTransport owner) {
    _live.removeWhere((key, value) => identical(value.owner, owner));
  }

  void clearDetails() {
    _generation++;
    _live.clear();
  }

  void clear() {
    _generation++;
    _live.clear();
    _attempted.clear();
    _knownQuestions.clear();
  }

  String _key(WatchContext scope, String? profile, String thread, String id) =>
      jsonEncode([scope.id, scope.revision, profile, thread, id]);

  /// Receives request lifecycle events from their owning live transport.
  void observe(
    WatchContext scope,
    String? profile,
    String thread,
    ChatTransport owner,
    ChatEvent event,
  ) {
    if (!allowed() ||
        context()?.id != scope.id ||
        context()?.revision != scope.revision) {
      return;
    }
    switch (event) {
      case ApprovalRequested(:final request, :final raisedAsEvent):
        _live[_key(scope, profile, thread, request.requestId)] = _LiveRequest(
          request,
          owner,
          raisedAsEvent,
        );
      case ClarifyRequested(:final request, :final raisedAsEvent):
        _knownQuestions.add(_key(scope, profile, thread, request.requestId));
        _live[_key(scope, profile, thread, request.requestId)] = _LiveRequest(
          request,
          owner,
          raisedAsEvent,
        );
      case InputRequestExpired(:final requestId):
        final key = _key(scope, profile, thread, requestId);
        if (identical(_live[key]?.owner, owner)) {
          _live.remove(key);
        }
      case InputRequestsCancelled(:final requestIds):
        _live.removeWhere(
          (key, value) =>
              identical(value.owner, owner) &&
              (requestIds.isEmpty ||
                  requestIds.contains(value.request.requestId)),
        );
      case _ when beginsTurn(event):
        final owned = _live.entries
            .where((entry) => identical(entry.value.owner, owner))
            .toList();
        if (owned.length == 1) _live.remove(owned.single.key);
      case ReplyCompleted():
        _live.removeWhere((key, value) => identical(value.owner, owner));
      default:
        break;
    }
  }

  /// Returns a complete bounded payload or a content-free phone fallback.
  Future<Map<String, Object?>> handle(Map<Object?, Object?> input) async {
    final scope = context();
    final thread = WatchThreadId.decode(input['threadId']);
    final id = input['requestId'];
    if (scope == null ||
        thread == null ||
        thread.contextId != scope.id ||
        input['contextId'] != scope.id ||
        input['revision'] != scope.revision) {
      return _error('context_changed');
    }
    if (!allowed() || input['requestEpoch'] != epoch()) return _error('locked');
    if (id is! String ||
        id.isEmpty ||
        !['request_details', 'request_answer'].contains(input['op'])) {
      return _error('unavailable');
    }
    final generation = _generation;
    final requestEpoch = epoch();
    bool current() =>
        allowed() &&
        epoch() == requestEpoch &&
        generation == _generation &&
        context()?.id == scope.id &&
        context()?.revision == scope.revision;
    final key = _key(scope, thread.profile, thread.sessionId, id);
    ChatTransport? fresh;
    try {
      var live = _live[key];
      if (live == null && _knownQuestions.contains(key)) {
        return _error('unavailable');
      }
      if (live?.request is! ClarifyRequest) {
        final chat = fresh = transport();
        if (chat == null) return _error('unavailable');
        final approvals = await chat.pendingApprovals(
          threadId: thread.sessionId,
          profile: thread.profile,
        );
        if (!current()) return _error(allowed() ? 'context_changed' : 'locked');
        final matches = approvals.where(
          (request) =>
              request.requestId == id &&
              request.status == InputRequestStatus.pending,
        );
        if (matches.length != 1) {
          return {
            'ok': true,
            'status': 'expired',
            'requestEpoch': requestEpoch,
          };
        }
        final approval = matches.single;
        live = _LiveRequest(approval, chat, live?.raisedAsEvent ?? false);
      }
      if (!current()) return _error('locked');
      if (live == null || live.request.status != InputRequestStatus.pending) {
        return {'ok': true, 'status': 'expired', 'requestEpoch': requestEpoch};
      }
      final details = _details(live);
      if (details != null) {
        details['fingerprint'] = sha256
            .convert(utf8.encode(jsonEncode(details)))
            .toString();
      }
      if (details == null ||
          utf8.encode(jsonEncode({...scope.fields, ...details})).length >=
              payloadLimit) {
        return _error('unavailable');
      }
      if (input['op'] == 'request_details') {
        return {'ok': true, 'requestEpoch': requestEpoch, ...details};
      }
      if (input['fingerprint'] != details['fingerprint']) {
        return _error('unavailable');
      }
      final request = live.request;
      final qid = input['qid'];
      final attemptKey =
          '$key/${request is ClarifyRequest && request.batch ? qid : ''}';
      if (_attempted[attemptKey] case final String status) {
        return {'ok': true, 'status': status, 'requestEpoch': requestEpoch};
      }
      OpenRequestAnswer answer;
      ClarifyQuestion? question;
      switch (request) {
        case ApprovalRequest(:final choices, :final command):
          final choice = input['choice'];
          if (choice is! String ||
              !choices.contains(choice) ||
              input['command'] != command) {
            return _error('unavailable');
          }
          answer = ApprovalChoiceAnswer(choice);
        case ClarifyRequest(:final questions):
          final matches = questions.where((item) => item.qid == qid);
          if (matches.length != 1 || live.accepted.contains(qid)) {
            return _error('unavailable');
          }
          question = matches.single;
          final raw = input['values'];
          if (raw is! List ||
              raw.isEmpty ||
              raw.any((value) => value is! String || value.trim().isEmpty)) {
            return _error('unavailable');
          }
          final values = raw.cast<String>();
          if (values.toSet().length != values.length ||
              (!question.multiSelect && values.length != 1) ||
              (question.choices.isNotEmpty &&
                  values.any((value) => !question!.choices.contains(value)))) {
            return _error('unavailable');
          }
          answer = QuestionAnswer(
            questionId: question.qid,
            values: values,
            multiSelect: question.multiSelect,
          );
        default:
          return _error('unavailable');
      }
      if (utf8.encode(jsonEncode(input)).length >= payloadLimit) {
        return _error('unavailable');
      }
      if (!current() ||
          (request is ClarifyRequest && !identical(_live[key], live))) {
        return _error('locked');
      }
      _attempted[attemptKey] = 'uncertain';
      final accepted = request is ClarifyRequest && request.batch
          ? await live.owner.answerClarify(
              id,
              (answer as QuestionAnswer).values,
              questionId: question!.qid,
              multiSelect: question.multiSelect,
            )
          : await live.owner.answerOpenRequest(
              id,
              answer,
              threadId: thread.sessionId,
              profile: thread.profile,
              raisedAsEvent: live.raisedAsEvent,
              deadline: DateTime.now().add(const Duration(seconds: 20)),
            );
      if (!current()) return _error('locked');
      _attempted[attemptKey] = accepted ? 'accepted' : 'expired';
      if (accepted && question != null) {
        live.accepted.add(question.qid);
        live.acceptedFingerprints[question.qid] =
            input['fingerprint'] as String;
      }
      if (!accepted ||
          request is ApprovalRequest ||
          (request is ClarifyRequest && !request.batch)) {
        _live.remove(key);
      }
      return {
        'ok': true,
        'status': accepted ? 'accepted' : 'expired',
        'requestEpoch': requestEpoch,
      };
    } on Object {
      return {'ok': true, 'status': 'uncertain', 'requestEpoch': requestEpoch};
    } finally {
      await fresh?.close().catchError((Object _) {});
    }
  }

  Map<String, Object?>? _details(_LiveRequest live) => switch (live.request) {
    ApprovalRequest(
      :final requestId,
      :final command,
      :final description,
      :final choices,
    )
        when command.isNotEmpty &&
            choices.isNotEmpty &&
            choices.toSet().length == choices.length &&
            choices.every(['once', 'session', 'always', 'deny'].contains) =>
      {
        'kind': 'approval',
        'requestId': requestId,
        'command': command,
        'description': description,
        'choices': choices,
      },
    ClarifyRequest(:final requestId, :final questions, :final batch)
        when questions.isNotEmpty &&
            (batch || questions.length == 1) &&
            questions.map((q) => q.qid).toSet().length == questions.length &&
            questions.every(
              (q) =>
                  q.question.isNotEmpty &&
                  (!batch || q.qid.isNotEmpty) &&
                  q.choices.toSet().length == q.choices.length &&
                  q.choices.every((v) => v.isNotEmpty),
            ) =>
      {
        'kind': 'question',
        'requestId': requestId,
        'batch': batch,
        'accepted': live.accepted.toList(),
        'acceptedFingerprints': live.acceptedFingerprints,
        'questions': [
          for (final q in questions)
            {
              'qid': q.qid,
              'prompt': q.question,
              'choices': q.choices,
              'multiSelect': q.multiSelect,
            },
        ],
      },
    _ => null,
  };
  static Map<String, Object?> _error(String error) => {
    'ok': false,
    'error': error,
  };
}

class _LiveRequest {
  _LiveRequest(this.request, this.owner, this.raisedAsEvent);
  final InputRequest request;
  final ChatTransport owner;
  final bool raisedAsEvent;
  final accepted = <String>{};
  final acceptedFingerprints = <String, String>{};
}
