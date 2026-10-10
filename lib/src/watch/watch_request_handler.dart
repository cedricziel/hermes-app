import 'dart:async';
import 'dart:typed_data';

import '../chat/chat_models.dart';
import '../chat/chat_transport.dart';
import '../chat/hermes_chat_repository.dart';
import '../notifications/attention_policy.dart';

/// Answers the requests the watch app relays through the phone. Requests and
/// replies are plain maps of property-list types, the shape WatchConnectivity
/// carries: `{'op': 'threads' | 'messages' | 'send' | 'transcribe', ...}` in, `{'ok': true,
/// ...}` or `{'ok': false, 'error': 'signed_out' | 'bad_request' | 'failed'}`
/// out.
///
/// The watch shows a glance, so lists are cut to what fits on it.
///
/// A thread id the watch sees is tied to the profile it was listed under
/// (`<encoded profile>/<session id>`), because the same session id can exist in
/// two profiles. The watch treats it as opaque and hands it back, and the
/// thread is read and continued in that profile, even after a switch.
class WatchRequestHandler {
  WatchRequestHandler({
    required this.repository,
    required this.transport,
    required this.activeProfile,
    this.serverUrl = _noServer,
    this.connecting = _never,
    this.ready = _alreadyReady,
    this.sendTimeout = const Duration(seconds: 60),
    this.waitingTimeout = const Duration(minutes: 15),
    this.waitingHold = const Duration(seconds: 20),
    this.announce = _ignore,
    this.appLock = _off,
    this.transcribeOnDevice,
  });

  /// What the watch is told when the agent asks for something only the phone's
  /// own chat could answer. It names neither the command nor the question.
  static const cannotAnswerText =
      "Hermes asked for something the watch can't answer. "
      'Ask again on your iPhone.';

  /// What the watch shows for a successful reply that has no text at all.
  static const emptyReplyText = 'Hermes replied without any text.';

  /// What a retried send answers when Hermes had the prompt but has not
  /// finished replying to it.
  static const stillReplyingText =
      'Hermes is still replying. Open the chat again in a moment.';

  /// The title of a notification for a chat the gateway has not named.
  static const untitledChat = 'Hermes';

  static const threadLimit = 20;
  static const messageLimit = 20;
  static const contentLimit = 4000;

  /// How many sends are remembered by their id, so a retry finds its first
  /// try.
  static const sendMemory = 16;

  /// Both return null while nobody is signed in.
  final HermesChatRepository? Function() repository;
  final ChatTransport? Function() transport;
  final Future<String?> Function() activeProfile;

  /// The canonical address of the connected server, which the watch only
  /// passes on for Handoff. Null when there is none.
  final String? Function() serverUrl;

  /// Whether the phone is still getting ready to serve, rather than signed
  /// out: restoring its session, reaching the server, or mid sign-in. Then
  /// the watch is told to open the phone app instead of to sign in.
  final bool Function() connecting;

  /// Completes once the phone is no longer [connecting], or has given up
  /// waiting. A watch request often wakes the phone app, which then needs a
  /// moment to restore its session.
  final Future<void> Function() ready;

  /// How long a send may go without an event before it is given up on.
  final Duration sendTimeout;

  /// The same while the turn waits on the user's approval or answer, which
  /// they give from the notification.
  final Duration waitingTimeout;

  /// How long a retry of a send that waited on the user is held before it is
  /// answered with the state again. Each answer must come within the phone's
  /// background time, and the watch's next retry wakes the phone again.
  final Duration waitingHold;

  /// Tells the user a turn they sent from the watch is over or waits on
  /// them. The watch may have lost sight of it by then, so it is called
  /// whatever the phone shows. Answers whether the notification was posted.
  final Future<bool> Function(AttentionNotification notification) announce;

  /// Whether App Lock is on: a request is then announced without its text
  /// or buttons, so a watch send cannot wait for an answer to it.
  final bool Function() appLock;

