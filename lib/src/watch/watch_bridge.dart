import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import '../api/hermes_api_client.dart';
import '../auth/auth_controller.dart';
import '../chat/gateway/gateway_connection.dart';
import '../chat/gateway/hermes_gateway_transport.dart';
import '../chat/hermes_chat_repository.dart';
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
  static WatchBridge? forAuth(AuthController auth) {
    if (!Platform.isIOS) return null;
    return WatchBridge(handler: handlerFor(auth));
  }

  static WatchRequestHandler handlerFor(AuthController auth) {
    // The client exists from the first connect, before anyone has signed in.
    HermesApiClient? readyApi() =>
        auth.state == HermesConnectionState.ready ? auth.api : null;

    return WatchRequestHandler(
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

  void start() => _channel.setMethodCallHandler(_onCall);

  void dispose() => _channel.setMethodCallHandler(null);

  Future<Object?> _onCall(MethodCall call) async {
    if (call.method != 'request') throw MissingPluginException();
    final arguments = call.arguments;
    return _handler.handle(arguments is Map ? arguments : const {});
  }
}
