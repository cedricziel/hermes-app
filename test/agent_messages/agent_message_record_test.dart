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

  group('writeIfCurrent', () {
    test('writes when the stored record is what the look read', () async {
      await record.write('acct', {'work': 100});

      final wrote = await record.writeIfCurrent(
        'acct',
        expected: {'work': 100},
        {'work': 200},
      );

      expect(wrote, isTrue);
      expect(await record.read('acct'), {'work': 200});
    });

    test('writes a first record when none was there', () async {
      final wrote = await record.writeIfCurrent('acct', expected: null, {
        'work': 0,
      });

      expect(wrote, isTrue);
      expect(await record.read('acct'), {'work': 0});
    });

    test('writes nothing when another look moved it meanwhile', () async {
      await record.write('acct', {'work': 100});
      await record.write('acct', {'work': 300});

      final wrote = await record.writeIfCurrent(
        'acct',
        expected: {'work': 100},
        {'work': 200},
      );

      expect(wrote, isFalse);
      expect(await record.read('acct'), {'work': 300});
    });

    test('writes nothing when the record went away meanwhile', () async {
      await record.write('acct', {'work': 100});
      await record.clear();

      final wrote = await record.writeIfCurrent(
        'acct',
        expected: {'work': 100},
        {'work': 200},
      );

      expect(wrote, isFalse);
      expect(await record.read('acct'), isNull);
    });

    test('writes nothing when a record appeared for a first look', () async {
      await record.write('acct', {'work': 300});

      final wrote = await record.writeIfCurrent('acct', expected: null, {
        'work': 200,
      });

      expect(wrote, isFalse);
      expect(await record.read('acct'), {'work': 300});
    });

    test('drops a profile the list no longer names', () async {
      await record.write('acct', {'work': 100, 'home': 50});

      final wrote = await record.writeIfCurrent(
        'acct',
        expected: {'work': 100, 'home': 50},
        {'work': 100},
      );

      expect(wrote, isTrue);
      expect(await record.read('acct'), {'work': 100});
    });

    test('reads a corrupt stored value as none', () async {
      await SharedPreferencesAsync().setString(
        'hermes.agent_messages.baseline.v1',
        'not json',
      );

      expect(
        await record.writeIfCurrent('acct', expected: {'work': 1}, {'work': 2}),
        isFalse,
      );
      expect(
        await record.writeIfCurrent('acct', expected: null, {'work': 2}),
        isTrue,
      );
      expect(await record.read('acct'), {'work': 2});
    });

    test("reads another account's record as none", () async {
      await record.write('other', {'work': 100});

      expect(
        await record.writeIfCurrent(
          'acct',
          expected: {'work': 100},
          {'work': 200},
        ),
        isFalse,
      );
      expect(
        await record.writeIfCurrent('acct', expected: null, {'work': 200}),
        isTrue,
      );
      expect(await record.read('acct'), {'work': 200});
    });

    test('lets only one of two looks with the same record write', () async {
      await record.write('acct', {'work': 100});

      final results = await Future.wait([
        record.writeIfCurrent('acct', expected: {'work': 100}, {'work': 200}),
        record.writeIfCurrent('acct', expected: {'work': 100}, {'work': 200}),
      ]);

      expect(results, unorderedEquals([true, false]));
    });

    test('throws when the stored record cannot be read', () async {
      SharedPreferencesAsyncPlatform.instance = _UnreadablePrefs();

      expect(
        AgentMessageRecord().writeIfCurrent('acct', expected: null, {
          'work': 1,
        }),
        throwsStateError,
      );
    });
  });
}

base class _UnreadablePrefs extends InMemorySharedPreferencesAsync {
  _UnreadablePrefs() : super.empty();

  @override
  Future<String?> getString(
    String key,
    SharedPreferencesOptions options,
  ) async => throw StateError('unreadable');
}
