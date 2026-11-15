import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:hermes_app/src/voice/calls/call_agent.dart';
import 'package:hermes_app/src/voice/calls/voice_call.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:stream_channel/stream_channel.dart';

import '../../support/fake_chat_transport.dart';
import 'fakes.dart';

/// The call, the real [ChatCallAgent] and the real [ChatController], which the
/// fake agent of the other call tests cannot stand in for.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeChatTransport transport;
  late ChatController chat;
  late ChatCallAgent agent;
  late FakeCallBridge bridge;
  late VoiceCall call;
  late AttentionNotifier attention;
  final logged = <(String, Map<String, Object>)>[];

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    logged.clear();
    transport = FakeChatTransport();
    attention = AttentionNotifier(
      service: null,
      settings: null,
      onOpen: (_) {},
    );
    chat = ChatController(
      transport: transport,
      attention: attention,
      report: (_) {},
    )..newThread();
    agent = ChatCallAgent(chat, onContextLost: () {});
    bridge = FakeCallBridge();
    final socket = StreamChannelController<Object?>();
    socket.foreign.stream.listen((_) {});
    call = VoiceCall(
      bridge: bridge,
      agent: agent,
      consented: true,
      connect: ([_ = const {}]) async => socket.local,
      prepare: () async {},
      transcribe: (_) async => 'Hello',
      events: (name, [attributes = const {}]) => logged.add((name, attributes)),
    );
  });
  tearDown(() async {
    if (!call.ended) await call.end();
    call.dispose();
    chat.dispose();
    attention.dispose();
    unawaited(bridge.controller.close());
  });

  Future<void> activate() async {
    await call.start();
    bridge.emit('activated');
    await pumpEventQueue();
  }

  test(
    'a typed prompt Hermes takes as its stop phrase ends the call',
    () async {
      await activate();
      expect(await chat.submit('stop', const []), isTrue);
      transport.sends.single
        ..emit(const PromptAccepted(PromptAccepted.voiceStopped))
        ..finish();
      await pumpEventQueue();
      expect(call.ended, isTrue);
      expect(call.endReason, 'voice_stopped');
      expect(
        logged.singleWhere((e) => e.$1 == 'voice_call.ended').$2['reason'],
        'voice_stopped',
      );
    },
  );

  test(
    'a typed prompt that is not a stop phrase leaves the call alone',
    () async {
      await activate();
      await chat.submit('hello', const []);
      transport.sends.single
        ..emit(const ReplyCompleted('Hi'))
        ..finish();
      await pumpEventQueue();
      expect(call.ended, isFalse);
    },
  );
}
