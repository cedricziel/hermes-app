import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/widgets/chat_history_state.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/loading_skeleton.dart';
import 'package:hermes_app/src/widgets/state_message.dart';

/// The loading and failed states of a stored chat's transcript, alone.
Widget _host(
  Widget child, {
  Brightness brightness = Brightness.light,
  bool reduceMotion = false,
  double textScale = 1,
  double? height,
  double? width,
}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: brightness == Brightness.light
      ? buildHermesLightTheme()
      : buildHermesDarkTheme(),
  home: MediaQuery(
    data: MediaQueryData(
      disableAnimations: reduceMotion,
      textScaler: TextScaler.linear(textScale),
    ),
    child: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: width, height: height, child: child),
      ),
    ),
  ),
);

const _fade = ValueKey('chat-history-fade');

void main() {
  final skeleton = find.byType(LoadingSkeleton);

  for (final height in [150.0, 100.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('the skeleton is clipped, not overflowing, in a ${height}px '
          'area at text scale $scale', (tester) async {
        await tester.pumpWidget(
          _host(
            const ChatHistoryState(
              status: ChatHistoryStatus.loading,
              delay: Duration.zero,
            ),
            height: height,
            width: 360,
            textScale: scale,
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));

        expect(skeleton, findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(tester.getSize(find.byType(ChatHistoryState)).height, height);
      });
    }
  }

  testWidgets('a phone in landscape with the keyboard open does not overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildHermesLightTheme(),
        home: const Scaffold(
          body: ChatHistoryState(
            status: ChatHistoryStatus.loading,
            delay: Duration.zero,
            bottomPadding: 56,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(skeleton, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the skeleton fades in when it appears after the delay', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const ChatHistoryState(status: ChatHistoryStatus.loading)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(skeleton, findsNothing);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 30));
    expect(skeleton, findsOneWidget);
    expect(tester.widget<Opacity>(find.byKey(_fade)).opacity, lessThan(1));

    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.widget<Opacity>(find.byKey(_fade)).opacity, 1);
  });

  testWidgets('under reduced motion the skeleton appears at full opacity', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const ChatHistoryState(status: ChatHistoryStatus.loading),
        reduceMotion: true,
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 30));

    expect(skeleton, findsOneWidget);
    expect(tester.widget<Opacity>(find.byKey(_fade)).opacity, 1);
  });

  for (final brightness in Brightness.values) {
    testWidgets('the bars are drawn in a visible colour (${brightness.name})', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const ChatHistoryState(
            status: ChatHistoryStatus.loading,
            delay: Duration.zero,
          ),
          brightness: brightness,
        ),
      );
      final scheme = Theme.of(tester.element(skeleton)).colorScheme;
      final bar = tester.widget<DecoratedBox>(
        find
            .descendant(of: skeleton, matching: find.byType(DecoratedBox))
            .first,
      );
      final color = (bar.decoration as BoxDecoration).color!;
      expect(color, isNot(scheme.surfaceContainerHighest));
      expect(color, isNot(scheme.surface));
    });
  }

  testWidgets('the bars grow with the text size', (tester) async {
    Future<double> bar(double scale) async {
      await tester.pumpWidget(
        _host(
          const ChatHistoryState(
            status: ChatHistoryStatus.loading,
            delay: Duration.zero,
          ),
          textScale: scale,
          height: 800,
          width: 360,
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      return tester.getSize(find.byType(FractionallySizedBox).first).height;
    }

    final normal = await bar(1);
    final large = await bar(2);
    expect(normal, 16);
    expect(large, 32);
  });

  testWidgets('the failed state is a polite live region with a Retry', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    var retried = 0;
    await tester.pumpWidget(
      _host(
        ChatHistoryState(
          status: ChatHistoryStatus.failed,
          onRetry: () => retried++,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    final node = tester.getSemantics(find.byType(StateMessage));
    expect(node.flagsCollection.isLiveRegion, isTrue);
    await tester.tap(find.text('Retry'));
    expect(retried, 1);
    handle.dispose();
  });
}
