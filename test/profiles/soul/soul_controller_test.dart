import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:flutter_otel/flutter_otel.dart' show BreadcrumbTrail;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/profiles/soul/soul_controller.dart';
import 'package:hermes_app/src/profiles/soul/soul_repository.dart';
import 'package:hermes_app/src/profiles/soul/soul_telemetry.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';

import '../../support/fake_hermes_server.dart';
import '../../support/recorded_events.dart';
import '../../support/recording_tracer.dart';
import 'soul_fixtures.dart';

void main() {
  late FakeHermesServer server;
  late RecordingTracer tracer;
  late RecordedEvents events;
  late BreadcrumbTrail trail;
  late SoulController controller;
  var notified = 0;

  // What the fake server holds, and what it was sent.
  var fileExists = true;
  var fileText = 'You are Quill.';
  var putStatus = 200;
  Object? putBody = soulSaved;
  var applyPuts = true;
  final puts = <String>[];
  int gets() => server.requests.where((r) => r.method == 'GET').length;

  void routes() {
    server.onRequest(
      'GET',
      soulPath,
      (_) => (status: 200, body: {'content': fileText, 'exists': fileExists}),
    );
    server.onRequest('PUT', soulPath, (request) {
      final sent =
          (jsonBody(request)! as Map<String, Object?>)['content']! as String;
      puts.add(sent);
      if (putStatus == 200 && applyPuts) {
        fileText = sent;
        fileExists = true;
      }
      return (status: putStatus, body: putBody);
    });
  }

  SoulController build({
    Duration timeout = kSoulAnswerTimeout,
    VoidCallback? onUnsupported,
    String profile = soulProfile,
    SoulOpenedFrom from = SoulOpenedFrom.sidebar,
  }) {
    controller = SoulController(
      repository: SoulRepository(server.client().raw),
      profile: profile,
      openedFrom: from,
      answerTimeout: timeout,
      onUnsupported: onUnsupported,
      telemetry: SoulTelemetry(
        ConnectionTelemetry(
          events: events.call,
          tracer: tracer,
          serverAttributes: const {'hermes.version': '0.14.2'},
        ),
        Breadcrumbs.of(trail),
      ),
    )..addListener(() => notified++);
    addTearDown(controller.dispose);
    return controller;
  }

  /// A loaded controller with [text] typed in.
  Future<SoulController> loaded([String? text]) async {
    build();
    await controller.start();
    if (text != null) controller.setText(text);
    return controller;
  }

  /// Saves [text] through the question, up to and including Replace.
  Future<void> save() async {
    expect(controller.requestSave(), isNotNull);
    await controller.confirmSave();
  }

  /// Lets the real Dio pipeline run to its end on the fake clock.
  void settle(FakeAsync async) {
    async.elapse(const Duration(milliseconds: 1));
    async.flushMicrotasks();
  }

  setUp(() {
    server = FakeHermesServer();
    tracer = RecordingTracer();
    events = RecordedEvents();
    trail = BreadcrumbTrail();
    notified = 0;
    fileExists = true;
    fileText = 'You are Quill.';
    putStatus = 200;
    putBody = soulSaved;
    applyPuts = true;
    puts.clear();
    routes();
  });

  group('loading', () {
    test('a read file is the baseline and the editor text', () async {
      await loaded();
      expect(controller.load, SoulLoad.loaded);
      expect(controller.showsEditor, isTrue);
      expect(controller.text, 'You are Quill.');
      expect(controller.dirty, isFalse);
      expect(controller.exists, isTrue);
    });

    test('is loading until the answer, and reads the named profile', () async {
      build();
      final started = controller.start();
      expect(controller.load, SoulLoad.loading);
      expect(controller.showsEditor, isFalse);
      await started;
      final request = server.requests.single;
      expect(request.path, soulPath);
      expect(request.queryParameters, isEmpty);
    });

    test('an absent file is notSet with an empty editor', () async {
      fileExists = false;
      fileText = '';
      await loaded();
      expect(controller.load, SoulLoad.notSet);
      expect(controller.showsEditor, isTrue);
      expect(controller.text, '');
      expect(controller.exists, isFalse);
      expect(controller.dirty, isFalse);
    });

    test('an empty file is loaded, not notSet', () async {
      fileText = '';
      await loaded();
      expect(controller.load, SoulLoad.loaded);
    });

    test('a 500 or malformed answer shows no editor', () async {
      for (final (status, body) in <(int, Object?)>[
        (500, soulPlainServerError),
        (200, {'exists': true}),
        (422, soulMissingContent),
      ]) {
        server.on('GET', soulPath, body, status: status);
        build();
        await controller.start();
        expect(controller.load, SoulLoad.failed, reason: '$status');
        expect(controller.showsEditor, isFalse);
        expect(controller.text, '');
        controller.setText('typed anyway');
        expect(controller.text, '');
      }
    });

    test('no answer is offline, and reload recovers', () async {
      server.onRequest(
        'GET',
        soulPath,
        (request) => throw DioException.connectionError(
          requestOptions: request,
          reason: 'down',
        ),
      );
      build();
      await controller.start();
      expect(controller.load, SoulLoad.offline);
      expect(controller.showsEditor, isFalse);
      routes();
      await controller.reload();
      expect(controller.load, SoulLoad.loaded);
      expect(controller.text, 'You are Quill.');
    });

    test('a missing profile is profileGone', () async {
      server.on('GET', soulPath, soulProfileMissing, status: 404);
      build();
      await controller.start();
      expect(controller.load, SoulLoad.profileGone);
      expect(controller.showsEditor, isFalse);
    });

    test('a missing route is unsupported and says so once', () async {
      server.on('GET', soulPath, soulRouteMissing, status: 404);
      var told = 0;
      build(onUnsupported: () => told++);
      await controller.start();
      expect(controller.load, SoulLoad.unsupported);
      await controller.reload();
      expect(told, 1);
    });

    test('a 401 is a failed read, not a crash', () async {
      server.on('GET', soulPath, soulUnauthorized, status: 401);
      build();
      await controller.start();
      expect(controller.load, SoulLoad.failed);
    });
  });

  group('editing', () {
    test('dirty means the text differs from the baseline', () async {
      await loaded();
      controller.setText('Changed');
      expect(controller.dirty, isTrue);
      controller.setText('You are Quill.');
      expect(controller.dirty, isFalse);
    });

    test('revert returns to the baseline', () async {
      await loaded('Changed');
      controller.revert();
      expect(controller.text, 'You are Quill.');
      expect(controller.dirty, isFalse);
    });

    test('a text over 500,000 characters stays editable and savable', () async {
      await loaded();
      final long = 'a' * 600000;
      controller.setText(long);
      expect(controller.text.length, 600000);
      expect(controller.dirty, isTrue);
      await save();
      expect(puts.single.length, 600000);
      expect(controller.status, SoulStatus.saved);
    });
  });

  group('saving', () {
    test('sends nothing until the question is confirmed', () async {
      await loaded('New text');
      final question = controller.requestSave();
      expect(question, isNotNull);
      expect(question!.empty, isFalse);
      expect(question.pendingSaveNote, isFalse);
      expect(controller.status, SoulStatus.asking);
      expect(puts, isEmpty);
      expect(gets(), 1);
      controller.cancelSave();
      expect(controller.status, SoulStatus.idle);
      expect(puts, isEmpty);
      expect(gets(), 1);
    });

    test('a confirm without a question sends nothing', () async {
      await loaded('New text');
      await controller.confirmSave();
      expect(puts, isEmpty);
      expect(gets(), 1);
    });

    test('nothing to save: no question', () async {
      await loaded();
      expect(controller.requestSave(), isNull);
    });

    test('the question for empty text says so', () async {
      await loaded('');
      expect(controller.requestSave()!.empty, isTrue);
    });

    test('reads again, then sends once, and moves the baseline', () async {
      await loaded('New text');
      await save();
      expect(server.requests.map((r) => r.method), ['GET', 'GET', 'PUT']);
      expect(puts, ['New text']);
      expect(controller.status, SoulStatus.saved);
      expect(controller.dirty, isFalse);
      controller.setText('More');
      expect(controller.dirty, isTrue);
      controller.setText('New text');
      expect(controller.dirty, isFalse);
    });

    test('empty text saves, and the file then exists', () async {
      await loaded('');
      await save();
      expect(puts, ['']);
      expect(controller.exists, isTrue);
      expect(controller.status, SoulStatus.saved);
    });

    test('an absent file with an empty editor has nothing to save', () async {
      fileExists = false;
      fileText = '';
      await loaded();
      expect(controller.requestSave(), isNull);
    });

    test('a read equal to the new text is Saved without a PUT', () async {
      await loaded('New text');
      fileText = 'New text';
      await save();
      expect(puts, isEmpty);
      expect(controller.status, SoulStatus.saved);
      expect(controller.dirty, isFalse);
    });

    test('a file changed on the server sends nothing', () async {
      await loaded('Mine');
      fileText = 'Theirs';
      await save();
      expect(puts, isEmpty);
      expect(controller.status, SoulStatus.changedOnServer);
      expect(controller.serverText, 'Theirs');
      expect(controller.serverExists, isTrue);
      expect(controller.text, 'Mine');
    });

    test('a file gone on the server is a change', () async {
      await loaded('Mine');
      fileExists = false;
      fileText = '';
      await save();
      expect(puts, isEmpty);
      expect(controller.status, SoulStatus.changedOnServer);
      expect(controller.serverExists, isFalse);
    });

    test('Keep editing leaves the text and sends nothing', () async {
      await loaded('Mine');
      fileText = 'Theirs';
      await save();
      controller.keepEditing();
      expect(controller.status, SoulStatus.idle);
      expect(controller.text, 'Mine');
      expect(controller.serverText, isNull);
      expect(puts, isEmpty);
    });

    test(
      'Replace anyway sends exactly once, then it is the baseline',
      () async {
        await loaded('Mine');
        fileText = 'Theirs';
        await save();
        final first = controller.replaceAnyway();
        final second = controller.replaceAnyway();
        await Future.wait([first, second]);
        expect(puts, ['Mine']);
        expect(controller.status, SoulStatus.saved);
        expect(controller.dirty, isFalse);
        await controller.replaceAnyway();
        expect(puts, ['Mine']);
      },
    );

    test('a failed check read sends nothing and Try again works', () async {
      await loaded('Mine');
      server.on('GET', soulPath, soulPlainServerError, status: 500);
      await save();
      expect(controller.status, SoulStatus.saveCheckFailed);
      expect(puts, isEmpty);
      expect(controller.text, 'Mine');
      routes();
      await controller.confirmSave();
      expect(puts, ['Mine']);
      expect(controller.status, SoulStatus.saved);
    });

    test(
      'a missing file is never Saved without a PUT, even for empty text',
      () async {
        await loaded('Mine');
        controller.setText('');
        fileExists = false;
        fileText = '';
        await save();
        expect(controller.status, SoulStatus.changedOnServer);
        expect(puts, isEmpty);
        await controller.replaceAnyway();
        expect(puts, ['']);
        expect(controller.status, SoulStatus.saved);
      },
    );

    test('Keep editing after a save conflict logs conflict_kept', () async {
      await loaded('Mine');
      fileText = 'Theirs';
      await save();
      controller.keepEditing();
      expect(events.named('profile_soul.saved').last, {
        'outcome': 'conflict_kept',
        'empty': false,
      });
    });

    test('Try again after a failed check read adds no second crumb', () async {
      await loaded('Mine');
      server.on('GET', soulPath, soulPlainServerError, status: 500);
      await save();
      routes();
      await controller.confirmSave();
      expect(
        trail.recent.where((c) => c.name == 'profile_soul.save.confirmed'),
        hasLength(1),
      );
    });

    test('a refused write keeps the text and is never resent', () async {
      await loaded('Mine');
      for (final status in [400, 404, 422, 500]) {
        putStatus = status;
        putBody = status == 404 ? soulProfileMissing : soulBadName;
        puts.clear();
        build();
        await controller.start();
        controller.setText('Mine');
        await save();
        expect(puts, ['Mine'], reason: '$status');
        if (status == 404) {
          expect(controller.load, SoulLoad.profileGone);
        } else {
          expect(controller.status, SoulStatus.saveFailed, reason: '$status');
          expect(controller.text, 'Mine');
          expect(controller.dirty, isTrue);
        }
      }
    });

    test('a 200 without ok is a lost answer', () async {
      putBody = {'ok': false};
      await loaded('Mine');
      await save();
      expect(controller.status, SoulStatus.lostAnswer);
      expect(controller.dirty, isTrue);
    });

    test('a second press while busy sends nothing', () async {
      final gate = Completer<void>();
      await loaded('Mine');
      server.onRequest('PUT', soulPath, (request) async {
        puts.add('x');
        await gate.future;
        return (status: 200, body: soulSaved);
      });
      expect(controller.requestSave(), isNotNull);
      final running = controller.confirmSave();
      await pumpEventQueue();
      expect(controller.status, SoulStatus.saving);
      expect(controller.busy, isTrue);
      expect(controller.requestSave(), isNull);
      await controller.confirmSave();
      await controller.check();
      expect(puts, ['x']);
      gate.complete();
      await running;
      expect(puts, ['x']);
    });

    test('the editor is read-only while the read and the PUT run', () async {
      final gate = Completer<void>();
      await loaded('Mine');
      server.onRequest('GET', soulPath, (_) async {
        await gate.future;
        return (status: 200, body: {'content': fileText, 'exists': true});
      });
      expect(controller.readOnly, isFalse);
      expect(controller.requestSave(), isNotNull);
      final running = controller.confirmSave();
      await pumpEventQueue();
      expect(controller.status, SoulStatus.verifying);
      expect(controller.readOnly, isTrue);
      controller.setText('Sneaky');
      controller.revert();
      expect(controller.text, 'Mine');
      gate.complete();
      await running;
      expect(controller.readOnly, isFalse);
      expect(puts, ['Mine']);
    });
  });

  group('lost answers', () {
    // The PUT goes out and no answer comes back.
    Future<void> lose(String text) async {
      applyPuts = false;
      server.onRequest('PUT', soulPath, (request) {
        puts.add(text);
        throw DioException.connectionError(
          requestOptions: request,
          reason: 'dropped',
        );
      });
      await loaded(text);
      await save();
      expect(controller.status, SoulStatus.lostAnswer);
    }

    test('keeps the text, resends nothing, is not Saved', () async {
      await lose('Mine');
      expect(puts, ['Mine']);
      expect(controller.text, 'Mine');
      expect(controller.dirty, isTrue);
      expect(controller.canCheck, isTrue);
      expect(controller.status, isNot(SoulStatus.saved));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(puts, ['Mine']);
    });

    test('Check: the file holds what was sent, so Saved', () async {
      await lose('Mine');
      fileText = 'Mine';
      await controller.check();
      expect(controller.status, SoulStatus.saved);
      expect(controller.dirty, isFalse);
      expect(puts, ['Mine']);
    });

    test('Check compares with the sent text, edits stay dirty', () async {
      await lose('Mine');
      controller.setText('Mine, then more');
      fileText = 'Mine';
      await controller.check();
      expect(controller.status, SoulStatus.saved);
      expect(controller.text, 'Mine, then more');
      expect(controller.dirty, isTrue);
      expect(controller.canCheck, isFalse);
    });

    test('Check: a missing file never confirms an empty text', () async {
      fileText = 'x';
      await loaded('');
      applyPuts = false;
      server.onRequest('PUT', soulPath, (request) {
        puts.add('');
        throw DioException.connectionError(
          requestOptions: request,
          reason: 'dropped',
        );
      });
      await save();
      expect(controller.status, SoulStatus.lostAnswer);
      fileExists = false;
      fileText = '';
      await controller.check();
      expect(controller.status, isNot(SoulStatus.saved));
      expect(controller.status, SoulStatus.changedOnServer);
    });

    test('Check: still the earlier text, not a definite failure', () async {
      await lose('Mine');
      await controller.check();
      expect(controller.status, SoulStatus.earlierText);
      expect(controller.text, 'Mine');
      expect(controller.pendingSaveNote, isTrue);
      expect(controller.canCheck, isTrue);
      final question = controller.requestSave();
      expect(question!.pendingSaveNote, isTrue);
    });

    test('Check: anything else is the changed-on-server question', () async {
      await lose('Mine');
      fileText = 'Theirs';
      await controller.check();
      expect(controller.status, SoulStatus.changedOnServer);
      expect(controller.serverText, 'Theirs');
      expect(puts, ['Mine']);
      routes();
      await controller.replaceAnyway();
      expect(puts, ['Mine', 'Mine']);
      expect(controller.status, SoulStatus.saved);
    });

    test('a failed Check says so and the lost answer stands', () async {
      await lose('Mine');
      server.on('GET', soulPath, soulPlainServerError, status: 500);
      await controller.check();
      expect(controller.status, SoulStatus.lostCheckFailed);
      expect(controller.canCheck, isTrue);
      expect(puts, ['Mine']);
    });

    test('Save after a save that landed reports Saved without a PUT', () async {
      await lose('Mine');
      fileText = 'Mine';
      expect(controller.requestSave(), isNotNull);
      await controller.confirmSave();
      expect(puts, ['Mine']);
      expect(controller.status, SoulStatus.saved);
    });

    test(
      'an earlier save that landed does not make a later edit a conflict',
      () async {
        await lose('A');
        fileText = 'A';
        controller.setText('AB');
        applyPuts = true;
        routes();
        await save();
        expect(controller.status, SoulStatus.saved);
        expect(puts, ['A', 'AB']);
        expect(fileText, 'AB');
        expect(controller.dirty, isFalse);
      },
    );

    test('a refused save after a lost answer still offers Check', () async {
      await lose('Mine');
      controller.setText('Other');
      putStatus = 500;
      putBody = {'detail': 'boom'};
      server.onRequest('PUT', soulPath, (_) => (status: 500, body: putBody));
      await save();
      expect(controller.status, SoulStatus.saveFailed);
      expect(controller.canCheck, isTrue);
      fileText = 'Mine';
      await controller.check();
      expect(controller.status, SoulStatus.saved);
    });

    test('Keep editing after Check logs no conflict_kept', () async {
      await lose('Mine');
      fileText = 'Someone else';
      await controller.check();
      expect(controller.status, SoulStatus.changedOnServer);
      controller.keepEditing();
      expect(
        events
            .named('profile_soul.saved')
            .where((e) => e['outcome'] == 'conflict_kept'),
        isEmpty,
      );
    });

    test('Check is only offered after a lost answer', () async {
      await loaded('Mine');
      final before = gets();
      await controller.check();
      expect(gets(), before);
    });
  });

  group('timeouts', () {
    test('the check read gives up after 10 s and sends nothing', () {
      fakeAsync((async) {
        final gate = Completer<FakeResponse>();
        build();
        controller.start();
        settle(async);
        controller.setText('Mine');
        server.onRequest('GET', soulPath, (_) => gate.future);
        controller.requestSave();
        controller.confirmSave();
        async.elapse(const Duration(seconds: 9));
        expect(controller.status, SoulStatus.verifying);
        async.elapse(const Duration(seconds: 1));
        settle(async);
        expect(controller.status, SoulStatus.saveCheckFailed);
        expect(puts, isEmpty);
        // The answer that comes late changes nothing.
        gate.complete((status: 200, body: {'content': 'x', 'exists': true}));
        settle(async);
        expect(controller.status, SoulStatus.saveCheckFailed);
        expect(puts, isEmpty);
      });
    });

    test('the PUT gives up after 10 s: lost answer, nothing resent', () {
      fakeAsync((async) {
        final gate = Completer<FakeResponse>();
        build();
        controller.start();
        settle(async);
        controller.setText('Mine');
        server.onRequest('PUT', soulPath, (request) {
          puts.add('Mine');
          return gate.future;
        });
        controller.requestSave();
        controller.confirmSave();
        async.elapse(const Duration(seconds: 9));
        expect(controller.status, SoulStatus.saving);
        async.elapse(const Duration(seconds: 1));
        settle(async);
        expect(controller.status, SoulStatus.lostAnswer);
        expect(controller.text, 'Mine');
        gate.complete((status: 200, body: soulSaved));
        settle(async);
        async.elapse(const Duration(minutes: 5));
        expect(controller.status, SoulStatus.lostAnswer);
        expect(puts, ['Mine']);
      });
    });

    test('the Check read gives up after 10 s', () {
      fakeAsync((async) {
        build();
        controller.start();
        settle(async);
        controller.setText('Mine');
        server.onRequest('PUT', soulPath, (request) {
          puts.add('Mine');
          throw DioException.connectionError(
            requestOptions: request,
            reason: 'dropped',
          );
        });
        controller.requestSave();
        controller.confirmSave();
        settle(async);
        expect(controller.status, SoulStatus.lostAnswer);
        server.onRequest(
          'GET',
          soulPath,
          (_) => Completer<FakeResponse>().future,
        );
        controller.check();
        async.elapse(const Duration(seconds: 10));
        settle(async);
        expect(controller.status, SoulStatus.lostCheckFailed);
        expect(puts, ['Mine']);
      });
    });
  });

  group('dropping', () {
    test('clear drops the text and ends the controller', () async {
      await loaded('Secret words');
      controller.clear();
      expect(controller.text, '');
      expect(controller.showsEditor, isFalse);
      controller.setText('again');
      expect(controller.text, '');
      expect(controller.requestSave(), isNull);
      await controller.reload();
      expect(controller.text, '');
    });

    test('App Lock drops everything at once, nothing kept', () async {
      await loaded('Secret words');
      fileText = 'Theirs';
      await save();
      expect(controller.serverText, 'Theirs');
      controller.cover();
      expect(controller.covered, isTrue);
      expect(controller.text, '');
      expect(controller.serverText, isNull);
      expect(controller.showsEditor, isFalse);
      expect(controller.requestSave(), isNull);
      final before = gets();
      await pumpEventQueue();
      expect(gets(), before);
    });

    test('after unlock the server text is read again', () async {
      await loaded('Typed and unsaved');
      controller.cover();
      fileText = 'On the server';
      controller.uncover();
      await pumpEventQueue();
      expect(controller.covered, isFalse);
      expect(controller.load, SoulLoad.loaded);
      expect(controller.text, 'On the server');
      expect(controller.dirty, isFalse);
    });

    test('a PUT in flight at App Lock finishes, its outcome dropped, '
        'and the unlock reloads', () async {
      final gate = Completer<void>();
      await loaded('Mine');
      server.onRequest('PUT', soulPath, (request) async {
        puts.add('Mine');
        await gate.future;
        fileText = 'Mine';
        return (status: 200, body: soulSaved);
      });
      expect(controller.requestSave(), isNotNull);
      final running = controller.confirmSave();
      await pumpEventQueue();
      controller.cover();
      gate.complete();
      await running;
      expect(controller.text, '');
      expect(controller.status, isNot(SoulStatus.saved));
      controller.uncover();
      await pumpEventQueue();
      expect(controller.text, 'Mine');
      expect(controller.status, SoulStatus.idle);
      expect(puts, ['Mine']);
    });

    test('the unlocked editor stays read-only until the PUT is out and the '
        'reload lands', () async {
      final gate = Completer<void>();
      await loaded('Mine');
      server.onRequest('PUT', soulPath, (request) async {
        puts.add('Mine');
        await gate.future;
        fileText = 'Mine';
        return (status: 200, body: soulSaved);
      });
      expect(controller.requestSave(), isNotNull);
      final running = controller.confirmSave();
      await pumpEventQueue();
      controller.cover();
      final reads = gets();
      controller.uncover();
      await pumpEventQueue();
      expect(controller.showsEditor, isFalse);
      expect(controller.busy, isTrue);
      expect(controller.readOnly, isTrue);
      expect(gets(), reads, reason: 'no read while the PUT is out');
      controller.setText('Sneaky');
      expect(controller.text, '');
      gate.complete();
      await running;
      await pumpEventQueue();
      expect(controller.busy, isFalse);
      expect(controller.showsEditor, isTrue);
      expect(controller.text, 'Mine');
      expect(controller.status, SoulStatus.idle);
      expect(puts, ['Mine']);
    });

    test('a hung PUT at unlock does not hold the reload past the timeout', () {
      fakeAsync((async) {
        build(timeout: const Duration(seconds: 10));
        unawaited(controller.start());
        settle(async);
        controller.setText('Mine');
        server.onRequest('PUT', soulPath, (_) => Completer<Never>().future);
        controller.requestSave();
        unawaited(controller.confirmSave());
        settle(async);
        controller.cover();
        controller.uncover();
        async.elapse(const Duration(seconds: 11));
        settle(async);
        expect(controller.showsEditor, isTrue);
        expect(controller.text, fileText);
      });
    });

    test('start twice, or while a reload runs, reads once', () async {
      build();
      final first = controller.start();
      final second = controller.start();
      await Future.wait([first, second]);
      expect(gets(), 1);
    });

    test('a late answer after clear is ignored', () async {
      final gate = Completer<void>();
      await loaded('Mine');
      server.onRequest('PUT', soulPath, (request) async {
        puts.add('Mine');
        await gate.future;
        return (status: 200, body: soulSaved);
      });
      expect(controller.requestSave(), isNotNull);
      final running = controller.confirmSave();
      await pumpEventQueue();
      controller.clear();
      final seen = notified;
      gate.complete();
      await running;
      expect(notified, seen);
      expect(controller.status, isNot(SoulStatus.saved));
      expect(controller.text, '');
      expect(controller.exists, isFalse);
    });

    test(
      'cover before start still records opened once, on the first read',
      () async {
        build();
        controller.cover();
        await controller.start();
        expect(
          trail.recent.where((c) => c.name == 'profile_soul.opened'),
          isEmpty,
        );
        controller.uncover();
        await pumpEventQueue();
        controller.cover();
        controller.uncover();
        await pumpEventQueue();
        expect(
          trail.recent.where((c) => c.name == 'profile_soul.opened'),
          hasLength(1),
        );
      },
    );

    test('a check in flight at App Lock is dropped too', () async {
      final gate = Completer<void>();
      await loaded('Mine');
      applyPuts = false;
      server.onRequest('PUT', soulPath, (request) {
        throw DioException.connectionError(
          requestOptions: request,
          reason: 'dropped',
        );
      });
      await save();
      server.onRequest('GET', soulPath, (_) async {
        await gate.future;
        return (status: 200, body: {'content': 'Mine', 'exists': true});
      });
      final checking = controller.check();
      await pumpEventQueue();
      controller.cover();
      gate.complete();
      await checking;
      expect(controller.status, isNot(SoulStatus.saved));
      expect(controller.text, '');
    });

    test(
      'a late answer after dispose is ignored and does not notify',
      () async {
        final gate = Completer<void>();
        build();
        server.onRequest('GET', soulPath, (_) async {
          await gate.future;
          return (status: 200, body: {'content': 'Late', 'exists': true});
        });
        final starting = controller.start();
        await pumpEventQueue();
        controller.dispose();
        final seen = notified;
        gate.complete();
        await starting;
        expect(notified, seen);
        expect(controller.text, '');
      },
    );
  });

  group('paused connection', () {
    test(
      'a pause that lands during the read before a save sends no PUT',
      () async {
        final gate = Completer<void>();
        await loaded('Mine');
        server.onRequest('GET', soulPath, (_) async {
          await gate.future;
          return (status: 200, body: {'content': fileText, 'exists': true});
        });
        expect(controller.requestSave(), isNotNull);
        final running = controller.confirmSave();
        await pumpEventQueue();
        expect(controller.status, SoulStatus.verifying);
        controller.pause();
        gate.complete();
        await running;
        expect(puts, isEmpty);
        expect(controller.status, SoulStatus.saveCheckFailed);
        expect(controller.text, 'Mine');
        expect(controller.dirty, isTrue);
        controller.resume();
        expect(puts, isEmpty, reason: 'the resume sends nothing');
        await controller.confirmSave();
        expect(puts, ['Mine']);
      },
    );

    test('an uncover while paused reads nothing until the resume', () async {
      await loaded('Mine');
      controller.cover();
      controller.pause();
      final reads = gets();
      controller.uncover();
      await pumpEventQueue();
      expect(gets(), reads, reason: 'nothing is read while paused');
      expect(controller.load, SoulLoad.loading);
      controller.resume();
      await pumpEventQueue();
      expect(gets(), reads + 1);
      expect(controller.load, SoulLoad.loaded);
      expect(controller.showsEditor, isTrue);
      expect(controller.text, 'You are Quill.');
    });

    test('a pause that lands while a reload waits reads nothing', () async {
      final gate = Completer<void>();
      await loaded('Mine');
      server.onRequest('PUT', soulPath, (request) async {
        puts.add('Mine');
        await gate.future;
        return (status: 200, body: soulSaved);
      });
      expect(controller.requestSave(), isNotNull);
      final running = controller.confirmSave();
      await pumpEventQueue();
      controller.cover();
      controller.uncover();
      controller.pause();
      final reads = gets();
      gate.complete();
      await running;
      await pumpEventQueue();
      expect(gets(), reads);
      controller.resume();
      await pumpEventQueue();
      expect(gets(), reads + 1);
      expect(controller.showsEditor, isTrue);
    });

    test('a stale flag from Discard does not drop a later edit', () async {
      await loaded('Mine');
      controller.pause();
      controller.discardText();
      controller.cover();
      controller.resume();
      controller.uncover();
      await pumpEventQueue();
      expect(controller.text, 'You are Quill.');
      controller.setText('new unsaved edit');
      final reads = gets();
      controller.pause();
      controller.resume();
      await pumpEventQueue();
      expect(controller.text, 'new unsaved edit');
      expect(gets(), reads);
    });

    test('a discard while paused reads once at the resume', () async {
      await loaded('Mine');
      controller.pause();
      final reads = gets();
      controller.discardText();
      await pumpEventQueue();
      expect(gets(), reads);
      controller.resume();
      await pumpEventQueue();
      expect(gets(), reads + 1);
      expect(controller.text, 'You are Quill.');
    });
  });

  group('telemetry', () {
    const markerText = 'MARKER-TEXT-hunter2';
    const markerProfile = 'marker-profile';
    const markerPath = '/api/profiles/$markerProfile/soul';

    String recorded() => [
      for (final span in tracer.spans) ...[
        span.name,
        ...span.attributes.keys,
        ...span.attributes.values.map((v) => '$v'),
        ...span.events,
        ...span.eventDetails,
        '${span.statusDescription}',
      ],
      for (final name in events.namesStartingWith('')) ...[
        name,
        ...events
            .named(name)
            .expand((a) => [...a.keys, ...a.values.map((v) => '$v')]),
        ...events
            .serverAttributes(name)
            .expand((a) => [...a.keys, ...a.values.map((v) => '$v')]),
      ],
      for (final crumb in trail.recent) ...[
        crumb.name,
        ...crumb.attributes.keys,
        ...crumb.attributes.values.map((v) => '$v'),
      ],
    ].join('\n');

    void markerRoutes() {
      server
        ..on('GET', markerPath, {'content': 'old', 'exists': true})
        ..on('PUT', markerPath, soulSaved);
    }

    test('fixed names and values only, never the text or profile', () async {
      markerRoutes();
      build(profile: markerProfile, from: SoulOpenedFrom.profilesPage);
      await controller.start();
      controller.setText(markerText);
      controller.requestSave();
      await controller.confirmSave();
      expect(controller.status, SoulStatus.saved);

      final fetch = tracer.spans.firstWhere(
        (s) => s.name == 'profile_soul.fetch',
      );
      expect(fetch.attributes['outcome'], 'ok');
      expect(fetch.attributes['exists'], true);
      expect(fetch.attributes['hermes.version'], '0.14.2');
      final span = tracer.spans.singleWhere(
        (s) => s.name == 'profile_soul.save',
      );
      expect(span.attributes['outcome'], 'saved');
      expect(span.attributes['empty'], false);
      expect(span.attributes['length_bucket'], 'lt_1k');
      expect(span.attributes['hermes.version'], '0.14.2');
      expect(span.ended, isTrue);
      expect(events.named('profile_soul.saved'), [
        {'outcome': 'saved', 'empty': false},
      ]);
      final opened = trail.recent.singleWhere(
        (c) => c.name == 'profile_soul.opened',
      );
      expect(opened.attributes, {'source': 'profiles_page'});
      expect(
        trail.recent
            .singleWhere((c) => c.name == 'profile_soul.save.confirmed')
            .attributes,
        isEmpty,
      );

      final text = recorded();
      expect(text, isNot(contains(markerText)));
      expect(text, isNot(contains('MARKER')));
      expect(text, isNot(contains(markerProfile)));
    });

    test('failures, conflicts and lost answers carry no text either', () async {
      markerRoutes();
      build(profile: markerProfile);
      await controller.start();
      controller.setText(markerText);
      server.on('GET', markerPath, {'content': 'theirs', 'exists': true});
      controller.requestSave();
      await controller.confirmSave();
      expect(controller.status, SoulStatus.changedOnServer);
      controller.keepEditing();

      server.on('PUT', markerPath, 'boom $markerText', status: 500);
      server.on('GET', markerPath, {'content': 'old', 'exists': true});
      controller.requestSave();
      await controller.confirmSave();
      expect(controller.status, SoulStatus.saveFailed);

      server.on('PUT', markerPath, {'ok': false});
      controller.requestSave();
      await controller.confirmSave();
      expect(controller.status, SoulStatus.lostAnswer);

      expect(events.named('profile_soul.saved').map((a) => a['outcome']), [
        'conflict_kept',
        'failed',
        'unconfirmed',
      ]);
      final outcomes = tracer.spans
          .where((s) => s.name == 'profile_soul.save')
          .map((s) => s.attributes['outcome']);
      expect(outcomes, ['conflict', 'failed', 'unconfirmed']);
      final text = recorded();
      expect(text, isNot(contains('MARKER')));
      expect(text, isNot(contains(markerProfile)));
      expect(text, isNot(contains('boom')));
      for (final span in tracer.spans) {
        expect(span.events, isNot(contains('exception')));
      }
    });

    test(
      'Replace anyway logs conflict_replaced; length and empty buckets',
      () async {
        await loaded('');
        fileText = 'Theirs';
        await save();
        await controller.replaceAnyway();
        expect(events.named('profile_soul.saved').last, {
          'outcome': 'conflict_replaced',
          'empty': true,
        });
        final buckets = <int, String>{
          999: 'lt_1k',
          1000: 'lt_5k',
          4999: 'lt_5k',
          5000: 'lt_20k',
          19999: 'lt_20k',
          20000: 'gte_20k',
        };
        for (final MapEntry(key: length, value: bucket) in buckets.entries) {
          tracer.spans.clear();
          fileText = 'old';
          build();
          await controller.start();
          controller.setText('a' * length);
          await save();
          expect(
            tracer.spans
                .singleWhere((s) => s.name == 'profile_soul.save')
                .attributes['length_bucket'],
            bucket,
          );
        }
      },
    );

    test('an unread file ends the fetch span as failed', () async {
      server.on('GET', soulPath, soulPlainServerError, status: 500);
      build();
      await controller.start();
      final span = tracer.spans.singleWhere(
        (s) => s.name == 'profile_soul.fetch',
      );
      expect(span.attributes['outcome'], 'failed');
      expect(span.ended, isTrue);
    });
  });
}
