import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/widgets/chat_earlier_messages_failed_row.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/app_banner.dart';

Widget _host(
  Widget child, {
  TargetPlatform platform = TargetPlatform.android,
  double textScale = 1,
  double width = 360,
}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: buildHermesLightTheme().copyWith(platform: platform),
  home: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
    child: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: width, child: child),
      ),
    ),
  ),
);

void main() {
  final retry = find.byType(TextButton);

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('Retry is at least 44 high on ${platform.name} and reads '
        'once per tap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          ChatEarlierMessagesFailedRow(
            status: ChatEarlierMessagesStatus.failed,
            onRetry: () => taps++,
          ),
          platform: platform,
        ),
      );

      expect(find.text("Couldn't load earlier messages"), findsOneWidget);
      expect(tester.getSize(retry).height, greaterThanOrEqualTo(44));
      await tester.tap(retry);
      expect(taps, 1);
    });
  }

  testWidgets('on desktop Retry is compact', (tester) async {
    await tester.pumpWidget(
      _host(
        ChatEarlierMessagesFailedRow(
          status: ChatEarlierMessagesStatus.failed,
          onRetry: () {},
        ),
        platform: TargetPlatform.macOS,
        width: 680,
      ),
    );
    expect(tester.getSize(retry).height, 32);
  });

  testWidgets('retrying shows a spinner and no button, at the height of '
      'the failed row', (tester) async {
    await tester.pumpWidget(
      _host(
        ChatEarlierMessagesFailedRow(
          status: ChatEarlierMessagesStatus.failed,
          onRetry: () {},
        ),
      ),
    );
    final failed = tester.getSize(find.byType(ChatEarlierMessagesFailedRow));

    await tester.pumpWidget(
      _host(
        const ChatEarlierMessagesFailedRow(
          status: ChatEarlierMessagesStatus.retrying,
        ),
      ),
    );

    expect(find.text('Retrying…'), findsOneWidget);
    expect(find.byType(TextButton), findsNothing);
    expect(
      tester.getSize(find.byType(ChatEarlierMessagesFailedRow)).height,
      failed.height,
    );
  });

  testWidgets('without a callback a failed row offers no button', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const ChatEarlierMessagesFailedRow(
          status: ChatEarlierMessagesStatus.failed,
        ),
      ),
    );
    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets('at the largest text size it stacks and does not overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        ChatEarlierMessagesFailedRow(
          status: ChatEarlierMessagesStatus.failed,
          onRetry: () {},
        ),
        textScale: 3.1,
      ),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(retry).height, greaterThanOrEqualTo(44));
  });

  testWidgets('a screen reader gets a title-only live region and a pressable '
      'Retry', (tester) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(
      _host(
        ChatEarlierMessagesFailedRow(
          status: ChatEarlierMessagesStatus.failed,
          onRetry: () => taps++,
        ),
      ),
    );
    final banner = tester.getSemantics(find.byType(AppBanner));
    expect(banner.flagsCollection.isLiveRegion, isTrue);
    expect(banner.label, "Couldn't load earlier messages");
    final button = tester.getSemantics(find.byType(TextButton));
    expect(button.label, 'Retry loading earlier messages');
    expect(button.flagsCollection.isButton, isTrue);
    expect(button.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    expect(button.getSemanticsData().hasAction(SemanticsAction.focus), isTrue);
    tester.semantics.tap(
      find.semantics.byLabel('Retry loading earlier messages'),
    );
    expect(taps, 1);
    handle.dispose();
  });

  testWidgets('the banner label is the same while retrying', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(
        ChatEarlierMessagesFailedRow(
          status: ChatEarlierMessagesStatus.failed,
          onRetry: () {},
        ),
      ),
    );
    final failed = tester.getSemantics(find.byType(AppBanner)).label;
    await tester.pumpWidget(
      _host(
        const ChatEarlierMessagesFailedRow(
          status: ChatEarlierMessagesStatus.retrying,
        ),
      ),
    );
    final retrying = tester.getSemantics(find.byType(AppBanner)).label;
    expect(retrying, failed);
    expect(failed, "Couldn't load earlier messages");
    handle.dispose();
  });

  for (final platform in [
    TargetPlatform.android,
    TargetPlatform.iOS,
    TargetPlatform.macOS,
    TargetPlatform.linux,
  ]) {
    testWidgets('the banner keeps its height from failed to retrying on '
        '${platform.name}', (tester) async {
      Future<double> height(ChatEarlierMessagesStatus status) async {
        await tester.pumpWidget(
          _host(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ChatEarlierMessagesFailedRow(
                  status: status,
                  onRetry: status == ChatEarlierMessagesStatus.failed
                      ? () {}
                      : null,
                ),
              ],
            ),
            platform: platform,
            // Wide enough that the test font's wide glyphs do not wrap the
            // title in one state and not the other.
            width: 680,
          ),
        );
        return tester.getSize(find.byType(AppBanner)).height;
      }

      final failed = await height(ChatEarlierMessagesStatus.failed);
      final retrying = await height(ChatEarlierMessagesStatus.retrying);
      expect(retrying, failed);
    });
  }
}
