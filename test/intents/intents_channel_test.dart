import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/intents/ask_hermes.dart';
import 'package:hermes_app/src/intents/intent_shortcuts.dart';
import 'package:hermes_app/src/intents/intents_channel.dart';

class _Ask extends AskHermes {
  _Ask() : super(engine: AskEngine.headless);

  final requests = <AskRequest>[];
  final answers = <Completer<AskResult>>[];
  final finishes = <Completer<void>>[];
  var expired = 0;

  @override
  AskRun start(AskRequest request) {
    requests.add(request);
    final answer = Completer<AskResult>();
    final finished = Completer<void>();
    answers.add(answer);
    finishes.add(finished);
    return AskRun(
      answer: answer.future,
      finished: finished.future,
      onExpire: () => expired++,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(kIntentsChannel);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late _Ask ask;
  late IntentsChannel intents;
  late List<MethodCall> outgoing;

  setUp(() {
    ask = _Ask();
    outgoing = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      outgoing.add(call);
      return null;
    });
    intents = IntentsChannel(ask);
  });

  tearDown(() {
    intents.dispose();
    messenger.setMockMethodCallHandler(channel, null);
  });

  /// What Swift's call to Dart answers; null for a method nobody handles.
  Future<Object?> fromSwift(String method, [Object? arguments]) async {
    final reply = Completer<ByteData?>();
    unawaited(
      messenger.handlePlatformMessage(
        kIntentsChannel,
        const StandardMethodCodec().encodeMethodCall(
          MethodCall(method, arguments),
        ),
        reply.complete,
      ),
    );
    final data = await reply.future;
    return data == null
        ? null
        : const StandardMethodCodec().decodeEnvelope(data);
  }

  Map<String, Object?> askArguments({
    Object? question = 'How many tickets?',
    Object? profile = 'work',
    Object? chatId,
    Object? msLeft = 21000,
    Object? id = 'a1',
  }) => {
    'id': id,
    'question': question,
    'profile': profile,
    'chatId': chatId,
    'msLeft': msLeft,
  };

  test('tells Swift it is ready once the handler is in place', () async {
    await intents.start();

    expect([for (final call in outgoing) call.method], ['ready']);
  });

  group('ask', () {
    setUp(() => intents.start());

    test('parses the arguments into a request', () async {
      final reply = fromSwift('ask', askArguments(chatId: 'work/abc'));
      await pumpEventQueue();

      final request = ask.requests.single;
      expect(request.question, 'How many tickets?');
      expect(request.profile, 'work');
      expect(request.chatId, 'work/abc');
      expect(request.answerWithin, const Duration(seconds: 21));

      ask.answers.single.complete(
        const AskResult(AskOutcome.answered, 'Three.'),
      );
      expect(await reply, {'outcome': 'answered', 'text': 'Three.'});
    });

    test('answers an outcome without text as its name alone', () async {
      final reply = fromSwift('ask', askArguments(profile: null));
      await pumpEventQueue();
      expect(ask.requests.single.profile, isNull);

      ask.answers.single.complete(const AskResult(AskOutcome.stillWorking));
      expect(await reply, {'outcome': 'still_working'});
    });

    test('leaves no time at all for a clock already past', () async {
      unawaited(fromSwift('ask', askArguments(msLeft: -300)));
      await pumpEventQueue();

      expect(ask.requests.single.answerWithin, Duration.zero);
    });

    for (final (name, arguments) in <(String, Object?)>[
      ('no arguments', null),
      ('a non-text question', askArguments(question: 7)),
      ('no question', askArguments(question: null)),
      ('no id', askArguments(id: null)),
      ('a non-number time', askArguments(msLeft: 'soon')),
      ('a non-text chat', askArguments(chatId: 3)),
    ]) {
      test('answers failed to $name and starts nothing', () async {
        expect(await fromSwift('ask', arguments), {'outcome': 'failed'});
        expect(ask.requests, isEmpty);
      });
    }

    test('tells Swift when the ask has nothing left to do', () async {
      unawaited(fromSwift('ask', askArguments()));
      await pumpEventQueue();
      ask.answers.single.complete(const AskResult(AskOutcome.stillWorking));
      await pumpEventQueue();
      expect([for (final call in outgoing) call.method], ['ready']);

      ask.finishes.single.complete();
      await pumpEventQueue();

      expect(outgoing.last.method, 'finished');
      expect(outgoing.last.arguments, 'a1');
    });
  });

  group('expire', () {
    setUp(() => intents.start());

    test('ends the ask it names', () async {
      unawaited(fromSwift('ask', askArguments()));
      unawaited(fromSwift('ask', askArguments(id: 'a2')));
      await pumpEventQueue();

      await fromSwift('expire', 'a2');

      expect(ask.expired, 1);
    });

    test('ignores an ask that is already over', () async {
      unawaited(fromSwift('ask', askArguments()));
      await pumpEventQueue();
      ask.answers.single.complete(const AskResult(AskOutcome.answered, 'Hi'));
      ask.finishes.single.complete();
      await pumpEventQueue();

      await fromSwift('expire', 'a1');

      expect(ask.expired, 0);
    });

    test('ends every ask when it names none', () async {
      unawaited(fromSwift('ask', askArguments()));
      unawaited(fromSwift('ask', askArguments(id: 'a2')));
      await pumpEventQueue();

      await fromSwift('expire');

      expect(ask.expired, 2);
    });
  });

  test('does not know other methods', () async {
    await intents.start();

    expect(await fromSwift('nope'), isNull);
  });
}
