import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';
import 'package:hermes_app/src/skills/hermes_skills_repository.dart';
import 'package:hermes_app/src/skills/skill_detail_screen.dart';
import 'package:hermes_app/src/skills/skills_screen.dart';

import 'support/fake_hermes_server.dart';

/// The Skills pages against a fake dashboard, through the real generated
/// client.
void main() {
  late FakeHermesServer server;

  setUp(() {
    server = FakeHermesServer()
      ..on('GET', '/api/skills', [
        skillRow(
          name: 'apple-notes',
          description: 'Read Apple Notes',
          category: 'apple',
          usage: 14,
        ),
        skillRow(
          name: 'pr-review',
          description: 'Review a PR',
          category: 'github',
          provenance: 'agent',
        ),
        skillRow(
          name: 'compose',
          description: 'Compose stacks',
          category: 'devops',
          provenance: 'hub',
          enabled: false,
        ),
      ])
      ..on('GET', '/api/skills/content', {
        'name': 'pr-review',
        'content': '---\nname: pr-review\n---\n\n# Review PRs\n\nBe kind.',
        'path': '/x',
      })
      ..on('PUT', '/api/skills/toggle', {'ok': true})
      ..on('PUT', '/api/skills/content', {'success': true})
      ..on('POST', '/api/skills', {'success': true})
      ..on(
        'GET',
        '/api/profiles',
        profileListBody([
          profileRow(name: 'default', isDefault: true),
          profileRow(name: 'work'),
        ]),
      )
      ..on('GET', '/api/profiles/active', activeProfileBody(active: 'default'));
  });

  Future<void> pumpSkills(
    WidgetTester tester, {
    String? chatProfile = 'default',
    bool withProfiles = true,
    ValueChanged<String?>? onPopped,
  }) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                final draft = await Navigator.of(context).push<String>(
                  MaterialPageRoute(
                    builder: (_) => SkillsScreen(
                      repository: HermesSkillsRepository(server.client().raw),
                      profiles: withProfiles
                          ? HermesProfilesRepository(server.client().raw)
                          : null,
                      chatProfile: chatProfile,
                    ),
                  ),
                );
                onPopped?.call(draft);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group('installed list', () {
    testWidgets('lists skills grouped, with source badge and usage', (
      tester,
    ) async {
      await pumpSkills(tester);

      expect(find.text('APPLE'), findsOneWidget);
      expect(find.text('DEVOPS'), findsOneWidget);
      expect(find.text('GITHUB'), findsOneWidget);
      expect(find.text('apple-notes'), findsOneWidget);
      expect(find.text('Bundled'), findsWidgets);
      expect(find.text('Hub'), findsWidgets);
      expect(find.text('Agent'), findsWidgets);
      expect(find.text('used 14×'), findsOneWidget);
    });

    testWidgets('a disabled skill has its switch off', (tester) async {
      await pumpSkills(tester);

      final tile = find.byKey(const ValueKey('skill-compose'));
      expect(
        tester
            .widget<Switch>(
              find.descendant(of: tile, matching: find.byType(Switch)),
            )
            .value,
        isFalse,
      );
    });

    testWidgets('a failing load offers Retry', (tester) async {
      server.on('GET', '/api/skills', {'detail': 'x'}, status: 500);
      await pumpSkills(tester);
      expect(find.text('Could not load skills'), findsOneWidget);

      server.on('GET', '/api/skills', [skillRow(name: 'back')]);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('back'), findsOneWidget);
    });

    testWidgets('an older server is told so, without Retry', (tester) async {
      server.on('GET', '/api/skills', {'detail': 'Not Found'}, status: 404);
      await pumpSkills(tester);

      expect(
        find.text('The connected Hermes does not support skills.'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('a profile without skills says so', (tester) async {
      server.on('GET', '/api/skills', <Object?>[]);
      await pumpSkills(tester);

      expect(find.text('This profile has no skills yet.'), findsOneWidget);
    });

    testWidgets('search narrows the list and can be cleared', (tester) async {
      await pumpSkills(tester);

      await tester.enterText(find.byType(TextField), 'review');
      await tester.pump();
      expect(find.text('pr-review'), findsOneWidget);
      expect(find.text('apple-notes'), findsNothing);
      expect(find.text('APPLE'), findsNothing);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump();
      expect(find.text('No skills match.'), findsOneWidget);

      await tester.tap(find.text('Clear filters'));
      await tester.pump();
      expect(find.text('apple-notes'), findsOneWidget);
    });

    testWidgets('a source chip narrows the list', (tester) async {
      await pumpSkills(tester);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Hub'));
      await tester.pump();

      expect(find.text('compose'), findsOneWidget);
      expect(find.text('apple-notes'), findsNothing);
    });
  });

  group('toggling', () {
    testWidgets('sends the change for the chat\'s profile', (tester) async {
      await pumpSkills(tester, chatProfile: 'work');

      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('skill-apple-notes')),
          matching: find.byType(Switch),
        ),
      );
      await tester.pumpAndSettle();

      expect(jsonBody(server.requestsTo('PUT', '/api/skills/toggle').single), {
        'name': 'apple-notes',
        'enabled': false,
        'profile': 'work',
      });
    });

    testWidgets('a refusal puts the switch back and says so', (tester) async {
      server.on('PUT', '/api/skills/toggle', {'detail': 'x'}, status: 500);
      await pumpSkills(tester);

      final switchFinder = find.descendant(
        of: find.byKey(const ValueKey('skill-apple-notes')),
        matching: find.byType(Switch),
      );
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(switchFinder).value, isTrue);
      expect(find.text('Could not change apple-notes'), findsOneWidget);
    });
  });

  group('profile picker', () {
    testWidgets('shows the profile and reloads for another one', (
      tester,
    ) async {
      await pumpSkills(tester);
      expect(find.text('default'), findsOneWidget);

      await tester.tap(find.text('default'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(CheckedPopupMenuItem<String>, 'work'),
      );
      await tester.pumpAndSettle();

      expect(server.requestsTo('GET', '/api/skills').last.queryParameters, {
        'profile': 'work',
      });
      expect(server.requestsTo('POST', '/api/profiles/active'), isEmpty);
    });

    testWidgets('without profiles the chip is only a label', (tester) async {
      server.on('GET', '/api/profiles', {'detail': 'x'}, status: 500);
      await pumpSkills(tester);

      expect(find.text('default'), findsOneWidget);
      await tester.tap(find.text('default'));
      await tester.pumpAndSettle();
      expect(find.text('work'), findsNothing);
      expect(find.text('apple-notes'), findsOneWidget);
    });
  });

  group('detail', () {
    Future<void> openSkill(WidgetTester tester, String name) async {
      await tester.tap(find.text(name));
      await tester.pumpAndSettle();
    }

    testWidgets('renders the SKILL.md without its front matter', (
      tester,
    ) async {
      await pumpSkills(tester);
      await openSkill(tester, 'pr-review');

      expect(find.textContaining('Review PRs'), findsOneWidget);
      expect(find.textContaining('name: pr-review'), findsNothing);
      expect(
        server.requestsTo('GET', '/api/skills/content').single.queryParameters,
        {'name': 'pr-review', 'profile': 'default'},
      );
    });

    testWidgets('an agent skill offers Edit and Ask agent to delete', (
      tester,
    ) async {
      await pumpSkills(tester);
      await openSkill(tester, 'pr-review');

      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Ask agent to delete'), findsOneWidget);
    });

    testWidgets('a bundled skill offers neither and says why', (tester) async {
      await pumpSkills(tester);
      await openSkill(tester, 'apple-notes');

      expect(find.text('Edit'), findsNothing);
      expect(find.text('Ask agent to delete'), findsNothing);
      expect(
        find.text(
          'Bundled and hub skills can only be switched on or off here.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a content failure offers Retry and keeps the switch', (
      tester,
    ) async {
      server.on('GET', '/api/skills/content', {'detail': 'x'}, status: 500);
      await pumpSkills(tester);
      await openSkill(tester, 'pr-review');

      expect(find.text('Could not load this skill'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('asking to delete pops with a drafted message', (tester) async {
      String? draft;
      await pumpSkills(tester, onPopped: (d) => draft = d);
      await openSkill(tester, 'pr-review');

      await tester.tap(find.text('Ask agent to delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Draft message'));
      await tester.pumpAndSettle();

      expect(draft, deleteRequestFor('pr-review'));
      expect(find.byType(SkillsScreen), findsNothing);
    });

    testWidgets('cancelling the confirmation drafts nothing', (tester) async {
      String? draft;
      await pumpSkills(tester, onPopped: (d) => draft = d);
      await openSkill(tester, 'pr-review');

      await tester.tap(find.text('Ask agent to delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(draft, isNull);
      expect(find.byType(SkillDetailScreen), findsOneWidget);
    });
  });

  group('editor', () {
    Future<void> openEditor(WidgetTester tester) async {
      await pumpSkills(tester);
      await tester.tap(find.text('pr-review'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
    }

    testWidgets('Save is off until the text changes', (tester) async {
      await openEditor(tester);

      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Save'))
            .onPressed,
        isNull,
      );
      await tester.enterText(find.byType(TextField), 'changed');
      await tester.pump();
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Save'))
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('saving sends the whole text and returns to the detail', (
      tester,
    ) async {
      await openEditor(tester);

      await tester.enterText(find.byType(TextField), '# New text');
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();

      expect(jsonBody(server.requestsTo('PUT', '/api/skills/content').single), {
        'name': 'pr-review',
        'content': '# New text',
        'profile': 'default',
      });
      expect(find.text('Edit pr-review'), findsNothing);
    });

    testWidgets('a refusal keeps the editor and the text', (tester) async {
      server.on('PUT', '/api/skills/content', {
        'detail': 'Unsafe script',
      }, status: 400);
      await openEditor(tester);

      await tester.enterText(find.byType(TextField), 'bad');
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('Unsafe script'), findsOneWidget);
      expect(find.text('bad'), findsOneWidget);
    });

    testWidgets('closing with changes asks before discarding', (tester) async {
      await openEditor(tester);
      await tester.enterText(find.byType(TextField), 'changed');
      await tester.pump();

      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);

      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.text('Edit pr-review'), findsOneWidget);

      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.text('Edit pr-review'), findsNothing);
    });

    testWidgets('closing without changes does not ask', (tester) async {
      await openEditor(tester);

      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsNothing);
      expect(find.text('Edit pr-review'), findsNothing);
    });

    testWidgets('Preview shows the text rendered', (tester) async {
      await openEditor(tester);

      await tester.tap(find.text('Preview'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNothing);
      expect(find.textContaining('Review PRs'), findsOneWidget);
    });
  });

  group('new skill', () {
    Future<void> openCreate(WidgetTester tester) async {
      await pumpSkills(tester);
      await tester.tap(find.text('New skill'));
      await tester.pumpAndSettle();
    }

    testWidgets('starts from a template with Save off until it has a name', (
      tester,
    ) async {
      await openCreate(tester);

      expect(find.textContaining('description:'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Save'))
            .onPressed,
        isNull,
      );
    });

    testWidgets('creating sends name, category and text, then opens it', (
      tester,
    ) async {
      server.on('GET', '/api/skills/content', {
        'name': 'fresh',
        'content': '# Fresh skill',
        'path': '/x',
      });
      await openCreate(tester);

      await tester.enterText(find.widgetWithText(TextField, 'Name'), 'fresh');
      await tester.enterText(
        find.widgetWithText(TextField, 'Category (optional)'),
        'ops',
      );
      await tester.enterText(find.byType(TextField).last, '# Fresh skill');
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();

      expect(jsonBody(server.requestsTo('POST', '/api/skills').single), {
        'name': 'fresh',
        'content': '# Fresh skill',
        'category': 'ops',
        'profile': 'default',
      });
      expect(find.byType(SkillDetailScreen), findsOneWidget);
    });

    testWidgets('a refused name keeps the editor open', (tester) async {
      server.on('POST', '/api/skills', {
        'detail': 'Already exists',
      }, status: 400);
      await openCreate(tester);

      await tester.enterText(find.widgetWithText(TextField, 'Name'), 'dup');
      await tester.enterText(find.byType(TextField).last, 'x');
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('Already exists'), findsOneWidget);
    });
  });

  test('skillMarkdownBody drops only a leading front matter block', () {
    expect(skillMarkdownBody('---\na: b\n---\n\n# T'), '# T');
    expect(skillMarkdownBody('# T\n---\nx\n---'), '# T\n---\nx\n---');
  });
}