  /// What the phone's own recognizer heard in a voice message, or null when
  /// it is not the one to transcribe it; the server transcribes it then.
  final Future<String?> Function(Uint8List audio)? transcribeOnDevice;

  static Future<bool> _ignore(AttentionNotification _) async => false;

  static bool _off() => false;

  static String? _noServer() => null;

  static bool _never() => false;

  static Future<void> _alreadyReady() async {}

  /// Recent sends by the id the watch gave them, oldest first.
  final _sends = <String, _SendAttempt>{};

  Future<Map<String, Object?>> handle(Map<Object?, Object?> request) async {
    try {
      if (connecting()) {
        await ready();
      }
      return switch (request['op']) {
        'threads' => await _threads(),
        'messages' => await _messages(request['threadId']),
        'send' => await _sendOnce(
          request['sendId'],
          request['threadId'],
          request['text'],
          retry: request['retry'] == true,
          waits: request['waits'] == true,
        ),
        'transcribe' => await _transcribe(
          request['audio'],
          request['mimeType'],
        ),
        _ => _error('bad_request'),
      };
    } on Object {
      return _error('failed');
    }
  }

  Future<Map<String, Object?>> _threads() async {
    final repo = repository();
    if (repo == null) return _noSession();
    final profile = await activeProfile();
    final threads = await repo.loadThreads(
      limit: threadLimit,
      profile: profile,
    );
    return {
      'ok': true,
      'threads': [
        for (final thread in threads.take(threadLimit))
          {
            'id': _bind(profile, thread.id),
            'title': thread.title,
            'updatedAt': thread.updatedAt.millisecondsSinceEpoch ~/ 1000,
            'pinned': thread.pinned,
            ..._handoff(profile, thread.id),
          },
      ],
    };
  }

  Future<Map<String, Object?>> _messages(Object? threadId) async {
    final thread = _unbind(threadId);
    if (thread == null) return _error('bad_request');
    final repo = repository();
    if (repo == null) return _noSession();
    final messages =
        <({ChatMessage message, String text, List<String> tools})>[];
    // Tools called since the last text, named on the text that follows them.
    final used = <String>{};
    for (final message in await repo.loadMessages(
      thread.id,
      profile: thread.profile,
    )) {
      if (message.role == ChatRole.user) used.clear();
      final text = _text(message);
      if (text.isNotEmpty) {
        messages.add((message: message, text: text, tools: [...used]));
        used.clear();
      }
      used.addAll(message.toolCalls.map((call) => call.name));
    }
    return {
      'ok': true,
      'messages': [
        for (final (:message, :text, :tools) in messages.skip(
          messages.length > messageLimit ? messages.length - messageLimit : 0,
        ))
          {
            'id': message.id,
            'role': message.role == ChatRole.user ? 'user' : 'assistant',
            'content': _cut(text),
            'at': message.createdAt.millisecondsSinceEpoch ~/ 1000,
            if (tools.isNotEmpty) 'tools': tools,
          },
      ],
    };
  }

  /// Everything [message] says, in the order it was written: a turn that
  /// called tools keeps its text in [ChatMessage.sealedProse], not in
  /// [ChatMessage.content].
  static String _text(ChatMessage message) {
    final display = message.displayText;
    return [
      for (final prose in message.sealedProse) prose.text.trim(),
      (display != null && display.trim().isNotEmpty ? display : message.content)
          .trim(),
    ].where((part) => part.isNotEmpty).join('\n\n');
  }

  Future<Map<String, Object?>> _transcribe(
    Object? audio,
    Object? mimeType,
  ) async {
    if (audio is! Uint8List || audio.isEmpty || mimeType is! String) {
      return _error('bad_request');
    }
    final repo = repository();
    if (repo == null) return _noSession();
    final heard = await _heardOnDevice(audio);
    if (heard != null) return {'ok': true, 'text': heard, 'engine': 'device'};
    final text = await repo.transcribe(
      audio,
      mimeType: mimeType,
      profile: await activeProfile(),
      timeout: HermesChatRepository.transcribeTimeout(audio.length),
    );
    return {'ok': true, 'text': text, 'engine': 'hermes'};
  }

