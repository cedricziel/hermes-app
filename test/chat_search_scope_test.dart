import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/chat/thread_search.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_hermes_server.dart';

Map<String, Object?> _results(String id, String title, double lastActive) => {
  'results': [
    {'session_id': id, 'title': title, 'last_active': lastActive},
  ],
};

/// Searching every profile: one request per profile, in parallel, merged by
/// recency; a profile that fails is left out.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeHermesServer server;
  late ChatController chat;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/profiles',
        profileListBody([
          profileRow(name: 'default', isDefault: true),
          profileRow(name: 'work'),
          profileRow(name: 'broken'),
        ]),
      )
      ..on('GET', '/api/profiles/active', activeProfileBody(active: 'default'))
      ..on('GET', '/api/sessions', sessionListBody([]))
      ..on(
        'GET',
        '/api/sessions/search',
        _results('d1', 'Backup at home', 1780000100),
        query: {'profile': 'default'},
      )
      ..on(
        'GET',
        '/api/sessions/search',
        _results('w1', 'Backup at work', 1780000900),
        query: {'profile': 'work'},
      )
      ..on(
        'GET',
        '/api/sessions/search',
        {'detail': 'boom'},
        status: 500,
        query: {'profile': 'broken'},
      );
    final api = server.client().raw;
    final attention = AttentionNotifier(
      service: null,
      settings: null,
      onOpen: (_) {},
    );
    chat = ChatController(
      repository: HermesChatRepository(api),
      profiles: HermesProfilesRepository(api),
      attention: attention,
      report: (_) {},
    );
    addTearDown(() {
      chat.dispose();
      attention.dispose();
    });
    await chat.loadThreads();
  });

  Future<void> search(String query, ThreadSearchScope scope) async {
    final search = chat.search!
      ..setScope(scope)
      ..update(query);
    while (search.status == ThreadSearchStatus.loading) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  test('this profile searches only the active one', () async {
    await search('backup', ThreadSearchScope.profile);

    expect(
      server
          .requestsTo('GET', '/api/sessions/search')
          .map((r) => r.queryParameters['profile']),
      ['default'],
    );
    expect(chat.search!.hits.single.id, 'd1');
  });

  test('all profiles asks each one and merges by recency, skipping a '
      'failure', () async {
    await search('backup', ThreadSearchScope.allProfiles);

    expect(
      server
          .requestsTo('GET', '/api/sessions/search')
          .map((r) => r.queryParameters['profile']),
      unorderedEquals(['default', 'work', 'broken']),
    );
    final hits = chat.search!.hits;
    expect(chat.search!.status, ThreadSearchStatus.done);
    expect(
      [for (final h in hits) (h.id, h.profile)],
      [('w1', 'work'), ('d1', 'default')],
    );
  });

  test('all profiles fails only when every profile does', () async {
    for (final profile in ['default', 'work']) {
      server.on(
        'GET',
        '/api/sessions/search',
        {'detail': 'boom'},
        status: 500,
        query: {'profile': profile},
      );
    }

    await search('backup', ThreadSearchScope.allProfiles);

    expect(chat.search!.status, ThreadSearchStatus.failed);
  });
}
