import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_otel/flutter_otel.dart' show BreadcrumbTrail;
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/models/auth_provider_info.dart';
import 'package:hermes_app/src/models/hermes_session.dart';
import 'package:hermes_app/src/windows/conversation_windows.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_conversation_window_host.dart';
import 'support/memory_token_store.dart';

class _Dashboard {
  _Dashboard(this.server) {
    server.listen((request) {
      final me = request.uri.path == '/api/auth/me';
      final body = switch (request.uri.path) {
        '/api/status' => {
          'auth_required': true,
          'auth_flows': ['native_pkce'],
        },
        '/api/auth/providers' => {'providers': []},
        '/api/auth/me' => {
          'user_id': user,
          'org_id': organization,
          'provider': provider,
        },
        _ => <String, Object>{},
      };
      request.response
        ..statusCode = me ? meStatus : 200
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(body))
        ..close();
    });
  }
  final HttpServer server;
  String user = 'user-A';
  String organization = 'org-A';
  String provider = 'oidc';
  int meStatus = 200;
  String get url => 'http://127.0.0.1:${server.port}';
}

class _HeldClear extends MemoryTokenStore {
  _HeldClear(super.session);
  bool hold = false;
  final started = Completer<void>();
  final release = Completer<void>();
  @override
  Future<void> clear() async {
    if (hold) {
      started.complete();
      await release.future;
    }
    await super.clear();
  }
}

const _tokens = HermesSession(
  accessToken: 'access',
  refreshToken: '',
  expiresAt: 4102444800,
  userId: 'user-A',
  provider: 'oidc',
);
const _provider = AuthProviderInfo(
  name: 'oidc',
  displayName: 'SSO',
  supportsPassword: false,
);

void main() {
  late _Dashboard dashboard;
  late _HeldClear store;
  late AuthController auth;
  late FakeConversationWindowHost host;
  late ConversationWindows windows;
  late BreadcrumbTrail trail;
  final shown = <ConversationRef>[];

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    dashboard = _Dashboard(
      await HttpServer.bind(InternetAddress.loopbackIPv4, 0),
    );
    store = _HeldClear(_tokens);
    auth = AuthController(
      tokenStore: store,
      devServerUrl: dashboard.url,
      login: (url, {provider, httpClient, cancelled}) async => _tokens,
    );
    await auth.bootstrap();
    host = FakeConversationWindowHost();
    shown.clear();
    trail = BreadcrumbTrail();
    windows = ConversationWindows(
      host: host,
      store: ConversationWindowStore(SharedPreferencesAsync()),
      ownerKey: () => windowSessionOwnerKey(auth),
      connection: () =>
          auth.protectedRequestsAllowed &&
              auth.state == HermesConnectionState.ready
          ? (baseUrl: auth.baseUrl!, authRequired: true)
          : null,
      headers: auth.windowAuthHeaders,
      breadcrumbs: Breadcrumbs.of(trail),
    )..bindSession(auth);
    windows.showInMainRequests.listen(shown.add);
    await windows.open('private-A', profile: 'work', title: 'Private');
    await pumpEventQueue();
    host.closedNatively.clear();
  });

  tearDown(() async {
    if (store.hold && !store.release.isCompleted) store.release.complete();
    windows.dispose();
    auth.dispose();
    host.dispose();
    await dashboard.server.close(force: true);
  });

  test(
    'a new main manager closes untracked engines before restoring',
    () async {
      windows.dispose();
      windows = ConversationWindows(
        host: host,
        store: ConversationWindowStore(SharedPreferencesAsync()),
        ownerKey: () => windowSessionOwnerKey(auth),
        connection: () => (baseUrl: auth.baseUrl!, authRequired: true),
        headers: auth.windowAuthHeaders,
      )..bindSession(auth);
      await windows.restore();
      await pumpEventQueue();
      expect(host.created.length, 1);
      expect(host.created.keys, ['w1']);
    },
  );

  test(
    'window session breadcrumbs contain fixed outcomes and flags only',
    () async {
      dashboard.meStatus = 401;
      await expectLater(auth.api!.fetchMe(), throwsA(isA<DioException>()));
      dashboard.meStatus = 200;
      await auth.signInWithProvider(_provider);
      await windows.restore();
      final session = [
        for (final entry in trail.recent)
          if (entry.name.startsWith('window.session.'))
            '${entry.name} ${entry.attributes}',
      ];
      expect(session, [
        'window.session.initialized {restore: true}',
        'window.session.resumed {}',
        'window.session.suspended {restore: true}',
        'window.session.resumed {}',
      ]);
    },
  );

  for (final expire in [false, true]) {
    test(
      'native suspension precedes held auth cleanup (expiry: $expire)',
      () async {
        store.hold = true;
        final Future<void> cleanup;
        if (expire) {
          dashboard.meStatus = 401;
          cleanup = expectLater(
            auth.api!.fetchMe(),
            throwsA(isA<DioException>()),
          );
        } else {
          cleanup = auth.signOut();
        }
        await store.started.future;
        try {
          expect(host.closedNatively, contains('*'));
          expect(windows.windows, isEmpty);
          expect(
            await windows.open('private-A', profile: 'work', title: 'Private'),
            isFalse,
          );
          await host.call('showInMain', {
            'window_id': 'w0',
            'thread_id': 'private-A',
            'profile': 'work',
          });
          await pumpEventQueue();
          expect(shown, isEmpty);
        } finally {
          store.release.complete();
          await cleanup;
        }
        expect(auth.state, HermesConnectionState.needsLogin);
      },
    );
  }

  for (final scope in ['same', 'user', 'organization', 'provider', 'missing']) {
    test('expiry restoration checks $scope verified owner', () async {
      dashboard.meStatus = 401;
      await expectLater(auth.api!.fetchMe(), throwsA(isA<DioException>()));
      dashboard.meStatus = 200;
      if (scope == 'user') dashboard.user = 'user-B';
      if (scope == 'organization') dashboard.organization = 'org-B';
      if (scope == 'provider') dashboard.provider = 'another-provider';
      if (scope == 'missing') dashboard.user = ' ';
      await auth.signInWithProvider(_provider);
      await windows.restore();
      await pumpEventQueue();
      expect(host.created.length, scope == 'same' ? 1 : 0);
      if (scope != 'same') {
        expect(
          await ConversationWindowStore(SharedPreferencesAsync()).load(),
          isEmpty,
        );
      }
    });
  }
}
