import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/widgets/chat_branch_notice.dart';
import 'package:hermes_app/src/chat/widgets/mac_search_results.dart';
import 'package:hermes_app/src/chat/widgets/mac_thread_row.dart';
import 'package:hermes_app/src/chat/widgets/thread_actions_menu.dart';
import 'package:hermes_app/src/chat/widgets/thread_search_view.dart';
import 'package:hermes_app/src/chat/thread_search.dart';
import 'package:hermes_app/src/chat/widgets/thread_sidebar.dart';
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:material_ui/material_ui.dart';

import 'support/pump_on_platform.dart';

Widget _notice(
  ChatBranchNoticeState state,
  VoidCallback onTap, {
  String? title = 'Release notes',
}) => ChatBranchNotice(state: state, parentTitle: title, onTap: onTap);

void main() {
  group('ChatBranchNotice', () {
    testWidgets('names the original when its title is known', (tester) async {
      var taps = 0;
      await pumpOnPlatform(
        tester,
        _notice(ChatBranchNoticeState.title, () => taps++),
        platform: TargetPlatform.iOS,
      );
      expect(find.text('Branched from Release notes'), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(ChatBranchNotice)),
        matchesSemantics(
          label: 'Branched from Release notes. Opens the original chat.',
          isButton: true,
          hasTapAction: true,
        ),
      );
      await tester.tap(find.byType(ChatBranchNotice));
      expect(taps, 1);
    });

    testWidgets('reads "another chat" without a title, and stays tappable', (
      tester,
    ) async {
      var taps = 0;
      await pumpOnPlatform(
        tester,
        _notice(ChatBranchNoticeState.unknown, () => taps++, title: null),
        platform: TargetPlatform.iOS,
      );
      expect(find.text('Branched from another chat'), findsOneWidget);
      await tester.tap(find.byType(ChatBranchNotice));
      expect(taps, 1);
    });

    testWidgets('a known state without a title falls back to "another chat"', (
      tester,
    ) async {
      await pumpOnPlatform(
        tester,
        _notice(ChatBranchNoticeState.title, () {}, title: ''),
        platform: TargetPlatform.iOS,
      );
      expect(find.text('Branched from another chat'), findsOneWidget);
    });

    testWidgets('opening shows a spinner and ignores taps', (tester) async {
      var taps = 0;
      await pumpOnPlatform(
        tester,
        _notice(ChatBranchNoticeState.opening, () => taps++),
        platform: TargetPlatform.iOS,
      );
      expect(find.text('Opening the original chat…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(ChatBranchNotice)),
        matchesSemantics(label: 'Opening the original chat…'),
      );
      await tester.tap(find.byType(ChatBranchNotice));
      expect(taps, 0);
    });

    testWidgets('deleted is information: an info icon, no chevron, no button', (
      tester,
    ) async {
      var taps = 0;
      await pumpOnPlatform(
        tester,
        _notice(ChatBranchNoticeState.deleted, () => taps++),
        platform: TargetPlatform.iOS,
      );
      expect(find.text('The original chat was deleted.'), findsOneWidget);
      expect(find.byType(InkWell), findsNothing);
      expect(find.byType(AppIcon), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(ChatBranchNotice)),
        matchesSemantics(label: 'The original chat was deleted.'),
      );
      await tester.tap(find.byType(ChatBranchNotice));
      expect(taps, 0);
    });

    testWidgets('unreachable offers Try again and fires the tap', (
      tester,
    ) async {
      var taps = 0;
      await pumpOnPlatform(
        tester,
        _notice(ChatBranchNoticeState.unreachable, () => taps++),
        platform: TargetPlatform.iOS,
      );
      expect(
        find.text("Couldn't reach Hermes. Check your connection. Try again"),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(find.byType(ChatBranchNotice)),
        matchesSemantics(
          label: "Couldn't reach Hermes. Check your connection. Try again",
          isButton: true,
          hasTapAction: true,
        ),
      );
      await tester.tap(find.byType(ChatBranchNotice));
      expect(taps, 1);
    });

    testWidgets('is German when the locale is', (tester) async {
      await pumpOnPlatform(
        tester,
        _notice(ChatBranchNoticeState.title, () {}),
        platform: TargetPlatform.iOS,
        locale: const Locale('de'),
      );
      expect(find.text('Verzweigt von Release notes'), findsOneWidget);
    });

    for (final (platform, height) in [
      (TargetPlatform.iOS, 44.0),
      (TargetPlatform.android, 48.0),
      (TargetPlatform.macOS, 32.0),
    ]) {
      testWidgets('is at least $height high on $platform', (tester) async {
        await pumpOnPlatform(
          tester,
          _notice(ChatBranchNoticeState.title, () {}),
          platform: platform,
        );
        expect(
          tester.getSize(find.byType(ChatBranchNotice)).height,
          greaterThanOrEqualTo(height),
        );
      });
    }

    testWidgets(
      'wraps a long title to two lines and then ends in an ellipsis',
      (tester) async {
        await pumpOnPlatform(
          tester,
          _notice(ChatBranchNoticeState.title, () {}, title: 'word ' * 80),
          platform: TargetPlatform.iOS,
        );
        final text = tester.widget<Text>(
          find
              .descendant(
                of: find.byType(ChatBranchNotice),
                matching: find.byType(Text),
              )
              .first,
        );
        expect(text.maxLines, 2);
        expect(text.overflow, TextOverflow.ellipsis);
      },
    );
  });

  testWidgets('unreachable wraps instead of cutting off "Try again"', (
    tester,
  ) async {
    await pumpOnPlatform(
      tester,
      _notice(ChatBranchNoticeState.unreachable, () {}),
      platform: TargetPlatform.iOS,
    );
    final text = tester.widget<Text>(
      find
          .descendant(
            of: find.byType(ChatBranchNotice),
            matching: find.byType(Text),
          )
          .first,
    );
    expect(text.maxLines, isNull);
    expect(text.overflow, isNot(TextOverflow.ellipsis));
  });

  group('the branch glyph', () {
    final glyph = find.byWidgetPredicate(
      (w) => w is AppIcon && w.icon == AppIcons.branch,
    );
    final thread = ChatThread(
      id: 't1',
      title: 'Try another approach',
      updatedAt: DateTime(2026, 1, 1),
      remote: true,
    );
    final hit = ThreadSearchHit(
      id: 't1',
      title: 'Try another approach',
      snippet: const [],
      updatedAt: DateTime(2026, 1, 1),
    );
    final branchHit = ThreadSearchHit(
      id: 't1',
      title: 'Try another approach',
      snippet: const [],
      updatedAt: DateTime(2026, 1, 1),
      branch: true,
    );

    Widget touchRow({required bool branch}) => SidebarThreadRow(
      thread: thread,
      selected: false,
      busy: false,
      onTap: () {},
      branch: branch,
    );

    Widget macRow({required bool branch}) => MacThreadRow(
      title: thread.title,
      selected: false,
      onTap: () {},
      menuItems: (context) => const <PopupMenuEntry<ThreadAction>>[],
      onAction: (_) {},
      branch: branch,
    );

    Widget touchSearch(ThreadSearchHit hit) => ThreadSearchResults(
      query: 'try',
      status: ThreadSearchStatus.done,
      hits: [hit],
      onOpen: (_) {},
    );

    Widget macSearch(ThreadSearchHit hit) => MacSearchResults(
      query: 'try',
      status: ThreadSearchStatus.done,
      hits: [hit],
      scope: ThreadSearchScope.profile,
      recent: const [],
      onOpen: (_) {},
      onPickRecent: (_) {},
    );

    final rows = <(String, Widget Function(bool), TargetPlatform)>[
      ('sidebar row', (b) => touchRow(branch: b), TargetPlatform.iOS),
      ('Mac thread row', (b) => macRow(branch: b), TargetPlatform.macOS),
      (
        'search result',
        (b) => touchSearch(b ? branchHit : hit),
        TargetPlatform.iOS,
      ),
      (
        'Mac search result',
        (b) => macSearch(b ? branchHit : hit),
        TargetPlatform.macOS,
      ),
    ];

    for (final (name, build, platform) in rows) {
      testWidgets('$name shows it only for a branch, and says "Branch"', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await pumpOnPlatform(tester, build(false), platform: platform);
        expect(glyph, findsNothing);
        expect(find.bySemanticsLabel(RegExp('Branch')), findsNothing);

        await pumpOnPlatform(tester, build(true), platform: platform);
        expect(glyph, findsOneWidget);
        expect(
          find.bySemanticsLabel(RegExp('^Try another approach, Branch')),
          findsOneWidget,
        );
        handle.dispose();
      });
    }

    testWidgets('is 14 pt on a touch row and 12 pt in the Mac source list', (
      tester,
    ) async {
      await pumpOnPlatform(
        tester,
        touchRow(branch: true),
        platform: TargetPlatform.iOS,
      );
      expect(tester.getSize(glyph).width, 14);
      await pumpOnPlatform(
        tester,
        macRow(branch: true),
        platform: TargetPlatform.macOS,
      );
      expect(tester.getSize(glyph).width, 12);
    });
  });
}
