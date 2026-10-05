import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/handoff/handoff_activity.dart';
import 'package:hermes_app/src/handoff/handoff_bridge.dart';
import 'package:hermes_app/src/handoff/handoff_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const first = HandoffActivity('https://example.test', 'work', 'first');
  const second = HandoffActivity('https://example.test', 'home', 'second');
  late HandoffController controller;
  setUp(() => controller = HandoffController(HandoffBridge(enabled: false)));
  tearDown(() => controller.dispose());
  void ready({bool unlocked = true, bool signedIn = true}) =>
      controller.configure(
        serverUrl: first.serverUrl,
        ready: signedIn,
        unlocked: unlocked,
        initializing: false,
        fixedServer: false,
        userGeneration: 0,
      );
  test(
    'waits for connection and unlock before restoring a cold-launch target',
    () async {
      var opened = '';
      controller.receive(first.payload);
      controller.bind((activity, valid) async {
        opened = activity.threadId;
        return true;
      });
      ready(unlocked: false);
      await controller.drive();
      expect(opened, isEmpty);
      ready(signedIn: false);
      await controller.drive();
      expect(controller.pending, isNotNull);
      ready();
      await controller.drive();
      expect(opened, 'first');
      expect(controller.pending, isNull);
    },
  );
  test('new target invalidates an older outstanding restoration', () async {
    final release = Completer<bool>();
    bool Function()? oldValid;
    controller.bind((activity, valid) {
      oldValid = valid;
      return release.future;
    });
    ready();
    controller.receive(first.payload);
    final operation = controller.drive();
    controller.receive(second.payload);
    expect(oldValid!(), isFalse);
    release.complete(true);
    await operation;
    expect(controller.pending?.threadId, 'second');
  });
  test('explicit user actions discard pending continuation', () async {
    ready();
    controller.receive(first.payload);
    controller.configure(
      serverUrl: first.serverUrl,
      ready: false,
      unlocked: true,
      initializing: false,
      fixedServer: false,
      userGeneration: 1,
    );
    expect(controller.pending, isNull);
  });
  test('does not connect to a different dashboard automatically', () async {
    controller.configure(
      serverUrl: 'https://other.test',
      ready: true,
      unlocked: true,
      initializing: false,
      fixedServer: false,
      userGeneration: 0,
    );
    controller.receive(first.payload);
    expect(controller.needsConnection, isTrue);
    expect(controller.setupUrl, isNull);
    controller.cancel();
    expect(controller.pending, isNull);
  });
  test('accepted server change preserves its target across auth routing', () {
    ready();
    controller.receive(
      const HandoffActivity('https://other.test', 'work', 'saved').payload,
    );
    controller.acceptConnection();
    controller.configure(
      serverUrl: first.serverUrl,
      ready: true,
      unlocked: true,
      initializing: false,
      fixedServer: false,
      userGeneration: 1,
    );
    expect(controller.setupUrl, 'https://other.test');
    expect(controller.pending?.threadId, 'saved');
    expect(controller.needsConnection, isFalse);
  });
  test('fixed development server refuses another dashboard', () {
    controller.configure(
      serverUrl: 'https://other.test',
      ready: true,
      unlocked: true,
      initializing: false,
      fixedServer: true,
      userGeneration: 0,
    );
    controller.receive(first.payload);
    controller.acceptConnection();
    expect(controller.setupUrl, isNull);
    expect(controller.error, contains('fixed development'));
  });
  test('does not retry a failed restoration on every state update', () async {
    var attempts = 0;
    ready();
    controller.bind((activity, valid) async {
      attempts++;
      throw StateError('offline');
    });
    controller.receive(first.payload);
    await controller.drive();
    await controller.drive();
    expect(attempts, 1);
    expect(controller.pending, isNotNull);
    expect(controller.retryable, isTrue);
    controller.retry();
    await controller.drive();
    expect(attempts, 2);
  });
  test(
    'publishes only eligible identity changes and clears covered chats',
    () async {
      controller.dispose();
      final bridge = RecordingBridge();
      controller = HandoffController(bridge);
      Future<void> flushed() => Future<void>.delayed(Duration.zero);
      controller.advertise(first);
      await flushed();
      expect(bridge.activities, isEmpty);
      ready();
      await flushed();
      expect(bridge.activities, [first]);
      controller.advertise(first);
      await flushed();
      expect(bridge.activities, hasLength(1));
      controller.cover(true);
      await flushed();
      expect(bridge.activities.last, isNull);
      controller.cover(false);
      await flushed();
      expect(bridge.activities.last, first);
      ready(unlocked: false);
      await flushed();
      expect(bridge.activities.last, isNull);
      ready();
      controller.receive(second.payload);
      await flushed();
      expect(bridge.activities.last, isNull);
      controller.cancel();
      await flushed();
      expect(bridge.activities.last, first);
      controller.advertise(null);
      await flushed();
      expect(bridge.activities.last, isNull);
    },
  );
}

class RecordingBridge extends HandoffBridge {
  RecordingBridge() : super(enabled: false);
  final activities = <HandoffActivity?>[];
  @override
  Future<void> publish(HandoffActivity? activity) async =>
      activities.add(activity);
}
