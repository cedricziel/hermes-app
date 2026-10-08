import 'package:flutter_otel/flutter_otel.dart' show BreadcrumbTrail;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/platform_hint/platform_hint_offer.dart';
import 'package:hermes_app/src/platform_hint/platform_hint_repository.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_hermes_server.dart';

void main() {
  late FakeHermesServer server;
  late BreadcrumbTrail trail;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    server = FakeHermesServer()
      ..on('GET', '/api/profiles', {
        'profiles': [
          {'name': 'default'},
          {'name': 'work'},
          {'name': 'mine'},
        ],
      })
      ..on('PUT', '/api/config', {'ok': true});
    trail = BreadcrumbTrail();
  });

  void hint(String profile, Object? value, {int status = 200}) => server.on(
    'GET',
    '/api/config',
    status: status,
    value == null
        ? {}
        : {
            'platform_hints': {'hermes_app': value},
          },
    query: {'profile': profile, 'include_defaults': 'false'},
  );

  PlatformHintOffer offer({String server_ = 'https://hermes.example'}) =>
      PlatformHintOffer(
        repository: PlatformHintRepository(
          server.client().raw,
          text: 'new',
          earlierTexts: const ['old'],
        ),
        server: server_,
        breadcrumbs: Breadcrumbs.of(trail),
      );

  List<String> written() => [
    for (final r in server.requestsTo('PUT', '/api/config'))
      r.queryParameters['profile'] as String,
  ];

  test('offers the profiles without the hint, not foreign ones', () async {
    hint('default', null);
    hint('work', {'replace': 'new'});
    hint('mine', {'replace': 'my words'});
    final o = offer();

    expect(await o.check(), isTrue);
    expect(o.profiles, ['default']);
    expect(o.update, isFalse);
  });

  test('an older app text is offered as an update', () async {
    hint('default', {'replace': 'old'});
    hint('work', {'replace': 'old'});
    hint('mine', {'replace': 'new'});
    final o = offer();

    expect(await o.check(), isTrue);
    expect(o.profiles, ['default', 'work']);
    expect(o.update, isTrue);
  });

  test('nothing is offered when every profile is done', () async {
    hint('default', {'replace': 'new'});
    hint('work', {'replace': 'new'});
    hint('mine', 'appended');

    expect(await offer().check(), isFalse);
  });

  test('an unreadable profile is skipped', () async {
    hint('default', null, status: 500);
    hint('work', {'replace': 'new'});
    hint('mine', {'replace': 'new'});

    expect(await offer().check(), isFalse);
  });

  test('a server whose profiles cannot be listed is not asked', () async {
    server.on('GET', '/api/profiles', {'detail': 'x'}, status: 500);

    expect(await offer().check(), isFalse);
  });

  test('add writes each needed profile and reports success', () async {
    hint('default', null);
    hint('work', {'replace': 'old'});
    hint('mine', {'replace': 'mine'});
    final o = offer();
    await o.check();

    expect(await o.add(), isTrue);
    expect(written(), ['default', 'work']);
    expect(o.failed, isEmpty);
  });

  test('a failed profile is reported and only it is retried', () async {
    hint('default', null);
    hint('work', null);
    hint('mine', null);
    server.onRequest(
      'PUT',
      '/api/config',
      (r) => r.queryParameters['profile'] == 'work'
          ? (status: 500, body: {'detail': 'x'})
          : (status: 200, body: {'ok': true}),
    );
    final o = offer();
    await o.check();

    expect(await o.add(), isFalse);
    expect(o.failed, ['work']);
    expect(o.busy, isFalse);

    server.on('PUT', '/api/config', {'ok': true});
    expect(await o.add(), isTrue);
    expect(written(), ['default', 'work', 'mine', 'work']);
  });

  test('only ticked profiles are written', () async {
    hint('default', null);
    hint('work', null);
    hint('mine', null);
    final o = offer();
    await o.check();
    expect(o.selected, {'default', 'work', 'mine'});

    o.toggle('work', false);
    await o.add();

    expect(written(), ['default', 'mine']);
  });

  test("don't ask again holds for that server only", () async {
    hint('default', null);
    hint('work', null);
    hint('mine', null);

    await offer().never();

    expect(await offer().check(), isFalse);
    expect(await offer(server_: 'https://other.example').check(), isTrue);
  });

  test('breadcrumbs carry counts and outcomes only', () async {
    hint('default', null);
    hint('work', null);
    hint('mine', {'replace': 'mine'});
    final o = offer();

    await o.check();
    o.offered();
    await o.add();
    o.later();

    expect(
      [for (final c in trail.recent) '${c.name} ${c.attributes}'],
      [
        'platform_hint.offered {profiles: 2, update: false}',
        'platform_hint.answered {outcome: added}',
        'platform_hint.answered {outcome: later}',
      ],
    );
  });
}
