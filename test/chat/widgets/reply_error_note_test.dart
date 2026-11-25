import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/widgets/reply_error_note.dart';

void main() {
  Future<void> pump(WidgetTester tester, double scale) => tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: const Scaffold(body: ReplyErrorNote('Something went wrong.')),
      ),
    ),
  );

  testWidgets('the icon scales with the text', (tester) async {
    await pump(tester, 1);
    final normal = tester.getSize(find.byType(Icon)).width;

    await pump(tester, 2);

    expect(tester.getSize(find.byType(Icon)).width, normal * 2);
    expect(tester.takeException(), isNull);
  });
}
