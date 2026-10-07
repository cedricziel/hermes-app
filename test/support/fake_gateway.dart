import 'dart:async';
import 'dart:convert';

import 'package:stream_channel/stream_channel.dart';

/// Plays the dashboard's side of the socket: answers each RPC the way the
/// real gateway does and pushes the events a turn produces.
class FakeGateway {
  FakeGateway() {
    _open();
  }

  var _closedByClient = Completer<void>();

  /// Completes when the app closed its end of the current socket.
  Future<void> get closedByClient => _closedByClient.future;

  var _wire = StreamChannelController<String>();

  var _handedOut = false;

  /// Whether the current socket is open. Events recorded while it is down
  /// only reach the replay ring.
  var _socketOpen = false;

  /// Every request received, in order.
  final requests = <Map<String, Object?>>[];

  /// Every response frame the app sent to a server-to-client request.
  final responses = <Map<String, Object?>>[];

  StreamChannel<String> get channel => _wire.local;

  void _open() {
    final wire = _wire = StreamChannelController<String>();
    final closed = _closedByClient = Completer<void>();
    _socketOpen = true;
    wire.foreign.stream.listen(
      _onFrame,
      onDone: () {
        if (identical(_wire, wire)) _socketOpen = false;
        closed.complete();
      },
    );
  }

  /// Opens a socket for the app. The first call gives the socket the
  /// constructor made; each later one is a new socket to the same server,
  /// so the events, seq counters and replay ring carry over.
  Future<StreamChannel<String>> connect() async {
    if (_handedOut) _open();
    _handedOut = true;
    if (sendReady) _greet();
    return _wire.local;
  }

  /// Stamps every event with a `seq`, counted from 1 per runtime session, and
  /// keeps each session's events for `session.events.since`.
  bool stampSeq = false;

  /// Whether a connect sends `gateway.ready` carrying [epoch].
  bool sendReady = false;

  String epoch = 'epoch-1';

  /// Whether `session.events.since` reports that the replay was truncated.
  bool truncateReplay = false;

  /// The `open_requests` `session.events.since` reports.
  List<Object?> openRequests = const [];

  /// Whether `gateway.ping` is refused as an unknown method, as a gateway
  /// that predates the heartbeat refuses it.
  bool pingUnknown = false;

  /// The `status` the `prompt.submit` answer carries.
  String submitStatus = 'streaming';

  /// Whether `session.info {running: false}` follows each turn, as the
  /// gateway sends it once a turn has settled.
  bool emitSessionInfo = false;

  /// The stored id `session.info` reports after a turn; null reports the id
  /// the session was created with.
  String? storedAfterTurn;

  /// Runs after a `session.resume` request arrives and before it is answered,
  /// to send events that reach the app ahead of the answer.
  void Function(FakeGateway gateway)? beforeResumeAnswer;

  /// Runs after a `session.events.since` request arrives and before it is
  /// answered, so the events it sends are in the answer's replay.
  void Function(FakeGateway gateway)? beforeEventsAnswer;

  /// Runs after a `prompt.submit` request arrives and before it is answered,
  /// to send events that reach the app ahead of the submit answer.
  void Function(FakeGateway gateway)? beforeSubmitAnswer;

  /// The sessions `session.active_list` reports, as stored id to status. Null
  /// leaves the request unanswered, as before this knob existed.
  Map<String, String>? activeSessions;

  final _seqs = <String, int>{};
  final _ring = <String, List<Map<String, Object?>>>{};

  void _greet() => _send({
    'method': 'event',
    'params': {
      'type': 'gateway.ready',
      'payload': {'replay_epoch': epoch},
    },
  });

  /// Runs after `prompt.submit` was answered; emits the turn's events.
  void Function(FakeGateway gateway, String sessionId) turn = (_, _) {};

  Map<String, Object?> createResult = {
    'session_id': 'rt-1',
    'stored_session_id': 'stored-1',
  };

  bool rejectSubmit = false;

  /// Requests the gateway never answers, as a socket the OS dropped while the
  /// app slept does not.
  final silent = <String>{};

  /// Every request goes unanswered.
  bool deaf = false;

  /// The runtime session of the latest `prompt.submit`.
  String lastSessionId = '';

  /// When set, `session.create` and `session.resume` fail with this JSON-RPC
  /// error code, as a gateway does for a profile that no longer exists.
  int? sessionErrorCode;

  /// How many approvals `approval.respond` reports resolved.
  int approvalsResolved = 1;

