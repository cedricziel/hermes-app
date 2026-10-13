import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/owned_session_transport.dart';
import 'package:hermes_app/src/chat/todo_plan/todo_plan_state.dart';
import 'package:hermes_app/src/chat/session_usage/usage_snapshot.dart';
import 'package:hermes_app/src/chat/session_usage/session_usage_controller.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';

import 'support/fake_chat_transport.dart';

class OwnedTodoTransport extends FakeChatTransport
    implements OwnedSessionTransport {
  final changes = StreamController<OwnedSessionChange>.broadcast(sync: true);
  final bindings = <(String?, String), OwnedSessionBinding>{};
  @override
  Stream<OwnedSessionChange> get ownedSessions => changes.stream;
  @override
  OwnedSessionBinding? ownedSessionFor(String threadId, {String? profile}) =>
      bindings[(profile, threadId)];
  @override
  Future<Map<String, Object?>> readOwnedSession(
    OwnedSessionBinding binding,
    String method,
  ) async => {'total': 0};
  void publish(
    OwnedSessionBinding binding, {
    bool connected = true,
    bool resuming = false,
    Object? token,
    Object? snapshot,
  }) {
    final owner = (binding.profile, 'stored');
    if (connected) {
      bindings[owner] = binding;
    } else if (bindings[owner] == binding) {
      bindings.remove(owner);
    }
    changes.add(
      OwnedSessionChange(
        'stored',
        binding,
        connected: connected,
        resuming: resuming,
        resumeToken: token,
        resumeSnapshot: snapshot == null ? null : {'todo_state': snapshot},
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late OwnedTodoTransport source;
  late ChatController chat;
  late AttentionNotifier attention;
  late ValueNotifier<bool> activity;
  late OwnedSessionBinding binding;
  Map<String, Object?> plan(int revision, String text) => {
    'revision': revision,
    'todos': [
      {'id': 'task', 'content': text, 'status': 'pending'},
    ],
  };
  setUp(() {
    source = OwnedTodoTransport();
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
    chat.submit('Synthetic turn', const []);
  });
  tearDown(() async {
    chat.dispose();
    attention.dispose();
    activity.dispose();
    await source.changes.close();
  });

  test(
    'confirmed resume metadata survives arrival before ThreadBound',
    () async {
      await pumpEventQueue();
      final thread = chat.selectedThread!;
      source.publish(binding, snapshot: plan(1, 'Restored task'));
      expect(thread.remote, isFalse);
      expect(chat.todoPlanIn(thread), isNull);
      source.sends.single.emit(const ThreadBound('stored'));
      await pumpEventQueue();

      expect(
        chat.todoPlanIn(thread)!.snapshot!.entries.single!.content,
        'Restored task',
      );
    },
  );

  for (final missing in [false, true]) {
    test(
      'a held resume ${missing ? 'without state' : 'snapshot'} cannot erase accepted live work',
      () async {
        await pumpEventQueue();
        source.sends.single.emit(const ThreadBound('stored'));
        await pumpEventQueue();
        final thread = chat.selectedThread!;
        source.publish(binding, snapshot: plan(1, 'Initial task'));
        final token = Object();
        source.publish(binding, resuming: true, token: token);
        source.sends.single.emit(
          TodoUpdated(
            TodoSnapshot.decode(plan(6, 'Live task'))!,
            runtimeId: binding.runtimeId,
            connection: binding.connection,
          ),
        );
        await pumpEventQueue();
        expect(chat.todoPlanIn(thread)!.snapshot!.revision, 6);
        source.publish(
          binding,
          token: token,
          snapshot: missing ? null : plan(5, 'Held task'),
        );

        expect(chat.todoPlanIn(thread)!.snapshot!.revision, 6);
        expect(
          chat.todoPlanIn(thread)!.snapshot!.entries.single!.content,
          'Live task',
        );
      },
    );
  }

  test('old socket frames and loss cannot overwrite a new binding with reused runtime ID', () async {
    await pumpEventQueue();
    source.sends.single.emit(const ThreadBound('stored'));
    await pumpEventQueue();
    final thread = chat.selectedThread!;
    source.publish(binding, snapshot: plan(6, 'Old socket task'));
    final next = OwnedSessionBinding(
      connection: Object(),
      runtimeId: binding.runtimeId,
      profile: null,
    );
    source.publish(next, snapshot: plan(1, 'New socket task'));
    source.publish(binding, connected: false);
    source.sends.single.emit(
      TodoUpdated(
        TodoSnapshot.decode(plan(99, 'Late old socket task'))!,
        runtimeId: binding.runtimeId,
        connection: binding.connection,
      ),
    );
    await pumpEventQueue();

    expect(chat.todoPlanIn(thread)!.snapshot!.revision, 1);
    expect(
      chat.todoPlanIn(thread)!.snapshot!.entries.single!.content,
      'New socket task',
    );
  });

  test(
    'activity retirement during adoption cannot restore protected plan state',
    () async {
      await pumpEventQueue();
      source.sends.single.emit(const ThreadBound('stored'));
      await pumpEventQueue();
      final thread = chat.selectedThread!;
      TodoPlanState? retired;
      chat.addListener(() {
        if (retired != null) return;
        final state = chat.todoPlanIn(thread);
        if (state == null) return;
        retired = state;
        activity.value = false;
      });
      source.publish(binding, snapshot: plan(1, 'Must not restore'));

      expect(retired, isNotNull);
      expect(retired!.attached, isFalse);
      expect(retired!.snapshot, isNull);
      expect(chat.todoPlanIn(thread), isNull);
      expect(chat.usageIn(thread), isNull);
    },
  );

  test(
    'new todo adoption never exposes old usage through a listener',
    () async {
      await pumpEventQueue();
      source.sends.single.emit(const ThreadBound('stored'));
      await pumpEventQueue();
      final thread = chat.selectedThread!;
      source.publish(binding, snapshot: plan(6, 'Old owner task'));
      source.sends.single.emit(
        SessionUsageUpdated(
          UsageSnapshot.decode({'total': 7})!,
          runtimeId: binding.runtimeId,
          connection: binding.connection,
        ),
      );
      await pumpEventQueue();
      expect(chat.usageIn(thread)!.snapshot!.total, 7);
      final observed = <int?>[];
      chat.addListener(
        () => observed.add(chat.usageIn(thread)?.snapshot?.total),
      );
      final next = OwnedSessionBinding(
        connection: Object(),
        runtimeId: 'new-runtime',
        profile: null,
      );

      source.publish(next, snapshot: plan(1, 'New owner task'));
      await pumpEventQueue();

      expect(observed, isNot(contains(7)));
      expect(chat.todoPlanIn(thread)!.snapshot!.revision, 1);
    },
  );

  test(
    'usage-first notification hides todo from an earlier confirmed binding',
    () async {
      await pumpEventQueue();
      source.sends.single.emit(const ThreadBound('stored'));
      await pumpEventQueue();
      final thread = chat.selectedThread!;
      source.publish(binding, snapshot: plan(6, 'Old owner task'));
      final usage = chat.usageIn(thread)!;
      final next = OwnedSessionBinding(
        connection: Object(),
        runtimeId: 'new-runtime',
        profile: null,
      );
      final observed = <int?>[];
      chat.addListener(
        () => observed.add(chat.todoPlanIn(thread)?.snapshot?.revision),
      );
      source.bindings[(null, 'stored')] = next;

      usage.bind(
        UsageScope(
          connection: next.connection,
          sessionId: next.runtimeId,
          profile: null,
        ),
        (_, _) async => {'total': 0},
      );
      source.publish(next, snapshot: plan(1, 'New owner task'));

      expect(observed, isNot(contains(6)));
      expect(chat.todoPlanIn(thread)!.snapshot!.revision, 1);
    },
  );

  test('disconnected usage retains explicitly stale totals without restoring a plan', () async {
    await pumpEventQueue();
    source.sends.single.emit(const ThreadBound('stored'));
    await pumpEventQueue();
    final thread = chat.selectedThread!;
    source.publish(binding, snapshot: plan(6, 'Old owner task'));
    source.sends.single.emit(
      SessionUsageUpdated(
        UsageSnapshot.decode({'total': 7})!,
        runtimeId: binding.runtimeId,
        connection: binding.connection,
      ),
    );
    await pumpEventQueue();

    source.publish(binding, connected: false);

    expect(chat.usageIn(thread)!.snapshot!.total, 7);
    expect(chat.usageIn(thread)!.freshness, UsageFreshness.stale);
    expect(chat.todoPlanIn(thread), isNull);
  });
}
