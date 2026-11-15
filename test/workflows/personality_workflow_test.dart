import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/api/hermes_repositories.dart';
import 'package:hermes_app/src/profiles/soul/open_soul.dart';
import 'package:hermes_app/src/profiles/soul/soul_availability.dart';
import 'package:hermes_app/src/profiles/soul/soul_telemetry.dart';
import 'package:provider/provider.dart';

import '../support/fake_hermes_server.dart';
import '../support/screenshot_recorder.dart';
import '../support/workflow_app.dart';

// Invented text: screenshots are published.
const _profile = 'work';
const _path = '/api/profiles/$_profile/soul';

const _loaded =
    'You are Mara, the support assistant for a small bakery.\n'
    '\n'
    '# How to talk\n'
    '- Be warm and brief.\n'
    "- Answer in the customer's language.\n"
    '- Never promise a delivery date you cannot check.';

const _edited =
    'You are Mara, the support assistant for a small bakery with two '
    'shops.\n'
    '\n'
    '# How to talk\n'
    '- Be warm and brief.\n'
    "- Answer in the customer's language.\n"
    '- Never promise a delivery date you cannot check.\n'
    '- Offer the opening hours when someone asks about a visit.';

const _someoneElse =
    'You are Mara, the support assistant for a bakery with two shops.\n'
    '\n'
    '# How to talk\n'
    '- Be warm and very brief.\n'
    '- Offer the opening hours when someone asks about a visit.';

