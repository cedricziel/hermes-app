import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_session_state.dart';
import 'package:hermes_app/src/chat/widgets/session_status_card.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

void main() {
  testWidgets(
    'control details use reported values and stay compact until expanded',
    (tester) async {
      final state = ChatSessionState()
        ..control = const SessionControlSnapshot(
          revision: 'opaque',
          goal: {
            'status': 'paused',
            'turns_used': 2,
            'max_turns': 5,
            'paused_reason': '[Review](https://example.invalid)',
          },
          heartbeat: {'status': 'running', 'fire_count': 3},
        );
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHermesLightTheme(),
          home: Scaffold(body: SessionStatusCard(state: state)),
        ),
      );
      expect(find.textContaining('Goal: paused'), findsOneWidget);
      expect(find.text('Turns used: 2'), findsNothing);
      await tester.tap(find.textContaining('Goal: paused'));
      await tester.pumpAndSettle();
      expect(find.text('Turns used: 2'), findsOneWidget);
      expect(find.text('Maximum turns: 5'), findsOneWidget);
      expect(find.text('Fire count: 3'), findsOneWidget);
      expect(
        find.text('Paused reason: [Review](https://example.invalid)'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'empty controls disappear and unsupported controls show no invented action',
    (tester) async {
      final state = ChatSessionState()
        ..control = const SessionControlSnapshot(revision: 'empty');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SessionStatusCard(state: state)),
        ),
      );
      expect(find.byType(Text), findsNothing);
      state.unavailable = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SessionStatusCard(state: state, initiallyOpen: true),
          ),
        ),
      );
      expect(find.text('Session controls unavailable'), findsOneWidget);
      expect(find.text('Reopen session'), findsNothing);
    },
  );

  testWidgets(
    'reclaim offers an accessible explicit reopen action on narrow screens',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      var reopened = false;
      final state = ChatSessionState()
        ..reclaimedReason = 'Another client reopened this session.';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SessionStatusCard(
              state: state,
              initiallyOpen: true,
              onReopen: () => reopened = true,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Reopen session'));
      expect(reopened, isTrue);
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.text('Reopen session')),
        matchesSemantics(
          label: 'Reopen session',
          isButton: true,
          hasTapAction: true,
          hasFocusAction: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
        ),
      );
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );
}
