import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_otel/flutter_otel.dart' show BreadcrumbTrail;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/drag_out/drag_out_item.dart';
import 'package:hermes_app/src/drag_out/drag_out_source.dart';
import 'package:hermes_app/src/drag_out/drag_out_telemetry.dart';
import 'package:hermes_app/src/drag_out/mac_drag_out_source.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';
import 'package:provider/provider.dart';

import '../support/recording_tracer.dart';

const _channel = MethodChannel('test/drag_out');

void main() {
  late List<MethodCall> started;
  late bool nativeStarts;
  late BreadcrumbTrail trail;
  late List<(String, Map<String, Object>)> events;
  late RecordingTracer tracer;
  late MacDragOutSource source;

  setUp(() {
    started = [];
    nativeStarts = true;
    trail = BreadcrumbTrail();
    events = [];
    tracer = RecordingTracer();
    source = MacDragOutSource(
      channel: _channel,
      telemetry: DragOutTelemetry(
        breadcrumbs: Breadcrumbs.of(trail),
        events: (name, [attributes = const {}]) =>
            events.add((name, attributes)),
        tracer: tracer,
      ),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          started.add(call);
          return nativeStarts;
        });
  });

  tearDown(() {
    source.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  // What the Swift side does: calls into Dart on the channel.
  Future<Object?> fromNative(String method, Object? arguments) {
    final reply = Completer<ByteData?>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          _channel.name,
          const StandardMethodCodec().encodeMethodCall(
            MethodCall(method, arguments),
          ),
          reply.complete,
        );
    return reply.future.then(
      (data) => const StandardMethodCodec().decodeEnvelope(data!),
    );
  }

  Future<void> pump(
    WidgetTester tester, {
    DragOutItem? Function()? item,
    DragOutKind kind = DragOutKind.attachment,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Provider<DragOutSource?>.value(
        value: source,
        child: Center(
          child: DragOut(
            kind: kind,
            item: item ?? () => DragOutFile(name: 'a.pdf', read: _noBytes),
            child: const SizedBox.square(dimension: 100, child: Text('card')),
          ),
        ),
      ),
    ),
  );

  Future<TestGesture> press(
    WidgetTester tester, {
    PointerDeviceKind kind = PointerDeviceKind.mouse,
    int buttons = kPrimaryMouseButton,
  }) async {
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('card')),
      kind: kind,
      buttons: buttons,
    );
    return gesture;
  }

  group('starting a drag', () {
    testWidgets('a mouse drag past the slop starts a file promise', (
      tester,
    ) async {
      await pump(
        tester,
        item: () => DragOutFile(name: 'report.pdf', read: _noBytes),
      );

      final gesture = await press(tester);
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump();

      expect(started.single.method, 'startDrag');
      expect(started.single.arguments, {
        'id': 1,
        'type': 'file',
        'name': 'report.pdf',
        'fileType': 'com.adobe.pdf',
      });
      expect(trail.recent.single.name, 'drag_out.started');
      expect(trail.recent.single.attributes, {'kind': 'attachment'});
      await gesture.up();
    });

    testWidgets('text goes out as text', (tester) async {
      await pump(tester, item: () => const DragOutText('# Hi'));

      final gesture = await press(tester);
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump();

      expect(started.single.arguments, {
        'id': 1,
        'type': 'text',
        'text': '# Hi',
      });
      await gesture.up();
    });

    testWidgets('a click, or a slip inside the slop, starts nothing', (
      tester,
    ) async {
      await pump(tester);

      final gesture = await press(tester);
      await gesture.moveBy(const Offset(2, 2));
      await gesture.up();
      await tester.pump();

      expect(started, isEmpty);
      expect(trail.recent, isEmpty);
    });

    testWidgets('a tap still reaches the widget underneath', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Provider<DragOutSource?>.value(
            value: source,
            child: Center(
              child: DragOut(
                kind: DragOutKind.attachment,
                item: () => DragOutFile(name: 'a.pdf', read: _noBytes),
                child: GestureDetector(
                  onTap: () => taps++,
                  child: const SizedBox.square(
                    dimension: 100,
                    child: Text('card'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('card'));

      expect(taps, 1);
      expect(started, isEmpty);
    });

    testWidgets('nothing to hand out starts nothing', (tester) async {
      await pump(tester, item: () => null);

      final gesture = await press(tester);
      await gesture.moveBy(const Offset(20, 0));
      await gesture.up();

      expect(started, isEmpty);
    });

    testWidgets('touch and the secondary button start nothing', (tester) async {
      await pump(tester);

      final touch = await press(tester, kind: PointerDeviceKind.touch);
      await touch.moveBy(const Offset(20, 0));
      await touch.up();
      final secondary = await press(tester, buttons: kSecondaryMouseButton);
      await secondary.moveBy(const Offset(20, 0));
      await secondary.up();

      expect(started, isEmpty);
    });

    testWidgets('one drag per press', (tester) async {
      await pump(tester);

      final gesture = await press(tester);
      await gesture.moveBy(const Offset(20, 0));
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump();

      expect(started, hasLength(1));
      await gesture.up();
    });

    testWidgets('a drag the system refuses leaves no trace', (tester) async {
      nativeStarts = false;
      await pump(tester);

      final gesture = await press(tester);
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump();
      await gesture.up();

      expect(trail.recent, isEmpty);
      await expectLater(
        fromNative('readFile', 1),
        throwsA(isA<PlatformException>()),
      );
    });
  });

  group('delivering a file', () {
    Future<void> begin(WidgetTester tester, DragOutFile file) async {
      await pump(tester, item: () => file);
      final gesture = await press(tester);
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump();
      await gesture.up();
    }

    testWidgets('reads only when the receiver asks, then logs the write', (
      tester,
    ) async {
      var reads = 0;
      await begin(
        tester,
        DragOutFile(
          name: 'a.pdf',
          read: () async {
            reads++;
            return Uint8List.fromList([1, 2, 3]);
          },
        ),
      );
      expect(reads, 0);

      final bytes = await fromNative('readFile', 1);
      expect(bytes, Uint8List.fromList([1, 2, 3]));
      expect(reads, 1);
      expect(events, isEmpty);

      await fromNative('fileWritten', {'id': 1, 'ok': true});
      await fromNative('ended', {'id': 1, 'copied': true});

      expect(events.single.$1, 'drag_out.completed');
      expect(events.single.$2, {'kind': 'attachment', 'outcome': 'delivered'});
      expect(tracer.spans.single.name, 'drag_out.promise');
      expect(tracer.spans.single.ended, isTrue);
    });

    testWidgets('a read that fails gives the receiver no file', (tester) async {
      await begin(
        tester,
        DragOutFile(
          name: 'a.pdf',
          read: () async => throw StateError('/secret/path 404'),
        ),
      );

      await expectLater(
        fromNative('readFile', 1),
        throwsA(
          isA<PlatformException>().having((e) => e.code, 'code', 'fetch'),
        ),
      );

      expect(events.single.$2, {
        'kind': 'attachment',
        'outcome': 'failed',
        'failure': 'fetch',
      });
      expect(events.toString(), isNot(contains('secret')));
    });

    testWidgets('a write that fails is logged as a write failure', (
      tester,
    ) async {
      await begin(tester, DragOutFile(name: 'a.pdf', read: _noBytes));
      await fromNative('readFile', 1);

      await fromNative('fileWritten', {'id': 1, 'ok': false});

      expect(events.single.$2, {
        'kind': 'attachment',
        'outcome': 'failed',
        'failure': 'write',
      });
    });

    testWidgets('a drag no receiver took is cancelled', (tester) async {
      await begin(tester, DragOutFile(name: 'a.pdf', read: _noBytes));

      await fromNative('ended', {'id': 1, 'copied': false});

      expect(events.single.$2, {'kind': 'attachment', 'outcome': 'cancelled'});
    });

    testWidgets('a drop is not complete until the file is written', (
      tester,
    ) async {
      await begin(tester, DragOutFile(name: 'a.pdf', read: _noBytes));

      await fromNative('ended', {'id': 1, 'copied': true});
      expect(events, isEmpty);

      await fromNative('readFile', 1);
      await tester.pump(pendingExpiry * 2);
      expect(events, isEmpty, reason: 'waiting for the write');
    });

    testWidgets('text is complete when the session ends', (tester) async {
      await pump(tester, item: () => const DragOutText('hi'));
      final gesture = await press(tester);
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump();
      await gesture.up();

      await fromNative('ended', {'id': 1, 'copied': true});

      expect(events.single.$2, {'kind': 'attachment', 'outcome': 'delivered'});
    });

    testWidgets('a local file is handed over by path, not read', (
      tester,
    ) async {
      var reads = 0;
      await begin(
        tester,
        DragOutFile(
          name: 'a.pdf',
          read: () async {
            reads++;
            return Uint8List(1);
          },
          localPath: () async => '/cache/a.pdf',
        ),
      );

      expect(await fromNative('readFile', 1), '/cache/a.pdf');
      expect(reads, 0);
    });

    testWidgets('with no local file the bytes are read', (tester) async {
      await begin(
        tester,
        DragOutFile(
          name: 'a.pdf',
          read: () async => Uint8List.fromList([7]),
          localPath: () async => null,
        ),
      );

      expect(await fromNative('readFile', 1), Uint8List.fromList([7]));
    });

    testWidgets('a local file that cannot be produced is a fetch failure', (
      tester,
    ) async {
      await begin(
        tester,
        DragOutFile(
          name: 'a.pdf',
          read: _noBytes,
          localPath: () async => throw StateError('404'),
        ),
      );

      await expectLater(
        fromNative('readFile', 1),
        throwsA(
          isA<PlatformException>().having((e) => e.code, 'code', 'fetch'),
        ),
      );
      expect(events.single.$2['failure'], 'fetch');
    });

    testWidgets('a promise Swift gave up on is logged once', (tester) async {
      final read = Completer<Uint8List>();
      await begin(tester, DragOutFile(name: 'a.pdf', read: () => read.future));
      final asked = fromNative('readFile', 1);
      await tester.pump();

      await fromNative('readTimedOut', 1);
      read.complete(Uint8List(1));

      await expectLater(
        asked,
        throwsA(isA<PlatformException>().having((e) => e.code, 'code', 'gone')),
      );
      expect(events.single.$2, {
        'kind': 'attachment',
        'outcome': 'failed',
        'failure': 'fetch',
      });
    });

    testWidgets('a drop nobody asks a file for is forgotten', (tester) async {
      await begin(tester, DragOutFile(name: 'a.pdf', read: _noBytes));

      await fromNative('ended', {'id': 1, 'copied': true});
      await tester.pump(pendingExpiry - const Duration(seconds: 1));
      expect(events, isEmpty);
      await tester.pump(const Duration(seconds: 2));

      expect(events.single.$2, {'kind': 'attachment', 'outcome': 'cancelled'});
      await expectLater(
        fromNative('readFile', 1),
        throwsA(isA<PlatformException>()),
      );
    });

    testWidgets('a file that is asked for is not forgotten meanwhile', (
      tester,
    ) async {
      await begin(tester, DragOutFile(name: 'a.pdf', read: _noBytes));
      await fromNative('ended', {'id': 1, 'copied': true});
      await fromNative('readFile', 1);

      await tester.pump(pendingExpiry * 2);
      expect(events, isEmpty);

      await fromNative('fileWritten', {'id': 1, 'ok': true});
      expect(events.single.$2['outcome'], 'delivered');
    });

    testWidgets('a reconnect keeps the drop in flight and logs on the new '
        'server', (tester) async {
      await begin(tester, DragOutFile(name: 'a.pdf', read: _noBytes));
      await fromNative('readFile', 1);
      final reconnected = <(String, Map<String, Object>)>[];
      source.telemetry = DragOutTelemetry(
        events: (name, [attributes = const {}]) =>
            reconnected.add((name, attributes)),
      );

      await fromNative('fileWritten', {'id': 1, 'ok': true});

      expect(events, isEmpty);
      expect(reconnected.single.$2['outcome'], 'delivered');
    });

    testWidgets('a disposed source forgets everything', (tester) async {
      await begin(tester, DragOutFile(name: 'a.pdf', read: _noBytes));

      source.dispose();

      // Nobody answers on the channel any more.
      await expectLater(fromNative('readFile', 1), throwsA(anything));
    });

    testWidgets('only slugs reach telemetry', (tester) async {
      await begin(
        tester,
        DragOutFile(name: 'secret-plan.pdf', read: () async => Uint8List(2)),
      );
      await fromNative('readFile', 1);
      await fromNative('fileWritten', {'id': 1, 'ok': true});

      const allowed = {'kind', 'outcome', 'failure'};
      for (final (_, attributes) in events) {
        expect(attributes.keys, everyElement(isIn(allowed)));
      }
      for (final span in tracer.spans) {
        expect(span.attributes.keys, everyElement(isIn(allowed)));
      }
      expect(
        [
          ...events.map((e) => e.$2),
          ...trail.recent.map((c) => c.attributes),
          ...tracer.spans.map((s) => s.attributes),
        ].toString(),
        isNot(contains('secret')),
      );
    });
  });

  test('is supported only on macOS', () {
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    for (final platform in TargetPlatform.values) {
      debugDefaultTargetPlatformOverride = platform;
      expect(
        MacDragOutSource.supported,
        platform == TargetPlatform.macOS,
        reason: '$platform',
      );
    }
  });
}

Future<Uint8List> _noBytes() async => Uint8List(0);
