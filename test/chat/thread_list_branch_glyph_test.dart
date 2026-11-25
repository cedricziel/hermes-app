import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/chat/thread_search.dart';
import 'package:hermes_app/src/chat/widgets/thread_sidebar.dart';
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/fake_hermes_server.dart';
import '../support/test_localizations.dart';

/// The chat list marks a branch on every surface that lists chats, from the
/// session rows the repository read: a branch (`_branched_from`) has the
/// glyph; a compression continuation or a sub-agent run (`parent_session_id`
/// alone) and a plain chat have none.
void main() {
  final glyph = find.byWidgetPredicate(
    (w) => w is AppIcon && w.icon == AppIcons.branch,
  );

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  Future<List<ChatThread>> readRows(WidgetTester tester) async {
    final server = FakeHermesServer()
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([
          {...sessionRow(id: 'b', title: 'Try another approach'), ..._branched},
          {
            ...sessionRow(id: 'c', title: 'Continued after compression'),
            'parent_session_id': 'p',
          },
          {
            ...sessionRow(id: 'r', title: 'Started fresh'),
            'parent_session_id': 'p',
            '_reset_from': 'p',
          },
          sessionRow(id: 'n', title: 'Plain chat'),
        ]),
      );
    final threads = await tester.runAsync(
      () => HermesChatRepository(server.client().raw).loadThreads(),
    );
    return threads!;
  }

  Future<void> pumpSidebar(
    WidgetTester tester,
    TargetPlatform platform,
    List<ChatThread> threads, {
    ThreadSearch? search,
  }) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthController(),
        child: MaterialApp(
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildHermesLightTheme(platform: platform),
          home: Scaffold(
            body: ThreadSidebar(
              threads: threads,
              selectedId: null,
              onSelect: (_) {},
              onNewThread: () {},
              search: search,
              onOpenHit: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  void expectOnlyTheBranchMarked(WidgetTester tester) {
    expect(glyph, findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('^Try another approach, Branch')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(RegExp('Branch')), findsOneWidget);
  }

  for (final (name, platform) in [
    ('sidebar', TargetPlatform.iOS),
    ('Mac source list', TargetPlatform.macOS),
  ]) {
    testWidgets('the $name marks only the branch', (tester) async {
      final handle = tester.ensureSemantics();
      final threads = await readRows(tester);
      await pumpSidebar(tester, platform, threads);
      expectOnlyTheBranchMarked(tester);
      handle.dispose();
    });
  }

  for (final (name, platform) in [
    ('search results', TargetPlatform.iOS),
    ('Mac search results', TargetPlatform.macOS),
  ]) {
    testWidgets('$name mark only the branch', (tester) async {
      final handle = tester.ensureSemantics();
      final threads = await readRows(tester);
      final search = ThreadSearch(
        (query) async => [
          for (final t in threads)
            ThreadSearchHit(
              id: t.id,
              title: t.title,
              snippet: const [],
              updatedAt: t.updatedAt,
            ),
        ],
        debounce: Duration.zero,
      );
      addTearDown(search.dispose);
      await pumpSidebar(tester, platform, threads, search: search);
      search
        ..begin()
        ..update('a');
      await tester.pumpAndSettle();
      expect(find.text('Plain chat'), findsOneWidget);
      expectOnlyTheBranchMarked(tester);
      handle.dispose();
    });
  }

  testWidgets('a result of another profile is not matched by id', (
    tester,
  ) async {
    final threads = await readRows(tester);
    final search = ThreadSearch(
      (query) async => [
        ThreadSearchHit(
          id: 'b',
          title: 'Try another approach',
          snippet: const [],
          updatedAt: DateTime(2026),
          profile: 'other',
        ),
      ],
      debounce: Duration.zero,
    );
    addTearDown(search.dispose);
    await pumpSidebar(tester, TargetPlatform.iOS, threads, search: search);
    search.update('a');
    await tester.pumpAndSettle();
    expect(find.text('Try another approach'), findsOneWidget);
    expect(glyph, findsNothing);
  });
}

const _branched = {'_branched_from': 'p'};
