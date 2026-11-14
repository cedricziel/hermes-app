import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/voice/calls/active_call.dart';
import 'package:hermes_app/src/voice/hands_free_strip_layer.dart';
import 'package:hermes_app/src/voice/widgets/hands_free_strip.dart';
import 'package:provider/provider.dart';

import 'call_harness.dart';

void main() {
  late CallHarness h;
  late ActiveCallRegistry registry;
  final navigator = GlobalKey<NavigatorState>();

  setUp(() {
    h = CallHarness();
    registry = ActiveCallRegistry();
    addTearDown(registry.dispose);
  });
  tearDown(() => h.dispose());

  /// The app's own arrangement: the layer wraps the navigator in the app's
  /// builder, so pages pushed over the home page sit under the strip too.
  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    Widget? home,
    bool provide = true,
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Widget app = MaterialApp(
      navigatorKey: navigator,
      theme: buildHermesLightTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => HandsFreeStripLayer(child: child!),
      home: home ?? const Scaffold(body: Center(child: Text('chat'))),
    );
    if (provide) {
      app = ChangeNotifierProvider.value(value: registry, child: app);
    }
    await tester.pumpWidget(app);
  }

  Future<void> startCall(WidgetTester tester) async {
    await tester.runAsync(() async {
      await h.activate();
      registry.attach(h.call);
    });
    await tester.pump();
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
  }

  final strip = find.byType(HandsFreeStrip);

  testWidgets('no call, no strip, and no provider is fine', (tester) async {
    await pump(tester);
    expect(strip, findsNothing);
    await pump(tester, provide: false);
    expect(find.text('chat'), findsOneWidget);
    expect(strip, findsNothing);
  });

  testWidgets('a running call shows the strip under the status bar', (
    tester,
  ) async {
    await pump(tester);
    await startCall(tester);
    expect(strip, findsOneWidget);
    expect(
      find.text('Hands-free on · microphone open', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('chat'), findsOneWidget);
  });

  testWidgets('the strip stays over a page pushed on the navigator', (
    tester,
  ) async {
    await pump(tester);
    await startCall(tester);
    unawaited(
      navigator.currentState!.push<void>(
        MaterialPageRoute(
          builder: (_) => const Scaffold(body: Center(child: Text('settings'))),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('settings'), findsOneWidget);
    expect(strip, findsOneWidget);
  });

  testWidgets('the page keeps its state when the strip comes and goes', (
    tester,
  ) async {
    await pump(tester, home: const Scaffold(body: _Counter()));
    await tester.tap(find.byType(_Counter));
    await tester.pump();
    expect(find.text('taps 1'), findsOneWidget);
    await startCall(tester);
    expect(strip, findsOneWidget);
    expect(find.text('taps 1'), findsOneWidget);
    await tester.runAsync(() => h.call.end());
    await tester.pump();
    expect(strip, findsNothing);
    expect(find.text('taps 1'), findsOneWidget);
  });

  testWidgets('End on the strip ends the call and the strip goes', (
    tester,
  ) async {
    await pump(tester);
    await startCall(tester);
    await tester.tap(find.text('End'));
    await settle(tester);
    expect(h.call.ended, isTrue);
    expect(strip, findsNothing);
  });

  testWidgets('it follows mute and the paused capture', (tester) async {
    await pump(tester);
    await startCall(tester);
    await tester.runAsync(() => h.call.setMuted(true));
    await tester.pump();
    expect(
      find.textContaining('microphone muted', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets(
    'a tone pauses capture for a moment, which the strip calls open',
    (tester) async {
      await tester.runAsync(() => h.rebuild(withTones: true));
      await pump(tester);
      await startCall(tester);
      h.tones.gate = Completer<void>();
      await tester.runAsync(() async {
        await h.say('Hello');
      });
      await tester.pump();
      expect(
        h.call.capturePaused,
        isTrue,
        reason: 'the tone has capture paused',
      );
      expect(
        find.text('Hands-free on · microphone open', findRichText: true),
        findsOneWidget,
      );
      h.tones.gate!.complete();
      await tester.runAsync(() => pumpEventQueue());
    },
  );

  testWidgets('Waiting for you shows paused', (tester) async {
    await pump(tester);
    await startCall(tester);
    h.agent.setThreadAttention(true);
    await tester.pump();
    expect(
      find.text('Hands-free on · microphone paused', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('while the call screen is open the strip has no End', (
    tester,
  ) async {
    await pump(tester);
    await startCall(tester);
    expect(find.text('End'), findsOneWidget);
    final owner = Object();
    registry.screenOpened(owner);
    await tester.pump();
    expect(strip, findsOneWidget);
    expect(find.text('End'), findsNothing);
    // A screen that was replaced cannot close the new one's mark.
    registry.screenClosed(Object());
    await tester.pump();
    expect(find.text('End'), findsNothing);
    registry.screenClosed(owner);
    await tester.pump();
    expect(find.text('End'), findsOneWidget);
  });

  testWidgets('an unconfirmed close keeps a strip that says so, with no End', (
    tester,
  ) async {
    h.bridge.stopCaptureGate = Completer<void>();
    await pump(tester);
    await startCall(tester);
    unawaited(registry.end());
    await settle(tester);
    expect(h.call.microphoneUnconfirmed, isTrue);
    expect(registry.active, isFalse);
    expect(registry.microphoneMayBeOpen, isTrue);
    expect(
      find.text('Microphone may still be open', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('End'), findsNothing);
    // It can be dismissed, and a new call that ends the same way shows it
    // again.
    await tester.tap(find.text('Dismiss'));
    await tester.pump();
    expect(strip, findsNothing);
    expect(registry.microphoneMayBeOpen, isFalse);
    // A new call replaces the warning.
    final next = h.build();
    addTearDown(() async {
      await next.end();
      next.dispose();
    });
    registry.attach(next);
    await tester.pump();
    expect(
      find.text('Microphone may still be open', findRichText: true),
      findsNothing,
    );
  });

  testWidgets('release ends a call whose owner goes and keeps its warning', (
    tester,
  ) async {
    h.bridge.stopCaptureGate = Completer<void>();
    await pump(tester);
    await startCall(tester);
    final released = registry.release(h.call);
    // The owner disposes the call right after, which tells nobody anything.
    h.call.dispose();
    await settle(tester);
    await tester.runAsync(() => released);
    await tester.pump();
    expect(registry.active, isFalse);
    expect(
      find.text('Microphone may still be open', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('release of a call that is not the current one does nothing', (
    tester,
  ) async {
    await pump(tester);
    await startCall(tester);
    final other = h.build();
    addTearDown(() async {
      await other.end();
      other.dispose();
    });
    await tester.runAsync(() => registry.release(other));
    await tester.pump();
    expect(h.call.ended, isFalse);
    expect(registry.active, isTrue);
    expect(strip, findsOneWidget);
  });

  testWidgets('a confirmed release leaves no strip', (tester) async {
    await pump(tester);
    await startCall(tester);
    await tester.runAsync(() async {
      final released = registry.release(h.call);
      h.call.dispose();
      await released;
    });
    await tester.pump();
    expect(registry.active, isFalse);
    expect(strip, findsNothing);
  });
}

class _Counter extends StatefulWidget {
  const _Counter();
  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int taps = 0;
  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () => setState(() => taps++),
    child: Center(child: Text('taps $taps')),
  );
}