  /// A recognizer failure is no answer: the server gets the recording then.
  Future<String?> _heardOnDevice(Uint8List audio) async {
    try {
      return await transcribeOnDevice?.call(audio);
    } on Object {
      return null;
    }
  }

  /// Sends [text] unless the send [id] names already reached Hermes. The
  /// watch retries with the same id when it lost sight of a send: the phone
  /// may have been suspended mid-turn, or the watch may have gone to sleep.
  /// A retry joins a send still running, repeats a reply already given, and
  /// for a send that failed after Hermes had the prompt reads the chat
  /// instead, so the agent never gets the prompt twice.
  ///
  /// A send that waits on the user answers early with `waiting`, and the
  /// watch retries to keep waiting: see [_poll].
  ///
  /// A [retry] is the watch asking again about a send that answered
  /// `waiting`. When this phone app no longer knows it, as after iOS ended
  /// the app meanwhile, the chat is read instead: sending it again would give
  /// the agent the prompt twice.
  Future<Map<String, Object?>> _sendOnce(
    Object? id,
    Object? threadId,
    Object? text, {
    bool retry = false,
    bool waits = false,
  }) async {
    if (id is! String || id.isEmpty) {
      final attempt = _SendAttempt();
      return attempt.reply = _send(threadId, text, attempt);
    }
    if (_sends[id] case final earlier?) {
      final reply = await _poll(earlier, fresh: false);
      if (!earlier.finished || reply['ok'] == true) return reply;
      if (earlier.reached) return _afterLostReply(earlier);
      _sends.remove(id);
    } else if (retry) {
      final thread = _unbind(threadId);
      if (thread == null) return _error('failed');
      return _afterLostReply(
        _SendAttempt()
          ..profile = thread.profile
          ..threadId = thread.id,
      );
    }
    final attempt = _SendAttempt()..waits = waits;
    attempt.reply = _send(
      threadId,
      text,
      attempt,
    ).catchError((Object _) => _error('failed'));
    unawaited(attempt.reply.then((_) => attempt.finished = true));
    _sends[id] = attempt;
    while (_sends.length > sendMemory) {
      _sends.remove(_sends.keys.first);
    }
    return _poll(attempt, fresh: true);
  }

  /// The reply of [attempt] once it is over, or its waiting state as soon as
  /// that is news to the watch: on a [fresh] send when it starts waiting, on
  /// a retry when the state changes. A retry of a send that has waited is
  /// also answered after [waitingHold] with the state as it is.
  Future<Map<String, Object?>> _poll(
    _SendAttempt attempt, {
    required bool fresh,
  }) async {
    final shown = fresh ? null : attempt.reported;
    var held = false;
    final hold = !fresh && attempt.waited
        ? Future<void>.delayed(waitingHold).then((_) => held = true)
        : null;
    while (true) {
      if (attempt.finished) return attempt.reply;
      if (attempt.waiting != shown || held) {
        attempt.reported = attempt.waiting;
        return {
          'ok': true,
          ..._threadEntry(attempt.profile, attempt.threadId),
          'waiting': attempt.waiting ?? 'working',
        };
      }
      await Future.any([attempt.changed, attempt.reply, ?hold]);
    }
  }

  /// What the chat of a send that failed after reaching Hermes holds now:
  /// the reply, or word that Hermes is still on it.
  Future<Map<String, Object?>> _afterLostReply(_SendAttempt attempt) async {
    final threadId = attempt.threadId;
    final repo = repository();
    if (repo == null) return _noSession();
    if (threadId == null) return _error('failed');
    final messages = await repo.loadMessages(
      threadId,
      profile: attempt.profile,
    );
    final last = messages.reversed
        .map((message) => (message: message, text: _text(message)))
        .where((entry) => entry.text.isNotEmpty)
        .firstOrNull;
    return {
      'ok': true,
      ..._threadEntry(attempt.profile, threadId),
      'text': last != null && last.message.role == ChatRole.assistant
          ? _cut(last.text)
          : stillReplyingText,
      'failed': false,
    };
  }

