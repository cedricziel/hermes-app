import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:hermes_app/src/share/shared_item.dart';
import 'package:hermes_app/src/watch/watch_complication.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_chat_transport.dart';
import 'support/fake_hermes_server.dart';

/// What a chat tells the watch's complications about a reply sent from the
/// phone.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeHermesServer server;
  late FakeChatTransport transport;
  late List<Map<String, Object>> sent;
  late AttentionNotifier attention;
  late ChatController chat;
  var disposedEarly = false;

  const approval = ApprovalRequested(
    ApprovalRequest(
      requestId: 'r1',
      command: 'rm -rf build',
      description: 'delete files',
      choices: ['once', 'deny'],
    ),
  );

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    transport = FakeChatTransport();
    sent = [];
    disposedEarly = false;
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([
          sessionRow(id: 's1', title: 'Run failure', lastActive: 1780000600),
          sessionRow(
            id: 's2',
            preview: 'my private first words',
            lastActive: 1780000500,
          ),
        ]),
      )
      ..on(
        'GET',
        '/api/sessions/s1/messages',
        messageListBody('s1', [
          messageRow(id: 1, role: 'user', content: 'Why did the run fail?'),
        ]),
      )
      ..on(
        'GET',
        '/api/sessions/s2/messages',
        messageListBody('s2', [
          messageRow(id: 1, role: 'user', content: 'my private first words'),
        ]),
      )
      ..on('DELETE', '/api/sessions/s1', {'ok': true})
      ..on('PATCH', '/api/sessions/s1', {'title': ''})
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([]),
        query: {'profile': 'work'},
      );
    attention = AttentionNotifier(
      service: null,
      settings: null,
      onOpen: (_) {},
    );
    chat = ChatController(
      repository: HermesChatRepository(server.client().raw),
      transport: transport,
      attention: attention,
      watchStatus: WatchComplicationStatus(
        send: (payload, {required urgent}) async {
          sent.add(payload);
          return 'complication';
        },
      ),
      report: (_) {},
    );
  });

  tearDown(() {
    if (!disposedEarly) chat.dispose();
    attention.dispose();
  });

  String state() => sent.last['state'] as String;

  Future<FakeSend> submitIn(String id) async {
    await chat.loadThreads();
    chat.select(id);
    await pumpEventQueue();
    chat.submit('Any news?', const []);
    await pumpEventQueue();
    return transport.sends.last;
  }

  test('a reply sent here shows on the watch, with its chat', () async {
    await submitIn('s1');

    expect(sent.single, containsPair('state', 'working'));
    expect(sent.single, containsPair('title', 'Run failure'));
    expect(sent.single, containsPair('threadId', '/s1'));
  });

  test('the reply drives it to ready, without its text', () async {
    final turn = await submitIn('s1');

    turn.emit(approval);
    await pumpEventQueue();
    expect(state(), 'waiting');

    turn.emit(const ReplyCompleted('Nothing new.'));
    await pumpEventQueue();
    expect(state(), 'ready');
    expect(sent.join(), isNot(contains('rm -rf')));
    expect(sent.join(), isNot(contains('Nothing new')));
  });

  test('a broken turn shows as failed', () async {
    final turn = await submitIn('s1');

    turn.fail();
    await pumpEventQueue();

    expect(state(), 'failed');
  });

  test('deleting the chat takes it off the watch', () async {
    await submitIn('s1');

    final thread = chat.threads.firstWhere((t) => t.id == 's1');
    await chat.housekeeping!.delete(thread);
    await pumpEventQueue();

    expect(state(), 'none');
  });

  group('the title', () {
    test('of a new chat is not made from the prompt', () async {
      chat.newThread();
      chat.submit('my secret prompt', const []);
      final turn = transport.sends.last;
      turn
        ..emit(const ThreadBound('n1'))
        ..emit(const ReplyDelta('Sure'))
        ..emit(const ReplyCompleted('Done'));
      await pumpEventQueue();

      expect(sent, isNotEmpty);
      expect(sent.join(), isNot(contains('secret')));
      expect(sent.join(), isNot(contains('prompt')));
      expect(sent.any((payload) => payload.containsKey('title')), isFalse);
      expect(sent.last, containsPair('threadId', '/n1'));
    });

    test('of a new chat shows once the gateway names it', () async {
      chat.newThread();
      chat.submit('my secret prompt', const []);
      transport.sends.last
        ..emit(const ThreadBound('n1'))
        ..emit(const ThreadTitled('Backup'));
      await pumpEventQueue();

      expect(sent.last, containsPair('title', 'Backup'));
    });

    test('is not the server preview of an unnamed chat', () async {
      await submitIn('s2');

      expect(sent, isNotEmpty);
      expect(sent.join(), isNot(contains('private')));
      expect(sent.any((payload) => payload.containsKey('title')), isFalse);
      expect(sent.last, containsPair('threadId', '/s2'));
    });

    test('of a chat a file starts is not the file name', () async {
      chat.newThread();
      final file = File('${Directory.systemTemp.path}/taxes-2025.pdf')
        ..writeAsBytesSync([1, 2, 3]);
      addTearDown(file.deleteSync);
      chat.submit('', [SharedFile(path: file.path, name: 'taxes-2025.pdf')]);
      await pumpEventQueue();

      expect(sent, isNotEmpty);
      expect(sent.join(), isNot(contains('taxes')));
    });
  });

  group('the title of a named chat', () {
    test('is kept when a retry empties its only turn', () async {
      await chat.loadThreads();
      chat.select('s1');
      await pumpEventQueue();

      await chat.retry(chat.selectedThread!);
      await pumpEventQueue();

      expect(sent, isNotEmpty);
      expect(sent.last, containsPair('title', 'Run failure'));
      expect(sent.join(), isNot(contains('Why did the run fail')));
    });

    test('is kept when an edit empties its only turn', () async {
      await chat.loadThreads();
      chat.select('s1');
      await pumpEventQueue();

      await chat.editLastPrompt(chat.selectedThread!);
      chat.submit('my edited secret', const []);
      await pumpEventQueue();

      expect(sent, isNotEmpty);
      expect(sent.last, containsPair('title', 'Run failure'));
      expect(sent.join(), isNot(contains('secret')));
    });

    test('is kept when a send goes in before its messages load', () async {
      await chat.loadThreads();
      chat.select('s1');
      chat.submit('my hasty secret', const []);
      await pumpEventQueue();

      expect(sent, isNotEmpty);
      expect(sent.last, containsPair('title', 'Run failure'));
      expect(sent.join(), isNot(contains('secret')));
    });

    test('is not kept once the rename cleared it', () async {
      await chat.loadThreads();
      chat.select('s1');
      await pumpEventQueue();
      final thread = chat.selectedThread!;

      await chat.housekeeping!.rename(thread, '');
      expect(thread.named, isFalse);
      await chat.retry(thread);
      await pumpEventQueue();

      expect(sent.any((payload) => payload.containsKey('title')), isFalse);
    });

    test('follows what another window made of it', () async {
      await chat.loadThreads();
      final thread = chat.threads.firstWhere((t) => t.id == 's1');

      chat.housekeeping!.adopt(
        thread,
        ChatThread(id: 's1', title: 'first words', updatedAt: DateTime.now()),
      );
      expect(thread.named, isFalse);

      chat.housekeeping!.adopt(
        thread,
        ChatThread(
          id: 's1',
          title: 'Named',
          updatedAt: DateTime.now(),
          named: true,
        ),
      );
      expect(thread.named, isTrue);
    });
  });

  group('a turn the user did not send from here', () {
    test('chained after the reply restarts the status', () async {
      final turn = await submitIn('s1');
      turn
        ..emit(const ReplyCompleted('Checking first.'))
        ..finish();
      await pumpEventQueue();
      expect(state(), 'ready');

      transport.followUpStreams['s1']!.emit(const ReplyStarted());
      await pumpEventQueue();
      expect(state(), 'working');

      transport.followUpStreams['s1']!.emit(const ReplyCompleted('Then more.'));
      await pumpEventQueue();
      expect(state(), 'ready');
    });

    test('chained after the reply that asks needs the user', () async {
      final turn = await submitIn('s1');
      turn
        ..emit(const ReplyCompleted('Checking first.'))
        ..finish();
      await pumpEventQueue();

      transport.followUpStreams['s1']!
        ..emit(const ReplyStarted())
        ..emit(approval);
      await pumpEventQueue();

      expect(state(), 'waiting');
    });

    test('after a resume does not finish the prompt, which waits', () async {
      chat.newThread();
      chat.submit('Plan it', const []);
      final turn = transport.sends.last..emit(const ThreadBound('n1'));
      turn
        ..emit(const UnsolicitedEvent(ReplyStarted()))
        ..emit(const UnsolicitedEvent(ReplyDelta('resumed work')))
        ..emit(const UnsolicitedEvent(ReplyCompleted('resumed work')));
      await pumpEventQueue();

      expect(state(), 'working');
      expect(sent.map((payload) => payload['state']), isNot(contains('ready')));

      turn.emit(const ReplyCompleted('Planned.'));
      await pumpEventQueue();
      expect(state(), 'ready');
    });

    test('after a resume that asks shows the user is needed', () async {
      chat.newThread();
      chat.submit('Plan it', const []);
      transport.sends.last
        ..emit(const ThreadBound('n1'))
        ..emit(const UnsolicitedEvent(ReplyStarted()))
        ..emit(const UnsolicitedEvent(approval));
      await pumpEventQueue();

      expect(state(), 'waiting');
    });
  });

  group('a turn that ends in no way the chat reports', () {
    test('a stop the server has nothing left to stop for', () async {
      final turn = await submitIn('s1');
      turn.emit(const ReplyStarted());
      await pumpEventQueue();
      expect(state(), 'working');
      transport.stopsRunning = false;

      await chat.stopReply(chat.selectedThread!);
      await pumpEventQueue();

      expect(state(), 'none');
    });

    test('a folded prompt whose connection breaks', () async {
      final turn = await submitIn('s1');
      turn.emit(const PromptFolded());
      await pumpEventQueue();
      expect(state(), 'working');

      turn.fail();
      await pumpEventQueue();

      expect(state(), 'failed');
    });

    test('a turn followed in a profile that goes out of view', () async {
      final turn = await submitIn('s1');
      turn
        ..emit(const ReplyCompleted('Checking first.'))
        ..finish();
      await pumpEventQueue();
      transport.followUpStreams['s1']!.emit(const ReplyStarted());
      await pumpEventQueue();
      expect(state(), 'working');

      await chat.loadThreads('work');
      await pumpEventQueue();

      expect(state(), 'none');
    });

    test('a reply of another profile when the chat is closed', () async {
      final turn = await submitIn('s1');
      await chat.loadThreads('work');
      await pumpEventQueue();
      // The reply goes on in the profile that is out of view.
      turn.emit(const ReplyDelta('still going'));
      await pumpEventQueue();
      expect(state(), 'working');

      disposedEarly = true;
      chat.dispose();
      await pumpEventQueue();

      expect(state(), 'none');
    });

    test('a chat that is closed with its reply running', () async {
      await submitIn('s1');
      expect(state(), 'working');

      disposedEarly = true;
      chat.dispose();
      await pumpEventQueue();

      expect(state(), 'none');
    });
  });
}
