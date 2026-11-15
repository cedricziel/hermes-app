import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/api/hermes_api_client.dart';
import 'package:hermes_app/src/api/hermes_repositories.dart';
import 'package:hermes_app/src/background/headless_hermes.dart';
import 'package:hermes_app/src/bot_screen/bot_screen_controller.dart';
import 'package:hermes_app/src/bot_screen/bot_screen_repository.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/gateway/gateway_connection.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/files/files_profile.dart';
import 'package:hermes_app/src/files/hermes_files_repository.dart';
import 'package:hermes_app/src/memory/memory_destination.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';
import 'package:hermes_app/src/profiles/server_default_profile.dart';
import 'package:hermes_app/src/surfaces/surface_snapshot.dart';
import 'package:hermes_app/src/surfaces/surface_snapshot_store.dart';
import 'package:hermes_app/src/tools/hermes_tools_repository.dart';
import 'package:hermes_app/src/tools/tools_availability.dart';
import 'package:hermes_app/src/tools/tools_profile.dart';
import 'package:hermes_app/src/workspaces/hermes_workspaces_repository.dart';
import 'package:hermes_app/src/workspaces/workspace_catalog_loader.dart';
import 'package:provider/provider.dart';
import 'package:stream_channel/stream_channel.dart';

import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/memory_token_store.dart';

