import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/chat/widgets/mac_chat_toolbar.dart';
import 'package:hermes_app/src/profiles/widgets/profile_avatar.dart';
import 'package:hermes_app/src/chat/widgets/thread_actions_menu.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/workspaces/widgets/working_directory_line.dart';

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

  // One inclusive 1.3 threshold moves the title and the folder line on every
  // platform, iOS included.
  for (final (scale, below) in [(1.25, false), (1.3, true)]) {
    testWidgets('iOS at $scale: the folder line is '
        '${below ? 'a full-width row under the bar' : 'kept in the title'}', (
      tester,
    ) async {
      late bool decided;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildHermesLightTheme().copyWith(platform: TargetPlatform.iOS),
          home: MediaQuery(
            data: MediaQueryData(
              size: phone,
              textScaler: TextScaler.linear(scale),
            ),
            child: Builder(
              builder: (context) {
                decided = workingDirectoryLineBelowBar(context);
                return const Scaffold(
                  body: Align(
                    alignment: Alignment.topLeft,
                    child: WorkingDirectoryLine(folderName: 'api'),
                  ),
                );
              },
            ),
          ),
        ),
      );
      expect(decided, below);
      final width = tester.getSize(find.byType(WorkingDirectoryLine)).width;
      if (below) {
        expect(
          width,
          tester.getSize(find.byType(Scaffold)).width,
          reason: 'full-width row',
        );
      } else {
        expect(
          width,
          lessThan(tester.getSize(find.byType(Scaffold)).width),
          reason: 'inline in the title',
        );
      }
    });
  }

  testWidgets('an untitled phone chat is called "Neue Nachricht" in German', (
    tester,
  ) async {
    tester.platformDispatcher.localesTestValue = const [Locale('de')];
    tester.platformDispatcher.localeTestValue = const Locale('de');
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    final server = FakeHermesServer()
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([sessionRow(id: 'rn', title: title)]),
      )
      ..on('GET', '/api/sessions/rn/messages', messageListBody('rn', []))
      ..on('DELETE', '/api/sessions/rn', {'ok': true});
    await pumpChatScreen(
      tester,
      server: server,
      transport: FakeChatTransport(),
      platform: TargetPlatform.android,
      size: phone,
    );
    await openThread(tester, title);
    // Deleting the open chat leaves the bar without a thread to name.
    await tester.tap(find.byKey(const Key('header-thread-actions')));
    await tester.pumpAndSettle();
    final delete = lookupAppLocalizations(const Locale('de'))
        .chatWidgetsThreadMenuDelete;
    await tester.tap(find.text(delete));
    await tester.pumpAndSettle();
    // The dialog's confirm button reuses the menu's label.
    await tester.tap(
      find.descendant(of: find.byType(Dialog), matching: find.text(delete)),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: bar, matching: find.text('Neue Nachricht')),
      findsOneWidget,
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
