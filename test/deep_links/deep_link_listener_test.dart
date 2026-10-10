import 'dart:async';

import 'package:flutter_otel/flutter_otel.dart' show BreadcrumbTrail;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/deep_links/deep_link_listener.dart';
import 'package:hermes_app/src/deep_links/deep_link_target.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';

void main() {
  late StreamController<Uri> links;
  late StreamController<void> signedOut;
  late Completer<void> firstFrame;
  late BreadcrumbTrail trail;
  late DeepLinks deepLinks;
  late int notified;

  setUp(() {
    links = StreamController<Uri>.broadcast(sync: true);
    signedOut = StreamController<void>.broadcast(sync: true);
    firstFrame = Completer<void>();
    trail = BreadcrumbTrail();
    deepLinks = DeepLinks(
      links: links.stream,
      signedOut: signedOut.stream,
      firstFrame: firstFrame.future,
      breadcrumbs: Breadcrumbs.of(trail),
    );
    notified = 0;
    deepLinks.addListener(() => notified++);
  });

  tearDown(() async {
    deepLinks.dispose();
    await links.close();
    await signedOut.close();
  });

  void arrive(String url) => links.add(Uri.parse(url));

  test('keeps a link until it is taken', () {
    arrive('hermes://kanban');

    expect(deepLinks.pending?.target, const OpenKanban());
    expect(notified, 1);
    expect(deepLinks.take()?.target, const OpenKanban());
    expect(deepLinks.pending, isNull);
    expect(deepLinks.take(), isNull);
  });

  test('the latest link wins', () {
    arrive('hermes://kanban');
    arrive('hermes://schedules?job=j1');

    expect(deepLinks.take()?.target, const OpenSchedules(jobId: 'j1'));
    expect(deepLinks.take(), isNull);
  });

  test('only the first link can be cold', () {
    arrive('hermes://requests');
    final first = deepLinks.take();
    arrive('hermes://kanban');

    expect(first?.cold, isTrue);
    expect(deepLinks.take()?.cold, isFalse);
  });

  test('a link after the first frame is warm', () async {
    firstFrame.complete();
    await Future<void>.delayed(Duration.zero);
    arrive('hermes://requests');

    expect(deepLinks.take()?.cold, isFalse);
  });

  test('keeps nothing for a malformed link', () {
    arrive('hermes://chat?profile=work');

    expect(deepLinks.pending, isNull);
    expect(notified, 0);
  });

  test('a malformed link does not drop a waiting one', () {
    arrive('hermes://kanban');
    arrive('hermes://memory');

    expect(deepLinks.take()?.target, const OpenKanban());
  });

  test('signing out drops the pending link', () {
    arrive('hermes://kanban');
    signedOut.add(null);

    expect(deepLinks.pending, isNull);
    expect(notified, 2);
  });

  group('breadcrumbs', () {
    List<String> crumbs() => [
      for (final c in trail.recent) '${c.name} ${c.attributes}',
    ];

    test('say why a link was ignored, with no part of the link', () {
      arrive('hermes://memory?secret=1');
      arrive('hermes://chat?profile=work&prompt=private');
      arrive('hermes:chat?id=1');

      expect(crumbs(), [
        'deeplink.ignored {reason: unknown}',
        'deeplink.ignored {reason: malformed}',
        'deeplink.ignored {reason: malformed}',
      ]);
    });

    test('call an invalid escape malformed and keep nothing', () {
      arrive('hermes://new?prompt=%E2%82');

      expect(crumbs(), ['deeplink.ignored {reason: malformed}']);
      expect(deepLinks.pending, isNull);
    });

    test('survive an error on the link stream', () {
      links.addError(const FormatException('bad'));
      arrive('hermes://kanban');

      expect(crumbs(), ['deeplink.ignored {reason: malformed}']);
      expect(deepLinks.take()?.target, const OpenKanban());
    });

    test('say nothing of the other schemes app_links also delivers', () {
      arrive('hermes-activity://chat?id=abc');
      arrive('hermes-share://x');
      arrive('ShareMedia-com.example://dataUrl=x');
      arrive('https://example.com/hermes');

      expect(crumbs(), isEmpty);
      expect(deepLinks.pending, isNull);
    });
  });

  test('another scheme is not the first link, so it cannot make one cold', () {
    arrive('hermes-activity://chat?id=abc');
    arrive('hermes://kanban');

    expect(deepLinks.take()?.cold, isTrue);
  });
}
