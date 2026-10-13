import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/moa_progress_state.dart';
import 'package:hermes_app/src/chat/owned_session_transport.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';

import 'support/fake_chat_transport.dart';

class _Source extends FakeChatTransport implements OwnedSessionTransport {
  final changes = StreamController<OwnedSessionChange>.broadcast(sync: true);
  OwnedSessionBinding? current;
  @override
  Stream<OwnedSessionChange> get ownedSessions => changes.stream;
  @override
  OwnedSessionBinding? ownedSessionFor(String threadId, {String? profile}) =>
      threadId == 'stored' && current?.profile == profile ? current : null;
  @override
  Future<Map<String, Object?>> readOwnedSession(
    OwnedSessionBinding binding,
    String method,
  ) async => const {};
  void publish(OwnedSessionBinding binding, {bool connected = true}) {
    current = connected ? binding : null;
    changes.add(OwnedSessionChange('stored', binding, connected: connected));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Source source;
  late ChatController chat;
  late AttentionNotifier attention;
  late ValueNotifier<bool> activity;
  late OwnedSessionBinding binding;
  setUp(() async {
    source = _Source();
    activity = ValueNotifier(true);
    attention = AttentionNotifier(
      service: null,
      settings: null,
      onOpen: (_) {},
    );
    binding = OwnedSessionBinding(
      connection: Object(),
      runtimeId: 'runtime',
      profile: null,
    );
    chat = ChatController(
      transport: source,
      activity: activity,
      attention: attention,
      report: (_) {},
    );
    chat.newThread();
    chat.submit('Synthetic prompt', const []);
    source.publish(binding);
    source.sends.single.emit(const ThreadBound('stored'));
    await pumpEventQueue();
  });
  tearDown(() async {
    chat.dispose();
    attention.dispose();
    activity.dispose();
    await source.changes.close();
  });
  void progress({OwnedSessionBinding? owner, Object identity = 'progress'}) {
    final scope = owner ?? binding;
    source.sends.single.emit(
      MoaUpdated(
        MoaUpdate.decode('moa.reference', {
          'label': 'Advisor',
          'text': 'Private reference',
        })!,
        runtimeId: scope.runtimeId,
        connection: scope.connection,
        identity: identity,
      ),
    );
  }

  test(
    'getter hides divergent actual ownership before any notification',
    () async {
      progress();
      await pumpEventQueue();
      final thread = chat.selectedThread!;
      expect(chat.moaIn(thread), hasLength(1));
      source.current = OwnedSessionBinding(
        connection: Object(),
        runtimeId: binding.runtimeId,
        profile: binding.profile,
      );
      expect(chat.moaIn(thread), isEmpty);
      source.current = null;
      expect(chat.moaIn(thread), isEmpty);
    },
  );
  test('an earlier Todo observer cannot expose old advisor references during ownership replacement', () async {
    progress();
    await pumpEventQueue();
    final thread = chat.selectedThread!;
    expect(chat.moaIn(thread), hasLength(1));
    final next = OwnedSessionBinding(
      connection: Object(),
      runtimeId: 'next',
      profile: null,
    );
    final seen = <bool>[];
    chat.addListener(() {
      if (source.current == next) seen.add(chat.moaIn(thread).isEmpty);
    });
    source.publish(next);
    expect(seen, isNotEmpty);
    expect(seen.every((hidden) => hidden), true);
    progress(owner: binding);
    await pumpEventQueue();
    expect(chat.moaIn(thread), isEmpty);
  });
  test('duplicate identity has one effect and activity suspension hides all references', () async {
    progress();
    progress();
    await pumpEventQueue();
    final thread = chat.selectedThread!;
    expect(chat.moaIn(thread).single.references, hasLength(1));
    activity.value = false;
    expect(chat.moaIn(thread), isEmpty);
    activity.value = true;
    await pumpEventQueue();
    expect(chat.moaIn(thread), isEmpty);
  });
  test('disconnect hides references and reconnect cannot reconstruct missed details', () async {
    progress();
    await pumpEventQueue();
    final thread = chat.selectedThread!;
    source.publish(binding, connected: false);
    expect(chat.moaIn(thread), isEmpty);
    final replacement = OwnedSessionBinding(
      connection: Object(),
      runtimeId: binding.runtimeId,
      profile: null,
    );
    source.publish(replacement);
    progress(owner: replacement, identity: 'new-frame');
    await pumpEventQueue();
    final card = chat.moaIn(thread).single;
    expect(card.referencesAvailable, false);
    expect(card.references.map((reference) => reference.eventIdentity), [
      'new-frame',
    ]);
  });
  test(
    'profile replacement hides the old references before its callback',
    () async {
      progress();
      await pumpEventQueue();
      final thread = chat.selectedThread!;
      source.current = OwnedSessionBinding(
        connection: binding.connection,
        runtimeId: binding.runtimeId,
        profile: 'other-profile',
      );
      expect(chat.moaIn(thread), isEmpty);
      progress();
      await pumpEventQueue();
      expect(chat.moaIn(thread), isEmpty);
    },
  );
  test('an idle replay gap invalidates settled reference details', () async {
    progress();
    source.sends.single.emit(const ReplyCompleted('Main answer'));
    source.sends.single.finish();
    await pumpEventQueue();
    final thread = chat.selectedThread!;
    expect(chat.moaIn(thread).single.references, hasLength(1));
    source.followUpStreams['stored']!.emit(const ThreadNeedsRefetch());
    await pumpEventQueue();
    expect(chat.moaIn(thread).single.referencesAvailable, false);
    expect(chat.moaIn(thread).single.references, isEmpty);
  });
  test(
    'stream closure finishes the actual unsolicited foreground card',
    () async {
      source.sends.single.emit(const UnsolicitedEvent(ReplyStarted()));
      source.sends.single.emit(
        UnsolicitedEvent(
          MoaUpdated(
            MoaUpdate.decode('moa.phase', {'phase': 'aggregator'})!,
            runtimeId: binding.runtimeId,
            connection: binding.connection,
            identity: 'foreign-phase',
          ),
        ),
      );
      await pumpEventQueue();
      final thread = chat.selectedThread!;
      expect(chat.moaIn(thread).single.live, true);
      source.sends.single.finish();
      await pumpEventQueue();
      expect(chat.moaIn(thread).single.live, false);
    },
  );
  test('unconfirmed runtime cannot create advisor state', () async {
    progress(
      owner: OwnedSessionBinding(
        connection: binding.connection,
        runtimeId: 'other',
        profile: null,
      ),
    );
    await pumpEventQueue();
    expect(chat.moaIn(chat.selectedThread!), isEmpty);
  });
}
