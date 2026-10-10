import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:hermes_app/src/surfaces/chat_hints.dart';
import 'package:hermes_app/src/surfaces/surface_snapshot.dart';

import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/fake_chat_transport.dart';
import '../support/fake_hermes_server.dart';

const approval = ApprovalRequest(
  requestId: 'r1',
  command: 'rm -rf build',
  description: 'delete files',
  choices: ['once', 'deny'],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeChatTransport transport;
  late List<(SurfaceTrigger, ChatHints)> reports;
  late ChatController chat;

  ChatController build({HermesChatRepository? repository}) {
    final attention = AttentionNotifier(
      service: null,
      settings: null,
      onOpen: (_) {},
    );
    final controller = ChatController(
      repository: repository,
      transport: transport,
      attention: attention,
      report: (_) {},
      onSurfaceChange: (trigger, hints) => reports.add((trigger, hints)),
    );
    addTearDown(() {
      controller.dispose();
      attention.dispose();
    });
    return controller;
  }

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    transport = FakeChatTransport();
    reports = [];
    chat = build();
  });

  Future<FakeSend> sendHello() async {
    chat.newThread();
    chat.submit('Hello', const []);
    final send = transport.sends.single..emit(const ThreadBound('s1'));
    await pumpEventQueue();
    return send;
  }

  List<SurfaceTrigger> triggers() => [for (final (t, _) in reports) t];

  test('the chat list loading is reported with the open profile', () async {
    final server = FakeHermesServer()
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([
          sessionRow(id: 's1', title: 'Trip plan', lastActive: 1780000600),
          sessionRow(id: 's2', title: 'Release notes', lastActive: 1780000100),
        ]),
      );
    chat = build(repository: HermesChatRepository(server.client().raw));

    await chat.loadThreads('work');

    final (trigger, hints) = reports.single;
    expect(trigger, SurfaceTrigger.threads);
    expect(hints.profile, 'work');
    expect(hints.threads.map((t) => (t.id, t.title)), [
      ('s1', 'Trip plan'),
      ('s2', 'Release notes'),
    ]);
    expect(hints.threads.first.snippet, isNull);
  });

  group('removing a chat', () {
    late FakeHermesServer server;

    setUp(() {
      server = FakeHermesServer()
        ..on(
          'GET',
          '/api/sessions',
          sessionListBody([
            sessionRow(id: 's1', title: 'Trip plan', lastActive: 1780000600),
            sessionRow(id: 's2', title: 'Notes', lastActive: 1780000100),
          ]),
        )
        ..on('DELETE', '/api/sessions/s1', {'ok': true})
        ..on('PATCH', '/api/sessions/s2', sessionPatchBody());
      chat = build(repository: HermesChatRepository(server.client().raw));
    });

    test('deleting one is reported without it', () async {
      await chat.loadThreads('work');
      reports.clear();

      await chat.housekeeping!.delete(chat.threads.first);

      expect(triggers(), [SurfaceTrigger.threads]);
      expect(reports.single.$2.threads.map((t) => t.id), ['s2']);
    });

    test('archiving one is reported without it', () async {
      await chat.loadThreads('work');
      reports.clear();

      await chat.housekeeping!.archive(chat.threads.last);

      expect(triggers(), [SurfaceTrigger.threads]);
      expect(reports.single.$2.threads.map((t) => t.id), ['s1']);
    });

    test('a failed delete reports nothing', () async {
      server.on('DELETE', '/api/sessions/s1', {'detail': 'no'}, status: 500);
      await chat.loadThreads('work');
      reports.clear();

      await chat.housekeeping!.delete(chat.threads.first);

      expect(reports, isEmpty);
    });
  });

  test('a finished reply is reported with its start as the snippet', () async {
    final send = await sendHello();
    reports.clear();

    send
      ..emit(const ReplyDelta('Hi '))
      ..emit(const ReplyCompleted('Hi there'));
    await pumpEventQueue();

    expect(triggers(), [SurfaceTrigger.reply]);
    final thread = reports.single.$2.threads.single;
    expect(
      (thread.id, thread.title, thread.snippet),
      ('s1', 'Hello', 'Hi there'),
    );
    expect(
      thread.updatedAt.isAfter(
        DateTime.now().subtract(const Duration(minutes: 1)),
      ),
      isTrue,
    );
  });

  test('a failed reply is reported', () async {
    final send = await sendHello();
    reports.clear();

    send.emit(const ReplyCompleted('', failed: true));
    await pumpEventQueue();

    expect(triggers(), [SurfaceTrigger.reply]);
  });

  test('a stopped reply is reported', () async {
    final send = await sendHello();
    reports.clear();

    send.emit(const ReplyCompleted('Half', stopped: true));
    await pumpEventQueue();

    expect(triggers(), [SurfaceTrigger.reply]);
  });

  test('streaming text is not reported', () async {
    final send = await sendHello();
    reports.clear();

    send
      ..emit(const ReplyDelta('Hi '))
      ..emit(const ReplyDelta('there'));
    await pumpEventQueue();

    expect(reports, isEmpty);
  });

  test('a request opening and being answered is reported', () async {
    final send = await sendHello();
    reports.clear();

    send.emit(const ApprovalRequested(approval));
    await pumpEventQueue();

    expect(triggers(), [SurfaceTrigger.request]);
    final request = reports.single.$2.requests.single;
    expect(
      (request.threadId, request.threadTitle, request.kind, request.requestId),
      ('s1', 'Hello', PendingKind.approval, 'r1'),
    );

    reports.clear();
    await chat.answerApproval(chat.selectedThread!, 'r1', 'once');

    expect(triggers(), [SurfaceTrigger.request]);
    expect(reports.single.$2.requests, isEmpty);
  });

  test('a request keeps the time it was first seen', () async {
    final send = await sendHello();
    send.emit(const ApprovalRequested(approval));
    await pumpEventQueue();
    final first = reports.last.$2.requests.single.seenAt;
    await Future<void>.delayed(const Duration(milliseconds: 5));

    send.emit(
      const ApprovalRequested(
        ApprovalRequest(
          requestId: 'r2',
          command: 'ls',
          description: 'list',
          choices: ['once', 'deny'],
        ),
      ),
    );
    await pumpEventQueue();

    final requests = reports.last.$2.requests;
    expect(requests.map((r) => r.requestId), ['r1', 'r2']);
    expect(requests.first.seenAt, first);
    expect(requests.last.seenAt.isAfter(first), isTrue);
  });

  test('a question counts as a question and a secret as input', () async {
    final send = await sendHello();
    reports.clear();

    send
      ..emit(
        const ClarifyRequested(
          ClarifyRequest(
            requestId: 'q1',
            questions: [ClarifyQuestion(qid: '', question: 'Which?')],
          ),
        ),
      )
      ..emit(
        const VaultRequested(
          VaultRequest(requestId: 'v1', kind: VaultKind.unlock),
        ),
      );
    await pumpEventQueue();

    expect(reports.last.$2.requests.map((r) => (r.requestId, r.kind)), [
      ('q1', PendingKind.question),
      ('v1', PendingKind.input),
    ]);
  });

  test('a chat without a server id is not reported', () async {
    chat.newThread();
    chat.submit('Hello', const []);
    transport.sends.single.emit(const ReplyDelta('Hi'));
    transport.sends.single.emit(const ReplyCompleted('Hi'));
    await pumpEventQueue();

    expect(reports.last.$2.threads, isEmpty);
  });
}
