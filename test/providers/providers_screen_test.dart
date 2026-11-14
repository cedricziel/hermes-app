import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/providers/provider_detail_pane.dart';
import 'package:hermes_app/src/providers/widgets/provider_detail_frame.dart';
import 'package:hermes_app/src/providers/widgets/provider_detail_view.dart';
import 'package:hermes_app/src/providers/widgets/provider_list_view.dart';

import 'fake_provider_backend.dart';
import 'providers_screen_rig.dart';

const _fakeKey = 'sk-or-v1-test-aaaa-4f2a';

/// A backend where OpenRouter is connected and serves the default model.
FakeProviderBackend _connected() => FakeProviderBackend()
  ..keys['OPENROUTER_API_KEY'] = FakeProviderBackend.redact(_fakeKey)
  ..defaultProvider = 'openrouter'
  ..defaultModel = 'example-model-a';

/// OpenRouter and a Nous sign-in.
FakeProviderBackend _two() => _connected()..signedIn.add('nous');

const _settle = ProvidersRig.settle;

Future<void> _openKeyForm(WidgetTester tester) async {
  await tester.tap(_row('openrouter'));
  await _settle(tester);
}

Finder _row(String id) => find.byKey(ValueKey('provider-row-$id'));

void main() {
  group('layout', () {
    testWidgets('a phone pushes the detail as a page', (tester) async {
      final rig = ProvidersRig(backend: _connected());
      await rig.pump(tester);

      expect(find.byType(ProviderListView), findsOneWidget);
      expect(find.byType(ProviderDetailView), findsNothing);
      expect(find.text('work · 1 connected'), findsOneWidget);

      await tester.tap(_row('openrouter'));
      await _settle(tester);

      expect(find.byType(ProviderDetailPage), findsOneWidget);
      expect(find.textContaining('Connected with an API key'), findsOneWidget);
    });

    for (final (name, size, platform, split) in [
      ('900 points', const Size(900, 700), TargetPlatform.android, true),
      ('899 points', const Size(899, 700), TargetPlatform.android, false),
      ('a full-screen iPad', const Size(834, 1194), TargetPlatform.iOS, true),
      ('a split iPad window', const Size(507, 1194), TargetPlatform.iOS, false),
      ('a Mac at 560 points', const Size(560, 700), TargetPlatform.macOS, true),
      (
        'a Mac at 559 points',
        const Size(559, 700),
        TargetPlatform.macOS,
        false,
      ),
    ]) {
      testWidgets('$name: ${split ? 'beside' : 'below'} the list', (
        tester,
      ) async {
        final rig = ProvidersRig(backend: _two());
        await rig.pump(tester, size: size, platform: platform);

        expect(find.byType(ProviderListView), findsOneWidget);
        expect(
          find.byType(ProviderDetailView),
          split ? findsOneWidget : findsNothing,
        );
        if (!split) return;
        // The first connected provider is selected, and another can be picked.
        expect(
          find.textContaining('Connected with an API key'),
          findsOneWidget,
        );
        await tester.tap(_row('nous'));
        await _settle(tester);
        expect(find.byType(ProviderDetailPage), findsNothing);
        expect(find.text('Signed in'), findsWidgets);
        expect(find.textContaining('Connected with an API key'), findsNothing);
      });
    }

    testWidgets('the pane beside the list names the provider', (tester) async {
      final rig = ProvidersRig(backend: _two());
      await rig.pump(tester, size: const Size(1000, 700));
      final pane = find.byType(ProviderDetailPane);
      expect(
        find.descendant(
          of: pane.hitTestable(),
          matching: find.text('OpenRouter'),
        ),
        findsNothing,
      );
      expect(find.byType(ProviderDetailHeader), findsOneWidget);
      expect(
        tester
            .widget<ProviderDetailHeader>(find.byType(ProviderDetailHeader))
            .name,
        'OpenRouter',
      );
      await tester.tap(_row('nous'));
      await _settle(tester);
      expect(
        tester
            .widget<ProviderDetailHeader>(find.byType(ProviderDetailHeader))
            .name,
        'Nous Portal',
      );
    });

    testWidgets('the header starts where the detail does', (tester) async {
      final rig = ProvidersRig(backend: _two());
      await rig.pump(tester, size: const Size(1280, 700));
      final header = tester.getTopLeft(find.byType(ProviderDetailHeader)).dx;
      final text = tester
          .getTopLeft(
            find.descendant(
              of: find.byType(ProviderDetailHeader),
              matching: find.text('OpenRouter'),
            ),
          )
          .dx;
      final section = tester
          .getTopLeft(
            find
                .byWidgetPredicate(
                  (w) =>
                      w is Text &&
                      (w.data ?? '').toLowerCase() == 'default model',
                )
                .last,
          )
          .dx;
      expect(text, closeTo(section, 1));
      expect(header, lessThan(text + 1));
    });

    testWidgets('the pane says where to start while nothing is connected', (
      tester,
    ) async {
      final rig = ProvidersRig();
      await rig.pump(tester, size: const Size(1000, 700));
      expect(find.byType(ProviderDetailPlaceholder), findsOneWidget);
      expect(find.text('Pick one in the list to connect it.'), findsOneWidget);
      expect(find.byType(ProviderDetailHeader), findsNothing);
    });

    testWidgets('the Add provider button scrolls to the providers to add', (
      tester,
    ) async {
      final rig = ProvidersRig(backend: _two());
      await rig.pump(
        tester,
        size: const Size(1000, 360),
        platform: TargetPlatform.macOS,
      );
      final heading = find.text('Add a provider');
      expect(tester.getTopLeft(heading).dy, greaterThan(360 - 100));

      await tester.tap(find.byTooltip('Add Provider'));
      await _settle(tester);

      expect(tester.getTopLeft(heading).dy, lessThan(200));
    });
  });

  group('forms', () {
    testWidgets('a phone opens a form as a bottom sheet', (tester) async {
      final rig = ProvidersRig();
      await rig.pump(tester);
      await _openKeyForm(tester);

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('Connect OpenRouter'), findsOneWidget);
    });

    testWidgets('macOS opens a dialog, never a bottom sheet', (tester) async {
      final rig = ProvidersRig();
      await rig.pump(
        tester,
        size: const Size(1000, 800),
        platform: TargetPlatform.macOS,
      );
      await _openKeyForm(tester);

      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('Connect OpenRouter'), findsOneWidget);
    });

    testWidgets('a Mac dialog leads with Cancel, not a back chevron', (
      tester,
    ) async {
      final rig = ProvidersRig();
      await rig.pump(
        tester,
        size: const Size(1000, 800),
        platform: TargetPlatform.macOS,
      );
      await _openKeyForm(tester);

      final dialog = find.byType(Dialog);
      expect(
        find.descendant(of: dialog, matching: find.text('Cancel')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: dialog,
          matching: find.byKey(const Key('settings-back')),
        ),
        findsNothing,
      );
      // A Mac control is 28 points tall.
      expect(
        tester.getSize(find.byKey(const Key('settings-cancel'))).height,
        greaterThanOrEqualTo(28),
      );
      await tester.tap(find.byKey(const Key('settings-cancel')));
      await _settle(tester);
      expect(find.byType(Dialog), findsNothing);
      expect(find.byType(ProviderListView), findsOneWidget);
    });

    testWidgets('Cancel is worded in German too', (tester) async {
      final rig = ProvidersRig();
      await rig.pump(tester, locale: const Locale('de'));
      await tester.tap(_row('openrouter'));
      await _settle(tester);
      expect(find.text('Abbrechen'), findsOneWidget);
      expect(find.text('Cancel'), findsNothing);
    });

    testWidgets('the endpoint form starts its fields at one x', (tester) async {
      final rig = ProvidersRig();
      await rig.pump(tester);
      await tester.scrollUntilVisible(find.text('Custom endpoint'), 200);
      await tester.tap(find.text('Custom endpoint'));
      await _settle(tester);
      final xs = [
        for (var i = 0; i < 3; i++)
          tester.getTopLeft(find.byType(TextField).at(i)).dx,
      ];
      expect(xs[1], xs[0]);
      expect(xs[2], xs[0]);
    });

    testWidgets('a narrow Mac window also opens a dialog', (tester) async {
      final rig = ProvidersRig();
      await rig.pump(
        tester,
        size: const Size(500, 800),
        platform: TargetPlatform.macOS,
      );
      await _openKeyForm(tester);

      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(Dialog), findsOneWidget);
    });

    testWidgets('a wide window opens a dialog', (tester) async {
      final rig = ProvidersRig();
      await rig.pump(
        tester,
        size: const Size(1000, 800),
        platform: TargetPlatform.android,
      );
      await _openKeyForm(tester);

      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(Dialog), findsOneWidget);
    });

    testWidgets('Android opens a full-screen page on a phone', (tester) async {
      final rig = ProvidersRig();
      await rig.pump(tester, platform: TargetPlatform.android);
      await _openKeyForm(tester);

      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('Connect OpenRouter'), findsOneWidget);
      final route = ModalRoute.of(tester.element(find.byType(TextField)));
      expect(route, isA<MaterialPageRoute<dynamic>>());
      expect((route! as MaterialPageRoute<dynamic>).fullscreenDialog, isTrue);
    });

    testWidgets('Escape closes a form on desktop', (tester) async {
      final rig = ProvidersRig();
      await rig.pump(
        tester,
        size: const Size(1000, 800),
        platform: TargetPlatform.macOS,
      );
      await _openKeyForm(tester);
      expect(find.byType(Dialog), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await _settle(tester);

      expect(find.byType(Dialog), findsNothing);
      // Only the form closed.
      expect(find.byType(ProviderListView), findsOneWidget);
      expect(rig.backend.server.requestsTo('PUT', '/api/env'), isEmpty);
    });

    testWidgets('Return submits a form on desktop once it has a key', (
      tester,
    ) async {
      final rig = ProvidersRig();
      await rig.pump(
        tester,
        size: const Size(1000, 800),
        platform: TargetPlatform.macOS,
      );
      await _openKeyForm(tester);

      // Nothing to submit yet.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await _settle(tester);
      expect(rig.backend.server.requestsTo('PUT', '/api/env'), isEmpty);
      expect(find.byType(Dialog), findsOneWidget);

      await tester.enterText(find.byType(TextField), _fakeKey);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await _settle(tester);

      expect(rig.backend.server.requestsTo('PUT', '/api/env'), hasLength(1));
    });

    testWidgets('a key goes through the form to the default model step', (
      tester,
    ) async {
      final rig = ProvidersRig();
      await rig.pump(tester, pushed: true);
      await _openKeyForm(tester);

      await tester.enterText(find.byType(TextField), _fakeKey);
      await tester.pump();
      await tester.tap(find.text('Save'));
      await _settle(tester);

      final put = rig.backend.server.requestsTo('PUT', '/api/env').single;
      expect(put.queryParameters['profile'], 'work');
      expect(rig.backend.defaultModel, 'example-model-a');
      expect(find.text("You're ready"), findsOneWidget);
      expect(rig.changed, greaterThan(0));

      await tester.tap(find.text('Start chatting'));
      await _settle(tester);
      // The screen was opened from the chat, so it goes back to it.
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(ProviderListView), findsNothing);
      expect(find.text('open providers'), findsOneWidget);
    });

    testWidgets('Cancel closes the form and clears the key', (tester) async {
      final rig = ProvidersRig();
      await rig.pump(tester);
      await _openKeyForm(tester);
      await tester.enterText(find.byType(TextField), _fakeKey);
      await tester.pump();
      final controller = tester
          .widget<TextField>(find.byType(TextField))
          .controller!;

      await tester.tap(find.text('Cancel'));
      await _settle(tester);

      expect(find.byType(BottomSheet), findsNothing);
      expect(controller.text, isEmpty);
      expect(rig.backend.server.requestsTo('PUT', '/api/env'), isEmpty);
    });
  });

  group('pull to refresh', () {
    Future<void> pull(WidgetTester tester) async {
      await tester.fling(
        find.byType(ListView).first,
        const Offset(0, 400),
        1000,
      );
      await _settle(tester);
    }

    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      testWidgets('$platform reads again when pulled', (tester) async {
        final rig = ProvidersRig(backend: _connected());
        await rig.pump(tester, platform: platform);
        expect(find.byType(RefreshIndicator), findsOneWidget);
        final before = rig.backend.server
            .requestsTo('GET', '/api/model/options')
            .length;

        await pull(tester);

        expect(
          rig.backend.server.requestsTo('GET', '/api/model/options').length,
          before + 1,
        );
      });
    }

    testWidgets('macOS has no pull to refresh', (tester) async {
      final rig = ProvidersRig(backend: _connected());
      await rig.pump(
        tester,
        size: const Size(1000, 800),
        platform: TargetPlatform.macOS,
      );
      expect(find.byType(RefreshIndicator), findsNothing);
    });

    testWidgets('Command R reads again on a Mac', (tester) async {
      final rig = ProvidersRig(backend: _connected());
      await rig.pump(
        tester,
        size: const Size(1000, 800),
        platform: TargetPlatform.macOS,
      );
      final before = rig.backend.server
          .requestsTo('GET', '/api/model/options')
          .length;

      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await _settle(tester);

      expect(
        rig.backend.server.requestsTo('GET', '/api/model/options').length,
        before + 1,
      );
    });
  });
}
