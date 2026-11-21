import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/deep_links/deep_link_listener.dart';
import 'package:hermes_app/src/deep_links/deep_link_source.dart';
import 'package:hermes_app/src/deep_links/deep_link_target.dart';
import 'package:hermes_app/src/deep_links/deep_link_uri.dart';

void main() {
  group('deepLinksSupported', () {
    test('Linux registers the scheme, Windows does not', () {
      for (final platform in [
        TargetPlatform.iOS,
        TargetPlatform.macOS,
        TargetPlatform.android,
        TargetPlatform.linux,
      ]) {
        expect(deepLinksSupported(platform), isTrue, reason: '$platform');
      }
      expect(deepLinksSupported(TargetPlatform.windows), isFalse);
      expect(deepLinksSupported(TargetPlatform.fuchsia), isFalse);
      expect(deepLinksSupported(TargetPlatform.linux, web: true), isFalse);
    });
  });

  group('withLaunchLink', () {
    final prompt = deepLinkUri(const NewChat(prompt: 'hello'));

    test('a link in the launch arguments reaches DeepLinks as cold', () async {
      final live = StreamController<Uri>.broadcast(sync: true);
      final shown = Completer<void>();
      final deepLinks = DeepLinks(
        links: withLaunchLink(live.stream, ['--flag', prompt.toString()]),
        firstFrame: shown.future,
      );
      addTearDown(() async {
        deepLinks.dispose();
        await live.close();
      });
      await pumpEventQueue();

      final pending = deepLinks.take();
      expect(pending?.target, const NewChat(prompt: 'hello'));
      expect(pending?.cold, isTrue);
    });

    test('later links from the running instance follow it', () async {
      final live = StreamController<Uri>.broadcast(sync: true);
      addTearDown(live.close);
      final seen = <Uri>[];
      final sub = withLaunchLink(live.stream, [
        prompt.toString(),
      ]).listen(seen.add);
      addTearDown(sub.cancel);
      await pumpEventQueue();
      live.add(Uri.parse('hermes://kanban'));
      await pumpEventQueue();

      expect(seen, [prompt, Uri.parse('hermes://kanban')]);
    });

    test('arguments that are not hermes links add nothing', () async {
      final live = StreamController<Uri>.broadcast(sync: true);
      addTearDown(live.close);
      final seen = <Uri>[];
      final sub = withLaunchLink(live.stream, [
        '--verbose',
        'https://example.com',
      ]).listen(seen.add);
      addTearDown(sub.cancel);
      await pumpEventQueue();

      expect(seen, isEmpty);
    });
  });
}
