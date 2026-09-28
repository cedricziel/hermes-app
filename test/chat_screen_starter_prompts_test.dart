import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/api/hermes_repositories.dart';
import 'package:hermes_app/src/chat/starter_context_loader.dart';
import 'package:hermes_app/src/chat/starter_prompts.dart';
import 'package:hermes_app/src/chat/widgets/welcome_view.dart';

import 'support/cron_fixtures.dart';
import 'support/fake_hermes_server.dart';
import 'support/pump_chat.dart';

/// The welcome view's starter prompts, built from the dashboard's jobs,
/// chats and skills.
void main() {
  late FakeHermesServer server;

  const jobPrompt =
      "Why did the scheduled job 'Nightly backup' fail on its last run?";

  setUp(() {
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([sessionRow(id: 's1', title: 'Telegram pairing')]),
      )
      ..on(
        'GET',
        '/api/sessions/s1/messages',
        messageListBody('s1', [
          messageRow(id: 1, role: 'user', content: 'Pair the bot'),
        ]),
      )
      ..on('GET', '/api/cron/jobs', [
        cronJobRow(
          name: 'Nightly backup',
          lastRunAt: '2026-09-27T03:00:00Z',
          lastStatus: 'error',
        ),
      ])
      ..on('GET', '/api/dashboard/plugins', [])
      ..on('GET', '/api/skills', [skillRow(name: 'nextcloud-notes', usage: 4)]);
  });

  Future<void> pump(WidgetTester tester, {bool settle = true}) =>
      pumpChatScreen(
        tester,
        server: server,
        starterContext: StarterContextLoader(
          HermesRepositories(server.client()),
        ),
        settle: settle,
      );

  List<String> promptTexts(WidgetTester tester) => tester
      .widget<WelcomeView>(find.byType(WelcomeView))
      .prompts
      .map((p) => p.text)
      .toList();

  String composerText(WidgetTester tester) =>
      tester.widget<EditableText>(find.byType(EditableText)).controller.text;

  testWidgets('shows the generic prompts until the context has loaded', (
    tester,
  ) async {
    final jobs = Completer<FakeResponse>();
    server.onRequest('GET', '/api/cron/jobs', (_) => jobs.future);
    await pump(tester);

    expect(promptTexts(tester), kStarterPrompts);

    jobs.complete((status: 200, body: []));
    await tester.pumpAndSettle();

    expect(promptTexts(tester), [
      "Pick up 'Telegram pairing'",
      'Use the nextcloud-notes skill to ',
      ...kStarterPrompts.take(2),
    ]);
  });

  testWidgets('puts a job, task or skill prompt in the composer', (
    tester,
  ) async {
    await pump(tester);
    await tester.enterText(find.byType(EditableText), 'half a thought');

    await tester.tap(find.text(jobPrompt));
    await tester.pumpAndSettle();

    expect(composerText(tester), jobPrompt);
    expect(server.requests.where((r) => r.method != 'GET'), isEmpty);
  });

  testWidgets('a recent-chat prompt opens that chat', (tester) async {
    await pump(tester);

    await tester.tap(find.text("Pick up 'Telegram pairing'"));
    await tester.pumpAndSettle();

    expect(find.byType(WelcomeView), findsNothing);
    expect(server.requestsTo('GET', '/api/sessions/s1/messages'), isNotEmpty);
    expect(server.requests.where((r) => r.method != 'GET'), isEmpty);
  });

  testWidgets('is read again for another profile, dropping a late answer', (
    tester,
  ) async {
    final profiles = HermesRepositories(server.client());
    final workJobs = Completer<FakeResponse>();
    server
      ..on('GET', '/api/profiles/active', activeProfileBody(active: 'work'))
      ..on(
        'GET',
        '/api/profiles',
        profileListBody([profileRow(name: 'work'), profileRow(name: 'home')]),
      )
      ..on('POST', '/api/profiles/active', {'active': 'home'})
      ..onRequest(
        'GET',
        '/api/cron/jobs',
        (_) => workJobs.future,
        query: {'profile': 'work'},
      )
      ..on(
        'GET',
        '/api/cron/jobs',
        [
          cronJobRow(
            name: 'Home backup',
            lastRunAt: '2026-09-27T03:00:00Z',
            lastStatus: 'error',
          ),
        ],
        query: {'profile': 'home'},
      );
    await pumpChatScreen(
      tester,
      server: server,
      withProfiles: true,
      starterContext: StarterContextLoader(profiles),
    );

    await openSidebarMore(tester);
    await tester.tap(find.text('Profiles'));
    await tester.pumpAndSettle();
    server.on('GET', '/api/profiles/active', activeProfileBody(active: 'home'));
    await tester.tap(find.text('home'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    workJobs.complete((
      status: 200,
      body: [
        cronJobRow(
          name: 'Work backup',
          lastRunAt: '2026-09-27T03:00:00Z',
          lastStatus: 'error',
        ),
      ],
    ));
    await tester.pumpAndSettle();

    expect(
      promptTexts(tester).first,
      "Why did the scheduled job 'Home backup' fail on its last run?",
    );
  });
}
