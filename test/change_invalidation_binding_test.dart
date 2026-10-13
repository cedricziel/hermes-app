import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';
import 'package:hermes_app/src/chat/gateway_connection_transport.dart';
import 'package:hermes_app/src/chat/invalidation/change_invalidation_binding.dart';
import 'package:hermes_app/src/chat/invalidation/change_signal.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_session_auth.dart';

class _Feed implements GatewayConnectionTransport {
  final frames = StreamController<GatewayConnectionEvent>.broadcast(sync: true);
  Object? current = Object();
  @override
  Stream<GatewayConnectionEvent> get connectionEvents => frames.stream;
  @override
  Object? get gatewayConnection => current;
  @override
  bool ownsGatewayConnection(Object connection) =>
      identical(current, connection);
  void hint([Object? owner]) => frames.add(
    GatewayConnectionEvent.received(
      owner ?? current!,
      const GatewayEvent(type: 'cron.changed', sessionId: '', payload: {}),
    ),
  );
}

class _Auth extends FakeSessionAuth {
  void startExpiry() {
    expiry++;
    expired = true;
    allowed = false;
    notifyListeners();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Auth auth;
  late _Feed feed;
  late ChangeInvalidationBinding binding;
  late String profile;
  late bool hideExpiry;
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    auth = _Auth();
    hideExpiry = false;
    auth.addListener(() {
      if (hideExpiry && auth.expired) auth.recover();
    });
    feed = _Feed();
    profile = 'work';
    binding = ChangeInvalidationBinding(
      source: feed,
      auth: auth,
      resource: InvalidationResource.schedules,
      profile: () => profile,
    );
  });
  tearDown(() async {
    binding.dispose();
    auth.dispose();
    await feed.frames.close();
  });
  test('a response cannot apply after physical client replacement before its callback', () async {
    final response = Completer<String>();
    final applied = <String>[];
    binding.controller.register<String>(
      InvalidationResource.schedules,
      readSnapshot: (_) => response.future,
      applySnapshot: applied.add,
    );
    binding.sync(active: true);
    feed.hint();
    await pumpEventQueue();
    feed.current = Object();
    response.complete('Previous connection');
    await pumpEventQueue();
    expect(applied, isEmpty);
  });
  test('a response cannot cross auth expiry even when another observer hides suspension', () async {
    final response = Completer<String>();
    final applied = <String>[];
    hideExpiry = true;
    binding.controller.register<String>(
      InvalidationResource.schedules,
      readSnapshot: (_) => response.future,
      applySnapshot: applied.add,
    );
    binding.sync(active: true);
    feed.hint();
    await pumpEventQueue();
    auth.startExpiry();
    expect(auth.protectedRequestsAllowed, true);
    response.complete('Before expiry');
    await pumpEventQueue();
    expect(applied, isEmpty);
  });
  test('a late result cannot cross the explicit repository profile', () async {
    final response = Completer<String>();
    final applied = <String>[];
    binding.controller.register<String>(
      InvalidationResource.schedules,
      readSnapshot: (_) => response.future,
      applySnapshot: applied.add,
    );
    binding.sync(active: true);
    feed.hint();
    await pumpEventQueue();
    profile = 'different';
    response.complete('Old profile');
    await pumpEventQueue();
    expect(applied, isEmpty);
  });
}
