import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_warning_state.dart';
import 'package:hermes_app/src/chat/widgets/agent_notice_card.dart';
import 'package:hermes_app/src/chat/widgets/tool_call_card.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

void main() {
  testWidgets(
    'notice details and dismissal remain accessible on narrow screens',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      var opened = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHermesLightTheme(),
          home: Scaffold(
            body: AgentNoticeCard(
              notice: const AgentNotice(
                text: 'Warning details remain inspectable when the message is long.',
              ),
              onDismiss: () {},
              onDetails: () => opened = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.byTooltip('Dismiss notice')),
        matchesSemantics(
          tooltip: 'Dismiss notice',
          isButton: true,
          hasTapAction: true,
          hasFocusAction: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
        ),
      );
      await tester.tap(find.textContaining('Warning details'));
      await tester.pumpAndSettle();
      expect(opened, isTrue);
      expect(find.byType(SelectableText), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets('notice details remain plain text and can be dismissed', (
    tester,
  ) async {
    var dismissed = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesLightTheme(),
        home: Scaffold(
          body: AgentNoticeCard(
            notice: const AgentNotice(
              text: '[Warning](https://example.invalid)',
              level: 'future',
            ),
            onDismiss: () => dismissed = true,
          ),
        ),
      ),
    );
    await tester.tap(find.text('[Warning](https://example.invalid)').first);
    await tester.pumpAndSettle();
    expect(find.byType(SelectableText), findsOneWidget);
    await tester.tap(find.byTooltip('Dismiss notice'));
    expect(dismissed, isTrue);
  });

  testWidgets('risk and redaction are visible before findings expand', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesLightTheme(),
        home: Scaffold(
          body: const ToolCallCard(
            call: ToolCall(
              name: 'terminal',
              summary: '',
              outputRisk: ToolOutputRisk(
                risk: 'secret',
                findings: ['Credential removed'],
                redacted: true,
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Output risk: secret · Redacted'), findsOneWidget);
    expect(find.text('Credential removed'), findsNothing);
    await tester.tap(find.text('terminal'));
    await tester.pumpAndSettle();
    expect(find.text('Credential removed'), findsOneWidget);
  });
}