/// Which profile the app names for a chat whose profile is null, on a
/// dashboard that was started with a launch profile other than `default` while
/// another profile is the sticky `active` one.
///
/// Hermes' `GET /api/profiles/active` answers `{active, current}`: `active` is
/// the sticky default that `hermes profile use` writes, `current` is the
/// profile the running dashboard was launched with (`hermes -p NAME
/// dashboard`). A chat with no profile of its own belongs to `current`, so
/// every surface must send it, never `default` and never `active`.
///
///     scripts/verify.sh launch-profile        # starts the backend below
///
/// or by hand:
///
///     scripts/dev-backend.sh start --launch-profile launchprof \
///       --sticky-profile stickyprof
///     HERMES_DEV_URL=$(scripts/dev-backend.sh url) \
///       HERMES_DEV_LAUNCH_PROFILE=launchprof flutter test \
///       test/launch_profile_contract_test.dart
///
/// Skipped unless both `HERMES_DEV_URL` and `HERMES_DEV_LAUNCH_PROFILE` are
/// set, and CI sets neither. Read only: nothing is written on the backend, no
/// model is called. Every surface is driven through the app's own repository
/// or controller code, on the real generated client and Dio pipeline, with an
/// interceptor that records the `profile` each request names; the gateway
/// surfaces record the `profile` of each JSON-RPC call. Each test prints what
/// it saw, and the group ends with a table of surface to profile sent.
void main() {
  final url = Platform.environment['HERMES_DEV_URL'];
  final launch = Platform.environment['HERMES_DEV_LAUNCH_PROFILE'];
  final skip = url == null || launch == null || launch.isEmpty
      ? 'set HERMES_DEV_URL and HERMES_DEV_LAUNCH_PROFILE to run '
            '(scripts/verify.sh launch-profile)'
      : null;

  final seen = <_Request>[];
  final table = <String, String>{};
  late Dio dio;
  late HermesApiClient api;
  late HermesProfilesRepository profiles;
  var sticky = '?';
  GatewayRpcClient? gateway;

  Future<Map<String, Object?>> recordedRpc(
    String method,
    Map<String, Object?> params, {
    required Duration timeout,
  }) {
    seen.add(_Request('rpc', method, _text(params['profile'])));
    return gateway!.requestWithin(method, params, timeout: timeout);
  }

  /// The dashboard's gateway socket with each outgoing JSON-RPC frame's
  /// `profile` recorded, for a transport the app opens for itself.
  Future<StreamChannel<String>> recordingConnect() async {
    final channel = await hermesGatewayConnect(
      baseUrl: url!,
      authRequired: false,
      api: api,
    )();
    final tap = StreamChannelController<String>();
    tap.local.stream.listen((frame) {
      try {
        final body = jsonDecode(frame);
        if (body is Map && body['params'] is Map) {
          final params = body['params'] as Map<Object?, Object?>;
          seen.add(
            _Request('rpc', '${body['method']}', _text(params['profile'])),
          );
        }
      } on Object {
        // Not a request frame.
      }
      channel.sink.add(frame);
    }, onDone: () => channel.sink.close());
    channel.stream.listen(
      tap.local.sink.add,
      onDone: () => tap.local.sink.close(),
    );
    return tap.foreign;
  }

  /// The chat the app has before its first load: no profile of its own, on a
  /// connection to the dashboard. This is what each surface is given.
  ChatController newChat() {
    final chat = ChatController(
      repository: HermesChatRepository(api.raw),
      profiles: profiles,
      workspaces: HermesWorkspacesRepository(api.raw, recordedRpc),
      attention: AttentionNotifier(
        service: null,
        settings: null,
        onOpen: (_) {},
      ),
      activity: ValueNotifier(true),
      report: (_) {},
    );
    addTearDown(chat.dispose);
    return chat;
  }

  /// Runs [drive] and returns the profiles named by the requests it made
  /// (those that name one), `none` when nothing named any.
  Future<Set<String>> sent(Future<void> Function() drive) async {
    final from = seen.length;
    await drive();
    return {
      for (final r in seen.skip(from))
        if (r.profile != null) r.profile!,
    };
  }

  void check(String surface, Set<String> profilesSent) {
    final shown = profilesSent.isEmpty ? 'none' : profilesSent.join(', ');
    table[surface] = shown;
    // ignore: avoid_print
    print('launch-profile: $surface -> $shown');
    expect(
      profilesSent,
      {launch},
      reason:
          '$surface names $shown for a chat with no profile; the dashboard '
          'was launched with $launch (sticky active: $sticky)',
    );
  }

  setUp(seen.clear);

  setUpAll(() async {
    if (skip != null) return;
    // The widget test binding refuses every HTTP request; this one talks to
    // a real dashboard.
    HttpOverrides.global = null;
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final page = await Dio().get<String>('$url/');
    final token = RegExp(r'__HERMES_SESSION_TOKEN__="([^"]+)"')
        .firstMatch(page.data ?? '')
        ?.group(1);
    dio = Dio(
      BaseOptions(baseUrl: url!, headers: {'X-Hermes-Session-Token': ?token}),
    )..interceptors.add(_Recorder(seen));
    api = HermesApiClient(dio);
    profiles = HermesProfilesRepository(api.raw);
    gateway = GatewayRpcClient(
      await hermesGatewayConnect(baseUrl: url, authRequired: false, api: api)(),
    );
  });

  tearDownAll(() async {
    if (skip != null) return;
    await gateway?.close();
    if (table.isEmpty) return;
    final width = table.keys.fold<int>(
      0,
      (w, k) => k.length > w ? k.length : w,
    );
    // ignore: avoid_print
    print(
      [
        '',
        'launch profile: $launch (sticky active: $sticky)',
        for (final e in table.entries)
          '  ${e.key.padRight(width)}  ->  ${e.value}'
              '${e.value == launch ? '' : '   WRONG'}',
      ].join('\n'),
    );
  });

  group('launch profile (a dashboard started with a non-default profile)', () {
    test('the server reports a launch profile that is not the sticky one, '
        'and neither is `default`', () async {
      final answer = await profiles.loadActive();
      sticky = answer.active;
      expect(launch, isNot('default'));
      expect(
        answer.current,
        launch,
        reason: 'the dashboard was not launched with it',
      );
      expect(
        answer.active,
        allOf(isNot(launch), isNot('default')),
        reason:
            'the sticky profile must be a third profile, or the surfaces '
            'cannot be told apart (scripts/dev-backend.sh --sticky-profile)',
      );
      final names = [for (final p in await profiles.list()) p.name];
      expect(names, containsAll([launch, answer.active, 'default']));
    });

    test('Chat: the first list of a chat that names no profile opens the '
        'launch profile', () async {
      final chat = newChat();
      expect(chat.profile, isNull);
      final from = seen.length;
      await chat.loadThreads();
      final listed = {
        for (final r in seen.skip(from))
          if (r.path == '/api/sessions' && r.profile != null) r.profile!,
      };
      table['Chat: profile the controller settles on'] = '${chat.profile}';
      // ignore: avoid_print
      print('launch-profile: Chat controller profile -> ${chat.profile}');
      check('Chat: session list', listed);
      expect(chat.profile, launch);
    });

    test(
      'Bot Screen: display.* of a chat with no profile '
      '(BotScreenController, as ChatScreen._syncBotScreen builds it)',
      () async {
        final chat = newChat();
        expect(chat.profile, isNull);
        final profilesSent = await sent(() async {
          final controller = BotScreenController(
            BotScreenRepository(recordedRpc),
            const Stream.empty(),
            profile: chat.profile,
          );
          final watch = controller.watch(frames: false);
          await _until(
            () =>
                controller.status != null ||
                controller.failure != null ||
                controller.unsupported,
          );
          watch.release();
          controller.dispose();
        });
        check('Bot Screen display.status', profilesSent);
      },
    );

    test('Files: /api/fs/* of a chat with no profile '
        '(HermesFilesRepository, as openFiles builds it)', () async {
      final chat = newChat();
      expect(chat.profile, isNull);
      final profilesSent = await sent(() async {
        // open_files.dart builds the repository with filesProfileFor.
        final files = HermesFilesRepository(
          api,
          profile: filesProfileFor(chat.profile),
        );
        await files.defaultCwd();
      });
      check('Files /api/fs/default-cwd', profilesSent);
    });

    test('Workspaces: the catalog of a chat with no profile '
        '(ChatController.workspaceCatalog, the welcome view and the '
        'picker)', () async {
      final chat = newChat();
      expect(chat.profile, isNull);
      final profilesSent = await sent(() async {
        final loader = chat.workspaceCatalog();
        expect(loader, isNotNull);
        await _until(
          () =>
              loader!.status != WorkspaceCatalogStatus.idle &&
              loader.status != WorkspaceCatalogStatus.loading,
        );
      });
      check('Workspaces /api/chat/workspaces', profilesSent);
    });

    test('Background refresh: the profile a headless snapshot names '
        '(withHeadlessHermes + HeadlessHermes.refreshSnapshot)', () async {
      final adapter = _RecordingAdapter(seen);
      final outcome = await withHeadlessHermes<SurfaceSnapshot?>(
        (hermes) => hermes.refreshSnapshot(),
        task: 'launch_profile',
        timeout: const Duration(seconds: 30),
        deps: HeadlessDeps(
          devServerUrl: url,
          tokenStore: MemoryTokenStore(),
          adapter: adapter,
          snapshotStore: SurfaceSnapshotStore(storage: MemorySurfaceStorage()),
          appLockOn: () async => false,
        ),
      );
      expect(outcome, isA<HeadlessDone<SurfaceSnapshot?>>());
      final snapshot = (outcome as HeadlessDone<SurfaceSnapshot?>).value;
      expect(snapshot, isNotNull, reason: 'the snapshot was not saved');
      // Every profile a request named is a real one (or `all`), none invented.
      final names = {for (final p in await profiles.list()) p.name, 'all'};
      final named = {
        for (final r in seen)
          if (r.profile != null) r.profile!,
      };
      expect(
        named.difference(names),
        isEmpty,
        reason: 'the headless run named a profile the server does not have',
      );
      check('Background refresh snapshot', {?snapshot!.profile});
    });

    testWidgets('Memory: the profile the screen opens on with no profile '
        '(MemoryDestination, as the sidebar entry opens it)', (tester) async {
      final repositories = HermesRepositories(api);
      final chat = newChat();
      expect(chat.profile, isNull);
      // The destination's proposals commands go over this socket.
      final transport = HermesGatewayTransport(connect: recordingConnect);
      addTearDown(transport.close);
      bool memoryRead(_Request r) =>
          r.kind == 'rpc' ||
          r.path.startsWith('/api/memory') ||
          r.path == '/api/config';
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Provider<HermesRepositories?>.value(
              value: repositories,
              // chat_screen_navigation.dart: `profile: _chat.profile`
              child: MemoryDestination(
                profile: chat.profile,
                transport: transport,
              ),
            ),
          ),
        );
        await _until(
          () =>
              seen.any((r) => r.path.startsWith('/api/memory')) &&
              seen.any((r) => r.kind == 'rpc' && r.profile != null),
          pump: tester.pump,
        );
        // Let the first reads settle.
        await Future<void>.delayed(const Duration(milliseconds: 500));
        await tester.pump();
      });
      await tester.pumpWidget(const SizedBox());
      check('Memory screen reads', {
        for (final r in seen.where(memoryRead))
          if (r.profile != null) r.profile!,
      });
    });

    test('Tools: /api/tools/* of a chat with no profile '
        '(ToolsAvailability as AppShell seeds it, then the screen)', () async {
      final chat = newChat();
      expect(chat.profile, isNull);
      final profilesSent = await sent(() async {
        // AppShell._resolveServerCareProfile: the server's own default.
        final name = serverDefaultProfile(await profiles.loadActive());
        expect(name, isNotNull);
        final availability = ToolsAvailability(
          HermesToolsRepository(api.raw, profile: ''),
        );
        addTearDown(availability.dispose);
        // AppShell._followToolsProfile
        await availability.refresh(name!);
        // ChatScreen._openTools
        final opened = toolsProfileFor(chat.profile, availability);
        expect(opened, isNotNull);
        await HermesToolsRepository(
          api.raw,
          profile: '',
        ).forProfile(opened!).list();
      });
      check('Tools /api/tools/toolsets', profilesSent);
    });
  }, skip: skip);
}

