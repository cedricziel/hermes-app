import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/widgets/chat_earlier_messages_failed_row.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

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
    expect(tester.getSize(retry).height, inInclusiveRange(28, 36));
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

  testWidgets('the Retry button has the screen reader label', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(
        ChatEarlierMessagesFailedRow(
          status: ChatEarlierMessagesStatus.failed,
          onRetry: () {},
        ),
      ),
    );
    final node = tester.getSemantics(retry);
    expect(node.label, contains('Retry loading earlier messages'));
    handle.dispose();
  });
}
