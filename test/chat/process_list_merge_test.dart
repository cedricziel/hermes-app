import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/process_card_mapper.dart';
import 'package:hermes_app/src/chat/process_output_state.dart';
import 'package:hermes_app/src/chat/subagents/process_models.dart';
import 'package:hermes_app/src/chat/widgets/process_output_card.dart';

import 'subagents/process_fixtures.dart';

ProcessList list(List<Map<String, Object?>> rows) =>
    parseProcessList({'processes': rows})!;

Map<String, Object?> row(
  String id, {
  String status = 'running',
  String? command,
  int? exit,
  String? reason,
  int? uptime,
  String? tail,
}) => {
  'session_id': id,
  'status': status,
  'command': ?command,
  'exit_code': ?exit,
  'completion_reason': ?reason,
  'uptime_seconds': ?uptime,
  'output_tail': ?tail,
};

void main() {
  late ProcessOutputState state;
  late Object attachment;

  setUp(() {
    state = ProcessOutputState();
    attachment = Object();
    state.adopt(attachment);
  });

  void frame(String id, String chunk) => state.apply(
    ProcessOutputUpdate(id, chunk: chunk),
    attachment: attachment,
  );

  ProcessCardInfo? infoOf(String id) => processCardInfo(state.card(id)!);

  group('merging the list', () {
    test('a listed row names its card by id and no other', () {
      frame('proc_1', 'out');
      frame('proc_2', 'other');
      state.applyList(
        list([row('proc_1', command: 'npm test', uptime: 42)]),
        attachment: attachment,
      );
      final info = infoOf('proc_1')!;
      expect(info.command, 'npm test');
      expect(info.status, ProcessCardStatus.running);
      expect(info.runTime, const Duration(seconds: 42));
      expect(infoOf('proc_2'), isNull);
    });

    test('killed reads Stopped whatever the code; other exits carry their '
        'code, 0 included; an exit without a code is Ended', () {
      for (final id in ['k', 'k0', 'e1', 'e0', 'end', 'odd']) {
        frame(id, 'x');
      }
      state.applyList(
        list([
          row('k', status: 'exited', exit: -15, reason: 'killed'),
          row('k0', status: 'exited', exit: 0, reason: 'killed'),
          row('e1', status: 'exited', exit: 1),
          row('e0', status: 'exited', exit: 0),
          row('end', status: 'exited'),
          row('odd', status: 'vanished'),
        ]),
        attachment: attachment,
      );
      expect(infoOf('k')!.status, ProcessCardStatus.stopped);
      expect(infoOf('k0')!.status, ProcessCardStatus.stopped);
      expect(infoOf('e1')!.status, ProcessCardStatus.exited);
      expect(infoOf('e1')!.exitCode, 1);
      expect(infoOf('e0')!.status, ProcessCardStatus.exited);
      expect(infoOf('e0')!.exitCode, 0);
      expect(infoOf('end')!.status, ProcessCardStatus.ended);
      expect(infoOf('odd')!.status, ProcessCardStatus.ended);
    });

    test('a command of 200 characters is shown with a trailing ellipsis', () {
      frame('p', 'x');
      final long = 'a' * 200;
      state.applyList(list([row('p', command: long)]), attachment: attachment);
      final command = infoOf('p')!.command!;
      expect(command, long, reason: 'kept as given');
      expect(processCommandLine(command), '$long…');
      expect(processCommandLine('a' * 199), 'a' * 199);
    });

    test('a card without a list entry keeps today\'s wording and never '
        'claims success', () {
      frame('p', 'out');
      state.apply(
        const ProcessOutputUpdate('p', closed: true),
        attachment: attachment,
      );
      state.applyList(list([]), attachment: attachment);
      expect(state.card('p')!.listed, isFalse);
      expect(infoOf('p'), isNull);
    });

    test('a running program the list no longer has reads Ended', () {
      frame('p', 'out');
      state.applyList(list([row('p')]), attachment: attachment);
      state.applyList(list([]), attachment: attachment);
      expect(infoOf('p')!.status, ProcessCardStatus.ended);
    });

    test('a list for another attachment is stale and changes nothing', () {
      frame('p', 'out');
      expect(
        state.applyList(list([row('p', command: 'x')]), attachment: Object()),
        ProcessOutputOutcome.stale,
      );
      expect(state.card('p')!.listed, isFalse);
    });
  });

  group('output_tail', () {
    test('never replaces or extends frame output', () {
      final frames = 'f' * (20 * 1024);
      frame('p', frames);
      state.applyList(
        list([row('p', tail: 't' * kProcessTailChars)]),
        attachment: attachment,
      );
      expect(state.card('p')!.text, frames);
      expect(infoOf('p')!.seeded, isFalse);
    });

    test('seeds an empty card once, with the omission flag only when it is '
        '4,000 characters', () {
      state.apply(
        const ProcessOutputUpdate('closed-empty', closed: true),
        attachment: attachment,
      );
      state.applyList(
        list([
          row('closed-empty', tail: 'short'),
          row('new', tail: 'n' * kProcessTailChars),
        ]),
        attachment: attachment,
      );
      expect(state.card('closed-empty')!.text, 'short');
      expect(infoOf('closed-empty')!.seeded, isFalse);
      expect(state.card('new')!.text, 'n' * kProcessTailChars);
      expect(infoOf('new')!.seeded, isTrue);
      // A later tail does not touch the seeded text.
      state.applyList(
        list([row('new', tail: 'newer')]),
        attachment: attachment,
      );
      expect(state.card('new')!.text, 'n' * kProcessTailChars);
    });

    test('only a running program without a card gets one', () {
      state.applyList(
        parseProcessList(processListAnswer)!,
        attachment: attachment,
      );
      expect(state.cards.map((c) => c.processId), ['proc_ab12']);
      expect(state.card('proc_ab12')!.text, 'PASS src/a.test.js\n');
    });

    test('exited programs without a card cannot evict cards at the cap', () {
      for (var i = 0; i < ProcessOutputState.maxCards; i++) {
        frame('$i', 'out');
      }
      state.applyList(
        list([
          for (var i = 0; i < 20; i++)
            row('gone-$i', status: 'exited', exit: 0),
        ]),
        attachment: attachment,
      );
      expect(state.cards, hasLength(ProcessOutputState.maxCards));
      expect(state.cards.map((c) => c.processId), [
        for (var i = 0; i < ProcessOutputState.maxCards; i++) '$i',
      ]);
      expect(state.omittedCards, isFalse);
    });

    test('a running program at the cap evicts an ended card first', () {
      for (var i = 0; i < ProcessOutputState.maxCards; i++) {
        frame('$i', 'out');
      }
      state.applyList(
        list([row('5', status: 'exited', exit: 0), row('new')]),
        attachment: attachment,
      );
      expect(state.cards, hasLength(ProcessOutputState.maxCards));
      expect(state.card('5'), isNull);
      expect(state.card('new'), isNotNull);
      expect(state.omittedCards, isTrue);
    });
  });

  test('a list-only program never evicts a running card at the cap', () {
    for (var i = 0; i < ProcessOutputState.maxCards; i++) {
      frame('$i', 'frame output $i');
    }
    final running = [
      for (var i = 0; i < ProcessOutputState.maxCards; i++) row('$i'),
    ];
    for (var read = 0; read < 3; read++) {
      state.applyList(
        list([...running, row('extra', tail: 'x')]),
        attachment: attachment,
      );
    }
    expect(state.card('extra'), isNull);
    expect(state.cards.map((c) => c.text), [
      for (var i = 0; i < ProcessOutputState.maxCards; i++) 'frame output $i',
    ]);
    expect(state.omittedCards, isFalse);
  });

  group('kill answers', () {
    test('killed reads Stopped and its output is not appended to a card '
        'with output', () {
      frame('p', 'from frames');
      state.applyList(
        list([row('p', command: 'npm run dev')]),
        attachment: attachment,
      );
      state.applyKill(
        'p',
        parseProcessKill({...killKilled, 'output': 'from frames and more'})!,
        attachment: attachment,
      );
      expect(state.card('p')!.text, 'from frames');
      expect(infoOf('p')!.status, ProcessCardStatus.stopped);
    });

    test('kill output seeds an empty card, omitted only when cut', () {
      state.apply(
        const ProcessOutputUpdate('a', closed: true),
        attachment: attachment,
      );
      state.apply(
        const ProcessOutputUpdate('b', closed: true),
        attachment: attachment,
      );
      state.applyKill(
        'a',
        parseProcessKill({...killKilled, 'output': 'tail a'})!,
        attachment: attachment,
      );
      state.applyKill(
        'b',
        parseProcessKill({
          ...killKilled,
          'output': 'tail b',
          'output_cut': true,
        })!,
        attachment: attachment,
      );
      expect(state.card('a')!.text, 'tail a');
      expect(state.card('a')!.seeded, isFalse);
      expect(state.card('b')!.text, 'tail b');
      expect(state.card('b')!.seeded, isTrue);
    });

    test('already exited takes its code; error leaves the card unchanged; '
        'no answer adds a card', () {
      frame('p', 'x');
      state.applyList(list([row('p')]), attachment: attachment);
      state.applyKill(
        'p',
        parseProcessKill(killError)!,
        attachment: attachment,
      );
      expect(infoOf('p')!.status, ProcessCardStatus.running);
      state.applyKill(
        'p',
        parseProcessKill(killAlreadyExited)!,
        attachment: attachment,
      );
      expect(infoOf('p')!.status, ProcessCardStatus.exited);
      expect(infoOf('p')!.exitCode, 0);
      state.applyKill(
        'none',
        parseProcessKill(killKilled)!,
        attachment: attachment,
      );
      expect(state.card('none'), isNull);
    });

    test('a kill for another attachment is stale', () {
      frame('p', 'x');
      state.applyList(list([row('p')]), attachment: attachment);
      expect(
        state.applyKill(
          'p',
          parseProcessKill(killKilled)!,
          attachment: Object(),
        ),
        ProcessOutputOutcome.stale,
      );
      expect(infoOf('p')!.status, ProcessCardStatus.running);
    });
  });

  test('toString prints counts only', () {
    frame('secret-proc', 'secret output');
    state.applyList(
      list([row('secret-proc', command: 'secret-command')]),
      attachment: attachment,
    );
    final text = '$state ${state.cards.join(' ')}';
    expect(text, isNot(contains('secret')));
  });

  test('the stop status reaches the card info', () {
    frame('p', 'x');
    state.applyList(list([row('p')]), attachment: attachment);
    expect(
      processCardInfo(state.card('p')!, stop: ProcessStopStatus.checking)!.stop,
      ProcessStopStatus.checking,
    );
  });
}
