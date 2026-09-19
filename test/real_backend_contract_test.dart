import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/api/hermes_api_client.dart';
import 'package:hermes_app/src/bots/hermes_bots_repository.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';

/// Runs the repositories against a real Hermes dashboard, to check the
/// response shapes they parse (the spec declares none for these routes).
///
///     scripts/dev-backend.sh start
///     HERMES_DEV_URL=$(scripts/dev-backend.sh url) flutter test \
///       test/real_backend_contract_test.dart
///
/// Skipped when `HERMES_DEV_URL` is unset. Use a throwaway backend: the
/// profile test switches the active profile back to `default`.
void main() {
  final url = Platform.environment['HERMES_DEV_URL'];
  final skip = url == null ? 'set HERMES_DEV_URL to run' : null;

  late HermesApiClient client;

  setUpAll(() async {
    if (url == null) return;
    final page = await Dio().get<String>('$url/');
    final token = RegExp(r'__HERMES_SESSION_TOKEN__="([^"]+)"')
        .firstMatch(page.data ?? '')
        ?.group(1);
    client = HermesApiClient(
      Dio(
        BaseOptions(baseUrl: url, headers: {'X-Hermes-Session-Token': ?token}),
      ),
    );
  });

  test('sessions load as threads', () async {
    final threads = await HermesChatRepository(client.raw).loadThreads();

    expect(threads.every((t) => t.id.isNotEmpty && t.title.isNotEmpty), isTrue);
  }, skip: skip);

  test('the first session\'s messages load', () async {
    final repository = HermesChatRepository(client.raw);
    final threads = await repository.loadThreads();
    if (threads.isEmpty) return;

    final messages = await repository.loadMessages(threads.first.id);

    expect(messages.every((m) => m.id.startsWith(threads.first.id)), isTrue);
  }, skip: skip);

  test('profiles load and the active one can be set', () async {
    final repository = HermesProfilesRepository(client.raw);

    final overview = await repository.load();
    await repository.setActive(overview.active);

    expect(overview.profiles.map((p) => p.name), contains(overview.active));
  }, skip: skip);

  test('messaging platforms load as bots', () async {
    final bots = await HermesBotsRepository(client.raw).load();

    expect(bots, isNotEmpty);
    expect(bots.every((b) => b.name.isNotEmpty), isTrue);
  }, skip: skip);
}
