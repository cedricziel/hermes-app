import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';
import 'package:hermes_app/src/skills/hermes_skills_repository.dart';
import 'package:hermes_app/src/skills/skills_controller.dart';

import 'support/fake_hermes_server.dart';

void main() {
  late FakeHermesServer server;
  late List<(String, Map<String, Object>)> events;

  SkillsController controller({String? profile = 'work'}) => SkillsController(
    repository: HermesSkillsRepository(server.client().raw),
    profiles: HermesProfilesRepository(server.client().raw),
    chatProfile: profile,
    events: (name, [attributes = const {}]) => events.add((name, attributes)),
  );

  setUp(() {
    server = FakeHermesServer();
    events = [];
    server.on('GET', '/api/skills', [
      skillRow(name: 'zeta', category: 'devops', description: 'Docker stacks'),
      skillRow(name: 'alpha', category: 'devops', enabled: false),
      skillRow(name: 'pr', category: 'github', provenance: 'agent'),
      skillRow(name: 'loose', category: null, provenance: 'hub'),
      skillRow(name: 'apple-notes', category: 'apple'),
    ]);
  });

  group('load', () {
    test('groups by category, sorted, with Other last', () async {
      final c = controller();
      await c.load();

      expect(c.status, SkillsStatus.ready);
      expect(c.groups.map((g) => g.category), [
        'apple',
        'devops',
        'github',
        'Other',
      ]);
      expect(c.groups[1].skills.map((s) => s.name), ['alpha', 'zeta']);
    });

    test('asks for the chat\'s profile', () async {
      await controller().load();

      expect(server.requestsTo('GET', '/api/skills').single.queryParameters, {
        'profile': 'work',
      });
    });

    test('a failure is reported and Retry can recover', () async {
      server.on('GET', '/api/skills', {'detail': 'x'}, status: 500);
      final c = controller();
      await c.load();
      expect(c.status, SkillsStatus.failed);

      server.on('GET', '/api/skills', [skillRow(name: 'a')]);
      await c.load();
      expect(c.status, SkillsStatus.ready);
    });

    test('a 404 means unsupported', () async {
      server.on('GET', '/api/skills', {'detail': 'Not Found'}, status: 404);
      final c = controller();
      await c.load();

      expect(c.status, SkillsStatus.unsupported);
    });

    test('a profile without skills is empty, not failed', () async {
      server.on('GET', '/api/skills', <Object?>[]);
      final c = controller();
      await c.load();

      expect(c.status, SkillsStatus.ready);
      expect(c.hasSkills, isFalse);
    });
  });

  group('search and filter', () {
    late SkillsController c;
    setUp(() async {
      c = controller();
      await c.load();
    });

    test('search matches name, description and category, ignoring case', () {
      c.setQuery('DOCKER');
      expect(c.groups.expand((g) => g.skills).map((s) => s.name), ['zeta']);
      c.setQuery('apple');
      expect(c.groups.expand((g) => g.skills).map((s) => s.name), [
        'apple-notes',
      ]);
    });

    test('empty groups are hidden', () {
      c.setQuery('pr');
      expect(c.groups.map((g) => g.category), ['github']);
    });

    test('filters by source and by state', () {
      c.setFilter(SkillFilter.hub);
      expect(c.groups.expand((g) => g.skills).map((s) => s.name), ['loose']);
      c.setFilter(SkillFilter.agent);
      expect(c.groups.expand((g) => g.skills).map((s) => s.name), ['pr']);
      c.setFilter(SkillFilter.bundled);
      expect(c.groups.expand((g) => g.skills).map((s) => s.name), [
        'apple-notes',
        'alpha',
        'zeta',
      ]);
      c.setFilter(SkillFilter.enabled);
      expect(
        c.groups.expand((g) => g.skills).any((s) => s.name == 'alpha'),
        isFalse,
      );
    });

    test('nothing matching is distinguishable from no skills', () {
      c.setQuery('nope');
      expect(c.groups, isEmpty);
      expect(c.hasSkills, isTrue);
      c.clearFilters();
      expect(c.groups, isNotEmpty);
    });

    test('does not ask the server again', () {
      c.setQuery('x');
      c.setFilter(SkillFilter.hub);
      expect(server.requestsTo('GET', '/api/skills'), hasLength(1));
    });
  });

  group('toggle', () {
    test(
      'switches at once and tells the server, for the selected profile',
      () async {
        final gate = Completer<void>();
        server.onRequest('PUT', '/api/skills/toggle', (_) async {
          await gate.future;
          return (status: 200, body: {'ok': true});
        });
        final c = controller();
        await c.load();

        final done = c.toggle('zeta', false);
        expect(c.skill('zeta')!.enabled, isFalse);
        gate.complete();
        expect(await done, isTrue);

        expect(
          jsonBody(server.requestsTo('PUT', '/api/skills/toggle').single),
          {'name': 'zeta', 'enabled': false, 'profile': 'work'},
        );
      },
    );

    test('goes back when the server refuses', () async {
      server.on('PUT', '/api/skills/toggle', {'detail': 'x'}, status: 500);
      final c = controller();
      await c.load();

      expect(await c.toggle('zeta', false), isFalse);
      expect(c.skill('zeta')!.enabled, isTrue);
    });

    test('quick taps are sent in order', () async {
      final sent = <bool>[];
      server.onRequest('PUT', '/api/skills/toggle', (r) async {
        sent.add((jsonBody(r)! as Map)['enabled'] as bool);
        return (status: 200, body: {'ok': true});
      });
      final c = controller();
      await c.load();

      final a = c.toggle('zeta', false);
      final b = c.toggle('zeta', true);
      await Future.wait([a, b]);

      expect(sent, [false, true]);
      expect(c.skill('zeta')!.enabled, isTrue);
    });

    test('a switch is logged without the skill name', () async {
      server.on('PUT', '/api/skills/toggle', {'ok': true});
      final c = controller();
      await c.load();
      await c.toggle('zeta', false);

      expect(events.single.$1, 'skills.write');
      expect(events.single.$2, {'op': 'toggle', 'result': 'ok'});
    });

    test('a failing event logger does not break the switch', () async {
      server.on('PUT', '/api/skills/toggle', {'ok': true});
      final c = SkillsController(
        repository: HermesSkillsRepository(server.client().raw),
        chatProfile: null,
        events: (_, [ignored = const {}]) => throw StateError('telemetry down'),
      );
      await c.load();

      expect(await c.toggle('zeta', false), isTrue);
    });
  });

  group('profile', () {
    setUp(() {
      server.on(
        'GET',
        '/api/profiles',
        profileListBody([
          profileRow(name: 'default', isDefault: true),
          profileRow(name: 'work'),
        ]),
      );
      server.on(
        'GET',
        '/api/profiles/active',
        activeProfileBody(active: 'default'),
      );
    });

    test(
      'picking another reloads for it and never switches the active one',
      () async {
        final c = controller();
        await c.load();
        await c.loadProfiles();
        expect(c.availableProfiles.map((p) => p.name), ['default', 'work']);

        await c.selectProfile('default');

        expect(c.profile, 'default');
        expect(server.requestsTo('GET', '/api/skills').last.queryParameters, {
          'profile': 'default',
        });
        expect(server.requestsTo('POST', '/api/profiles/active'), isEmpty);
      },
    );

    test('a failing profile list leaves no picker', () async {
      server.on('GET', '/api/profiles', {'detail': 'x'}, status: 500);
      final c = controller();
      await c.loadProfiles();

      expect(c.availableProfiles, isEmpty);
    });

    test('a stale reply from the previous profile is dropped', () async {
      final slow = Completer<FakeResponse>();
      server.onRequest(
        'GET',
        '/api/skills',
        (_) => slow.future,
        query: {'profile': 'work'},
      );
      server.on(
        'GET',
        '/api/skills',
        [skillRow(name: 'mine')],
        query: {'profile': 'default'},
      );
      final c = controller();
      final first = c.load();
      await c.selectProfile('default');
      slow.complete((status: 200, body: [skillRow(name: 'stale')]));
      await first;

      expect(c.groups.expand((g) => g.skills).map((s) => s.name), ['mine']);
    });
  });

  group('writes', () {
    test('save returns null on success and reloads the list', () async {
      server.on('PUT', '/api/skills/content', {'success': true});
      final c = controller();
      await c.load();

      expect(await c.save('pr', '# x'), isNull);
      expect(server.requestsTo('GET', '/api/skills'), hasLength(2));
    });

    test('save returns the reason on refusal', () async {
      server.on('PUT', '/api/skills/content', {
        'detail': 'Blocked',
      }, status: 400);
      final c = controller();
      await c.load();

      expect(await c.save('pr', '# x'), 'Blocked');
      expect(server.requestsTo('GET', '/api/skills'), hasLength(1));
    });

    test('an unreachable server gives a generic message', () async {
      server.on('POST', '/api/skills', {'detail': 'x'}, status: 500);
      final c = controller();
      await c.load();

      expect(await c.create('new', '# x'), isNotNull);
    });

    test('create sends the category and reloads', () async {
      server.on('POST', '/api/skills', {'success': true});
      final c = controller();
      await c.load();

      expect(await c.create('new', '# x', category: 'ops'), isNull);
      expect(
        (jsonBody(server.requestsTo('POST', '/api/skills').single)!
            as Map)['category'],
        'ops',
      );
    });
  });

  test('a queued toggle goes to the profile it was made for', () async {
    final gate = Completer<FakeResponse>();
    final sent = <Object?>[];
    server.onRequest('PUT', '/api/skills/toggle', (r) {
      sent.add((jsonBody(r)! as Map)['profile']);
      return sent.length == 1 ? gate.future : (status: 200, body: {'ok': true});
    });
    final c = controller();
    await c.load();

    final a = c.toggle('zeta', false);
    final b = c.toggle('zeta', true);
    await c.selectProfile('home');
    gate.complete((status: 200, body: {'ok': true}));
    await Future.wait([a, b]);

    expect(sent, ['work', 'work']);
  });

  test('profiles arriving after dispose do not notify', () async {
    final gate = Completer<FakeResponse>();
    server.onRequest('GET', '/api/profiles', (_) => gate.future);
    final c = controller();
    final done = c.loadProfiles();
    c.dispose();
    gate.complete((
      status: 200,
      body: profileListBody([profileRow(name: 'a')]),
    ));

    await expectLater(done, completes);
  });
}