  Future<Map<String, Object?>> _send(
    Object? threadId,
    Object? text,
    _SendAttempt attempt,
  ) async {
    if (text is! String || text.trim().isEmpty) return _error('bad_request');
    final thread = threadId == null ? null : _unbind(threadId);
    if (threadId != null && thread == null) return _error('bad_request');
    final chat = transport();
    if (chat == null) return _noSession();
    String? profile;
    String? boundId;
    var title = untitledChat;
    final streamed = StringBuffer();
    final tools = <String>{};

    /// Posts what [event] deserves; answers whether it was posted with
    /// buttons that answer a request.
    Future<bool> announce(ChatEvent event) async {
      final id = boundId;
      if (id == null) return false;
      final notification = attentionFor(
        event: event,
        thread: ChatThread(id: id, title: title, updatedAt: DateTime.now()),
        appFocused: false,
        selectedThreadId: null,
        enabled: true,
        profile: profile,
        appLock: appLock(),
      );
      if (notification == null) return false;
      final posted = await this.announce(notification);
      return posted && notification.request != null;
    }

    Map<String, Object?> cannotAnswer() => {
      'ok': true,
      ..._threadEntry(profile, boundId),
      'text': cannotAnswerText,
      'failed': false,
    };

    StreamIterator<ChatEvent>? events;
    try {
      profile = thread != null ? thread.profile : await activeProfile();
      boundId = thread?.id;
      attempt
        ..profile = profile
        ..threadId = boundId;
      final turn = events = StreamIterator(
        chat.send(threadId: boundId, profile: profile, text: text),
      );
      while (await turn.moveNext().timeout(
        attempt.waiting == null ? sendTimeout : waitingTimeout,
      )) {
        final event = turn.current;
        attempt.reached = true;
        // The turn Hermes ran ahead of the prompt asks too.
        final own = event is UnsolicitedEvent ? event.event : event;
        switch (own) {
          case ApprovalRequested(:final request):
            // Announced either way; only an answerable notification, for a
            // watch that can show it, is worth waiting for.
            final answerable = await announce(own);
            if (!attempt.waits || !answerable) return cannotAnswer();
            attempt.open(request.requestId, 'approval');
            continue;
          case ClarifyRequested(:final request):
            final answerable = await announce(own);
            if (!attempt.waits || !answerable) return cannotAnswer();
            attempt.open(request.requestId, 'question');
            continue;
          case VaultRequested() || UnsupportedRequested():
            unawaited(announce(own));
            return cannotAnswer();
          case InputRequestExpired(:final requestId):
            attempt.close([requestId]);
          case InputRequestsCancelled(:final requestIds):
            attempt.close(requestIds);
          case _ when beginsTurn(own):
            attempt.progressed();
          default:
        }
        switch (event) {
          case ThreadBound(:final threadId):
            boundId = threadId;
            attempt.threadId = threadId;
          case ThreadTitled(title: final named):
            title = named;
          case ReplyDelta(:final text):
            streamed.write(text);
          case ToolStarted(:final name):
            tools.add(name);
          case ReplyCompleted(:final text, :final failed):
            unawaited(announce(event));
            return {
              'ok': true,
              ..._threadEntry(profile, boundId),
              'text': _cut(failed ? text : _shown(text, streamed.toString())),
              'failed': failed,
              if (tools.isNotEmpty) 'tools': [...tools],
            };
          default:
        }
      }
      unawaited(announce(const ReplyCompleted('', failed: true)));
      return _error('failed');
    } on Object {
      unawaited(announce(const ReplyCompleted('', failed: true)));
      rethrow;
    } finally {
      unawaited(events?.cancel());
      await chat.close();
    }
  }

