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
