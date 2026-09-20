import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/mcp/mcp_command_review.dart';
import 'package:hermes_app/src/mcp/mcp_command_review_items.dart';

/// The review step on its own: a sheet or a dialog by width, what it shows and
/// the one answer it gives.
void main() {
  const notes = McpCommandReviewItem(
    name: 'notes-fs',
    command: 'npx',
    args: ['-y', '@modelcontextprotocol/server-filesystem', '/srv/my notes'],
    envNames: ['NOTES_TOKEN'],
  );

  bool? answer;

  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(420, 900),
    List<McpCommandReviewItem> items = const [notes],
    String confirmLabel = 'Add and run on server',
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    answer = null;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (page) => Scaffold(
                  body: TextButton(
                    onPressed: () async => answer = await showMcpCommandReview(
                      page,
                      items,
                      confirmLabel: confirmLabel,
                    ),
                    child: const Text('review'),
                  ),
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('review'));
    await tester.pumpAndSettle();
  }

  final confirm = find.byKey(const ValueKey('mcp-review-confirm'));
  final back = find.byKey(const ValueKey('mcp-review-back'));

  testWidgets('is a bottom sheet on a narrow layout', (tester) async {
    await open(tester);

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('is a dialog on a wide layout', (tester) async {
    await open(tester, size: const Size(1200, 800));

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('says the server runs on the host and shows what runs', (
    tester,
  ) async {
    await open(tester);

    expect(find.text('Run this on your server?'), findsOneWidget);
    expect(find.textContaining('runs on your Hermes host'), findsOneWidget);
    expect(find.text('notes-fs'), findsOneWidget);
    expect(find.text('npx'), findsOneWidget);
    expect(find.text('-y'), findsOneWidget);
    expect(
      find.text('@modelcontextprotocol/server-filesystem'),
      findsOneWidget,
    );
    expect(find.text('/srv/my notes'), findsOneWidget);
    expect(find.text('NOTES_TOKEN'), findsOneWidget);
    expect(find.text('Add and run on server'), findsOneWidget);
    expect(find.text('Back to edit'), findsOneWidget);
  });

  testWidgets('uses the confirm label it is given', (tester) async {
    await open(tester, confirmLabel: 'Save and run on server');

    expect(find.text('Save and run on server'), findsOneWidget);
    expect(find.text('Add and run on server'), findsNothing);
  });

  testWidgets('lists every server it is given', (tester) async {
    await open(
      tester,
      items: const [
        notes,
        McpCommandReviewItem(name: 'other', command: 'true'),
      ],
    );

    expect(find.text('Run these on your server?'), findsOneWidget);
    expect(find.text('notes-fs'), findsOneWidget);
    expect(find.text('other'), findsOneWidget);
    expect(find.text('true'), findsOneWidget);
  });

  testWidgets('confirming answers yes', (tester) async {
    await open(tester);

    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(answer, isTrue);
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('confirming twice closes one route', (tester) async {
    await open(tester);

    final onPressed = tester.widget<FilledButton>(confirm).onPressed!;
    onPressed();
    onPressed();
    await tester.pumpAndSettle();

    expect(answer, isTrue);
    expect(find.text('review'), findsOneWidget);
  });

  testWidgets('going back answers no', (tester) async {
    await open(tester);

    await tester.tap(back);
    await tester.pumpAndSettle();

    expect(answer, isFalse);
  });

  testWidgets('dismissing the sheet answers no', (tester) async {
    await open(tester);

    await tester.tapAt(const Offset(200, 20));
    await tester.pumpAndSettle();

    expect(answer, isFalse);
  });

  testWidgets('dismissing the dialog answers no', (tester) async {
    await open(tester, size: const Size(1200, 800));

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(answer, isFalse);
  });
}
