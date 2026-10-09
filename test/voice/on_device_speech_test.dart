import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/voice/on_device_speech.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late List<MethodCall> calls;
  late Map<String, Object? Function(MethodCall)> answers;
  late MockStreamHandlerEventSink? events;
  late int listens;

  setUp(() {
    calls = [];
    answers = {};
    events = null;
    listens = 0;
    messenger.setMockMethodCallHandler(OnDeviceSpeech.methods, (call) async {
      calls.add(call);
      return answers[call.method]?.call(call);
    });
    messenger.setMockStreamHandler(
      OnDeviceSpeech.events,
      MockStreamHandler.inline(
        onListen: (_, sink) {
          listens++;
          events = sink;
        },
      ),
    );
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(OnDeviceSpeech.methods, null);
    messenger.setMockStreamHandler(OnDeviceSpeech.events, null);
  });

  group('status', () {
    for (final (answer, model) in [
      ('unsupported', OnDeviceModel.unsupported),
      ('missing', OnDeviceModel.missing),
      ('downloading', OnDeviceModel.downloading),
      ('installed', OnDeviceModel.installed),
      ('something new', OnDeviceModel.unsupported),
    ]) {
      test('"$answer" reads as $model', () async {
        answers['status'] = (_) => answer;

        expect(await OnDeviceSpeech().status('de-DE'), model);
        expect(calls.single.arguments, {'locale': 'de-DE'});
      });
    }

    test('a platform without the plugin is unsupported', () async {
      messenger.setMockMethodCallHandler(OnDeviceSpeech.methods, null);

      expect(await OnDeviceSpeech().status('en-US'), OnDeviceModel.unsupported);
    });
  });

  group('install', () {
    test('reports progress until the model is installed', () async {
      answers['install'] = (_) => null;
      final speech = OnDeviceSpeech();
      final progress = <double>[];
      speech.installProgress.listen(progress.add);
      await pumpEventQueue();

      events!.success({'type': 'progress', 'fraction': 0.25});
      events!.success({'type': 'progress', 'fraction': 1.0});
      await speech.install('de-DE');
      await pumpEventQueue();

      expect(progress, [0.25, 1.0]);
      expect(calls.single.method, 'install');
      expect(calls.single.arguments, {'locale': 'de-DE'});
    });

    test('tells listeners once a model is installed', () async {
      answers['install'] = (_) => null;
      final speech = OnDeviceSpeech();
      var installs = 0;
      speech.installed.listen((_) => installs++);

      await speech.install('de-DE');
      await pumpEventQueue();

      expect(installs, 1);
    });

    test('a failed install throws its code', () async {
      answers['install'] = (_) =>
          throw PlatformException(code: 'unsupported', message: 'nope');

      await expectLater(
        OnDeviceSpeech().install('xx-YY'),
        throwsA(
          isA<OnDeviceSpeechException>().having(
            (e) => e.code,
            'code',
            'unsupported',
          ),
        ),
      );
    });
  });

  group('session', () {
    late OnDeviceSpeech speech;

    setUp(() {
      answers['start'] = (_) => 7;
      speech = OnDeviceSpeech();
    });

    test('streams audio in and partials and the transcript out', () async {
      answers['finish'] = (_) => 'book a table';
      final session = await speech.start(locale: 'en-US', sampleRate: 16000);
      final partials = <String>[];
      session.partials.listen(partials.add);

      session.add(Uint8List.fromList([1, 2]));
      events!.success({'id': 7, 'type': 'partial', 'text': 'book'});
      events!.success({'id': 8, 'type': 'partial', 'text': 'not ours'});
      events!.success({'id': 7, 'type': 'partial', 'text': 'book a'});
      await pumpEventQueue();

      expect(await session.finish(), 'book a table');
      expect(partials, ['book', 'book a']);
      expect(calls.map((c) => c.method), ['start', 'append', 'finish']);
      expect(calls[0].arguments, {'locale': 'en-US', 'sampleRate': 16000});
      expect(calls[1].arguments, {
        'id': 7,
        'pcm': Uint8List.fromList([1, 2]),
      });
      expect(calls[2].arguments, {'id': 7});
    });

    test('an error ends the session without a transcript', () async {
      answers['finish'] = (_) => 'too late';
      final session = await speech.start(locale: 'en-US', sampleRate: 16000);

      events!.success({'id': 7, 'type': 'error', 'code': 'modelMissing'});
      await pumpEventQueue();

      expect(session.errorCode, 'modelMissing');
      expect(await session.finish(), isNull);
      session.add(Uint8List(2));
      expect(calls.map((c) => c.method), isNot(contains('append')));
    });

    test('a failed finish answers null with its code', () async {
      answers['finish'] = (_) => throw PlatformException(code: 'failed');
      final session = await speech.start(locale: 'en-US', sampleRate: 16000);

      expect(await session.finish(), isNull);
      expect(session.errorCode, 'failed');
    });

    test('cancel tells the platform and stops the audio', () async {
      final session = await speech.start(locale: 'en-US', sampleRate: 16000);

      session.cancel();
      session.add(Uint8List(2));
      await pumpEventQueue();

      expect(calls.map((c) => c.method), ['start', 'cancel']);
      expect(calls.last.arguments, {'id': 7});
      expect(await session.finish(), isNull);
    });

    test('a failed start throws its code', () async {
      answers['start'] = (_) => throw PlatformException(code: 'modelMissing');

      await expectLater(
        speech.start(locale: 'de-DE', sampleRate: 16000),
        throwsA(
          isA<OnDeviceSpeechException>().having(
            (e) => e.code,
            'code',
            'modelMissing',
          ),
        ),
      );
    });
  });

  test('sessions and install progress share one event subscription', () async {
    answers['start'] = (_) => 1;
    final speech = OnDeviceSpeech();
    final progress = <double>[];
    speech.installProgress.listen(progress.add);
    final session = await speech.start(locale: 'en-US', sampleRate: 16000);
    final partials = <String>[];
    session.partials.listen(partials.add);
    await pumpEventQueue();

    events!.success({'type': 'progress', 'fraction': 0.5});
    events!.success({'id': 1, 'type': 'partial', 'text': 'hi'});
    await pumpEventQueue();

    expect(listens, 1);
    expect(progress, [0.5]);
    expect(partials, ['hi']);
  });
}