  /// The `status` `clarify.respond` reports.
  String clarifyStatus = 'ok';

  /// The `status` `clarify.lock` reports.
  String lockStatus = 'ok';

  /// The `status` `sudo.respond` and `secret.respond` report.
  String skipStatus = 'ok';

  /// The `status` `session.interrupt` reports.
  String interruptStatus = 'interrupted';

  /// How many messages `session.undo` reports it removed.
  int undoRemoved = 2;

  /// Whether `client.capabilities` fails, as it does on a gateway that
  /// predates server-to-client requests.
  bool capabilitiesUnknown = false;

  /// Attach methods the gateway does not know, as a gateway that predates
  /// them answers.
  final unknownMethods = <String>{};

  /// Attach calls that fail, by `<method> <file name>`: the JSON-RPC error
  /// code and message to answer with.
  final attachFailures = <String, (int, String)>{};

  /// The image paths the gateway queued for the next prompt, as `image.detach`
  /// leaves them.
  final queuedImages = <String>[];

  Object? resumeResult = {'session_id': 'rt-2', 'session_key': 'stored-2'};
  Map<String, Object?> slashResult = {'output': 'Command output'};
  final slashResults = <Map<String, Object?>>[];
  bool slashNeedsDispatch = false;

  Iterable<String> get methods => requests.map((r) => r['method'] as String);

  Map<String, Object?> requestOf(String method) =>
      requests.firstWhere((r) => r['method'] == method);

  void event(
    String type,
    String sessionId, [
    Map<String, Object?> payload = const {},
  ]) {
    final params = <String, Object?>{
      'type': type,
      'session_id': sessionId,
      'payload': payload,
    };
    if (stampSeq) {
      final seq = (_seqs[sessionId] ?? 0) + 1;
      _seqs[sessionId] = seq;
      params['seq'] = seq;
      (_ring[sessionId] ??= []).add(params);
    }
    _send({'method': 'event', 'params': params});
  }

  /// Sends a server-to-client request, the way the gateway asks the client a
  /// question and waits for the response frame carrying the same [id].
  void serverRequest(
    String id,
    String method,
    String sessionId, [
    Map<String, Object?> params = const {},
  ]) => _send({
    'id': id,
    'method': method,
    'params': {'session_id': sessionId, ...params},
  });

  /// Closes the current socket, as the network does. Frames sent while it is
  /// down are dropped, and the ring still keeps the events.
  void drop() {
    _socketOpen = false;
    _wire.foreign.sink.close();
  }

  void _send(Map<String, Object?> message) {
    if (!_socketOpen) return;
    _wire.foreign.sink.add(jsonEncode({'jsonrpc': '2.0', ...message}));
  }

