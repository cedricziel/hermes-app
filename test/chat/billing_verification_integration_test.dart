import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/app_lock/app_lock_controller.dart';
import 'package:hermes_app/src/chat/billing_verification_controller.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_thread_bindings.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/chat/widgets/billing_verification_card.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:hermes_app/src/windows/conversation_window_args.dart';
import 'package:hermes_app/src/windows/conversation_window_screen.dart';
import 'package:hermes_app/src/windows/desktop_conversation_windows.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/fake_gateway.dart';
import '../support/fake_attachment_source.dart';
import '../support/fake_hermes_server.dart';
import 'billing_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeGateway gateway;
  late HermesGatewayTransport transport;
  late ChatController chat;
  late bool ownsChat;
  late AttentionNotifier attention;
  late FakeHermesServer server;
  late _TestAppLock lock;
  late ValueNotifier<bool> activity;
  late DateTime now;
  final opened = <Uri>[], copied = <String>[];
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    ownsChat = true;
    now = DateTime.utc(2030);
    opened.clear();
    copied.clear();
    lock = _TestAppLock();
    activity = ValueNotifier(true);
    gateway = FakeGateway();
    gateway.activeSessions = {};
    gateway.silent.add('billing.step_up');
    gateway.handlers['session.resume'] = (params) => {
      'session_id': params['profile'] == 'other' ? 'rt-2' : 'rt-1',
      'stored_session_id': 'stored-1',
      'session_key': 'stored-1',
    };
    transport = HermesGatewayTransport(connect: gateway.connect);
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([sessionRow(id: 'stored-1', title: 'Billing test')]),
      )
      ..on(
        'GET',
        '/api/sessions/stored-1/messages',
        messageListBody('stored-1', []),
      );
    attention = AttentionNotifier(
      service: null,
      settings: null,
      onOpen: (_) {},
    );
    chat = ChatController(
      repository: HermesChatRepository(server.client().raw),
      transport: transport,
      activity: activity,
      appLock: lock,
      attention: attention,
      report: (_) {},
      now: () => now,
      billingBrowser: (uri) async {
        opened.add(uri);
        return true;
      },
      billingCopyCode: (code) async {
        copied.add(code);
      },
    );
  });
  tearDown(() async {
    if (ownsChat) chat.dispose();
    attention.dispose();
    await transport.close();
    lock.dispose();
    activity.dispose();
  });
  Future<void> open([String? profile = 'work']) async {
    await chat.loadThreads(profile);
    chat.select('stored-1');
    await pumpEventQueue();
  }

  void details([String runtime = 'rt-1']) => gateway.event(
    'billing.step_up.verification',
    runtime,
    billingVerificationFixture,
  );
  void answer(Map<String, Object?> result) => gateway.replyTo(
    gateway.requests.lastWhere((row) => row['method'] == 'billing.step_up'),
    result,
  );

  test('owned billing action remains explicit and active details cannot settle the foreground turn', () async {
    await open();
    final thread = chat.selectedThread!;
    final module = chat.billingVerificationIn(thread);
    expect(module, isNotNull);
    expect(gateway.methods, isNot(contains('billing.step_up')));
    chat.submit('Foreground', const []);
    await pumpEventQueue();
    final pending = module!.start();
    await pumpEventQueue();
    details();
    await pumpEventQueue();
    expect(module.verification!.userCode, 'PRIVATE-CODE');
    expect(module.status, BillingVerificationStatus.pending);
    expect(thread.isReplying, isTrue);
    await module.openVerification();
    await module.copyVerificationCode();
    expect(opened.single.host, 'billing.invalid');
    expect(copied, ['PRIVATE-CODE']);
    expect(module.status, BillingVerificationStatus.pending);
    answer({'ok': true, 'granted': true});
    await pending;
    expect(module.status, BillingVerificationStatus.granted);
    expect(module.verification, isNull);
    expect(thread.isReplying, isTrue);
    expect(gateway.methods, isNot(contains('billing.charge')));
    gateway.event('message.complete', 'rt-1', {
      'text': 'Main',
      'status': 'complete',
    });
    await pumpEventQueue();
  });
  test(
    'unresolved profile and unowned runtime cannot guess billing authority',
    () async {
      await open(null);
      final thread = chat.selectedThread!;
      expect(chat.billingVerificationIn(thread), isNull);
      details();
      details('foreign');
      await pumpEventQueue();
      expect(chat.billingVerificationIn(thread), isNull);
      expect(gateway.methods, isNot(contains('billing.step_up')));
      expect(opened, isEmpty);
    },
  );
  test('App Lock clears real event details while the dispatched RPC remains the duplicate barrier', () async {
    await open();
    final module = chat.billingVerificationIn(chat.selectedThread!)!;
    final pending = module.start();
    await pumpEventQueue();
    details();
    await pumpEventQueue();
    final old = module.verification!;
    lock.setCovered(true);
    expect(module.verification, isNull);
    details();
    await pumpEventQueue();
    expect(module.verification, isNull);
    lock.setCovered(false);
    await module.start();
    await module.openVerification(expectedDetails: old);
    await module.copyVerificationCode(expectedDetails: old);
    expect(
      gateway.requests.where((row) => row['method'] == 'billing.step_up'),
      hasLength(1),
    );
    expect(opened, isEmpty);
    expect(copied, isEmpty);
    expect(module.status, BillingVerificationStatus.pending);
    answer({'ok': true, 'granted': true});
    await pending;
    expect(module.status, BillingVerificationStatus.granted);
    expect(module.verification, isNull);
  });
  test('profile replacement rejects old code callbacks and a late granted response', () async {
    await open();
    final thread = chat.selectedThread!;
    final old = chat.billingVerificationIn(thread)!;
    final pending = old.start();
    await pumpEventQueue();
    details();
    await pumpEventQueue();
    final oldDetails = old.verification!;
    await chat.loadThreads('other');
    chat.select('stored-1');
    await pumpEventQueue();
    final replacement = chat.billingVerificationIn(chat.selectedThread!)!;
    answer({'ok': true, 'granted': true});
    await pending;
    expect(old.verification, isNull);
    expect(replacement.status, BillingVerificationStatus.idle);
    await old.openVerification(expectedDetails: oldDetails);
    await old.copyVerificationCode(expectedDetails: oldDetails);
    expect(opened, isEmpty);
    expect(copied, isEmpty);
  });
  test('reclaim and protected activity retirement clear code and disable old actions', () async {
    await open();
    final thread = chat.selectedThread!;
    final old = chat.billingVerificationIn(thread)!;
    details();
    await pumpEventQueue();
    gateway.event('session.reclaimed', '', {
      'session_id': 'rt-1',
      'stored_session_id': 'stored-1',
      'reason': 'Synthetic retirement',
    });
    await pumpEventQueue();
    expect(old.verification, isNull);
    expect(chat.billingVerificationIn(thread), isNull);
    await old.start();
    expect(gateway.methods, isNot(contains('billing.step_up')));
    activity.value = false;
    details();
    await pumpEventQueue();
    expect(chat.billingVerificationIn(thread), isNull);
  });
  test('socket loss clears details and same runtime on a new client needs fresh authority', () async {
    await open();
    final thread = chat.selectedThread!;
    final old = chat.billingVerificationIn(thread)!;
    details();
    await pumpEventQueue();
    gateway.drop();
    await pumpEventQueue();
    expect(old.verification, isNull);
    expect(chat.billingVerificationIn(thread), isNull);
    chat.submit('Reconnect', const []);
    await pumpEventQueue();
    final replacement = chat.billingVerificationIn(thread)!;
    expect(replacement.verification, isNull);
    await old.start();
    expect(gateway.methods, isNot(contains('billing.step_up')));
    gateway.event('message.complete', 'rt-1', {
      'text': 'Main',
      'status': 'complete',
    });
    await pumpEventQueue();
  });
  test('unavailable optional RPC preserves ordinary chat and server retry delay is authoritative', () async {
    await open();
    final module = chat.billingVerificationIn(chat.selectedThread!)!;
    final pending = module.start();
    await pumpEventQueue();
    answer({'ok': false, 'granted': false, 'retry_after': 10});
    await pending;
    expect(module.status, BillingVerificationStatus.refused);
    expect(module.canStart, isFalse);
    now = now.add(const Duration(seconds: 10));
    expect(module.canStart, isTrue);
    gateway.silent.remove('billing.step_up');
    gateway.handlers['billing.step_up'] = (_) =>
        throw const FakeRpcError(-32601);
    await module.start();
    expect(module.status, BillingVerificationStatus.unavailable);
    final requestsBefore = gateway.requests
        .where((row) => row['method'] == 'billing.step_up')
        .length;
    await chat.loadThreads('other');
    chat.select('stored-1');
    await pumpEventQueue();
    final unavailable = chat.billingVerificationIn(chat.selectedThread!)!;
    expect(unavailable.canStart, isFalse);
    await unavailable.start();
    expect(
      gateway.requests.where((row) => row['method'] == 'billing.step_up'),
      hasLength(requestsBefore),
    );
    chat.submit('Ordinary chat', const []);
    await pumpEventQueue();
    expect(chat.selectedThread!.isReplying, isTrue);
    gateway.event('message.complete', 'rt-2', {
      'text': 'Main',
      'status': 'complete',
    });
    await pumpEventQueue();
  });
  test(
    'lock reentry during pending notification prevents actual billing mutation',
    () async {
      await open();
      final module = chat.billingVerificationIn(chat.selectedThread!)!;
      module.addListener(() {
        if (module.status == BillingVerificationStatus.pending &&
            !lock.covered) {
          lock.setCovered(true);
        }
      });
      await module.start();
      expect(gateway.methods, isNot(contains('billing.step_up')));
      expect(module.verification, isNull);
    },
  );
  test('activity retirement during pending notification prevents billing bytes and clears private state', () async {
    await open();
    final module = chat.billingVerificationIn(chat.selectedThread!)!;
    chat.addListener(() {
      if (module.status == BillingVerificationStatus.pending &&
          activity.value) {
        activity.value = false;
      }
    });
    await module.start();
    expect(gateway.methods, isNot(contains('billing.step_up')));
    expect(module.verification, isNull);
    expect(chat.billingVerificationIn(chat.selectedThread!), isNull);
  });
  test('billing notification can retire activity without disposing an active notifier', () async {
    await open();
    final thread = chat.selectedThread!;
    final module = chat.billingVerificationIn(thread)!;
    final errors = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = errors.add;
    try {
      module.addListener(() {
        if (module.status == BillingVerificationStatus.pending &&
            activity.value) {
          activity.value = false;
        }
      });
      await module.start();
      await pumpEventQueue();
      expect(errors, isEmpty);
      expect(gateway.methods, isNot(contains('billing.step_up')));
      expect(module.verification, isNull);
      expect(chat.billingVerificationIn(thread), isNull);
    } finally {
      FlutterError.onError = previous;
    }
  });

  test(
    'auxiliary controller without lock coverage exposes no billing authority',
    () async {
      chat.dispose();
      chat = ChatController(
        repository: HermesChatRepository(server.client().raw),
        transport: transport,
        attention: attention,
        report: (_) {},
        billingBrowser: (uri) async {
          opened.add(uri);
          return true;
        },
        billingCopyCode: (code) async {
          copied.add(code);
        },
      );
      lock.setCovered(true);
      await open();
      final thread = chat.selectedThread!;
      details();
      await pumpEventQueue();
      final module = chat.billingVerificationIn(thread);
      if (module != null) {
        expect(module.verification?.userCode, 'PRIVATE-CODE');
        expect(module.canStart, isTrue);
        final pending = module.start();
        await pumpEventQueue();
        answer({'ok': true, 'granted': true});
        await pending;
      }
      expect(module, isNull);
      expect(gateway.methods, isNot(contains('billing.step_up')));
      expect(opened, isEmpty);
      expect(copied, isEmpty);
    },
  );

  testWidgets(
    'actual auxiliary window omits billing without proven lock coverage',
    (tester) async {
      chat.dispose();
      ownsChat = false;
      final link = _AuxiliaryLink();
      try {
        lock.setCovered(true);
        await tester.pumpWidget(
          MaterialApp(
            home: ConversationWindowScreen(
              args: const ConversationWindowArgs(
                threadId: 'stored-1',
                profile: 'work',
                title: 'Billing test',
                baseUrl: 'https://hermes.test',
                authRequired: true,
              ),
              link: link,
              chat: HermesChatRepository(server.client().raw),
              transport: transport,
              attachmentSource: FakeAttachmentSource(),
            ),
          ),
        );
        await tester.runAsync(() async {
          await pumpEventQueue();
        });
        await tester.pump();
        for (
          var attempt = 0;
          attempt < 4 && !gateway.methods.contains('session.resume');
          attempt++
        ) {
          await tester.pumpAndSettle();
          await tester.runAsync(() async {
            await pumpEventQueue();
          });
          await tester.pump();
        }
        expect(gateway.methods, contains('session.resume'));
        await tester.runAsync(() async {
          details();
          await pumpEventQueue();
        });
        await tester.pump();
        expect(find.byType(BillingVerificationCard), findsNothing);
        expect(find.text('Verify billing access'), findsNothing);
        expect(find.text('PRIVATE-CODE'), findsNothing);
        expect(gateway.methods, isNot(contains('billing.step_up')));
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(() async {
          await transport.close();
          await pumpEventQueue();
        });
        await link.dispose();
      }
    },
  );

  testWidgets(
    'actual bounded chat exposes explicit billing action and private expandable details',
    (tester) async {
      tester.view.physicalSize = const Size(320, 360);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.runAsync(() async {
        await open();
      });
      final composer = TextEditingController(),
          focus = FocusNode(),
          latest = LatestReply();
      addTearDown(composer.dispose);
      addTearDown(focus.dispose);
      addTearDown(latest.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: boundChatThreadView(
              chat: chat,
              thread: chat.selectedThread,
              composerController: composer,
              composerFocus: focus,
              attachments: const [],
              attachmentSource: FakeAttachmentSource(),
              onAddAttachments: (_) {},
              onRemoveAttachment: (_) {},
              onSend: (_) {},
              latestReply: latest,
            ),
          ),
        ),
      );
      expect(find.text('Verify billing access'), findsOneWidget);
      expect(gateway.methods, isNot(contains('billing.step_up')));
      expect(find.text('PRIVATE-CODE'), findsNothing);
      await tester.ensureVisible(find.text('Verify billing access'));
      await tester.tap(find.text('Verify billing access'));
      await tester.runAsync(() async {
        await pumpEventQueue();
        details();
        await pumpEventQueue();
      });
      await tester.pump();
      final disclosure = find.descendant(
        of: find.byType(BillingVerificationCard),
        matching: find.byType(ExpansionTile),
      );
      await tester.ensureVisible(disclosure);
      await tester.tap(disclosure);
      await tester.pumpAndSettle();
      expect(find.text('PRIVATE-CODE'), findsOneWidget);
      expect(find.text('Copy code'), findsOneWidget);
      expect(tester.takeException(), isNull);
      lock.setCovered(true);
      await tester.pump();
      expect(find.text('PRIVATE-CODE'), findsNothing);
      await tester.runAsync(() async {
        answer({'ok': true, 'granted': true});
        await pumpEventQueue();
      });
    },
  );
}

class _TestAppLock extends AppLockController {
  bool _covered = false;
  @override
  bool get covered => _covered;
  void setCovered(bool value) {
    _covered = value;
    notifyListeners();
  }
}

class _AuxiliaryLink implements ConversationWindowLink {
  final _commands = StreamController<String>.broadcast();
  final _keys = StreamController<bool>.broadcast();
  Future<void> dispose() async {
    await _commands.close();
    await _keys.close();
  }

  @override
  Stream<String> get commands => _commands.stream;
  @override
  Stream<bool> get keyChanges => _keys.stream;
  @override
  Future<Map<String, String>> headers({Map<String, String>? rejected}) async =>
      const {};
  @override
  void reportFocus(bool focused) {}
  @override
  void reportThread(String title, {required bool pinned}) {}
  @override
  Future<void> showInMain(String threadId, String? profile) async {}
  @override
  Future<void> showMain() async {}
  @override
  Future<void> present({
    required String frameName,
    required String title,
  }) async {}
  @override
  Future<void> close() async {}
  @override
  Future<void> share(String text, Rect anchor) async {}
}
