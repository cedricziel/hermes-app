import 'package:flutter/material.dart';
import 'package:hermes_app/src/api/hermes_api_client.dart';
import 'package:hermes_app/src/app_lock/app_lock_controller.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/auth/connect_failure.dart';
import 'package:hermes_app/src/models/auth_provider_info.dart';
import 'package:hermes_app/src/models/hermes_session.dart';
import 'package:hermes_app/src/models/hermes_status.dart';
import 'package:hermes_app/src/notifications/notification_service.dart';
import 'package:hermes_app/src/notifications/notification_settings.dart';
import 'package:hermes_app/src/settings/theme_controller.dart';
import 'package:hermes_app/src/share/share_controller.dart';
import 'package:provider/provider.dart';

import '../test/support/fake_device_authenticator.dart';
import '../test/support/fake_hermes_server.dart';
import '../test/support/fake_notification_service.dart';
import '../test/support/fake_share_inbox.dart';

/// An [AuthController] that sits in one state, for the screens that read it:
/// nothing connects, signs in or leaves. With [server] its client talks to the
/// fake dashboard.
class CatalogAuth extends AuthController {
  CatalogAuth({
    this.fixedState = HermesConnectionState.ready,
    this.server,
    this.failure,
    this.message,
    this.signInProviders = const [],
    this.gated = false,
  });

  final HermesConnectionState fixedState;
  final FakeHermesServer? server;
  final ConnectFailure? failure;
  final String? message;
  final List<AuthProviderInfo> signInProviders;
  final bool gated;

  @override
  HermesConnectionState get state => fixedState;

  @override
  String? get baseUrl => 'https://hermes.example.com';

  @override
  String? get savedServerUrl => 'https://hermes.example.com';

  @override
  HermesStatus? get status => HermesStatus(
    authRequired: gated,
    authProviders: [for (final p in signInProviders) p.name],
    authFlows: const ['native_pkce'],
    version: '0.20.0',
  );

  @override
  List<AuthProviderInfo> get providers => signInProviders;

  @override
  HermesIdentity? get identity => gated
      ? const HermesIdentity(
          userId: 'u1',
          email: 'ada@example.com',
          displayName: 'Ada',
          orgId: 'acme',
          provider: 'oidc',
        )
      : null;

  @override
  String? get errorMessage => message;

  @override
  ConnectFailure? get lastFailure => failure;

  @override
  bool? get vpnActive => false;

  @override
  HermesApiClient? get api => server?.client();

  @override
  Future<void> connect(
    String rawUrl, {
    bool remember = true,
    bool restoring = false,
    bool automatic = false,
  }) async {}

  @override
  Future<void> signInWithProvider(AuthProviderInfo provider) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<void> changeServer() async {}
}

const ssoProvider = AuthProviderInfo(
  name: 'oidc',
  displayName: 'Acme SSO',
  supportsPassword: false,
);

/// The providers the app sets up around its screens, minus telemetry and the
/// platform's share inbox and notification code.
Widget withAppProviders(
  AuthController auth,
  Widget child, {
  AppLockController? lock,
}) => MultiProvider(
  providers: [
    ChangeNotifierProvider<AuthController>.value(value: auth),
    ChangeNotifierProvider<ShareController>(
      create: (_) => ShareController(FakeShareInbox()),
    ),
    ChangeNotifierProvider<ThemeController>(create: (_) => ThemeController()),
    ChangeNotifierProvider<AppLockController>.value(
      value:
          lock ?? AppLockController(authenticator: FakeDeviceAuthenticator()),
    ),
    ChangeNotifierProvider(create: (_) => NotificationSettings()),
    Provider<NotificationService>.value(value: FakeNotificationService()),
  ],
  child: child,
);
