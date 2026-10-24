import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/agent_messages/agent_message_record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  late AgentMessageRecord record;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    record = AgentMessageRecord();
  });

  test('reads nothing before a look wrote it', () async {
    expect(await record.read('acct'), isNull);
  });

  test('keeps what the last look saw of each profile', () async {
    await record.write('acct', {'default': 1780000100.5, 'work': 0});

    expect(await record.read('acct'), {'default': 1780000100.5, 'work': 0});
  });

  test('another account reads none', () async {
    await record.write('acct', {'default': 5});

    expect(await record.read('other'), isNull);
  });

  test('a stored value it cannot read is none', () async {
    await SharedPreferencesAsync().setString(
      'hermes.agent_messages.baseline.v1',
      'not json',
    );

    expect(await record.read('acct'), isNull);
  });

  test('clear forgets it', () async {
    await record.write('acct', {'default': 5});

    await record.clear();

    expect(await record.read('acct'), isNull);
  });
}
