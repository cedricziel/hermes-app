import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/widgets/mac_chat_toolbar.dart';
import 'package:hermes_app/src/chat/widgets/thread_actions_menu.dart';

import '../support/fake_chat_transport.dart';
import '../support/fake_hermes_server.dart';
import '../support/pump_chat.dart';

/// The open chat's phone app bar at a large text size: the title stays
/// readable and every action keeps its touch target.
void main() {
  const phone = Size(360, 640);
  const title = 'Weekly plan';

  Future<void> open(
    WidgetTester tester, {
    required TargetPlatform platform,
    required double scale,
  }) async {
    final server = FakeHermesServer()
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([sessionRow(id: 'rn', title: title)]),
      )
      ..on('GET', '/api/sessions/rn/messages', messageListBody('rn', []));
    await pumpChatScreen(
      tester,
      server: server,
      transport: FakeChatTransport(),
      platform: platform,
      size: platform == TargetPlatform.macOS ? const Size(1280, 800) : phone,
      wrap: (app) => Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: app,
        ),
      ),
    );
    if (platform != TargetPlatform.macOS) await openThread(tester, title);
  }

  final bar = find.byType(AppBar);
  final barTitle = find.descendant(of: bar, matching: find.text(title));

  bool truncated(WidgetTester tester) {
    final paragraph = tester.renderObject<RenderParagraph>(barTitle);
    return paragraph.didExceedMaxLines;
  }

  for (final scale in [1.0, 1.5, 2.0]) {
    testWidgets('Android at $scale: the title is whole and the actions keep '
        '48 dp targets', (tester) async {
      await open(tester, platform: TargetPlatform.android, scale: scale);
      expect(tester.takeException(), isNull, reason: 'no RenderFlex overflow');
      expect(barTitle, findsOneWidget);
      // The title is the bar's header and names the route wherever it sits.
      expect(
        find.ancestor(
          of: barTitle,
          matching: find.byWidgetPredicate(
            (w) =>
                w is Semantics &&
                w.properties.header == true &&
                w.properties.namesRoute == true,
          ),
        ),
        findsWidgets,
        reason: 'header and namesRoute on the title',
      );
      // Up to 1.3 the bar is unchanged and a short title may be cut by
      // the three actions; from there it moves under the bar and is whole.
      if (scale > 1.3) {
        expect(
          truncated(tester),
          isFalse,
          reason: 'a short title is not cut off',
        );
      }
      for (final tooltip in ['New chat', 'Activity']) {
        final button = find.descendant(
          of: bar,
          matching: find.byTooltip(RegExp('^$tooltip')),
        );
        expect(button, findsOneWidget, reason: tooltip);
        final size = tester.getSize(button);
        expect(size.width, greaterThanOrEqualTo(48), reason: tooltip);
        expect(size.height, greaterThanOrEqualTo(48), reason: tooltip);
      }
      final actions = find.descendant(
        of: bar,
        matching: find.byType(ThreadActionsButton),
      );
      expect(tester.getSize(actions).width, greaterThanOrEqualTo(48));
      // The bar draws inside the screen.
      expect(tester.getRect(bar).right, lessThanOrEqualTo(phone.width));
    });
  }

  for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
    testWidgets('${platform.name} at 2.0 chrome is unchanged', (tester) async {
      await open(tester, platform: platform, scale: 2.0);
      expect(tester.takeException(), isNull);
      expect(
        tester.widgetList<AppBar>(bar).where((b) => b.bottom != null),
        isEmpty,
        reason: 'no title row under the bar',
      );
      if (platform == TargetPlatform.macOS) {
        expect(find.byType(MacChatToolbar), findsOneWidget);
        expect(bar, findsNothing, reason: 'the title stays in the toolbar');
      }
      if (platform == TargetPlatform.iOS) {
        expect(tester.getSize(bar).height, 44);
        expect(find.descendant(of: bar, matching: find.text(title)), findsOne);
        expect(
          tester.renderObject<RenderParagraph>(barTitle).maxLines,
          1,
          reason: 'iOS keeps its one-line title',
        );
      }
    });
  }
}
