import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/widgets/message_actions.dart';
import 'package:hermes_app/src/chat/widgets/reasoning_block.dart';
import 'package:hermes_app/src/chat/widgets/tool_call_group.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

Future<void> _pump(
  WidgetTester tester,
  TargetPlatform platform,
  Widget child,
) => tester.pumpWidget(
  MaterialApp(
    theme: buildHermesLightTheme().copyWith(platform: platform),
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: 320, child: child),
      ),
    ),
  ),
);

Size _sizeOf(WidgetTester tester, Finder finder) =>
    tester.getSize(finder.first);

Finder _button(String label) => find.ancestor(
  of: find.bySemanticsLabel(label),
  matching: find.byType(IconButton),
);

void main() {
  const group = [
    ToolCall(name: 'terminal', summary: 'ls'),
    ToolCall(name: 'read_file', summary: 'a.dart'),
  ];
  const single = [ToolCall(name: 'terminal', summary: 'ls', result: 'a')];

  testWidgets('on iOS the copy and retry actions are 44 points', (
    tester,
  ) async {
    await _pump(
      tester,
      TargetPlatform.iOS,
      MessageActions(text: 'hi', onRetry: () {}),
    );

    for (final label in ['Copy', 'Try again']) {
      final size = _sizeOf(tester, _button(label));
      expect(size.width, greaterThanOrEqualTo(44), reason: label);
      expect(size.height, greaterThanOrEqualTo(44), reason: label);
    }
  });

  testWidgets('on iOS the reasoning toggle is 44 points tall', (tester) async {
    await _pump(
      tester,
      TargetPlatform.iOS,
      const ReasoningBlock(text: 'because'),
    );

    expect(
      _sizeOf(tester, find.byType(InkWell)).height,
      greaterThanOrEqualTo(44),
    );
  });

  testWidgets('on iOS the tool group toggle is 44 points tall', (tester) async {
    await _pump(tester, TargetPlatform.iOS, const ToolCallGroup(calls: group));

    expect(
      _sizeOf(tester, find.byType(InkWell)).height,
      greaterThanOrEqualTo(44),
    );
  });

  testWidgets('on iOS the tool call header is 44 points tall', (tester) async {
    await _pump(tester, TargetPlatform.iOS, const ToolCallGroup(calls: single));

    expect(
      _sizeOf(tester, find.byType(ListTile)).height,
      greaterThanOrEqualTo(44),
    );
  });

  for (final platform in [
    TargetPlatform.android,
    TargetPlatform.macOS,
    TargetPlatform.linux,
  ]) {
    testWidgets('on $platform the sizes stay as they were', (tester) async {
      await _pump(
        tester,
        platform,
        Column(
          children: [
            MessageActions(text: 'hi', onRetry: () {}),
            const ReasoningBlock(text: 'because'),
            const ToolCallGroup(calls: group),
            const ToolCallGroup(calls: single),
          ],
        ),
      );

      expect(_sizeOf(tester, _button('Copy')), const Size(40, 40));
      expect(_sizeOf(tester, find.byType(ReasoningBlock)).height, lessThan(44));
      expect(_sizeOf(tester, find.byType(ListTile)).height, 36);
    });
  }
}
