import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:hermes_app/src/app_lock/app_lock_controller.dart';
import 'package:hermes_app/src/app_lock/app_lock_dialog.dart';
import 'package:hermes_app/src/app_lock/app_lock_gate.dart';
import 'package:hermes_app/src/chat/attachments/attachment_source.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_screen.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/chat/media/media_source.dart';
import 'package:hermes_app/src/chat/media/media_store.dart';
import 'package:hermes_app/src/share/shared_item.dart';

import '../support/fake_attachment_source.dart';
import '../support/fake_chat_transport.dart';
import '../support/fake_device_authenticator.dart';
import '../support/fake_hermes_server.dart';
import '../support/fake_media_actions.dart';
import '../support/screenshot_recorder.dart';
import '../support/workflow_app.dart';

const _unbrokenWord =
    'Supercalifragilisticexpialidocious_Supercalifragilisticexpialidocious_'
    'Supercalifragilisticexpialidocious_Supercalifragilisticexpialidocious_'
    'Supercalifragilisticexpialidocious';

const _unbrokenPath =
    '/srv/data/warehouse/analytics/staging/2026/09/19/nightly-backup-analytics-'
    'warehouse-with-a-remarkably-long-file-name-that-never-breaks-anywhere.tar.zst';

const _longTool =
    'mcp__github_enterprise_cloud__list_pull_request_review_comments_for_'
    'repository_and_branch';

const _longFile =
    'Quarterly numbers final (v3) with a really long file name that has to '
    'wrap somewhere sensible.csv';

/// Real I/O (fetching, decoding, writing a file) does not run on the test
/// clock, so give it wall-clock time in between frames.
Future<void> _settleIo(WidgetTester tester, {int rounds = 8}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// A picture with something in it, so a thumbnail is worth looking at.
Future<Uint8List> _picture(int w, int h, Color a, Color b) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final size = Size(w.toDouble(), h.toDouble());
  canvas.drawRect(
    Offset.zero & size,
    Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        size.bottomRight(Offset.zero),
        [a, b],
      ),
  );
  final bar = Paint()..color = Colors.white.withValues(alpha: 0.85);
  for (var i = 0; i < 5; i++) {
    final height = size.height * (0.25 + 0.13 * ((i * 3) % 5));
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * (0.08 + i * 0.18),
        size.height - height - 8,
        size.width * 0.12,
        height,
      ),
      bar,
    );
  }
  final image = await recorder.endRecording().toImage(w, h);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

/// A layout overflow is what these screenshots look for, and it would fail
/// the test before the picture is taken. Report it on stdout and carry on;
/// anything else still fails the test.
void richTest(String name, Future<void> Function(WidgetTester) body) {
  testWidgets(name, (tester) async {
    final previous = FlutterError.onError;
    final seen = <String>{};
    FlutterError.onError = (details) {
      final message = details.exceptionAsString();
      if (!message.contains('overflowed')) return previous?.call(details);
      final where = RegExp(r'creator: (.*)')
          .firstMatch(details.exception.toString());
      final line = message.split('\n').first;
      if (seen.add('$line ${where?[1]}')) {
        final chain = where?[1]?.split(' ← ').take(5).join(' < ');
        // ignore: avoid_print
        print('OVERFLOW [$name] $line | $chain');
      }
    };
    try {
      await body(tester);
    } finally {
      FlutterError.onError = previous;
    }
  });
}

typedef _Variant = ({String name, Size size, Brightness brightness});

const _light = <_Variant>[
  (name: 'phone', size: phoneSize, brightness: Brightness.light),
  (name: 'desktop', size: desktopSize, brightness: Brightness.light),
];

const _withDark = <_Variant>[
  ..._light,
  (name: 'phone-dark', size: phoneSize, brightness: Brightness.dark),
];

