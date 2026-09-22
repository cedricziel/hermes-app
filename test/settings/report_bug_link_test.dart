import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/settings/report_bug_link.dart';

void main() {
  testWidgets('opens the issue tracker when tapped', (tester) async {
    Uri? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: ReportBugLink(
          openLink: (uri) async {
            opened = uri;
            return true;
          },
        ),
      ),
    );

    await tester.tap(find.text('Report a bug'));
    await tester.pump();

    expect(
      opened,
      Uri.parse('https://github.com/cedricziel/hermes-app/issues'),
    );
  });

  testWidgets('does not throw when the link fails to open', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReportBugLink(openLink: (_) async => throw Exception('nope')),
      ),
    );

    await tester.tap(find.text('Report a bug'));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Report a bug'), findsOneWidget);
  });
}
