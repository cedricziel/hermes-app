import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import '../api/hermes_api_client.dart';
import '../auth/auth_controller.dart';
import '../chat/gateway/gateway_connection.dart';
import '../chat/gateway/hermes_gateway_transport.dart';
import '../chat/hermes_chat_repository.dart';
import '../notifications/attention_policy.dart';
import '../notifications/notification_service.dart';
import '../notifications/notification_settings.dart';
import '../profiles/hermes_profiles_repository.dart';
import 'watch_request_handler.dart';

/// The Dart end of the watch relay. The iOS runner receives what the watch
/// sends over WatchConnectivity and forwards each request here as a `request`
/// call; the returned map goes back to the watch as the reply.
class WatchBridge {
  WatchBridge({
    required this._handler,
    this._channel = const MethodChannel(channelName),
  });

  static const channelName = 'app.hermes/watch';

  final WatchRequestHandler _handler;
  final MethodChannel _channel;

  /// A bridge that serves the watch from whoever is signed in right now, or
  /// null off iOS, where there is no watch to relay for.
  ///
  /// A turn sent from the watch is announced through [notifications], under
  /// the user's [settings].
  static WatchBridge? forAuth(
    AuthController auth, {
    NotificationService? notifications,
    NotificationSettings? settings,
  }) {
    if (!Platform.isIOS) return null;
    return WatchBridge(
      handler: handlerFor(auth, announce: announcer(notifications, settings)),
    );
  }

  /// Posts what the relay announces, while notifications are on. It never asks
  /// for permission: the prompt would appear on a phone the user is not
  /// holding, so it stays with the chat on the phone. A notification that
  /// cannot be shown is dropped.
  static void Function(AttentionNotification) announcer(
    NotificationService? service,
    NotificationSettings? settings,
  ) => (notification) {
    if (service == null) return;
    if (settings != null && !(settings.loaded && settings.enabled)) return;
    try {
      unawaited(service.show(notification).catchError((Object _) {}));
    } on Object {
      // Dropped, like any notification that cannot be shown.
    }
  };

  static WatchRequestHandler handlerFor(
    AuthController auth, {
    void Function(AttentionNotification) announce = _ignore,
  }) {
    // The client exists from the first connect, before anyone has signed in.
    HermesApiClient? readyApi() =>
        auth.state == HermesConnectionState.ready ? auth.api : null;

    return WatchRequestHandler(
      announce: announce,
      repository: () {
        final api = readyApi();
        return api == null ? null : HermesChatRepository(api.raw);
      },
      transport: () {
        final api = readyApi();
        final baseUrl = auth.baseUrl;
        if (api == null || baseUrl == null) return null;
        return HermesGatewayTransport(
          connect: hermesGatewayConnect(
            baseUrl: baseUrl,
            authRequired: auth.status?.authRequired ?? true,
            api: api,
          ),
        );
      },
      activeProfile: () async {
        final api = readyApi();
        if (api == null) return null;
        try {
          return (await HermesProfilesRepository(api.raw).loadActive()).active;
        } on Object {
          return null;
        }
      },
    );
  }

  static void _ignore(AttentionNotification _) {}

  void start() => _channel.setMethodCallHandler(_onCall);

  void dispose() => _channel.setMethodCallHandler(null);

  Future<Object?> _onCall(MethodCall call) async {
    if (call.method != 'request') throw MissingPluginException();
    final arguments = call.arguments;
    return _handler.handle(arguments is Map ? arguments : const {});
  }
}
