import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/background/running_replies.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  late RunningReplies running;
  final since = DateTime.utc(2026, 10, 11, 12);

  RunningReply reply(String id, {bool fromAsk = false, String? profile}) =>
      RunningReply(
        profile: profile ?? 'work',
        threadId: id,
        since: since,
        fromAsk: fromAsk,
      );

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    running = RunningReplies();
  });

  test(
    'an ask entry survives what the chat screen writes on a pause',
    () async {
      await running.add(reply('asked', fromAsk: true));

      await running.replace([reply('shown')]);

      expect((await running.read()).map((r) => r.threadId), ['asked', 'shown']);
    },
  );

  test('the chat screen still owns the chats it names', () async {
    await running.add(reply('c1', fromAsk: true));

    await running.replace([reply('c1')]);

    expect(await running.read(), [reply('c1')]);
  });

  test('a pause with nothing replying drops its own entries only', () async {
    await running.replace([reply('shown')]);
    await running.add(reply('asked', fromAsk: true));

    await running.replace(const []);

    expect(await running.read(), [reply('asked', fromAsk: true)]);
  });

  test('the same chat of another profile is another entry', () async {
    await running.add(reply('c1', fromAsk: true, profile: 'home'));

    await running.replace([reply('c1')]);

    expect((await running.read()).map((r) => r.profile), ['home', 'work']);
  });

  test('add replaces the entry of the same chat', () async {
    await running.add(reply('c1', fromAsk: true));
    await running.add(reply('c1', fromAsk: true));

    expect(await running.read(), hasLength(1));
  });

  test(
    'the app returning forgets what it showed, not what an ask handed over',
    () async {
      await running.add(reply('asked', fromAsk: true));
      await running.replace([reply('shown')]);

      await running.clear();

      expect(await running.read(), [reply('asked', fromAsk: true)]);
    },
  );

  test('signing out forgets everything, asks included', () async {
    await running.add(reply('asked', fromAsk: true));
    await running.replace([reply('shown')]);

    await running.clearAll();

    expect(await running.read(), isEmpty);
  });

  test('forget removes an ask entry like any other', () async {
    await running.add(reply('asked', fromAsk: true));

    await running.forget([reply('asked', fromAsk: true)]);

    expect(await running.read(), isEmpty);
  });
}