/// Editing a profile's personality: open the page, edit, Save asks, the file
/// changed on the server meanwhile, the server's version, Replace anyway,
/// Saved; and the Discard question on the way out. Phone and desktop, light
/// and dark.
void main() {
  late FakeHermesServer server;
  var fileText = _loaded;
  final puts = <String>[];
  var reads = 0;
  // The second read of a save (the one that checks) finds someone else's text.
  var changeOnSecondRead = false;

  setUp(() {
    fileText = _loaded;
    puts.clear();
    reads = 0;
    changeOnSecondRead = false;
    server = FakeHermesServer()
      ..onRequest('GET', _path, (_) {
        reads++;
        if (changeOnSecondRead && reads == 2) fileText = _someoneElse;
        return (status: 200, body: {'content': fileText, 'exists': true});
      })
      ..onRequest('PUT', _path, (request) {
        final sent =
            (jsonBody(request)! as Map<String, Object?>)['content']! as String;
        puts.add(sent);
        fileText = sent;
        return (status: 200, body: {'ok': true});
      });
  });

  // Phone and desktop in both themes; Android (the Material bar, two-button
  // dialogs, the Material bottom sheet) and an iPad (a pushed page at 820 pt,
  // Save and Revert under the editor, the changed state as a dialog) in light.
  for (final (name, size, platform, brightnesses) in [
    (
      'phone',
      phoneSize,
      TargetPlatform.iOS,
      [Brightness.light, Brightness.dark],
    ),
    (
      'desktop',
      desktopSize,
      TargetPlatform.macOS,
      [Brightness.light, Brightness.dark],
    ),
    ('android', phoneSize, TargetPlatform.android, [Brightness.light]),
    ('ipad', const Size(820, 1180), TargetPlatform.iOS, [Brightness.light]),
  ]) {
    for (final brightness in brightnesses) {
      final mode = brightness == Brightness.dark ? 'dark' : 'light';
      testWidgets('$name, $mode: edit, save question, conflict, save', (
        tester,
      ) async {
        final shots = ScreenshotRecorder('personality-$name-$mode');
        final availability = SoulAvailability();
        addTearDown(availability.dispose);
        await pumpScreen(
          tester,
          shots,
          Builder(
            builder: (context) => Scaffold(
              appBar: AppBar(title: const Text('Profile')),
              body: Center(
                child: TextButton(
                  onPressed: () => unawaited(
                    openSoul(
                      context,
                      profile: _profile,
                      from: SoulOpenedFrom.profilesPage,
                    ),
                  ),
                  child: const Text('Personality'),
                ),
              ),
            ),
          ),
          size: size,
          brightness: brightness,
          platform: platform,
          providers: [
            Provider<HermesRepositories>.value(
              value: HermesRepositories(server.client()),
            ),
            ChangeNotifierProvider<SoulAvailability?>.value(
              value: availability,
            ),
          ],
        );
        await tester.tap(find.text('Personality'));
        await tester.pumpAndSettle();
        await shots.capture(tester, 'loaded');

        // Typing at the end of the text.
        await tester.enterText(find.byType(TextField), _edited);
        await animate(tester);
        await shots.capture(tester, 'edited');

        // The phone bar has Save as a text action; the Mac and wide windows
        // (an iPad too) have it under the editor.
        final barSave = name == 'phone' || name == 'android';
        Finder save() => barSave
            ? find.widgetWithText(TextButton, 'Save')
            : find.widgetWithText(FilledButton, 'Save');

        // Save asks first; nothing is sent.
        await tester.tap(save());
        await tester.pumpAndSettle();
        await shots.capture(tester, 'save-question');
        expect(puts, isEmpty);

        // Someone else saved meanwhile: the check read finds it.
        changeOnSecondRead = true;
        await tester.tap(find.text('Replace'));
        await tester.pumpAndSettle();
        await shots.capture(tester, 'changed-on-server');
        expect(puts, isEmpty);

        await tester.tap(find.text("Show server's version"));
        await tester.pumpAndSettle();
        await shots.capture(tester, 'server-version');

        await tester.tap(find.text('Replace anyway'));
        await tester.pumpAndSettle();
        await shots.capture(tester, 'saved');
        expect(puts, [_edited]);
        expect(find.text('Saved. New chats use it.'), findsOneWidget);

        // Edit again and try to leave: Discard asks, Keep editing is first.
        await tester.enterText(find.byType(TextField), '$_edited\n- Be kind.');
        await animate(tester);
        if (name == 'desktop') {
          await tester.tap(find.byKey(const Key('settings-back')));
        } else {
          await tester.pageBack();
        }
        await tester.pumpAndSettle();
        await shots.capture(tester, 'discard-question');
        expect(find.text('Discard changes?'), findsOneWidget);
        await tester.tap(find.text('Discard'));
        await tester.pumpAndSettle();
        expect(find.text('Personality'), findsOneWidget);
        expect(puts, [_edited]);
      });
    }
  }

  /// The pages that are not the editor, and the states around a save, on a
  /// phone and on a desktop window.
  for (final (name, size, platform) in [
    ('phone', phoneSize, TargetPlatform.iOS),
    ('desktop', desktopSize, TargetPlatform.macOS),
  ]) {
    testWidgets('$name: lost answer, saving, and the pages without an editor', (
      tester,
    ) async {
      final shots = ScreenshotRecorder('personality-states-$name');
      final availability = SoulAvailability();
      addTearDown(availability.dispose);
      Future<void> open() async {
        // A fresh app, so the page opens anew.
        await tester.pumpWidget(const SizedBox.shrink());
        await pumpScreen(
          tester,
          shots,
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => unawaited(
                    openSoul(
                      context,
                      profile: _profile,
                      from: SoulOpenedFrom.sidebar,
                    ),
                  ),
                  child: const Text('Personality'),
                ),
              ),
            ),
          ),
          size: size,
          platform: platform,
          providers: [
            Provider<HermesRepositories>.value(
              value: HermesRepositories(server.client()),
            ),
            ChangeNotifierProvider<SoulAvailability?>.value(
              value: availability,
            ),
          ],
        );
        await tester.tap(find.text('Personality'));
        // A spinner may be up: a few frames, not a settle.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
      }

      Finder save() => name == 'phone'
          ? find.widgetWithText(TextButton, 'Save')
          : find.widgetWithText(FilledButton, 'Save');

      // Reading takes a while: the loading state.
      final read = Completer<FakeResponse>();
      server.onRequest('GET', _path, (_) => read.future);
      await open();
      await shots.capture(tester, 'loading');
      read.complete((status: 200, body: {'content': _loaded, 'exists': true}));
      server.onRequest(
        'GET',
        _path,
        (_) => (status: 200, body: {'content': fileText, 'exists': true}),
      );
      await tester.pumpAndSettle();

      // The write is slow: read-only editor, Saving.
      await tester.enterText(find.byType(TextField), _edited);
      await animate(tester);
      final write = Completer<FakeResponse>();
      server.onRequest('PUT', _path, (_) => write.future);
      await tester.tap(save());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Replace'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await shots.capture(tester, 'saving');

      // The answer is lost: nothing says Saved, the text stays, Check.
      write.complete((status: 200, body: <String, Object?>{}));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'lost-answer');
      expect(find.text("Couldn't confirm the save"), findsOneWidget);

      // The server still has the earlier text.
      await tester.tap(find.widgetWithText(TextButton, 'Check'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'earlier-text');

      // A read that fails shows no editor; a missing profile and an old
      // server say so.
      server.on('GET', _path, 'Internal Server Error', status: 500);
      await open();
      await shots.capture(tester, 'read-failed');
      server.on('GET', _path, {
        'detail': "Profile 'work' does not exist.",
      }, status: 404);
      await open();
      await shots.capture(tester, 'profile-gone');
      server.on('GET', _path, {
        'detail': 'No such API endpoint: /api/profiles/work/soul',
      }, status: 404);
      await open();
      await shots.capture(tester, 'unsupported');
      expect(availability.shown, isFalse);
    });
  }
}
