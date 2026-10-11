import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/deep_links/deep_link_listener.dart';
import 'package:hermes_app/src/deep_links/deep_link_target.dart';
import 'package:hermes_app/src/spotlight/spotlight_links.dart';

import '../support/fake_spotlight_index.dart';
import '../support/recorded_events.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeSpotlightIndex index;
  late RecordedEvents events;
  late StreamController<Uri> system;
  late Completer<void> firstFrame;
  late DeepLinks deepLinks;
  var started = false;

  Future<void> start() async {
    started = true;
    deepLinks = DeepLinks(
      links: linksWithSpotlight(system.stream, index, events: events.call),
      firstFrame: firstFrame.future,
    );
    await pumpEventQueue();
  }

  setUp(() {
    index = FakeSpotlightIndex();
    events = RecordedEvents();
    system = StreamController<Uri>.broadcast(sync: true);
    firstFrame = Completer<void>();
    started = false;
  });

  tearDown(() async {
    if (started) deepLinks.dispose();
    index.dispose();
    await system.close();
  });

  test('a tapped result reaches the deep links as an OpenChat', () async {
    await start();

    index.openedController.add(Uri.parse('hermes://chat?profile=work&id=abc'));

    expect(
      deepLinks.pending?.target,
      const OpenChat(profile: 'work', threadId: 'abc'),
    );
  });

  test('the result that launched the app is opened as a cold link', () async {
    index.launch = Uri.parse('hermes://chat?profile=work&id=abc');

    await start();

    expect(
      deepLinks.pending?.target,
      const OpenChat(profile: 'work', threadId: 'abc'),
    );
    expect(deepLinks.pending?.cold, isTrue);
  });

  test('links from the system still arrive', () async {
    await start();

    system.add(Uri.parse('hermes://kanban'));

    expect(deepLinks.pending?.target, const OpenKanban());
  });

  test('an identifier that is not a hermes link is ignored', () async {
    await start();

    index.openedController.add(Uri.parse('https://example.com/chat?id=abc'));

    expect(deepLinks.pending, isNull);
    expect(events.named('spotlight.opened'), isEmpty);
  });

  test(
    'logs the domain of an opened result and nothing that names it',
    () async {
      index.launch = Uri.parse('hermes://chat?profile=work&id=abc');
      await start();
      index.openedController.add(Uri.parse('hermes://chat?id=def'));

      expect(events.named('spotlight.opened'), [
        {'spotlight.domain': 'chat'},
        {'spotlight.domain': 'chat'},
      ]);
    },
  );

  test('stops listening to both sources when cancelled', () async {
    final subscription = linksWithSpotlight(
      system.stream,
      index,
    ).listen((_) {});
    await pumpEventQueue();
    expect(system.hasListener, isTrue);
    expect(index.openedController.hasListener, isTrue);

    await subscription.cancel();

    expect(system.hasListener, isFalse);
    expect(index.openedController.hasListener, isFalse);
  });
}