  void _onFrame(String frame) {
    final request = jsonDecode(frame) as Map<String, Object?>;
    if (!request.containsKey('method')) {
      responses.add(request);
      return;
    }
    requests.add(request);
    if (deaf || silent.contains(request['method'])) return;
    final id = request['id'];
    final params = request['params'] as Map<String, Object?>;
    switch (request['method']) {
      case 'session.create' || 'session.resume' when sessionErrorCode != null:
        _send({
          'id': id,
          'error': {
            'code': sessionErrorCode,
            'message': "profile 'gone' not found",
          },
        });
      case 'session.create':
        _send({'id': id, 'result': createResult});
      case 'session.resume':
        beforeResumeAnswer?.call(this);
        final result = resumeResult;
        _send(
          result is Map
              ? {'id': id, 'result': result}
              : {
                  'id': id,
                  'error': {'code': 4007, 'message': 'session not found'},
                },
        );
      case 'session.events.since'
          when unknownMethods.contains('session.events.since'):
        _send({
          'id': id,
          'error': {'code': -32601, 'message': 'unknown method'},
        });
      case 'session.events.since':
        beforeEventsAnswer?.call(this);
        final replaySid = params['session_id'] as String;
        final lastSeen = (params['last_seen'] as num?)?.toInt() ?? 0;
        final replayRing = _ring[replaySid] ?? const <Map<String, Object?>>[];
        final missed = [
          for (final sent in replayRing)
            if ((sent['seq'] as int) > lastSeen) sent,
        ];
        _send({
          'id': id,
          'result': {
            'events': missed,
            'latest_seq': _seqs[replaySid] ?? 0,
            'truncated': truncateReplay,
            'count': missed.length,
            'epoch': epoch,
            'open_requests': openRequests,
          },
        });
      case 'gateway.ping' when pingUnknown:
        _send({
          'id': id,
          'error': {'code': -32601, 'message': 'unknown method'},
        });
      case 'gateway.ping':
        _send({
          'id': id,
          'result': {'ok': true},
        });
      case 'client.capabilities' when capabilitiesUnknown:
        _send({
          'id': id,
          'error': {'code': -32601, 'message': 'unknown method'},
        });
      case 'client.capabilities':
        _send({
          'id': id,
          'result': {
            'server_requests': ['approval', 'clarify', 'sudo', 'secret'],
          },
        });
      case 'config.set':
        _send({
          'id': id,
          'result': {'key': params['key'], 'value': params['value']},
        });
      case 'commands.catalog':
        _send({
          'id': id,
          'result': {
            'pairs': [
              ['/help', 'Show help'],
              ['/model', 'Choose a model'],
              ['/quit', 'Exit the CLI'],
            ],
            'commands': {
              '/quit': {'desktop': 'terminal'},
            },
          },
        });
      case 'slash.exec' when slashNeedsDispatch:
        _send({
          'id': id,
          'error': {'code': 4018, 'message': 'dispatch command'},
        });
      case 'slash.exec' || 'command.dispatch':
        _send({
          'id': id,
          'result': slashResults.isEmpty
              ? slashResult
              : slashResults.removeAt(0),
        });
      case 'session.interrupt':
        _send({
          'id': id,
          'result': {'status': interruptStatus},
        });
      case 'session.undo' when unknownMethods.contains('session.undo'):
        _send({
          'id': id,
          'error': {'code': -32601, 'message': 'unknown method'},
        });
      case 'session.undo':
        _send({
          'id': id,
          'result': {'removed': undoRemoved},
        });
      case 'sudo.respond' || 'secret.respond':
        _send({
          'id': id,
          'result': {'status': skipStatus},
        });
      case 'clarify.lock':
        _send({
          'id': id,
          'result': {'status': lockStatus, 'remaining': <String>[]},
        });
      case 'approval.respond':
        _send({
          'id': id,
          'result': {'resolved': approvalsResolved},
        });
      case 'clarify.respond':
        _send({
          'id': id,
          'result': {'status': clarifyStatus},
        });
      case 'image.attach_bytes' || 'file.attach' || 'image.detach'
          when unknownMethods.contains(request['method']):
        _send({
          'id': id,
          'error': {'code': -32601, 'message': 'unknown method'},
        });
      case 'image.attach_bytes' || 'file.attach'
          when attachFailures.containsKey(
            '${request['method']} ${params['filename'] ?? params['name']}',
          ):
        final (code, message) =
            attachFailures['${request['method']} ${params['filename'] ?? params['name']}']!;
        _send({
          'id': id,
          'error': {'code': code, 'message': message},
        });
      case 'image.attach_bytes':
        final path =
            '/home/u/.hermes/images/upload_${queuedImages.length + 1}.png';
        queuedImages.add(path);
        _send({
          'id': id,
          'result': {
            'attached': true,
            'path': path,
            'count': queuedImages.length,
            'remainder': '',
            'text': '[User attached image: upload.png]',
          },
        });
      case 'file.attach':
        final name = params['name'] as String;
        _send({
          'id': id,
          'result': {
            'attached': true,
            'name': name,
            'path': '/home/u/.hermes/attachments/$name',
            'ref_path': 'attachments/$name',
            'ref_text': '@file:attachments/$name',
            'uploaded': true,
          },
        });
      case 'image.detach':
        queuedImages.remove(params['path']);
        _send({
          'id': id,
          'result': {'detached': true, 'count': queuedImages.length},
        });
      case 'prompt.submit' when rejectSubmit:
        _send({
          'id': id,
          'error': {'code': 4009, 'message': 'session busy'},
        });
      case 'session.active_list' when activeSessions != null:
        _send({
          'id': id,
          'result': {
            'sessions': [
              for (final entry in activeSessions!.entries)
                {'session_key': entry.key, 'status': entry.value},
            ],
          },
        });
      case 'prompt.submit':
        beforeSubmitAnswer?.call(this);
        _send({
          'id': id,
          'result': {'status': submitStatus},
        });
        lastSessionId = params['session_id'] as String;
        turn(this, lastSessionId);
        if (emitSessionInfo) {
          event('session.info', lastSessionId, {
            'running': false,
            'stored_session_id':
                storedAfterTurn ?? createResult['stored_session_id'],
          });
        }
    }
  }
}