  /// The `threadId` entry of a reply, left out when there is no thread: a null
  /// is not a property-list type and WatchConnectivity would refuse the reply.
  /// It also names the chat for Handoff, so a chat started on the watch can be
  /// continued before the list is loaded again.
  Map<String, Object?> _threadEntry(String? profile, String? id) => id == null
      ? const {}
      : {'threadId': _bind(profile, id), ..._handoff(profile, id)};

  /// What a Handoff to the phone or Mac needs, with the raw session id since
  /// the thread id the watch sees is bound to a profile. Left out unless the
  /// server and the profile are both known: the receivers reject less.
  Map<String, Object?> _handoff(String? profile, String sessionId) {
    final server = serverUrl();
    if (server == null || profile == null || profile.trim().isEmpty) {
      return const {};
    }
    return {'serverUrl': server, 'profile': profile, 'sessionId': sessionId};
  }

  static String _bind(String? profile, String sessionId) =>
      '${Uri.encodeComponent(profile ?? '')}/$sessionId';

  static _Thread? _unbind(Object? threadId) {
    if (threadId is! String) return null;
    final slash = threadId.indexOf('/');
    if (slash < 0 || slash == threadId.length - 1) return null;
    try {
      final profile = Uri.decodeComponent(threadId.substring(0, slash));
      return _Thread(
        profile.isEmpty ? null : profile,
        threadId.substring(slash + 1),
      );
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    }
  }

  /// The final [text] of a successful reply, else what streamed, else a note
  /// that there was nothing, so the watch never shows an empty bubble.
  static String _shown(String text, String streamed) {
    if (text.trim().isNotEmpty) return text;
    return streamed.trim().isNotEmpty ? streamed : emptyReplyText;
  }

  static String _cut(String text) => text.length <= contentLimit
      ? text
      : '${text.substring(0, contentLimit)}…';

  Map<String, Object?> _noSession() =>
      _error(connecting() ? 'unavailable' : 'signed_out');

  static Map<String, Object?> _error(String code) => {
    'ok': false,
    'error': code,
  };
}

class _SendAttempt {
  late final Future<Map<String, Object?>> reply;
  bool finished = false;
  String? profile;
  String? threadId;

  /// Hermes answered something, so it has the prompt.
  bool reached = false;

  /// Whether the watch can be answered `waiting`; an older one cannot.
  bool waits = false;

  /// The requests the turn waits on, oldest first, with their kind.
  final _open = <String, String>{};

  /// `approval` or `question` while the turn waits on the user: the kind of
  /// the newest open request.
  String? get waiting => _open.isEmpty ? null : _open.values.last;

  /// The state the watch was last told.
  String? reported;

  /// Whether the turn ever waited on the user.
  bool waited = false;

  var _changed = Completer<void>();

  /// Completes when [waiting] next changes.
  Future<void> get changed => _changed.future;

  void open(String requestId, String kind) =>
      _update(() => _open[requestId] = kind);

  /// [requestIds] went away; none named means every one.
  void close(List<String> requestIds) => _update(
    () => requestIds.isEmpty ? _open.clear() : requestIds.forEach(_open.remove),
  );

  /// The turn went on, which an answered request lets it do. Which one is not
  /// said, so this only counts when one request alone is open; with more,
  /// their expiry or withdrawal closes them.
  void progressed() => _update(() {
    if (_open.length == 1) _open.clear();
  });

  void _update(void Function() change) {
    final before = waiting;
    change();
    waited = waited || waiting != null;
    if (waiting == before) return;
    final changed = _changed;
    _changed = Completer<void>();
    changed.complete();
  }
}

class _Thread {
  const _Thread(this.profile, this.id);

  /// Null for a thread listed by a server without profiles.
  final String? profile;
  final String id;
}
