import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/widgets/mac_chat_toolbar.dart';
import 'package:hermes_app/src/profiles/widgets/profile_avatar.dart';
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
    double width = 360,
    EdgeInsets insets = EdgeInsets.zero,
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
      size: platform == TargetPlatform.macOS
          ? const Size(1280, 800)
          : Size(width, phone.height),
      wrap: (app) => Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            padding: insets,
            viewPadding: insets,
          ),
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

  // The header and the folder line move together from 1.3x, inclusive.
  testWidgets('Android at exactly 1.3 on 360 dp: the title is under the bar', (
    tester,
  ) async {
    await open(tester, platform: TargetPlatform.android, scale: 1.3);
    expect(tester.takeException(), isNull);
    expect(tester.widget<AppBar>(bar).bottom, isNotNull);
    expect(tester.widget<AppBar>(bar).title, isNull);
    expect(truncated(tester), isFalse);
  });

  testWidgets('Android just under 1.3 keeps the title in the bar', (
    tester,
  ) async {
    await open(tester, platform: TargetPlatform.android, scale: 1.25);
    expect(tester.widget<AppBar>(bar).bottom, isNull);
  });

  for (final scale in [2.0, 3.1]) {
    for (final width in [360.0, 800.0]) {
      testWidgets('Android at $scale on ${width.toInt()} dp: the moved title '
          'is the header and names the route', (tester) async {
        await open(
          tester,
          platform: TargetPlatform.android,
          scale: scale,
          width: width,
        );
        expect(tester.takeException(), isNull);
        expect(tester.widget<AppBar>(bar).bottom, isNotNull);
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
        );
      });
    }
  }

  testWidgets('the avatar is centred on the first line of the title', (
    tester,
  ) async {
    await open(tester, platform: TargetPlatform.android, scale: 2.0);
    final avatar = find.descendant(
      of: bar,
      matching: find.byType(ProfileAvatar),
    );
    final paragraph = tester.renderObject<RenderParagraph>(barTitle);
    final first = paragraph
        .getBoxesForSelection(
          const TextSelection(baseOffset: 0, extentOffset: 1),
        )
        .first;
    final lineCentre =
        paragraph.localToGlobal(Offset.zero).dy +
        (first.top + first.bottom) / 2;
    expect(
      tester.getCenter(avatar).dy,
      moreOrLessEquals(lineCentre, epsilon: 1),
    );
  });

  testWidgets('a cutout at the side narrows the title row and its height '
      'follows', (tester) async {
    const insets = EdgeInsets.symmetric(horizontal: 40);
    await open(
      tester,
      platform: TargetPlatform.android,
      scale: 1.5,
      insets: insets,
    );
    // Fits one line at the full width and two beside the cutout: a height
    // measured without the insets would overflow the row.
    expect(tester.takeException(), isNull);
    final rect = tester.getRect(barTitle);
    expect(rect.left, greaterThanOrEqualTo(insets.left));
    expect(rect.right, lessThanOrEqualTo(phone.width - insets.right));
    expect(truncated(tester), isFalse);
    // Both lines sit under the 56 dp toolbar and above the 12 dp padding.
    expect(rect.top, greaterThanOrEqualTo(56 - 0.5));
    expect(
      rect.bottom,
      lessThanOrEqualTo(tester.getRect(bar).bottom - 12 + 0.5),
    );
  });

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