class _Request {
  const _Request(this.kind, this.path, this.profile);

  /// `http` for a REST call, `rpc` for a gateway call.
  final String kind;

  /// The path of a REST call, the method of a gateway call.
  final String path;
  final String? profile;
}

String? _text(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

/// The `profile` a request names: in its query, else in a JSON body.
String? _profileOf(RequestOptions options) {
  final query = _text(options.queryParameters['profile']);
  if (query != null) return query;
  final data = options.data;
  Object? body = data;
  if (data is String) {
    try {
      body = jsonDecode(data);
    } on Object {
      return null;
    }
  }
  return body is Map ? _text(body['profile']) : null;
}

class _Recorder extends Interceptor {
  _Recorder(this._seen);

  final List<_Request> _seen;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _seen.add(_Request('http', options.path, _profileOf(options)));
    handler.next(options);
  }
}

/// For a Dio the app builds itself (the headless run's): records at the
/// adapter, then sends the request for real.
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this._seen);

  final List<_Request> _seen;
  final _inner = IOHttpClientAdapter();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    _seen.add(_Request('http', options.path, _profileOf(options)));
    return _inner.fetch(options, requestStream, cancelFuture);
  }

  @override
  void close({bool force = false}) => _inner.close(force: force);
}

Future<void> _until(
  bool Function() done, {
  Duration limit = const Duration(seconds: 20),
  Future<void> Function([Duration? duration, EnginePhase phase])? pump,
}) async {
  final end = DateTime.now().add(limit);
  while (!done()) {
    if (DateTime.now().isAfter(end)) return;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await pump?.call();
  }
}
