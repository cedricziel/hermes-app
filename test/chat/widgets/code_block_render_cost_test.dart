import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' hide MessageStatus;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/chat/chat_message_kinds.dart';
import 'package:hermes_app/src/chat/widgets/chat_builders.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

/// Wall-clock cost of laying out and painting a reply that holds a fenced code
/// block. `flutter_test` pumps are synchronous on the test isolate, so a
/// Stopwatch around `pumpWidget` and `pump` is real time (no fake clock is
/// involved in build, layout or paint).
final _measured = <String>[];

Future<({int first, int rest})> _render(
  WidgetTester tester,
  String text,
) async {
  tester.view.physicalSize = const Size(1000, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final controller = InMemoryChatController(
    messages: [
      Message.text(
        id: 'a-1',
        authorId: kAssistantAuthorId,
        text: text,
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    ],
  );
  addTearDown(controller.dispose);
  final first = Stopwatch()..start();
  await tester.pumpWidget(
    MaterialApp(
      theme: buildHermesLightTheme(),
      home: Scaffold(
        body: Chat(
          currentUserId: kUserAuthorId,
          resolveUser: (id) async => User(id: id),
          chatController: controller,
          builders: buildChatBuilders(onPickPrompt: (_) {})
              .copyWith(composerBuilder: (_) => const SizedBox.shrink()),
        ),
      ),
    ),
  );
  first.stop();
  final rest = Stopwatch()..start();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
  rest.stop();
  return (first: first.elapsedMilliseconds, rest: rest.elapsedMilliseconds);
}

String _fence(String lang, String body) =>
    'Here:\n\n```$lang\n$body\n```\n\nDone.';

String _base64Like(int n) =>
    List.generate(n, (i) => 'ABCDEFGHabcdefgh01234567+/'[i % 26]).join();

void main() {
  tearDownAll(() {
    // ignore: avoid_print
    print('RENDER-COST\n${_measured.join('\n')}');
  });

  final cases = <String, String>{
    'normal js 40 lines': _fence(
      'javascript',
      List.generate(40, (i) => 'const x$i = foo($i); // note').join('\n'),
    ),
    for (final n in [2500, 5000, 10000, 20000])
      'quadratic js a+$n spaces': _fence('javascript', 'a${' ' * n}'),
    for (final n in [2000, 10000, 50000])
      'dense 1+ x$n js': _fence('javascript', '1+' * n),
    for (final n in [2000, 10000])
      'dense 1+ x$n python': _fence('python', '1+' * n),
    'comment lines x2000 js': _fence(
      'javascript',
      List.filled(2000, '// a benign comment line').join('\n'),
    ),
    'comment lines x2000 dart': _fence(
      'dart',
      List.filled(2000, '// a benign comment line').join('\n'),
    ),
    for (final n in [100000, 400000])
      'one line base64-like $n text': _fence('text', _base64Like(n)),
    'one line base64-like 100000 js': _fence('javascript', _base64Like(100000)),
    'many fences x100 (20 lines each)': List.generate(
      100,
      (i) => _fence(
        'python',
        List.generate(20, (j) => 'x$j = f($j)  # c').join('\n'),
      ),
    ).join('\n\n'),
  };

  for (final e in cases.entries) {
    testWidgets(e.key, (tester) async {
      final r = await _render(tester, e.value);
      _measured.add(
        '${e.key} | chars=${e.value.length} | first=${r.first}ms | pumps=${r.rest}ms',
      );
      // Unbounded, the 20k-space and 50k-run cases take 6 s and 16 s here.
      expect(r.first + r.rest, lessThan(2500), reason: e.key);
    }, timeout: const Timeout(Duration(minutes: 4)));
  }
}
