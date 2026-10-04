import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/thread_search.dart';
import 'package:hermes_app/src/chat/widgets/mac_search_results.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

ThreadSearchHit _hit(String id, String title, {String? profile}) =>
    ThreadSearchHit(
      id: id,
      title: title,
      snippet: const [
        (text: 'the ', match: false),
        (text: 'backup', match: true),
      ],
      updatedAt: DateTime.now(),
      profile: profile,
    );

void main() {
  Future<({List<ThreadSearchHit> opened, List<String> picked})> pump(
    WidgetTester tester, {
    String query = 'backup',
    ThreadSearchStatus status = ThreadSearchStatus.done,
    List<ThreadSearchHit> hits = const [],
    List<String> recent = const [],
    ValueChanged<ThreadSearchScope>? onScopeChanged,
  }) async {
    final opened = <ThreadSearchHit>[];
    final picked = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesLightTheme(platform: TargetPlatform.macOS),
        home: Scaffold(
          body: SizedBox(
            width: 280,
            child: MacSearchResults(
              query: query,
              status: status,
              hits: hits,
              scope: ThreadSearchScope.profile,
              recent: recent,
              currentProfile: 'default',
              onOpen: opened.add,
              onPickRecent: picked.add,
              onScopeChanged: onScopeChanged,
            ),
          ),
        ),
      ),
    );
    return (opened: opened, picked: picked);
  }

  testWidgets('groups title matches as Chats and the rest as Messages', (
    tester,
  ) async {
    await pump(
      tester,
      hits: [
        _hit('a', 'Nightly backup'),
        _hit('b', 'Release notes'),
        _hit('c', 'Backup providers'),
      ],
    );

    double top(String text) => tester.getTopLeft(find.text(text)).dy;
    expect(find.text('Chats'), findsOneWidget);
    expect(find.text('Messages'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(top('Chats'), lessThan(top('Nightly backup')));
    expect(top('Backup providers'), lessThan(top('Messages')));
    expect(top('Messages'), lessThan(top('Release notes')));
  });

  testWidgets('a hit from another profile names it', (tester) async {
    await pump(tester, hits: [_hit('a', 'Nightly backup', profile: 'work')]);
    expect(find.textContaining('work · ', findRichText: true), findsOneWidget);
  });

  testWidgets('a hit from this profile does not', (tester) async {
    await pump(tester, hits: [_hit('a', 'Nightly backup', profile: 'default')]);
    expect(find.textContaining(' · ', findRichText: true), findsNothing);
  });

  testWidgets('a tap opens the hit', (tester) async {
    final calls = await pump(tester, hits: [_hit('a', 'Nightly backup')]);
    await tester.tap(find.text('Nightly backup'));
    expect(calls.opened.single.id, 'a');
  });

  testWidgets('no results says so with the query', (tester) async {
    await pump(tester);
    expect(find.text('No results for “backup”'), findsOneWidget);
  });

  testWidgets('an empty query lists recent searches to pick', (tester) async {
    final calls = await pump(tester, query: '', recent: ['backup', 'release']);
    expect(find.text('Recent searches'), findsOneWidget);
    await tester.tap(find.text('release'));
    expect(calls.picked, ['release']);
  });

  testWidgets('the scope switch shows only with a handler', (tester) async {
    await pump(tester);
    expect(find.text('All profiles'), findsNothing);

    final scopes = <ThreadSearchScope>[];
    await pump(tester, onScopeChanged: scopes.add);
    await tester.tap(find.text('All profiles'));
    await tester.pumpAndSettle();
    expect(scopes, [ThreadSearchScope.allProfiles]);
  });
}
