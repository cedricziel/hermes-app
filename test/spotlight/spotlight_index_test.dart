import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/spotlight/spotlight_index.dart';

import '../support/recorded_events.dart';

const channel = MethodChannel('hermes_app/spotlight');

const item = SpotlightItem(
  domain: 'chat',
  id: 'abc',
  title: 'Trip plan',
  text: 'Booked the flights',
  url: 'hermes://chat?profile=default&id=abc',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> calls;
  late RecordedEvents events;
  late ChannelSpotlightIndex index;
  Object? Function(MethodCall) answer = (_) => null;

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    calls = [];
    events = RecordedEvents();
    answer = (_) => null;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return answer(call);
    });
    index = ChannelSpotlightIndex(events: events.call);
  });

  tearDown(() {
    index.dispose();
    messenger.setMockMethodCallHandler(channel, null);
  });

  test(
    "replace sends the domain and each item's link, title and text",
    () async {
      expect(await index.replace('chat', [item]), isTrue);

      expect(calls.single.method, 'replace');
      expect(calls.single.arguments, {
        'domain': 'chat',
        'items': [
          {
            'url': 'hermes://chat?profile=default&id=abc',
            'title': 'Trip plan',
            'text': 'Booked the flights',
          },
        ],
      });
    },
  );

  test('update sends the changed items and the links to drop', () async {
    expect(
      await index.update(
        'chat',
        upsert: [item],
        remove: ['hermes://chat?profile=default&id=old'],
      ),
      isTrue,
    );

    expect(calls.single.method, 'update');
    expect(calls.single.arguments, {
      'domain': 'chat',
      'items': [
        {
          'url': 'hermes://chat?profile=default&id=abc',
          'title': 'Trip plan',
          'text': 'Booked the flights',
        },
      ],
      'remove': ['hermes://chat?profile=default&id=old'],
    });
  });

  test('isAvailable asks whether the device lets the index be used', () async {
    answer = (call) => false;

    expect(await index.isAvailable(), isFalse);
    expect(calls.single.method, 'isAvailable');
  });

  test('a runner that cannot say counts as available', () async {
    messenger.setMockMethodCallHandler(channel, null);

    expect(await index.isAvailable(), isTrue);
  });

  test('a call from the runner says the index can be used again', () async {
    var heard = 0;
    index.becameAvailable.listen((_) => heard++);

    await messenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('becameAvailable'),
      ),
      (_) {},
    );
    await Future<void>.delayed(Duration.zero);

    expect(heard, 1);
  });

  test('deleteDomain and deleteAll name the domain or none', () async {
    expect(await index.deleteDomain('memory'), isTrue);
    expect(await index.deleteAll(), isTrue);

    expect(
      [for (final call in calls) call.method],
      ['deleteDomain', 'deleteAll'],
    );
    expect(calls.first.arguments, {'domain': 'memory'});
  });

  test('takeLaunch asks the runner for the tapped link', () async {
    answer = (call) => 'hermes://chat?id=abc';

    expect(await index.takeLaunch(), Uri.parse('hermes://chat?id=abc'));
    expect(calls.single.method, 'take');
  });

  test('takeLaunch is null when nothing launched the app', () async {
    expect(await index.takeLaunch(), isNull);
  });

  test('a call from the runner takes the tapped link and emits it', () async {
    answer = (call) => 'hermes://chat?id=abc';
    final opened = <Uri>[];
    index.opened.listen(opened.add);

    await messenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(const MethodCall('opened')),
      (_) {},
    );
    await Future<void>.delayed(Duration.zero);

    expect(opened, [Uri.parse('hermes://chat?id=abc')]);
  });

  test('a failing platform call is swallowed, reported and logged', () async {
    answer = (call) => throw PlatformException(code: 'index', message: 'boom');

    expect(await index.replace('chat', [item]), isFalse);
    expect(await index.update('chat', upsert: [item], remove: []), isFalse);
    expect(await index.deleteDomain('chat'), isFalse);
    expect(await index.deleteAll(), isFalse);

    expect(events.named('spotlight.index_failed'), [
      {
        'operation': 'replace',
        'spotlight.domain': 'chat',
        'error.type': 'PlatformException',
      },
      {
        'operation': 'update',
        'spotlight.domain': 'chat',
        'error.type': 'PlatformException',
      },
      {
        'operation': 'delete_domain',
        'spotlight.domain': 'chat',
        'error.type': 'PlatformException',
      },
      {
        'operation': 'delete_all',
        'spotlight.domain': 'all',
        'error.type': 'PlatformException',
      },
    ]);
  });

  test('a runner without the channel counts as a failed call', () async {
    messenger.setMockMethodCallHandler(channel, null);

    expect(await index.replace('chat', [item]), isFalse);
    expect(await index.takeLaunch(), isNull);
  });

  test('no event holds a title, text, link or id', () async {
    answer = (call) => throw PlatformException(code: 'index', message: 'boom');

    await index.replace('chat', [item]);

    final logged = events.named('spotlight.index_failed').single.toString();
    for (final secret in ['Trip plan', 'Booked', 'hermes://', 'abc']) {
      expect(logged, isNot(contains(secret)));
    }
  });

  test('macOS uses the native index', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final mac = SpotlightIndex.forPlatform(events: events.call);
    addTearDown(mac.dispose);
    expect(await mac.replace('chat', [item]), isTrue);
    expect(calls.single.method, 'replace');
  });

  test('the platform index does nothing on unsupported platforms', () async {
    final none = SpotlightIndex.forPlatform(events: events.call);

    expect(await none.replace('chat', [item]), isTrue);
    expect(await none.deleteAll(), isTrue);
    expect(await none.takeLaunch(), isNull);
    expect(calls, isEmpty);
  });
}
