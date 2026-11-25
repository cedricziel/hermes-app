import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/report_chat_bug.dart';

void main() {
  late void Function(FlutterErrorDetails)? previous;
  late List<FlutterErrorDetails> reported;

  setUp(() {
    previous = FlutterError.onError;
    reported = [];
    FlutterError.onError = reported.add;
  });

  tearDown(() => FlutterError.onError = previous);

  test('hands an Error to the crash reporter under the fixed name', () {
    final bug = TypeError();

    reportChatBug(bug, StackTrace.current, 'a place');

    expect(reported.single.exception, same(bug));
    expect(reported.single.context.toString(), 'a place');
  });

  test('stays quiet about the chat refusals (a StateError)', () {
    reportChatBug(
      StateError('Chat activity suspended'),
      StackTrace.current,
      'a place',
    );

    expect(reported, isEmpty);
  });

  test('stays quiet about an Exception', () {
    reportChatBug(const FormatException('x'), StackTrace.current, 'a place');

    expect(reported, isEmpty);
  });
}