/// The newer chat features: reasoning, reply actions and follow-ups, files
/// the agent sends, files the user attaches, requests the app cannot answer,
/// the app lock, and content that does not fit.
void main() {
  late FakeHermesServer server;
  late FakeChatTransport transport;
  late FakeMediaActions actions;
  late Directory cache;
  late MediaStore store;
  final copied = <String>[];

  setUp(() {
    transport = FakeChatTransport();
    actions = FakeMediaActions();
    cache = Directory.systemTemp.createTempSync('rich_workflow_cache');
    addTearDown(() => cache.deleteSync(recursive: true));
    server = FakeHermesServer();
    store = MediaStore(
      source: HermesMediaSource(() => server.client()),
      cacheDirectory: () async => cache,
      actions: actions,
    );
    copied.clear();
    server
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([
          sessionRow(id: 's1', title: 'Backup failure', lastActive: 1780000900),
          sessionRow(
            id: 's2',
            title: 'Charts and exports',
            lastActive: 1780000800,
          ),
          sessionRow(
            id: 's3',
            title: 'Stress: long content',
            lastActive: 1780000700,
          ),
          sessionRow(
            id: 's4',
            title: 'Attach something',
            lastActive: 1780000600,
          ),
        ]),
      )
      ..on(
        'GET',
        '/api/sessions/s1/messages',
        messageListBody('s1', [
          messageRow(
            id: 1,
            role: 'user',
            content: 'Why did the nightly backup fail?',
          ),
          messageRow(
            id: 2,
            role: 'assistant',
            content:
                'The job died at **02:14** with a connection reset. The '
                'certificate was rotated at 02:10 and the agent still '
                'pinned the old one.',
            reasoning:
                'The user asks about a backup failure. The logs show a '
                'reset at 02:14, four minutes after the certificate '
                'rotation. That points at a stale pin.',
          ),
        ]),
      )
      ..on(
        'GET',
        '/api/sessions/s2/messages',
        messageListBody('s2', [
          messageRow(
            id: 1,
            role: 'user',
            content: 'Chart the failures and export them.',
          ),
          messageRow(
            id: 2,
            role: 'assistant',
            content:
                'Here is the chart and the exports.\n\n'
                'MEDIA:/home/u/.hermes/images/failures.png\n'
                'MEDIA:/home/u/.hermes/images/portrait.png\n'
                'MEDIA:/srv/exports/report.pdf\n'
                'MEDIA:"/srv/exports/$_longFile"\n'
                'MEDIA:/srv/gone.png\n'
                'MEDIA:/srv/exports/missing.zip\n\n'
                'The last two were cleaned up already.',
          ),
        ]),
      )
      ..on(
        'GET',
        '/api/sessions/s3/messages',
        messageListBody('s3', [
          messageRow(
            id: 1,
            role: 'user',
            content:
                'Check $_unbrokenWord and $_unbrokenPath please, '
                'and $_unbrokenWord$_unbrokenWord',
          ),
          messageRow(
            id: 2,
            role: 'assistant',
            content:
                '# $_unbrokenWord\n\n'
                'The artifact is at $_unbrokenPath and the token '
                '`$_unbrokenWord` did not match.\n\n'
                '- $_unbrokenPath\n'
                '- **$_unbrokenWord**\n'
                '- [$_unbrokenWord](https://example.com/$_unbrokenWord)\n\n'
                'https://staging.example.internal/api/v2/jobs/2f9d6c1e-7a4b-4c1f-9e0d-5b7a1c3e8f42/artifacts/$_unbrokenWord',
            toolCalls: [
              for (var i = 0; i < 14; i++)
                functionCall(
                  i.isEven ? '${_longTool}_$i' : 'read_file',
                  '{"path":"$_unbrokenPath","attempt":$i,"note":"$_unbrokenWord"}',
                ),
            ],
            reasoning:
                'Considering $_unbrokenWord $_unbrokenWord and the path '
                '$_unbrokenPath.',
          ),
        ]),
      )
      ..on('GET', '/api/sessions/s4/messages', messageListBody('s4', []));
  });

  Future<void> mockClipboard(WidgetTester tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
  }

  Future<void> pumpChat(
    WidgetTester tester,
    ScreenshotRecorder shots,
    _Variant v, {
    AttachmentSource? attachmentSource,
  }) async {
    await pumpScreen(
      tester,
      shots,
      ChatScreen(
        repository: HermesChatRepository(server.client().raw),
        transport: transport,
        attachmentSource: attachmentSource,
      ),
      size: v.size,
      brightness: v.brightness,
      providers: [Provider<MediaStore?>.value(value: store)],
    );
  }

  Future<void> openThread(
    WidgetTester tester,
    String id, {
    bool spinners = false,
  }) async {
    await openSidebar(tester);
    await tester.tap(find.byKey(ValueKey('thread-$id')));
    // Images being fetched show a spinner, which never settles.
    await (spinners ? _settleIo(tester) : tester.pumpAndSettle());
  }

  Future<void> send(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(EditableText), text);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await runFrames(tester);
  }

  Future<void> emit(
    WidgetTester tester,
    FakeSend reply,
    ChatEvent event, {
    bool settle = true,
  }) async {
    reply.emit(event);
    await (settle ? runFrames(tester) : tester.pump());
  }

  /// What a user does when the list has not followed the stream down.
  Future<void> toBottom(WidgetTester tester) async {
    final down = find.byIcon(Icons.keyboard_arrow_down);
    if (down.evaluate().isEmpty) return;
    await tester.tap(down, warnIfMissed: false);
    await runFrames(tester);
  }

  Future<FakeSend> startReply(
    WidgetTester tester,
    String threadId,
    String text,
  ) async {
    await openThread(tester, threadId);
    await send(tester, text);
    final reply = transport.sends.last;
    await emit(tester, reply, const ReplyStarted(), settle: false);
    return reply;
  }

  // ---------------------------------------------------------------------
  // Reasoning, reply actions, follow-ups
  // ---------------------------------------------------------------------
  for (final v in _withDark) {
    richTest('${v.name}: reasoning, reply actions, follow-ups', (tester) async {
      final shots = ScreenshotRecorder('chat-rich-${v.name}-reasoning');
      await mockClipboard(tester);
      await pumpChat(tester, shots, v);
      await openThread(tester, 's1');
      await runFrames(tester);
      await shots.capture(tester, 'history-with-actions');

      await tester.tap(find.text('Reasoning'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'history-reasoning-open');
      await tester.tap(find.text('Reasoning'));
      await tester.pumpAndSettle();

      await send(tester, 'Could a stale pin also explain the retries?');
      final reply = transport.sends.single;
      await emit(tester, reply, const ReplyStarted(), settle: false);
      await emit(
        tester,
        reply,
        const ReasoningUpdated('The retries all failed with the same '),
      );
      await shots.capture(tester, 'thinking');

      await emit(
        tester,
        reply,
        const ReasoningUpdated('x509 error, so the pin never changed. '),
      );
      await tester.tap(find.text('Thinking…'));
      await runFrames(tester);
      await shots.capture(tester, 'thinking-open');

      await emit(tester, reply, const ReplyDelta('Yes. Every retry reused '));
      await shots.capture(tester, 'streaming-reply');

      const answer =
          'Yes. Every retry reused the same stale pin, so each one failed '
          'the same way.';
      await emit(tester, reply, const ReplyCompleted(answer));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'completed-actions-follow-ups');

      await tester.tap(find.byTooltip('Copy').last);
      await tester.pump();
      await shots.capture(tester, 'copied');
      expect(copied, [answer]);
      await tester.pump(const Duration(seconds: 3));

      await tester.tap(find.text('Give an example'));
      await runFrames(tester);
      await shots.capture(tester, 'follow-up-sent');
      expect(transport.sends.last.text, 'Give an example');
      await emit(tester, transport.sends.last, const ReplyCompleted('Sure.'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'follow-up-answered');
    });
  }

  // ---------------------------------------------------------------------
  // Files and images the agent sends
  // ---------------------------------------------------------------------
  for (final v in _light) {
    richTest('${v.name}: files and images from the agent', (tester) async {
      final shots = ScreenshotRecorder('chat-rich-${v.name}-agent-media');
      final chart = (await tester.runAsync(
        () => _picture(
          720,
          420,
          const Color(0xff3b6ef5),
          const Color(0xff8a4bd6),
        ),
      ))!;
      final portrait = (await tester.runAsync(
        () => _picture(
          300,
          520,
          const Color(0xffe8833a),
          const Color(0xffb5305c),
        ),
      ))!;
      server
        ..onMedia('/home/u/.hermes/images/failures.png', chart)
        ..onMedia('/home/u/.hermes/images/portrait.png', portrait)
        ..on(
          'GET',
          '/api/media',
          {'detail': 'gone'},
          status: 404,
          query: {'path': '/srv/gone.png'},
        )
        ..on(
          'GET',
          '/api/files/download',
          {'detail': 'gone'},
          status: 404,
          query: {'path': '/srv/exports/missing.zip'},
        )
        ..on(
          'GET',
          '/api/files/download',
          {'detail': 'boom'},
          status: 500,
          query: {'path': '/srv/exports/$_longFile'},
        );
      final gate = Completer<void>();
      server.onRequest('GET', '/api/files/download', (_) async {
        await gate.future;
        return (
          status: 200,
          body: Uint8List.fromList('%PDF-1.7 fake'.codeUnits),
        );
      }, query: {'path': '/srv/exports/report.pdf'});

      await pumpChat(tester, shots, v);
      await openThread(tester, 's2', spinners: true);
      await _settleIo(tester);
      await runFrames(tester);
      await shots.capture(tester, 'reply-with-media');

      await tester.drag(find.byType(Scrollable).first, const Offset(0, 900));
      await tester.pump(const Duration(milliseconds: 500));
      await shots.capture(tester, 'scrolled-up');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -1400));
      await tester.pump(const Duration(milliseconds: 500));
      await runFrames(tester);

      await tester.tap(find.byType(Image).first);
      await _settleIo(tester);
      await tester.pumpAndSettle();
      await shots.capture(tester, 'image-full-screen');
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        await tester.tap(find.text('report.pdf'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump(const Duration(milliseconds: 50));
      await shots.capture(tester, 'file-downloading');

      gate.complete();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(actions.opened, hasLength(1));

      await tester.runAsync(() async {
        await tester.tap(find.byTooltip('Save').first);
        await Future<void>.delayed(const Duration(milliseconds: 250));
      });
      await tester.pump(const Duration(milliseconds: 800));
      await shots.capture(tester, 'file-saved');
      // The snackbar's timer only starts once its slide-in has finished.
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 1));

      await tester.runAsync(() async {
        await tester.tap(find.text(_longFile));
        await Future<void>.delayed(const Duration(milliseconds: 250));
      });
      await tester.pump(const Duration(milliseconds: 300));
      await shots.capture(tester, 'download-failed');

      // The agent's live reply carries a tag too.
      await send(tester, 'And one more picture?');
      final reply = transport.sends.single;
      await emit(tester, reply, const ReplyStarted(), settle: false);
      await emit(
        tester,
        reply,
        const ReplyCompleted(
          'Here it is MEDIA:/home/u/.hermes/images/failures.png',
        ),
      );
      await _settleIo(tester);
      await tester.pumpAndSettle();
      await toBottom(tester);
      await shots.capture(tester, 'live-reply-with-image');
    });
  }

  // ---------------------------------------------------------------------
  // Attaching to the composer
  // ---------------------------------------------------------------------
  for (final v in _withDark) {
    richTest('${v.name}: attach to the composer and send', (tester) async {
      final shots = ScreenshotRecorder('chat-rich-${v.name}-attach');
      final desktop = v.size == desktopSize;
      final dir = Directory.systemTemp.createTempSync('rich_workflow_files');
      addTearDown(() => dir.deleteSync(recursive: true));
      final png = (await tester.runAsync(
        () => _picture(
          640,
          400,
          const Color(0xff2aa876),
          const Color(0xff1d5fa8),
        ),
      ))!;
      File write(String name, List<int> bytes) =>
          File('${dir.path}/$name')..writeAsBytesSync(bytes);
      final report = SharedFile(
        path: write('report.pdf', List.filled(2400 * 1024, 1)).path,
        name: 'quarterly-report-final-v3.pdf',
      );
      final notes = SharedFile(
        path: write('notes.txt', 'some notes'.codeUnits).path,
        name: 'notes.txt',
      );
      final photo = SharedFile(
        path: write('photo.png', png).path,
        name: 'IMG_20260920_153012_034.png',
        mimeType: 'image/png',
        isImage: true,
      );
      final long = SharedFile(
        path: write('long.txt', 'x'.codeUnits).path,
        name: '$_longFile.txt',
      );
      final source =
          FakeAttachmentSource(
              origins: desktop
                  ? const [AttachOrigin.files]
                  : const [
                      AttachOrigin.files,
                      AttachOrigin.photos,
                      AttachOrigin.camera,
                    ],
            )
            ..picks[AttachOrigin.files] = [report, notes]
            ..picks[AttachOrigin.photos] = [photo];

      await pumpChat(tester, shots, v, attachmentSource: source);
      await openThread(tester, 's4');
      await shots.capture(tester, 'empty-thread');

      await tester.tap(find.byIcon(Icons.attach_file));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'attach-menu');

      await tester.tap(find.text('Choose files'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'files-attached');

      if (desktop) {
        source.dragOver(true);
        await tester.pump();
        await shots.capture(tester, 'drag-over');
        source.dragOver(false);
        source.drop([photo, long]);
      } else {
        await tester.tap(find.byIcon(Icons.attach_file));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Photo library'));
        await tester.pumpAndSettle();
        source.drop([long]);
      }
      await tester.pumpAndSettle();
      await shots.capture(tester, 'image-and-long-name-attached');

      await tester.enterText(
        find.byType(EditableText),
        'Summarize these for me',
      );
      await tester.pump();
      await shots.capture(tester, 'ready-to-send');

      await tester.tap(find.byTooltip('Remove notes.txt'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'one-removed');

      await tester.tap(find.byIcon(Icons.arrow_upward));
      await runFrames(tester);
      await _settleIo(tester);
      await shots.capture(tester, 'sent');
      expect(transport.sends.single.attachments, hasLength(3));

      final reply = transport.sends.single;
      await emit(tester, reply, const ReplyStarted(), settle: false);
      await emit(
        tester,
        reply,
        const ReplyCompleted('Got all three. The report is mostly tables.'),
      );
      await tester.pumpAndSettle();
      await shots.capture(tester, 'reply');
    });
  }

  // ---------------------------------------------------------------------
  // A request the app cannot answer
  // ---------------------------------------------------------------------
  for (final v in _withDark) {
    richTest('${v.name}: unsupported requests', (tester) async {
      final shots = ScreenshotRecorder('chat-rich-${v.name}-unsupported');
      await pumpChat(tester, shots, v);
      final reply = await startReply(tester, 's1', 'Install the update.');

      await emit(
        tester,
        reply,
        const UnsupportedRequested(
          UnsupportedRequest(requestId: 'r1', kind: UnsupportedKind.sudo),
        ),
      );
      await shots.capture(tester, 'sudo-requested');

      await tester.tap(find.text('Skip'));
      await tester.pump(const Duration(milliseconds: 300));
      await shots.capture(tester, 'sudo-skipped');
      expect(transport.skips, [('r1', UnsupportedKind.sudo)]);

      await emit(
        tester,
        reply,
        const UnsupportedRequested(
          UnsupportedRequest(requestId: 'r2', kind: UnsupportedKind.secret),
        ),
      );
      await shots.capture(tester, 'secret-requested');

      await emit(tester, reply, const InputRequestExpired('r2'));
      await shots.capture(tester, 'secret-expired');

      await emit(tester, reply, const ReplyCompleted('Carried on without it.'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'completed');
    });
  }

  // ---------------------------------------------------------------------
  // App lock
  // ---------------------------------------------------------------------
  for (final v in _withDark) {
    richTest('${v.name}: app lock', (tester) async {
      final shots = ScreenshotRecorder('chat-rich-${v.name}-app-lock');
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final device = FakeDeviceAuthenticator();
      AppLockController controller() {
        final lock = AppLockController(authenticator: device);
        addTearDown(lock.dispose);
        return lock;
      }

      await tester.runAsync(() async {
        final first = controller();
        await first.load();
        await first.setEnabled(true);
      });
      device.succeeds = false;
      final lock = controller();
      await tester.runAsync(lock.load);

      await pumpScreen(
        tester,
        shots,
        AppLockGate(
          child: ChatScreen(
            repository: HermesChatRepository(server.client().raw),
            transport: transport,
          ),
        ),
        size: v.size,
        brightness: v.brightness,
        providers: [
          ChangeNotifierProvider<AppLockController>.value(value: lock),
          Provider<MediaStore?>.value(value: store),
        ],
      );
      expect(lock.locked, isTrue);
      await shots.capture(tester, 'locked-at-launch');

      device.succeeds = true;
      await tester.tap(find.text('Unlock'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'unlocked');

      await openThread(tester, 's1');
      await runFrames(tester);
      await shots.capture(tester, 'in-a-chat');

      device.succeeds = false;
      lock.didChangeAppLifecycleState(AppLifecycleState.hidden);
      await tester.pump();
      await shots.capture(tester, 'locked-after-leaving');

      lock.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.runAsync(pumpEventQueue);
      await tester.pump();
      expect(lock.locked, isTrue);

      device.succeeds = true;
      await tester.tap(find.text('Unlock'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'back-in-the-chat');
    });
  }

  Future<void> pumpLockSetting(
    WidgetTester tester,
    ScreenshotRecorder shots,
    _Variant v,
    FakeDeviceAuthenticator device,
  ) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final lock = AppLockController(authenticator: device);
    addTearDown(lock.dispose);
    await tester.runAsync(lock.load);
    await pumpScreen(
      tester,
      shots,
      Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: Center(
            child: TextButton(
              onPressed: () => showAppLockDialog(context),
              child: const Text('App lock'),
            ),
          ),
        ),
      ),
      size: v.size,
      brightness: v.brightness,
      providers: [ChangeNotifierProvider<AppLockController>.value(value: lock)],
    );
    await tester.tap(find.text('App lock'));
    await tester.pumpAndSettle();
  }

  for (final v in _withDark) {
    richTest('${v.name}: app lock setting', (tester) async {
      final shots = ScreenshotRecorder('chat-rich-${v.name}-app-lock-setting');
      await pumpLockSetting(tester, shots, v, FakeDeviceAuthenticator());
      await shots.capture(tester, 'off');

      await tester.runAsync(() async {
        await tester.tap(find.byType(SwitchListTile));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();
      await shots.capture(tester, 'on');
    });
  }

  richTest('phone: app lock setting on a device without biometrics', (
    tester,
  ) async {
    final shots = ScreenshotRecorder('chat-rich-phone-app-lock-unavailable');
    await pumpLockSetting(
      tester,
      shots,
      _light.first,
      FakeDeviceAuthenticator(available: false),
    );
    await shots.capture(tester, 'not-available');
  });

  // ---------------------------------------------------------------------
  // Content that does not fit
  // ---------------------------------------------------------------------
  for (final v in _light) {
    richTest('${v.name}: long content stress', (tester) async {
      final shots = ScreenshotRecorder('chat-rich-${v.name}-stress');
      final dir = Directory.systemTemp.createTempSync('rich_workflow_files');
      addTearDown(() => dir.deleteSync(recursive: true));
      final long = SharedFile(
        path: (File('${dir.path}/a.txt')..writeAsStringSync('x')).path,
        name: '$_unbrokenWord.txt',
      );
      final source = FakeAttachmentSource()..picks[AttachOrigin.files] = [long];

      await pumpChat(tester, shots, v, attachmentSource: source);
      await openThread(tester, 's3');
      await runFrames(tester);
      await shots.capture(tester, 'history-bottom');

      await tester.drag(find.byType(Scrollable).first, const Offset(0, 1200));
      await tester.pump(const Duration(milliseconds: 500));
      await shots.capture(tester, 'history-scrolled-up');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 2400));
      await tester.pump(const Duration(milliseconds: 500));
      await shots.capture(tester, 'history-top');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -6000));
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byIcon(Icons.attach_file));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose files'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'long-attachment-chip');

      await send(tester, _unbrokenWord * 3);
      final reply = transport.sends.single;
      await emit(tester, reply, const ReplyStarted(), settle: false);
      for (var i = 0; i < 12; i++) {
        await emit(
          tester,
          reply,
          ToolStarted(
            name: i.isEven ? '${_longTool}_live_$i' : 'run_shell',
            summary: i.isEven ? _unbrokenPath : 'ls -la /var/log',
          ),
          settle: false,
        );
      }
      await runFrames(tester);
      await shots.capture(tester, 'many-tools-running-as-is');
      await toBottom(tester);
      await shots.capture(tester, 'many-tools-running');

      for (var i = 0; i < 12; i++) {
        await emit(
          tester,
          reply,
          ToolFinished(
            name: i.isEven ? '${_longTool}_live_$i' : 'run_shell',
            failed: i % 5 == 0,
          ),
          settle: false,
        );
      }
      await emit(
        tester,
        reply,
        ReasoningUpdated('Hmm, $_unbrokenWord and $_unbrokenPath.'),
      );
      await toBottom(tester);
      await shots.capture(tester, 'many-tools-finished-reasoning-closed');
      for (
        var i = 0;
        i < 20 && find.text('Thinking…').evaluate().isEmpty;
        i++
      ) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, 300));
        await tester.pump(const Duration(milliseconds: 300));
      }
      await tester.tap(find.text('Thinking…'));
      await runFrames(tester);
      await shots.capture(tester, 'many-tools-finished-reasoning');

      await emit(
        tester,
        reply,
        ReplyCompleted('Result: $_unbrokenWord $_unbrokenPath'),
      );
      await tester.pumpAndSettle();
      await toBottom(tester);
      await shots.capture(tester, 'completed');
    });
  }
}
